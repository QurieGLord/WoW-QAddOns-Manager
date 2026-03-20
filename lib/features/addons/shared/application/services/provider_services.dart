import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

abstract class CurseForgeService {
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });

  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  });

  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });

  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });
}

abstract class GitHubService {
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });

  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });

  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });
}

abstract class WowskillService {
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });

  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  });

  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });

  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  });
}
