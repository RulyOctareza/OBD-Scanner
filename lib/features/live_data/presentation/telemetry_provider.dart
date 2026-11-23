import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/performance_utils.dart';
import 'live_chart_buffer.dart';
import 'widgets/gauge_widget.dart';

enum TelemetryTimeRange {
  oneMin('1m', Duration(minutes: 1)),
  fiveMin('5m', Duration(minutes: 5)),
  fifteenMin('15m', Duration(minutes: 15)),
  oneHour('1h', Duration(hours: 1)),
  all('Semua', null);

  final String label;
  final Duration? duration;

  const TelemetryTimeRange(this.label, this.duration);
}

class TelemetryPoint {
  final DateTime timestamp;
  final double value;

  TelemetryPoint({required this.timestamp, required this.value});
}

class TelemetryHistoryData {
  final List<TelemetryPoint> points;
  final double? currentValue;
  final double? minValue;
  final double? maxValue;
  final double? avgValue;
  final int totalPointsCount;
  final bool isStable;

  TelemetryHistoryData({
    required this.points,
    this.currentValue,
    this.minValue,
    this.maxValue,
    this.avgValue,
    required this.totalPointsCount,
    this.isStable = false,
  });

  factory TelemetryHistoryData.empty() =>
      TelemetryHistoryData(points: const [], totalPointsCount: 0);
}

final telemetryTimeRangeProvider = StateProvider<TelemetryTimeRange>(
  (ref) => TelemetryTimeRange.fiveMin,
);

/// Computes chart-friendly Y-axis bounds for a metric series.
({double minY, double maxY}) computeChartYBounds({
  required double minValue,
  required double maxValue,
  required double metricMin,
  required double metricMax,
}) {
  final span = (maxValue - minValue).abs();
  final fullScale = (metricMax - metricMin).abs();
  final pad = [
    span * 0.2,
    fullScale * 0.06,
    span < 0.001 ? fullScale * 0.08 : 0.0,
  ].reduce((a, b) => a > b ? a : b);

  var minY = minValue - pad;
  var maxY = maxValue + pad;

  // Soft floor near metric operating band when data itself is in-band
  // (avoids stretching to 0 when a stray low value slipped through).
  if (minValue >= metricMin * 0.85) {
    final softFloor = metricMin - fullScale * 0.08;
    if (minY < softFloor) minY = softFloor;
  }
  final softCeil = metricMax + fullScale * 0.08;
  if (maxY > softCeil) maxY = softCeil;

  if (maxY - minY < 1.0) {
    final mid = (minValue + maxValue) / 2;
    minY = mid - 0.5;
    maxY = mid + 0.5;
  }

  return (minY: minY, maxY: maxY);
}

/// Chart series for one metric: stored trip points in the selected range,
/// then the live 1 Hz buffer. It recomputes when the buffer samples, once a
/// second while a chart is open, never per PID response, and is disposed
/// with the chart together with the buffer and the stored series.
final telemetryHistoryProvider = Provider.autoDispose
    .family<AsyncValue<TelemetryHistoryData>, ObdMetricType>((ref, metricType) {
      final timeRange = ref.watch(telemetryTimeRangeProvider);
      final storedAsync = ref.watch(
        storedSeriesProvider((metricType, timeRange)),
      );
      final liveBuffer = ref.watch(liveChartBufferProvider);

      if (storedAsync.hasError) {
        return AsyncValue.error(storedAsync.error!, storedAsync.stackTrace!);
      }
      final stored = storedAsync.valueOrNull;
      // Live samples are shown while the stored series is still loading.
      if (stored == null && liveBuffer.isEmpty)
        return const AsyncValue.loading();
      return AsyncValue.data(
        buildTelemetryHistory(
          metricType: metricType,
          timeRange: timeRange,
          stored: stored ?? const [],
          live: liveBuffer,
          now: clock.now(),
        ),
      );
    });

