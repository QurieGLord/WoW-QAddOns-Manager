part of 'main.dart';

const bool kBenchmarkMode = bool.fromEnvironment('BENCHMARK_MODE');
const String kBenchmarkVariant = String.fromEnvironment(
  'BENCHMARK_VARIANT',
  defaultValue: 'baseline',
);
const bool kBenchmarkDisableBannerImageLayer = bool.fromEnvironment(
  'BENCH_DISABLE_BANNER_IMAGE',
);
const bool kBenchmarkDisableBannerBlurPath = bool.fromEnvironment(
  'BENCH_DISABLE_BANNER_BLUR',
);
const bool kBenchmarkDisableSvgOverlay = bool.fromEnvironment(
  'BENCH_DISABLE_SVG_OVERLAY',
);
const bool kBenchmarkDisableOpacityLayering = bool.fromEnvironment(
  'BENCH_DISABLE_OPACITY_STACKS',
);
const bool kBenchmarkSimplifyCollapsingHeader = bool.fromEnvironment(
  'BENCH_SIMPLIFY_HEADER',
);
const bool kBenchmarkDisableEntryAnimations = bool.fromEnvironment(
  'BENCH_DISABLE_ENTRY_ANIMATIONS',
);
const bool kBenchmarkDisableInstalledMatching = bool.fromEnvironment(
  'BENCH_DISABLE_INSTALLED_MATCHING',
);
const bool kBenchmarkSimplifyDashboardCards = bool.fromEnvironment(
  'BENCH_SIMPLIFY_DASHBOARD_CARDS',
);
const bool kBenchmarkDisableImprovedScrolling = bool.fromEnvironment(
  'BENCH_DISABLE_IMPROVED_SCROLLING',
);

final GlobalKey<NavigatorState> _benchmarkNavigatorKey =
    GlobalKey<NavigatorState>();
final _BenchmarkRecorder _benchmarkRecorder = _BenchmarkRecorder();
final _BenchmarkHarness _benchmarkHarness = _BenchmarkHarness();
final ValueNotifier<_BenchmarkViewportState> _benchmarkViewportNotifier =
    ValueNotifier<_BenchmarkViewportState>(const _BenchmarkViewportState());

enum _BenchmarkSceneMode { app, minimalShell }

enum _BenchmarkOverlayMode { none, movingMarker }

class _BenchmarkViewportState {
  final _BenchmarkSceneMode sceneMode;
  final _BenchmarkOverlayMode overlayMode;
  final String label;

  const _BenchmarkViewportState({
    this.sceneMode = _BenchmarkSceneMode.app,
    this.overlayMode = _BenchmarkOverlayMode.none,
    this.label = '',
  });
}

List<Override> _benchmarkProviderOverrides() {
  if (!kBenchmarkMode) {
    return const <Override>[];
  }

  return _benchmarkHarness.buildOverrides();
}

void _benchmarkCount(String key, [int value = 1]) {
  _benchmarkRecorder.incrementCounter(key, value);
}

void _benchmarkRecordDuration(String key, Duration duration) {
  _benchmarkRecorder.recordDuration(key, duration);
}

Widget _benchmarkWrapOpacity(double opacity, Widget child) {
  if (kBenchmarkDisableOpacityLayering || opacity >= 0.999) {
    return child;
  }

  return Opacity(opacity: opacity, child: child);
}

class _BenchmarkAppShell extends StatelessWidget {
  final Widget child;

  const _BenchmarkAppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_BenchmarkViewportState>(
      valueListenable: _benchmarkViewportNotifier,
      builder: (context, viewport, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: viewport.sceneMode != _BenchmarkSceneMode.app,
              child: child,
            ),
            if (viewport.sceneMode == _BenchmarkSceneMode.minimalShell)
              _BenchmarkMinimalShell(label: viewport.label),
            if (viewport.overlayMode == _BenchmarkOverlayMode.movingMarker)
              _BenchmarkMarkerOverlay(label: viewport.label),
            const Positioned.fill(
              child: IgnorePointer(child: _BenchmarkRunner()),
            ),
          ],
        );
      },
    );
  }
}

class _BenchmarkRunner extends StatefulWidget {
  const _BenchmarkRunner();

  @override
  State<_BenchmarkRunner> createState() => _BenchmarkRunnerState();
}

