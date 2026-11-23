// Sheets and dialogs on a phone with a status bar and a navigation bar, at
// narrow widths and large text: nothing may overflow, and the last line of a
// sheet must scroll into view above the navigation bar (the SM-A605G has a
// 48 dp button bar; a sheet once ended under it).
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/core/ui/ui.dart';
import 'package:autocare/core/widgets/obd_connection_sheet.dart';
import 'package:autocare/features/diagnostics/presentation/dtc_detail_sheet.dart';
import 'package:autocare/features/live_data/presentation/widgets/telemetry_chart_modal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

const double _dpr = 2.625;
const double _statusBarDp = 24;
const double _navBarDp = 48;

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  void emit(ObdState next) => state = next;
}

typedef _Device = ({double width, double height, double scale});

const List<_Device> _devices = [
  (width: 411, height: 846, scale: 1.0),
  (width: 320, height: 640, scale: 1.3),
  (width: 320, height: 640, scale: 2.0),
];

void _setDevice(WidgetTester tester, _Device d) {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = Size(d.width * _dpr, d.height * _dpr);
  const insets = FakeViewPadding(top: _statusBarDp * _dpr, bottom: _navBarDp * _dpr);
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = d.scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Scrolls [target] into view and checks it ends above the navigation bar.
Future<void> _expectReachable(
  WidgetTester tester,
  Finder target,
  _Device d,
) async {
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 300));
  final rect = tester.getRect(target);
  expect(
    rect.bottom,
    lessThanOrEqualTo(d.height - _navBarDp + 0.5),
    reason: 'ends under the navigation bar at ${d.width} dp, text ${d.scale}x',
  );
}

Widget _host(void Function(BuildContext) open) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  for (final d in _devices) {
    final tag = '${d.width.toInt()} dp, text ${d.scale}x';

    testWidgets('long AppSheet scrolls above the nav bar ($tag)', (tester) async {
      _setDevice(tester, d);
      await tester.pumpWidget(_host((context) => showAppSheet<void>(
            context: context,
            builder: (_) => AppSheet(
              title: 'Pilih isi meter',
              subtitle: 'Data yang tidak dilaporkan mobil ini tidak ditampilkan.',
              actions: [FilledButton(onPressed: () {}, child: const Text('Simpan'))],
              child: Column(
                children: [
                  for (final c in ObdMetricConfig.all)
                    ListTile(title: Text(c.label)),
                ],
              ),
            ),
          )));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _expectReachable(tester, find.text('Waktu pengapian'), d);
      await _expectReachable(tester, find.text('Simpan'), d);
    });

    testWidgets('DTC detail sheet reaches its last advice ($tag)', (tester) async {
      _setDevice(tester, d);
      await tester.pumpWidget(_host((context) => showDtcDetailSheet(context, 'P0300')));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _expectReachable(tester, find.text('Tutup'), d);
    });

    testWidgets('confirm and info dialogs fit ($tag)', (tester) async {
      _setDevice(tester, d);
      const message = 'Lampu Check Engine akan mati, tetapi kerusakannya belum '
          'tentu hilang: kode yang sama bisa muncul lagi. Data kesiapan uji '
          'emisi ikut terhapus.\n\nNyalakan kunci kontak (ON) dengan mesin '
          'mati sebelum menghapus.';
      await tester.pumpWidget(_host((context) => showConfirmDialog(
            context,
            title: 'Hapus kode kerusakan?',
            message: message,
            confirmLabel: 'Hapus kode',
            destructive: true,
          )));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _expectReachable(tester, find.text('Hapus kode'), d);
    });

    testWidgets('connection sheet fits with system bars ($tag)', (tester) async {
      _setDevice(tester, d);
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        obdServiceProvider.overrideWith((ref) => _ScriptedObd(ref)),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton(
                  onPressed: () => showObdConnectionSheet(context, ref),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Buka'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Adapter OBD'), findsOneWidget);
      await _expectReachable(tester, find.text('Mode simulator'), d);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      container.dispose();
      db.close();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('chart sheet keeps its statistics reachable ($tag)', (tester) async {
      _setDevice(tester, d);
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      late _ScriptedObd obd;
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        obdServiceProvider.overrideWith((ref) => obd = _ScriptedObd(ref)),
      ]);
      container.read(obdServiceProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _host((context) => TelemetryChartModal.show(context, ObdMetricType.rpm)),
      ));
      final initial = ObdState.initial();
      obd.emit(initial.copyWith(
        status: ObdStatus.connected,
        telemetry: initial.telemetry.copyWith(rpm: 1500),
        checkedSensors: const {ObdMetricType.rpm},
        supportedSensors: const {ObdMetricType.rpm},
      ));
      await tester.tap(find.text('Buka'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await _expectReachable(tester, find.text('Rata-rata'), d);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      container.dispose();
      db.close();
      await tester.pump(const Duration(milliseconds: 500));
    });
  }
}
