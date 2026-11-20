import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/obd_telemetry.dart';
import 'widgets/gauge_widget.dart';

/// In-memory ring buffer of live OBD samples for charts.
/// Independent from trip DB writes (which are throttled to ~30s).
class LiveChartBuffer extends StateNotifier<List<TelemetryPointBundle>> {
  LiveChartBuffer(this._ref) : super(const []) {
    // 1 Hz is enough for charts and halves CPU/GC vs 500ms.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sample();
    });
    _sample();
  }

  final Ref _ref;
  Timer? _timer;
  static const int _maxSamples = 3600; // ~1 hour at 1s

  void _sample() {
    final obd = _ref.read(obdServiceProvider);
    if (obd.status != ObdStatus.connected &&
        obd.status != ObdStatus.initializing) {
      return;
    }
    final bundle = TelemetryPointBundle.fromTelemetry(obd.telemetry);
    final next = [...state, bundle];
    if (next.length > _maxSamples) {
      state = next.sublist(next.length - _maxSamples);
    } else {
      state = next;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class TelemetryPointBundle {
  final DateTime timestamp;
  final double rpm;
  final double speed;
  final double coolant;
  final double voltage;
  final double throttle;
  final double engineLoad;
  final double mapValue;
  final double? fuel;
  final double? fuelEconomy;
  final double? intakeAirTemp;
  final double? maf;
  final double? timingAdvance;

  TelemetryPointBundle({
    required this.timestamp,
    required this.rpm,
    required this.speed,
    required this.coolant,
    required this.voltage,
    required this.throttle,
    required this.engineLoad,
    required this.mapValue,
    this.fuel,
    this.fuelEconomy,
    this.intakeAirTemp,
    this.maf,
    this.timingAdvance,
  });

  factory TelemetryPointBundle.fromTelemetry(ObdTelemetry t) {
    return TelemetryPointBundle(
      timestamp: DateTime.now(),
      rpm: t.rpm,
      speed: t.speed,
      coolant: t.coolant,
      voltage: t.voltage,
      throttle: t.throttle,
      engineLoad: t.engineLoad,
      mapValue: t.mapValue,
      fuel: t.fuelLevel,
      fuelEconomy: t.fuelEconomy,
      intakeAirTemp: t.intakeAirTemp,
      maf: t.maf,
      timingAdvance: t.timingAdvance,
    );
  }

  double? valueFor(ObdMetricType type) {
    switch (type) {
      case ObdMetricType.rpm:
        return rpm;
      case ObdMetricType.speed:
        return speed;
      case ObdMetricType.coolant:
        return coolant;
      case ObdMetricType.voltage:
        return voltage;
      case ObdMetricType.throttle:
        return throttle;
      case ObdMetricType.engineLoad:
        return engineLoad;
      case ObdMetricType.map:
        return mapValue;
      case ObdMetricType.fuel:
        return fuel;
      case ObdMetricType.fuelEconomy:
        return fuelEconomy;
      case ObdMetricType.intakeAirTemp:
        return intakeAirTemp;
      case ObdMetricType.maf:
        return maf;
      case ObdMetricType.timingAdvance:
        return timingAdvance;
    }
  }
}

final liveChartBufferProvider =
    StateNotifierProvider.autoDispose<LiveChartBuffer,
        List<TelemetryPointBundle>>((ref) {
  // Disposes when no screen is watching — avoids forever 1Hz sampling.
  return LiveChartBuffer(ref);
});
