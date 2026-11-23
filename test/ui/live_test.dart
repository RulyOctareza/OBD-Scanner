import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/core/ui/ui.dart';
import 'package:autocare/features/live_data/presentation/dashboard_screen.dart';
import 'package:autocare/features/live_data/presentation/live_data_screen.dart';
import 'package:autocare/features/live_data/presentation/widgets/telemetry_chart_modal.dart';
import 'package:autocare/features/trips/presentation/trip_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  void emit(ObdState next) => state = next;
}

class _ScriptedTrips extends TripRecorderNotifier {
  _ScriptedTrips(super.ref);

  void emit(TripRecorderState next) => state = next;
}

const _all = {
  ObdMetricType.rpm,
  ObdMetricType.speed,
  ObdMetricType.coolant,
  ObdMetricType.voltage,
  ObdMetricType.fuel,
  ObdMetricType.map,
};

ObdState _connected({
  double rpm = 900,
  double coolant = 90,
  double volts = 14,
  Set<ObdMetricType> checked = _all,
  Set<ObdMetricType> supported = _all,
}) {
  final initial = ObdState.initial();
  return initial.copyWith(
    status: ObdStatus.connected,
    connectedDeviceName: 'OBDII',
    telemetry: initial.telemetry.copyWith(
      rpm: rpm,
      speed: 0,
      coolant: coolant,
      voltage: volts,
      fuelLevel: 60,
      mapValue: 35,
    ),
    checkedSensors: checked,
    supportedSensors: supported,
    dtcsChecked: true,
  );
}

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late ProviderContainer container;
  late _ScriptedObd obd;
  late _ScriptedTrips trips;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
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

  testWidgets('Meter follows readings and never shows a value it has not got',
      (tester) async {
    await pump(tester, const DashboardScreen());
    expect(find.text('Meter belum aktif'), findsOneWidget);

    // Connected, nothing asked yet: dashes, not zeros.
    obd.emit(_connected(checked: const {}, supported: const {}));
    await settle(tester);
    expect(find.text('—', findRichText: true), findsWidgets);
    expect(find.text('0'), findsNothing);

    obd.emit(_connected(rpm: 900));
    await settle(tester);
    expect(find.text('900'), findsOneWidget);

    obd.emit(_connected(rpm: 2400, coolant: 118));
    await settle(tester);
    expect(find.text('2.400'), findsOneWidget);
    expect(find.text('Sangat tinggi'), findsOneWidget);

    await finish(tester);
  });

  testWidgets('Trip A and B show the recorder distances', (tester) async {
    await pump(tester, const DashboardScreen());
    obd.emit(_connected());
    trips.emit(trips.state.copyWith(tripADistance: 12.34, tripBDistance: 401.06));
    await settle(tester);
    expect(find.bySemanticsLabel('Trip A 12,3 km'), findsOneWidget);
    expect(find.bySemanticsLabel('Trip B 401,1 km'), findsOneWidget);

    trips.emit(trips.state.copyWith(tripADistance: 0));
    await settle(tester);
    expect(find.bySemanticsLabel('Trip A 0,0 km'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Sensor lists values and what the car does not report',
      (tester) async {
    await pump(tester, const LiveDataScreen());
    obd.emit(_connected(
      checked: {..._all, ObdMetricType.maf},
      supported: _all,
    ));
    await settle(tester);
    expect(find.text('90 °C'), findsOneWidget);
    expect(find.text('Tidak dilaporkan mobil ini'), findsOneWidget);
    expect(find.text('Aliran udara'), findsOneWidget);

    obd.emit(_connected(coolant: 108, checked: {..._all, ObdMetricType.maf}, supported: _all));
    await settle(tester);
    expect(find.text('108 °C'), findsOneWidget);
    expect(find.text('Tinggi'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('chart sheet fills from live samples', (tester) async {
    await pump(
      tester,
      const Scaffold(body: TelemetryChartModal(metricType: ObdMetricType.rpm)),
    );
    // The stored series is a database read: let it finish for real.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    expect(find.text('Belum ada data grafik'), findsOneWidget);

    obd.emit(_connected(rpm: 1500));
    await settle(tester, 3000);
    expect(find.text('Saat ini'), findsOneWidget);
    expect(find.text('1.500 rpm'), findsWidgets);
    expect(find.byType(StatusChip), findsOneWidget); // "Live"
    await finish(tester);
  });
}
