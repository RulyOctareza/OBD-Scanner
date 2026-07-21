import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../obd/obd_parser.dart';
import '../obd/obd_simulator.dart';
import '../obd/obd_telemetry.dart';
import '../obd/vin_decoder.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../../features/live_data/presentation/widgets/gauge_widget.dart';

class DiagnosticScanResult {
  final String protocol;
  final String vin;
  final bool milStatus;
  final int dtcCount;
  final int supportedSensorsCount;
  final List<String> activeDtcs;
  final List<String> pendingDtcs;
  final List<String> permanentDtcs;
  final Map<String, bool> imReadiness;
  final DateTime scanTimestamp;
  final double? odometerKm;

  DiagnosticScanResult({
    required this.protocol,
    required this.vin,
    required this.milStatus,
    required this.dtcCount,
    required this.supportedSensorsCount,
    required this.activeDtcs,
    required this.pendingDtcs,
    required this.permanentDtcs,
    required this.imReadiness,
    required this.scanTimestamp,
    this.odometerKm,
  });
}

/// Result of a lightweight VIN + odometer identity read from the ECU.
class EcuVehicleIdentityResult {
  final bool success;
  final String? vin;
  final double? odometer;
  final String? suggestedName;
  final String message;

  const EcuVehicleIdentityResult({
    required this.success,
    this.vin,
    this.odometer,
    this.suggestedName,
    required this.message,
  });
}

enum ObdStatus {
  disconnected,
  connecting,
  initializing,
  connected,
  error
}

class ObdState {
  final ObdStatus status;
  final String? errorMessage;
  final ObdTelemetry telemetry;
  final bool isSimulatorMode;
  final String? connectedDeviceName;
  final String? connectedDeviceAddress;
  final Set<ObdMetricType> supportedSensors;
  final Set<ObdMetricType> checkedSensors;
  final bool simHighTemp;
  final bool simLowVoltage;
  final bool simHasDtc;

  ObdState({
    required this.status,
    this.errorMessage,
    required this.telemetry,
    required this.isSimulatorMode,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
    required this.supportedSensors,
    required this.checkedSensors,
    this.simHighTemp = false,
    this.simLowVoltage = false,
    this.simHasDtc = false,
  });

  factory ObdState.initial() {
    return ObdState(
      status: ObdStatus.disconnected,
      telemetry: ObdTelemetry.empty(),
      isSimulatorMode: false,
      supportedSensors: const {},
      checkedSensors: const {},
    );
  }

  ObdState copyWith({
    ObdStatus? status,
    Object? errorMessage = _obdUnset,
    ObdTelemetry? telemetry,
    bool? isSimulatorMode,
    Object? connectedDeviceName = _obdUnset,
    Object? connectedDeviceAddress = _obdUnset,
    Set<ObdMetricType>? supportedSensors,
    Set<ObdMetricType>? checkedSensors,
    bool? simHighTemp,
    bool? simLowVoltage,
    bool? simHasDtc,
  }) {
    return ObdState(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _obdUnset)
          ? this.errorMessage
          : errorMessage as String?,
      telemetry: telemetry ?? this.telemetry,
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      connectedDeviceName: identical(connectedDeviceName, _obdUnset)
          ? this.connectedDeviceName
          : connectedDeviceName as String?,
      connectedDeviceAddress: identical(connectedDeviceAddress, _obdUnset)
          ? this.connectedDeviceAddress
          : connectedDeviceAddress as String?,
      supportedSensors: supportedSensors ?? this.supportedSensors,
      checkedSensors: checkedSensors ?? this.checkedSensors,
      simHighTemp: simHighTemp ?? this.simHighTemp,
      simLowVoltage: simLowVoltage ?? this.simLowVoltage,
      simHasDtc: simHasDtc ?? this.simHasDtc,
    );
  }
}

const Object _obdUnset = Object();

class ObdService extends StateNotifier<ObdState> {
  final Ref _ref;
  final ObdSimulator _simulator = ObdSimulator();
  BluetoothConnection? _connection;
  StreamSubscription? _simSubscription;
  Timer? _pollingTimer;
  Timer? _autoReconnectTimer;
  Completer<String>? _pendingResponseCompleter;

