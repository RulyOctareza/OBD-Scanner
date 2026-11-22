// Dev-only: used by tests and the benchmark entrypoint (lib/dev/bench), never
// imported from lib/main.dart, so it is not compiled into app builds.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/bluetooth/obd_link.dart';

enum FakeEngineProfile {
  /// Speed swings 10–70 km/h over a minute; every PID keeps moving.
  drive,

  /// Parked with the engine running: speed 0, RPM jitters around 780.
  idle,
}

/// An ELM327 adapter in software. Answers AT, mode 01/03/04/07/09/0A commands
/// with ELM327 framing after [latency], so [ObdService]'s real framing and
/// parse path runs at link-like rates (about 10 answers/s at 95 ms).
class FakeElm327Connector implements ObdLinkConnector {
  FakeElm327Connector({
    this.latency = const Duration(milliseconds: 95),
    this.autoReply = true,
  });

  Duration latency;

  /// Default for links opened from now on.
  bool autoReply;

  bool ready = true;
  int openCount = 0;
  int cancelDiscoveryCount = 0;
  final List<FakeElm327Link> links = [];

  /// Decides how an open ends: return `newLink()`, throw, or return a future
  /// that never completes. Null opens immediately.
  Future<ObdLink> Function(String address, FakeElm327Link Function() newLink)?
      onOpen;

  /// Custom answer for a command (spaces removed, upper case, no `\r`);
  /// null falls through to the built-in answer.
  String? Function(String command)? responder;

  FakeEngineProfile profile = FakeEngineProfile.drive;

  /// Stored DTCs as 4 hex digits, e.g. `0133` for P0133.
  List<String> dtcs = const [];

  int answers = 0;

  final Stopwatch _clock = Stopwatch()..start();

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> cancelDiscovery() async => cancelDiscoveryCount++;

  @override
  Future<ObdLink> open(String address) {
    openCount++;
    FakeElm327Link newLink() {
      final link = FakeElm327Link._(this, autoReply);
      links.add(link);
      return link;
    }

    final handler = onOpen;
    if (handler != null) return handler(address, newLink);
    return Future.value(newLink());
  }

  String _answer(String command) {
    final custom = responder?.call(command);
    if (custom != null) return custom;
    switch (command) {
      case 'ATZ':
        return '\r\rELM327 v1.5';
      case 'ATE0':
        return 'ATE0\rOK';
      case 'ATSP0':
        return 'OK';
      case 'ATDP':
        return 'AUTO, ISO 15765-4 (CAN 11/500)';
      case 'ATRV':
        return '${_values().voltage.toStringAsFixed(1)}V';
      case '0100':
        return '41 00 BE 3F B8 13';
      case '0101':
        return '41 01 ${dtcs.isEmpty ? '00' : '81'} 07 65 00';
      case '03':
        return _dtcAnswer('43', dtcs);
      case '07':
        return _dtcAnswer('47', const []);
      case '0A':
        return _dtcAnswer('4A', const []);
      case '04':
        dtcs = const [];
        return '44';
      case '0902':
        return '014\r'
            '0: 49 02 01 4D 48 4B\r'
            '1: 4D 31 35 30 32 58 4B\r'
            '2: 30 31 39 38 34 32 31';
    }
    if (command.length == 4 && command.startsWith('01')) {
      final pid = command.substring(2);
      final bytes = _pidBytes(pid);
      if (bytes == null) return 'NO DATA';
      return '41 $pid ${bytes.map(_hex).join(' ')}';
    }
    return '?';
  }

  static String _dtcAnswer(String header, List<String> codes) {
    if (codes.isEmpty) return '$header 00';
    final hex = codes.map((c) => '${c.substring(0, 2)} ${c.substring(2)}');
    return '$header ${_hex(codes.length)} ${hex.join(' ')}';
  }

