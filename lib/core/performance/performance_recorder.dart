import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

enum PerformanceMilestone { firstFrame, bootstrapReady, dashboardReady }

/// Opt-in profiling only. Default release builds eliminate the disabled path.
class PerformanceRecorder with WidgetsBindingObserver {
  PerformanceRecorder._();
  static const enabled = bool.fromEnvironment('HYNER_PERF');
  static final _instance = PerformanceRecorder._();
  final _frames = FramePerformanceWindow();
  final _marks = <PerformanceMilestone>{};
  final _pendingMarks = <PerformanceMilestone>{};
  Stopwatch? _startup;
  bool _initialized = false;
  int _received = 0;
  final _runId = DateTime.now().microsecondsSinceEpoch;

  static void initialize(Stopwatch? started) {
    if (!enabled || _instance._initialized) return;
    final value = _instance;
    value._initialized = true;
    value._startup = started ?? (Stopwatch()..start());
    WidgetsBinding.instance.addObserver(value);
    WidgetsBinding.instance.addTimingsCallback(value._recordFrames);
    afterFrame(PerformanceMilestone.firstFrame);
  }

  static void mark(PerformanceMilestone phase) {
    if (!enabled || !_instance._initialized || !_instance._marks.add(phase)) {
      return;
    }
    _instance._emit({
      'event': 'milestone',
      'phase': phase.name,
      'elapsed_us': _instance._startup!.elapsedMicroseconds,
    });
  }

  static void afterFrame(PerformanceMilestone phase) {
    if (!enabled ||
        !_instance._initialized ||
        _instance._marks.contains(phase) ||
        !_instance._pendingMarks.add(phase)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _instance._pendingMarks.remove(phase);
      mark(phase);
    });
  }

  void _recordFrames(List<ui.FrameTiming> timings) {
    for (final frame in timings) {
      _frames.add(
        frame.buildDuration.inMicroseconds,
        frame.rasterDuration.inMicroseconds,
      );
      _received++;
    }
    if (_received >= 120) {
      _received = 0;
      _emit({'event': 'frames', ..._frames.summary});
    }
  }

  void _emit(Map<String, Object> event) {
    developer.Timeline.instantSync('Hyner.performance', arguments: event);
    debugPrint('HYNER_PERF ${jsonEncode({'run_id': _runId, ...event})}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _frames.length > 0) {
      _emit({'event': 'frames', ..._frames.summary});
    }
  }
}

/// Fixed-size rolling statistics, not an unbounded recording of a long session.
class FramePerformanceWindow {
  FramePerformanceWindow({this.capacity = 240}) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }
  final int capacity;
  final _samples = ListQueue<(int, int)>();
  int get length => _samples.length;
  void add(int buildUs, int rasterUs) {
    if (_samples.length == capacity) _samples.removeFirst();
    _samples.add((buildUs, rasterUs));
  }

  Map<String, Object> get summary {
    final build = _samples.map((e) => e.$1).toList()..sort();
    final raster = _samples.map((e) => e.$2).toList()..sort();
    int percentile(List<int> values, double fraction) =>
        values.isEmpty ? 0 : values[(fraction * values.length).ceil() - 1];
    return {
      'samples': length,
      'build_p50_us': percentile(build, .5),
      'build_p95_us': percentile(build, .95),
      'build_p99_us': percentile(build, .99),
      'raster_p50_us': percentile(raster, .5),
      'raster_p95_us': percentile(raster, .95),
      'raster_p99_us': percentile(raster, .99),
      'over_60hz_stage_budget_samples': _samples
          .where((e) => e.$1 > 16667 || e.$2 > 16667)
          .length,
    };
  }
}