class _BenchmarkRunnerState extends State<_BenchmarkRunner> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runBenchmarks());
    });
  }

  Future<void> _runBenchmarks() async {
    try {
      stdout.writeln(
        '[BENCHMARK] variant=$kBenchmarkVariant '
        'flags=${jsonEncode(_benchmarkFlagSnapshot())}',
      );
      await _pause(const Duration(milliseconds: 900));
      await _captureViewportScenario(
        'control_minimal_shell_marker',
        const _BenchmarkViewportState(
          sceneMode: _BenchmarkSceneMode.minimalShell,
          label: 'minimal-shell',
        ),
      );
      await _pause(const Duration(milliseconds: 200));
      await _waitForScrollableExtent(label: 'home-grid');
      await _pause(const Duration(milliseconds: 900));

      await _captureViewportScenario(
        'control_static_home_shell_marker',
        const _BenchmarkViewportState(
          overlayMode: _BenchmarkOverlayMode.movingMarker,
          label: 'home-shell',
        ),
      );

      await _captureScenario('home_idle', () async {
        await _pause(const Duration(milliseconds: 1800));
      });

      await _captureScenario('home_scroll_cards', () async {
        await _scrollFirstScrollable(
          target: 720,
          duration: const Duration(milliseconds: 1200),
        );
        await _pause(const Duration(milliseconds: 240));
        await _scrollFirstScrollable(
          target: 0,
          duration: const Duration(milliseconds: 1200),
        );
      });

      await _openDetailsScreen();
      await _pause(const Duration(milliseconds: 900));

      await _captureViewportScenario(
        'control_static_client_details_marker',
        const _BenchmarkViewportState(
          overlayMode: _BenchmarkOverlayMode.movingMarker,
          label: 'client-details-shell',
        ),
      );

      await _captureScenario('client_details_idle_hero', () async {
        await _pause(const Duration(milliseconds: 1800));
      });

      await _captureScenario(
        'client_details_collapsing_header_scroll',
        () async {
          final state = _findState<_ClientDetailsScreenState>();
          if (state == null) {
            throw StateError('ClientDetails state not found');
          }

          await state._nestedScrollController.animateTo(
            220,
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeInOutCubic,
          );
          await _pause(const Duration(milliseconds: 200));
          await state._nestedScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeInOutCubic,
          );
        },
      );

      await _captureScenario('local_addons_scroll', () async {
        final state = _findState<_ClientDetailsScreenState>();
        if (state == null) {
          throw StateError('ClientDetails state not found');
        }

        await state._nestedScrollController.animateTo(
          980,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOutCubic,
        );
        await _pause(const Duration(milliseconds: 220));
        await state._nestedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOutCubic,
        );
      });

      await _captureScenario('discovery_progressive_arrival', () async {
        final detailsState = _findState<_ClientDetailsScreenState>();
        if (detailsState == null) {
          throw StateError('ClientDetails state not found');
        }

        detailsState._onNavTap(1);
        await _waitForState<_SearchAddonsViewState>(label: 'search-view');
        await _pause(const Duration(milliseconds: 2800));
      });

      await _captureScenario('discovery_idle_with_results', () async {
        await _pause(const Duration(milliseconds: 1500));
      });

      await _captureScenario('search_progressive_arrival', () async {
        final searchState = _findState<_SearchAddonsViewState>();
        final detailsState = _findState<_ClientDetailsScreenState>();
        if (searchState == null) {
          throw StateError('Search state not found');
        }
        if (detailsState == null) {
          throw StateError('ClientDetails state not found');
        }

        await detailsState._nestedScrollController.animateTo(
          460,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
        );
        await _pause(const Duration(milliseconds: 160));
        searchState._handleQueryChanged('bench');
        await _pause(const Duration(milliseconds: 2800));
      });

      await _captureScenario('search_idle_with_results', () async {
        await _pause(const Duration(milliseconds: 1500));
      });

      await _captureScenario('search_results_scroll', () async {
        final detailsState = _findState<_ClientDetailsScreenState>();
        if (detailsState == null) {
          throw StateError('ClientDetails state not found');
        }

        await detailsState._nestedScrollController.animateTo(
          1480,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOutCubic,
        );
        await _pause(const Duration(milliseconds: 220));
        await detailsState._nestedScrollController.animateTo(
          120,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOutCubic,
        );
      });

      _benchmarkRecorder.printSummary();
      await _pause(const Duration(milliseconds: 400));
      exit(0);
    } catch (error, stackTrace) {
      stdout.writeln('[BENCHMARK_ERROR] $error');
      stdout.writeln(stackTrace);
      exit(1);
    }
  }

  Future<void> _captureScenario(
    String scenarioName,
    Future<void> Function() action,
  ) async {
    stdout.writeln('[BENCHMARK] start scenario=$scenarioName');
    _benchmarkRecorder.beginScenario(scenarioName);
    await action();
    await _pause(const Duration(milliseconds: 260));
    _benchmarkRecorder.endScenario();
  }

  Future<void> _captureViewportScenario(
    String scenarioName,
    _BenchmarkViewportState viewportState,
  ) async {
    _benchmarkViewportNotifier.value = viewportState;
    await _pause(const Duration(milliseconds: 220));
    await _captureScenario(scenarioName, () async {
      await _pause(const Duration(milliseconds: 2400));
    });
    _benchmarkViewportNotifier.value = const _BenchmarkViewportState();
    await _pause(const Duration(milliseconds: 220));
  }

  Future<void> _openDetailsScreen() async {
    final navigator = _benchmarkNavigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Navigator not ready');
    }

    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              ClientDetailsScreen(client: _benchmarkHarness.clients.first),
        ),
      ),
    );
    await _waitForState<_ClientDetailsScreenState>(label: 'client-details');
  }

  Future<void> _scrollFirstScrollable({
    required double target,
    required Duration duration,
  }) async {
    final scrollable = _findFirstScrollable();
    if (scrollable == null) {
      throw StateError('Scrollable not found');
    }

    final maxExtent = scrollable.position.maxScrollExtent;
    final clampedTarget = target.clamp(0, maxExtent).toDouble();
    await scrollable.position.animateTo(
      clampedTarget,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  ScrollableState? _findFirstScrollable() {
    ScrollableState? result;
    _visitElements((element) {
      if (result != null) {
        return;
      }

      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        if (scrollable.position.hasContentDimensions &&
            scrollable.position.maxScrollExtent > 0) {
          result = scrollable;
        }
      }
    });
    return result;
  }

  Future<void> _waitForScrollableExtent({required String label}) async {
    await _waitForCondition(() {
      final scrollable = _findFirstScrollable();
      return scrollable != null &&
          scrollable.position.hasContentDimensions &&
          scrollable.position.maxScrollExtent > 0;
    }, label: label);
  }

  Future<void> _waitForState<T extends State<StatefulWidget>>({
    required String label,
  }) async {
    await _waitForCondition(() => _findState<T>() != null, label: label);
  }

  T? _findState<T extends State<StatefulWidget>>() {
    T? result;
    _visitElements((element) {
      if (result != null) {
        return;
      }

      if (element is StatefulElement && element.state is T) {
        result = element.state as T;
      }
    });
    return result;
  }

  void _visitElements(void Function(Element element) visitor) {
    final rootContext = _benchmarkNavigatorKey.currentContext;
    if (rootContext == null) {
      return;
    }

    void visit(Element element) {
      visitor(element);
      element.visitChildren(visit);
    }

    visit(rootContext as Element);
  }

  Future<void> _waitForCondition(
    bool Function() condition, {
    required String label,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (condition()) {
        return;
      }
      await _pause(const Duration(milliseconds: 60));
    }

    throw TimeoutException('Timed out waiting for $label', timeout);
  }

  Future<void> _pause(Duration duration) async {
    await Future<void>.delayed(duration);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _BenchmarkMinimalShell extends StatelessWidget {
  final String label;

  const _BenchmarkMinimalShell({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              width: 420,
              height: 220,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          _BenchmarkMarkerOverlay(label: label, padded: false),
        ],
      ),
    );
  }
}

