import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';

class SearchTelemetryService {
  static const int _maxSessions = 32;
  static const int _maxFrameSnapshots = 16;

  final LinkedHashMap<String, SearchTelemetrySession> _sessions =
      LinkedHashMap<String, SearchTelemetrySession>();
  final LinkedHashMap<String, UiFrameTelemetrySnapshot> _frameSnapshots =
      LinkedHashMap<String, UiFrameTelemetrySnapshot>();

  void startSession({
    required String traceId,
    required String kind,
    required String gameVersion,
    String? query,
    required int targetCount,
  }) {
    if (!kDebugMode) {
      return;
    }

    _sessions[traceId] = SearchTelemetrySession(
      traceId: traceId,
      kind: kind,
      gameVersion: gameVersion,
      query: query,
      targetCount: targetCount,
      startedAt: DateTime.now(),
    );
    _trimSessions();
    debugPrint(
      '[SearchTelemetry][$traceId] start kind=$kind version=$gameVersion '
      'target=$targetCount query="${query ?? ''}"',
    );
  }

  void recordPhase(
    String traceId,
    String phase,
    Duration elapsed, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!kDebugMode) {
      return;
    }

    final session = _sessions[traceId];
    session?.events.add(
      SearchTelemetryEvent(
        phase: phase,
        elapsed: elapsed,
        details: Map<String, Object?>.from(details),
      ),
    );

    final detailsText = details.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
      '[SearchTelemetry][$traceId] $phase '
      '${elapsed.inMilliseconds}ms'
      '${detailsText.isEmpty ? '' : ' $detailsText'}',
    );
  }

  void recordStateEmission(
    String traceId,
    AddonFeedState state,
    Duration elapsed,
  ) {
    if (!kDebugMode) {
      return;
    }

    final session = _sessions[traceId];
    if (session == null) {
      return;
    }

    session.emissionCount += 1;
    if (!session.firstVisibleRecorded && state.items.isNotEmpty) {
      session.firstVisibleRecorded = true;
      recordPhase(
        traceId,
        'first_visible_result',
        elapsed,
        details: <String, Object?>{'visibleItems': state.items.length},
      );
    }

    if (!session.pageCompleteRecorded &&
        state.items.length >= session.targetCount) {
      session.pageCompleteRecorded = true;
      recordPhase(
        traceId,
        'page_complete',
        elapsed,
        details: <String, Object?>{'visibleItems': state.items.length},
      );
    }

    if (!session.loadMoreReadyRecorded && state.canLoadMore) {
      session.loadMoreReadyRecorded = true;
      recordPhase(
        traceId,
        'load_more_ready',
        elapsed,
        details: <String, Object?>{'visibleItems': state.items.length},
      );
    }

    recordPhase(
      traceId,
      'state_emission',
      elapsed,
      details: <String, Object?>{
        'phase': state.loadingPhase.name,
        'items': state.items.length,
        'canLoadMore': state.canLoadMore,
        'emissions': session.emissionCount,
      },
    );
  }

  void finishSession(String traceId, Duration elapsed, {Object? error}) {
    if (!kDebugMode) {
      return;
    }

    final session = _sessions[traceId];
    if (session == null) {
      return;
    }

    session.finishedAt = DateTime.now();
    if (error != null) {
      session.error = error.toString();
    }

    recordPhase(
      traceId,
      error == null ? 'session_complete' : 'session_error',
      elapsed,
      details: <String, Object?>{
        'emissions': session.emissionCount,
        if (error != null) 'error': error.toString(),
      },
    );
  }

  void recordFrameTimings(String screenName, List<FrameTiming> timings) {
    if (!kDebugMode || timings.isEmpty) {
      return;
    }

    var totalBuildMicros = 0;
    var totalRasterMicros = 0;
    var slowFrames = 0;
    for (final timing in timings) {
      totalBuildMicros += timing.buildDuration.inMicroseconds;
      totalRasterMicros += timing.rasterDuration.inMicroseconds;
      if (timing.totalSpan.inMilliseconds >= 16) {
        slowFrames += 1;
      }
    }

    final sampleCount = timings.length;
    final snapshot = UiFrameTelemetrySnapshot(
      screenName: screenName,
      sampledAt: DateTime.now(),
      averageBuild: Duration(microseconds: totalBuildMicros ~/ sampleCount),
      averageRaster: Duration(microseconds: totalRasterMicros ~/ sampleCount),
      slowFrameCount: slowFrames,
      sampleCount: sampleCount,
    );

    _frameSnapshots[screenName] = snapshot;
    while (_frameSnapshots.length > _maxFrameSnapshots) {
      _frameSnapshots.remove(_frameSnapshots.keys.first);
    }

    debugPrint(
      '[FrameTelemetry][$screenName] samples=$sampleCount '
      'avgBuild=${snapshot.averageBuild.inMilliseconds}ms '
      'avgRaster=${snapshot.averageRaster.inMilliseconds}ms '
      'slowFrames=$slowFrames',
    );
  }

  SearchTelemetrySession? latestSession(String traceId) {
    return _sessions[traceId];
  }

  UiFrameTelemetrySnapshot? latestFrameSnapshot(String screenName) {
    return _frameSnapshots[screenName];
  }

  void _trimSessions() {
    while (_sessions.length > _maxSessions) {
      _sessions.remove(_sessions.keys.first);
    }
  }
}

class SearchTelemetrySession {
  final String traceId;
  final String kind;
  final String gameVersion;
  final String? query;
  final int targetCount;
  final DateTime startedAt;
  final List<SearchTelemetryEvent> events = <SearchTelemetryEvent>[];

  DateTime? finishedAt;
  String? error;
  int emissionCount = 0;
  bool firstVisibleRecorded = false;
  bool pageCompleteRecorded = false;
  bool loadMoreReadyRecorded = false;

  SearchTelemetrySession({
    required this.traceId,
    required this.kind,
    required this.gameVersion,
    required this.query,
    required this.targetCount,
    required this.startedAt,
  });
}

class SearchTelemetryEvent {
  final String phase;
  final Duration elapsed;
  final Map<String, Object?> details;

  const SearchTelemetryEvent({
    required this.phase,
    required this.elapsed,
    required this.details,
  });
}

class UiFrameTelemetrySnapshot {
  final String screenName;
  final DateTime sampledAt;
  final Duration averageBuild;
  final Duration averageRaster;
  final int slowFrameCount;
  final int sampleCount;

  const UiFrameTelemetrySnapshot({
    required this.screenName,
    required this.sampledAt,
    required this.averageBuild,
    required this.averageRaster,
    required this.slowFrameCount,
    required this.sampleCount,
  });
}
