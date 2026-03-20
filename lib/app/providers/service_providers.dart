import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/core/services/background_task_service.dart';
import 'package:wow_qaddons_manager/core/services/cache_service.dart';
import 'package:wow_qaddons_manager/core/services/file_system_service.dart';
import 'package:wow_qaddons_manager/core/services/search_telemetry_service.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_client.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/data/network/default_provider_services.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/data/network/wowskill_provider.dart';
import 'package:wow_qaddons_manager/data/repositories/client_repository.dart';
import 'package:wow_qaddons_manager/data/services/addon_identity_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_installer_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_registry_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_search_service.dart';
import 'package:wow_qaddons_manager/data/services/default_addon_service.dart';
import 'package:wow_qaddons_manager/data/services/hybrid_cache_service.dart';
import 'package:wow_qaddons_manager/data/services/local_file_system_service.dart';
import 'package:wow_qaddons_manager/data/services/local_background_task_service.dart';
import 'package:wow_qaddons_manager/data/services/wow_scanner_service.dart';
import 'package:wow_qaddons_manager/features/addons/search/application/search_session_controller.dart';
import 'package:wow_qaddons_manager/features/addons/search/data/search_repository.dart';
import 'package:wow_qaddons_manager/features/addons/search/data/verified_addon_resolver.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/addon_service.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/provider_services.dart';

final scannerServiceProvider = Provider<WoWScannerService>((ref) {
  return WoWScannerService();
});

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository();
});

final curseForgeClientProvider = Provider<CurseForgeClient>((ref) {
  return CurseForgeClient();
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return HybridCacheService();
});

final searchTelemetryServiceProvider = Provider<SearchTelemetryService>((ref) {
  return SearchTelemetryService();
});

final backgroundTaskServiceProvider = Provider<BackgroundTaskService>((ref) {
  return LocalBackgroundTaskService();
});

final curseForgeProviderAdapterProvider = Provider<CurseForgeProvider>((ref) {
  return CurseForgeProvider(ref.read(curseForgeClientProvider));
});

final githubProviderAdapterProvider = Provider<GitHubProvider>((ref) {
  return GitHubProvider();
});

final wowskillProviderAdapterProvider = Provider<WowskillProvider>((ref) {
  return WowskillProvider();
});

final curseForgeServiceProvider = Provider<CurseForgeService>((ref) {
  return DefaultCurseForgeService(ref.read(curseForgeProviderAdapterProvider));
});

final githubServiceProvider = Provider<GitHubService>((ref) {
  return DefaultGitHubService(ref.read(githubProviderAdapterProvider));
});

final wowskillServiceProvider = Provider<WowskillService>((ref) {
  return DefaultWowskillService(ref.read(wowskillProviderAdapterProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(
    ref.read(curseForgeServiceProvider),
    ref.read(githubServiceProvider),
    ref.read(wowskillServiceProvider),
    ref.read(cacheServiceProvider),
    ref.read(searchTelemetryServiceProvider),
  );
});

final verifiedAddonResolverProvider = Provider<VerifiedAddonResolver>((ref) {
  return VerifiedAddonResolver(
    ref.read(curseForgeServiceProvider),
    ref.read(githubServiceProvider),
    ref.read(wowskillServiceProvider),
    ref.read(cacheServiceProvider),
    ref.read(searchTelemetryServiceProvider),
  );
});

final searchSessionControllerProvider = Provider<SearchSessionController>((
  ref,
) {
  return SearchSessionController(
    ref.read(searchRepositoryProvider),
    ref.read(verifiedAddonResolverProvider),
    ref.read(searchTelemetryServiceProvider),
  );
});

final addonSearchServiceProvider = Provider<AddonSearchService>((ref) {
  return AddonSearchService(
    ref.read(searchSessionControllerProvider),
    ref.read(verifiedAddonResolverProvider),
  );
});

final addonInstallerServiceProvider = Provider<AddonInstallerService>((ref) {
  return AddonInstallerService(ref.read(backgroundTaskServiceProvider));
});

final addonIdentityServiceProvider = Provider<AddonIdentityService>((ref) {
  return AddonIdentityService();
});

final addonRegistryServiceProvider = Provider<AddonRegistryService>((ref) {
  return AddonRegistryService();
});

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return LocalFileSystemService(
    ref.read(scannerServiceProvider),
    ref.read(addonInstallerServiceProvider),
    ref.read(cacheServiceProvider),
  );
});

final addonServiceProvider = Provider<AddonService>((ref) {
  return DefaultAddonService(
    ref.read(addonSearchServiceProvider),
    ref.read(addonIdentityServiceProvider),
  );
});
