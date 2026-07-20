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
  final double? fuelLevel;
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
      fuelLevel: null,
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

  /// Calculates dynamically if driving style is economical.
  /// Conditions: RPM 1200 - 2000, Speed > 10 km/h, Throttle < 25%, Engine Load < 40%.
  bool get isEcoMode {
    if (speed <= 10.0) return false; // ECO light is off when stopped or crawling under 10 km/h
    return rpm >= 1200 && rpm <= 2000 && throttle < 25.0 && engineLoad < 40.0;
  }

  /// Dynamic calculation of fuel consumption in km/L using Speed-Density (MAP) or MAF
  double get fuelEconomy {
    if (rpm < 500) return 0.0; // Engine off or starting

    double estimatedFuelFlowLh;

    if (maf != null && maf! > 0.0) {
      // MAF method (if supported): Fuel Flow L/h = MAF * 3600 / (14.7 * 740)
      estimatedFuelFlowLh = maf! * 0.3309;
    } else if (mapValue > 0.0) {
      // Speed-Density method (specifically tailored for MAP-based engines like Toyota Agya)
      // If Intake Air Temp is null, default to 25°C (298.15 Kelvin)
      final tempK = (intakeAirTemp ?? 25.0) + 273.15;
      
      // Agya has 1.0L or 1.2L engine. We assume 1.2L displacement and 80% volumetric efficiency.
      const displacement = 1.2;
      const volumetricEfficiency = 0.80;
      
      // Calculate air mass flow rate using ideal gas law (PV = nRT)
      // MAF (g/s) = (MAP * displacement * RPM * VE * MolarMassOfAir) / (120 * R * tempK)
      // Molar mass of air = 28.97 g/mol. R = 8.314.
      final estimatedMaf = (mapValue * rpm / tempK) * (displacement * volumetricEfficiency * 28.97 / (120 * 8.314));
      
      // Fuel Flow (L/h) = MAF (g/s) * 3600 / (14.7 * 740)
      estimatedFuelFlowLh = estimatedMaf * 0.3309;
    } else {
      // Fallback calculation using engine RPM and load
      estimatedFuelFlowLh = (rpm * (engineLoad / 100.0) * 0.003) + 0.5;
    }

    if (estimatedFuelFlowLh < 0.1) estimatedFuelFlowLh = 0.1;
    if (speed < 2.0) return 0.0; // Show 0.0 when stationary
    final kml = speed / estimatedFuelFlowLh;
    return kml > 50.0 ? 50.0 : kml; // Cap at 50 km/L max
  }
}
