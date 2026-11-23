// A new install knows nothing about the car: a neutral name, no odometer and
// no oil target until the driver enters them, and every screen says so
// instead of showing someone else's car. Also guards the Beranda listener:
// healthProvider must not refresh while Beranda is offstage, because each
// Riverpod refresh costs the whole screen a frame.
import 'package:autocare/app.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/navigation/router.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/features/health/presentation/health_provider.dart';
import 'package:autocare/features/health/presentation/health_screen.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';
import 'package:autocare/features/settings/presentation/settings_screen.dart';
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
}

class _HealthRefreshes extends ProviderObserver {
  int count = 0;

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (provider == healthProvider) count++;
  }
}

ObdState _connected(double coolant) {
  final initial = ObdState.initial();
  const sensors = {ObdMetricType.coolant, ObdMetricType.voltage, ObdMetricType.rpm};
  return initial.copyWith(
    status: ObdStatus.connected,
    connectedDeviceName: 'OBDII',
    telemetry: initial.telemetry.copyWith(rpm: 800, coolant: coolant, voltage: 14),
    checkedSensors: sensors,
    supportedSensors: sensors,
    dtcsChecked: true,
  );
}

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late ProviderContainer container;
  late _ScriptedObd obd;
  late _HealthRefreshes refreshes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    refreshes = _HealthRefreshes();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        obdServiceProvider.overrideWith((ref) => obd = _ScriptedObd(ref)),
      ],
      observers: [refreshes],
    );
    container.read(obdServiceProvider);
  });

  Future<void> settle(WidgetTester tester, [int ms = 800]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> loadSettings(WidgetTester tester) async {
    container.read(settingsProvider);
    for (var i = 0; i < 50 && !container.read(settingsProvider).isLoaded; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await settle(tester, 200);
  }

  Future<void> finish(WidgetTester tester) async {
    await settle(tester, 4000);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    container.dispose();
    db.close();
    await settle(tester, 500);
  }

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
  }

  testWidgets('a new install has a neutral name and no odometer or oil target',
      (tester) async {
    await loadSettings(tester);
    final s = container.read(settingsProvider);
    expect(s.vehicleName, defaultVehicleName);
    expect(s.hasOdometer, isFalse);
    expect(s.hasOilSchedule, isFalse);
    await tester.runAsync(() async {
      expect(await db.getDoublePreference('current_odometer'), 0);
      expect(await db.getDoublePreference('next_oil_odometer'), 0);
    });

    // An oil target without an odometer gives no oil reminder, an entered
    // odometer close to the target does.
    final notifier = container.read(settingsProvider.notifier);
    await tester.runAsync(() => notifier.updateNextOilOdometer(5000));
    final kinds = healthReportFor(_connected(90), container.read(settingsProvider))
        .warnings
        .map((w) => w.title);
    expect(kinds, isNot(contains('Ganti oli sebentar lagi')));
    await tester.runAsync(() => notifier.updateOdometer(4000));
    expect(
      healthReportFor(_connected(90), container.read(settingsProvider))
          .warnings
          .map((w) => w.title),
      contains('Ganti oli sebentar lagi'),
    );
    await finish(tester);
  });

  testWidgets('Beranda and Pengaturan say the odometer is not entered',
      (tester) async {
    phone(tester);
    await loadSettings(tester);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const HealthScreen()),
    ));
    await settle(tester);
    expect(find.text('Mobil saya'), findsOneWidget);
    expect(find.text('Ganti oli'), findsOneWidget);
    expect(find.text('Belum diisi'), findsOneWidget);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const SettingsScreen()),
    ));
    await settle(tester);
    // Odometer and oil target.
    expect(find.text('Belum diisi'), findsNWidgets(2));
    expect(find.text('Isi agar diingatkan saat waktunya ganti oli.'), findsOneWidget);
    expect(find.textContaining('161.420'), findsNothing);
    await finish(tester);
  });

  testWidgets(
      'an offstage Beranda does not refresh healthProvider and still vibrates '
      'on a new warning', (tester) async {
    phone(tester);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    await tester.runAsync(() => db.setBoolPreference('has_completed_obd_intro', true));
    goRouter.go('/splash');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const AutoCareApp(),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    goRouter.go('/health');
    await settle(tester);
    obd.emit(_connected(90));
    await settle(tester);

    goRouter.go('/dashboard');
    await settle(tester);
    refreshes.count = 0;
    haptics.clear();
    for (final coolant in [91.0, 92.0, 93.0, 94.0]) {
      obd.emit(_connected(coolant));
      await settle(tester, 200);
    }
    expect(refreshes.count, 0, reason: 'healthProvider refreshed offstage');
    expect(haptics, isEmpty);

    obd.emit(_connected(118));
    await settle(tester, 200);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(refreshes.count, 0);

    goRouter.go('/health');
    await settle(tester);
    expect(find.text('Mesin terlalu panas'), findsOneWidget);
    await finish(tester);
  });
}
