import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class AddonFeedState {
  final List<AddonItem> items;
  final bool isLoading;
  final int checkedCandidates;
  final int totalCandidates;
  final int targetCount;
  final Object? error;

  const AddonFeedState({
    this.items = const <AddonItem>[],
    this.isLoading = false,
    this.checkedCandidates = 0,
    this.totalCandidates = 0,
    this.targetCount = 0,
    this.error,
  });

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
    bool? isLoading,
    int? checkedCandidates,
    int? totalCandidates,
    int? targetCount,
    Object? error,
  }) {
    return AddonFeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      checkedCandidates: checkedCandidates ?? this.checkedCandidates,
      totalCandidates: totalCandidates ?? this.totalCandidates,
      targetCount: targetCount ?? this.targetCount,
      error: error,
    );
  }
}
