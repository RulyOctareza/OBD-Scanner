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
import '../database/database.dart';
import '../database/database_provider.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../../features/live_data/presentation/widgets/gauge_widget.dart';

class DiagnosticScanResult {
  final List<String> activeDtcs;
  final List<String> pendingDtcs;
  final List<String> permanentDtcs;
  final Map<String, bool> imReadiness;

  DiagnosticScanResult({
    required this.activeDtcs,
    required this.pendingDtcs,
    required this.permanentDtcs,
    required this.imReadiness,
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

  ObdState({
    required this.status,
    this.errorMessage,
    required this.telemetry,
    required this.isSimulatorMode,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
    required this.supportedSensors,
    required this.checkedSensors,
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
    String? errorMessage,
    ObdTelemetry? telemetry,
    bool? isSimulatorMode,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
    Set<ObdMetricType>? supportedSensors,
    Set<ObdMetricType>? checkedSensors,
  }) {
    return ObdState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      telemetry: telemetry ?? this.telemetry,
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      connectedDeviceAddress: connectedDeviceAddress ?? this.connectedDeviceAddress,
      supportedSensors: supportedSensors ?? this.supportedSensors,
      checkedSensors: checkedSensors ?? this.checkedSensors,
    );
  }
}

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
    Future.microtask(() {
      if (state.isSimulatorMode) {
        _startSimulation();
      } else {
        // Wait 3 seconds on app startup to give the OS Bluetooth stack and 
        // ELM327 dongle time to fully release the previous RFCOMM connection.
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _autoConnect();
          }
        });
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
        final db = _ref.read(databaseProvider);
        final autoConnectOBD = await db.getBoolPreference('auto_connect_obd') ?? true;
        final isSimulatorMode = await db.getBoolPreference('is_simulator_mode') ?? false;

        if (autoConnectOBD &&
            !isSimulatorMode &&
            (state.status == ObdStatus.disconnected || state.status == ObdStatus.error)) {
          _autoConnect();
        }
      } catch (e) {
        debugPrint('Auto-reconnect check failed: $e');
      }
    });
  }

  Future<void> _autoConnect() async {
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

  void toggleSimulatorMode(bool value) {
    if (state.isSimulatorMode == value) return;
    if (state.isSimulatorMode) {
      _stopSimulation();
    } else {
      _disconnectReal();
    }
    state = state.copyWith(
      isSimulatorMode: value,
      status: ObdStatus.disconnected,
      telemetry: ObdTelemetry.empty(),
    );
    if (value) {
      _startSimulation();
    }
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
      toggleSimulatorMode(false);
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

  Future<DiagnosticScanResult> performFullDiagnosticScan() async {
    if (state.isSimulatorMode) {
      final active = List<String>.from(state.telemetry.dtcs);
      return DiagnosticScanResult(
        activeDtcs: active,
        pendingDtcs: const [],
        permanentDtcs: const [],
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
      );
    }

    List<String> activeDtcs = [];
    List<String> pendingDtcs = [];
    List<String> permanentDtcs = [];
    Map<String, bool> readiness = {};

    try {
      final mode03Resp = await _sendAndAwaitResponse('03\r', timeout: const Duration(seconds: 4));
      activeDtcs = ObdParser.parseDtc(mode03Resp);
    } catch (e) {
      debugPrint("Mode 03 scan error: $e");
    }

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

    try {
      final pid0101Resp = await _sendAndAwaitResponse('0101\r', timeout: const Duration(seconds: 4));
      readiness = ObdParser.parseImReadiness(pid0101Resp) ?? {};
    } catch (e) {
      debugPrint("PID 0101 scan error: $e");
    }

    state = state.copyWith(
      telemetry: state.telemetry.copyWith(dtcs: activeDtcs),
    );

    return DiagnosticScanResult(
      activeDtcs: activeDtcs,
      pendingDtcs: pendingDtcs,
      permanentDtcs: permanentDtcs,
      imReadiness: readiness,
    );
  }

  Future<bool> clearDtcCodes() async {
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
