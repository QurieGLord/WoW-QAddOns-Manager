import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

enum LaunchGameFailure {
  missingExecutableName,
  executableNotFound,
  invalidClientPath,
  launchFailed,
}

class LaunchGameException implements Exception {
  final LaunchGameFailure failure;
  final String? details;

  const LaunchGameException(this.failure, {this.details});

  @override
  String toString() {
    return switch (failure) {
      LaunchGameFailure.missingExecutableName => 'MISSING_EXECUTABLE_NAME',
      LaunchGameFailure.executableNotFound => 'EXECUTABLE_NOT_FOUND',
      LaunchGameFailure.invalidClientPath => 'INVALID_CLIENT_PATH',
      LaunchGameFailure.launchFailed => details ?? 'LAUNCH_FAILED',
    };
  }
}

abstract class FileSystemService {
  Future<List<GameClient>> scanWowClients(String path);

  Future<List<InstalledAddonFolder>> scanInstalledAddonFolders(
    GameClient client,
  );

  Future<AddonInstallResult> installAddonDownload(
    String downloadUrl,
    String fileName,
    GameClient client,
  );

  Future<AddonInstallResult> importAddonArchive(
    String archivePath,
    GameClient client, {
    bool replaceExisting = false,
  });

  Future<AddonInstallResult> importAddonFolder(
    String directoryPath,
    GameClient client, {
    bool replaceExisting = false,
  });

  Future<void> deleteAddonGroup(GameClient client, InstalledAddonGroup group);

  Future<void> launchGameClient(GameClient client);
}