class _BenchmarkMarkerOverlay extends StatefulWidget {
  final String label;
  final bool padded;

  const _BenchmarkMarkerOverlay({required this.label, this.padded = true});

  @override
  State<_BenchmarkMarkerOverlay> createState() =>
      _BenchmarkMarkerOverlayState();
}

class _BenchmarkMarkerOverlayState extends State<_BenchmarkMarkerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final marker = AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.34),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (context, child) {
        final horizontal = ui.lerpDouble(-0.82, 0.82, _controller.value)!;
        return Align(
          alignment: Alignment(horizontal, widget.padded ? -0.76 : 0),
          child: child,
        );
      },
    );

    if (!widget.padded) {
      return marker;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: marker,
    );
  }
}

Map<String, Object?> _benchmarkFlagSnapshot() {
  return <String, Object?>{
    'disableBannerImage': kBenchmarkDisableBannerImageLayer,
    'disableBannerBlur': kBenchmarkDisableBannerBlurPath,
    'disableSvgOverlay': kBenchmarkDisableSvgOverlay,
    'disableOpacityStacks': kBenchmarkDisableOpacityLayering,
    'simplifyHeader': kBenchmarkSimplifyCollapsingHeader,
    'disableEntryAnimations': kBenchmarkDisableEntryAnimations,
    'disableInstalledMatching': kBenchmarkDisableInstalledMatching,
    'simplifyDashboardCards': kBenchmarkSimplifyDashboardCards,
    'disableImprovedScrolling': kBenchmarkDisableImprovedScrolling,
  };
}

