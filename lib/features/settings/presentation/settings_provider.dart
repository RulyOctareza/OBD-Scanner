import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/vin_decoder.dart';
import 'package:autocare/features/live_data/presentation/widgets/gauge_widget.dart';
import 'package:drift/drift.dart';

class SettingsState {
  final double currentOdometer;
  final double nextOilOdometer;
  final String vehicleName;
  final String vehicleVin;
  final bool isSimulatorMode;
  final bool isIgnitionOn;
  final ObdMetricType leftMetric;
  final ObdMetricType rightMetric;
  final ObdMetricType smallMetric1;
  final ObdMetricType smallMetric2;
  final ObdMetricType smallMetric3;
  final ObdMetricType smallMetric4;
  final bool isFullscreenCockpit;
  final bool autoConnectOBD;
  final String lastOBDAddress;
  final bool hasCompletedObdIntro;
  final bool isLoaded;

  SettingsState({
    required this.currentOdometer,
    required this.nextOilOdometer,
    required this.vehicleName,
    this.vehicleVin = '',
    required this.isSimulatorMode,
    required this.isIgnitionOn,
    required this.leftMetric,
    required this.rightMetric,
    required this.smallMetric1,
    required this.smallMetric2,
    required this.smallMetric3,
    required this.smallMetric4,
    required this.isFullscreenCockpit,
    required this.autoConnectOBD,
    required this.lastOBDAddress,
    required this.hasCompletedObdIntro,
    this.isLoaded = false,
  });

