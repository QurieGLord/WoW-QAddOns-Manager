import 'package:wow_qaddons_manager/core/services/cache_service.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/services/search_telemetry_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/application/elvui_resolver_service.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/provider_services.dart';

class VerifiedAddonResolver {
  static const Duration verifiedPayloadTtl = Duration(hours: 6);
  static const String _verifiedPayloadNamespace = 'verified_payloads_v2';
  static const String _verifiedPayloadInflightNamespace =
      'verified_payload_inflight_v2';

  final CurseForgeService _curseForgeService;
  final GitHubService _gitHubService;
  final WowskillService _wowskillService;
  final ElvUiResolverService _elvUiResolver;
  final CacheService _cacheService;
  final SearchTelemetryService _telemetryService;

  const VerifiedAddonResolver(
    this._curseForgeService,
    this._gitHubService,
    this._wowskillService,
    this._elvUiResolver,
    this._cacheService,
    this._telemetryService,
  );

  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    required ProviderRequestContext requestContext,
  }) async {
    if (item.hasVerifiedPayload) {
      return item;
    }

    final cacheKey =
        '${item.providerName}:${item.originalId}|${gameVersion.trim().toLowerCase()}';
    final cached = await _readFromCache(cacheKey, requestContext);
    if (cached != null) {
      _telemetryService.recordPhase(
        requestContext.traceId,
        'verified_payload_cache_hit',
        DateTime.now().difference(requestContext.startedAt),
        details: <String, Object?>{
          'provider': item.providerName,
          'id': item.originalId.toString(),
        },
      );
      return cached;
    }

    return _cacheService.coalesce(
      _verifiedPayloadInflightNamespace,
      cacheKey,
      () async {
        final stopwatch = Stopwatch()..start();
        final resolved = await _resolveProvider(
          item,
        ).verifyCandidate(item, gameVersion, requestContext: requestContext);
        stopwatch.stop();
        _telemetryService.recordPhase(
          requestContext.traceId,
          'verified_payload_resolve',
          stopwatch.elapsed,
          details: <String, Object?>{
            'provider': item.providerName,
            'verified': resolved != null,
            'id': item.originalId.toString(),
          },
        );
        if (resolved != null) {
          await _writeToCache(cacheKey, resolved, requestContext);
        }
        return resolved;
      },
    );
  }

  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    if (item.hasVerifiedPayload) {
      return (url: item.verifiedDownloadUrl!, fileName: item.verifiedFileName!);
    }

    final effectiveContext =
        requestContext ??
        ProviderRequestContext(
          traceId: 'download:${item.providerName}:${item.originalId}',
        );
    final verified = await verifyCandidate(
      item,
      gameVersion,
      requestContext: effectiveContext,
    );
    if (verified == null || !verified.hasVerifiedPayload) {
      return null;
    }

    return (
      url: verified.verifiedDownloadUrl!,
      fileName: verified.verifiedFileName!,
    );
  }

  Future<AddonItem?> _readFromCache(
    String cacheKey,
    ProviderRequestContext requestContext,
  ) async {
    if (requestContext.cachePolicy.readMemory) {
      final memoryItem = _cacheService.get<AddonItem>(
        _verifiedPayloadNamespace,
        cacheKey,
      );
      if (memoryItem != null) {
        return memoryItem;
      }
    }

    if (!requestContext.cachePolicy.readDisk) {
      return null;
    }

    final json = await _cacheService.getJson(
      _verifiedPayloadNamespace,
      cacheKey,
    );
    if (json == null) {
      return null;
    }

    final cachedItem = AddonItem.fromJson(json);
    if (requestContext.cachePolicy.writeMemory) {
      _cacheService.set<AddonItem>(
        _verifiedPayloadNamespace,
        cacheKey,
        cachedItem,
        ttl: verifiedPayloadTtl,
      );
    }
    return cachedItem;
  }

  Future<void> _writeToCache(
    String cacheKey,
    AddonItem item,
    ProviderRequestContext requestContext,
  ) async {
    if (requestContext.cachePolicy.writeMemory) {
      _cacheService.set<AddonItem>(
        _verifiedPayloadNamespace,
        cacheKey,
        item,
        ttl: verifiedPayloadTtl,
      );
    }

    if (requestContext.cachePolicy.writeDisk) {
      await _cacheService.setJson(
        _verifiedPayloadNamespace,
        cacheKey,
        item.toJson(),
        ttl: verifiedPayloadTtl,
      );
    }
  }

  dynamic _resolveProvider(AddonItem item) {
    if (_elvUiResolver.isManifestBackedItem(item)) {
      return _ElvUiVerifierAdapter(_elvUiResolver);
    }
    if (item.providerName == 'CurseForge') {
      return _curseForgeService;
    }
    if (item.providerName == 'Wowskill') {
      return _wowskillService;
    }
    return _gitHubService;
  }
}

class _ElvUiVerifierAdapter {
  final ElvUiResolverService _resolver;

  const _ElvUiVerifierAdapter(this._resolver);

  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    return _resolver.verifyCandidate(item, gameVersion);
  }
}
