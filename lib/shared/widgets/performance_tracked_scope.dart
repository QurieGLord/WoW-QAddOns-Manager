import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/app/providers/service_providers.dart';

class PerformanceTrackedScope extends ConsumerStatefulWidget {
  final String screenName;
  final Widget child;

  const PerformanceTrackedScope({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  ConsumerState<PerformanceTrackedScope> createState() =>
      _PerformanceTrackedScopeState();
}

class _PerformanceTrackedScopeState
    extends ConsumerState<PerformanceTrackedScope> {
  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!kDebugMode || !mounted) {
      return;
    }

    ref
        .read(searchTelemetryServiceProvider)
        .recordFrameTimings(widget.screenName, timings);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_handleFrameTimings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_handleFrameTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
