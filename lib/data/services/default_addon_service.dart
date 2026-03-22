import 'package:wow_qaddons_manager/data/services/addon_identity_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_search_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/addon_service.dart';

class DefaultAddonService implements AddonService {
  final AddonSearchService _searchService;
  final AddonIdentityService _identityService;

  const DefaultAddonService(this._searchService, this._identityService);

  @override
  Stream<AddonFeedState> watchSearchResults(
    String query,
    String gameVersion, {
    required String sessionKey,
    int verifiedLimit = 12,
    int concurrency = 3,
  }) {
    return _searchService.watchSearchResults(
      query,
      gameVersion,
      sessionKey: sessionKey,
      verifiedLimit: verifiedLimit,
      concurrency: concurrency,
    );
  }

  @override
  Stream<AddonFeedState> watchDiscoveryFeed(
    String gameVersion, {
    required String sessionKey,
    int limit = 12,
    bool allowFallback = false,
    int concurrency = 3,
  }) {
    return _searchService.watchDiscoveryFeed(
      gameVersion,
      sessionKey: sessionKey,
      limit: limit,
      allowFallback: allowFallback,
      concurrency: concurrency,
    );
  }

  @override
  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  ) {
    return _searchService.getDownloadInfo(item, gameVersion);
  }

  @override
  Future<AddonItem?> verifyCandidate(AddonItem item, String gameVersion) {
    return _searchService.verifyCandidate(item, gameVersion);
  }

  @override
  AddonInstalledMatch matchInstalledAddon(
    AddonItem item,
    List<InstalledAddonGroup> installedGroups,
  ) {
    return _identityService.matchInstalledAddon(item, installedGroups);
  }
}