class _BenchmarkRecorder {
  _BenchmarkScenarioAccumulator? _activeScenario;
  bool _initialized = false;

  void initialize() {
    if (!kBenchmarkMode || _initialized) {
      return;
    }

    _initialized = true;
    WidgetsBinding.instance.addTimingsCallback(_recordTimings);
  }

  void beginScenario(String name) {
    _activeScenario = _BenchmarkScenarioAccumulator(
      name: name,
      startedAt: DateTime.now(),
    );
  }

  void incrementCounter(String key, [int value = 1]) {
    final scenario = _activeScenario;
    if (scenario == null) {
      return;
    }

    scenario.counters.update(
      key,
      (current) => current + value,
      ifAbsent: () {
        return value;
      },
    );
  }

  void recordDuration(String key, Duration duration) {
    final scenario = _activeScenario;
    if (scenario == null) {
      return;
    }

    scenario.durationTotalsMicros.update(
      key,
      (current) => current + duration.inMicroseconds,
      ifAbsent: () => duration.inMicroseconds,
    );
    scenario.durationSamples.update(
      key,
      (current) => current + 1,
      ifAbsent: () {
        return 1;
      },
    );
  }

  void endScenario() {
    final scenario = _activeScenario;
    if (scenario == null) {
      return;
    }

    scenario.finishedAt = DateTime.now();
    stdout.writeln('BENCHMARK_RESULT ${jsonEncode(scenario.toJson())}');
    _activeScenario = null;
  }

  void printSummary() {
    stdout.writeln(
      'BENCHMARK_SUMMARY ${jsonEncode(<String, Object?>{'variant': kBenchmarkVariant, 'flags': _benchmarkFlagSnapshot()})}',
    );
  }

  void _recordTimings(List<ui.FrameTiming> timings) {
    final scenario = _activeScenario;
    if (scenario == null || timings.isEmpty) {
      return;
    }

    scenario.timings.addAll(timings);
  }
}

class _BenchmarkScenarioAccumulator {
  final String name;
  final DateTime startedAt;
  final List<ui.FrameTiming> timings = <ui.FrameTiming>[];
  final Map<String, int> counters = <String, int>{};
  final Map<String, int> durationTotalsMicros = <String, int>{};
  final Map<String, int> durationSamples = <String, int>{};

  DateTime? finishedAt;

  _BenchmarkScenarioAccumulator({required this.name, required this.startedAt});

