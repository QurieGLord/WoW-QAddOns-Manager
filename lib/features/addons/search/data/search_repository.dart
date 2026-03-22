import 'dart:async';

import 'package:dio/dio.dart';
import 'package:wow_qaddons_manager/core/services/cache_service.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/services/search_telemetry_service.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/application/elvui_resolver_service.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/provider_services.dart';

class SearchCandidate {
  final AddonItem item;
  final int rankScore;

  const SearchCandidate({required this.item, required this.rankScore});

  String get key => '${item.providerName}:${item.originalId}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'item': item.toJson(),
    'rankScore': rankScore,
  };

  factory SearchCandidate.fromJson(Map<String, dynamic> json) {
    return SearchCandidate(
      item: AddonItem.fromJson(Map<String, dynamic>.from(json['item'] as Map)),
      rankScore: json['rankScore'] as int? ?? 0,
    );
  }
}

class SearchRepository {
  static const Duration searchCacheTtl = Duration(minutes: 10);
  static const Duration discoveryCacheTtl = Duration(minutes: 30);
  static const int searchCandidateLimitPerProvider = 60;
  static const String _searchCandidateCacheNamespace =
      'search_candidate_windows_v2';
  static const String _searchCandidateInflightNamespace =
      'search_candidate_windows_inflight_v2';
  static const Duration initialSecondaryProviderBudget = Duration(
    milliseconds: 900,
  );
  static const Duration sparsePrimarySourceBudget = Duration(
    milliseconds: 2600,
  );

  final CurseForgeService _curseForgeService;
  final GitHubService _gitHubService;
  final WowskillService _wowskillService;
  final ElvUiResolverService _elvUiResolver;
  final CacheService _cacheService;
  final SearchTelemetryService _telemetryService;

  const SearchRepository(
    this._curseForgeService,
    this._gitHubService,
    this._wowskillService,
    this._elvUiResolver,
    this._cacheService,
    this._telemetryService,
  );

  Future<List<SearchCandidate>> loadSearchCandidates(
    String query,
    String gameVersion, {
    required ProviderRequestContext requestContext,
  }) async {
    final normalizedQuery = query.trim();
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedQuery.isEmpty || normalizedVersion.isEmpty) {
      return const <SearchCandidate>[];
    }

    final cacheKey = '$normalizedVersion|${normalizedQuery.toLowerCase()}';
    final cached = await _readCandidatesFromCache(
      namespace: _searchCandidateCacheNamespace,
      key: cacheKey,
      requestContext: requestContext,
    );
    if (cached != null) {
      _telemetryService.recordPhase(
        requestContext.traceId,
        'search_candidates_cache_hit',
        DateTime.now().difference(requestContext.startedAt),
        details: <String, Object?>{
          'query': normalizedQuery,
          'candidates': cached.length,
        },
      );
      return cached;
    }

