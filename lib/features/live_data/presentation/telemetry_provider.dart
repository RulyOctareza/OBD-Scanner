import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/obd_telemetry.dart';
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

  factory TelemetryHistoryData.empty() => TelemetryHistoryData(
        points: const [],
        totalPointsCount: 0,
      );
}

final telemetryTimeRangeProvider =
    StateProvider<TelemetryTimeRange>((ref) => TelemetryTimeRange.fiveMin);

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

final telemetryHistoryProvider =
    Provider.family<AsyncValue<TelemetryHistoryData>, ObdMetricType>((
  ref,
  metricType,
) {
  final dbAsync = ref.watch(_dbTripPointsProvider);
  final liveBuffer = ref.watch(liveChartBufferProvider);
  final timeRange = ref.watch(telemetryTimeRangeProvider);
  final liveTelemetry = ref.watch(
    obdServiceProvider.select((s) => s.telemetry),
  );

  return dbAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (dbPoints) {
      final now = DateTime.now();
      final startTime = timeRange.duration != null
          ? now.subtract(timeRange.duration!)
          : null;

      final extracted = <TelemetryPoint>[];

      for (final dp in dbPoints) {
        if (startTime != null && dp.timestamp.isBefore(startTime)) continue;
        final val = _extractMetricValue(metricType, dp);
        if (val != null && isValidChartMetricValue(metricType.name, val)) {
          extracted.add(TelemetryPoint(timestamp: dp.timestamp, value: val));
        }
      }

      for (final sample in liveBuffer) {
        if (startTime != null && sample.timestamp.isBefore(startTime)) {
          continue;
        }
        final val = sample.valueFor(metricType);
        if (val != null && isValidChartMetricValue(metricType.name, val)) {
          extracted.add(
            TelemetryPoint(timestamp: sample.timestamp, value: val),
          );
        }
      }

      // Always append freshest live value
      final liveVal = _extractLiveTelemetryValue(metricType, liveTelemetry);
      if (liveVal != null && isValidChartMetricValue(metricType.name, liveVal)) {
        extracted.add(TelemetryPoint(timestamp: now, value: liveVal));
      }

      if (extracted.isEmpty) {
        return AsyncValue.data(TelemetryHistoryData.empty());
      }

      extracted.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Deduplicate near-identical timestamps (< 200ms)
      final cleanPoints = <TelemetryPoint>[];
      DateTime? lastTime;
      for (final pt in extracted) {
        if (lastTime == null ||
            pt.timestamp.difference(lastTime).inMilliseconds >= 200) {
          cleanPoints.add(pt);
          lastTime = pt.timestamp;
        } else {
          // Replace with newer sample at same bucket
          cleanPoints[cleanPoints.length - 1] = pt;
          lastTime = pt.timestamp;
        }
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
      final currentV = liveVal ?? chartPoints.last.value;
      final isStable = (maxV - minV).abs() < 0.0001 ||
          (maxV - minV) / ((maxV.abs() < 1 ? 1 : maxV.abs())) < 0.002;

      return AsyncValue.data(
        TelemetryHistoryData(
          points: chartPoints,
          currentValue: currentV,
          minValue: minV,
          maxValue: maxV,
          avgValue: avgV,
          totalPointsCount: cleanPoints.length,
          isStable: isStable,
        ),
      );
    },
  );
});

final _dbTripPointsProvider = StreamProvider<List<TripPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tripPoints)
        ..orderBy([
          (t) => drift.OrderingTerm(
                expression: t.timestamp,
                mode: drift.OrderingMode.asc,
              ),
        ]))
      .watch();
});

double? _extractMetricValue(ObdMetricType type, TripPoint dp) {
  switch (type) {
    case ObdMetricType.rpm:
      return dp.rpm;
    case ObdMetricType.speed:
      return dp.speed;
    case ObdMetricType.coolant:
      return dp.coolant;
    case ObdMetricType.voltage:
      return dp.voltage;
    case ObdMetricType.throttle:
      return dp.throttle;
    case ObdMetricType.engineLoad:
      return dp.engineLoad;
    case ObdMetricType.map:
      return dp.mapValue;
    case ObdMetricType.fuel:
      return dp.fuel;
    case ObdMetricType.fuelEconomy:
      return dp.fuelEconomy;
    case ObdMetricType.intakeAirTemp:
      return dp.intakeAirTemp;
    case ObdMetricType.maf:
      return dp.maf;
    case ObdMetricType.timingAdvance:
      return dp.timingAdvance;
  }
}

double? _extractLiveTelemetryValue(ObdMetricType type, ObdTelemetry telemetry) {
  switch (type) {
    case ObdMetricType.rpm:
      return telemetry.rpm;
    case ObdMetricType.speed:
      return telemetry.speed;
    case ObdMetricType.coolant:
      return telemetry.coolant;
    case ObdMetricType.voltage:
      return telemetry.voltage;
    case ObdMetricType.throttle:
      return telemetry.throttle;
    case ObdMetricType.engineLoad:
      return telemetry.engineLoad;
    case ObdMetricType.map:
      return telemetry.mapValue;
    case ObdMetricType.fuel:
      return telemetry.fuelLevel;
    case ObdMetricType.fuelEconomy:
      return telemetry.fuelEconomy;
    case ObdMetricType.intakeAirTemp:
      return telemetry.intakeAirTemp;
    case ObdMetricType.maf:
      return telemetry.maf;
    case ObdMetricType.timingAdvance:
      return telemetry.timingAdvance;
  }
}
