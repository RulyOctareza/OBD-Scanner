import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/core/utils/usefulness_utils.dart';
import 'package:autocare/features/diagnostics/presentation/diagnostic_scanner_screen.dart';
import 'package:autocare/features/diagnostics/presentation/dtc_lookup_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

DiagnosticScanResult _result({
  List<String> active = const ['P0138'],
  bool activeRead = true,
  Map<String, bool> readiness = const {'catalyst': true, 'evap': false},
}) =>
    DiagnosticScanResult(
      protocol: 'ISO 15765-4 (CAN 11/500)',
      vin: 'MHKM1BA3JKJ000000',
      milStatus: active.isNotEmpty,
      dtcCount: active.length,
      supportedSensorsCount: 24,
      activeDtcs: active,
      pendingDtcs: const [],
      permanentDtcs: const [],
      imReadiness: readiness,
      scanTimestamp: DateTime(2026, 11, 23, 14, 5),
      activeDtcsRead: activeRead,
    );

/// Scan and clear answer from scripts instead of a car.
class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  DiagnosticScanResult scanResult = _result();
  DtcClearResult clearResult = const DtcClearResult(
    DtcClearOutcome.cleared,
    removed: ['P0138'],
  );

  void emit(ObdState next) => state = next;

  @override
  Future<DiagnosticScanResult> performFullDiagnosticScan({
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.7, '');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return scanResult;
  }

  @override
  Future<DtcClearResult> clearTroubleCodes() async => clearResult;
}

/// A button by its label, whatever its variant (.icon builds a subclass).
Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late ProviderContainer container;
  late _ScriptedObd obd;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      obdServiceProvider.overrideWith((ref) => obd = _ScriptedObd(ref)),
    ]);
    container.read(obdServiceProvider);
  });

  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
    ));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await settle(tester, 4000);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    container.dispose();
    db.close();
    await settle(tester, 500);
  }

  ObdState connected() => ObdState.initial().copyWith(
        status: ObdStatus.connected,
        connectedDeviceName: 'OBDII',
        checkedSensors: const {ObdMetricType.rpm},
        supportedSensors: const {ObdMetricType.rpm},
      );

  testWidgets('scan shows explained codes, readiness and keeps its result',
      (tester) async {
    await pump(tester, const DiagnosticScannerScreen());
    // Not connected: the scan cannot start.
    final button = _button('Pindai sekarang');
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);

    obd.emit(connected());
    await settle(tester);
    await tester.tap(button);
    await settle(tester, 1000);

    expect(find.text('1 kode kerusakan aktif'), findsOneWidget);
    expect(find.textContaining('P0138 · '), findsOneWidget);
    expect(find.text('Belum siap'), findsOneWidget);

    // The row opens the explanation.
    await tester.tap(find.textContaining('P0138 · '));
    await settle(tester);
    expect(find.text('Kemungkinan penyebab'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);

    // Leaving and coming back keeps the result.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await pump(tester, const DiagnosticScannerScreen());
    expect(find.text('1 kode kerusakan aktif'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an unanswered read says so, never "no codes"', (tester) async {
    obd.scanResult = _result(active: const [], activeRead: false, readiness: const {});
    await pump(tester, const DiagnosticScannerScreen());
    obd.emit(connected());
    await settle(tester);
    await tester.tap(_button('Pindai sekarang'));
    await settle(tester, 1000);
    expect(find.text('Kode aktif belum terbaca'), findsOneWidget);
    expect(find.text('Tidak ada kode aktif'), findsNothing);
    expect(find.textContaining('Tidak tersedia'), findsOneWidget);
    await finish(tester);
  });

  for (final (outcome, expected) in [
    (DtcClearOutcome.cleared, 'Kode kerusakan terhapus. Lampu Check Engine mati.'),
    (DtcClearOutcome.partial, 'Sebagian kode masih ada'),
    (DtcClearOutcome.rejected, 'Mobil menolak menghapus kode'),
    (DtcClearOutcome.failed, 'Hasilnya tidak bisa dipastikan'),
  ]) {
    testWidgets('clearing codes reports $outcome truthfully', (tester) async {
      obd.clearResult = DtcClearResult(
        outcome,
        removed: outcome == DtcClearOutcome.cleared ? const ['P0138'] : const [],
        remaining: outcome == DtcClearOutcome.cleared ? const [] : const ['P0138'],
      );
      await pump(tester, const DiagnosticScannerScreen());
      obd.emit(connected());
      await settle(tester);
      await tester.tap(_button('Pindai sekarang'));
      await settle(tester, 1000);
      await tester.scrollUntilVisible(
        _button('Hapus kode kerusakan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(_button('Hapus kode kerusakan'));
      await settle(tester);
      await tester.tap(_button('Hapus kode kerusakan'));
      await settle(tester);
      expect(find.text('Hapus kode kerusakan?'), findsOneWidget);
      await tester.tap(_button('Hapus kode'));
      await settle(tester);
      expect(find.text(expected), findsOneWidget);
      // A clear that removed codes restarts the readiness monitors: the old
      // readiness is gone, and the car is not blamed for not reporting it.
      final reset = outcome == DtcClearOutcome.cleared ||
          outcome == DtcClearOutcome.partial;
      expect(
        find.textContaining('Direset karena kode baru saja dihapus',
            skipOffstage: false),
        reset ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('mobil tidak melaporkan', skipOffstage: false),
          findsNothing);
      expect(find.text('Belum siap', skipOffstage: false),
          reset ? findsNothing : findsOneWidget);
      await finish(tester);
    });
  }

  testWidgets('dictionary finds codes and opens a well-formed unknown one',
      (tester) async {
    await pump(tester, const DtcLookupScreen());
    await tester.enterText(find.byType(TextField), 'p0300');
    await settle(tester);
    expect(find.textContaining('P0300 · '), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'P1999');
    await settle(tester);
    expect(find.textContaining('P1999 · '), findsOneWidget);
    await tester.tap(find.textContaining('P1999 · '));
    await settle(tester);
    expect(find.textContaining('Belum ada penjelasan'), findsWidgets);
    await finish(tester);
  });

  test('report reads in the app words', () {
    final text = formatDtcReport(_result(active: const [], activeRead: false));
    expect(text, contains('Kode aktif:\n- belum terbaca'));
    expect(text, contains('Lampu Check Engine: Mati'));
    expect(text, contains('Katalis: Siap'));
    expect(text, contains('Waktu: 23 Nov 2026, 14.05'));
  });
}