  Map<String, Object?> toJson() {
    final orderedTimings = timings.toList()
      ..sort(
        (a, b) => a
            .timestampInMicroseconds(ui.FramePhase.vsyncStart)
            .compareTo(b.timestampInMicroseconds(ui.FramePhase.vsyncStart)),
      );
    final totalSpans = orderedTimings
        .map((timing) => timing.totalSpan.inMicroseconds / 1000)
        .toList(growable: false);
    final buildSpans = orderedTimings
        .map((timing) => timing.buildDuration.inMicroseconds / 1000)
        .toList(growable: false);
    final rasterSpans = orderedTimings
        .map((timing) => timing.rasterDuration.inMicroseconds / 1000)
        .toList(growable: false);
    final vsyncOverheads = orderedTimings
        .map((timing) => timing.vsyncOverhead.inMicroseconds / 1000)
        .toList(growable: false);
    final layerCacheCounts = orderedTimings
        .map((timing) => timing.layerCacheCount.toDouble())
        .toList(growable: false);
    final pictureCacheCounts = orderedTimings
        .map((timing) => timing.pictureCacheCount.toDouble())
        .toList(growable: false);
    final layerCacheMegabytes = orderedTimings
        .map((timing) => timing.layerCacheMegabytes)
        .toList(growable: false);
    final pictureCacheMegabytes = orderedTimings
        .map((timing) => timing.pictureCacheMegabytes)
        .toList(growable: false);
    final cadenceIntervals = List<double>.generate(
      orderedTimings.length <= 1 ? 0 : orderedTimings.length - 1,
      (index) {
        final current = orderedTimings[index].timestampInMicroseconds(
          ui.FramePhase.vsyncStart,
        );
        final next = orderedTimings[index + 1].timestampInMicroseconds(
          ui.FramePhase.vsyncStart,
        );
        return (next - current) / 1000;
      },
      growable: false,
    ).where((value) => value > 0).toList(growable: false);

    final slowFrames16 = totalSpans.where((value) => value >= 16.6).length;
    final slowFrames33 = totalSpans.where((value) => value >= 33.0).length;
    final cadenceNear60 = cadenceIntervals
        .where((value) => value >= 12 && value < 21)
        .length;
    final cadenceNear30 = cadenceIntervals
        .where((value) => value >= 28 && value < 40)
        .length;
    final cadenceJitter = cadenceIntervals
        .where(
          (value) => value < 12 || (value >= 21 && value < 28) || value >= 40,
        )
        .length;
    final buildDominant = List<int>.generate(
      orderedTimings.length,
      (index) => buildSpans[index] > rasterSpans[index] ? 1 : 0,
      growable: false,
    ).where((value) => value == 1).length;
    final rasterDominant = List<int>.generate(
      orderedTimings.length,
      (index) => rasterSpans[index] > buildSpans[index] ? 1 : 0,
      growable: false,
    ).where((value) => value == 1).length;
    final avgCadence = _average(cadenceIntervals);

    return <String, Object?>{
      'variant': kBenchmarkVariant,
      'scenario': name,
      'frames': orderedTimings.length,
      'elapsedMs': finishedAt == null
          ? 0
          : finishedAt!.difference(startedAt).inMilliseconds,
      'avgBuildMs': _average(buildSpans),
      'p95BuildMs': _percentile(buildSpans, 0.95),
      'maxBuildMs': _max(buildSpans),
      'avgRasterMs': _average(rasterSpans),
      'p95RasterMs': _percentile(rasterSpans, 0.95),
      'maxRasterMs': _max(rasterSpans),
      'avgTotalMs': _average(totalSpans),
      'p95TotalMs': _percentile(totalSpans, 0.95),
      'maxTotalMs': _max(totalSpans),
      'avgCadenceMs': avgCadence,
      'p50CadenceMs': _percentile(cadenceIntervals, 0.5),
      'p95CadenceMs': _percentile(cadenceIntervals, 0.95),
      'maxCadenceMs': _max(cadenceIntervals),
      'effectiveFps': avgCadence <= 0
          ? 0
          : double.parse((1000 / avgCadence).toStringAsFixed(1)),
      'cadenceNear60Pct': cadenceIntervals.isEmpty
          ? 0
          : (cadenceNear60 * 100 / cadenceIntervals.length).toStringAsFixed(1),
      'cadenceNear30Pct': cadenceIntervals.isEmpty
          ? 0
          : (cadenceNear30 * 100 / cadenceIntervals.length).toStringAsFixed(1),
      'cadenceJitterPct': cadenceIntervals.isEmpty
          ? 0
          : (cadenceJitter * 100 / cadenceIntervals.length).toStringAsFixed(1),
      'cadenceLabel': _cadenceLabel(
        avgCadence: avgCadence,
        p95Cadence: _percentile(cadenceIntervals, 0.95),
        cadenceNear60: cadenceNear60,
        cadenceNear30: cadenceNear30,
        cadenceJitter: cadenceJitter,
        sampleCount: cadenceIntervals.length,
      ),
      'avgVsyncOverheadMs': _average(vsyncOverheads),
      'p95VsyncOverheadMs': _percentile(vsyncOverheads, 0.95),
      'avgLayerCacheCount': _average(layerCacheCounts),
      'avgPictureCacheCount': _average(pictureCacheCounts),
      'avgLayerCacheMb': _average(layerCacheMegabytes),
      'avgPictureCacheMb': _average(pictureCacheMegabytes),
      'slowFrames16': slowFrames16,
      'slowFrames33': slowFrames33,
      'slowFramePct16': orderedTimings.isEmpty
          ? 0
          : (slowFrames16 * 100 / orderedTimings.length).toStringAsFixed(1),
      'dominant': _dominantLabel(
        avgBuild: _average(buildSpans),
        avgRaster: _average(rasterSpans),
        p95Build: _percentile(buildSpans, 0.95),
        p95Raster: _percentile(rasterSpans, 0.95),
      ),
      'buildDominantFrames': buildDominant,
      'rasterDominantFrames': rasterDominant,
      'counters': counters,
      'durationTotalsMicros': durationTotalsMicros,
      'durationAvgMicros': <String, String>{
        for (final entry in durationTotalsMicros.entries)
          entry.key:
              (entry.value /
                      (durationSamples[entry.key] == 0
                          ? 1
                          : durationSamples[entry.key]!))
                  .toStringAsFixed(1),
      },
    };
  }

  String _cadenceLabel({
    required double avgCadence,
    required double p95Cadence,
    required int cadenceNear60,
    required int cadenceNear30,
    required int cadenceJitter,
    required int sampleCount,
  }) {
    if (sampleCount <= 0) {
      return 'no_data';
    }

    final near60Ratio = cadenceNear60 / sampleCount;
    final near30Ratio = cadenceNear30 / sampleCount;
    final jitterRatio = cadenceJitter / sampleCount;

    if (near60Ratio >= 0.7 && p95Cadence <= 20.5) {
      return 'steady_60';
    }
    if (near30Ratio >= 0.55 && avgCadence >= 24) {
      return 'steady_30';
    }
    if (jitterRatio >= 0.3) {
      return 'jittery';
    }
    return 'mixed';
  }

