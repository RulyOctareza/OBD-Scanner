import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// A byte link to an ELM327 adapter, as [ObdService] uses it.
abstract interface class ObdLink {
  /// Raw bytes from the adapter. Completes when the link closes.
  Stream<Uint8List> get input;

  bool get isConnected;

  /// Writes [bytes]; completes once they have been handed to the OS.
  Future<void> send(Uint8List bytes);

  void dispose();
}

/// Opens [ObdLink]s. Replaced in tests and benchmarks by a fake adapter.
abstract interface class ObdLinkConnector {
  /// Whether Bluetooth is on and BLUETOOTH_CONNECT is granted. Never prompts.
  Future<bool> isReady();

  /// Discovery slows down or breaks RFCOMM connects, so it is stopped first.
  Future<void> cancelDiscovery();

  Future<ObdLink> open(String address);
}

final obdLinkConnectorProvider = Provider<ObdLinkConnector>(
  (ref) => const BluetoothObdLinkConnector(),
);

class BluetoothObdLinkConnector implements ObdLinkConnector {
  const BluetoothObdLinkConnector();

  @override
  Future<bool> isReady() async {
    if (await FlutterBluetoothSerial.instance.isEnabled != true) return false;
    return Permission.bluetoothConnect.isGranted;
  }

  @override
  Future<void> cancelDiscovery() async {
    await FlutterBluetoothSerial.instance.cancelDiscovery();
  }

  @override
  Future<ObdLink> open(String address) async =>
      _BluetoothObdLink(await BluetoothConnection.toAddress(address));
}

class _BluetoothObdLink implements ObdLink {
  _BluetoothObdLink(this._connection);

  final BluetoothConnection _connection;

  @override
  Stream<Uint8List> get input => _connection.input!;

  @override
  bool get isConnected => _connection.isConnected;

  @override
  Future<void> send(Uint8List bytes) {
    _connection.output.add(bytes);
    return _connection.output.allSent;
  }

  @override
  void dispose() => _connection.dispose();
}