    return _cacheService.coalesce(
      _searchCandidateInflightNamespace,
      cacheKey,
      () async {
        final isElvUiQuery = _elvUiResolver.isElvUiQuery(normalizedQuery);
        final elvUiItem = isElvUiQuery
            ? await _elvUiResolver.buildSearchItem(normalizedVersion)
            : null;
        final elvUiCandidate = elvUiItem == null
            ? null
            : SearchCandidate(
                item: elvUiItem,
                rankScore:
                    _scoreSearchCandidate(elvUiItem, normalizedQuery) + 1200,
              );
        final providerResults = await Future.wait<_ProviderItemsResult>(
          <Future<_ProviderItemsResult>>[
            _loadProviderItems(
              traceId: requestContext.traceId,
              phase: 'search_candidates_curseforge',
              providerName: CurseForgeProvider.staticProviderName,
              loader: () => _curseForgeService.search(
                normalizedQuery,
                gameVersion,
                requestContext: requestContext,
              ),
            ),
            _loadProviderItems(
              traceId: requestContext.traceId,
              phase: 'search_candidates_github',
              providerName: 'GitHub',
              loader: () => _gitHubService.search(
                normalizedQuery,
                gameVersion,
                requestContext: requestContext,
              ),
            ),
            _loadProviderItems(
              traceId: requestContext.traceId,
              phase: 'search_candidates_wowskill',
              providerName: 'Wowskill',
              loader: () => _wowskillService.search(
                normalizedQuery,
                gameVersion,
                requestContext: requestContext,
              ),
            ),
          ],
        );

        final merged = <String, SearchCandidate>{};
        if (elvUiCandidate != null) {
          merged[elvUiCandidate.key] = elvUiCandidate;
        }
        for (
          var providerIndex = 0;
          providerIndex < providerResults.length;
          providerIndex++
        ) {
          final items = providerResults[providerIndex].items;
          for (
            var itemIndex = 0;
            itemIndex < items.length &&
                itemIndex < searchCandidateLimitPerProvider;
            itemIndex++
          ) {
            final item = items[itemIndex];
            if (isElvUiQuery && _looksLikeGenericElvUiCoreItem(item)) {
              continue;
            }
            final candidate = SearchCandidate(
              item: item,
              rankScore:
                  _scoreSearchCandidate(item, normalizedQuery) -
                  itemIndex * 2 -
                  providerIndex * 5,
            );

            final existing = merged[candidate.key];
            if (existing == null || candidate.rankScore > existing.rankScore) {
              merged[candidate.key] = candidate;
            }
          }
        }

        final ranked = merged.values.toList()
          ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
        _telemetryService.recordPhase(
          requestContext.traceId,
          'search_candidates_ranked',
          DateTime.now().difference(requestContext.startedAt),
          details: <String, Object?>{
            'query': normalizedQuery,
            'mergedCandidates': ranked.length,
          },
        );
        await _writeCandidatesToCache(
          namespace: _searchCandidateCacheNamespace,
          key: cacheKey,
          candidates: ranked,
          ttl: searchCacheTtl,
          requestContext: requestContext,
        );
        return ranked;
      },
    );
  }

  Future<List<SearchCandidate>> loadDiscoveryCandidates(
    String gameVersion, {
    required int limit,
    required ProviderRequestContext requestContext,
  }) async {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return const <SearchCandidate>[];
    }

    final cacheKey = '$normalizedVersion|$limit';
    final cached = await _readCandidatesFromCache(
      namespace: 'discovery_candidate_windows',
      key: cacheKey,
      requestContext: requestContext,
    );
    if (cached != null) {
      _telemetryService.recordPhase(
        requestContext.traceId,
        'discovery_candidates_cache_hit',
        DateTime.now().difference(requestContext.startedAt),
        details: <String, Object?>{
          'version': normalizedVersion,
          'candidates': cached.length,
          'limit': limit,
        },
      );
      return cached;
    }

    return _cacheService.coalesce(
      'discovery_candidate_windows_inflight',
      cacheKey,
      () async {
        final merged = <String, SearchCandidate>{};
        final providerLimit = limit < 12 ? 12 : limit;
        final wowskillContext = requestContext.copyWith(
          traceId: '${requestContext.traceId}:wowskill',
          cancelToken: CancelToken(),
        );
        unawaited(
          requestContext.cancelToken.whenCancel.then((_) {
            wowskillContext.cancel('parent_cancelled');
          }),
        );

        final curseForgeFuture = _loadProviderItems(
          traceId: requestContext.traceId,
          phase: 'discovery_candidates_curseforge',
          providerName: CurseForgeProvider.staticProviderName,
          loader: () => _curseForgeService.fetchPopularAddons(
            gameVersion,
            limit: providerLimit,
            requestContext: requestContext,
          ),
        );
        final wowskillFuture = _loadProviderItems(
          traceId: requestContext.traceId,
          phase: 'discovery_candidates_wowskill',
          providerName: 'Wowskill',
          loader: () => _wowskillService.fetchPopularAddons(
            gameVersion,
            limit: providerLimit,
            requestContext: wowskillContext,
          ),
        );

        final curseForgeResult = await curseForgeFuture;
        final sparsePrimarySource = _isSparseDiscoveryYield(
          curseForgeResult.items.length,
          limit,
        );
        final secondaryBudget = sparsePrimarySource
            ? sparsePrimarySourceBudget
            : initialSecondaryProviderBudget;
        _telemetryService.recordPhase(
          requestContext.traceId,
          'discovery_primary_source_yield',
          DateTime.now().difference(requestContext.startedAt),
          details: <String, Object?>{
            'provider': CurseForgeProvider.staticProviderName,
            'items': curseForgeResult.items.length,
            'sparse': sparsePrimarySource,
            'secondaryBudgetMs': secondaryBudget.inMilliseconds,
          },
        );

        final wowskillResult = await _awaitProviderWithinBudget(
          future: wowskillFuture,
          budget: secondaryBudget,
          traceId: requestContext.traceId,
          providerName: 'Wowskill',
          phase: 'discovery_secondary_budget',
          onTimeout: () => wowskillContext.cancel('initial_budget_exhausted'),
        );

        final providerResults = <_ProviderItemsResult>[
          curseForgeResult,
          wowskillResult,
        ];

        for (
          var providerIndex = 0;
          providerIndex < providerResults.length;
          providerIndex++
        ) {
          final items = providerResults[providerIndex].items;
          for (var index = 0; index < items.length; index++) {
            final item = items[index];
            final candidate = SearchCandidate(
              item: item,
              rankScore: _scoreDiscoveryCandidate(item, providerIndex, index),
            );

            final existing = merged[candidate.key];
            if (existing == null || candidate.rankScore > existing.rankScore) {
              merged[candidate.key] = candidate;
            }
          }
        }

        final ranked = merged.values.toList()
          ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
        final discoveryWindow = _resolveDiscoveryWindowLimit(limit);
        final limitedCandidates = ranked
            .take(discoveryWindow)
            .toList(growable: false);
        final providerCounts = <String, int>{};
        for (final candidate in limitedCandidates) {
          providerCounts.update(
            candidate.item.providerName,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        _telemetryService.recordPhase(
          requestContext.traceId,
          'discovery_candidates_ranked',
          DateTime.now().difference(requestContext.startedAt),
          details: <String, Object?>{
            'version': normalizedVersion,
            'window': discoveryWindow,
            'mergedCandidates': ranked.length,
            'providerLimit': providerLimit,
            'providers': providerCounts.entries
                .map((entry) => '${entry.key}:${entry.value}')
                .join(','),
          },
        );
        await _writeCandidatesToCache(
          namespace: 'discovery_candidate_windows',
          key: cacheKey,
          candidates: limitedCandidates,
          ttl: discoveryCacheTtl,
          requestContext: requestContext,
        );
        return limitedCandidates;
      },
    );
  }

  List<String> buildDiscoveryFallbackQueries(WowVersionProfile profile) {
    if (profile.isRetailEra) {
      return const <String>[
        'details',
        'elvui',
        'auctionator',
        'deadly boss mods',
        'weakauras',
        'bagnon',
      ];
    }

    return const <String>[
      'details',
      'elvui',
      'bagnon',
      'deadly boss mods',
      'atlasloot',
      'omen',
      'questie',
    ];
  }

  Future<List<SearchCandidate>?> _readCandidatesFromCache({
    required String namespace,
    required String key,
    required ProviderRequestContext requestContext,
  }) async {
    if (requestContext.cachePolicy.readMemory) {
      final memoryCandidates = _cacheService.get<List<SearchCandidate>>(
        namespace,
        key,
      );
      if (memoryCandidates != null) {
        return memoryCandidates;
      }
    }

    if (!requestContext.cachePolicy.readDisk) {
      return null;
    }

    final json = await _cacheService.getJson(namespace, key);
    final items = json?['items'];
    if (items is! List) {
      return null;
    }

    final cachedCandidates = items
        .whereType<Map>()
        .map(
          (entry) => SearchCandidate.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);

    if (requestContext.cachePolicy.writeMemory) {
      _cacheService.set<List<SearchCandidate>>(
        namespace,
        key,
        cachedCandidates,
        ttl: namespace == 'discovery_candidate_windows'
            ? discoveryCacheTtl
            : searchCacheTtl,
      );
    }
    return cachedCandidates;
  }

  Future<void> _writeCandidatesToCache({
    required String namespace,
    required String key,
    required List<SearchCandidate> candidates,
    required Duration ttl,
    required ProviderRequestContext requestContext,
  }) async {
    if (requestContext.cachePolicy.writeMemory) {
      _cacheService.set<List<SearchCandidate>>(
        namespace,
        key,
        candidates,
        ttl: ttl,
      );
    }

    if (requestContext.cachePolicy.writeDisk) {
      await _cacheService.setJson(namespace, key, <String, dynamic>{
        'items': candidates.map((candidate) => candidate.toJson()).toList(),
      }, ttl: ttl);
    }
  }

  int _scoreSearchCandidate(AddonItem item, String query) {
    final normalizedQuery = _normalizeIdentity(query);
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final queryTokens = _tokenizeIdentity(query);
    final normalizedName = _normalizeIdentity(item.name);
    final normalizedSlug = _normalizeIdentity(item.sourceSlug ?? '');
    final normalizedSummary = _normalizeIdentity(item.summary);
    final normalizedHints = item.identityHints
        .map(_normalizeIdentity)
        .where((hint) => hint.isNotEmpty)
        .toList(growable: false);
    var score = 0;

    if (normalizedName == normalizedQuery ||
        normalizedSlug == normalizedQuery) {
      score += 260;
    } else if (normalizedName.startsWith(normalizedQuery) ||
        normalizedSlug.startsWith(normalizedQuery)) {
      score += 180;
    } else if (normalizedName.contains(normalizedQuery) ||
        normalizedSlug.contains(normalizedQuery)) {
      score += 110;
    } else if (normalizedSummary.contains(normalizedQuery)) {
      score += 40;
    }

    if (normalizedHints.any((hint) => hint == normalizedQuery)) {
      score += 220;
    } else if (normalizedHints.any((hint) => hint.contains(normalizedQuery))) {
      score += 120;
    }

    if (_matchesAllIdentityTokens(<String>[
      item.name,
      item.sourceSlug ?? '',
      item.summary,
      ...item.identityHints,
    ], queryTokens)) {
      score += 90;
    }

    if (item.providerName == CurseForgeProvider.staticProviderName) {
      score += 8;
    }

    return score;
  }

  int _scoreDiscoveryCandidate(
    AddonItem item,
    int providerIndex,
    int itemIndex,
  ) {
    var score = 500 - itemIndex * 4 - providerIndex * 15;
    if (item.providerName == CurseForgeProvider.staticProviderName) {
      score += 12;
    }
    return score;
  }

  Future<_ProviderItemsResult> _loadProviderItems({
    required String traceId,
    required String phase,
    required String providerName,
    required Future<List<AddonItem>> Function() loader,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final items = await loader();
      stopwatch.stop();
      _telemetryService.recordPhase(
        traceId,
        phase,
        stopwatch.elapsed,
        details: <String, Object?>{
          'provider': providerName,
          'items': items.length,
        },
      );
      return _ProviderItemsResult(items: items);
    } catch (error) {
      stopwatch.stop();
      _telemetryService.recordPhase(
        traceId,
        '${phase}_error',
        stopwatch.elapsed,
        details: <String, Object?>{
          'provider': providerName,
          'error': error.toString(),
        },
      );
      return const _ProviderItemsResult(items: <AddonItem>[]);
    }
  }

  int _resolveDiscoveryWindowLimit(int verifiedLimit) {
    if (verifiedLimit <= 18) {
      return 24;
    }

    return verifiedLimit + 10;
  }

  bool _isSparseDiscoveryYield(int structuredItems, int verifiedLimit) {
    final threshold = verifiedLimit <= 12 ? 4 : 6;
    return structuredItems < threshold;
  }

  Future<_ProviderItemsResult> _awaitProviderWithinBudget({
    required Future<_ProviderItemsResult> future,
    required Duration budget,
    required String traceId,
    required String providerName,
    required String phase,
    required void Function() onTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await future.timeout(budget);
      stopwatch.stop();
      _telemetryService.recordPhase(
        traceId,
        phase,
        stopwatch.elapsed,
        details: <String, Object?>{
          'provider': providerName,
          'items': result.items.length,
          'budgetMs': budget.inMilliseconds,
          'timedOut': false,
        },
      );
      return result;
    } on TimeoutException {
      stopwatch.stop();
      onTimeout();
      _telemetryService.recordPhase(
        traceId,
        '${phase}_timeout',
        stopwatch.elapsed,
        details: <String, Object?>{
          'provider': providerName,
          'budgetMs': budget.inMilliseconds,
          'timedOut': true,
        },
      );
      return const _ProviderItemsResult(items: <AddonItem>[]);
    }
  }

  String _normalizeIdentity(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  List<String> _tokenizeIdentity(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }

  bool _matchesAllIdentityTokens(List<String> haystacks, List<String> tokens) {
    if (tokens.isEmpty) {
      return false;
    }

    final normalizedHaystack = haystacks
        .map(_normalizeIdentity)
        .where((value) => value.isNotEmpty)
        .join(' ');
    return tokens.every(
      (token) => normalizedHaystack.contains(_normalizeIdentity(token)),
    );
  }

  bool _looksLikeGenericElvUiCoreItem(AddonItem item) {
    if (_elvUiResolver.isManifestBackedItem(item)) {
      return false;
    }

    final normalizedName = _normalizeIdentity(item.name);
    final normalizedSlug = _normalizeIdentity(item.sourceSlug ?? '');
    if (normalizedName == ElvUiResolverService.addonId ||
        normalizedSlug == ElvUiResolverService.addonId) {
      return true;
    }

    return item.identityHints
        .map(_normalizeIdentity)
        .where((hint) => hint.isNotEmpty)
        .any((hint) => hint == ElvUiResolverService.addonId);
  }
}

class _ProviderItemsResult {
  final List<AddonItem> items;

  const _ProviderItemsResult({required this.items});
}