  String _dominantLabel({
    required double avgBuild,
    required double avgRaster,
    required double p95Build,
    required double p95Raster,
  }) {
    if (avgBuild <= 0 && avgRaster <= 0) {
      return 'no_data';
    }

    if (avgRaster > avgBuild * 1.2 && p95Raster >= p95Build) {
      return 'raster';
    }
    if (avgBuild > avgRaster * 1.2 && p95Build >= p95Raster) {
      return 'build';
    }
    return 'mixed';
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return double.parse((total / values.length).toStringAsFixed(2));
  }

  double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = values.toList()..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return double.parse(sorted[index].toStringAsFixed(2));
  }

  double _max(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return double.parse(
      values.reduce((a, b) => a > b ? a : b).toStringAsFixed(2),
    );
  }
}

class _BenchmarkHarness {
  late final List<GameClient> clients = _buildClients();
  late final Map<String, List<InstalledAddonGroup>> _groupsByClientId =
      _buildLocalGroups();
  late final _BenchmarkClientRepository clientRepository =
      _BenchmarkClientRepository(clients);
  late final _BenchmarkAddonRegistryService registryService =
      _BenchmarkAddonRegistryService(_groupsByClientId);
  late final _BenchmarkFileSystemService fileSystemService =
      _BenchmarkFileSystemService(_groupsByClientId);
  late final _BenchmarkAddonService addonService = _BenchmarkAddonService(
    installedGroupsByClientId: _groupsByClientId,
  );

  List<Override> buildOverrides() {
    return <Override>[
      clientRepositoryProvider.overrideWithValue(clientRepository),
      fileSystemServiceProvider.overrideWithValue(fileSystemService),
      addonRegistryServiceProvider.overrideWithValue(registryService),
      addonServiceProvider.overrideWithValue(addonService),
    ];
  }

  List<GameClient> _buildClients() {
    return <GameClient>[
      GameClient(
        id: 'bench-retail',
        path: r'D:\Benchmark\Retail',
        version: '11.0.0',
        build: 'bench-11',
        type: ClientType.retail,
        productCode: 'wow',
        executableName: 'Wow.exe',
      ),
      GameClient(
        id: 'bench-classic',
        path: r'D:\Benchmark\Wrath',
        version: '3.4.3',
        build: 'bench-34',
        type: ClientType.classic,
        productCode: 'wow_classic',
        executableName: 'WowClassic.exe',
      ),
      GameClient(
        id: 'bench-legacy',
        path: r'D:\Benchmark\Cataclysm',
        version: '4.3.4',
        build: 'bench-43',
        type: ClientType.legacy,
        productCode: 'wow_legacy',
        executableName: 'WowLegacy.exe',
      ),
      GameClient(
        id: 'bench-modern',
        path: r'D:\Benchmark\Dragonflight',
        version: '10.2.7',
        build: 'bench-1027',
        type: ClientType.retail,
        productCode: 'wow',
        executableName: 'WowModern.exe',
      ),
      GameClient(
        id: 'bench-era',
        path: r'D:\Benchmark\ClassicEra',
        version: '1.15.2',
        build: 'bench-1152',
        type: ClientType.classic,
        productCode: 'wow_classic_era',
        executableName: 'WowClassicEra.exe',
      ),
      GameClient(
        id: 'bench-shadowlands',
        path: r'D:\Benchmark\Shadowlands',
        version: '9.2.7',
        build: 'bench-927',
        type: ClientType.retail,
        productCode: 'wow',
        executableName: 'WowShadowlands.exe',
      ),
    ];
  }

  Map<String, List<InstalledAddonGroup>> _buildLocalGroups() {
    final result = <String, List<InstalledAddonGroup>>{};

    for (final client in clients) {
      result[client.id] = List<InstalledAddonGroup>.generate(42, (index) {
        final id = index + 1;
        final folderName = 'BenchAddon$id';
        return InstalledAddonGroup(
          id: 'bench:$folderName',
          displayName: 'Bench Addon $id',
          providerName: id.isEven ? 'CurseForge' : 'GitHub',
          originalId: 'bench-addon-$id',
          version: '1.$id.0',
          thumbnailUrl: null,
          installedFolders: <String>[
            folderName,
            if (id % 4 == 0) '${folderName}_Core',
          ],
          isManaged: id % 3 != 0,
          folderDetails: <InstalledAddonFolder>[
            InstalledAddonFolder(
              folderName: folderName,
              displayName: 'Bench Addon $id',
              title: 'Bench Addon $id',
              tocNames: <String>[folderName],
            ),
            if (id % 4 == 0)
              InstalledAddonFolder(
                folderName: '${folderName}_Core',
                displayName: 'Bench Addon $id Core',
                title: 'Bench Addon $id Core',
                tocNames: <String>['${folderName}_Core'],
              ),
          ],
        );
      });
    }

    return result;
  }
}

