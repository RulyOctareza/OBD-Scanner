import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../obd/obd_parser.dart';
import '../obd/obd_simulator.dart';
import '../obd/obd_telemetry.dart';

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

  ObdState({
    required this.status,
    this.errorMessage,
    required this.telemetry,
    required this.isSimulatorMode,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
  });

  factory ObdState.initial() {
    return ObdState(
      status: ObdStatus.disconnected,
      telemetry: ObdTelemetry.empty(),
      isSimulatorMode: false,
    );
  }

  ObdState copyWith({
    ObdStatus? status,
    String? errorMessage,
    ObdTelemetry? telemetry,
    bool? isSimulatorMode,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
  }) {
    return ObdState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      telemetry: telemetry ?? this.telemetry,
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      connectedDeviceAddress: connectedDeviceAddress ?? this.connectedDeviceAddress,
    );
  }
}

class ObdService extends StateNotifier<ObdState> {
  final ObdSimulator _simulator = ObdSimulator();
  BluetoothConnection? _connection;
  StreamSubscription? _simSubscription;
  Timer? _pollingTimer;
  Completer<String>? _pendingResponseCompleter;

  final StringBuffer _rxBuffer = StringBuffer();
  final List<String> _pendingCommands = ['AT RV', '010C', '010D', '0105', '010F', '010B', '0110', '010E', '0111', '0104', '01A6', '012F', '03'];
  int _currentCommandIndex = 0;
  bool _isAwaitingResponse = false;
  DateTime? _lastActivityTime;

  static const int _responseTimeoutMs = 3000;

  ObdService() : super(ObdState.initial()) {
    if (state.isSimulatorMode) {
      _startSimulation();
    } else {
      _autoConnect();
    }
  }

  static const String _lastDeviceAddressKey = 'last_obd_device_address';

  Future<void> _autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAddress = prefs.getString(_lastDeviceAddressKey);
      if (lastAddress != null && lastAddress.isNotEmpty) {
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastDeviceAddressKey, device.address);

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
      state = state.copyWith(status: ObdStatus.disconnected);
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
    if (command == 'AT RV') {
      final val = ObdParser.parseVoltage(response);
      if (val != null) current = current.copyWith(voltage: val);
    } else if (command == '010C') {
      final val = ObdParser.parseRpm(response);
      if (val != null) current = current.copyWith(rpm: val);
    } else if (command == '010D') {
      final val = ObdParser.parseSpeed(response);
      if (val != null) current = current.copyWith(speed: val);
    } else if (command == '0105') {
      final val = ObdParser.parseCoolant(response);
      if (val != null) current = current.copyWith(coolant: val);
    } else if (command == '010F') {
      final val = ObdParser.parseIntakeAirTemp(response);
      if (val != null) current = current.copyWith(intakeAirTemp: val);
    } else if (command == '010B') {
      final val = ObdParser.parseMap(response);
      if (val != null) current = current.copyWith(mapValue: val);
    } else if (command == '0110') {
      final val = ObdParser.parseMaf(response);
      if (val != null) current = current.copyWith(maf: val);
    } else if (command == '010E') {
      final val = ObdParser.parseTimingAdvance(response);
      if (val != null) current = current.copyWith(timingAdvance: val);
    } else if (command == '0111') {
      final val = ObdParser.parseThrottle(response);
      if (val != null) current = current.copyWith(throttle: val);
    } else if (command == '0104') {
      final val = ObdParser.parseEngineLoad(response);
      if (val != null) current = current.copyWith(engineLoad: val);
    } else if (command == '01A6') {
      final val = ObdParser.parseOdometer(response);
      if (val != null) current = current.copyWith(odometer: val);
    } else if (command == '012F') {
      final val = ObdParser.parseFuelLevel(response);
      if (val != null) current = current.copyWith(fuelLevel: val);
    } else if (command == '03') {
      final val = ObdParser.parseDtc(response);
      current = current.copyWith(dtcs: val);
    }
    state = state.copyWith(
      telemetry: current.copyWith(timestamp: DateTime.now()),
    );
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
    _stopSimulation();
    _disconnectReal();
    super.dispose();
  }
}

final obdServiceProvider = StateNotifierProvider<ObdService, ObdState>((ref) {
  return ObdService();
});

final pairedDevicesProvider = FutureProvider.autoDispose<List<BluetoothDevice>>((ref) async {
  return ref.read(obdServiceProvider.notifier).getPairedDevices();
});
