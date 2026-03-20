import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/features/addons/search/application/search_use_cases.dart';

class ClientSearchScopeKey {
  final String clientId;
  final String gameVersion;

  const ClientSearchScopeKey({
    required this.clientId,
    required this.gameVersion,
  });

  @override
  bool operator ==(Object other) {
    return other is ClientSearchScopeKey &&
        other.clientId == clientId &&
        other.gameVersion == gameVersion;
  }

  @override
  int get hashCode => Object.hash(clientId, gameVersion);
}

class SearchResultsNotifier extends StateNotifier<AddonFeedState> {
  final SearchAddonsUseCase _searchAddonsUseCase;
  final String _sessionKey;
  StreamSubscription<AddonFeedState>? _subscription;
  Timer? _debounceTimer;
  int _requestToken = 0;

  SearchResultsNotifier(this._searchAddonsUseCase, this._sessionKey)
    : super(const AddonFeedState());

  Future<void> search(String query, {required String gameVersion}) async {
    if (query.isEmpty || gameVersion.trim().isEmpty) {
      _debounceTimer?.cancel();
      await _subscription?.cancel();
      state = const AddonFeedState();
      return;
    }

    final requestToken = ++_requestToken;
    final previousItems = state.items;
    state = AddonFeedState(
      items: previousItems,
      loadingPhase: previousItems.isEmpty
          ? AddonFeedLoadingPhase.initial
          : AddonFeedLoadingPhase.refreshing,
      targetCount: 12,
    );

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 260), () async {
      await _subscription?.cancel();
      _subscription =
          _searchAddonsUseCase(
            query,
            gameVersion: gameVersion,
            sessionKey: _sessionKey,
          ).listen(
            (nextState) {
              if (requestToken != _requestToken) {
                return;
              }

              if (nextState.items.isEmpty &&
                  nextState.isLoading &&
                  previousItems.isNotEmpty) {
                state = nextState.copyWith(items: previousItems);
                return;
              }

              state = nextState;
            },
            onError: (error, stackTrace) {
              if (requestToken != _requestToken) {
                return;
              }

              state = AddonFeedState(
                items: previousItems,
                loadingPhase: AddonFeedLoadingPhase.idle,
                targetCount: 12,
                error: error,
              );
            },
          );
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

class DiscoveryFeedNotifier extends StateNotifier<AddonFeedState> {
  final LoadDiscoveryFeedUseCase _loadDiscoveryFeedUseCase;
  final String _sessionKey;
  final String _gameVersion;
  StreamSubscription<AddonFeedState>? _subscription;
  int _requestToken = 0;
  int _currentLimit = 12;

  DiscoveryFeedNotifier(
    this._loadDiscoveryFeedUseCase,
    this._gameVersion,
    this._sessionKey,
  ) : super(
        const AddonFeedState(
          loadingPhase: AddonFeedLoadingPhase.initial,
          targetCount: 12,
        ),
      ) {
    _startLoad();
  }

  Future<void> load({bool resetToFirstPage = false}) async {
    if (resetToFirstPage) {
      _currentLimit = 12;
    }
    await _startLoad();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.canLoadMore) {
      return;
    }

    _currentLimit += 12;
    await _startLoad();
  }

  Future<void> _startLoad() async {
    if (_gameVersion.trim().isEmpty) {
      await _subscription?.cancel();
      state = const AddonFeedState();
      return;
    }

    await _subscription?.cancel();
    final requestToken = ++_requestToken;
    final previousItems = state.items;
    state = AddonFeedState(
      items: previousItems,
      loadingPhase: previousItems.isEmpty
          ? AddonFeedLoadingPhase.initial
          : AddonFeedLoadingPhase.paginating,
      canLoadMore: state.canLoadMore,
      targetCount: _currentLimit,
    );

    final allowFallback = _currentLimit > 12;
    _subscription =
        _loadDiscoveryFeedUseCase(
          _gameVersion,
          sessionKey: _sessionKey,
          limit: _currentLimit,
          allowFallback: allowFallback,
        ).listen(
          (nextState) {
            if (requestToken != _requestToken) {
              return;
            }

            if (nextState.items.isEmpty &&
                nextState.isLoading &&
                previousItems.isNotEmpty) {
              state = nextState.copyWith(items: previousItems);
              return;
            }

            state = nextState;
          },
          onError: (error, stackTrace) {
            if (requestToken != _requestToken) {
              return;
            }

            state = AddonFeedState(
              items: previousItems,
              loadingPhase: AddonFeedLoadingPhase.idle,
              canLoadMore: state.canLoadMore,
              targetCount: _currentLimit,
              error: error,
            );
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final searchResultsProvider = StateNotifierProvider.autoDispose
    .family<SearchResultsNotifier, AddonFeedState, ClientSearchScopeKey>((
      ref,
      key,
    ) {
      return SearchResultsNotifier(
        ref.read(searchAddonsUseCaseProvider),
        'search:${key.clientId}',
      );
    });

final discoveryFeedProvider = StateNotifierProvider.autoDispose
    .family<DiscoveryFeedNotifier, AddonFeedState, ClientSearchScopeKey>((
      ref,
      key,
    ) {
      return DiscoveryFeedNotifier(
        ref.read(loadDiscoveryFeedUseCaseProvider),
        key.gameVersion,
        'discovery:${key.clientId}',
      );
    });
