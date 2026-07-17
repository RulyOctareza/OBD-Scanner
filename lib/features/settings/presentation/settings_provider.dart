import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database.dart';
import '../../../core/bluetooth/obd_service.dart';
import 'package:autocare/features/live_data/presentation/widgets/gauge_widget.dart';
import 'package:drift/drift.dart';

class SettingsState {
  final double currentOdometer;
  final double nextOilOdometer;
  final String vehicleName;
  final bool isSimulatorMode;
  final bool isIgnitionOn;
  final ObdMetricType leftMetric;
  final ObdMetricType rightMetric;
  final bool isFullscreenCockpit;
  final bool autoConnectOBD;
  final String lastOBDAddress;

  SettingsState({
    required this.currentOdometer,
    required this.nextOilOdometer,
    required this.vehicleName,
    required this.isSimulatorMode,
    required this.isIgnitionOn,
    required this.leftMetric,
    required this.rightMetric,
    required this.isFullscreenCockpit,
    required this.autoConnectOBD,
    required this.lastOBDAddress,
  });

  SettingsState copyWith({
    double? currentOdometer,
    double? nextOilOdometer,
    String? vehicleName,
    bool? isSimulatorMode,
    bool? isIgnitionOn,
    ObdMetricType? leftMetric,
    ObdMetricType? rightMetric,
    bool? isFullscreenCockpit,
    bool? autoConnectOBD,
    String? lastOBDAddress,
  }) {
    return SettingsState(
      currentOdometer: currentOdometer ?? this.currentOdometer,
      nextOilOdometer: nextOilOdometer ?? this.nextOilOdometer,
      vehicleName: vehicleName ?? this.vehicleName,
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      isIgnitionOn: isIgnitionOn ?? this.isIgnitionOn,
      leftMetric: leftMetric ?? this.leftMetric,
      rightMetric: rightMetric ?? this.rightMetric,
      isFullscreenCockpit: isFullscreenCockpit ?? this.isFullscreenCockpit,
      autoConnectOBD: autoConnectOBD ?? this.autoConnectOBD,
      lastOBDAddress: lastOBDAddress ?? this.lastOBDAddress,
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
    leftMetric: ObdMetricType.rpm,
    rightMetric: ObdMetricType.speed,
    isFullscreenCockpit: false,
    autoConnectOBD: true,
    lastOBDAddress: "",
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
    final db = _ref.read(databaseProvider);
    _prefs = await SharedPreferences.getInstance();

    // 1. Try loading from SQLite database
    String? name = await db.getPreference('vehicle_name');
    double? nextOil = await db.getDoublePreference('next_oil_odometer');
    bool? simMode = await db.getBoolPreference('is_simulator_mode');
    bool? ignition = await db.getBoolPreference('is_ignition_on');
    double? currentOdo = await db.getDoublePreference('current_odometer');
    
    // Dashboard preferences
    String? leftMetricStr = await db.getPreference('left_gauge_metric');
    String? rightMetricStr = await db.getPreference('right_gauge_metric');
    bool? isFullscreen = await db.getBoolPreference('cockpit_fullscreen');
    
    // Auto connect preferences
    bool? autoConnect = await db.getBoolPreference('auto_connect_obd');
    String? lastAddr = await db.getPreference('last_obd_device_address');

    // 2. Fallback to SharedPreferences (legacy migration) and then default values
    if (name == null) {
      name = _prefs!.getString('vehicle_name') ?? "Agya";
      await db.setPreference('vehicle_name', name);
    }
    if (nextOil == null) {
      nextOil = _prefs!.getDouble('next_oil_odometer') ?? 166420.0;
      await db.setDoublePreference('next_oil_odometer', nextOil);
    }
    if (simMode == null) {
      simMode = _prefs!.getBool('is_simulator_mode') ?? false;
      await db.setBoolPreference('is_simulator_mode', simMode);
    }
    if (ignition == null) {
      ignition = _prefs!.getBool('is_ignition_on') ?? true;
      await db.setBoolPreference('is_ignition_on', ignition);
    }
    if (currentOdo == null) {
      currentOdo = _prefs!.getDouble('current_odometer') ?? 161420.0;
      await db.setDoublePreference('current_odometer', currentOdo);
    }
    
    // Dashboard fallbacks
    ObdMetricType leftMetric = ObdMetricType.rpm;
    if (leftMetricStr != null) {
      leftMetric = ObdMetricType.values.firstWhere(
        (e) => e.toString().split('.').last == leftMetricStr,
        orElse: () => ObdMetricType.rpm,
      );
    } else {
      await db.setPreference('left_gauge_metric', 'rpm');
    }

    ObdMetricType rightMetric = ObdMetricType.speed;
    if (rightMetricStr != null) {
      rightMetric = ObdMetricType.values.firstWhere(
        (e) => e.toString().split('.').last == rightMetricStr,
        orElse: () => ObdMetricType.speed,
      );
    } else {
      await db.setPreference('right_gauge_metric', 'speed');
    }

    if (isFullscreen == null) {
      isFullscreen = false;
      await db.setBoolPreference('cockpit_fullscreen', false);
    }

    if (autoConnect == null) {
      autoConnect = true;
      await db.setBoolPreference('auto_connect_obd', true);
    }

    if (lastAddr == null) {
      lastAddr = _prefs!.getString('last_obd_device_address') ?? "";
      await db.setPreference('last_obd_device_address', lastAddr);
    }

    // Try loading odometer from database Vehicles table
    double odo = currentOdo;
    try {
      final vehicle = await (db.select(db.vehicles)..limit(1)).getSingleOrNull();
      if (vehicle != null) {
        odo = vehicle.odometer;
      } else {
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
      leftMetric: leftMetric,
      rightMetric: rightMetric,
      isFullscreenCockpit: isFullscreen,
      autoConnectOBD: autoConnect,
      lastOBDAddress: lastAddr,
    );
  }

  Future<void> updateOdometer(double val) async {
    state = state.copyWith(currentOdometer: val);
    final db = _ref.read(databaseProvider);
    await db.setDoublePreference('current_odometer', val);
    
    // Sync back to Drift Database Vehicles table
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
    await _ref.read(databaseProvider).setDoublePreference('next_oil_odometer', val);
  }

  Future<void> updateVehicleName(String name) async {
    state = state.copyWith(vehicleName: name);
    final db = _ref.read(databaseProvider);
    await db.setPreference('vehicle_name', name);
    
    // Sync name back to Drift Database Vehicles table
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
    await _ref.read(databaseProvider).setBoolPreference('is_simulator_mode', val);
  }

  Future<void> setIgnitionOn(bool val) async {
    state = state.copyWith(isIgnitionOn: val);
    await _ref.read(databaseProvider).setBoolPreference('is_ignition_on', val);
  }

  Future<void> updateLeftMetric(ObdMetricType metric) async {
    if (state.leftMetric == metric) return;
    state = state.copyWith(leftMetric: metric);
    final metricStr = metric.toString().split('.').last;
    await _ref.read(databaseProvider).setPreference('left_gauge_metric', metricStr);
  }

  Future<void> updateRightMetric(ObdMetricType metric) async {
    if (state.rightMetric == metric) return;
    state = state.copyWith(rightMetric: metric);
    final metricStr = metric.toString().split('.').last;
    await _ref.read(databaseProvider).setPreference('right_gauge_metric', metricStr);
  }

  Future<void> setFullscreenCockpit(bool val) async {
    if (state.isFullscreenCockpit == val) return;
    state = state.copyWith(isFullscreenCockpit: val);
    await _ref.read(databaseProvider).setBoolPreference('cockpit_fullscreen', val);
  }

  Future<void> setAutoConnectOBD(bool val) async {
    if (state.autoConnectOBD == val) return;
    state = state.copyWith(autoConnectOBD: val);
    await _ref.read(databaseProvider).setBoolPreference('auto_connect_obd', val);
  }

  Future<void> updateLastOBDAddress(String address) async {
    if (state.lastOBDAddress == address) return;
    state = state.copyWith(lastOBDAddress: address);
    await _ref.read(databaseProvider).setPreference('last_obd_device_address', address);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