/// The cleaning pipeline of the chart (book telemetry/chart_history):
/// range filter, validity filter, merge by time, collapse samples closer than
/// 200 ms, pad a single point, downsample to 200, stats. [stored] and [live]
/// are each in time order.
TelemetryHistoryData buildTelemetryHistory({
  required ObdMetricType metricType,
  required TelemetryTimeRange timeRange,
  required List<TelemetryPoint> stored,
  required List<TelemetryPointBundle> live,
  required DateTime now,
}) {
  final startTime = timeRange.duration != null
      ? now.subtract(timeRange.duration!)
      : null;
  bool inRange(DateTime t) => startTime == null || !t.isBefore(startTime);

  final fromStore = [
    for (final point in stored)
      if (inRange(point.timestamp)) point,
  ];
  final fromLive = <TelemetryPoint>[];
  for (final sample in live) {
    if (!inRange(sample.timestamp)) continue;
    final value = sample.valueFor(metricType);
    if (value != null && isValidChartMetricValue(metricType.name, value)) {
      fromLive.add(TelemetryPoint(timestamp: sample.timestamp, value: value));
    }
  }

  // Both lists are in time order: a merge instead of a sort.
  final merged = <TelemetryPoint>[];
  var i = 0;
  var j = 0;
  while (i < fromStore.length || j < fromLive.length) {
    if (j >= fromLive.length ||
        (i < fromStore.length &&
            !fromStore[i].timestamp.isAfter(fromLive[j].timestamp))) {
      merged.add(fromStore[i++]);
    } else {
      merged.add(fromLive[j++]);
    }
  }
  if (merged.isEmpty) return TelemetryHistoryData.empty();

  final cleanPoints = <TelemetryPoint>[];
  DateTime? lastTime;
  for (final pt in merged) {
    if (lastTime == null ||
        pt.timestamp.difference(lastTime).inMilliseconds >= 200) {
      cleanPoints.add(pt);
    } else {
      // Replace with newer sample at same bucket
      cleanPoints[cleanPoints.length - 1] = pt;
    }
    lastTime = pt.timestamp;
  }

  if (cleanPoints.length == 1) {
    final p0 = cleanPoints.first;
    cleanPoints.insert(
      0,
      TelemetryPoint(
        timestamp: p0.timestamp.subtract(const Duration(seconds: 15)),
        value: p0.value,
      ),
    );
  }

  final chartPoints = downsamplePoints(cleanPoints, maxPoints: 200);
  final values = chartPoints.map((e) => e.value).toList();
  final minV = values.reduce((a, b) => a < b ? a : b);
  final maxV = values.reduce((a, b) => a > b ? a : b);
  final avgV = values.reduce((a, b) => a + b) / values.length;
  final currentV = fromLive.isNotEmpty
      ? fromLive.last.value
      : chartPoints.last.value;
  final isStable =
      (maxV - minV).abs() < 0.0001 ||
      (maxV - minV) / ((maxV.abs() < 1 ? 1 : maxV.abs())) < 0.002;

  return TelemetryHistoryData(
    points: chartPoints,
    currentValue: currentV,
    minValue: minV,
    maxValue: maxV,
    avgValue: avgV,
    totalPointsCount: cleanPoints.length,
    isStable: isStable,
  );
}

/// Rows the "Semua" range reads at most; downsampling keeps 200 of them.
const _allRangeBuckets = 400;

/// Stored trip points of one metric in one range, read once per chart
/// opening: only timestamp and that column, only the range. Points recorded
/// while the chart is open reach it at a higher rate through the live buffer,
/// so watching the table would repeat work on every insert.
@visibleForTesting
final storedSeriesProvider = FutureProvider.autoDispose
    .family<List<TelemetryPoint>, (ObdMetricType, TelemetryTimeRange)>((
      ref,
      key,
    ) async {
      final (metricType, timeRange) = key;
      final db = ref.watch(databaseProvider);
      final column = _tripPointColumn(db, metricType).name;
      final duration = timeRange.duration;

      final List<drift.QueryRow> rows;
      if (duration != null) {
        rows = await db
            .customSelect(
              'SELECT timestamp AS t, $column AS v FROM trip_points '
              'WHERE $column IS NOT NULL AND timestamp >= ? ORDER BY timestamp',
              variables: [
                drift.Variable<DateTime>(clock.now().subtract(duration)),
              ],
              readsFrom: {db.tripPoints},
            )
            .get();
      } else {
        // "Semua" spans every trip ever recorded, so it is bucketed in SQL.
        // Timestamps are unix seconds; with a bare column next to MAX(), SQLite
        // returns that column from the newest row of each bucket.
        final span = await db
            .customSelect(
              'SELECT MIN(timestamp) AS a, MAX(timestamp) AS b FROM trip_points '
              'WHERE $column IS NOT NULL',
              readsFrom: {db.tripPoints},
            )
            .getSingle();
        final first = span.readNullable<int>('a');
        final last = span.readNullable<int>('b');
        if (first == null || last == null) return const [];
        final bucket = math.max(1, ((last - first) / _allRangeBuckets).ceil());
        rows = await db
            .customSelect(
              'SELECT MAX(timestamp) AS t, $column AS v FROM trip_points '
              'WHERE $column IS NOT NULL GROUP BY timestamp / ? ORDER BY t',
              variables: [drift.Variable.withInt(bucket)],
              readsFrom: {db.tripPoints},
            )
            .get();
      }

      return [
        for (final row in rows)
          if (isValidChartMetricValue(metricType.name, row.read<double>('v')))
            TelemetryPoint(
              timestamp: row.read<DateTime>('t'),
              value: row.read<double>('v'),
            ),
      ];
    });

drift.GeneratedColumn<double> _tripPointColumn(
  AppDatabase db,
  ObdMetricType type,
) {
  final t = db.tripPoints;
  switch (type) {
    case ObdMetricType.rpm:
      return t.rpm;
    case ObdMetricType.speed:
      return t.speed;
    case ObdMetricType.coolant:
      return t.coolant;
    case ObdMetricType.voltage:
      return t.voltage;
    case ObdMetricType.throttle:
      return t.throttle;
    case ObdMetricType.engineLoad:
      return t.engineLoad;
    case ObdMetricType.map:
      return t.mapValue;
    case ObdMetricType.fuel:
      return t.fuel;
    case ObdMetricType.fuelEconomy:
      return t.fuelEconomy;
    case ObdMetricType.intakeAirTemp:
      return t.intakeAirTemp;
    case ObdMetricType.maf:
      return t.maf;
    case ObdMetricType.timingAdvance:
      return t.timingAdvance;
  }
}
