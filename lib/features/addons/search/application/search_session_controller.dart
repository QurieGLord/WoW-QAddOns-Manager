import 'dart:async';

import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/services/search_telemetry_service.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/features/addons/search/data/search_repository.dart';
import 'package:wow_qaddons_manager/features/addons/search/data/verified_addon_resolver.dart';

class SearchSessionController {
  static const int searchVerifiedLimit = 12;
  static const int searchVerificationConcurrency = 3;
  static const int discoveryVerificationConcurrency = 3;
  static const int slowProviderInitialDiscoveryBudget = 4;
  static const Duration searchDebounce = Duration(milliseconds: 280);

  final SearchRepository _searchRepository;
  final VerifiedAddonResolver _verifiedResolver;
  final SearchTelemetryService _telemetryService;
  final Map<String, _ActiveSearchSession> _activeSessions =
      <String, _ActiveSearchSession>{};

  SearchSessionController(
    this._searchRepository,
    this._verifiedResolver,
    this._telemetryService,
  );

  Stream<AddonFeedState> watchSearchResults(
    String sessionKey,
    String query,
    String gameVersion, {
    int verifiedLimit = searchVerifiedLimit,
    int concurrency = searchVerificationConcurrency,
  }) {
    final normalizedQuery = query.trim();
    final normalizedVersion = gameVersion.trim();
    if (normalizedQuery.isEmpty || normalizedVersion.isEmpty) {
      return Stream<AddonFeedState>.value(
        AddonFeedState(targetCount: verifiedLimit),
      );
    }

    final requestContext = _openSession(
      'search:$sessionKey',
      timeout: const Duration(seconds: 18),
    );
    final sessionStopwatch = Stopwatch()..start();
    _telemetryService.startSession(
      traceId: requestContext.traceId,
      kind: 'search',
      gameVersion: normalizedVersion,
      query: normalizedQuery,
      targetCount: verifiedLimit,
    );
    final controller = StreamController<AddonFeedState>();
    controller.onCancel = () => requestContext.cancel('listener_cancelled');

    () async {
      Object? sessionError;
      try {
        await Future<void>.delayed(searchDebounce);
        if (requestContext.isCancelled) {
          return;
        }

        final candidates = await _searchRepository.loadSearchCandidates(
          normalizedQuery,
          normalizedVersion,
          requestContext: requestContext,
        );
        if (requestContext.isCancelled) {
          return;
        }

        await _verifyCandidatesProgressively(
          controller: controller,
          candidates: candidates,
          deferredCandidates: const <SearchCandidate>[],
          gameVersion: normalizedVersion,
          verifiedLimit: verifiedLimit,
          concurrency: concurrency,
          allowFallback: false,
          requestContext: requestContext,
          sessionStopwatch: sessionStopwatch,
          loadMoreAvailableHint: false,
        );
      } catch (error, stackTrace) {
        sessionError = error;
        if (!requestContext.isCancelled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        sessionStopwatch.stop();
        _telemetryService.finishSession(
          requestContext.traceId,
          sessionStopwatch.elapsed,
          error: sessionError,
        );
        _closeSession('search:$sessionKey', requestContext);
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  Stream<AddonFeedState> watchDiscoveryFeed(
    String sessionKey,
    String gameVersion, {
    int limit = 12,
    bool allowFallback = false,
    int concurrency = discoveryVerificationConcurrency,
  }) {
    final normalizedVersion = gameVersion.trim();
    if (normalizedVersion.isEmpty) {
      return Stream<AddonFeedState>.value(AddonFeedState(targetCount: limit));
    }

    final requestContext = _openSession(
      'discovery:$sessionKey',
      timeout: const Duration(seconds: 20),
    );
    final sessionStopwatch = Stopwatch()..start();
    _telemetryService.startSession(
      traceId: requestContext.traceId,
      kind: 'discovery',
      gameVersion: normalizedVersion,
      targetCount: limit,
    );
    final controller = StreamController<AddonFeedState>();
    controller.onCancel = () => requestContext.cancel('listener_cancelled');

    () async {
      Object? sessionError;
      try {
        final candidates = await _searchRepository.loadDiscoveryCandidates(
          normalizedVersion,
          limit: _resolveDiscoveryCandidateWindow(limit),
          requestContext: requestContext,
        );
        if (requestContext.isCancelled) {
          return;
        }

        final candidatePlan = _buildDiscoveryCandidatePlan(
          candidates,
          allowFallback: allowFallback,
        );
        _telemetryService.recordPhase(
          requestContext.traceId,
          'discovery_candidate_plan',
          sessionStopwatch.elapsed,
          details: <String, Object?>{
            'primary': candidatePlan.primaryCandidates.length,
            'deferred': candidatePlan.deferredCandidates.length,
            'primaryProviders': _formatProviderCounts(
              candidatePlan.primaryCounts,
            ),
            'deferredProviders': _formatProviderCounts(
              candidatePlan.deferredCounts,
            ),
            'slowProviderBudget': candidatePlan.slowProviderBudget,
            'sparseStructuredPrimary': candidatePlan.sparseStructuredPrimary,
          },
        );

        await _verifyCandidatesProgressively(
          controller: controller,
          candidates: candidatePlan.primaryCandidates,
          deferredCandidates: candidatePlan.deferredCandidates,
          gameVersion: normalizedVersion,
          verifiedLimit: limit,
          concurrency: concurrency,
          allowFallback: allowFallback,
          requestContext: requestContext,
          sessionStopwatch: sessionStopwatch,
          loadMoreAvailableHint:
              candidatePlan.deferredCandidates.isNotEmpty ||
              !allowFallback ||
              candidates.length > limit,
        );
      } catch (error, stackTrace) {
        sessionError = error;
        if (!requestContext.isCancelled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        sessionStopwatch.stop();
        _telemetryService.finishSession(
          requestContext.traceId,
          sessionStopwatch.elapsed,
          error: sessionError,
        );
        _closeSession('discovery:$sessionKey', requestContext);
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  ProviderRequestContext _openSession(String key, {required Duration timeout}) {
    final existing = _activeSessions.remove(key);
    existing?.context.cancel('superseded');

    final context = ProviderRequestContext(
      traceId: '$key:${DateTime.now().microsecondsSinceEpoch}',
      cachePolicy: CachePolicy.preferCache,
      timeout: timeout,
    );
    _activeSessions[key] = _ActiveSearchSession(context);
    return context;
  }

  void _closeSession(String key, ProviderRequestContext context) {
    final existing = _activeSessions[key];
    if (existing != null && identical(existing.context, context)) {
      _activeSessions.remove(key);
    }
  }

  Future<void> _verifyCandidatesProgressively({
    required StreamController<AddonFeedState> controller,
    required List<SearchCandidate> candidates,
    required List<SearchCandidate> deferredCandidates,
    required String gameVersion,
    required int verifiedLimit,
    required int concurrency,
    required bool allowFallback,
    required ProviderRequestContext requestContext,
    required Stopwatch sessionStopwatch,
    required bool loadMoreAvailableHint,
  }) async {
    final verifiedByKey = <String, AddonItem>{};
    final rankByKey = <String, int>{
      for (final candidate in candidates) candidate.key: candidate.rankScore,
    };
    final seenKeys = <String>{...rankByKey.keys};
    var checkedCandidates = 0;
    var totalCandidates = candidates.length;
    String? lastSignature;

    lastSignature = _emitStateIfNeeded(
      controller,
      _buildFeedState(
        verifiedByKey: verifiedByKey,
        rankByKey: rankByKey,
        checkedCandidates: checkedCandidates,
        totalCandidates: totalCandidates,
        verifiedLimit: verifiedLimit,
        loadingPhase: AddonFeedLoadingPhase.initial,
        canLoadMore: loadMoreAvailableHint,
      ),
      lastSignature,
      traceId: requestContext.traceId,
      sessionStopwatch: sessionStopwatch,
    );

    final primaryProgress = await _verifySequence(
      controller: controller,
      candidates: candidates,
      gameVersion: gameVersion,
      verifiedLimit: verifiedLimit,
      concurrency: concurrency,
      verifiedByKey: verifiedByKey,
      rankByKey: rankByKey,
      checkedCandidates: checkedCandidates,
      totalCandidates: totalCandidates,
      requestContext: requestContext,
      lastSignature: lastSignature,
      loadingPhase: AddonFeedLoadingPhase.initial,
      sessionStopwatch: sessionStopwatch,
      canLoadMore: loadMoreAvailableHint,
    );

    checkedCandidates = primaryProgress.checkedCandidates;
    totalCandidates = primaryProgress.totalCandidates;
    lastSignature = primaryProgress.lastSignature;

    if (allowFallback &&
        deferredCandidates.isNotEmpty &&
        verifiedByKey.length < verifiedLimit) {
      totalCandidates += deferredCandidates.length;
      _telemetryService.recordPhase(
        requestContext.traceId,
        'deferred_candidates_appended',
        sessionStopwatch.elapsed,
        details: <String, Object?>{
          'newCandidates': deferredCandidates.length,
          'providers': _formatProviderCounts(
            _countProviders(deferredCandidates),
          ),
        },
      );
      final deferredProgress = await _verifySequence(
        controller: controller,
        candidates: deferredCandidates,
        gameVersion: gameVersion,
        verifiedLimit: verifiedLimit,
        concurrency: concurrency,
        verifiedByKey: verifiedByKey,
        rankByKey: rankByKey,
        checkedCandidates: checkedCandidates,
        totalCandidates: totalCandidates,
        requestContext: requestContext,
        lastSignature: lastSignature,
        loadingPhase: AddonFeedLoadingPhase.paginating,
        sessionStopwatch: sessionStopwatch,
        canLoadMore: true,
      );

      checkedCandidates = deferredProgress.checkedCandidates;
      totalCandidates = deferredProgress.totalCandidates;
      lastSignature = deferredProgress.lastSignature;
    }

    if (allowFallback && verifiedByKey.length < verifiedLimit) {
      final fallbackQueries = _searchRepository.buildDiscoveryFallbackQueries(
        WowVersionProfile.parse(gameVersion),
      );

      for (
        var queryIndex = 0;
        queryIndex < fallbackQueries.length &&
            verifiedByKey.length < verifiedLimit;
        queryIndex++
      ) {
        if (requestContext.isCancelled) {
          return;
        }

        final fallbackCandidates = await _searchRepository.loadSearchCandidates(
          fallbackQueries[queryIndex],
          gameVersion,
          requestContext: requestContext.copyWith(
            traceId: '${requestContext.traceId}:fallback:$queryIndex',
          ),
        );

        final newCandidates = <SearchCandidate>[];
        for (final candidate in fallbackCandidates) {
          if (!seenKeys.add(candidate.key)) {
            continue;
          }

          final adjustedScore = candidate.rankScore - queryIndex * 20;
          rankByKey[candidate.key] = adjustedScore;
          newCandidates.add(
            SearchCandidate(item: candidate.item, rankScore: adjustedScore),
          );
        }

        if (newCandidates.isEmpty) {
          continue;
        }

        totalCandidates += newCandidates.length;
        _telemetryService.recordPhase(
          requestContext.traceId,
          'fallback_candidates_appended',
          sessionStopwatch.elapsed,
          details: <String, Object?>{
            'query': fallbackQueries[queryIndex],
            'newCandidates': newCandidates.length,
          },
        );
        final fallbackProgress = await _verifySequence(
          controller: controller,
          candidates: newCandidates,
          gameVersion: gameVersion,
          verifiedLimit: verifiedLimit,
          concurrency: concurrency,
          verifiedByKey: verifiedByKey,
          rankByKey: rankByKey,
          checkedCandidates: checkedCandidates,
          totalCandidates: totalCandidates,
          requestContext: requestContext,
          lastSignature: lastSignature,
          loadingPhase: AddonFeedLoadingPhase.paginating,
          sessionStopwatch: sessionStopwatch,
          canLoadMore: true,
        );

        checkedCandidates = fallbackProgress.checkedCandidates;
        totalCandidates = fallbackProgress.totalCandidates;
        lastSignature = fallbackProgress.lastSignature;
      }
    }

    final hasUncheckedCandidates = checkedCandidates < totalCandidates;
    final canLoadMore = hasUncheckedCandidates || !allowFallback;
    _emitStateIfNeeded(
      controller,
      _buildFeedState(
        verifiedByKey: verifiedByKey,
        rankByKey: rankByKey,
        checkedCandidates: checkedCandidates,
        totalCandidates: totalCandidates,
        verifiedLimit: verifiedLimit,
        loadingPhase: AddonFeedLoadingPhase.idle,
        canLoadMore: canLoadMore,
      ),
      lastSignature,
      traceId: requestContext.traceId,
      sessionStopwatch: sessionStopwatch,
    );
  }

  Future<_VerificationProgress> _verifySequence({
    required StreamController<AddonFeedState> controller,
    required List<SearchCandidate> candidates,
    required String gameVersion,
    required int verifiedLimit,
    required int concurrency,
    required Map<String, AddonItem> verifiedByKey,
    required Map<String, int> rankByKey,
    required int checkedCandidates,
    required int totalCandidates,
    required ProviderRequestContext requestContext,
    required String? lastSignature,
    required AddonFeedLoadingPhase loadingPhase,
    required Stopwatch sessionStopwatch,
    required bool canLoadMore,
  }) async {
    if (candidates.isEmpty) {
      return _VerificationProgress(
        checkedCandidates: checkedCandidates,
        totalCandidates: totalCandidates,
        lastSignature: lastSignature,
      );
    }

    for (
      var chunkStart = 0;
      chunkStart < candidates.length && verifiedByKey.length < verifiedLimit;
      chunkStart += concurrency
    ) {
      if (requestContext.isCancelled) {
        break;
      }

      final chunkEnd = chunkStart + concurrency > candidates.length
          ? candidates.length
          : chunkStart + concurrency;
      final candidateChunk = candidates.sublist(chunkStart, chunkEnd);
      final chunkStopwatch = Stopwatch()..start();
      final verifiedChunk = await Future.wait(
        candidateChunk.map(
          (candidate) => _verifiedResolver.verifyCandidate(
            candidate.item,
            gameVersion,
            requestContext: requestContext,
          ),
        ),
      );
      chunkStopwatch.stop();

      final previousVerifiedCount = verifiedByKey.length;
      checkedCandidates += candidateChunk.length;

      for (var index = 0; index < candidateChunk.length; index++) {
        final verifiedItem = verifiedChunk[index];
        if (verifiedItem == null) {
          continue;
        }

        verifiedByKey[candidateChunk[index].key] = verifiedItem;
      }

      _telemetryService.recordPhase(
        requestContext.traceId,
        'verification_chunk',
        chunkStopwatch.elapsed,
        details: <String, Object?>{
          'checked': checkedCandidates,
          'chunkSize': candidateChunk.length,
          'verified': verifiedByKey.length,
          'target': verifiedLimit,
        },
      );

      if (verifiedByKey.length > previousVerifiedCount) {
        lastSignature = _emitStateIfNeeded(
          controller,
          _buildFeedState(
            verifiedByKey: verifiedByKey,
            rankByKey: rankByKey,
            checkedCandidates: checkedCandidates,
            totalCandidates: totalCandidates,
            verifiedLimit: verifiedLimit,
            loadingPhase: loadingPhase,
            canLoadMore: canLoadMore,
          ),
          lastSignature,
          traceId: requestContext.traceId,
          sessionStopwatch: sessionStopwatch,
        );
      }
    }

    return _VerificationProgress(
      checkedCandidates: checkedCandidates,
      totalCandidates: totalCandidates,
      lastSignature: lastSignature,
    );
  }

  AddonFeedState _buildFeedState({
    required Map<String, AddonItem> verifiedByKey,
    required Map<String, int> rankByKey,
    required int checkedCandidates,
    required int totalCandidates,
    required int verifiedLimit,
    required AddonFeedLoadingPhase loadingPhase,
    required bool canLoadMore,
  }) {
    return AddonFeedState(
      items: _sortVerifiedItems(verifiedByKey, rankByKey, verifiedLimit),
      loadingPhase: loadingPhase,
      canLoadMore: canLoadMore,
      checkedCandidates: checkedCandidates,
      totalCandidates: totalCandidates,
      targetCount: verifiedLimit,
    );
  }

  List<AddonItem> _sortVerifiedItems(
    Map<String, AddonItem> verifiedByKey,
    Map<String, int> rankByKey,
    int limit,
  ) {
    final entries = verifiedByKey.entries.toList()
      ..sort((a, b) {
        final rankComparison = (rankByKey[b.key] ?? 0).compareTo(
          rankByKey[a.key] ?? 0,
        );
        if (rankComparison != 0) {
          return rankComparison;
        }

        return a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase());
      });

    return entries
        .take(limit)
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  String? _emitStateIfNeeded(
    StreamController<AddonFeedState> controller,
    AddonFeedState state,
    String? previousSignature, {
    required String traceId,
    required Stopwatch sessionStopwatch,
  }) {
    if (controller.isClosed) {
      return previousSignature;
    }

    final signature = _buildStateSignature(state);
    if (signature == previousSignature) {
      return previousSignature;
    }

    controller.add(state);
    _telemetryService.recordStateEmission(
      traceId,
      state,
      sessionStopwatch.elapsed,
    );
    return signature;
  }

  String _buildStateSignature(AddonFeedState state) {
    final itemsSignature = state.items
        .map((item) => '${item.providerName}:${item.originalId}')
        .join('|');
    return '${state.loadingPhase.name}|${state.canLoadMore}|${state.targetCount}|$itemsSignature';
  }

  int _resolveDiscoveryCandidateWindow(int verifiedLimit) {
    if (verifiedLimit <= 12) {
      return 18;
    }

    return verifiedLimit + 10;
  }

  _DiscoveryCandidatePlan _buildDiscoveryCandidatePlan(
    List<SearchCandidate> candidates, {
    required bool allowFallback,
  }) {
    final providerCounts = _countProviders(candidates);
    if (allowFallback || candidates.isEmpty) {
      return _DiscoveryCandidatePlan(
        primaryCandidates: candidates,
        deferredCandidates: const <SearchCandidate>[],
        primaryCounts: providerCounts,
        deferredCounts: const <String, int>{},
        slowProviderBudget: slowProviderInitialDiscoveryBudget,
        sparseStructuredPrimary: false,
      );
    }

    final sparseStructuredPrimary = _isStructuredPrimarySparse(providerCounts);
    final effectiveSlowBudget = _resolveSlowProviderBudget(
      providerCounts,
      sparseStructuredPrimary: sparseStructuredPrimary,
    );
    final primaryCandidates = <SearchCandidate>[];
    final deferredCandidates = <SearchCandidate>[];
    final slowProviderUsage = <String, int>{};

    for (final candidate in candidates) {
      if (_isSlowDiscoveryProvider(candidate.item.providerName)) {
        final currentUsage =
            slowProviderUsage[candidate.item.providerName] ?? 0;
        if (currentUsage >= effectiveSlowBudget) {
          deferredCandidates.add(candidate);
          continue;
        }
        slowProviderUsage[candidate.item.providerName] = currentUsage + 1;
      }

      primaryCandidates.add(candidate);
    }

    return _DiscoveryCandidatePlan(
      primaryCandidates: primaryCandidates,
      deferredCandidates: deferredCandidates,
      primaryCounts: _countProviders(primaryCandidates),
      deferredCounts: _countProviders(deferredCandidates),
      slowProviderBudget: effectiveSlowBudget,
      sparseStructuredPrimary: sparseStructuredPrimary,
    );
  }

  Map<String, int> _countProviders(List<SearchCandidate> candidates) {
    final counts = <String, int>{};
    for (final candidate in candidates) {
      counts.update(
        candidate.item.providerName,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  String _formatProviderCounts(Map<String, int> counts) {
    if (counts.isEmpty) {
      return 'none';
    }

    return counts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
  }

  bool _isSlowDiscoveryProvider(String providerName) {
    return providerName == 'Wowskill';
  }

  bool _isStructuredPrimarySparse(Map<String, int> providerCounts) {
    final curseForgeCount = providerCounts['CurseForge'] ?? 0;
    return curseForgeCount < 4;
  }

  int _resolveSlowProviderBudget(
    Map<String, int> providerCounts, {
    required bool sparseStructuredPrimary,
  }) {
    if (!sparseStructuredPrimary) {
      return slowProviderInitialDiscoveryBudget;
    }

    final wowskillCount = providerCounts['Wowskill'] ?? 0;
    if (wowskillCount <= slowProviderInitialDiscoveryBudget) {
      return wowskillCount;
    }

    return wowskillCount >= 8 ? 8 : wowskillCount;
  }
}

class _ActiveSearchSession {
  final ProviderRequestContext context;

  const _ActiveSearchSession(this.context);
}

class _VerificationProgress {
  final int checkedCandidates;
  final int totalCandidates;
  final String? lastSignature;

  const _VerificationProgress({
    required this.checkedCandidates,
    required this.totalCandidates,
    required this.lastSignature,
  });
}

class _DiscoveryCandidatePlan {
  final List<SearchCandidate> primaryCandidates;
  final List<SearchCandidate> deferredCandidates;
  final Map<String, int> primaryCounts;
  final Map<String, int> deferredCounts;
  final int slowProviderBudget;
  final bool sparseStructuredPrimary;

  const _DiscoveryCandidatePlan({
    required this.primaryCandidates,
    required this.deferredCandidates,
    required this.primaryCounts,
    required this.deferredCounts,
    required this.slowProviderBudget,
    required this.sparseStructuredPrimary,
  });
}
