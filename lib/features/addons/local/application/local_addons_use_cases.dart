import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/app/providers/service_providers.dart';
import 'package:wow_qaddons_manager/core/services/file_system_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_registry_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class LoadLocalAddonsUseCase {
  final FileSystemService _fileSystemService;
  final AddonRegistryService _registryService;

  const LoadLocalAddonsUseCase(this._fileSystemService, this._registryService);

  Future<List<InstalledAddonGroup>> call(GameClient client) async {
    final scannedFolders = await _fileSystemService.scanInstalledAddonFolders(
      client,
    );
    return _registryService.loadAddonGroups(client, scannedFolders);
  }
}

class RegisterInstalledAddonUseCase {
  final AddonRegistryService _registryService;

  const RegisterInstalledAddonUseCase(this._registryService);

  Future<void> call(
    GameClient client, {
    required AddonItem addon,
    required List<String> installedFolders,
  }) {
    return _registryService.registerInstallation(
      client,
      addon: addon,
      installedFolders: installedFolders,
    );
  }
}

class ImportLocalAddonUseCase {
  final FileSystemService _fileSystemService;
  final AddonRegistryService _registryService;

  const ImportLocalAddonUseCase(this._fileSystemService, this._registryService);

  Future<void> call(
    GameClient client, {
    required String archivePath,
    bool replaceExisting = false,
  }) async {
    final result = await _fileSystemService.importAddonArchive(
      archivePath,
      client,
      replaceExisting: replaceExisting,
    );
    final installedFolders = result.installedFolders.toList()..sort();
    final identitySeed = installedFolders.join('+');

    await _registryService.registerInstallation(
      client,
      addon: AddonItem(
        id: 'manual-$identitySeed',
        name: result.displayName,
        summary: '',
        providerName: 'Manual',
        originalId: identitySeed,
        sourceSlug: installedFolders.isEmpty ? null : installedFolders.first,
        identityHints: <String>[result.displayName, ...installedFolders],
        version: '',
      ),
      installedFolders: installedFolders,
    );
  }
}

class DeleteLocalAddonsUseCase {
  final FileSystemService _fileSystemService;
  final AddonRegistryService _registryService;

  const DeleteLocalAddonsUseCase(
    this._fileSystemService,
    this._registryService,
  );

  Future<void> call(GameClient client, List<InstalledAddonGroup> groups) async {
    for (final group in groups) {
      await _fileSystemService.deleteAddonGroup(client, group);
      await _registryService.removeGroup(client, group);
    }
  }
}

final loadLocalAddonsUseCaseProvider = Provider<LoadLocalAddonsUseCase>((ref) {
  return LoadLocalAddonsUseCase(
    ref.read(fileSystemServiceProvider),
    ref.read(addonRegistryServiceProvider),
  );
});

final registerInstalledAddonUseCaseProvider =
    Provider<RegisterInstalledAddonUseCase>((ref) {
      return RegisterInstalledAddonUseCase(
        ref.read(addonRegistryServiceProvider),
      );
    });

final importLocalAddonUseCaseProvider = Provider<ImportLocalAddonUseCase>((
  ref,
) {
  return ImportLocalAddonUseCase(
    ref.read(fileSystemServiceProvider),
    ref.read(addonRegistryServiceProvider),
  );
});

final deleteLocalAddonsUseCaseProvider = Provider<DeleteLocalAddonsUseCase>((
  ref,
) {
  return DeleteLocalAddonsUseCase(
    ref.read(fileSystemServiceProvider),
    ref.read(addonRegistryServiceProvider),
  );
});
