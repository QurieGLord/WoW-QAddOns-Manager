import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class AddonRootDescriptor {
  final String sourcePath;
  final String targetFolderName;
  final String title;

  const AddonRootDescriptor({
    required this.sourcePath,
    required this.targetFolderName,
    required this.title,
  });
}

abstract class BackgroundTaskService {
  Future<List<AddonRootDescriptor>> analyzeAddonRoots(
    String rootPath,
    String sourceLabel,
  );

  Future<List<InstalledAddonFolder>> scanInstalledAddonFolders(
    String addonsPath,
  );
}
