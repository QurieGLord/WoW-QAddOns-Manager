import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

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
}
