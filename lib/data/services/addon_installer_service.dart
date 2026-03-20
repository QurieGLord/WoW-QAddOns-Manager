import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wow_qaddons_manager/core/services/background_task_service.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class AddonInstallerService {
  final Dio _dio = Dio();
  final BackgroundTaskService _backgroundTaskService;

  AddonInstallerService(this._backgroundTaskService);

  Future<AddonInstallResult> installAddon(
    String downloadUrl,
    String fileName,
    GameClient client,
  ) async {
    final systemTempDir = await getTemporaryDirectory();
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();
    final tempExtractDir = Directory(
      p.join(systemTempDir.path, 'extract_$uniqueId'),
    );
    final tempZipPath = p.join(systemTempDir.path, '$uniqueId.zip');

    await tempExtractDir.create(recursive: true);

    try {
      await _dio.download(downloadUrl, tempZipPath);
      await _extractZipFile(File(tempZipPath), tempExtractDir);
      final result = await _installPreparedContent(
        tempExtractDir,
        client,
        sourceLabel: fileName,
        strictConflictCheck: false,
        replaceExisting: true,
      );
      return result;
    } finally {
      await _safeDeleteDirectory(tempExtractDir);
      await _safeDeleteFile(File(tempZipPath));
    }
  }

  Future<AddonInstallResult> installFromArchive(
    String archivePath,
    GameClient client, {
    bool replaceExisting = false,
  }) async {
    final sourceFile = File(archivePath);
    if (!await sourceFile.exists()) {
      throw Exception('ARCHIVE_NOT_FOUND');
    }

    final systemTempDir = await getTemporaryDirectory();
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();
    final tempExtractDir = Directory(
      p.join(systemTempDir.path, 'manual_extract_$uniqueId'),
    );

    await tempExtractDir.create(recursive: true);

    try {
      await _extractZipFile(sourceFile, tempExtractDir);
      final result = await _installPreparedContent(
        tempExtractDir,
        client,
        sourceLabel: p.basename(archivePath),
        strictConflictCheck: true,
        replaceExisting: replaceExisting,
      );
      return result;
    } finally {
      await _safeDeleteDirectory(tempExtractDir);
    }
  }

  Future<AddonInstallResult> installFromDirectory(
    String directoryPath,
    GameClient client, {
    bool replaceExisting = false,
  }) async {
    final sourceDirectory = Directory(directoryPath);
    if (!await sourceDirectory.exists()) {
      throw Exception('DIRECTORY_NOT_FOUND');
    }

    return _installPreparedContent(
      sourceDirectory,
      client,
      sourceLabel: p.basename(directoryPath),
      strictConflictCheck: true,
      replaceExisting: replaceExisting,
    );
  }

  Future<List<InstalledAddonFolder>> scanInstalledFolders(
    GameClient client,
  ) async {
    final addonsDir = Directory(p.join(client.path, 'Interface', 'AddOns'));
    if (!await addonsDir.exists()) {
      return [];
    }
    return _backgroundTaskService.scanInstalledAddonFolders(addonsDir.path);
  }

  Future<void> deleteAddon(GameClient client, InstalledAddonGroup group) async {
    for (final folderName in group.installedFolders) {
      final directory = Directory(
        p.join(client.path, 'Interface', 'AddOns', folderName),
      );
      if (await directory.exists()) {
        try {
          await directory.delete(recursive: true);
        } catch (error) {
          throw Exception('DELETE_FAILED: $error');
        }
      }
    }
  }

  Future<AddonInstallResult> _installPreparedContent(
    Directory preparedRoot,
    GameClient client, {
    required String sourceLabel,
    required bool strictConflictCheck,
    required bool replaceExisting,
  }) async {
    final addonsDir = await _ensureAddonsDirectory(client);
    final addonRoots = await _backgroundTaskService.analyzeAddonRoots(
      preparedRoot.path,
      sourceLabel,
    );
    if (addonRoots.isEmpty) {
      throw Exception('NO_TOC_FOLDERS_FOUND');
    }

    final resolvedRoots = <_ResolvedAddonRoot>[];
    final targetFolderNames = <String>{};

    for (final root in addonRoots) {
      resolvedRoots.add(
        _ResolvedAddonRoot(
          source: Directory(root.sourcePath),
          targetFolderName: root.targetFolderName,
          title: root.title,
        ),
      );
      targetFolderNames.add(root.targetFolderName);
    }

    if (resolvedRoots.isEmpty || targetFolderNames.isEmpty) {
      throw Exception('NO_VALID_ADDON_CONTENT');
    }

    if (strictConflictCheck) {
      final conflictingFolders = await _findExistingTargetFolders(
        addonsDir,
        targetFolderNames,
      );
      if (conflictingFolders.isNotEmpty && !replaceExisting) {
        throw AddonInstallConflictException(conflictingFolders);
      }
    } else if (await _allTargetFoldersExist(addonsDir, targetFolderNames)) {
      throw Exception('ALREADY_INSTALLED');
    }

    final installedFolders = <String>{};
    final stagedDirectories = <Directory>[];
    final committedDirectories = <Directory>[];

    try {
      for (final root in resolvedRoots) {
        final targetDir = Directory(
          p.join(addonsDir.path, root.targetFolderName),
        );
        final stagedTargetDir = await _prepareStagedTargetDirectory(
          addonsDir,
          root.targetFolderName,
        );
        stagedDirectories.add(stagedTargetDir);

        await _copyAddonRoot(root.source, stagedTargetDir);
        await _ensureValidInstalledRoot(stagedTargetDir);

        if (await targetDir.exists()) {
          await targetDir.delete(recursive: true);
        }

        await stagedTargetDir.rename(targetDir.path);
        stagedDirectories.remove(stagedTargetDir);
        committedDirectories.add(targetDir);
        installedFolders.add(root.targetFolderName);
      }
    } catch (_) {
      for (final stagedDirectory in stagedDirectories) {
        await _safeDeleteDirectory(stagedDirectory);
      }

      for (final committedDirectory in committedDirectories) {
        await _safeDeleteDirectory(committedDirectory);
      }
      rethrow;
    }

    if (installedFolders.isEmpty) {
      throw Exception('NO_VALID_ADDON_CONTENT');
    }

    return AddonInstallResult(
      installedFolders: installedFolders.toList()..sort(),
      displayName: _resolveInstalledDisplayName(resolvedRoots, sourceLabel),
    );
  }

  Future<Directory> _ensureAddonsDirectory(GameClient client) async {
    final addonsDir = Directory(p.join(client.path, 'Interface', 'AddOns'));
    if (!await addonsDir.exists()) {
      await addonsDir.create(recursive: true);
    }
    return addonsDir;
  }

  Future<void> _extractZipFile(
    File archiveFile,
    Directory outputDirectory,
  ) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    await _extractArchive(archive, outputDirectory.path);
  }

  Future<void> _extractArchive(Archive archive, String outputPath) async {
    final normalizedOutputPath = p.normalize(outputPath);

    for (final file in archive) {
      final sanitizedName = p.normalize(
        file.name.replaceAll('\\', p.separator).trim(),
      );
      if (sanitizedName.isEmpty ||
          _containsUnsupportedPathSegment(sanitizedName) ||
          p.isAbsolute(sanitizedName) ||
          sanitizedName.startsWith('..') ||
          sanitizedName.startsWith('/')) {
        continue;
      }

      final filePath = p.normalize(p.join(normalizedOutputPath, sanitizedName));
      if (filePath != normalizedOutputPath &&
          !p.isWithin(normalizedOutputPath, filePath)) {
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

  Future<List<String>> _findExistingTargetFolders(
    Directory addonsDir,
    Iterable<String> folderNames,
  ) async {
    final conflicts = <String>[];

    for (final folderName in folderNames) {
      final targetDir = Directory(p.join(addonsDir.path, folderName));
      if (await targetDir.exists()) {
        conflicts.add(folderName);
      }
    }

    conflicts.sort();
    return conflicts;
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
    if (!await source.exists()) {
      throw FileSystemException('Addon root is missing', source.path);
    }
    await target.create(recursive: true);
    await _copyDirectoryContents(source, target);
  }

  Future<void> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    if (!await source.exists()) {
      throw FileSystemException('Source directory is missing', source.path);
    }
    await target.create(recursive: true);
    final entities = await _listDirectoryEntities(source);
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (_shouldSkipCopiedEntry(name)) {
        continue;
      }

      final targetPath = p.join(target.path, name);
      if (entity is File) {
        if (!await entity.exists()) {
          continue;
        }

        final targetFile = File(targetPath);
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(await entity.readAsBytes());
      } else if (entity is Directory) {
        await _copyDirectoryContents(entity, Directory(targetPath));
      }
    }
  }

  Future<Directory> _prepareStagedTargetDirectory(
    Directory addonsDir,
    String targetFolderName,
  ) async {
    final stagedDirectory = Directory(
      p.join(
        addonsDir.path,
        '.qadd_stage_${DateTime.now().microsecondsSinceEpoch}_$targetFolderName',
      ),
    );
    if (await stagedDirectory.exists()) {
      await stagedDirectory.delete(recursive: true);
    }
    await stagedDirectory.create(recursive: true);
    return stagedDirectory;
  }

  Future<void> _ensureValidInstalledRoot(Directory directory) async {
    final tocFiles = await _getDirectTocFiles(directory);
    if (tocFiles.isEmpty) {
      throw Exception('INVALID_ADDON_ROOT');
    }
  }

  Future<List<File>> _getDirectTocFiles(Directory directory) async {
    final entities = await _listDirectoryEntities(directory);
    return entities
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.toc'))
        .toList(growable: false);
  }

  bool _shouldSkipCopiedEntry(String name) {
    final lower = name.toLowerCase();
    return _containsUnsupportedPathSegment(name) || lower == '__macosx';
  }

  String _resolveInstalledDisplayName(
    List<_ResolvedAddonRoot> roots,
    String fallbackSource,
  ) {
    if (roots.isEmpty) {
      return _prettifyGroupTitle(_stripSourceExtension(fallbackSource));
    }

    if (roots.length == 1) {
      return roots.first.title;
    }

    final groupedTitles = roots
        .map((root) => _extractTitleGroupBase(root.title))
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    if (groupedTitles.length == 1) {
      return groupedTitles.first;
    }

    final prefix = _extractCommonFolderPrefix(
      roots.map((root) => root.targetFolderName).toList(growable: false),
    );
    if (prefix != null && prefix.trim().isNotEmpty) {
      return _prettifyGroupTitle(prefix);
    }

    return roots.first.title;
  }

  String _extractTitleGroupBase(String title) {
    final withoutBrackets = title.replaceAll(RegExp(r'\[[^\]]+\]'), ' ').trim();
    final withoutParentheses = withoutBrackets
        .replaceAll(RegExp(r'\([^\)]+\)'), ' ')
        .trim();
    final splitByDash = withoutParentheses
        .split(RegExp(r'\s*[-:]\s*'))
        .first
        .trim();
    return splitByDash.isEmpty ? title.trim() : splitByDash;
  }

  String? _extractCommonFolderPrefix(List<String> folderNames) {
    if (folderNames.length < 2) {
      return null;
    }

    String? sharedPrefix;
    for (final folderName in folderNames) {
      final parts = folderName.split(RegExp(r'[_-]'));
      if (parts.length < 2 || parts.first.trim().isEmpty) {
        return null;
      }

      final prefix = parts.first.trim();
      if (sharedPrefix == null) {
        sharedPrefix = prefix;
        continue;
      }

      if (sharedPrefix.toLowerCase() != prefix.toLowerCase()) {
        return null;
      }
    }

    return sharedPrefix;
  }

  String _prettifyGroupTitle(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'Addon' : normalized;
  }

  String _stripSourceExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.zip')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  Future<List<FileSystemEntity>> _listDirectoryEntities(
    Directory directory,
  ) async {
    try {
      return await directory.list().toList();
    } catch (_) {
      return const <FileSystemEntity>[];
    }
  }

  bool _containsUnsupportedPathSegment(String path) {
    final segments = path
        .split(RegExp(r'[\\/]'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty);

    for (final segment in segments) {
      if (RegExp(r'[<>:"|?*]').hasMatch(segment)) {
        return true;
      }
    }

    return false;
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

class AddonInstallConflictException implements Exception {
  final List<String> folderNames;

  const AddonInstallConflictException(this.folderNames);

  @override
  String toString() {
    return 'AddonInstallConflictException(${folderNames.join(', ')})';
  }
}

class _ResolvedAddonRoot {
  final Directory source;
  final String targetFolderName;
  final String title;

  const _ResolvedAddonRoot({
    required this.source,
    required this.targetFolderName,
    required this.title,
  });
}
