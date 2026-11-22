import 'package:flutter/painting.dart' show Color;

import 'obd_telemetry.dart';

enum ObdMetricType {
  rpm,
  speed,
  coolant,
  voltage,
  throttle,
  engineLoad,
  map,
  fuel,
  fuelEconomy,
  intakeAirTemp,
  maf,
  timingAdvance,
}

class ObdMetricConfig {
  final ObdMetricType type;
  final String label;
  final String unit;
  final double minValue;
  final double maxValue;
  final double warningThreshold;
  final Color color;

  const ObdMetricConfig({
    required this.type,
    required this.label,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.warningThreshold,
    required this.color,
  });

  /// Config of [type]. [all] is in [ObdMetricType] order, so this is an index.
  static ObdMetricConfig of(ObdMetricType type) => all[type.index];

  /// One entry per [ObdMetricType], in enum order ([of] relies on it).
  static const List<ObdMetricConfig> all = [
    ObdMetricConfig(
      type: ObdMetricType.rpm,
      label: 'Putaran Mesin',
      unit: 'RPM',
      minValue: 0,
      maxValue: 8000,
      warningThreshold: 6000,
      color: Color(0xFF00FFCC),
    ),
    ObdMetricConfig(
      type: ObdMetricType.speed,
      label: 'Kecepatan',
      unit: 'km/h',
      minValue: 0,
      maxValue: 220,
      warningThreshold: 110,
      color: Color(0xFF00E5FF),
    ),
    ObdMetricConfig(
      type: ObdMetricType.coolant,
      label: 'Suhu Pendingin',
      unit: '°C',
      minValue: 50,
      maxValue: 130,
      warningThreshold: 100,
      color: Color(0xFFFF9900),
    ),
    ObdMetricConfig(
      type: ObdMetricType.voltage,
      label: 'Tegangan Aki',
      unit: 'V',
      minValue: 9,
      maxValue: 16,
      warningThreshold: 11.5,
      color: Color(0xFFD400FF),
    ),
    ObdMetricConfig(
      type: ObdMetricType.throttle,
      label: 'Bukaan Gas',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 90,
      color: Color(0xFF33FF33),
    ),
    ObdMetricConfig(
      type: ObdMetricType.engineLoad,
      label: 'Beban Mesin',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 85,
      color: Color(0xFFFF007F),
    ),
    ObdMetricConfig(
      type: ObdMetricType.map,
      label: 'Tekanan Intake',
      unit: 'kPa',
      minValue: 20,
      maxValue: 150,
      warningThreshold: 130,
      color: Color(0xFFFFD700),
    ),
    ObdMetricConfig(
      type: ObdMetricType.fuel,
      label: 'Level BBM',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 15,
      color: Color(0xFFFFB300),
    ),
    ObdMetricConfig(
      type: ObdMetricType.fuelEconomy,
      label: 'Konsumsi BBM',
      unit: 'km/L',
      minValue: 0,
      maxValue: 30,
      warningThreshold: 5,
      color: Color(0xFF00FF66),
    ),
    ObdMetricConfig(
      type: ObdMetricType.intakeAirTemp,
      label: 'Suhu Intake',
      unit: '°C',
      minValue: -20,
      maxValue: 100,
      warningThreshold: 70,
      color: Color(0xFF4FC3F7),
    ),
    ObdMetricConfig(
      type: ObdMetricType.maf,
      label: 'Aliran Udara',
      unit: 'g/s',
      minValue: 0,
      maxValue: 200,
      warningThreshold: 150,
      color: Color(0xFF80CBC4),
    ),
    ObdMetricConfig(
      type: ObdMetricType.timingAdvance,
      label: 'Timing Advance',
      unit: '°',
      minValue: -30,
      maxValue: 60,
      warningThreshold: 45,
      color: Color(0xFFFFEE58),
    ),
  ];
}

/// The live value of [type] in [telemetry]; null when the car never sent it.
double? metricValue(ObdTelemetry telemetry, ObdMetricType type) {
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
