import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'obd_link.dart';
import '../obd/obd_metric.dart';
import '../obd/obd_parser.dart';
import '../obd/obd_simulator.dart';
import '../obd/obd_telemetry.dart';
import '../obd/vin_decoder.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import '../services/background_service.dart';
import '../../features/settings/presentation/settings_provider.dart';

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

  /// False when mode 03 got no real answer: [activeDtcs] then holds the codes
  /// already known from polling (or none), not a fresh "no codes" result.
  final bool activeDtcsRead;

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
    this.activeDtcsRead = true,
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

/// What a request to clear the stored trouble codes actually achieved, judged
/// by reading mode 03 back afterwards rather than by the answer to mode 04.
enum DtcClearOutcome {
  /// The read-back reports no stored codes.
  cleared,

  /// Some codes are gone, others are still stored.
  partial,

  /// Nothing was cleared (ECUs often refuse while the engine runs).
  rejected,

  /// The read-back never answered, so nothing is known and nothing changed.
  failed,
}

class DtcClearResult {
  final DtcClearOutcome outcome;

  /// Codes that disappeared; only these are logged as resolved.
  final List<String> removed;

  /// Codes still stored according to the read-back.
  final List<String> remaining;

  const DtcClearResult(
    this.outcome, {
    this.removed = const [],
    this.remaining = const [],
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

  /// One line, shown in banners and snackbars.
  final String? errorMessage;

  /// Multi-line troubleshooting steps for [errorMessage], shown in the
  /// connection sheet only.
  final String? errorHelp;

  /// Current step or retry text while connecting; null otherwise.
  final String? statusDetail;
  final ObdTelemetry telemetry;
  final bool isSimulatorMode;
  final String? connectedDeviceName;
  final String? connectedDeviceAddress;
  final Set<ObdMetricType> supportedSensors;
  final Set<ObdMetricType> checkedSensors;
  final bool simHighTemp;
  final bool simLowVoltage;
  final bool simHasDtc;

  /// Trouble codes were read on this link (a mode 03 answer, a diagnostic
  /// scan or a clear), so an empty `telemetry.dtcs` means "no codes" rather
  /// than "not asked yet". Reset wherever [checkedSensors] is; always true in
  /// simulator mode.
  final bool dtcsChecked;

  ObdState({
    required this.status,
    this.errorMessage,
    this.errorHelp,
    this.statusDetail,
    required this.telemetry,
    required this.isSimulatorMode,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
    required this.supportedSensors,
    required this.checkedSensors,
    this.simHighTemp = false,
    this.simLowVoltage = false,
    this.simHasDtc = false,
    this.dtcsChecked = false,
  });

  factory ObdState.initial() {
    return ObdState(
      status: ObdStatus.disconnected,
      telemetry: ObdTelemetry.empty(),
      isSimulatorMode: false,
      supportedSensors: const {},
      checkedSensors: const {},
      dtcsChecked: false,
    );
  }

  ObdState copyWith({
    ObdStatus? status,
    Object? errorMessage = _obdUnset,
    Object? errorHelp = _obdUnset,
    Object? statusDetail = _obdUnset,
    ObdTelemetry? telemetry,
    bool? isSimulatorMode,
    Object? connectedDeviceName = _obdUnset,
    Object? connectedDeviceAddress = _obdUnset,
    Set<ObdMetricType>? supportedSensors,
    Set<ObdMetricType>? checkedSensors,
    bool? simHighTemp,
    bool? simLowVoltage,
    bool? simHasDtc,
    bool? dtcsChecked,
  }) {
    return ObdState(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _obdUnset)
          ? this.errorMessage
          : errorMessage as String?,
      errorHelp: identical(errorHelp, _obdUnset)
          ? this.errorHelp
          : errorHelp as String?,
      statusDetail: identical(statusDetail, _obdUnset)
          ? this.statusDetail
          : statusDetail as String?,
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
      dtcsChecked: dtcsChecked ?? this.dtcsChecked,
    );
  }
}

const Object _obdUnset = Object();

/// Thrown inside a connect attempt that was cancelled or superseded; the
/// attempt then exits without touching state.
class _ConnectCancelled implements Exception {
  const _ConnectCancelled();
}

class ObdService extends StateNotifier<ObdState> {
  final Ref _ref;
  final ObdSimulator _simulator = ObdSimulator();
  ObdLink? _connection;
  StreamSubscription? _simSubscription;
  Timer? _pollingTimer;
  Timer? _autoReconnectTimer;
  Completer<String>? _pendingResponseCompleter;

  final StringBuffer _rxBuffer = StringBuffer();
  // Live PIDs only. Mode 03 (DTCs) is polled sparsely to cut BT radio use.
  final List<String> _pendingCommands = [
    'AT RV',
    '010C',
    '010D',
    '0105',
    '010F',
    '010B',
    '0110',
    '010E',
    '0111',
    '0104',
    '01A6',
    '012F',
  ];
  int _currentCommandIndex = 0;
  int _pollCycleCount = 0;

  // Whether a live PID got a real answer in the current poll cycle. With the
  // ignition off the adapter still answers NO DATA to everything, so NO DATA
  // to the cycle's mode 03 only means "no stored codes" when this is true.
  bool _ecuAnsweredThisCycle = false;
  bool _isAwaitingResponse = false;
  DateTime? _lastActivityTime;
  bool _userRequestedDisconnect = false;