  final StringBuffer _rxBuffer = StringBuffer();
  final List<String> _pendingCommands = ['AT RV', '010C', '010D', '0105', '010F', '010B', '0110', '010E', '0111', '0104', '01A6', '012F', '03'];
  int _currentCommandIndex = 0;
  bool _isAwaitingResponse = false;
  DateTime? _lastActivityTime;

  static const int _responseTimeoutMs = 3000;

  ObdService(this._ref) : super(ObdState.initial()) {
    Future.microtask(() async {
      // Restore simulator preference before any Bluetooth auto-connect.
      // ObdState always boots as non-sim; prefs may say otherwise.
      try {
        final db = _ref.read(databaseProvider);
        final simMode =
            await db.getBoolPreference('is_simulator_mode') ?? false;
        if (simMode) {
          applySimulatorMode(true);
        } else {
          // Wait for OS Bluetooth / ELM327 to release previous RFCOMM.
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !state.isSimulatorMode) {
              _autoConnect();
            }
          });
        }
      } catch (e) {
        debugPrint('OBD startup mode restore failed: $e');
      }
      _startAutoReconnectTimer();
    });
  }

  void _startAutoReconnectTimer() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        if (state.isSimulatorMode) return;

        final db = _ref.read(databaseProvider);
        final autoConnectOBD = await db.getBoolPreference('auto_connect_obd') ?? true;
        final isSimulatorMode = await db.getBoolPreference('is_simulator_mode') ?? false;

        if (autoConnectOBD &&
            !isSimulatorMode &&
            !state.isSimulatorMode &&
            (state.status == ObdStatus.disconnected || state.status == ObdStatus.error)) {
          _autoConnect();
        }
      } catch (e) {
        debugPrint('Auto-reconnect check failed: $e');
      }
    });
  }

  Future<void> _autoConnect() async {
    if (state.isSimulatorMode) return;
    if (state.status == ObdStatus.connecting || state.status == ObdStatus.initializing) {
      return;
    }
    try {
      final db = _ref.read(databaseProvider);
      final lastAddress = await db.getPreference('last_obd_device_address') ?? "";
      if (lastAddress.isEmpty) return;

      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) return;

      final connectGranted = await Permission.bluetoothConnect.isGranted;
      if (!connectGranted) return;

      debugPrint('Auto-connecting to last device: $lastAddress');
      // Retrieve device name if possible, or just create a dummy one
      final bondedDevices = await getPairedDevices();
      BluetoothDevice? targetDevice;
      try {
         targetDevice = bondedDevices.firstWhere((d) => d.address == lastAddress);
      } catch (_) {}
      
      if (targetDevice != null) {
        await connectToDevice(targetDevice);
      }
    } catch (e) {
      debugPrint('Auto-connect failed: $e');
    }
  }

  ObdSimulator get simulator => _simulator;

  /// Applies simulator runtime mode. Prefer
  /// [SettingsNotifier.setSimulatorMode] from UI so prefs stay in sync.
  ///
  /// Idempotent: enabling while already healthy is a no-op; enabling while
  /// flag is stale / sim stopped forces a clean restart.
  void applySimulatorMode(bool value) {
    final simHealthy =
        value &&
        state.isSimulatorMode &&
        _simulator.isRunning &&
        _simSubscription != null;

    if (simHealthy) return;
    if (!value && !state.isSimulatorMode && !_simulator.isRunning) {
      _stopSimulation();
      return;
    }

    if (value) {
      _disconnectReal();
      _stopSimulation();

      var ignitionOn = true;
      try {
        ignitionOn = _ref.read(settingsProvider).isIgnitionOn;
      } catch (_) {}
      _simulator.resetDemoTriggers(engineRunning: ignitionOn);

      state = state.copyWith(
        isSimulatorMode: true,
        status: ObdStatus.disconnected,
        telemetry: ObdTelemetry.empty(),
        connectedDeviceName: 'Simulator',
        connectedDeviceAddress: null,
        errorMessage: null,
        supportedSensors: const {},
        checkedSensors: const {},
        simHighTemp: false,
        simLowVoltage: false,
        simHasDtc: false,
      );
      _startSimulation();
    } else {
      _stopSimulation();
      _simulator.resetDemoTriggers(engineRunning: true);
      state = state.copyWith(
        isSimulatorMode: false,
        status: ObdStatus.disconnected,
        telemetry: ObdTelemetry.empty(),
        connectedDeviceName: null,
        connectedDeviceAddress: null,
        errorMessage: null,
        supportedSensors: const {},
        checkedSensors: const {},
        simHighTemp: false,
        simLowVoltage: false,
        simHasDtc: false,
      );
    }
  }

  /// Compatibility alias used by older call sites.
  void toggleSimulatorMode(bool value) => applySimulatorMode(value);

  /// Updates simulator demo flags and nudges listeners.
  void configureSimulator({
    bool? isEngineRunning,
    bool? hasHighTemp,
    bool? hasLowVoltage,
    List<String>? injectedDtcs,
  }) {
    _simulator.configure(
      isEngineRunning: isEngineRunning,
      hasHighTemp: hasHighTemp,
      hasLowVoltage: hasLowVoltage,
      injectedDtcs: injectedDtcs,
    );
    state = state.copyWith(
      simHighTemp: _simulator.hasHighTemp,
      simLowVoltage: _simulator.hasLowVoltage,
      simHasDtc: _simulator.injectedDtcs.isNotEmpty,
    );
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    if (kIsWeb) return [];
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      debugPrint("Error fetching paired devices: $e");
      return [];
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (state.isSimulatorMode) {
      applySimulatorMode(false);
      // Keep Settings toggle in sync (avoid "ON in UI, OFF in OBD").
      unawaited(
        _ref.read(settingsProvider.notifier).setSimulatorMode(
              false,
              syncObd: false,
            ),
      );
    }

    state = state.copyWith(
      status: ObdStatus.connecting,
      errorMessage: null,
      connectedDeviceName: device.name,
      connectedDeviceAddress: device.address,
      supportedSensors: const {},
      checkedSensors: const {},
    );

    const int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        try {
          await FlutterBluetoothSerial.instance.cancelDiscovery();
        } catch (e) {
          debugPrint("Error canceling discovery: $e");
        }

        _connection = await BluetoothConnection.toAddress(device.address)
            .timeout(const Duration(seconds: 20));

        state = state.copyWith(status: ObdStatus.initializing);

        _connection!.input!.listen(_onDataReceived).onDone(() {
          _onConnectionLost("Connection closed by ELM327.");
        });

        await _initElm327();

        state = state.copyWith(status: ObdStatus.connected);
        
        // Save the address for future auto-connect
        _ref.read(settingsProvider.notifier).updateLastOBDAddress(device.address);

        _startPolling();
        return;
      } catch (e) {
        _disconnectReal();
        if (attempt == maxRetries) {
          String friendlyMessage = "Koneksi gagal: $e";
          final errStr = e.toString().toLowerCase();
          if (errStr.contains("read failed") || errStr.contains("socket might closed") || errStr.contains("timeout")) {
            friendlyMessage = "Gagal menyambungkan ke OBD-II.\n\n"
                "Silakan coba langkah berikut:\n"
                "1. Cabut dongle OBD-II dari mobil selama 10 detik, lalu pasang kembali.\n"
                "2. Tutup paksa (force close) semua aplikasi OBD lain (Torque, Car Scanner, dll).\n"
                "3. 'Lupakan Perangkat' (Unpair) di Pengaturan Bluetooth HP, lalu pair ulang.";
          }
          state = state.copyWith(
            status: ObdStatus.error,
            errorMessage: friendlyMessage,
          );
        } else {
          state = state.copyWith(
            status: ObdStatus.connecting,
            errorMessage: "Percobaan $attempt dari $maxRetries gagal. Mencoba lagi...",
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  Future<void> _initElm327() async {
    final initCommands = ['AT Z\r', 'AT E0\r', 'AT SP 0\r'];
    const int maxRetries = 2;

    for (final cmd in initCommands) {
      bool success = false;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          await _sendAndAwaitResponse(cmd);
          if (cmd == 'AT Z\r') {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          success = true;
          break;
        } catch (e) {
          debugPrint("Init $cmd attempt ${attempt + 1} failed: $e");
          if (attempt < maxRetries - 1) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }
      if (!success) {
        throw Exception("Init ELM327 gagal: $cmd");
      }
    }
  }

  Future<String> _sendAndAwaitResponse(String command, {Duration timeout = const Duration(seconds: 3)}) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception("Connection not active");
    }
    _pendingResponseCompleter = Completer<String>();
    try {
      _connection!.output.add(utf8.encode(command));
      await _connection!.output.allSent;
      return await _pendingResponseCompleter!.future.timeout(timeout);
    } catch (e) {
      _pendingResponseCompleter = null;
      rethrow;
    }
  }

  void disconnect() {
    if (state.isSimulatorMode) {
      // Keep simulation going
    } else {
      _disconnectReal();
      state = state.copyWith(
        status: ObdStatus.disconnected,
        supportedSensors: const {},
        checkedSensors: const {},
      );
    }
  }

  void _disconnectReal() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _connection?.dispose();
    _connection = null;
    _rxBuffer.clear();
    _isAwaitingResponse = false;
    _currentCommandIndex = 0;
    if (_pendingResponseCompleter != null && !_pendingResponseCompleter!.isCompleted) {
      _pendingResponseCompleter!.completeError(Exception("Disconnected"));
    }
    _pendingResponseCompleter = null;
  }

  void _startSimulation() {
    _simSubscription?.cancel();
    _simulator.start();
    _simSubscription = _simulator.telemetryStream.listen((telemetry) {
      state = state.copyWith(
        status: ObdStatus.connected,
        telemetry: telemetry,
        supportedSensors: ObdMetricType.values.toSet(),
        checkedSensors: ObdMetricType.values.toSet(),
      );
    });
  }

  void _stopSimulation() {
    _simSubscription?.cancel();
    _simSubscription = null;
    _simulator.stop();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _isAwaitingResponse = false;
    _currentCommandIndex = 0;
    _sendNextCommand();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isAwaitingResponse && _lastActivityTime != null &&
          DateTime.now().difference(_lastActivityTime!) > Duration(milliseconds: _responseTimeoutMs)) {
        _isAwaitingResponse = false;
        _sendNextCommand();
      }
    });
  }

  Future<void> _sendString(String command) async {
    if (_connection == null || !_connection!.isConnected) return;
    _connection!.output.add(utf8.encode(command));
    await _connection!.output.allSent;
  }

  void _sendNextCommand() {
    if (_isAwaitingResponse) return;
    if (_pendingCommands.isEmpty) return;
    final cmd = _pendingCommands[_currentCommandIndex];
    _isAwaitingResponse = true;
    _lastActivityTime = DateTime.now();
    _sendString("$cmd\r");
  }

  void _onDataReceived(Uint8List data) {
    final text = utf8.decode(data);
    _rxBuffer.write(text);

    if (_isAwaitingResponse) {
      _lastActivityTime = DateTime.now();
    }

    if (text.contains('>')) {
      final fullResponse = _rxBuffer.toString();
      _rxBuffer.clear();
      _isAwaitingResponse = false;

      if (_pendingResponseCompleter != null && !_pendingResponseCompleter!.isCompleted) {
        _pendingResponseCompleter!.complete(fullResponse);
        _pendingResponseCompleter = null;
      } else {
        _parseResponse(_pendingCommands[_currentCommandIndex], fullResponse);
        _currentCommandIndex = (_currentCommandIndex + 1) % _pendingCommands.length;
        _sendNextCommand();
      }
    }
  }

  void _parseResponse(String command, String response) {
    ObdTelemetry current = state.telemetry;
    ObdMetricType? metricType;
    bool isValid = false;

    if (command == 'AT RV') {
      metricType = ObdMetricType.voltage;
      final val = ObdParser.parseVoltage(response);
      if (val != null) {
        current = current.copyWith(voltage: val);
        isValid = true;
      }
    } else if (command == '010C') {
      metricType = ObdMetricType.rpm;
      final val = ObdParser.parseRpm(response);
      if (val != null) {
        current = current.copyWith(rpm: val);
        isValid = true;
      }
    } else if (command == '010D') {
      metricType = ObdMetricType.speed;
      final val = ObdParser.parseSpeed(response);
      if (val != null) {
        current = current.copyWith(speed: val);
        isValid = true;
      }
    } else if (command == '0105') {
      metricType = ObdMetricType.coolant;
      final val = ObdParser.parseCoolant(response);
      if (val != null) {
        current = current.copyWith(coolant: val);
        isValid = true;
      }
    } else if (command == '010F') {
      metricType = ObdMetricType.intakeAirTemp;
      final val = ObdParser.parseIntakeAirTemp(response);
      if (val != null) {
        current = current.copyWith(intakeAirTemp: val);
        isValid = true;
      }
    } else if (command == '010B') {
      metricType = ObdMetricType.map;
      final val = ObdParser.parseMap(response);
      if (val != null) {
        current = current.copyWith(mapValue: val);
        isValid = true;
      }
    } else if (command == '0110') {
      metricType = ObdMetricType.maf;
      final val = ObdParser.parseMaf(response);
      if (val != null) {
        current = current.copyWith(maf: val);
        isValid = true;
      }
    } else if (command == '010E') {
      metricType = ObdMetricType.timingAdvance;
      final val = ObdParser.parseTimingAdvance(response);
      if (val != null) {
        current = current.copyWith(timingAdvance: val);
        isValid = true;
      }
    } else if (command == '0111') {
      metricType = ObdMetricType.throttle;
      final val = ObdParser.parseThrottle(response);
      if (val != null) {
        current = current.copyWith(throttle: val);
        isValid = true;
      }
    } else if (command == '0104') {
      metricType = ObdMetricType.engineLoad;
      final val = ObdParser.parseEngineLoad(response);
      if (val != null) {
        current = current.copyWith(engineLoad: val);
        isValid = true;
      }
    } else if (command == '01A6') {
      final val = ObdParser.parseOdometer(response);
      if (val != null) current = current.copyWith(odometer: val);
    } else if (command == '012F') {
      metricType = ObdMetricType.fuel;
      final val = ObdParser.parseFuelLevel(response);
      if (val != null) {
        current = current.copyWith(fuelLevel: val);
        isValid = true;
      }
    } else if (command == '03') {
      final val = ObdParser.parseDtc(response);
      current = current.copyWith(dtcs: val);
    }

    final checked = Set<ObdMetricType>.from(state.checkedSensors);
    final supported = Set<ObdMetricType>.from(state.supportedSensors);

    if (metricType != null) {
      checked.add(metricType);
      if (isValid) {
        supported.add(metricType);
      }
    }

    // Handle calculated fuelEconomy support. It is supported if MAP or MAF is supported.
    if (checked.contains(ObdMetricType.map) || checked.contains(ObdMetricType.rpm)) {
      checked.add(ObdMetricType.fuelEconomy);
      if (supported.contains(ObdMetricType.map) || supported.contains(ObdMetricType.rpm)) {
        supported.add(ObdMetricType.fuelEconomy);
      }
    }

    state = state.copyWith(
      telemetry: current.copyWith(timestamp: DateTime.now()),
      checkedSensors: checked,
      supportedSensors: supported,
    );
  }

  Future<DiagnosticScanResult> performFullDiagnosticScan({
    void Function(double progress, String statusText)? onProgress,
  }) async {
    if (state.status != ObdStatus.connected) {
      return DiagnosticScanResult(
        protocol: 'Tidak Terhubung',
        vin: 'Tidak Ada Data',
        milStatus: false,
        dtcCount: 0,
        supportedSensorsCount: 0,
        activeDtcs: const [],
        pendingDtcs: const [],
        permanentDtcs: const [],
        imReadiness: const {},
        scanTimestamp: DateTime.now(),
      );
    }

    if (state.isSimulatorMode) {
      onProgress?.call(0.15, 'Mendeteksi Protokol ECU (Mode Simulator)...');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.30, 'Membaca Identitas & VIN Kendaraan (Mode 09)...');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.50, 'Memindai Dukungan Sensor & Parameter ECU (Mode 01)...');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.70, 'Membaca Kode Kerusakan Aktif (Mode 03)...');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.85, 'Membaca Kode Kerusakan Pending & Permanen (Mode 07/0A)...');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.95, 'Memeriksa Kesiapan Emisi (I/M Readiness)...');
      await Future.delayed(const Duration(milliseconds: 300));

      final active = List<String>.from(state.telemetry.dtcs);
      final pending = <String>[];
      final permanent = <String>[];
      const simVin = 'MHKM1502XK0198421';
      final simOdo = state.telemetry.odometer;

      unawaited(
        _ref.read(settingsProvider.notifier).applyEcuVehicleIdentity(
              vin: simVin,
              odometer: simOdo,
            ),
      );

      return DiagnosticScanResult(
        protocol: 'ISO 15765-4 (CAN 11/500 - Simulator)',
        vin: simVin,
        milStatus: active.isNotEmpty,
        dtcCount: active.length + pending.length + permanent.length,
        supportedSensorsCount: ObdMetricType.values.length,
        activeDtcs: active,
        pendingDtcs: pending,
        permanentDtcs: permanent,
        imReadiness: {
          'mil': active.isNotEmpty,
          'misfire': true,
          'fuelSystem': true,
          'components': true,
          'catalyst': true,
          'evap': true,
          'o2Sensor': true,
          'o2Heater': true,
          'egr': true,
        },
        scanTimestamp: DateTime.now(),
        odometerKm: simOdo,
      );
    }

    // REAL ELM327 BLUETOOTH ECU SCAN
    // Temporarily pause background telemetry polling timer during diagnostic scan to avoid command collisions!
    _pollingTimer?.cancel();
    _isAwaitingResponse = false;

    String protocol = 'ISO 15765-4 (CAN 11bit)';
    String vin = 'Tidak Dilaporkan ECU';
    int supportedPids = 0;
    List<String> activeDtcs = [];
    List<String> pendingDtcs = [];
    List<String> permanentDtcs = [];
    Map<String, bool> readiness = {};
    double? odometerKm;

    try {
      // Step 1: Detect Protocol
      onProgress?.call(0.15, 'Mendeteksi Protokol Komunikasi ECU...');
      try {
        final dpResp = await _sendAndAwaitResponse('AT DP\r', timeout: const Duration(seconds: 3));
        protocol = ObdParser.parseProtocol(dpResp);
      } catch (e) {
        debugPrint("Protocol scan error: $e");
      }

      // Step 2: Read VIN & Vehicle Information (Mode 09 PID 02)
      onProgress?.call(0.30, 'Membaca Identitas & VIN Kendaraan (Mode 09)...');
      try {
        final vinResp = await _sendAndAwaitResponse('0902\r', timeout: const Duration(seconds: 4));
        final parsedVin = ObdParser.parseVin(vinResp);
        if (parsedVin != null && parsedVin.isNotEmpty) {
          vin = parsedVin;
        }
      } catch (e) {
        debugPrint("VIN scan error: $e");
      }

      // Step 2b: Odometer (Mode 01 PID A6) — not supported on all cars
      onProgress?.call(0.40, 'Membaca Odometer ECU (PID 01A6)...');
      try {
        final odoResp = await _sendAndAwaitResponse('01A6\r', timeout: const Duration(seconds: 3));
        odometerKm = ObdParser.parseOdometer(odoResp);
        if (odometerKm != null) {
          state = state.copyWith(
            telemetry: state.telemetry.copyWith(odometer: odometerKm),
          );
        }
      } catch (e) {
        debugPrint("Odometer scan error: $e");
      }

      // Step 3: Scan Supported PIDs (Mode 01 PID 00, 20, 40)
      onProgress?.call(0.50, 'Memindai Dukungan Sensor & Parameter ECU (Mode 01)...');
      try {
        final pid00Resp = await _sendAndAwaitResponse('0100\r', timeout: const Duration(seconds: 3));
        supportedPids = ObdParser.parseSupportedPidsCount(pid00Resp);
        if (supportedPids == 0) supportedPids = state.supportedSensors.length;
      } catch (e) {
        debugPrint("PID 00 scan error: $e");
      }

      // Step 4: Active Fault Codes (Mode 03)
      onProgress?.call(0.70, 'Membaca Kode Kerusakan Aktif / MIL (Mode 03)...');
      try {
        final mode03Resp = await _sendAndAwaitResponse('03\r', timeout: const Duration(seconds: 4));
        activeDtcs = ObdParser.parseDtc(mode03Resp);
      } catch (e) {
        debugPrint("Mode 03 scan error: $e");
      }

      // Step 5: Pending & Permanent Fault Codes (Mode 07 & Mode 0A)
      onProgress?.call(0.85, 'Membaca Kode Kerusakan Pending & Permanen (Mode 07/0A)...');
      try {
        final mode07Resp = await _sendAndAwaitResponse('07\r', timeout: const Duration(seconds: 4));
        pendingDtcs = ObdParser.parsePendingDtc(mode07Resp);
      } catch (e) {
        debugPrint("Mode 07 scan error: $e");
      }

      try {
        final mode0AResp = await _sendAndAwaitResponse('0A\r', timeout: const Duration(seconds: 4));
        permanentDtcs = ObdParser.parsePermanentDtc(mode0AResp);
      } catch (e) {
        debugPrint("Mode 0A scan error: $e");
      }

      // Step 6: Emission Readiness (PID 0101)
      onProgress?.call(0.95, 'Memeriksa Uji Kesiapan Emisi (I/M Readiness)...');
      try {
        final pid0101Resp = await _sendAndAwaitResponse('0101\r', timeout: const Duration(seconds: 4));
        readiness = ObdParser.parseImReadiness(pid0101Resp) ?? {};
      } catch (e) {
        debugPrint("PID 0101 scan error: $e");
      }

      state = state.copyWith(
        telemetry: state.telemetry.copyWith(dtcs: activeDtcs),
      );
    } finally {
      // Resume background telemetry polling
      _startPolling();
    }

    final isMilOn = readiness['mil'] ?? activeDtcs.isNotEmpty;
    final totalSensorsCount = supportedPids > 1
        ? supportedPids
        : (state.supportedSensors.isNotEmpty
            ? state.supportedSensors.length
            : (state.checkedSensors.isNotEmpty ? state.checkedSensors.length : 12));

    if (VinDecoder.isValidVin(vin) || (odometerKm != null && odometerKm > 0)) {
      unawaited(
        _ref.read(settingsProvider.notifier).applyEcuVehicleIdentity(
              vin: VinDecoder.isValidVin(vin) ? vin : null,
              odometer: odometerKm,
            ),
      );
    }

    return DiagnosticScanResult(
      protocol: protocol,
      vin: vin,
      milStatus: isMilOn,
      dtcCount: activeDtcs.length + pendingDtcs.length + permanentDtcs.length,
      supportedSensorsCount: totalSensorsCount,
      activeDtcs: activeDtcs,
      pendingDtcs: pendingDtcs,
      permanentDtcs: permanentDtcs,
      imReadiness: readiness,
      scanTimestamp: DateTime.now(),
      odometerKm: odometerKm,
    );
  }

  /// Lightweight identity read used by Settings "Ambil dari ECU".
  Future<EcuVehicleIdentityResult> fetchVehicleIdentity() async {
    if (state.status != ObdStatus.connected &&
        state.status != ObdStatus.initializing) {
      return const EcuVehicleIdentityResult(
        success: false,
        message:
            'Hubungkan OBD-II atau aktifkan Mode Simulator terlebih dahulu.',
      );
    }

    if (state.isSimulatorMode) {
      const simVin = 'MHKM1502XK0198421';
      final odo = state.telemetry.odometer;
      return EcuVehicleIdentityResult(
        success: true,
        vin: simVin,
        odometer: odo,
        suggestedName: VinDecoder.displayNameFromVin(simVin),
        message: 'Identitas simulator berhasil dibaca.',
      );
    }

    _pollingTimer?.cancel();
    _isAwaitingResponse = false;

    String? vin;
    double? odometer;
    try {
      try {
        final vinResp = await _sendAndAwaitResponse(
          '0902\r',
          timeout: const Duration(seconds: 4),
        );
        vin = ObdParser.parseVin(vinResp);
      } catch (e) {
        debugPrint('fetchVehicleIdentity VIN: $e');
      }

      try {
        final odoResp = await _sendAndAwaitResponse(
          '01A6\r',
          timeout: const Duration(seconds: 3),
        );
        odometer = ObdParser.parseOdometer(odoResp);
        if (odometer != null) {
          state = state.copyWith(
            telemetry: state.telemetry.copyWith(odometer: odometer),
          );
        }
      } catch (e) {
        debugPrint('fetchVehicleIdentity odometer: $e');
      }
    } finally {
      _startPolling();
    }

    final hasVin = VinDecoder.isValidVin(vin);
    final hasOdo = odometer != null && odometer > 0;
    if (!hasVin && !hasOdo) {
      return const EcuVehicleIdentityResult(
        success: false,
        message:
            'ECU tidak mengembalikan VIN/odometer. Banyak mobil lama tidak mendukung PID ini — isi manual jika perlu.',
      );
    }

    return EcuVehicleIdentityResult(
      success: true,
      vin: hasVin ? vin : null,
      odometer: hasOdo ? odometer : null,
      suggestedName: hasVin ? VinDecoder.displayNameFromVin(vin) : null,
      message: [
        if (hasVin) 'VIN dibaca',
        if (hasOdo) 'Odometer dibaca',
        if (!hasVin) 'VIN tidak tersedia',
        if (!hasOdo) 'Odometer (01A6) tidak didukung ECU',
      ].join(' · '),
    );
  }

  Future<bool> clearDtcCodes() async {
    if (state.status != ObdStatus.connected) {
      return false;
    }
    final currentDtcs = List<String>.from(state.telemetry.dtcs);
    if (state.isSimulatorMode) {
      _simulator.clearDtcs();
      state = state.copyWith(
        telemetry: state.telemetry.copyWith(dtcs: []),
      );
    } else {
      try {
        await _sendAndAwaitResponse('04\r', timeout: const Duration(seconds: 5));
        state = state.copyWith(
          telemetry: state.telemetry.copyWith(dtcs: []),
        );
      } catch (e) {
        debugPrint("Failed to clear DTC codes: $e");
        return false;
      }
    }

    try {
      final db = _ref.read(databaseProvider);
      final now = DateTime.now();
      for (final code in currentDtcs) {
        await db.into(db.dtcLogs).insert(
          DtcLogsCompanion.insert(
            timestamp: now,
            code: code,
            description: 'Penghapusan via Scanner Diagnostik',
            category: code.startsWith('P') ? 'Powertrain' : (code.startsWith('C') ? 'Chassis' : 'Body/Network'),
            active: const Value(false),
            resolvedTime: Value(now),
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to save cleared DTC log: $e");
    }

    return true;
  }

  void _onConnectionLost(String reason) {
    _disconnectReal();
    state = state.copyWith(
      status: ObdStatus.error,
      errorMessage: reason,
    );
  }

  @override
  void dispose() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
    _stopSimulation();
    _disconnectReal();
    super.dispose();
  }
}

final obdServiceProvider = StateNotifierProvider<ObdService, ObdState>((ref) {
  return ObdService(ref);
});

final pairedDevicesProvider = FutureProvider.autoDispose<List<BluetoothDevice>>((ref) async {
  return ref.read(obdServiceProvider.notifier).getPairedDevices();
});
