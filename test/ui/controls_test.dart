// Every control the redesign moved still does its job (QA gate #111 item 3).
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/features/diagnostics/presentation/diagnostic_scanner_screen.dart';
import 'package:autocare/features/diagnostics/presentation/dtc_lookup_screen.dart';
import 'package:autocare/features/health/presentation/health_screen.dart';
import 'package:autocare/features/live_data/presentation/dashboard_screen.dart';
import 'package:autocare/features/live_data/presentation/telemetry_provider.dart';
import 'package:autocare/features/live_data/presentation/widgets/telemetry_chart_modal.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';
import 'package:autocare/features/settings/presentation/settings_screen.dart';
import 'package:autocare/features/timeline/presentation/timeline_screen.dart';
import 'package:autocare/features/trips/presentation/trip_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  void emit(ObdState next) => state = next;

  @override
  Future<DiagnosticScanResult> performFullDiagnosticScan({
    void Function(double progress, String status)? onProgress,
  }) async =>
      DiagnosticScanResult(
        protocol: 'ISO 15765-4',
        vin: '',
        milStatus: true,
        dtcCount: 1,
        supportedSensorsCount: 20,
        activeDtcs: const ['P0300'],
        pendingDtcs: const [],
        permanentDtcs: const [],
        imReadiness: const {},
        scanTimestamp: DateTime(2026, 11, 23, 14, 5),
      );
}

class _ScriptedTrips extends TripRecorderNotifier {
  _ScriptedTrips(super.ref);

  void emit(TripRecorderState next) => state = next;
}

Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

ObdState _connected() {
  final initial = ObdState.initial();
  const sensors = {ObdMetricType.rpm, ObdMetricType.speed, ObdMetricType.coolant};
  return initial.copyWith(
    status: ObdStatus.connected,
    connectedDeviceName: 'OBDII',
    telemetry: initial.telemetry.copyWith(rpm: 900, coolant: 90),
    checkedSensors: sensors,
    supportedSensors: sensors,
  );
}

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late ProviderContainer container;
  late _ScriptedObd obd;
  late _ScriptedTrips trips;
  final clipboard = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clipboard.clear();
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      obdServiceProvider.overrideWith((ref) => obd = _ScriptedObd(ref)),
      tripRecorderProvider.overrideWith((ref) => trips = _ScriptedTrips(ref)),
    ]);
    container.read(obdServiceProvider);
    container.read(tripRecorderProvider);
  });

  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flushDb(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
    ));
    await flushDb(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await settle(tester, 4000);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    container.dispose();
    db.close();
    await settle(tester, 500);
  }

  testWidgets('Meter: arrange mode swaps a gauge metric', (tester) async {
    await pump(tester, const DashboardScreen());
    obd.emit(_connected());
    await settle(tester);
    final before = container.read(settingsProvider).leftMetric;
    await tester.tap(find.byTooltip('Lainnya'));
    await settle(tester);
    await tester.tap(find.text('Atur tampilan'));
    await settle(tester);
    await tester.tap(find.text(ObdMetricConfig.of(before).label).first);
    await settle(tester);
    final choice = before == ObdMetricType.coolant ? 'Tegangan aki' : 'Suhu mesin';
    await tester.tap(find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(choice),
    ));
    await flushDb(tester);
    expect(ObdMetricConfig.of(container.read(settingsProvider).leftMetric).label,
        choice);
    await finish(tester);
  });

  testWidgets('Meter: Trip A resets after confirmation', (tester) async {
    await pump(tester, const DashboardScreen());
    obd.emit(_connected());
    trips.emit(trips.state.copyWith(tripADistance: 12.3, tripBDistance: 40));
    await settle(tester);
    await tester.tap(find.byTooltip('Lainnya'));
    await settle(tester);
    await tester.tap(find.text('Reset Trip A'));
    await settle(tester);
    await tester.tap(_button('Reset'));
    await flushDb(tester);
    expect(container.read(tripRecorderProvider).tripADistance, 0);
    expect(container.read(tripRecorderProvider).tripBDistance, 40);
    await finish(tester);
  });

  testWidgets('chart sheet: range chips change the range', (tester) async {
    await pump(
      tester,
      const Scaffold(body: TelemetryChartModal(metricType: ObdMetricType.rpm)),
    );
    await tester.tap(find.text('1 jam'));
    await settle(tester);
    expect(container.read(telemetryTimeRangeProvider), TelemetryTimeRange.oneHour);
    await finish(tester);
  });

  testWidgets('Riwayat: the Servis filter shows services only', (tester) async {
    await tester.runAsync(() async {
      await db.into(db.maintenanceLogs).insert(MaintenanceLogsCompanion.insert(
            timestamp: DateTime(2026, 11, 13),
            type: 'Servis Rem',
            odometer: 158300,
            cost: const Value(250000),
          ));
      await db.into(db.fuelLogs).insert(FuelLogsCompanion.insert(
            timestamp: DateTime(2026, 11, 20),
            fuelType: 'Pertalite',
            liters: 20,
            price: 200000,
            odometer: 161000,
          ));
    });
    await pump(tester, const TimelineScreen());
    expect(find.text('Isi BBM · Pertalite'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Servis'));
    await settle(tester);
    expect(find.text('Isi BBM · Pertalite'), findsNothing);
    expect(find.text('Rem (Kampas/Piringan)'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Pengaturan: auto-connect switch and read-from-car button',
      (tester) async {
    await pump(tester, const SettingsScreen());
    final before = container.read(settingsProvider).autoConnectOBD;
    await tester.tap(find.widgetWithText(SwitchListTile, 'Hubungkan otomatis'));
    await flushDb(tester);
    expect(container.read(settingsProvider).autoConnectOBD, !before);

    // Reading from the car needs a real link.
    final read = _button('Baca nama & odometer dari mobil');
    expect(tester.widget<ButtonStyleButton>(read).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('Diagnostik: scan result copies a report', (tester) async {
    await pump(tester, const DiagnosticScannerScreen());
    obd.emit(_connected());
    await settle(tester);
    await tester.tap(_button('Pindai sekarang'));
    await settle(tester, 1000);
    await tester.tap(_button('Salin laporan'));
    await settle(tester);
    expect(clipboard.single, contains('P0300'));
    expect(find.text('Laporan disalin'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Kamus kode: category chips filter', (tester) async {
    await pump(tester, const DtcLookupScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bodi'));
    await settle(tester);
    expect(find.textContaining('B0'), findsWidgets);
    expect(find.textContaining('P0300 · '), findsNothing);
    await finish(tester);
  });

  testWidgets('Beranda: Hubungkan opens the connection sheet', (tester) async {
    await pump(tester, const HealthScreen());
    await tester.tap(_button('Hubungkan'));
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Adapter OBD'), findsOneWidget);
    await finish(tester);
  });
}