  /// Backoff for auto-reconnect: 15s → 30s → 60s → 120s (cap).
  Duration _reconnectDelay = const Duration(seconds: 15);
  static const Duration _minReconnectDelay = Duration(seconds: 15);
  static const Duration _maxReconnectDelay = Duration(seconds: 120);
  /// Poll stored DTCs once every N full live-PID cycles (~every ~30–60s).
  static const int _dtcPollEveryNCycles = 20;

  static const int _responseTimeoutMs = 3000;

  /// The vendored plugin's native connect runs up to three blocking RFCOMM
  /// attempts in a row (packages/flutter_bluetooth_serial/LOCAL_CHANGES.md).
  /// This must exceed their sum, otherwise a native connect that is still
  /// running gets abandoned.
  static const Duration _socketOpenTimeout = Duration(seconds: 40);

  /// Bumped by every new connect, cancel and disconnect. A connect attempt
  /// whose token is no longer current must not touch state or the socket.
  int _connectToken = 0;

  /// Bumped whenever a socket is attached or torn down. Listener callbacks of
  /// an older socket compare against it and are ignored, because disposing a
  /// plugin connection fires its input `onDone` asynchronously.
  int _linkGeneration = 0;

  /// Completes when the most recent native connect has finished either way.
  Future<void>? _socketOpenInFlight;

  bool _pollingActive = false;
  Future<void> _exclusiveTail = Future.value();
  int _autoConnectHolds = 0;