  static String _hex(int b) =>
      (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();

  _Values _values() {
    final t = _clock.elapsedMilliseconds / 1000.0;
    double wave(double period) => math.sin(2 * math.pi * t / period);
    final warm = math.min(t / 300, 1.0);
    if (profile == FakeEngineProfile.idle) {
      return _Values(
        rpm: 780 + 12 * wave(3.7),
        speed: 0,
        coolant: 90,
        intakeAirTemp: 36,
        map: 33,
        maf: 2.6,
        timing: 10,
        throttle: 14.5,
        load: 22,
        fuel: 61,
        voltage: 14.1,
        odometerKm: 45678.9,
      );
    }
    final speed = 40 + 30 * wave(60);
    final throttle = 20 + 12 * wave(9) + (speed - 40) * 0.25;
    return _Values(
      rpm: 900 + speed * 32 + 250 * wave(6.5),
      speed: speed,
      coolant: 86 + 5 * warm,
      intakeAirTemp: 34 + 3 * warm,
      map: 45 + 30 * (throttle / 50),
      maf: 4 + speed * 0.22 + 3 * wave(6.5),
      timing: 14 + 6 * wave(5),
      throttle: throttle,
      load: 30 + 20 * wave(9),
      fuel: 62 - 0.5 * warm,
      voltage: 14.0 + 0.2 * wave(20),
      // About 40 km/h on average: the ECU odometer ticks every ~9 s.
      odometerKm: 45678.9 + t * 40 / 3600,
    );
  }

  List<int>? _pidBytes(String pid) {
    final v = _values();
    List<int> word(double value) {
      final w = value.round().clamp(0, 0xFFFF);
      return [w >> 8, w & 0xFF];
    }

    int byte(double value) => value.round().clamp(0, 0xFF);
    int percent(double value) => byte(value * 255 / 100);

    switch (pid) {
      case '0C':
        return word(v.rpm * 4);
      case '0D':
        return [byte(v.speed)];
      case '05':
        return [byte(v.coolant + 40)];
      case '0F':
        return [byte(v.intakeAirTemp + 40)];
      case '0B':
        return [byte(v.map)];
      case '10':
        return word(v.maf * 100);
      case '0E':
        return [byte((v.timing + 64) * 2)];
      case '11':
        return [percent(v.throttle)];
      case '04':
        return [percent(v.load)];
      case '2F':
        return [percent(v.fuel)];
      case 'A6':
        final odo = (v.odometerKm * 10).round();
        return [odo >> 24 & 0xFF, odo >> 16 & 0xFF, odo >> 8 & 0xFF, odo & 0xFF];
    }
    return null;
  }
}

class _Values {
  const _Values({
    required this.rpm,
    required this.speed,
    required this.coolant,
    required this.intakeAirTemp,
    required this.map,
    required this.maf,
    required this.timing,
    required this.throttle,
    required this.load,
    required this.fuel,
    required this.voltage,
    required this.odometerKm,
  });

  final double rpm;
  final double speed;
  final double coolant;
  final double intakeAirTemp;
  final double map;
  final double maf;
  final double timing;
  final double throttle;
  final double load;
  final double fuel;
  final double voltage;
  final double odometerKm;
}

class FakeElm327Link implements ObdLink {
  FakeElm327Link._(this._adapter, this.autoReply);

  final FakeElm327Connector _adapter;
  final StreamController<Uint8List> _input = StreamController<Uint8List>();
  final Set<Timer> _timers = {};
  final StringBuffer _partial = StringBuffer();
  bool _open = true;

  /// Commands written, in order, without the trailing `\r`.
  final List<String> sent = [];
  int disposeCount = 0;

  /// False makes the link silent: the test answers through [reply]/[inject].
  bool autoReply;

  /// When true, [dispose] stops the link but its input `onDone` arrives only
  /// on [finishClose], as the Bluetooth plugin closes asynchronously.
  bool deferCloseOnDispose = false;

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  bool get isConnected => _open;

  @override
  Future<void> send(Uint8List bytes) async {
    if (!_open) throw StateError('FakeElm327Link closed');
    _partial.write(ascii.decode(bytes));
    var text = _partial.toString();
    var end = text.indexOf('\r');
    while (end != -1) {
      final command = text.substring(0, end);
      text = text.substring(end + 1);
      sent.add(command);
      if (autoReply) _scheduleAnswer(command);
      end = text.indexOf('\r');
    }
    _partial
      ..clear()
      ..write(text);
  }

  void _scheduleAnswer(String raw) {
    final command = raw.replaceAll(' ', '').toUpperCase();
    late final Timer timer;
    timer = Timer(_adapter.latency, () {
      _timers.remove(timer);
      if (!_open) return;
      _adapter.answers++;
      // Bluetooth SPP delivers an answer in pieces: body first, prompt after.
      inject(ascii.encode(_adapter._answer(command)));
      inject(ascii.encode('\r\r>'));
    });
    _timers.add(timer);
  }

  /// Raw bytes into [input], as if the adapter sent them.
  void inject(List<int> bytes) {
    if (_open) _input.add(Uint8List.fromList(bytes));
  }

  /// [text] followed by the ELM327 prompt.
  void reply(String text) => inject(ascii.encode('$text\r\r>'));

  /// Closes the link from the adapter side, as when the dongle loses power.
  void closeFromAdapter() {
    _stop();
    finishClose();
  }

  /// Delivers the input `onDone` held back by [deferCloseOnDispose].
  void finishClose() {
    if (!_input.isClosed) unawaited(_input.close());
  }

  void _stop() {
    _open = false;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    disposeCount++;
    _stop();
    if (!deferCloseOnDispose) finishClose();
  }
}
