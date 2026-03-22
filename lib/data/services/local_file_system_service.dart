import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wow_qaddons_manager/core/services/cache_service.dart';
import 'package:wow_qaddons_manager/core/services/file_system_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_installer_service.dart';
import 'package:wow_qaddons_manager/data/services/wow_scanner_service.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class LocalFileSystemService implements FileSystemService {
  final WoWScannerService _scannerService;
  final AddonInstallerService _installerService;
  final CacheService _cacheService;

  const LocalFileSystemService(
    this._scannerService,
    this._installerService,
    this._cacheService,
  );

  @override
  Future<List<GameClient>> scanWowClients(String path) async {
    final normalizedPath = path.trim().toLowerCase();
    final memorySnapshot = _cacheService.get<List<GameClient>>(
      'client_scan_snapshots',
      normalizedPath,
    );
    if (memorySnapshot != null) {
      return memorySnapshot;
    }

    final diskSnapshot = await _cacheService.getJson(
      'client_scan_snapshots',
      normalizedPath,
    );
    final diskItems = diskSnapshot?['items'];
    if (diskItems is List) {
      final clients = diskItems
          .whereType<Map>()
          .map((item) => GameClient.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      _cacheService.set<List<GameClient>>(
        'client_scan_snapshots',
        normalizedPath,
        clients,
        ttl: const Duration(minutes: 10),
      );
      return clients;
    }

    return _cacheService.coalesce(
      'client_scan_snapshots_inflight',
      normalizedPath,
      () async {
        final clients = await _scannerService.scanDirectory(path);
        _cacheService.set<List<GameClient>>(
          'client_scan_snapshots',
          normalizedPath,
          clients,
          ttl: const Duration(minutes: 10),
        );
        await _cacheService.setJson(
          'client_scan_snapshots',
          normalizedPath,
          <String, dynamic>{
            'items': clients.map((client) => client.toJson()).toList(),
          },
          ttl: const Duration(minutes: 10),
        );
        return clients;
      },
    );
  }

  @override
  Future<List<InstalledAddonFolder>> scanInstalledAddonFolders(
    GameClient client,
  ) {
    return _installerService.scanInstalledFolders(client);
  }

  @override
  Future<AddonInstallResult> installAddonDownload(
    String downloadUrl,
    String fileName,
    GameClient client,
  ) {
    return _installerService.installAddon(downloadUrl, fileName, client);
  }

  @override
  Future<AddonInstallResult> importAddonArchive(
    String archivePath,
    GameClient client, {
    bool replaceExisting = false,
  }) {
    return _installerService.installFromArchive(
      archivePath,
      client,
      replaceExisting: replaceExisting,
    );
  }

  @override
  Future<AddonInstallResult> importAddonFolder(
    String directoryPath,
    GameClient client, {
    bool replaceExisting = false,
  }) {
    return _installerService.installFromDirectory(
      directoryPath,
      client,
      replaceExisting: replaceExisting,
    );
  }

  @override
  Future<void> deleteAddonGroup(GameClient client, InstalledAddonGroup group) {
    return _installerService.deleteAddon(client, group);
  }

  @override
  Future<void> launchGameClient(GameClient client) async {
    final executableName = client.executableName?.trim();
    if (executableName == null || executableName.isEmpty) {
      throw const LaunchGameException(LaunchGameFailure.missingExecutableName);
    }

    final clientDirectory = Directory(client.path);
    if (!await clientDirectory.exists()) {
      throw const LaunchGameException(LaunchGameFailure.invalidClientPath);
    }

    final executablePath = p.normalize(p.join(client.path, executableName));
    final executableFile = File(executablePath);
    if (!await executableFile.exists()) {
      throw LaunchGameException(
        LaunchGameFailure.executableNotFound,
        details: executablePath,
      );
    }

    try {
      if (Platform.isWindows) {
        await _launchWindowsClient(executablePath, client.path);
        return;
      }

      await Process.start(
        executablePath,
        const <String>[],
        workingDirectory: client.path,
        mode: ProcessStartMode.detached,
      );
    } on ProcessException catch (error) {
      throw LaunchGameException(
        LaunchGameFailure.launchFailed,
        details: error.message,
      );
    }
  }

  Future<void> _launchWindowsClient(
    String executablePath,
    String workingDirectory,
  ) async {
    String? lastError;

    for (final launcher in <Future<void> Function()>[
      () => _launchWindowsViaPowerShell(
        executablePath,
        workingDirectory,
        runAsAdmin: false,
      ),
      () => _launchWindowsViaPowerShell(
        executablePath,
        workingDirectory,
        runAsAdmin: true,
      ),
    ]) {
      try {
        await launcher();
        return;
      } on LaunchGameException catch (error) {
        lastError = error.details ?? error.toString();
      } on ProcessException catch (error) {
        lastError = error.message;
      }
    }

    throw LaunchGameException(
      LaunchGameFailure.launchFailed,
      details: lastError,
    );
  }

  Future<void> _launchWindowsViaPowerShell(
    String executablePath,
    String workingDirectory, {
    required bool runAsAdmin,
  }) async {
    final escapedExecutablePath = executablePath.replaceAll("'", "''");
    final escapedWorkingDirectory = workingDirectory.replaceAll("'", "''");
    final command = StringBuffer()
      ..write("\$ErrorActionPreference = 'Stop'; Start-Process ")
      ..write("-FilePath '$escapedExecutablePath' ")
      ..write("-WorkingDirectory '$escapedWorkingDirectory'");

    if (runAsAdmin) {
      command.write(' -Verb RunAs');
    }

    final result = await Process.run(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        command.toString(),
      ],
      runInShell: true,
      workingDirectory: workingDirectory,
    );

    if (result.exitCode != 0) {
      throw LaunchGameException(
        LaunchGameFailure.launchFailed,
        details: '${result.stderr}'.trim(),
      );
    }
  }
}
