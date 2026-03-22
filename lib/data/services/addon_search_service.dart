import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/features/addons/search/application/search_session_controller.dart';
import 'package:wow_qaddons_manager/features/addons/search/data/verified_addon_resolver.dart';

class AddonSearchService {
  static const int discoveryPageSize = 12;

  final SearchSessionController _sessionController;
  final VerifiedAddonResolver _verifiedResolver;

  const AddonSearchService(this._sessionController, this._verifiedResolver);

  Stream<AddonFeedState> watchSearchResults(
    String query,
    String gameVersion, {
    required String sessionKey,
    int verifiedLimit = 12,
    int concurrency = 3,
  }) {
    return _sessionController.watchSearchResults(
      sessionKey,
      query,
      gameVersion,
      verifiedLimit: verifiedLimit,
      concurrency: concurrency,
    );
  }

  Stream<AddonFeedState> watchDiscoveryFeed(
    String gameVersion, {
    required String sessionKey,
    int limit = discoveryPageSize,
    bool allowFallback = false,
    int concurrency = 3,
  }) {
    return _sessionController.watchDiscoveryFeed(
      sessionKey,
      gameVersion,
      limit: limit,
      allowFallback: allowFallback,
      concurrency: concurrency,
    );
  }

  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  ) {
    return _verifiedResolver.getDownloadInfo(
      item,
      gameVersion,
      requestContext: ProviderRequestContext(
        traceId: 'download:${item.providerName}:${item.originalId}',
        cachePolicy: CachePolicy.preferCache,
        timeout: const Duration(seconds: 15),
      ),
    );
  }

  Future<AddonItem?> verifyCandidate(AddonItem item, String gameVersion) {
    return _verifiedResolver.verifyCandidate(
      item,
      gameVersion,
      requestContext: ProviderRequestContext(
        traceId: 'verify:${item.providerName}:${item.originalId}',
        cachePolicy: CachePolicy.preferCache,
        timeout: const Duration(seconds: 15),
      ),
    );
  }
}
