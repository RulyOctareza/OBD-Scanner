class ObdTelemetry {
  final double rpm;
  final double speed;
  final double coolant;
  final double voltage;
  final double mapValue;
  final double throttle;
  final double engineLoad;
  final double? intakeAirTemp;
  final double? maf;
  final double? timingAdvance;
  final List<String> dtcs;
  final double? odometer;
  final double fuelLevel;
  final DateTime timestamp;

  ObdTelemetry({
    required this.rpm,
    required this.speed,
    required this.coolant,
    required this.voltage,
    required this.mapValue,
    required this.throttle,
    required this.engineLoad,
    this.intakeAirTemp,
    this.maf,
    this.timingAdvance,
    required this.dtcs,
    this.odometer,
    required this.fuelLevel,
    required this.timestamp,
  });

  factory ObdTelemetry.empty() {
    return ObdTelemetry(
      rpm: 0.0,
      speed: 0.0,
      coolant: 0.0,
      voltage: 0.0,
      mapValue: 0.0,
      throttle: 0.0,
      engineLoad: 0.0,
      intakeAirTemp: null,
      maf: null,
      timingAdvance: null,
      dtcs: const [],
      odometer: null,
      fuelLevel: 100.0,
      timestamp: DateTime.now(),
    );
  }

  ObdTelemetry copyWith({
    double? rpm,
    double? speed,
    double? coolant,
    double? voltage,
    double? mapValue,
    double? throttle,
    double? engineLoad,
    double? intakeAirTemp,
    double? maf,
    double? timingAdvance,
    List<String>? dtcs,
    double? odometer,
    double? fuelLevel,
    DateTime? timestamp,
  }) {
    return ObdTelemetry(
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      coolant: coolant ?? this.coolant,
      voltage: voltage ?? this.voltage,
      mapValue: mapValue ?? this.mapValue,
      throttle: throttle ?? this.throttle,
      engineLoad: engineLoad ?? this.engineLoad,
      intakeAirTemp: intakeAirTemp ?? this.intakeAirTemp,
      maf: maf ?? this.maf,
      timingAdvance: timingAdvance ?? this.timingAdvance,
      dtcs: dtcs ?? this.dtcs,
      odometer: odometer ?? this.odometer,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Calculates dynamically if the driving style is economical.
  /// Similar to the ECO indicator in Toyota Agya/modern cars.
  bool get isEcoMode {
    if (rpm < 500) return false; // Engine off or starting
    // Economical criteria: low throttle, moderate engine load, stable/normal RPM.
    if (speed == 0) {
      return throttle < 15 && engineLoad < 25; // Idle eco
    }
    return throttle < 22 && engineLoad < 38 && rpm < 2600;
  }

  /// Dynamic calculation of fuel consumption in km/L
  double get fuelEconomy {
    if (rpm < 500) return 0.0; // Engine off or starting
    // For a typical 1.0L engine (Agya):
    // Idle consumption at 850 RPM is ~0.5 L/h.
    // We estimate consumption based on engine RPM and load.
    final estimatedFuelFlowLh = (rpm * (engineLoad / 100.0) * 0.003) + 0.5;
    if (speed < 2.0) return 0.0; // Show 0.0 when stationary
    final kml = speed / estimatedFuelFlowLh;
    return kml > 50.0 ? 50.0 : kml; // Cap at 50 km/L max
  }
}
