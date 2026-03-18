import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class AddonInstallerService {
  final Dio _dio = Dio();

  Future<AddonInstallResult> installAddon(
    String downloadUrl,
    String fileName,
    GameClient client,
  ) async {
    final addonsDir = await _ensureAddonsDirectory(client);
    final systemTempDir = await getTemporaryDirectory();
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();
    final tempExtractDir = Directory(p.join(systemTempDir.path, 'extract_$uniqueId'));
    final tempZipPath = p.join(systemTempDir.path, '$uniqueId.zip');

    await tempExtractDir.create(recursive: true);

    try {
      await _dio.download(downloadUrl, tempZipPath);

      final bytes = await File(tempZipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      await _extractArchive(archive, tempExtractDir.path);

      final addonRoots = await _collectAddonRoots(tempExtractDir);
      if (addonRoots.isEmpty) {
        throw Exception('NO_TOC_FOLDERS_FOUND');
      }

      final targetFolderNames = <String>{};
      for (final root in addonRoots) {
        final targetFolderName = await _resolveTargetFolderName(root, fileName);
        if (targetFolderName == null || targetFolderName.trim().isEmpty) {
          continue;
        }

        targetFolderNames.add(targetFolderName);
      }

      if (targetFolderNames.isEmpty) {
        throw Exception('NO_VALID_ADDON_CONTENT');
      }

      if (await _allTargetFoldersExist(addonsDir, targetFolderNames)) {
        throw Exception('ALREADY_INSTALLED');
      }

      final installedFolders = <String>{};
      for (final root in addonRoots) {
        final targetFolderName = await _resolveTargetFolderName(root, fileName);
        if (targetFolderName == null || targetFolderName.trim().isEmpty) {
          continue;
        }

        final targetDir = Directory(p.join(addonsDir.path, targetFolderName));
        if (await targetDir.exists()) {
          await targetDir.delete(recursive: true);
        }

        await _copyAddonRoot(root, targetDir);
        installedFolders.add(targetFolderName);
      }

      if (installedFolders.isEmpty) {
        throw Exception('NO_VALID_ADDON_CONTENT');
      }

      return AddonInstallResult(
        installedFolders: installedFolders.toList()..sort(),
      );
    } finally {
      await _safeDeleteDirectory(tempExtractDir);
      await _safeDeleteFile(File(tempZipPath));
    }
  }

  Future<List<InstalledAddonFolder>> scanInstalledFolders(GameClient client) async {
    final addonsDir = Directory(p.join(client.path, 'Interface', 'AddOns'));
    if (!await addonsDir.exists()) {
      return [];
    }

    final folders = <InstalledAddonFolder>[];
    final entities = await addonsDir.list().toList();

    for (final entity in entities) {
      if (entity is! Directory) {
        continue;
      }

      final folderName = p.basename(entity.path);
      if (folderName.startsWith('Blizzard_') || folderName.startsWith('.')) {
        continue;
      }

      final tocFiles = await _getDirectTocFiles(entity);
      if (tocFiles.isEmpty) {
        continue;
      }

      final metadata = await _parseAddonMetadata(tocFiles, folderName);
      folders.add(
        InstalledAddonFolder(
          folderName: folderName,
          displayName: metadata.title,
          title: metadata.title,
          tocNames: metadata.tocNames,
          dependencies: metadata.dependencies,
          xPartOf: metadata.xPartOf,
        ),
      );
    }

    folders.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return folders;
  }

  Future<void> deleteAddon(GameClient client, InstalledAddonGroup group) async {
    for (final folderName in group.installedFolders) {
      final directory = Directory(p.join(client.path, 'Interface', 'AddOns', folderName));
      if (await directory.exists()) {
        try {
          await directory.delete(recursive: true);
        } catch (error) {
          throw Exception('DELETE_FAILED: $error');
        }
      }
    }
  }

  Future<Directory> _ensureAddonsDirectory(GameClient client) async {
    final addonsDir = Directory(p.join(client.path, 'Interface', 'AddOns'));
    if (!await addonsDir.exists()) {
      await addonsDir.create(recursive: true);
    }
    return addonsDir;
  }

  Future<void> _extractArchive(Archive archive, String outputPath) async {
    final normalizedOutputPath = p.normalize(outputPath);

    for (final file in archive) {
      final sanitizedName = p.normalize(file.name.replaceAll('\\', p.separator).trim());
      if (sanitizedName.isEmpty ||
          p.isAbsolute(sanitizedName) ||
          sanitizedName.startsWith('..') ||
          sanitizedName.startsWith('/')) {
        continue;
      }

      final filePath = p.normalize(p.join(normalizedOutputPath, sanitizedName));
      if (filePath != normalizedOutputPath && !p.isWithin(normalizedOutputPath, filePath)) {
        continue;
      }

      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  Future<List<Directory>> _collectAddonRoots(Directory rootDir) async {
    final addonRoots = <Directory>[];

    Future<void> traverse(Directory directory) async {
      final tocFiles = await _getDirectTocFiles(directory);
      if (tocFiles.isNotEmpty) {
        addonRoots.add(directory);
        return;
      }

      final children = await directory.list().toList();
      for (final child in children.whereType<Directory>()) {
        final folderName = p.basename(child.path);
        if (_shouldSkipFolder(folderName)) {
          continue;
        }
        await traverse(child);
      }
    }

    await traverse(rootDir);
    return addonRoots;
  }

  Future<List<File>> _getDirectTocFiles(Directory directory) async {
    final entities = await directory.list().toList();
    return entities
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.toc'))
        .toList();
  }

  bool _shouldSkipFolder(String folderName) {
    final lower = folderName.toLowerCase();
    return lower == '.git' ||
        lower == '.github' ||
        lower == '__macosx' ||
        lower == '.idea' ||
        lower == '.vscode';
  }

  Future<String?> _resolveTargetFolderName(Directory root, String archiveFileName) async {
    final tocFiles = await _getDirectTocFiles(root);
    if (root.parent.path == root.path) {
      return null;
    }

    if (tocFiles.isEmpty) {
      return _sanitizeFolderName(_stripArchiveExtension(archiveFileName));
    }

    final rootFolderName = p.basename(root.path);
    final normalizedRootFolderName = _normalizeFolderKey(rootFolderName);
    final archiveBaseName = _normalizeFolderKey(_stripArchiveExtension(archiveFileName));
    final tocNames =
        tocFiles
            .map((file) => p.basenameWithoutExtension(file.path))
            .where((name) => name.trim().isNotEmpty)
            .toList(growable: false);

    final matchingTocByFolder = tocNames.firstWhere(
      (tocName) => _normalizeFolderKey(tocName) == normalizedRootFolderName,
      orElse: () => '',
    );
    if (matchingTocByFolder.isNotEmpty) {
      return _sanitizeFolderName(matchingTocByFolder);
    }

    final matchingTocByArchive = tocNames.firstWhere(
      (tocName) => _normalizeFolderKey(tocName) == archiveBaseName,
      orElse: () => '',
    );
    if (matchingTocByArchive.isNotEmpty) {
      return _sanitizeFolderName(matchingTocByArchive);
    }

    if (tocNames.length == 1) {
      return _sanitizeFolderName(tocNames.first);
    }

    return _sanitizeFolderName(rootFolderName);
  }

  Future<bool> _allTargetFoldersExist(
    Directory addonsDir,
    Iterable<String> folderNames,
  ) async {
    for (final folderName in folderNames) {
      final targetDir = Directory(p.join(addonsDir.path, folderName));
      if (!await targetDir.exists()) {
        return false;
      }
    }

    return true;
  }

  Future<void> _copyAddonRoot(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      if (_shouldSkipEntity(name)) {
        continue;
      }

      final targetPath = p.join(target.path, name);
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      if (_shouldSkipEntity(name)) {
        continue;
      }

      final targetPath = p.join(target.path, name);
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

  bool _shouldSkipEntity(String name) {
    final lower = name.toLowerCase();
    return lower == '.ds_store' ||
        lower == 'thumbs.db' ||
        lower == '.gitignore' ||
        lower == '.gitattributes' ||
        lower == '.editorconfig' ||
        lower == 'license' ||
        lower == 'license.txt' ||
        lower == 'readme' ||
        lower == 'readme.md' ||
        lower == 'changelog' ||
        lower == 'changelog.md' ||
        lower == '__macosx';
  }

  Future<_TocMetadata> _parseAddonMetadata(List<File> tocFiles, String fallback) async {
    String displayName = fallback;
    final tocNames =
        tocFiles
            .map((file) => p.basenameWithoutExtension(file.path))
            .where((name) => name.trim().isNotEmpty)
            .toList(growable: false);
    final dependencies = <String>[];
    String? xPartOf;

    try {
      final preferredToc = tocFiles.firstWhere(
        (file) => p.basename(file.path).toLowerCase() == '${fallback.toLowerCase()}.toc',
        orElse: () => tocFiles.first,
      );

      final lines = await preferredToc.readAsLines();
      for (final line in lines) {
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('## Title:')) {
          final title = trimmedLine.replaceFirst('## Title:', '').trim();
          if (title.isNotEmpty) {
            displayName = _cleanWowTitle(title);
          }
          continue;
        }

        if (trimmedLine.startsWith('## RequiredDeps:')) {
          final value = trimmedLine.replaceFirst('## RequiredDeps:', '').trim();
          dependencies.addAll(_parseDependencies(value));
          continue;
        }

        if (trimmedLine.startsWith('## Dependencies:')) {
          final value = trimmedLine.replaceFirst('## Dependencies:', '').trim();
          dependencies.addAll(_parseDependencies(value));
          continue;
        }

        if (trimmedLine.startsWith('## X-Part-Of:')) {
          final value = trimmedLine.replaceFirst('## X-Part-Of:', '').trim();
          if (value.isNotEmpty) {
            xPartOf = _cleanWowTitle(value);
          }
        }
      }
    } catch (_) {
      return _TocMetadata(title: fallback);
    }

    return _TocMetadata(
      title: displayName,
      tocNames: tocNames,
      dependencies: dependencies.toSet().toList(),
      xPartOf: xPartOf,
    );
  }

  List<String> _parseDependencies(String rawValue) {
    return rawValue
        .split(',')
        .map((dependency) => dependency.trim())
        .where((dependency) => dependency.isNotEmpty)
        .toList();
  }

  String _cleanWowTitle(String title) {
    return title
        .replaceAll(RegExp(r'\|c[0-9a-fA-F]{8}'), '')
        .replaceAll('|r', '')
        .trim();
  }

  String _stripArchiveExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.zip')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  String _sanitizeFolderName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'-(main|master)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_!.-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return cleaned.isEmpty ? 'Addon' : cleaned;
  }

  String _normalizeFolderKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'-(main|master)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _safeDeleteDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _safeDeleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _TocMetadata {
  final String title;
  final List<String> tocNames;
  final List<String> dependencies;
  final String? xPartOf;

  const _TocMetadata({
    required this.title,
    this.tocNames = const <String>[],
    this.dependencies = const <String>[],
    this.xPartOf,
  });
}
