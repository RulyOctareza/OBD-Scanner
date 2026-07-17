import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database.dart';
import '../../../core/bluetooth/obd_service.dart';
import 'package:drift/drift.dart';

class SettingsState {
  final double currentOdometer;
  final double nextOilOdometer;
  final String vehicleName;
  final bool isSimulatorMode;
  final bool isIgnitionOn;

  SettingsState({
    required this.currentOdometer,
    required this.nextOilOdometer,
    required this.vehicleName,
    required this.isSimulatorMode,
    required this.isIgnitionOn,
  });

  SettingsState copyWith({
    double? currentOdometer,
    double? nextOilOdometer,
    String? vehicleName,
    bool? isSimulatorMode,
    bool? isIgnitionOn,
  }) {
    return SettingsState(
      currentOdometer: currentOdometer ?? this.currentOdometer,
      nextOilOdometer: nextOilOdometer ?? this.nextOilOdometer,
      vehicleName: vehicleName ?? this.vehicleName,
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      isIgnitionOn: isIgnitionOn ?? this.isIgnitionOn,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  SharedPreferences? _prefs;

  SettingsNotifier(this._ref) : super(SettingsState(
    currentOdometer: 161420.0,
    nextOilOdometer: 166420.0,
    vehicleName: "Agya",
    isSimulatorMode: false,
    isIgnitionOn: true,
  )) {
    _initPrefs();
    
    // Listen to OBD telemetry and update odometer dynamically from ECU if available
    _ref.listen(obdServiceProvider, (previous, next) {
      final ecuOdo = next.telemetry.odometer;
      if (ecuOdo != null && ecuOdo > 0 && ecuOdo != state.currentOdometer) {
        updateOdometer(ecuOdo);
      }
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final nextOil = _prefs!.getDouble('next_oil_odometer') ?? 166420.0;
    final name = _prefs!.getString('vehicle_name') ?? "Agya";
    final simMode = _prefs!.getBool('is_simulator_mode') ?? false;
    final ignition = _prefs!.getBool('is_ignition_on') ?? true;

    // Load odometer from database first (table Vehicles), fallback to prefs, then hardcoded default
    final db = _ref.read(databaseProvider);
    double odo = _prefs!.getDouble('current_odometer') ?? 161420.0;
    try {
      final vehicle = await (db.select(db.vehicles)..limit(1)).getSingleOrNull();
      if (vehicle != null) {
        odo = vehicle.odometer;
      } else {
        // Seed vehicle table with initial name and odo
        await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            name: name,
            odometer: Value(odo),
          ),
        );
      }
    } catch (_) {}

    state = SettingsState(
      currentOdometer: odo,
      nextOilOdometer: nextOil,
      vehicleName: name,
      isSimulatorMode: simMode,
      isIgnitionOn: ignition,
    );
  }

  Future<void> updateOdometer(double val) async {
    state = state.copyWith(currentOdometer: val);
    await _prefs?.setDouble('current_odometer', val);
    
    // Sync back to Drift Database Vehicles table
    final db = _ref.read(databaseProvider);
    try {
      final vehicle = await (db.select(db.vehicles)..limit(1)).getSingleOrNull();
      if (vehicle != null) {
        await (db.update(db.vehicles)..where((t) => t.id.equals(vehicle.id))).write(
          VehiclesCompanion(odometer: Value(val)),
        );
      }
    } catch (_) {}
  }

  Future<void> updateNextOilOdometer(double val) async {
    state = state.copyWith(nextOilOdometer: val);
    await _prefs?.setDouble('next_oil_odometer', val);
  }

  Future<void> updateVehicleName(String name) async {
    state = state.copyWith(vehicleName: name);
    await _prefs?.setString('vehicle_name', name);
    
    // Sync name back to Drift Database Vehicles table
    final db = _ref.read(databaseProvider);
    try {
      final vehicle = await (db.select(db.vehicles)..limit(1)).getSingleOrNull();
      if (vehicle != null) {
        await (db.update(db.vehicles)..where((t) => t.id.equals(vehicle.id))).write(
          VehiclesCompanion(name: Value(name)),
        );
      }
    } catch (_) {}
  }

  Future<void> setSimulatorMode(bool val) async {
    state = state.copyWith(isSimulatorMode: val);
    await _prefs?.setBool('is_simulator_mode', val);
  }

  Future<void> setIgnitionOn(bool val) async {
    state = state.copyWith(isIgnitionOn: val);
    await _prefs?.setBool('is_ignition_on', val);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
