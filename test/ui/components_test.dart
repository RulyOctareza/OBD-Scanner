import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/core/ui/ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  void emit(ObdState next) => state = next;
}

void main() {
  group('MetricTile', () {
    testWidgets('pending shows a dash, never a number', (tester) async {
      await tester.pumpWidget(_app(const MetricTile(
        label: 'Suhu mesin',
        value: '0',
        unit: '°C',
        assessment: MetricAssessment(StatusLevel.noData),
      )));
      expect(find.text('—', findRichText: true), findsOneWidget);
      expect(find.textContaining('0'), findsNothing);
      expect(
        find.bySemanticsLabel('Suhu mesin, Belum ada data'),
        findsOneWidget,
      );
    });

    testWidgets('unsupported says so', (tester) async {
      await tester.pumpWidget(_app(const MetricTile(
        label: 'Aliran udara',
        value: null,
        unit: 'g/s',
        assessment: MetricAssessment(StatusLevel.unsupported),
      )));
      expect(find.text('Tidak didukung'), findsOneWidget);
    });

    testWidgets('a problem shows its note and level colour', (tester) async {
      await tester.pumpWidget(_app(const MetricTile(
        label: 'Suhu mesin',
        value: '118',
        unit: '°C',
        assessment: MetricAssessment(StatusLevel.kritis, 'Sangat tinggi'),
      )));
      expect(find.text('Sangat tinggi'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Suhu mesin, 118${Fmt.nbsp}°C, Sangat tinggi'),
        findsOneWidget,
      );
    });

    testWidgets('a normal value carries no status chip', (tester) async {
      await tester.pumpWidget(_app(const MetricTile(
        label: 'Kecepatan',
        value: '52',
        unit: 'km/jam',
      )));
      expect(find.byType(StatusChip), findsNothing);
    });
  });

  group('ConnectionStatusCard', () {
    ConnectionView view({
      ObdStatus status = ObdStatus.disconnected,
      bool sim = false,
      String? device,
      String? error,
    }) =>
        (
          status: status,
          isSimulator: sim,
          deviceName: device,
          errorMessage: error,
          statusDetail: null,
        );

    testWidgets('disconnected offers one Hubungkan button', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(ConnectionStatusCard(
        view: view(),
        onTap: () => taps++,
      )));
      expect(find.text('Belum terhubung'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hubungkan'));
      expect(taps, 1);
    });

    testWidgets('connected names the adapter', (tester) async {
      await tester.pumpWidget(_app(ConnectionStatusCard(
        view: view(status: ObdStatus.connected, device: 'OBDII'),
        onTap: () {},
      )));
      expect(find.text('Terhubung'), findsOneWidget);
      expect(find.text('OBDII'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('simulator is labelled as sample data', (tester) async {
      await tester.pumpWidget(_app(ConnectionStatusCard(
        view: view(status: ObdStatus.connected, sim: true),
        onTap: () {},
      )));
      expect(find.text('Mode simulator'), findsOneWidget);
      expect(find.text('Data contoh, bukan dari mobil'), findsOneWidget);
    });

    testWidgets('error offers a retry', (tester) async {
      await tester.pumpWidget(_app(ConnectionStatusCard(
        view: view(status: ObdStatus.error, error: 'OBDII tidak merespons.'),
        onTap: () {},
      )));
      expect(find.text('Gagal terhubung'), findsOneWidget);
      expect(find.text('OBDII tidak merespons.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  testWidgets('showConfirmDialog resolves to the choice', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    var result = showConfirmDialog(ctx,
        title: 'Hapus catatan?', message: 'Tidak bisa dibatalkan.',
        confirmLabel: 'Hapus', destructive: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = showConfirmDialog(ctx,
        title: 'Hapus catatan?', message: 'Tidak bisa dibatalkan.',
        confirmLabel: 'Hapus');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('showAppSheet opens on the root navigator', (tester) async {
    final rootKey = GlobalKey<NavigatorState>();
    final innerKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      navigatorKey: rootKey,
      home: Navigator(
        key: innerKey,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: (_) => const AppSheet(
                  title: 'Judul',
                  child: Text('Isi'),
                ),
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Isi'), findsOneWidget);
    final sheetNavigator =
        Navigator.of(tester.element(find.text('Isi')));
    expect(sheetNavigator, same(rootKey.currentState));
  });

  group('LiveMetricTile', () {
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

    Future<void> finish(WidgetTester tester) async {
      // ObdService schedules its startup auto-connect 3 s after creation.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await db.close();
      });
    }

    ObdState connected({double coolant = 90, double rpm = 800, double volts = 14}) {
      final initial = ObdState.initial();
      const sensors = {
        ObdMetricType.coolant,
        ObdMetricType.rpm,
        ObdMetricType.voltage,
      };
      return initial.copyWith(
        status: ObdStatus.connected,
        telemetry: initial.telemetry
            .copyWith(coolant: coolant, rpm: rpm, voltage: volts),
        checkedSensors: sensors,
        supportedSensors: sensors,
      );
    }

    testWidgets('shows the new value and status when the state changes',
        (tester) async {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _app(const Column(children: [
          LiveMetricTile(ObdMetricType.coolant),
          LiveMetricTile(ObdMetricType.voltage),
        ])),
      ));
      // Not connected yet: no numbers.
      expect(find.text('—', findRichText: true), findsNWidgets(2));

      obd.emit(connected());
      await tester.pump();
      expect(find.textContaining('90', findRichText: true), findsOneWidget);
      expect(find.byType(StatusChip), findsNothing);

      obd.emit(connected(coolant: 118, volts: 12.4));
      await tester.pump();
      expect(find.textContaining('118', findRichText: true), findsOneWidget);
      expect(find.text('Sangat tinggi'), findsOneWidget);
      expect(find.text('Pengisian lemah'), findsOneWidget);

      // Engine off: 12,4 V is a normal resting battery.
      obd.emit(connected(coolant: 118, volts: 12.4, rpm: 0));
      await tester.pump();
      expect(find.text('Pengisian lemah'), findsNothing);

      await finish(tester);
    });
  });
}
