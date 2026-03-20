import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/app/providers/service_providers.dart';
import 'package:wow_qaddons_manager/core/services/file_system_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_registry_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/features/addons/local/application/local_addons_use_cases.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/addon_service.dart';

class SearchAddonsUseCase {
  final AddonService _addonService;

  const SearchAddonsUseCase(this._addonService);

  Stream<AddonFeedState> call(
    String query, {
    required String gameVersion,
    required String sessionKey,
  }) {
    return _addonService.watchSearchResults(
      query,
      gameVersion,
      sessionKey: sessionKey,
    );
  }
}

class LoadDiscoveryFeedUseCase {
  final AddonService _addonService;

  const LoadDiscoveryFeedUseCase(this._addonService);

  Stream<AddonFeedState> call(
    String gameVersion, {
    required String sessionKey,
    int limit = 12,
    bool allowFallback = false,
  }) {
    return _addonService.watchDiscoveryFeed(
      gameVersion,
      sessionKey: sessionKey,
      limit: limit,
      allowFallback: allowFallback,
    );
  }
}

class VerifyAddonCandidateUseCase {
  final AddonService _addonService;

  const VerifyAddonCandidateUseCase(this._addonService);

  Future<({String url, String fileName})?> call(
    AddonItem item,
    String gameVersion,
  ) {
    return _addonService.getDownloadInfo(item, gameVersion);
  }
}

enum InstallAddonStatus { success, alreadyInstalled, versionNotFound, failure }

class InstallAddonResult {
  final InstallAddonStatus status;
  final List<String> installedFolders;
  final Object? error;

  const InstallAddonResult._({
    required this.status,
    this.installedFolders = const <String>[],
    this.error,
  });

  const InstallAddonResult.success(List<String> installedFolders)
    : this._(
        status: InstallAddonStatus.success,
        installedFolders: installedFolders,
      );

  const InstallAddonResult.alreadyInstalled()
    : this._(status: InstallAddonStatus.alreadyInstalled);

  const InstallAddonResult.versionNotFound()
    : this._(status: InstallAddonStatus.versionNotFound);

  const InstallAddonResult.failure(Object error)
    : this._(status: InstallAddonStatus.failure, error: error);

  bool get isSuccess => status == InstallAddonStatus.success;
}

class InstallAddonUseCase {
  final AddonService _addonService;
  final FileSystemService _fileSystemService;
  final AddonRegistryService _registryService;
  final LoadLocalAddonsUseCase _loadLocalAddonsUseCase;

  const InstallAddonUseCase(
    this._addonService,
    this._fileSystemService,
    this._registryService,
    this._loadLocalAddonsUseCase,
  );

  Future<InstallAddonResult> call({
    required AddonItem addon,
    required GameClient client,
  }) async {
    final info = await _addonService.getDownloadInfo(addon, client.version);
    if (info == null) {
      return const InstallAddonResult.versionNotFound();
    }

    final installedGroups = await _loadLocalAddonsUseCase(client);
    final duplicateMatch = _addonService.matchInstalledAddon(
      addon,
      installedGroups,
    );
    if (duplicateMatch.isInstalled) {
      return const InstallAddonResult.alreadyInstalled();
    }

    try {
      final result = await _fileSystemService.installAddonDownload(
        info.url,
        info.fileName,
        client,
      );
      await _registryService.registerInstallation(
        client,
        addon: addon,
        installedFolders: result.installedFolders,
      );
      return InstallAddonResult.success(result.installedFolders);
    } catch (error) {
      if ('$error'.contains('ALREADY_INSTALLED')) {
        return const InstallAddonResult.alreadyInstalled();
      }
      return InstallAddonResult.failure(error);
    }
  }
}

final searchAddonsUseCaseProvider = Provider<SearchAddonsUseCase>((ref) {
  return SearchAddonsUseCase(ref.read(addonServiceProvider));
});

final loadDiscoveryFeedUseCaseProvider = Provider<LoadDiscoveryFeedUseCase>((
  ref,
) {
  return LoadDiscoveryFeedUseCase(ref.read(addonServiceProvider));
});

final verifyAddonCandidateUseCaseProvider =
    Provider<VerifyAddonCandidateUseCase>((ref) {
      return VerifyAddonCandidateUseCase(ref.read(addonServiceProvider));
    });

final installAddonUseCaseProvider = Provider<InstallAddonUseCase>((ref) {
  return InstallAddonUseCase(
    ref.read(addonServiceProvider),
    ref.read(fileSystemServiceProvider),
    ref.read(addonRegistryServiceProvider),
    ref.read(loadLocalAddonsUseCaseProvider),
  );
});