  SettingsState copyWith({
    double? currentOdometer,
    double? nextOilOdometer,
    String? vehicleName,
    String? vehicleVin,
    bool? isSimulatorMode,
    bool? isIgnitionOn,
    ObdMetricType? leftMetric,
    ObdMetricType? rightMetric,
    ObdMetricType? smallMetric1,
    ObdMetricType? smallMetric2,
    ObdMetricType? smallMetric3,
    ObdMetricType? smallMetric4,
    bool? isFullscreenCockpit,
    bool? autoConnectOBD,
    String? lastOBDAddress,
    bool? hasCompletedObdIntro,
    bool? isLoaded,
  }) {
    return SettingsState(
      currentOdometer: currentOdometer ?? this.currentOdometer,
      nextOilOdometer: nextOilOdometer ?? this.nextOilOdometer,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleVin: vehicleVin ?? this.vehicleVin,
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      isIgnitionOn: isIgnitionOn ?? this.isIgnitionOn,
      leftMetric: leftMetric ?? this.leftMetric,
      rightMetric: rightMetric ?? this.rightMetric,
      smallMetric1: smallMetric1 ?? this.smallMetric1,
      smallMetric2: smallMetric2 ?? this.smallMetric2,
      smallMetric3: smallMetric3 ?? this.smallMetric3,
      smallMetric4: smallMetric4 ?? this.smallMetric4,
      isFullscreenCockpit: isFullscreenCockpit ?? this.isFullscreenCockpit,
      autoConnectOBD: autoConnectOBD ?? this.autoConnectOBD,
      lastOBDAddress: lastOBDAddress ?? this.lastOBDAddress,
      hasCompletedObdIntro: hasCompletedObdIntro ?? this.hasCompletedObdIntro,
      isLoaded: isLoaded ?? this.isLoaded,
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
    vehicleVin: '',
    isSimulatorMode: false,
    isIgnitionOn: true,
    leftMetric: ObdMetricType.rpm,
    rightMetric: ObdMetricType.speed,
    smallMetric1: ObdMetricType.voltage,
    smallMetric2: ObdMetricType.coolant,
    smallMetric3: ObdMetricType.fuel,
    smallMetric4: ObdMetricType.fuelEconomy,
    isFullscreenCockpit: false,
    autoConnectOBD: true,
    lastOBDAddress: "",
    hasCompletedObdIntro: false,
    isLoaded: false,
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
    String? vin = await db.getPreference('vehicle_vin');
    double? nextOil = await db.getDoublePreference('next_oil_odometer');
    bool? simMode = await db.getBoolPreference('is_simulator_mode');
    bool? ignition = await db.getBoolPreference('is_ignition_on');
    double? currentOdo = await db.getDoublePreference('current_odometer');
    
    // Dashboard preferences
    String? leftMetricStr = await db.getPreference('left_gauge_metric');
    String? rightMetricStr = await db.getPreference('right_gauge_metric');
    String? sm1Str = await db.getPreference('small_metric_1');
    String? sm2Str = await db.getPreference('small_metric_2');
    String? sm3Str = await db.getPreference('small_metric_3');
    String? sm4Str = await db.getPreference('small_metric_4');
    bool? isFullscreen = await db.getBoolPreference('cockpit_fullscreen');
    
    // Auto connect preferences
    bool? autoConnect = await db.getBoolPreference('auto_connect_obd');
    String? lastAddr = await db.getPreference('last_obd_device_address');
    bool? hasIntro = await db.getBoolPreference('has_completed_obd_intro');

    // 2. Fallback to SharedPreferences (legacy migration) and then default values
    if (name == null) {
      name = _prefs!.getString('vehicle_name') ?? "Agya";
      await db.setPreference('vehicle_name', name);
    }
    vin ??= _prefs!.getString('vehicle_vin') ?? '';
    if (vin.isNotEmpty) {
      await db.setPreference('vehicle_vin', vin);
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

    ObdMetricType sm1 = ObdMetricType.voltage;
    if (sm1Str != null) {
      sm1 = ObdMetricType.values.firstWhere(
        (e) => e.toString().split('.').last == sm1Str,
        orElse: () => ObdMetricType.voltage,
      );
    } else {
      await db.setPreference('small_metric_1', 'voltage');
    }

    ObdMetricType sm2 = ObdMetricType.coolant;
    if (sm2Str != null) {
      sm2 = ObdMetricType.values.firstWhere(
        (e) => e.toString().split('.').last == sm2Str,
        orElse: () => ObdMetricType.coolant,
      );
    } else {
      await db.setPreference('small_metric_2', 'coolant');
    }

    ObdMetricType sm3 = ObdMetricType.fuel;
    if (sm3Str != null) {
      sm3 = ObdMetricType.values.firstWhere(
        (e) => e.toString().split('.').last == sm3Str,
        orElse: () => ObdMetricType.fuel,
      );
    } else {
      await db.setPreference('small_metric_3', 'fuel');
    }

    ObdMetricType sm4 = ObdMetricType.fuelEconomy;
    if (sm4Str != null) {
      sm4 = ObdMetricType.values.firstWhere(
        (e) => e.toString().split('.').last == sm4Str,
        orElse: () => ObdMetricType.fuelEconomy,
      );
    } else {
      await db.setPreference('small_metric_4', 'fuelEconomy');
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

    if (hasIntro == null) {
      hasIntro = _prefs!.getBool('has_completed_obd_intro') ?? false;
      await db.setBoolPreference('has_completed_obd_intro', hasIntro);
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
      vehicleVin: vin,
      isSimulatorMode: simMode,
      isIgnitionOn: ignition,
      leftMetric: leftMetric,
      rightMetric: rightMetric,
      smallMetric1: sm1,
      smallMetric2: sm2,
      smallMetric3: sm3,
      smallMetric4: sm4,
      isFullscreenCockpit: isFullscreen,
      autoConnectOBD: autoConnect,
      lastOBDAddress: lastAddr,
      hasCompletedObdIntro: hasIntro,
      isLoaded: true,
    );

    // Keep OBD runtime aligned with restored preference (idempotent).
    _ref.read(obdServiceProvider.notifier).applySimulatorMode(simMode);
    if (simMode) {
      _ref.read(obdServiceProvider.notifier).configureSimulator(
            isEngineRunning: ignition,
          );
    }
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

  /// Applies identity fields discovered from ECU (VIN Mode 09 + odometer PID A6).
  Future<void> applyEcuVehicleIdentity({
    String? vin,
    double? odometer,
    bool overwriteName = true,
  }) async {
    final db = _ref.read(databaseProvider);

    if (vin != null && VinDecoder.isValidVin(vin)) {
      final cleaned = vin.trim().toUpperCase();
      state = state.copyWith(vehicleVin: cleaned);
      await db.setPreference('vehicle_vin', cleaned);

      if (overwriteName) {
        final decoded = VinDecoder.displayNameFromVin(cleaned);
        if (decoded != null && decoded.isNotEmpty) {
          await updateVehicleName(decoded);
        }
      }
    }

    if (odometer != null && odometer > 0) {
      await updateOdometer(odometer);
    }
  }

  /// Pulls VIN + odometer from the connected ECU / simulator.
  Future<EcuVehicleIdentityResult> syncVehicleIdentityFromEcu() async {
    final identity =
        await _ref.read(obdServiceProvider.notifier).fetchVehicleIdentity();
    if (!identity.success) {
      return identity;
    }
    await applyEcuVehicleIdentity(
      vin: identity.vin,
      odometer: identity.odometer,
    );
    return identity;
  }

  Future<void> setSimulatorMode(bool val, {bool syncObd = true}) async {
    state = state.copyWith(isSimulatorMode: val);
    await _ref.read(databaseProvider).setBoolPreference('is_simulator_mode', val);
    if (syncObd) {
      _ref.read(obdServiceProvider.notifier).applySimulatorMode(val);
    }
    if (val) {
      // Simulator exposes a stable demo VIN + live odometer.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await syncVehicleIdentityFromEcu();
    }
  }

  Future<void> setIgnitionOn(bool val) async {
    state = state.copyWith(isIgnitionOn: val);
    await _ref.read(databaseProvider).setBoolPreference('is_ignition_on', val);
    if (state.isSimulatorMode) {
      _ref.read(obdServiceProvider.notifier).configureSimulator(
            isEngineRunning: val,
          );
    }
  }

  Future<void> setMetricAt(int index, ObdMetricType newMetric) async {
    final currentMetrics = [
      state.leftMetric,
      state.rightMetric,
      state.smallMetric1,
      state.smallMetric2,
      state.smallMetric3,
      state.smallMetric4,
    ];

    if (currentMetrics[index] == newMetric) return;

    final duplicateIndex = currentMetrics.indexOf(newMetric);
    if (duplicateIndex != -1) {
      final temp = currentMetrics[index];
      currentMetrics[index] = newMetric;
      currentMetrics[duplicateIndex] = temp;
    } else {
      currentMetrics[index] = newMetric;
    }

    state = state.copyWith(
      leftMetric: currentMetrics[0],
      rightMetric: currentMetrics[1],
      smallMetric1: currentMetrics[2],
      smallMetric2: currentMetrics[3],
      smallMetric3: currentMetrics[4],
      smallMetric4: currentMetrics[5],
    );

    final db = _ref.read(databaseProvider);
    await db.setPreference('left_gauge_metric', currentMetrics[0].toString().split('.').last);
    await db.setPreference('right_gauge_metric', currentMetrics[1].toString().split('.').last);
    await db.setPreference('small_metric_1', currentMetrics[2].toString().split('.').last);
    await db.setPreference('small_metric_2', currentMetrics[3].toString().split('.').last);
    await db.setPreference('small_metric_3', currentMetrics[4].toString().split('.').last);
    await db.setPreference('small_metric_4', currentMetrics[5].toString().split('.').last);
  }

  Future<void> updateLeftMetric(ObdMetricType metric) async {
    await setMetricAt(0, metric);
  }

  Future<void> updateRightMetric(ObdMetricType metric) async {
    await setMetricAt(1, metric);
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

  Future<void> setObdIntroCompleted(bool val) async {
    state = state.copyWith(hasCompletedObdIntro: val);
    final db = _ref.read(databaseProvider);
    await db.setBoolPreference('has_completed_obd_intro', val);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('has_completed_obd_intro', val);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
