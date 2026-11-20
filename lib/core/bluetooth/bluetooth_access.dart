import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/settings/presentation/settings_provider.dart';

/// What stands between the app and listing / reaching an ELM327 adapter.
enum BluetoothReadiness {
  ready,
  unsupported,
  bluetoothOff,
  permissionDenied,
  permissionPermanentlyDenied,
}

/// Name fragments used by common ELM327 clones and branded SPP adapters.
const List<String> _obdNameHints = [
  'obd',
  'elm',
  'vlink',
  'v-link',
  'vgate',
  'icar',
  'konnwei',
  'kw9',
  'viecar',
  'bafx',
  'panlong',
  'carista',
  'scan',
  '327',
];

bool isLikelyObdAdapter(String? name) {
  if (name == null || name.isEmpty) return false;
  final lower = name.toLowerCase();
  return _obdNameHints.any(lower.contains);
}

/// BLE-only devices cannot speak Bluetooth Classic SPP, so they are never
/// offered as adapters.
bool isClassicCapable(BluetoothDevice device) =>
    device.type != BluetoothDeviceType.le;

class ObdDeviceList {
  final BluetoothReadiness readiness;

  /// Last used adapter first, then devices whose name looks like an OBD
  /// adapter.
  final List<BluetoothDevice> likely;

  /// Every other bonded Classic device (headsets, car audio, ...).
  final List<BluetoothDevice> others;
  final String lastUsedAddress;

  const ObdDeviceList({
    required this.readiness,
    this.likely = const [],
    this.others = const [],
    this.lastUsedAddress = '',
  });

  factory ObdDeviceList.fromBonded(
    List<BluetoothDevice> bonded, {
    required String lastUsedAddress,
  }) {
    int byName(BluetoothDevice a, BluetoothDevice b) => (a.name ?? a.address)
        .toLowerCase()
        .compareTo((b.name ?? b.address).toLowerCase());

    final likely = <BluetoothDevice>[];
    final others = <BluetoothDevice>[];
    for (final device in bonded.where(isClassicCapable)) {
      if (device.address == lastUsedAddress || isLikelyObdAdapter(device.name)) {
        likely.add(device);
      } else {
        others.add(device);
      }
    }
    likely.sort((a, b) {
      if (a.address == lastUsedAddress) return -1;
      if (b.address == lastUsedAddress) return 1;
      return byName(a, b);
    });
    others.sort(byName);
    return ObdDeviceList(
      readiness: BluetoothReadiness.ready,
      likely: likely,
      others: others,
      lastUsedAddress: lastUsedAddress,
    );
  }

  bool get isEmpty => likely.isEmpty && others.isEmpty;
}

class BluetoothAccess {
  BluetoothAccess._();

  static bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  /// Requests what the next Bluetooth action needs and reports what is still
  /// missing. Location is never requested here: the vendored plugin asks for
  /// it natively, and only for discovery on Android 11 and older.
  static Future<BluetoothReadiness> check({bool forDiscovery = false}) async {
    if (!isSupportedPlatform) return BluetoothReadiness.unsupported;
    try {
      final available = await FlutterBluetoothSerial.instance.isAvailable;
      if (available != true) return BluetoothReadiness.unsupported;
    } catch (e) {
      debugPrint('Bluetooth availability check failed: $e');
      return BluetoothReadiness.unsupported;
    }

    // On Android 11 and older these resolve to granted without a prompt.
    final statuses = await [
      Permission.bluetoothConnect,
      if (forDiscovery) Permission.bluetoothScan,
    ].request();
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return BluetoothReadiness.permissionPermanentlyDenied;
    }
    if (statuses.values.any((s) => !s.isGranted)) {
      return BluetoothReadiness.permissionDenied;
    }

    final enabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (enabled != true) return BluetoothReadiness.bluetoothOff;
    return BluetoothReadiness.ready;
  }

  /// Shows the system "turn on Bluetooth" prompt. True when it ends up on.
  static Future<bool> requestEnable() async {
    try {
      return await FlutterBluetoothSerial.instance.requestEnable() == true;
    } catch (e) {
      debugPrint('Bluetooth enable request failed: $e');
      return false;
    }
  }

  static Future<void> openAppPermissionSettings() => openAppSettings();

  /// Classic discovery; the platform ends it on its own after ~12 s.
  static Stream<BluetoothDiscoveryResult> discover() =>
      FlutterBluetoothSerial.instance.startDiscovery();

  static Future<void> stopDiscovery() async {
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (e) {
      debugPrint('Cancel discovery failed: $e');
    }
  }

  /// Pairs with PIN 1234 first, the default of most ELM327 clones. When the
  /// dongle rejects it (some use 0000), Android's own PIN dialog takes over.
  static Future<bool> pair(String address) async {
    await stopDiscovery();
    final serial = FlutterBluetoothSerial.instance;
    // The plugin keeps its auto-PIN handler registered when no PIN request
    // ever arrived, and then refuses the next bonding call that passes a PIN.
    serial.setPairingRequestHandler(null);
    try {
      final bonded = await serial.bondDeviceAtAddress(address, pin: '1234');
      if (bonded == true) return true;
    } on PlatformException catch (e) {
      if ((e.message ?? '').contains('already bonded')) return true;
      debugPrint('Auto-PIN pairing failed: $e');
    } finally {
      serial.setPairingRequestHandler(null);
    }

    try {
      return await serial.bondDeviceAtAddress(address) == true;
    } on PlatformException catch (e) {
      if ((e.message ?? '').contains('already bonded')) return true;
      rethrow;
    }
  }
}

/// Bonded devices for the connection sheet, with readiness resolved first so
/// the sheet can show "turn on Bluetooth" / "grant permission" instead of an
/// empty list.
final obdDeviceListProvider = FutureProvider.autoDispose<ObdDeviceList>((
  ref,
) async {
  final readiness = await BluetoothAccess.check();
  if (readiness != BluetoothReadiness.ready) {
    return ObdDeviceList(readiness: readiness);
  }

  final List<BluetoothDevice> bonded;
  try {
    bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
  } on PlatformException catch (e) {
    if (e.code == 'no_permissions') {
      return const ObdDeviceList(
        readiness: BluetoothReadiness.permissionDenied,
      );
    }
    rethrow;
  }

  return ObdDeviceList.fromBonded(
    bonded,
    lastUsedAddress: ref.read(settingsProvider).lastOBDAddress,
  );
});