class _BenchmarkClientRepository extends ClientRepository {
  final List<GameClient> _clients;

  _BenchmarkClientRepository(this._clients);

  @override
  Future<List<GameClient>> getClients() async {
    return List<GameClient>.from(_clients, growable: false);
  }

  @override
  Future<void> saveClient(GameClient client) async {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index >= 0) {
      _clients[index] = client;
      return;
    }

    _clients.add(client);
  }

  @override
  Future<void> removeClient(String id) async {
    _clients.removeWhere((client) => client.id == id);
  }
}

class _BenchmarkAddonRegistryService extends AddonRegistryService {
  final Map<String, List<InstalledAddonGroup>> _groupsByClientId;

  _BenchmarkAddonRegistryService(this._groupsByClientId);

  @override
  Future<List<InstalledAddonGroup>> loadAddonGroups(
    GameClient client,
    List<InstalledAddonFolder> scannedFolders,
  ) async {
    return List<InstalledAddonGroup>.from(
      _groupsByClientId[client.id] ?? const <InstalledAddonGroup>[],
      growable: false,
    );
  }

  @override
  Future<void> registerInstallation(
    GameClient client, {
    required AddonItem addon,
    required List<String> installedFolders,
  }) async {
    final groups = _groupsByClientId.putIfAbsent(
      client.id,
      () => <InstalledAddonGroup>[],
    );
    groups.add(
      InstalledAddonGroup(
        id: 'bench:${addon.originalId}',
        displayName: addon.name,
        providerName: addon.providerName,
        originalId: addon.originalId.toString(),
        version: addon.version,
        thumbnailUrl: addon.thumbnailUrl,
        installedFolders: installedFolders,
        isManaged: true,
      ),
    );
  }

  @override
  Future<void> removeGroup(GameClient client, InstalledAddonGroup group) async {
    _groupsByClientId[client.id]?.removeWhere((item) => item.id == group.id);
  }
}

class _BenchmarkFileSystemService implements FileSystemService {
  final Map<String, List<InstalledAddonGroup>> _groupsByClientId;

  _BenchmarkFileSystemService(this._groupsByClientId);

  @override
  Future<List<GameClient>> scanWowClients(String path) async {
    return const <GameClient>[];
  }

