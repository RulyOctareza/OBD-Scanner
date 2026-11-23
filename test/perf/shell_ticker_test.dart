import 'package:autocare/app.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/navigation/router.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/features/live_data/presentation/dashboard_screen.dart';
import 'package:autocare/features/live_data/presentation/telemetry_provider.dart';
import 'package:autocare/features/live_data/presentation/widgets/gauge_widget.dart';
import 'package:autocare/features/live_data/presentation/widgets/telemetry_chart_modal.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  void emit(ObdState next) => state = next;
}

/// Engine idling, car standing (speed 0, rpm < 1100), so no trip starts:
/// trip recording is not what these tests are about.
ObdState _connected(double rpm) {
  final initial = ObdState.initial();
  return initial.copyWith(
    status: ObdStatus.connected,
    telemetry: initial.telemetry.copyWith(
      rpm: rpm,
      speed: 0,
      coolant: 90,
      voltage: 14,
    ),
    checkedSensors: ObdMetricType.values.toSet(),
    supportedSensors: ObdMetricType.values.toSet(),
  );
}

typedef _App = ({
  AppDatabase db,
  ProviderContainer container,
  _ScriptedObd obd,
});

Future<_App> _pumpMeter(WidgetTester tester) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 2220);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  final db = AppDatabase.withExecutor(NativeDatabase.memory());
  await tester.runAsync(
    () => db.setBoolPreference('has_completed_obd_intro', true),
  );
  late _ScriptedObd obd;
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      obdServiceProvider.overrideWith((ref) => obd = _ScriptedObd(ref)),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AutoCareApp()),
  );
  goRouter.go('/dashboard');
  await _settle(tester);
  obd.emit(_connected(800));
  await _settle(tester);
  return (db: db, container: container, obd: obd);
}

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _teardown(WidgetTester tester, _App app) async {
  await _settle(tester, 4000);
  await tester.pumpWidget(const SizedBox());
  await _settle(tester, 1000);
  app.container.dispose();
  app.db.close();
  await _settle(tester, 1000);
}

bool _ticking(WidgetTester tester, Finder finder) =>
    TickerMode.of(tester.element(finder.first));

Finder _onMeter(String text) => find.descendant(
  of: find.byType(DashboardScreen),
  matching: find.text(text),
);

void main() {
  testWidgets(
    'a root sheet pauses the Meter below; closing it shows fresh values',
    (tester) async {
      final app = await _pumpMeter(tester);
      expect(_ticking(tester, find.byType(GaugeWidget)), isTrue);

      TelemetryChartModal.show(
        tester.element(find.byType(DashboardScreen)),
        ObdMetricType.rpm,
      );
      await _settle(tester);
      expect(
        _ticking(tester, find.byType(GaugeWidget)),
        isFalse,
        reason: 'no gauge animation frames under the sheet',
      );

      app.obd.emit(_connected(900));
      await _settle(tester, 500);
      expect(
        _onMeter('900'),
        findsNothing,
        reason: 'no live rebuilds under the sheet',
      );

      Navigator.of(tester.element(find.byType(TelemetryChartModal))).pop();
      await _settle(tester);
      expect(_ticking(tester, find.byType(GaugeWidget)), isTrue);
      expect(
        _onMeter('900'),
        findsWidgets,
        reason: 'fresh value once uncovered',
      );
      await _teardown(tester, app);
    },
  );

  testWidgets('the chart sheet itself keeps updating', (tester) async {
    final app = await _pumpMeter(tester);
    TelemetryChartModal.show(
      tester.element(find.byType(DashboardScreen)),
      ObdMetricType.rpm,
    );
    await _settle(tester);
    expect(_ticking(tester, find.byType(TelemetryChartModal)), isTrue);

    app.obd.emit(_connected(1050));
    await _settle(tester, 1500); // the chart buffer samples once a second
    final history = app.container.read(
      telemetryHistoryProvider(ObdMetricType.rpm),
    );
    expect(history.valueOrNull?.currentValue, 1050);

    Navigator.of(tester.element(find.byType(TelemetryChartModal))).pop();
    await _teardown(tester, app);
  });

  testWidgets('the full-screen cockpit keeps animating', (tester) async {
    final app = await _pumpMeter(tester);
    await tester.runAsync(
      () => app.container
          .read(settingsProvider.notifier)
          .setFullscreenCockpit(true),
    );
    await _settle(tester);
    expect(_ticking(tester, find.byType(GaugeWidget)), isTrue);

    app.obd.emit(_connected(1000));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'gauge animates to 1000',
    );

    await tester.runAsync(
      () => app.container
          .read(settingsProvider.notifier)
          .setFullscreenCockpit(false),
    );
    await _teardown(tester, app);
  });
}