  bool get _isConnectBusy =>
      state.status == ObdStatus.connecting ||
      state.status == ObdStatus.initializing;

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
          Future.delayed(const Duration(seconds: 3), () async {
            try {
              if (await _autoConnectAllowed()) await _autoConnect();
            } catch (e) {
              debugPrint('Startup auto-connect failed: $e');
            }
          });
        }
      } catch (e) {
        debugPrint('OBD startup mode restore failed: $e');
      }
      // The awaited prefs read can outlive this notifier (and its container).
      if (!mounted) return;
      _startAutoReconnectTimer();
    });
  }

  void _startAutoReconnectTimer() {
    if (!_ref.read(obdAutoReconnectTimerProvider)) return;
    _scheduleNextReconnectCheck();
  }

  void _scheduleNextReconnectCheck() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer(_reconnectDelay, () async {
      try {
        if (!mounted) return;
        if (await _autoConnectAllowed()) {
          await _autoConnect();
          // Back off when still disconnected after an attempt.
          if (mounted &&
              (state.status == ObdStatus.disconnected ||
                  state.status == ObdStatus.error)) {
            _bumpReconnectDelay();
          }
        }
      } catch (e) {
        debugPrint('Auto-reconnect check failed: $e');
        _bumpReconnectDelay();
      }
      if (mounted) {
        _scheduleNextReconnectCheck();
      }
    });
  }

  void _bumpReconnectDelay() {
    final nextMs = (_reconnectDelay.inMilliseconds * 2)
        .clamp(_minReconnectDelay.inMilliseconds, _maxReconnectDelay.inMilliseconds);
    _reconnectDelay = Duration(milliseconds: nextMs);
  }

  void _resetReconnectDelay() {
    _reconnectDelay = _minReconnectDelay;
    // A check already waiting out a backed-off delay (up to 120 s) would
    // otherwise be the first to notice the next dropped link.
    if (_autoReconnectTimer != null) _scheduleNextReconnectCheck();
  }

  /// The one rule for every automatic connect, at startup and from the
  /// reconnect timer: the "Hubungkan otomatis" switch is on, the app is not in
  /// simulator mode, the link is idle, and the user has not cancelled or
  /// disconnected by hand. That latch clears only on a manual connect or when
  /// the switch is turned back on ([allowAutoReconnect]).
  Future<bool> _autoConnectAllowed() async {
    bool idle() =>
        mounted &&
        !state.isSimulatorMode &&
        !_userRequestedDisconnect &&
        (state.status == ObdStatus.disconnected ||
            state.status == ObdStatus.error);
    if (!idle()) return false;
    final db = _ref.read(databaseProvider);
    final enabled = await db.getBoolPreference('auto_connect_obd') ?? true;
    final simPref = await db.getBoolPreference('is_simulator_mode') ?? false;
    // Checked again after the reads: the user may have tapped Batal meanwhile.
    return enabled && !simPref && idle();
  }

  /// The connection sheet holds auto-connect while it is open, so a
  /// background attempt neither grabs the dongle nor cancels discovery while
  /// the user is choosing or pairing a device.
  void holdAutoConnect() => _autoConnectHolds++;

  void releaseAutoConnect() {
    if (_autoConnectHolds > 0) _autoConnectHolds--;
  }

  Future<void> _autoConnect() async {
    if (state.isSimulatorMode) return;
    if (_autoConnectHolds > 0) return;
    if (_isConnectBusy || state.status == ObdStatus.connected) {
      return;
    }
    try {
      final db = _ref.read(databaseProvider);
      final lastAddress =
          await db.getPreference('last_obd_device_address') ?? '';
      if (lastAddress.isEmpty) return;

      // Never prompts: prompting on the background reconnect path wakes the
      // permission / location stack every cycle.
      if (!await _ref.read(obdLinkConnectorProvider).isReady()) return;

      debugPrint('Auto-connecting to last device: $lastAddress');
      final lastName =
          await db.getPreference('last_obd_device_name') ?? 'OBD-II';
      final targetDevice = BluetoothDevice(
        name: lastName,
        address: lastAddress,
      );
      await connectToDevice(targetDevice, maxRetries: 1);
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
      // Abandon any real connect in flight so it cannot flip state to a real
      // link after the simulator took over.
      _connectToken++;
      _disconnectReal();
      _stopSimulation();
      unawaited(stopBackgroundMonitoring());

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
        errorHelp: null,
        statusDetail: null,
        supportedSensors: const {},
        checkedSensors: const {},
        dtcsChecked: false,
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
        errorHelp: null,
        statusDetail: null,
        supportedSensors: const {},
        checkedSensors: const {},
        dtcsChecked: false,
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

  Future<void> connectToDevice(
    BluetoothDevice device, {
    int maxRetries = 2,
  }) async {
    if (_isConnectBusy) return;
    final token = ++_connectToken;
    _userRequestedDisconnect = false;

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

    // Switching adapters: tear the current link down first, otherwise its
    // socket leaks when _connection is replaced and keeps holding that dongle.
    if (_connection != null) {
      _disconnectReal();
      unawaited(stopBackgroundMonitoring());
    }

    final deviceName = device.name ?? 'OBD-II';
    state = state.copyWith(
      status: ObdStatus.connecting,
      errorMessage: null,
      errorHelp: null,
      statusDetail: 'Membuka koneksi Bluetooth…',
      connectedDeviceName: device.name,
      connectedDeviceAddress: device.address,
      supportedSensors: const {},
      checkedSensors: const {},
      dtcsChecked: false,
    );

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final connection = await _openSocket(device.address, token);
        _connection = connection;
        _attachListener(connection);

        state = state.copyWith(
          status: ObdStatus.initializing,
          statusDetail: 'Menyiapkan adapter ELM327…',
        );

        await _initElm327(token);

        state = state.copyWith(
          status: ObdStatus.connected,
          statusDetail: null,
          errorMessage: null,
          errorHelp: null,
        );
        _resetReconnectDelay();

        // Save address + name for future auto-connect (no bonded-list scan).
        final settings = _ref.read(settingsProvider.notifier);
        settings.updateLastOBDAddress(device.address);
        unawaited(
          _ref.read(databaseProvider).setPreference(
                'last_obd_device_name',
                deviceName,
              ),
        );

        _startPolling();
        unawaited(startBackgroundMonitoring());
        return;
      } on _ConnectCancelled {
        return;
      } catch (e) {
        if (token != _connectToken) return;
        _disconnectReal();
        if (attempt == maxRetries) {
          final failure = _describeConnectFailure(e, deviceName);
          state = state.copyWith(
            status: ObdStatus.error,
            statusDetail: null,
            errorMessage: failure.message,
            errorHelp: failure.help,
          );
          unawaited(stopBackgroundMonitoring());
        } else {
          state = state.copyWith(
            status: ObdStatus.connecting,
            statusDetail:
                'Percobaan $attempt dari $maxRetries gagal, mencoba lagi…',
          );
          await Future.delayed(const Duration(seconds: 2));
          if (token != _connectToken) return;
        }
      }
    }
  }

  /// Abandons a connect in progress. A native connect that is still running
  /// is closed when it finishes (see [_openSocket]).
  void cancelConnect() {
    if (!_isConnectBusy) return;
    _connectToken++;
    _userRequestedDisconnect = true;
    _disconnectReal();
    state = state.copyWith(
      status: ObdStatus.disconnected,
      statusDetail: null,
      errorMessage: null,
      errorHelp: null,
      supportedSensors: const {},
      checkedSensors: const {},
      dtcsChecked: false,
    );
    unawaited(stopBackgroundMonitoring());
  }

  /// Opens the RFCOMM socket without ever leaving one this process does not
  /// own: the dongle accepts a single client, so an orphaned socket blocks
  /// every later attempt until the app is killed.
  Future<ObdLink> _openSocket(String address, int token) async {
    final previous = _socketOpenInFlight;
    if (previous != null) {
      // Two native connects to the same dongle at once make both fail.
      state = state.copyWith(
        statusDetail: 'Menunggu koneksi sebelumnya ditutup…',
      );
      await previous.timeout(_socketOpenTimeout, onTimeout: () {});
      _throwIfCancelled(token);
      state = state.copyWith(statusDetail: 'Membuka koneksi Bluetooth…');
    }

    final connector = _ref.read(obdLinkConnectorProvider);
    try {
      await connector.cancelDiscovery();
    } catch (e) {
      debugPrint('Error canceling discovery: $e');
    }
    _throwIfCancelled(token);

    // A Dart timeout does not stop the native connect, so a socket that opens
    // after the timeout is disposed here instead of being dropped.
    var abandoned = false;
    final open = connector.open(address);
    final settled = open.then<void>(
      (connection) {
        if (abandoned) connection.dispose();
      },
      onError: (Object _) {},
    );
    _socketOpenInFlight = settled;
    unawaited(
      settled.whenComplete(() {
        if (identical(_socketOpenInFlight, settled)) {
          _socketOpenInFlight = null;
        }
      }),
    );

    final ObdLink connection;
    try {
      connection = await open.timeout(_socketOpenTimeout);
    } on TimeoutException {
      abandoned = true;
      rethrow;
    }
    if (token != _connectToken) {
      connection.dispose();
      throw const _ConnectCancelled();
    }
    return connection;
  }

  void _throwIfCancelled(int token) {
    if (token != _connectToken) throw const _ConnectCancelled();
  }

  void _attachListener(ObdLink connection) {
    final generation = ++_linkGeneration;
    connection.input.listen(
      (data) {
        if (generation == _linkGeneration) _onDataReceived(data);
      },
      onError: (Object e) => debugPrint('OBD input error: $e'),
      onDone: () {
        if (generation == _linkGeneration) _onLinkClosed();
      },
    );
  }

  void _onLinkClosed() {
    if (state.status == ObdStatus.connected) {
      _onConnectionLost();
    } else {
      // Mid-connect: fail the pending init command now; the connect loop owns
      // state and decides whether to retry.
      _disconnectReal();
    }
  }

  Future<void> _initElm327(int token) async {
    // AT Z reboots the chip; clones can take well over a second to return
    // the prompt, so it gets a longer timeout than the other commands.
    const steps = <(String, Duration)>[
      ('AT Z\r', Duration(seconds: 5)),
      ('AT E0\r', Duration(seconds: 3)),
      ('AT SP 0\r', Duration(seconds: 3)),
    ];
    const int maxRetries = 2;

    for (final (cmd, timeout) in steps) {
      bool success = false;
      for (int attempt = 0; attempt < maxRetries && !success; attempt++) {
        _throwIfCancelled(token);
        try {
          await _sendAndAwaitResponse(cmd, timeout: timeout);
          success = true;
        } catch (e) {
          debugPrint("Init $cmd attempt ${attempt + 1} failed: $e");
          if (attempt < maxRetries - 1) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }
      if (!success) {
        throw Exception("Init ELM327 gagal: ${cmd.trim()}");
      }
      if (cmd == 'AT Z\r') {
        await Future.delayed(const Duration(milliseconds: 500));
        _rxBuffer.clear();
      }
    }

    // With AT SP 0 the first OBD request starts the protocol search, which
    // takes several seconds on older K-line cars. Running it here, before
    // polling starts, keeps the poll watchdog from sending a command
    // mid-search, which makes the ELM327 abort the search. Not fatal: with the
    // ignition off the car does not answer yet.
    _throwIfCancelled(token);
    state = state.copyWith(statusDetail: 'Mendeteksi protokol mobil…');
    try {
      await _sendAndAwaitResponse(
        '0100\r',
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('Protocol warm-up: $e');
    }
    _throwIfCancelled(token);
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Connection not active');
    }
  }

  Future<String> _sendAndAwaitResponse(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) {
      throw Exception("Connection not active");
    }
    // Leftovers of an aborted or late response would be prepended otherwise.
    _rxBuffer.clear();
    final completer = Completer<String>();
    _pendingResponseCompleter = completer;
    final response = completer.future.timeout(timeout);
    // _disconnectReal can fail the completer before anyone awaits it.
    unawaited(response.then((_) {}, onError: (Object _) {}));
    try {
      await connection.send(ascii.encode(command));
      return await response;
    } finally {
      if (identical(_pendingResponseCompleter, completer)) {
        _pendingResponseCompleter = null;
      }
    }
  }

  void disconnect() {
    if (state.isSimulatorMode) return;
    if (_isConnectBusy) {
      cancelConnect();
      return;
    }
    _userRequestedDisconnect = true;
    _connectToken++;
    _disconnectReal();
    state = state.copyWith(
      status: ObdStatus.disconnected,
      statusDetail: null,
      errorMessage: null,
      errorHelp: null,
      supportedSensors: const {},
      checkedSensors: const {},
      dtcsChecked: false,
    );
    unawaited(stopBackgroundMonitoring());
  }

  /// Clears the manual-disconnect latch so auto-reconnect may run again.
  void allowAutoReconnect() {
    _userRequestedDisconnect = false;
    _resetReconnectDelay();
  }

  void _disconnectReal() {
    _linkGeneration++;
    _stopPolling();
    _connection?.dispose();
    _connection = null;
    _rxBuffer.clear();
    _isAwaitingResponse = false;
    _currentCommandIndex = 0;
    _pollCycleCount = 0;
    _ecuAnsweredThisCycle = false;
    final pending = _pendingResponseCompleter;
    _pendingResponseCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(Exception("Disconnected"));
    }
  }

  void _startSimulation() {
    _simSubscription?.cancel();
    _simulator.start();
    _simSubscription = _simulator.telemetryStream.listen((telemetry) {
      state = state.copyWith(
        status: ObdStatus.connected,
        telemetry: telemetry,
        supportedSensors: _allSensors,
        checkedSensors: _allSensors,
        dtcsChecked: true,
      );
    });
  }

  void _stopSimulation() {
    _simSubscription?.cancel();
    _simSubscription = null;
    _simulator.stop();
  }

  void _startPolling() {
    _stopPolling();
    final connection = _connection;
    if (connection == null || !connection.isConnected) return;
    _pollingActive = true;
    _isAwaitingResponse = false;
    _currentCommandIndex = 0;
    _ecuAnsweredThisCycle = false;
    _rxBuffer.clear();
    _sendNextCommand();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollWatchdog(),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingActive = false;
  }

  void _pollWatchdog() {
    if (!_pollingActive || !_isAwaitingResponse) return;
    final last = _lastActivityTime;
    if (last != null &&
        clock.now().difference(last) <=
            const Duration(milliseconds: _responseTimeoutMs)) {
      return;
    }
    // Skip the PID that went silent instead of re-sending it forever.
    _isAwaitingResponse = false;
    _rxBuffer.clear();
    _advanceCommandIndex();
    _sendNextCommand();
  }

  /// Stops polling and waits for the poll command already on the wire to
  /// answer, so the next one-shot command does not receive that answer.
  Future<void> _pausePolling() async {
    _stopPolling();
    final deadline = clock.now().add(
      const Duration(milliseconds: _responseTimeoutMs),
    );
    while (_isAwaitingResponse &&
        _connection != null &&
        clock.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 40));
    }
    _isAwaitingResponse = false;
    _rxBuffer.clear();
  }

  /// Runs one-shot command sequences one at a time with polling paused. The
  /// ELM327 cannot multiplex: a command sent before the previous `>` prompt
  /// corrupts both responses.
  Future<T> _withPollingPaused<T>(Future<T> Function() body) {
    final run = _exclusiveTail.then((_) async {
      await _pausePolling();
      try {
        return await body();
      } finally {
        if (mounted &&
            state.status == ObdStatus.connected &&
            !state.isSimulatorMode &&
            _connection?.isConnected == true) {
          _startPolling();
        }
      }
    });
    _exclusiveTail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _sendString(String command) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) return;
    try {
      await connection.send(ascii.encode(command));
    } catch (e) {
      debugPrint('OBD send failed: $e');
    }
  }

  String _commandAtIndex(int index) {
    if (index < _pendingCommands.length) {
      return _pendingCommands[index];
    }
    // Sparse DTC slot appended after a full live-PID cycle.
    return '03';
  }

  int get _commandsPerCycle {
    // Also in the first cycle of each link (the count resets on disconnect),
    // so the trouble-code state is known about a second after connecting
    // instead of ~20 cycles later.
    final includeDtc = _pollCycleCount % _dtcPollEveryNCycles == 0;
    return _pendingCommands.length + (includeDtc ? 1 : 0);
  }

  void _advanceCommandIndex() {
    _currentCommandIndex++;
    if (_currentCommandIndex >= _commandsPerCycle) {
      _currentCommandIndex = 0;
      _pollCycleCount++;
      _ecuAnsweredThisCycle = false;
    }
  }

  void _sendNextCommand() {
    if (!_pollingActive || _isAwaitingResponse) return;
    if (_pendingCommands.isEmpty) return;
    final cmd = _commandAtIndex(_currentCommandIndex);
    _isAwaitingResponse = true;
    _lastActivityTime = clock.now();
    unawaited(_sendString('$cmd\r'));
  }

  /// ELM327 clones emit stray non-ASCII bytes, notably around AT Z. Only
  /// printable ASCII plus CR/LF is kept, so one bad byte cannot throw away a
  /// chunk that carries the `>` prompt.
  static bool _isElmByte(int b) =>
      b == 0x0A || b == 0x0D || (b >= 0x20 && b < 0x7F);

  void _onDataReceived(Uint8List data) {
    final text = String.fromCharCodes(data.where(_isElmByte));
    if (text.isEmpty) return;
    _rxBuffer.write(text);
    _lastActivityTime = clock.now();

    if (!text.contains('>')) return;

    final fullResponse = _rxBuffer.toString();
    _rxBuffer.clear();
    _isAwaitingResponse = false;

    final completer = _pendingResponseCompleter;
    if (completer != null && !completer.isCompleted) {
      _pendingResponseCompleter = null;
      completer.complete(fullResponse);
      return;
    }

    // No owner: a late answer to a timed-out one-shot command, or a poll
    // answer that arrived after polling paused. Parsing it would attribute it
    // to the wrong command.
    if (!_pollingActive) return;

    _parseResponse(_commandAtIndex(_currentCommandIndex), fullResponse);
    _advanceCommandIndex();
    _sendNextCommand();
  }

  static ({String message, String help}) _describeConnectFailure(
    Object error,
    String deviceName,
  ) {
    final raw = error.toString();
    final err = raw.toLowerCase();
    final detail = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;

    if (err.contains('init elm327')) {
      return (
        message: 'Adapter tersambung, tetapi tidak menjawab perintah ELM327.',
        help: '1. Cabut adapter selama 10 detik, lalu pasang kembali.\n'
            '2. Pastikan perangkat yang dipilih adalah adapter OBD (ELM327), '
            'bukan perangkat Bluetooth lain.\n\n'
            'Detail teknis: $detail',
      );
    }
    if (error is TimeoutException ||
        err.contains('read failed') ||
        err.contains('socket might closed') ||
        err.contains('timeout') ||
        err.contains('connection failed')) {
      return (
        message: '$deviceName tidak merespons.',
        help: '1. Pastikan adapter terpasang dan kontak ON '
            '(lampu adapter menyala).\n'
            '2. Tutup paksa aplikasi OBD lain (Torque, Car Scanner, dll.). '
            'Adapter hanya bisa dipakai satu aplikasi.\n'
            '3. Cabut adapter selama 10 detik, lalu pasang kembali.\n'
            '4. Jika masih gagal, lupakan perangkat di setelan Bluetooth HP, '
            'lalu pasangkan ulang (PIN biasanya 1234 atau 0000).\n\n'
            'Detail teknis: $detail',
      );
    }
    return (
      message: 'Gagal terhubung ke $deviceName.',
      help: 'Coba lagi beberapa saat. Jika terus gagal, cabut adapter 10 detik, '
          'lalu pasang kembali.\n\n'
          'Detail teknis: $detail',
    );
  }

  void _parseResponse(String command, String response) {
    ObdTelemetry current = state.telemetry;
    ObdMetricType? metricType;
    bool isValid = false;
    var dtcsChecked = state.dtcsChecked;

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
      if (val != null) {
        current = current.copyWith(odometer: val);
        _ecuAnsweredThisCycle = true;
      }
    } else if (command == '012F') {
      metricType = ObdMetricType.fuel;
      final val = ObdParser.parseFuelLevel(response);
      if (val != null) {
        current = current.copyWith(fuelLevel: val);
        isValid = true;
      }
    } else if (command == '03') {
      // Anything but a real mode 03 answer leaves the known codes alone.
      final codes = _storedCodesFrom(
        response,
        ecuAlive: _ecuAnsweredThisCycle,
      );
      if (codes != null) {
        current = current.copyWith(dtcs: codes);
        dtcsChecked = true;
      }
    }

    if (isValid && command != 'AT RV') _ecuAnsweredThisCycle = true;

    // The sets keep their identity unless membership changes, so selects on
    // them do not fire on every response (sets compare by identity).
    var checked = state.checkedSensors;
    var supported = state.supportedSensors;

    if (metricType != null) {
      checked = _withSensor(checked, metricType);
      if (isValid) {
        supported = _withSensor(supported, metricType);
      }
    }

    // Handle calculated fuelEconomy support. It is supported if MAP or MAF is supported.
    if (checked.contains(ObdMetricType.map) || checked.contains(ObdMetricType.rpm)) {
      checked = _withSensor(checked, ObdMetricType.fuelEconomy);
      if (supported.contains(ObdMetricType.map) || supported.contains(ObdMetricType.rpm)) {
        supported = _withSensor(supported, ObdMetricType.fuelEconomy);
      }
    }

    state = state.copyWith(
      telemetry: current.copyWith(timestamp: clock.now()),
      checkedSensors: checked,
      supportedSensors: supported,
      dtcsChecked: dtcsChecked,
    );
  }

  static Set<ObdMetricType> _withSensor(
    Set<ObdMetricType> sensors,
    ObdMetricType type,
  ) =>
      sensors.contains(type) ? sensors : {...sensors, type};

  /// One instance for every simulator tick, so the sets never look changed.
  static final Set<ObdMetricType> _allSensors =
      Set.unmodifiable(ObdMetricType.values);

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
        activeDtcsRead: false,
      );
    }

    if (state.isSimulatorMode) {
      onProgress?.call(0.15, 'Mendeteksi protokol mobil (mode simulator)…');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.30, 'Membaca identitas dan VIN mobil (mode 09)…');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.50, 'Memeriksa sensor yang didukung (mode 01)…');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.70, 'Membaca kode kerusakan aktif (mode 03)…');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.85, 'Membaca kode kerusakan tertunda dan permanen (mode 07/0A)…');
      await Future.delayed(const Duration(milliseconds: 350));

      onProgress?.call(0.95, 'Memeriksa kesiapan uji emisi (I/M)…');
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
    String protocol = 'ISO 15765-4 (CAN 11bit)';
    String vin = 'Tidak Dilaporkan ECU';
    int supportedPids = 0;
    List<String> activeDtcs = [];
    var activeDtcsRead = false;
    // Any real ECU answer in this scan; NO DATA to mode 03 only counts as
    // "no stored codes" with it (see _storedCodesFrom).
    var ecuAnswered = false;
    List<String> pendingDtcs = [];
    List<String> permanentDtcs = [];
    Map<String, bool> readiness = {};
    double? odometerKm;

    await _withPollingPaused(() async {
      // Step 1: Detect Protocol
      onProgress?.call(0.15, 'Mendeteksi protokol mobil…');
      try {
        final dpResp = await _sendAndAwaitResponse('AT DP\r', timeout: const Duration(seconds: 3));
        protocol = ObdParser.parseProtocol(dpResp);
      } catch (e) {
        debugPrint("Protocol scan error: $e");
      }

      // Step 2: Read VIN & Vehicle Information (Mode 09 PID 02)
      onProgress?.call(0.30, 'Membaca identitas dan VIN mobil (mode 09)…');
      try {
        final vinResp = await _sendAndAwaitResponse('0902\r', timeout: const Duration(seconds: 4));
        final parsedVin = ObdParser.parseVin(vinResp);
        if (parsedVin != null && parsedVin.isNotEmpty) {
          vin = parsedVin;
          ecuAnswered = true;
        }
      } catch (e) {
        debugPrint("VIN scan error: $e");
      }

      // Step 2b: Odometer (Mode 01 PID A6) — not supported on all cars
      onProgress?.call(0.40, 'Membaca odometer mobil (01A6)…');
      try {
        final odoResp = await _sendAndAwaitResponse('01A6\r', timeout: const Duration(seconds: 3));
        odometerKm = ObdParser.parseOdometer(odoResp);
        if (odometerKm != null) {
          ecuAnswered = true;
          state = state.copyWith(
            telemetry: state.telemetry.copyWith(odometer: odometerKm),
          );
        }
      } catch (e) {
        debugPrint("Odometer scan error: $e");
      }

      // Step 3: Scan Supported PIDs (Mode 01 PID 00, 20, 40)
      onProgress?.call(0.50, 'Memeriksa sensor yang didukung (mode 01)…');
      try {
        final pid00Resp = await _sendAndAwaitResponse('0100\r', timeout: const Duration(seconds: 3));
        supportedPids = ObdParser.parseSupportedPidsCount(pid00Resp);
        if (supportedPids > 0) ecuAnswered = true;
        if (supportedPids == 0) supportedPids = state.supportedSensors.length;
      } catch (e) {
        debugPrint("PID 00 scan error: $e");
      }

      // Step 4: Active Fault Codes (Mode 03)
      onProgress?.call(0.70, 'Membaca kode kerusakan aktif (mode 03)…');
      try {
        final mode03Resp = await _sendAndAwaitResponse('03\r', timeout: const Duration(seconds: 4));
        final codes = _storedCodesFrom(mode03Resp, ecuAlive: ecuAnswered);
        if (codes != null) {
          activeDtcs = codes;
          activeDtcsRead = true;
        }
      } catch (e) {
        debugPrint("Mode 03 scan error: $e");
      }

      // Step 5: Pending & Permanent Fault Codes (Mode 07 & Mode 0A)
      onProgress?.call(0.85, 'Membaca kode kerusakan tertunda dan permanen (mode 07/0A)…');
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
      onProgress?.call(0.95, 'Memeriksa kesiapan uji emisi (I/M)…');
      try {
        final pid0101Resp = await _sendAndAwaitResponse('0101\r', timeout: const Duration(seconds: 4));
        readiness = ObdParser.parseImReadiness(pid0101Resp) ?? {};
      } catch (e) {
        debugPrint("PID 0101 scan error: $e");
      }

      // An unread mode 03 must not wipe codes the polling already knows.
      if (activeDtcsRead) {
        state = state.copyWith(
          telemetry: state.telemetry.copyWith(dtcs: activeDtcs),
          dtcsChecked: true,
        );
      } else {
        activeDtcs = List<String>.from(state.telemetry.dtcs);
      }
    });

    final isMilOn = readiness['mil'] ?? activeDtcs.isNotEmpty;
    final totalSensorsCount = supportedPids > 1
        ? supportedPids
        : (state.supportedSensors.isNotEmpty
            ? state.supportedSensors.length
            : (state.checkedSensors.isNotEmpty ? state.checkedSensors.length : 12));

    if (VinDecoder.isValidVin(vin) || ((odometerKm ?? 0) > 0)) {
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
      activeDtcsRead: activeDtcsRead,
    );
  }

  /// Lightweight identity read used by Settings "Ambil dari ECU".
  Future<EcuVehicleIdentityResult> fetchVehicleIdentity() async {
    if (state.status != ObdStatus.connected &&
        state.status != ObdStatus.initializing) {
      return const EcuVehicleIdentityResult(
        success: false,
        message:
            'Hubungkan adapter OBD atau nyalakan mode simulator terlebih dahulu.',
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

    // The init sequence owns the link until the status reaches connected.
    if (state.status != ObdStatus.connected) {
      return const EcuVehicleIdentityResult(
        success: false,
        message: 'Tunggu hingga adapter selesai terhubung, lalu coba lagi.',
      );
    }

    String? vin;
    double? odometer;
    await _withPollingPaused(() async {
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
    });

    final hasVin = VinDecoder.isValidVin(vin);
    final hasOdo = (odometer ?? 0) > 0;
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
        if (!hasOdo) 'Odometer tidak dilaporkan mobil',
      ].join(' · '),
    );
  }

  /// True only when the read-back confirms every stored code is gone; use
  /// [clearTroubleCodes] to tell partial, rejected and failed apart.
  Future<bool> clearDtcCodes() async =>
      (await clearTroubleCodes()).outcome == DtcClearOutcome.cleared;

  /// Sends mode 04 between two mode 03 reads in one exclusive run. Any answer
  /// to 04 used to count as success, so a refused clear (7F 04, NO DATA) was
  /// reported and logged as cleared while the codes were still stored.
  Future<DtcClearResult> clearTroubleCodes() async {
    if (state.status != ObdStatus.connected) {
      return const DtcClearResult(DtcClearOutcome.failed);
    }

    if (state.isSimulatorMode) {
      final before = List<String>.from(state.telemetry.dtcs);
      _simulator.clearDtcs();
      state = state.copyWith(
        telemetry: state.telemetry.copyWith(dtcs: []),
        dtcsChecked: true,
      );
      await _logClearedCodes(before);
      return DtcClearResult(DtcClearOutcome.cleared, removed: before);
    }

    final known = state.dtcsChecked
        ? List<String>.from(state.telemetry.dtcs)
        : const <String>[];
    final (List<String>? beforeRead, String? clearReply, List<String>? after) =
        await _withPollingPaused(() async {
          Future<String?> ask(String command, Duration timeout) async {
            try {
              return await _sendAndAwaitResponse(command, timeout: timeout);
            } catch (e) {
              debugPrint('Clear DTC step $command failed: $e');
              return null;
            }
          }

          final first = await ask('03\r', const Duration(seconds: 4));
          final reply = await ask('04\r', const Duration(seconds: 5));
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final second = await ask('03\r', const Duration(seconds: 4));
          // Only a positive 44 proves the ECU is awake for the read-back; the
          // first read counts only a real 43 answer (else the known codes).
          final replyPositive = reply != null && !_isClearRefusal(reply);
          return (
            first == null ? null : _storedCodesFrom(first, ecuAlive: false),
            reply,
            second == null
                ? null
                : _storedCodesFrom(second, ecuAlive: replyPositive),
          );
        });

    if (after == null) {
      final refused = clearReply != null && _isClearRefusal(clearReply);
      return DtcClearResult(
        refused ? DtcClearOutcome.rejected : DtcClearOutcome.failed,
        remaining: beforeRead ?? known,
      );
    }

    final before = beforeRead ?? known;
    final removed = before.where((code) => !after.contains(code)).toList();
    if (mounted) {
      state = state.copyWith(
        telemetry: state.telemetry.copyWith(dtcs: after),
        dtcsChecked: true,
      );
    }
    await _logClearedCodes(removed);

    final DtcClearOutcome outcome;
    if (after.isEmpty) {
      outcome = DtcClearOutcome.cleared;
    } else if (removed.isNotEmpty) {
      outcome = DtcClearOutcome.partial;
    } else {
      outcome = DtcClearOutcome.rejected;
    }
    return DtcClearResult(outcome, removed: removed, remaining: after);
  }

  /// Stored codes from a mode 03 reply, or null when it is not a real answer
  /// (ERROR, '?', bus errors, SEARCHING alone). NO DATA means "no stored
  /// codes" only with proof the ECU is awake ([ecuAlive]): some non-CAN ECUs
  /// answer an empty mode 03 that way, but with the ignition off the adapter
  /// answers NO DATA to everything.
  static List<String>? _storedCodesFrom(
    String response, {
    required bool ecuAlive,
  }) {
    final compact = response.toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (compact.contains('43')) return ObdParser.parseDtc(response);
    if (ecuAlive && compact.contains('NODATA')) return const [];
    return null;
  }

  /// A negative answer to mode 04: an ECU rejection (7F 04 xx) or an adapter
  /// error instead of the positive "44".
  static bool _isClearRefusal(String response) {
    final compact = response.toUpperCase().replaceAll(RegExp(r'\s'), '');
    return compact.contains('7F04') ||
        compact.contains('NODATA') ||
        compact.contains('ERROR') ||
        compact.contains('?') ||
        !compact.contains('44');
  }

  Future<void> _logClearedCodes(List<String> codes) async {
    if (codes.isEmpty) return;
    try {
      final db = _ref.read(databaseProvider);
      final now = DateTime.now();
      for (final code in codes) {
        await db.into(db.dtcLogs).insert(
          DtcLogsCompanion.insert(
            timestamp: now,
            code: code,
            description: 'Dihapus lewat Diagnostik',
            category: code.startsWith('P') ? 'Powertrain' : (code.startsWith('C') ? 'Chassis' : 'Body/Network'),
            active: const Value(false),
            resolvedTime: Value(now),
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to save cleared DTC log: $e");
    }
  }

  void _onConnectionLost() {
    _disconnectReal();
    state = state.copyWith(
      status: ObdStatus.error,
      statusDetail: null,
      errorMessage: 'Koneksi ke adapter OBD terputus.',
      errorHelp: 'Pastikan adapter masih terpasang dan kontak ON. '
          'Jika Hubungkan otomatis aktif, aplikasi akan menghubungkan '
          'ulang sendiri.',
    );
    unawaited(stopBackgroundMonitoring());
  }

  @override
  void dispose() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
    _connectToken++;
    _stopSimulation();
    _disconnectReal();
    unawaited(stopBackgroundMonitoring());
    super.dispose();
  }
}

/// Whether [ObdService] runs its periodic auto-reconnect check (15 s backoff
/// up to 120 s). Off under `flutter test`; a test overrides it to true and
/// drives the backoff with fake_async.
final obdAutoReconnectTimerProvider = Provider<bool>(
  (ref) => !Platform.environment.containsKey('FLUTTER_TEST'),
);

final obdServiceProvider = StateNotifierProvider<ObdService, ObdState>((ref) {
  return ObdService(ref);
});
