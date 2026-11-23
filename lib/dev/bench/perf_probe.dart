// Dev-only benchmark probe (see lib/dev/bench/bench_main.dart).
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FrameTiming, FramePhase;

import 'package:flutter/scheduler.dart';

/// USER_HZ of Android/Linux kernels: /proc tick counts are in 1/100 s.
const int _ticksPerSecond = 100;

/// Frame budget of the 60 Hz reference phone.
const double _budgetMs = 1000 / 60;

/// CPU time (utime + stime) of every thread of this process, in ticks, from
/// /proc/self/stat. /proc/uptime is not readable by apps on Samsung Android 10
/// (SELinux), so startup time is taken on the host from `am start -W`.
int processCpuTicks() {
  final raw = File('/proc/self/stat').readAsStringSync();
  // Fields after "(comm)": index 0 is field 3 (state).
  final f = raw.substring(raw.lastIndexOf(')') + 2).split(' ');
  return int.parse(f[11]) + int.parse(f[12]);
}

/// Collects every reported frame for the whole run. Frame timings arrive in
/// batches (about once a second in profile builds), so windows select frames
/// by their vsync timestamp instead of by arrival.
class PerfProbe {
  final List<FrameTiming> _frames = [];

  void start() => SchedulerBinding.instance.addTimingsCallback(_frames.addAll);

  PerfWindow open(String name) => PerfWindow._(this, name);

  /// The first reported frame whose vsync came at or after [micros].
  FrameTiming? firstFrameAfter(int micros) {
    for (final frame in _frames) {
      if (frame.timestampInMicroseconds(FramePhase.vsyncStart) >= micros) {
        return frame;
      }
    }
    return null;
  }
}

class PerfWindow {
  PerfWindow._(this._probe, this.name)
    : _startMicros = Timeline.now,
      _cpuStart = processCpuTicks(),
      _wall = Stopwatch()..start();

  final PerfProbe _probe;
  final String name;
  final int _startMicros;
  final int _cpuStart;
  final Stopwatch _wall;

  /// Ends the window and summarizes it. Waits for the last timing batch.
  Future<Map<String, Object>> close() async {
    final endMicros = Timeline.now;
    final cpuEnd = processCpuTicks();
    _wall.stop();
    final seconds = _wall.elapsedMicroseconds / 1e6;
    final rssMb = ProcessInfo.currentRss / (1024 * 1024);
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final frames = _probe._frames.where((f) {
      final vsync = f.timestampInMicroseconds(FramePhase.vsyncStart);
      return vsync >= _startMicros && vsync <= endMicros;
    }).toList();
    final build =
        frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final raster =
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    final janky = frames
        .where(
          (f) =>
              f.buildDuration.inMicroseconds / 1000 > _budgetMs ||
              f.rasterDuration.inMicroseconds / 1000 > _budgetMs,
        )
        .length;

    double avg(List<double> v) =>
        v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    double pct(List<double> v, double p) =>
        v.isEmpty ? 0 : v[((v.length - 1) * p).round()];
    double r2(double v) => (v * 100).roundToDouble() / 100;

    return {
      'scenario': name,
      'seconds': r2(seconds),
      'frames': frames.length,
      'fps': r2(frames.length / seconds),
      'build_avg_ms': r2(avg(build)),
      'build_p90_ms': r2(pct(build, 0.9)),
      'build_p99_ms': r2(pct(build, 0.99)),
      'raster_avg_ms': r2(avg(raster)),
      'raster_p90_ms': r2(pct(raster, 0.9)),
      'raster_p99_ms': r2(pct(raster, 0.99)),
      'jank_pct': r2(frames.isEmpty ? 0 : janky * 100 / frames.length),
      'cpu_pct': r2((cpuEnd - _cpuStart) / _ticksPerSecond / seconds * 100),
      'rss_mb': r2(rssMb),
    };
  }
}