  @override
  Future<List<InstalledAddonFolder>> scanInstalledAddonFolders(
    GameClient client,
  ) async {
    final groups =
        _groupsByClientId[client.id] ?? const <InstalledAddonGroup>[];
    return groups
        .expand((group) {
          if (group.folderDetails.isNotEmpty) {
            return group.folderDetails;
          }

          return group.installedFolders.map(
            (folderName) => InstalledAddonFolder(
              folderName: folderName,
              displayName: folderName,
              title: group.displayName,
              tocNames: <String>[folderName],
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<AddonInstallResult> installAddonDownload(
    String downloadUrl,
    String fileName,
    GameClient client,
  ) async {
    return AddonInstallResult(
      installedFolders: <String>[fileName.replaceAll('.zip', '')],
      displayName: fileName,
    );
  }

  @override
  Future<AddonInstallResult> importAddonArchive(
    String archivePath,
    GameClient client, {
    bool replaceExisting = false,
  }) async {
    return AddonInstallResult(
      installedFolders: <String>['ImportedArchive'],
      displayName: 'Imported Archive',
    );
  }

  @override
  Future<AddonInstallResult> importAddonFolder(
    String directoryPath,
    GameClient client, {
    bool replaceExisting = false,
  }) async {
    return AddonInstallResult(
      installedFolders: <String>['ImportedFolder'],
      displayName: 'Imported Folder',
    );
  }

  @override
  Future<void> deleteAddonGroup(
    GameClient client,
    InstalledAddonGroup group,
  ) async {
    _groupsByClientId[client.id]?.removeWhere((item) => item.id == group.id);
  }

  @override
  Future<void> launchGameClient(GameClient client) async {}
}

class _BenchmarkAddonService implements AddonService {
  final AddonIdentityService _identityService = AddonIdentityService();
  final Map<String, List<InstalledAddonGroup>> installedGroupsByClientId;
  late final List<AddonItem> _catalog = _buildCatalog();

  _BenchmarkAddonService({required this.installedGroupsByClientId});

  @override
  Stream<AddonFeedState> watchSearchResults(
    String query,
    String gameVersion, {
    required String sessionKey,
    int verifiedLimit = 12,
    int concurrency = 3,
  }) {
    final lowerQuery = query.trim().toLowerCase();
    final items = _catalog
        .where((item) {
          if (lowerQuery.isEmpty) {
            return true;
          }
          return item.name.toLowerCase().contains(lowerQuery) ||
              item.summary.toLowerCase().contains(lowerQuery);
        })
        .take(verifiedLimit + 8)
        .toList(growable: false);
    return _emitProgressiveFeed(items, verifiedLimit: verifiedLimit);
  }

  @override
  Stream<AddonFeedState> watchDiscoveryFeed(
    String gameVersion, {
    required String sessionKey,
    int limit = 12,
    bool allowFallback = false,
    int concurrency = 3,
  }) {
    return _emitProgressiveFeed(
      _catalog.take(limit + 8).toList(growable: false),
      verifiedLimit: limit,
    );
  }

  @override
  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  ) async {
    return (
      url: 'https://example.invalid/${item.id}.zip',
      fileName: '${item.id}.zip',
    );
  }

  @override
  Future<AddonItem?> verifyCandidate(AddonItem item, String gameVersion) async {
    await Future<void>.delayed(const Duration(milliseconds: 24));
    return item.copyWith(
      verifiedDownloadUrl: 'https://example.invalid/${item.id}.zip',
      verifiedFileName: '${item.id}.zip',
    );
  }

  @override
  AddonInstalledMatch matchInstalledAddon(
    AddonItem item,
    List<InstalledAddonGroup> installedGroups,
  ) {
    return _identityService.matchInstalledAddon(item, installedGroups);
  }

  Stream<AddonFeedState> _emitProgressiveFeed(
    List<AddonItem> items, {
    required int verifiedLimit,
  }) async* {
    final visibleLimit = verifiedLimit.clamp(1, items.length).toInt();
    yield AddonFeedState(
      loadingPhase: AddonFeedLoadingPhase.initial,
      canLoadMore: items.length > visibleLimit,
      totalCandidates: items.length,
      targetCount: visibleLimit,
    );

    for (var index = 1; index <= visibleLimit; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
      yield AddonFeedState(
        items: items.take(index).toList(growable: false),
        loadingPhase: AddonFeedLoadingPhase.initial,
        canLoadMore: items.length > visibleLimit,
        checkedCandidates: index,
        totalCandidates: items.length,
        targetCount: visibleLimit,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 80));
    yield AddonFeedState(
      items: items.take(visibleLimit).toList(growable: false),
      loadingPhase: AddonFeedLoadingPhase.idle,
      canLoadMore: items.length > visibleLimit,
      checkedCandidates: visibleLimit,
      totalCandidates: items.length,
      targetCount: visibleLimit,
    );
  }

  List<AddonItem> _buildCatalog() {
    return List<AddonItem>.generate(28, (index) {
      final id = index + 1;
      final provider = switch (id % 3) {
        0 => 'CurseForge',
        1 => 'GitHub',
        _ => 'Wowskill',
      };
      final addonName = 'Bench Addon $id';
      return AddonItem(
        id: 'bench-addon-$id',
        name: addonName,
        summary:
            'Detailed benchmark addon card $id with deterministic discovery content for frame analysis.',
        author: provider == 'GitHub' ? 'bench-author-$id' : 'Bench Author $id',
        thumbnailUrl: null,
        screenshotUrls: const <String>[],
        providerName: provider,
        originalId: 'bench-addon-$id',
        sourceSlug: 'bench-addon-$id',
        identityHints: <String>[
          addonName,
          'BenchAddon$id',
          if (id % 4 == 0) 'BenchAddon${id}_Core',
        ],
        version: '1.$id.0',
        verifiedDownloadUrl: 'https://example.invalid/bench-addon-$id.zip',
        verifiedFileName: 'bench-addon-$id.zip',
      );
    });
  }
}

class _BenchmarkSimpleBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final Color accentColor;
  final BorderRadius borderRadius;

  const _BenchmarkSimpleBanner({
    required this.colorScheme,
    required this.accentColor,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primaryContainer,
            accentColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BenchmarkSimpleMedallion extends StatelessWidget {
  final ColorScheme colorScheme;
  final Color accentColor;
  final double size;

  const _BenchmarkSimpleMedallion({
    required this.colorScheme,
    required this.accentColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Icon(
        Icons.extension_rounded,
        color: colorScheme.onSurface,
        size: size * 0.52,
      ),
    );
  }
}
