import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/data/network/wowskill_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/provider_services.dart';

class DefaultCurseForgeService implements CurseForgeService {
  final CurseForgeProvider _provider;

  const DefaultCurseForgeService(this._provider);

  @override
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.searchWithContext(
      query,
      gameVersion,
      requestContext: requestContext,
    );
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  }) {
    return _provider.fetchPopularAddonsWithContext(
      gameVersion,
      limit: limit,
      requestContext: requestContext,
    );
  }

  @override
  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.verifyCandidateWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.getDownloadUrlWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
  }
}

class DefaultGitHubService implements GitHubService {
  final GitHubProvider _provider;

  const DefaultGitHubService(this._provider);

  @override
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.searchWithContext(
      query,
      gameVersion,
      requestContext: requestContext,
    );
  }

  @override
  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.verifyCandidateWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.getDownloadUrlWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
  }
}

class DefaultWowskillService implements WowskillService {
  final WowskillProvider _provider;

  const DefaultWowskillService(this._provider);

  @override
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.searchWithContext(
      query,
      gameVersion,
      requestContext: requestContext,
    );
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  }) {
    return _provider.fetchPopularAddonsWithContext(
      gameVersion,
      limit: limit,
      requestContext: requestContext,
    );
  }

  @override
  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.verifyCandidateWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _provider.getDownloadUrlWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
  }
}
