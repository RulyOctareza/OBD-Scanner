// Connection sheet, "Perangkat baru": a scan always ends on its own, also when
// the platform never starts it (defect F4: Location off on Android 11 and
// older), and a stale "Bluetooth mati" card goes away (O2).
import 'dart:async';

import 'package:autocare/core/bluetooth/bluetooth_access.dart';
import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/widgets/obd_connection_sheet.dart';
import 'package:autocare/dev/fake_elm327.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bonded = BluetoothDevice(name: 'OBDII', address: '00:00:00:00:00:0A');

/// Discovery the test scripts: what the platform reports and what it finds.
class FakeDiscovery extends BluetoothDiscovery {
  BluetoothReadiness readiness = BluetoothReadiness.ready;

  /// What `isDiscovering` answers: false when the platform refused to scan.
  bool running = true;
  bool locationOff = false;

  int startCount = 0;
  int stopCount = 0;
  StreamController<BluetoothDiscoveryResult>? _results;

  @override
  Future<BluetoothReadiness> check() async => readiness;

  @override
  Stream<BluetoothDiscoveryResult> start() {
    startCount++;
    final results = StreamController<BluetoothDiscoveryResult>();
    _results = results;
    return results.stream;
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> isLocationServiceOff() async => locationOff;

  void find(String name, String address) => _results!.add(
        BluetoothDiscoveryResult(
          device: BluetoothDevice(name: name, address: address),
          rssi: -60,
        ),
      );

  /// The platform ends discovery (about 12 s on a real phone).
  void finish() => _results!.close();

  void fail(Object error) => _results!.addError(error);
}

Future<FakeDiscovery> _openSheet(
  WidgetTester tester, {
  ObdDeviceList list = const ObdDeviceList(
    readiness: BluetoothReadiness.ready,
    likely: [_bonded],
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final discovery = FakeDiscovery();
  final db = AppDatabase.withExecutor(NativeDatabase.memory());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        obdLinkConnectorProvider.overrideWithValue(FakeElm327Connector()),
        obdAutoReconnectTimerProvider.overrideWithValue(false),
        bluetoothDiscoveryProvider.overrideWithValue(discovery),
        obdDeviceListProvider.overrideWith((ref) async => list),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => showObdConnectionSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  addTearDown(() async {
    // Unmount, then let the service's startup timer and the database finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await db.close();
  });

  await tester.tap(find.text('open'));
  await tester.pump();
  // Sheet animation, and the service's startup auto-connect window (3 s),
  // which would otherwise be a pending timer in tests that end sooner.
  await tester.pump(const Duration(seconds: 4));
  expect(find.text('Koneksi OBD-II'), findsOneWidget);
  return discovery;
}

Future<void> _tapCari(WidgetTester tester) async {
  await tester.tap(find.text('Cari'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  group('F4. scan ends on its own', () {
    testWidgets('S1 Location off: ends after 3 s with the Location hint',
        (tester) async {
      final discovery = await _openSheet(tester);
      discovery
        ..running = false
        ..locationOff = true;

      await _tapCari(tester);
      expect(discovery.startCount, 1);
      expect(find.text('Berhenti'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('Berhenti'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Berhenti'), findsNothing);
      expect(find.text('Cari lagi'), findsOneWidget);
      expect(find.textContaining('Lokasi HP mati'), findsOneWidget);
      expect(find.textContaining('Nyalakan Lokasi'), findsOneWidget);
      expect(discovery.stopCount, greaterThan(0));
    });

    testWidgets('S2 platform does not scan, Location on: ends after 3 s',
        (tester) async {
      final discovery = await _openSheet(tester);
      discovery.running = false;

      await _tapCari(tester);
      await tester.pump(const Duration(milliseconds: 3100));
      await tester.pump();

      expect(find.text('Cari lagi'), findsOneWidget);
      expect(find.textContaining('Lokasi HP mati'), findsNothing);
      expect(find.textContaining('lalu ketuk Cari lagi'), findsOneWidget);
    });

    testWidgets('S3 platform scans but never reports the end: 20 s limit',
        (tester) async {
      final discovery = await _openSheet(tester);

      await _tapCari(tester);
      await tester.pump(const Duration(milliseconds: 19800));
      await tester.pump();
      expect(find.text('Berhenti'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Cari lagi'), findsOneWidget);
      expect(
        find.textContaining('Tidak ada perangkat baru ditemukan'),
        findsOneWidget,
      );
      expect(discovery.stopCount, greaterThan(0));
    });

    testWidgets('S4 normal scan: found adapter listed, ends with the platform',
        (tester) async {
      final discovery = await _openSheet(tester);

      await _tapCari(tester);
      await tester.pump(const Duration(seconds: 2));
      discovery.find('V-LINK', '00:00:00:00:00:0B');
      await tester.pump();
      expect(find.text('V-LINK'), findsOneWidget);
      expect(find.text('Berhenti'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      discovery.finish();
      await tester.pump();
      expect(find.text('Cari lagi'), findsOneWidget);
      expect(find.text('V-LINK'), findsOneWidget);
      expect(find.textContaining('Tidak ada perangkat baru'), findsNothing);

      // The limit timer of the finished scan must not fire into the result.
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('V-LINK'), findsOneWidget);
      expect(find.text('Cari lagi'), findsOneWidget);
    });

    testWidgets('S5 a result before the 3 s check keeps the scan running',
        (tester) async {
      final discovery = await _openSheet(tester);
      discovery
        ..running = false
        ..locationOff = true;

      await _tapCari(tester);
      discovery.find('V-LINK', '00:00:00:00:00:0B');
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pump();

      expect(find.text('Berhenti'), findsOneWidget);
      expect(find.textContaining('Lokasi HP mati'), findsNothing);

      await tester.pump(const Duration(seconds: 17));
      await tester.pump();
      expect(find.text('Cari lagi'), findsOneWidget);
      expect(find.text('V-LINK'), findsOneWidget);
    });

    testWidgets('S6 Berhenti cancels the checks', (tester) async {
      final discovery = await _openSheet(tester);
      discovery
        ..running = false
        ..locationOff = true;

      await _tapCari(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Berhenti'));
      await tester.pump();
      expect(find.text('Cari lagi'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.textContaining('Lokasi HP mati'), findsNothing);
      expect(find.text('Cari lagi'), findsOneWidget);
    });

    testWidgets('S7 closing the sheet during a scan stops it', (tester) async {
      final discovery = await _openSheet(tester);
      discovery.running = false;

      await _tapCari(tester);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Koneksi OBD-II'), findsNothing);
      expect(discovery.stopCount, greaterThan(0));

      // The 3 s and 20 s timers of the closed sheet must not fire.
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('S8 scan error ends the scan with a message', (tester) async {
      final discovery = await _openSheet(tester);

      await _tapCari(tester);
      discovery.fail(Exception('boom'));
      await tester.pump();

      expect(find.text('Cari lagi'), findsOneWidget);
      expect(find.textContaining('Pencarian gagal'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.textContaining('Pencarian gagal'), findsOneWidget);
    });

    testWidgets('S9 "Cari lagi" after a refused scan starts a fresh scan',
        (tester) async {
      final discovery = await _openSheet(tester);
      discovery
        ..running = false
        ..locationOff = true;
      await _tapCari(tester);
      await tester.pump(const Duration(milliseconds: 3100));
      await tester.pump();
      expect(find.textContaining('Lokasi HP mati'), findsOneWidget);

      // The user switched Location on.
      discovery
        ..running = true
        ..locationOff = false;
      await tester.tap(find.text('Cari lagi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(discovery.startCount, 2);
      expect(find.textContaining('Lokasi HP mati'), findsNothing);
      expect(find.text('Berhenti'), findsOneWidget);

      discovery.finish();
      await tester.pump();
      expect(find.text('Cari lagi'), findsOneWidget);
    });
  });

  group('O2. "Bluetooth mati" under Perangkat baru', () {
    testWidgets('S10 shown when Cari is tapped with Bluetooth off',
        (tester) async {
      final discovery = await _openSheet(
        tester,
        list: const ObdDeviceList(readiness: BluetoothReadiness.bluetoothOff),
      );
      discovery.readiness = BluetoothReadiness.bluetoothOff;

      expect(find.text('Bluetooth mati'), findsOneWidget);
      await _tapCari(tester);

      expect(discovery.startCount, 0);
      expect(find.text('Bluetooth mati'), findsNWidgets(2));
      expect(find.text('Berhenti'), findsNothing);
    });

    testWidgets('S11 hidden once the bonded list reports ready',
        (tester) async {
      final discovery = await _openSheet(tester);
      discovery.readiness = BluetoothReadiness.bluetoothOff;

      await _tapCari(tester);

      expect(discovery.startCount, 0);
      expect(find.text('Bluetooth mati'), findsNothing);
      expect(find.text('OBDII'), findsOneWidget);
    });
  });
}
