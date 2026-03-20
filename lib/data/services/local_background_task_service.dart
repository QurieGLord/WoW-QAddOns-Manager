import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:wow_qaddons_manager/core/services/background_task_service.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class LocalBackgroundTaskService implements BackgroundTaskService {
  @override
  Future<List<AddonRootDescriptor>> analyzeAddonRoots(
    String rootPath,
    String sourceLabel,
  ) async {
    final payload = await Isolate.run(
      () => _analyzeAddonRootsPayload(rootPath, sourceLabel),
    );

    return payload
        .map(
          (item) => AddonRootDescriptor(
            sourcePath: item['sourcePath'] as String,
            targetFolderName: item['targetFolderName'] as String,
            title: item['title'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<InstalledAddonFolder>> scanInstalledAddonFolders(
    String addonsPath,
  ) async {
    final payload = await Isolate.run(
      () => _scanInstalledAddonFoldersPayload(addonsPath),
    );

    return payload
        .map(
          (item) => InstalledAddonFolder(
            folderName: item['folderName'] as String,
            displayName: item['displayName'] as String,
            title: item['title'] as String,
            tocNames: (item['tocNames'] as List<dynamic>).cast<String>(),
            dependencies: (item['dependencies'] as List<dynamic>)
                .cast<String>(),
            xPartOf: item['xPartOf'] as String?,
          ),
        )
        .toList(growable: false);
  }
}

Future<List<Map<String, Object?>>> _analyzeAddonRootsPayload(
  String rootPath,
  String sourceLabel,
) async {
  final rootDirectory = Directory(rootPath);
  if (!await rootDirectory.exists()) {
    return const <Map<String, Object?>>[];
  }

  final addonRootPaths = await _collectAddonRootPaths(rootDirectory);
  final results = <Map<String, Object?>>[];

  for (final addonRoot in addonRootPaths) {
    final tocFiles = await _getDirectTocFiles(Directory(addonRoot));
    final targetFolderName = _resolveTargetFolderName(
      addonRoot,
      sourceLabel,
      tocFiles,
    );
    if (targetFolderName == null || targetFolderName.trim().isEmpty) {
      continue;
    }

    final metadata = await _parseAddonMetadata(tocFiles, targetFolderName);
    results.add(<String, Object?>{
      'sourcePath': addonRoot,
      'targetFolderName': targetFolderName,
      'title': metadata.title,
    });
  }

  return results;
}

Future<List<Map<String, Object?>>> _scanInstalledAddonFoldersPayload(
  String addonsPath,
) async {
  final addonsDirectory = Directory(addonsPath);
  if (!await addonsDirectory.exists()) {
    return const <Map<String, Object?>>[];
  }

  final folders = <Map<String, Object?>>[];
  final entities = await _safeList(addonsDirectory);

  for (final entity in entities.whereType<Directory>()) {
    final folderName = p.basename(entity.path);
    if (folderName.startsWith('Blizzard_') || folderName.startsWith('.')) {
      continue;
    }

    final tocFiles = await _getDirectTocFiles(entity);
    if (tocFiles.isEmpty) {
      continue;
    }

    final metadata = await _parseAddonMetadata(tocFiles, folderName);
    folders.add(<String, Object?>{
      'folderName': folderName,
      'displayName': metadata.title,
      'title': metadata.title,
      'tocNames': metadata.tocNames,
      'dependencies': metadata.dependencies,
      'xPartOf': metadata.xPartOf,
    });
  }

  folders.sort(
    (a, b) => (a['displayName'] as String).toLowerCase().compareTo(
      (b['displayName'] as String).toLowerCase(),
    ),
  );
  return folders;
}

Future<List<String>> _collectAddonRootPaths(Directory rootDir) async {
  final addonRoots = <String>[];

  Future<void> traverse(Directory directory) async {
    final tocFiles = await _getDirectTocFiles(directory);
    if (tocFiles.isNotEmpty) {
      addonRoots.add(directory.path);
      return;
    }

    final children = await _safeList(directory);
    for (final child in children.whereType<Directory>()) {
      final folderName = p.basename(child.path);
      if (_shouldSkipTraversalFolder(folderName)) {
        continue;
      }
      await traverse(child);
    }
  }

  await traverse(rootDir);
  return addonRoots;
}

Future<List<File>> _getDirectTocFiles(Directory directory) async {
  final entities = await _safeList(directory);
  return entities
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.toc'))
      .toList(growable: false);
}

Future<List<FileSystemEntity>> _safeList(Directory directory) async {
  try {
    return await directory.list().toList();
  } catch (_) {
    return const <FileSystemEntity>[];
  }
}

bool _shouldSkipTraversalFolder(String folderName) {
  final lower = folderName.toLowerCase();
  return _containsUnsupportedPathSegment(folderName) || lower == '__macosx';
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

String? _resolveTargetFolderName(
  String rootPath,
  String sourceLabel,
  List<File> tocFiles,
) {
  if (tocFiles.isEmpty) {
    return _sanitizeFolderName(_stripSourceExtension(sourceLabel));
  }

  final rootFolderName = p.basename(rootPath);
  final normalizedRootFolderName = _normalizeFolderKey(rootFolderName);
  final sourceBaseName = _normalizeFolderKey(
    _stripSourceExtension(sourceLabel),
  );
  final tocNames = tocFiles
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

  final matchingTocBySource = tocNames.firstWhere(
    (tocName) => _normalizeFolderKey(tocName) == sourceBaseName,
    orElse: () => '',
  );
  if (matchingTocBySource.isNotEmpty) {
    return _sanitizeFolderName(matchingTocBySource);
  }

  if (tocNames.length == 1) {
    return _sanitizeFolderName(tocNames.first);
  }

  return _sanitizeFolderName(rootFolderName);
}

Future<_TocMetadata> _parseAddonMetadata(
  List<File> tocFiles,
  String fallback,
) async {
  String displayName = fallback;
  final tocNames = tocFiles
      .map((file) => p.basenameWithoutExtension(file.path))
      .where((name) => name.trim().isNotEmpty)
      .toList(growable: false);
  final dependencies = <String>[];
  String? xPartOf;

  try {
    final preferredToc = tocFiles.firstWhere(
      (file) =>
          p.basename(file.path).toLowerCase() ==
          '${fallback.toLowerCase()}.toc',
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
    dependencies: dependencies.toSet().toList(growable: false),
    xPartOf: xPartOf,
  );
}

List<String> _parseDependencies(String rawValue) {
  return rawValue
      .split(',')
      .map((dependency) => dependency.trim())
      .where((dependency) => dependency.isNotEmpty)
      .toList(growable: false);
}

String _cleanWowTitle(String title) {
  return title
      .replaceAll(RegExp(r'\|c[0-9a-fA-F]{8}'), '')
      .replaceAll('|r', '')
      .trim();
}

String _stripSourceExtension(String fileName) {
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
