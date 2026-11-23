import '../obd/obd_metric.dart';
import '../widgets/live_obd.dart' show MetricReading;
import 'status.dart';

/// The one set of thresholds for live values. Health checks, Live tiles,
/// gauges and the cockpit all judge a value here, so the same reading never
/// looks normal on one screen and critical on another.
abstract final class MetricThresholds {
  /// Above this the engine counts as running (a typical idle is 700–950 rpm).
  static const double engineRunningRpm = 500;

  /// Coolant above this is warm, above [coolantHigh] high, above
  /// [coolantCritical] an overheating engine.
  static const double coolantWarm = 100;
  static const double coolantHigh = 105;
  static const double coolantCritical = 115;

  /// Below this, with the engine running, the alternator is not charging.
  static const double chargingMinVolts = 12.8;

  /// Below this, with the engine off, the battery is weak.
  static const double batteryMinVolts = 11.8;

  /// Fuel level below these percentages is low, then nearly empty.
  static const double fuelLowPercent = 15;
  static const double fuelReservePercent = 7;

  /// Idle outside this band (vehicle stopped, engine running) is unstable.
  static const double idleMinRpm = 650;
  static const double idleMaxRpm = 1100;

  /// Start of the rev limit band on the RPM gauge (small petrol engines).
  static const double rpmRedline = 6000;
}

bool isEngineRunning(double rpm) => rpm > MetricThresholds.engineRunningRpm;

/// A judged value: its level and a short note such as "Hangat".
class MetricAssessment {
  const MetricAssessment(this.level, [this.note]);

  final StatusLevel level;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is MetricAssessment && other.level == level && other.note == note;

  @override
  int get hashCode => Object.hash(level, note);

  @override
  String toString() => 'MetricAssessment($level, $note)';
}

const _noData = MetricAssessment(StatusLevel.noData);

MetricAssessment assessCoolant(double celsius) {
  // The coolant PID cannot report 0 °C as a real engine value here: 0 is
  // what the app holds before the first answer.
  if (celsius <= 0) return _noData;
  if (celsius > MetricThresholds.coolantCritical) {
    return const MetricAssessment(StatusLevel.kritis, 'Sangat tinggi');
  }
  if (celsius > MetricThresholds.coolantHigh) {
    return const MetricAssessment(StatusLevel.waspada, 'Tinggi');
  }
  if (celsius > MetricThresholds.coolantWarm) {
    return const MetricAssessment(StatusLevel.waspada, 'Hangat');
  }
  return const MetricAssessment(StatusLevel.ok, 'Normal');
}

MetricAssessment assessVoltage(double volts, {required bool engineRunning}) {
  if (volts <= 0) return _noData;
  if (engineRunning) {
    return volts < MetricThresholds.chargingMinVolts
        ? const MetricAssessment(StatusLevel.waspada, 'Pengisian lemah')
        : const MetricAssessment(StatusLevel.ok, 'Pengisian normal');
  }
  return volts < MetricThresholds.batteryMinVolts
      ? const MetricAssessment(StatusLevel.waspada, 'Aki lemah')
      : const MetricAssessment(StatusLevel.ok, 'Aki normal');
}

MetricAssessment assessFuelLevel(double percent) {
  if (percent < MetricThresholds.fuelReservePercent) {
    return const MetricAssessment(StatusLevel.kritis, 'Hampir habis');
  }
  if (percent < MetricThresholds.fuelLowPercent) {
    return const MetricAssessment(StatusLevel.waspada, 'Menipis');
  }
  return const MetricAssessment(StatusLevel.ok);
}

/// Judges [value] of [type]. Metrics without a health meaning (speed, load,
/// throttle…) are always ok. [engineRunning] changes what a normal battery
/// voltage is (see [isEngineRunning]).
MetricAssessment assessMetric(
  ObdMetricType type,
  double value, {
  bool engineRunning = false,
}) {
  return switch (type) {
    ObdMetricType.coolant => assessCoolant(value),
    ObdMetricType.voltage => assessVoltage(value, engineRunning: engineRunning),
    ObdMetricType.fuel => assessFuelLevel(value),
    _ => const MetricAssessment(StatusLevel.ok),
  };
}

/// Judges a live reading: no data while pending, unsupported when the car
/// does not report the metric.
MetricAssessment assessReading(
  ObdMetricType type,
  MetricReading reading, {
  bool engineRunning = false,
}) {
  if (reading.isUnsupported) {
    return const MetricAssessment(StatusLevel.unsupported);
  }
  if (!reading.hasValue) return _noData;
  return assessMetric(type, reading.value!, engineRunning: engineRunning);
}

/// Metrics whose judgement depends on whether the engine runs.
bool assessmentNeedsRpm(ObdMetricType type) => type == ObdMetricType.voltage;

/// A band of a gauge scale and the level it stands for.
typedef GaugeZoneSpec = ({double from, double to, StatusLevel level});

/// Bands marked on a metric's gauge, from the same thresholds that judge its
/// value, so the dial and the readout agree. Voltage has none: whether a
/// voltage is low depends on the engine running, which the scale cannot show.
List<GaugeZoneSpec> gaugeZoneSpec(ObdMetricType type, {required double max}) {
  return switch (type) {
    ObdMetricType.rpm => [
        (from: MetricThresholds.rpmRedline, to: max, level: StatusLevel.waspada),
      ],
    ObdMetricType.coolant => [
        (
          from: MetricThresholds.coolantWarm,
          to: MetricThresholds.coolantCritical,
          level: StatusLevel.waspada,
        ),
        (from: MetricThresholds.coolantCritical, to: max, level: StatusLevel.kritis),
      ],
    ObdMetricType.fuel => [
        (from: 0, to: MetricThresholds.fuelReservePercent, level: StatusLevel.kritis),
        (
          from: MetricThresholds.fuelReservePercent,
          to: MetricThresholds.fuelLowPercent,
          level: StatusLevel.waspada,
        ),
      ],
    _ => const [],
  };
}
