import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/features/health/presentation/health_screen.dart';
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

ObdState _connected({double coolant = 90, double volts = 14, bool dtcsRead = true}) {
  final initial = ObdState.initial();
  const sensors = {ObdMetricType.coolant, ObdMetricType.voltage, ObdMetricType.rpm};
  return initial.copyWith(
    status: ObdStatus.connected,
    connectedDeviceName: 'OBDII',
    telemetry: initial.telemetry.copyWith(
      rpm: 800,
      coolant: coolant,
      voltage: volts,
    ),
    checkedSensors: sensors,
    supportedSensors: sensors,
    dtcsChecked: dtcsRead,
  );
}

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

  Future<void> settle(WidgetTester tester, [int ms = 800]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await settle(tester, 4000);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    container.dispose();
    db.close();
    await settle(tester, 500);
  }

  testWidgets('Beranda follows the live state, never claiming health without data',
      (tester) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const HealthScreen()),
    ));
    await settle(tester);

    // Not connected: no score, the connect call, every check without data.
    expect(find.text('Belum terhubung'), findsOneWidget);
    expect(find.text('Belum ada data'), findsWidgets);
    expect(find.text('Belum dipindai'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Skor kesehatan belum ada data')),
        findsOneWidget);

    obd.emit(_connected());
    await settle(tester);
    expect(find.text('Terhubung'), findsOneWidget);
    expect(find.text('Mobil saya dalam kondisi baik'), findsOneWidget);
    expect(find.text('90 °C'), findsOneWidget);
    expect(find.text('Tidak ada kode'), findsOneWidget);

    obd.emit(_connected(coolant: 118));
    await settle(tester);
    expect(find.text('Mesin terlalu panas'), findsOneWidget);
    expect(find.text('Lihat data live'), findsOneWidget);
    expect(find.text('118 °C'), findsOneWidget);
    expect(find.text('Periksa segera'), findsOneWidget);

    await finish(tester);
  });
}
