import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';

class WoWScannerService {
  Future<List<GameClient>> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return [];
    }

    final dataDir = Directory(p.join(path, 'Data'));
    final buildInfo = File(p.join(path, '.build.info'));
    final addonsDir = Directory(p.join(path, 'Interface', 'AddOns'));

    final hasData = await dataDir.exists();
    final hasBuildInfo = await buildInfo.exists();
    final hasAddonsDir = await addonsDir.exists();

    if (!hasData && !hasBuildInfo && !hasAddonsDir) {
      throw Exception('MISSING_DATA');
    }

    final executables = await _findExecutableCandidates(dir);
    final buildEntries = await _readBuildInfoEntries(path);
    final foundClients = <GameClient>[];

    for (final executable in executables) {
      final exeName = p.basename(executable.path);

      GameClient? client = _matchBuildEntryToExecutable(path, exeName, buildEntries);
      if (client == null && Platform.isWindows) {
        client = await _scanWindowsMetadata(path, executable);
      }

      client ??= _inferClientFromName(path, exeName);
      client ??= _buildLegacyFallbackClient(path, exeName: exeName);
      foundClients.add(client);
    }

    if (foundClients.isEmpty) {
      for (final entry in buildEntries) {
        foundClients.add(_buildClientFromBuildEntry(path, entry));
      }
    }

    if (foundClients.isEmpty && (hasData || hasAddonsDir || hasBuildInfo)) {
      foundClients.add(_buildLegacyFallbackClient(path));
    }

    final deduplicated = <String, GameClient>{};
    for (final client in foundClients) {
      final key = [
        client.productCode ?? '',
        client.executableName ?? '',
        client.version,
        client.path.toLowerCase(),
      ].join('|');
      deduplicated[key] = client;
    }

    if (deduplicated.isEmpty) {
      throw Exception('MISSING_EXE');
    }

    return deduplicated.values.toList(growable: false);
  }

  Future<List<File>> _findExecutableCandidates(Directory root) async {
    final queue = <({Directory directory, int depth})>[(directory: root, depth: 0)];
    final executables = <File>[];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final entities = await current.directory.list().toList();

      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
          final name = p.basename(entity.path).toLowerCase();
          if (name.contains('wow') || name.contains('world of warcraft')) {
            executables.add(entity);
          }
          continue;
        }

        if (entity is Directory && current.depth < 2) {
          final folderName = p.basename(entity.path).toLowerCase();
          if (folderName == 'data' || folderName == 'interface' || folderName.startsWith('.')) {
            continue;
          }

          queue.add((directory: entity, depth: current.depth + 1));
        }
      }
    }

    executables.sort((a, b) => a.path.compareTo(b.path));
    return executables;
  }

  Future<List<_BuildInfoEntry>> _readBuildInfoEntries(String path) async {
    final file = File(p.join(path, '.build.info'));
    if (!await file.exists()) {
      return const <_BuildInfoEntry>[];
    }

    try {
      final lines = await file.readAsLines();
      final meaningfulLines = lines.where((line) => line.trim().isNotEmpty).toList();
      if (meaningfulLines.length < 2) {
        return const <_BuildInfoEntry>[];
      }

      final header = meaningfulLines.first.split('|').map((value) => value.trim()).toList();
      final productIndex = header.indexWhere((value) => value.contains('Product'));
      final versionIndex = header.indexWhere((value) => value.contains('Version'));
      final buildIndex = header.indexWhere((value) => value.contains('Build'));

      if (productIndex == -1 && versionIndex == -1 && buildIndex == -1) {
        return const <_BuildInfoEntry>[];
      }

      final entries = <_BuildInfoEntry>[];
      for (final line in meaningfulLines.skip(1)) {
        final columns = line.split('|');
        if (columns.isEmpty) {
          continue;
        }

        final product = _readColumn(columns, productIndex)?.toLowerCase();
        final version = _readColumn(columns, versionIndex);
        final build = _readColumn(columns, buildIndex) ?? '0';

        if (product == null || !product.startsWith('wow')) {
          continue;
        }

        entries.add(
          _BuildInfoEntry(
            product: product,
            version: version ?? 'Unknown',
            build: build,
          ),
        );
      }

      return entries;
    } catch (_) {
      return const <_BuildInfoEntry>[];
    }
  }

  String? _readColumn(List<String> columns, int index) {
    if (index < 0 || index >= columns.length) {
      return null;
    }

    final value = columns[index].trim();
    return value.isEmpty ? null : value;
  }

  GameClient? _matchBuildEntryToExecutable(
    String path,
    String exeName,
    List<_BuildInfoEntry> entries,
  ) {
    if (entries.isEmpty) {
      return null;
    }

    final exeHint = exeName.toLowerCase();
    final rankedEntries = entries.toList()
      ..sort((a, b) => _scoreBuildEntryForExecutable(b, exeHint).compareTo(_scoreBuildEntryForExecutable(a, exeHint)));

    final bestEntry = rankedEntries.first;
    return _buildClientFromBuildEntry(path, bestEntry, exeName: exeName);
  }

  int _scoreBuildEntryForExecutable(_BuildInfoEntry entry, String exeHint) {
    var score = 0;
    final product = entry.product;

    if (exeHint.contains('ptr') || exeHint.contains('xptr')) {
      if (product.contains('ptr')) {
        score += 80;
      }
    } else if (product.contains('ptr')) {
      score -= 20;
    }

    if (exeHint.contains('classic')) {
      if (product.contains('classic')) {
        score += 60;
      }
    } else if (product == 'wow') {
      score += 20;
    }

    if (exeHint.contains('era') && product.contains('era')) {
      score += 40;
    }

    if (exeHint.contains('retail') && product == 'wow') {
      score += 40;
    }

    return score;
  }

  Future<GameClient?> _scanWindowsMetadata(String rootPath, File executable) async {
    if (!await executable.exists()) {
      return null;
    }

    try {
      final exePath = executable.path;
      final exeName = p.basename(exePath);
      final filenamePointer = exePath.toNativeUtf16();
      final size = GetFileVersionInfoSize(filenamePointer, nullptr);

      if (size > 0) {
        final buffer = calloc<Uint8>(size);
        if (GetFileVersionInfo(filenamePointer, 0, size, buffer) != 0) {
          final subBlock = r'\'.toNativeUtf16();
          final valuePointer = calloc<Pointer>();
          final valueLength = calloc<Uint32>();

          if (VerQueryValue(buffer, subBlock, valuePointer, valueLength) != 0) {
            final fileInfo = valuePointer.value.cast<VS_FIXEDFILEINFO>().ref;
            final version =
                '${fileInfo.dwFileVersionMS >> 16}.'
                '${fileInfo.dwFileVersionMS & 0xFFFF}.'
                '${fileInfo.dwFileVersionLS >> 16}';
            final build = '${fileInfo.dwFileVersionLS & 0xFFFF}';
            final profile = WowVersionProfile.parse(version);

            free(filenamePointer);
            free(buffer);
            free(subBlock);
            free(valuePointer);
            free(valueLength);

            return GameClient(
              id: _buildClientId(rootPath, exeName, version),
              path: rootPath,
              version: version,
              build: build,
              type: _clientTypeFromProfile(profile),
              productCode: null,
              executableName: exeName,
              displayName: GameClient.buildDisplayName(
                version: version,
                type: _clientTypeFromProfile(profile),
                executableName: exeName,
              ),
            );
          }

          free(subBlock);
          free(valuePointer);
          free(valueLength);
        }

        free(buffer);
      }

      free(filenamePointer);
    } catch (_) {
      // Ignore Win32 metadata failures and fallback to other heuristics.
    }

    return null;
  }

  GameClient? _inferClientFromName(String path, String exeName) {
    final combinedSource = '${p.basename(path)} $exeName'.toLowerCase();
    final versionMatch = RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(combinedSource);
    var version = versionMatch?.group(1);
    if (version == null) {
      final hintedProfile = WowVersionProfile.parse(combinedSource);
      if (hintedProfile.family == WowVersionFamily.unknown) {
        return null;
      }

      version = _defaultVersionForSource(combinedSource, hintedProfile.family);
      if (version == null) {
        return null;
      }
    }

    final profile = WowVersionProfile.parse(version);
    if (profile.family == WowVersionFamily.unknown && versionMatch == null) {
      return null;
    }

    final inferredType = _clientTypeFromHints(combinedSource, profile);

    return GameClient(
      id: _buildClientId(path, exeName, version),
      path: path,
      version: version,
      build: '0',
      type: inferredType,
      productCode: null,
      executableName: exeName,
      displayName: GameClient.buildDisplayName(
        version: version,
        type: inferredType,
        executableName: exeName,
      ),
    );
  }

  GameClient _buildClientFromBuildEntry(
    String path,
    _BuildInfoEntry entry, {
    String? exeName,
  }) {
    final clientType = _clientTypeFromProduct(entry.product, entry.version);

    return GameClient(
      id: _buildClientId(path, exeName ?? entry.product, entry.version),
      path: path,
      version: entry.version,
      build: entry.build,
      type: clientType,
      productCode: entry.product,
      executableName: exeName,
      displayName: GameClient.buildDisplayName(
        version: entry.version,
        type: clientType,
        productCode: entry.product,
        executableName: exeName,
      ),
    );
  }

  GameClient _buildLegacyFallbackClient(
    String path, {
    String? exeName,
  }) {
    final source = '${p.basename(path)} ${exeName ?? ''}'.toLowerCase();
    var inferredVersion =
        RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(source)?.group(1);
    if (inferredVersion == null) {
      final hintedProfile = WowVersionProfile.parse(source);
      inferredVersion = _defaultVersionForSource(source, hintedProfile.family);
    }

    inferredVersion ??= 'Unknown';
    final profile = WowVersionProfile.parse(inferredVersion);
    final clientType = inferredVersion == 'Unknown'
        ? ClientType.legacy
        : _clientTypeFromHints(source, profile);

    return GameClient(
      id: _buildClientId(path, exeName ?? p.basename(path), inferredVersion),
      path: path,
      version: inferredVersion,
      build: '0',
      type: clientType,
      productCode: null,
      executableName: exeName,
      displayName: GameClient.buildDisplayName(
        version: inferredVersion,
        type: clientType,
        executableName: exeName,
      ),
    );
  }

  ClientType _clientTypeFromProduct(String product, String version) {
    return GameClient.inferTypeForVersion(version, productCode: product);
  }

  ClientType _clientTypeFromProfile(WowVersionProfile profile) {
    return GameClient.inferTypeForVersion(profile.exactVersion);
  }

  ClientType _clientTypeFromHints(String source, WowVersionProfile profile) {
    if (source.contains('ptr') || source.contains('xptr')) {
      return ClientType.ptr;
    }
    if (source.contains('classic') || source.contains('era') || source.contains('sod')) {
      return ClientType.classic;
    }
    if (source.contains('retail') || source.contains('live') || source.contains('mainline')) {
      return ClientType.retail;
    }
    return GameClient.inferTypeForVersion(
      profile.exactVersion,
      fallbackType: ClientType.legacy,
    );
  }

  String _buildClientId(String path, String seed, String version) {
    return '${path.toLowerCase()}|${seed.toLowerCase()}|${version.toLowerCase()}';
  }

  String? _defaultVersionForSource(String source, WowVersionFamily family) {
    return switch (family) {
      WowVersionFamily.vanilla =>
        source.contains('season of discovery') || source.contains('sod')
            ? '1.15.0'
            : source.contains('classic era') || source.contains('era')
            ? '1.14.4'
            : '1.12.1',
      WowVersionFamily.burningCrusade => source.contains('classic') ? '2.5.4' : '2.4.3',
      WowVersionFamily.wrath => source.contains('classic') ? '3.4.3' : '3.3.5',
      WowVersionFamily.cataclysm => source.contains('classic') ? '4.4.0' : '4.3.4',
      WowVersionFamily.mistsOfPandaria => '5.4.8',
      WowVersionFamily.warlordsOfDraenor => '6.2.4',
      WowVersionFamily.legion => '7.3.5',
      WowVersionFamily.battleForAzeroth => '8.3.0',
      WowVersionFamily.shadowlands => '9.2.7',
      WowVersionFamily.dragonflight => '10.2.7',
      WowVersionFamily.warWithin => '11.1.0',
      WowVersionFamily.unknown => null,
    };
  }
}

class _BuildInfoEntry {
  final String product;
  final String version;
  final String build;

  const _BuildInfoEntry({
    required this.product,
    required this.version,
    required this.build,
  });
}
