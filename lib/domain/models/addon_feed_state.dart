import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

enum AddonFeedLoadingPhase { idle, initial, refreshing, paginating }

class AddonFeedState {
  final List<AddonItem> items;
  final AddonFeedLoadingPhase loadingPhase;
  final bool canLoadMore;
  final int checkedCandidates;
  final int totalCandidates;
  final int targetCount;
  final Object? error;

  const AddonFeedState({
    this.items = const <AddonItem>[],
    bool isLoading = false,
    AddonFeedLoadingPhase? loadingPhase,
    this.canLoadMore = false,
    this.checkedCandidates = 0,
    this.totalCandidates = 0,
    this.targetCount = 0,
    this.error,
  }) : loadingPhase =
           loadingPhase ??
           (isLoading
               ? AddonFeedLoadingPhase.initial
               : AddonFeedLoadingPhase.idle);

  bool get isLoading => loadingPhase != AddonFeedLoadingPhase.idle;

  bool get hasResults => items.isNotEmpty;

  bool get isComplete => !isLoading;

  bool get hasError => error != null;

  double get progressValue {
    if (totalCandidates <= 0) {
      return 0;
    }

    return checkedCandidates / totalCandidates;
  }

  AddonFeedState copyWith({
    List<AddonItem>? items,
    AddonFeedLoadingPhase? loadingPhase,
    bool? isLoading,
    bool? canLoadMore,
    int? checkedCandidates,
    int? totalCandidates,
    int? targetCount,
    Object? error,
  }) {
    return AddonFeedState(
      items: items ?? this.items,
      loadingPhase:
          loadingPhase ??
          ((isLoading ?? this.isLoading)
              ? this.loadingPhase == AddonFeedLoadingPhase.idle
                    ? AddonFeedLoadingPhase.initial
                    : this.loadingPhase
              : AddonFeedLoadingPhase.idle),
      canLoadMore: canLoadMore ?? this.canLoadMore,
      checkedCandidates: checkedCandidates ?? this.checkedCandidates,
      totalCandidates: totalCandidates ?? this.totalCandidates,
      targetCount: targetCount ?? this.targetCount,
      error: error,
    );
  }
}
