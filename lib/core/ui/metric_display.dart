import 'package:flutter/material.dart';

import '../obd/obd_metric.dart';
import 'format.dart';

/// How each metric is shown: icon, precision and its technical name. Label
/// and unit come from [ObdMetricConfig], so every screen names a metric the
/// same way.
abstract final class MetricDisplay {
  static IconData icon(ObdMetricType type) => switch (type) {
        ObdMetricType.rpm => Icons.rotate_right_rounded,
        ObdMetricType.speed => Icons.speed_rounded,
        ObdMetricType.coolant => Icons.thermostat_rounded,
        ObdMetricType.voltage => Icons.battery_charging_full_rounded,
        ObdMetricType.throttle => Icons.open_in_full_rounded,
        ObdMetricType.engineLoad => Icons.fitness_center_rounded,
        ObdMetricType.map => Icons.compress_rounded,
        ObdMetricType.fuel => Icons.local_gas_station_rounded,
        ObdMetricType.fuelEconomy => Icons.route_rounded,
        ObdMetricType.intakeAirTemp => Icons.device_thermostat_rounded,
        ObdMetricType.maf => Icons.air_rounded,
        ObdMetricType.timingAdvance => Icons.bolt_rounded,
      };

  /// Decimals shown for the metric.
  static int decimals(ObdMetricType type) => switch (type) {
        ObdMetricType.voltage ||
        ObdMetricType.fuelEconomy ||
        ObdMetricType.maf ||
        ObdMetricType.timingAdvance =>
          1,
        _ => 0,
      };

  /// Display precision as a [LiveMetric] step: a change smaller than what is
  /// shown does not rebuild the text.
  static double step(ObdMetricType type) => decimals(type) == 1 ? 0.1 : 1;

  /// OBD name for drivers who know it, shown as secondary detail only.
  static String? technicalName(ObdMetricType type) => switch (type) {
        ObdMetricType.rpm => 'Engine RPM',
        ObdMetricType.speed => 'Vehicle speed',
        ObdMetricType.coolant => 'Coolant temperature',
        ObdMetricType.voltage => 'Control module voltage',
        ObdMetricType.throttle => 'Throttle position',
        ObdMetricType.engineLoad => 'Calculated engine load',
        ObdMetricType.map => 'MAP',
        ObdMetricType.fuel => 'Fuel tank level',
        ObdMetricType.fuelEconomy => null,
        ObdMetricType.intakeAirTemp => 'Intake air temperature',
        ObdMetricType.maf => 'MAF',
        ObdMetricType.timingAdvance => 'Timing advance',
      };

  /// The value as text, without unit: `2.063`, `13,9`.
  static String value(ObdMetricType type, double value) =>
      Fmt.number(value, decimals: decimals(type));

  /// The value with its unit: `86 °C`, `72%`.
  static String valueWithUnit(ObdMetricType type, double value) =>
      Fmt.unit(MetricDisplay.value(type, value), ObdMetricConfig.of(type).unit);
}
