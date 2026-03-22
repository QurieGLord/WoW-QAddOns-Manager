import 'package:wow_qaddons_manager/data/services/addon_identity_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

abstract class AddonService {
  Stream<AddonFeedState> watchSearchResults(
    String query,
    String gameVersion, {
    required String sessionKey,
    int verifiedLimit = 12,
    int concurrency = 3,
  });

  Stream<AddonFeedState> watchDiscoveryFeed(
    String gameVersion, {
    required String sessionKey,
    int limit = 12,
    bool allowFallback = false,
    int concurrency = 3,
  });

  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  );

  Future<AddonItem?> verifyCandidate(AddonItem item, String gameVersion);

  AddonInstalledMatch matchInstalledAddon(
    AddonItem item,
    List<InstalledAddonGroup> installedGroups,
  );
}
