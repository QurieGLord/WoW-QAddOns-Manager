import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class AddonSearchService {
  static const int _searchVerifiedLimit = 12;
  static const int _searchCandidateLimitPerProvider = 40;
  static const int _searchVerificationConcurrency = 4;

  static const int _discoveryVerifiedLimit = 50;
  static const int _discoveryCandidateLimitPerProvider = 50;
  static const int _discoveryVerificationConcurrency = 4;
  static const int _discoveryVerificationBatchSize = 20;

  final List<IAddonProvider> _providers;
  final Map<String, AddonFeedState> _searchResultCache =
      <String, AddonFeedState>{};
  final Map<String, AddonFeedState> _discoveryResultCache =
      <String, AddonFeedState>{};
  final Map<String, Future<List<_CandidateEntry>>> _searchCandidateCache =
      <String, Future<List<_CandidateEntry>>>{};
  final Map<String, Future<List<_CandidateEntry>>> _discoveryCandidateCache =
      <String, Future<List<_CandidateEntry>>>{};
  final Map<String, Future<AddonItem?>> _verifiedItemCache =
      <String, Future<AddonItem?>>{};

  AddonSearchService(this._providers);

  Stream<AddonFeedState> watchSearchResults(
    String query,
    String gameVersion, {
    int verifiedLimit = _searchVerifiedLimit,
    int concurrency = _searchVerificationConcurrency,
  }) {
    final normalizedQuery = query.trim();
    final normalizedVersion = gameVersion.trim();
    final cacheKey =
        '${normalizedVersion.toLowerCase()}|${normalizedQuery.toLowerCase()}|$verifiedLimit';

    if (normalizedQuery.isEmpty || normalizedVersion.isEmpty) {
      return Stream<AddonFeedState>.value(
        AddonFeedState(targetCount: verifiedLimit),
      );
    }

    final cachedState = _searchResultCache[cacheKey];
    if (cachedState != null) {
      return Stream<AddonFeedState>.value(cachedState);
    }

    final controller = StreamController<AddonFeedState>();
    () async {
      try {
        final candidates = await _loadSearchCandidates(
          normalizedQuery,
          normalizedVersion,
        );

        final finalState = await _verifyCandidatesProgressively(
          controller: controller,
          candidates: candidates,
          gameVersion: normalizedVersion,
          verifiedLimit: verifiedLimit,
          concurrency: concurrency,
          batchSize: concurrency,
        );

        _searchResultCache[cacheKey] = finalState;
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  Stream<AddonFeedState> watchDiscoveryFeed(
    String gameVersion, {
    int limit = _discoveryVerifiedLimit,
    int concurrency = _discoveryVerificationConcurrency,
  }) {
    final normalizedVersion = gameVersion.trim();
    final cacheKey = '${normalizedVersion.toLowerCase()}|$limit';

    if (normalizedVersion.isEmpty) {
      return Stream<AddonFeedState>.value(AddonFeedState(targetCount: limit));
    }

    final cachedState = _discoveryResultCache[cacheKey];
    if (cachedState != null) {
      return Stream<AddonFeedState>.value(cachedState);
    }

    final controller = StreamController<AddonFeedState>();
    () async {
      try {
        final primaryCandidates = await _loadDiscoveryCandidates(
          normalizedVersion,
          limit: _discoveryCandidateLimitPerProvider,
        );

        final verifiedByKey = <String, AddonItem>{};
        final rankByKey = <String, int>{
          for (final candidate in primaryCandidates) candidate.key: candidate.rankScore,
        };
        final seenKeys = <String>{...rankByKey.keys};
        var checkedCandidates = 0;
        var totalCandidates = primaryCandidates.length;

        if (primaryCandidates.isEmpty) {
          controller.add(
            AddonFeedState(
              isLoading: true,
              totalCandidates: 0,
              targetCount: limit,
            ),
          );
        }

        final primaryState = await _verifyCandidateSequence(
          controller: controller,
          candidates: primaryCandidates,
          gameVersion: normalizedVersion,
          verifiedLimit: limit,
          concurrency: concurrency,
          batchSize: _discoveryVerificationBatchSize,
          verifiedByKey: verifiedByKey,
          rankByKey: rankByKey,
          checkedCandidates: checkedCandidates,
          totalCandidates: totalCandidates,
        );

        checkedCandidates = primaryState.checkedCandidates;
        totalCandidates = primaryState.totalCandidates;

        if (verifiedByKey.length < limit) {
          final fallbackQueries = _buildDiscoveryFallbackQueries(
            WowVersionProfile.parse(normalizedVersion),
          );

          for (var queryIndex = 0;
              queryIndex < fallbackQueries.length && verifiedByKey.length < limit;
              queryIndex++) {
            final fallbackCandidates = await _loadSearchCandidates(
              fallbackQueries[queryIndex],
              normalizedVersion,
            );

            final newCandidates = <_CandidateEntry>[];
            for (final candidate in fallbackCandidates) {
              if (!seenKeys.add(candidate.key)) {
                continue;
              }

              final adjustedScore = candidate.rankScore - queryIndex * 20;
              rankByKey[candidate.key] = adjustedScore;
              newCandidates.add(
                _CandidateEntry(
                  item: candidate.item,
                  rankScore: adjustedScore,
                ),
              );
            }

            if (newCandidates.isEmpty) {
              continue;
            }

            totalCandidates += newCandidates.length;
            final fallbackState = await _verifyCandidateSequence(
              controller: controller,
              candidates: newCandidates,
              gameVersion: normalizedVersion,
              verifiedLimit: limit,
              concurrency: concurrency,
              batchSize: _discoveryVerificationBatchSize,
              verifiedByKey: verifiedByKey,
              rankByKey: rankByKey,
              checkedCandidates: checkedCandidates,
              totalCandidates: totalCandidates,
            );

            checkedCandidates = fallbackState.checkedCandidates;
            totalCandidates = fallbackState.totalCandidates;
          }
        }

        final finalState = _buildFeedState(
          verifiedByKey: verifiedByKey,
          rankByKey: rankByKey,
          checkedCandidates: checkedCandidates,
          totalCandidates: totalCandidates,
          verifiedLimit: limit,
          isLoading: false,
        );

        if (_shouldEmit(controller)) {
          controller.add(finalState);
        }

        _discoveryResultCache[cacheKey] = finalState;
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  Future<List<AddonItem>> searchAll(String query, String gameVersion) async {
    AddonFeedState latestState = const AddonFeedState();
    await for (final state in watchSearchResults(query, gameVersion)) {
      latestState = state;
    }
    return latestState.items;
  }

  Future<List<AddonItem>> fetchDiscoveryFeed(
    String gameVersion, {
    int limit = _discoveryVerifiedLimit,
  }) async {
    AddonFeedState latestState = const AddonFeedState();
    await for (final state in watchDiscoveryFeed(gameVersion, limit: limit)) {
      latestState = state;
    }
    return latestState.items;
  }

  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  ) async {
    final normalizedVersion = gameVersion.trim();
    if (normalizedVersion.isEmpty) {
      return null;
    }

    if (item.hasVerifiedPayload) {
      return (
        url: item.verifiedDownloadUrl!,
        fileName: item.verifiedFileName!,
      );
    }

    final verifiedItem = await _verifyCandidate(item, normalizedVersion);
    if (verifiedItem == null || !verifiedItem.hasVerifiedPayload) {
      return null;
    }

    return (
      url: verifiedItem.verifiedDownloadUrl!,
      fileName: verifiedItem.verifiedFileName!,
    );
  }

  Future<AddonFeedState> _verifyCandidatesProgressively({
    required StreamController<AddonFeedState> controller,
    required List<_CandidateEntry> candidates,
    required String gameVersion,
    required int verifiedLimit,
    required int concurrency,
    required int batchSize,
  }) async {
    final verifiedByKey = <String, AddonItem>{};
    final rankByKey = <String, int>{
      for (final candidate in candidates) candidate.key: candidate.rankScore,
    };

    return _verifyCandidateSequence(
      controller: controller,
      candidates: candidates,
      gameVersion: gameVersion,
      verifiedLimit: verifiedLimit,
      concurrency: concurrency,
      batchSize: batchSize,
      verifiedByKey: verifiedByKey,
      rankByKey: rankByKey,
      checkedCandidates: 0,
      totalCandidates: candidates.length,
    );
  }

  Future<AddonFeedState> _verifyCandidateSequence({
    required StreamController<AddonFeedState> controller,
    required List<_CandidateEntry> candidates,
    required String gameVersion,
    required int verifiedLimit,
    required int concurrency,
    required int batchSize,
    required Map<String, AddonItem> verifiedByKey,
    required Map<String, int> rankByKey,
    required int checkedCandidates,
    required int totalCandidates,
  }) async {
    if (candidates.isEmpty) {
      final emptyState = AddonFeedState(
        items: _sortVerifiedItems(verifiedByKey, rankByKey, verifiedLimit),
        isLoading: false,
        checkedCandidates: checkedCandidates,
        totalCandidates: totalCandidates,
        targetCount: verifiedLimit,
      );
      if (_shouldEmit(controller)) {
        controller.add(emptyState);
      }
      return emptyState;
    }

    if (_shouldEmit(controller)) {
      controller.add(
        AddonFeedState(
          items: _sortVerifiedItems(verifiedByKey, rankByKey, verifiedLimit),
          isLoading: true,
          checkedCandidates: checkedCandidates,
          totalCandidates: totalCandidates,
          targetCount: verifiedLimit,
        ),
      );
    }

    final effectiveBatchSize = batchSize < concurrency ? concurrency : batchSize;

    for (var batchStart = 0;
        batchStart < candidates.length && verifiedByKey.length < verifiedLimit;
        batchStart += effectiveBatchSize) {
      final batchEnd = batchStart + effectiveBatchSize > candidates.length
          ? candidates.length
          : batchStart + effectiveBatchSize;
      final candidateBatch = candidates.sublist(batchStart, batchEnd);

      for (var chunkStart = 0;
          chunkStart < candidateBatch.length &&
              verifiedByKey.length < verifiedLimit;
          chunkStart += concurrency) {
        final chunkEnd = chunkStart + concurrency > candidateBatch.length
            ? candidateBatch.length
            : chunkStart + concurrency;
        final candidateChunk = candidateBatch.sublist(chunkStart, chunkEnd);
        final verifiedChunk = await Future.wait(
          candidateChunk.map(
            (candidate) => _verifyCandidate(candidate.item, gameVersion),
          ),
        );

        checkedCandidates += candidateChunk.length;
        for (var index = 0; index < candidateChunk.length; index++) {
          final verifiedItem = verifiedChunk[index];
          if (verifiedItem == null) {
            continue;
          }

          verifiedByKey[candidateChunk[index].key] = verifiedItem;
        }

        final state = _buildFeedState(
          verifiedByKey: verifiedByKey,
          rankByKey: rankByKey,
          checkedCandidates: checkedCandidates,
          totalCandidates: totalCandidates,
          verifiedLimit: verifiedLimit,
          isLoading:
              checkedCandidates < totalCandidates &&
              verifiedByKey.length < verifiedLimit,
        );
        if (_shouldEmit(controller)) {
          controller.add(state);
        }
      }
    }

    return _buildFeedState(
      verifiedByKey: verifiedByKey,
      rankByKey: rankByKey,
      checkedCandidates: checkedCandidates,
      totalCandidates: totalCandidates,
      verifiedLimit: verifiedLimit,
      isLoading:
          checkedCandidates < totalCandidates &&
          verifiedByKey.length < verifiedLimit,
    );
  }

  AddonFeedState _buildFeedState({
    required Map<String, AddonItem> verifiedByKey,
    required Map<String, int> rankByKey,
    required int checkedCandidates,
    required int totalCandidates,
    required int verifiedLimit,
    required bool isLoading,
  }) {
    return AddonFeedState(
      items: _sortVerifiedItems(verifiedByKey, rankByKey, verifiedLimit),
      isLoading: isLoading,
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

  bool _shouldEmit(StreamController<AddonFeedState> controller) {
    return !controller.isClosed;
  }

  Future<List<_CandidateEntry>> _loadSearchCandidates(
    String query,
    String gameVersion,
  ) {
    final normalizedQuery = query.trim();
    final normalizedVersion = gameVersion.trim();
    final cacheKey =
        '${normalizedVersion.toLowerCase()}|${normalizedQuery.toLowerCase()}|candidates';

    return _searchCandidateCache.putIfAbsent(
      cacheKey,
      () => _loadSearchCandidatesInternal(normalizedQuery, normalizedVersion),
    );
  }

  Future<List<_CandidateEntry>> _loadSearchCandidatesInternal(
    String normalizedQuery,
    String normalizedVersion,
  ) async {
    final providerResults = await Future.wait(
      _providers.map(
        (provider) => provider
            .search(normalizedQuery, normalizedVersion)
            .catchError((_) => <AddonItem>[]),
      ),
    );

    final merged = <String, _CandidateEntry>{};
    for (var providerIndex = 0;
        providerIndex < providerResults.length;
        providerIndex++) {
      final providerItems = providerResults[providerIndex];
      for (var itemIndex = 0;
          itemIndex < providerItems.length &&
              itemIndex < _searchCandidateLimitPerProvider;
          itemIndex++) {
        final item = providerItems[itemIndex];
        final candidate = _CandidateEntry(
          item: item,
          rankScore: _scoreSearchCandidate(item, normalizedQuery) -
              itemIndex * 2 -
              providerIndex * 5,
        );

        final existing = merged[candidate.key];
        if (existing == null || candidate.rankScore > existing.rankScore) {
          merged[candidate.key] = candidate;
        }
      }
    }

    final rankedCandidates = merged.values.toList()
      ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return rankedCandidates;
  }

  Future<List<_CandidateEntry>> _loadDiscoveryCandidates(
    String gameVersion, {
    required int limit,
  }) {
    final normalizedVersion = gameVersion.trim();
    final cacheKey = '${normalizedVersion.toLowerCase()}|$limit|discovery';

    return _discoveryCandidateCache.putIfAbsent(
      cacheKey,
      () => _loadDiscoveryCandidatesInternal(normalizedVersion, limit: limit),
    );
  }

  Future<List<_CandidateEntry>> _loadDiscoveryCandidatesInternal(
    String normalizedVersion, {
    required int limit,
  }) async {
    final merged = <String, _CandidateEntry>{};

    for (var providerIndex = 0; providerIndex < _providers.length; providerIndex++) {
      final provider = _providers[providerIndex];
      if (!provider.supportsDiscoveryFeed) {
        continue;
      }

      final items = await provider
          .fetchPopularAddons(
            normalizedVersion,
            limit: limit,
          )
          .catchError((_) => <AddonItem>[]);

      for (var itemIndex = 0;
          itemIndex < items.length && itemIndex < _discoveryCandidateLimitPerProvider;
          itemIndex++) {
        final item = items[itemIndex];
        final candidate = _CandidateEntry(
          item: item,
          rankScore: _scoreDiscoveryCandidate(item, providerIndex, itemIndex),
        );
        final existing = merged[candidate.key];
        if (existing == null || candidate.rankScore > existing.rankScore) {
          merged[candidate.key] = candidate;
        }
      }
    }

    final rankedCandidates = merged.values.toList()
      ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return rankedCandidates;
  }

  Future<AddonItem?> _verifyCandidate(
    AddonItem item,
    String gameVersion,
  ) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    final cacheKey = '${item.providerName}:${item.originalId}|$normalizedVersion';

    return _verifiedItemCache.putIfAbsent(cacheKey, () async {
      if (item.hasVerifiedPayload) {
        return item;
      }

      final provider = _resolveProvider(item.providerName);
      if (provider == null) {
        return null;
      }

      try {
        return await provider.verifyCandidate(item, normalizedVersion);
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'Addon verification failed for ${item.providerName}:${item.originalId}: $error',
          );
        }
        return null;
      }
    });
  }

  IAddonProvider? _resolveProvider(String providerName) {
    for (final provider in _providers) {
      if (provider.providerName == providerName) {
        return provider;
      }
      if (providerName == GitHubProvider.staticProviderName &&
          provider is GitHubProvider) {
        return provider;
      }
      if (providerName == CurseForgeProvider.staticProviderName &&
          provider is CurseForgeProvider) {
        return provider;
      }
    }

    return null;
  }

  List<String> _buildDiscoveryFallbackQueries(WowVersionProfile profile) {
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

  int _scoreSearchCandidate(AddonItem item, String query) {
    final normalizedQuery = _normalizeIdentity(query);
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final normalizedName = _normalizeIdentity(item.name);
    final normalizedSlug = _normalizeIdentity(item.sourceSlug ?? '');
    final normalizedSummary = _normalizeIdentity(item.summary);
    var score = 0;

    if (normalizedName == normalizedQuery || normalizedSlug == normalizedQuery) {
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

  String _normalizeIdentity(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }
}

class _CandidateEntry {
  final AddonItem item;
  final int rankScore;

  const _CandidateEntry({
    required this.item,
    required this.rankScore,
  });

  String get key => '${item.providerName}:${item.originalId}';
}
