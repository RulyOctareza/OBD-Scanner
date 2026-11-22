import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/widgets/live_obd.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);

  void emit(ObdState next) => state = next;
}

ObdState _connected({double rpm = 800, double coolant = 90}) {
  final initial = ObdState.initial();
  return initial.copyWith(
    status: ObdStatus.connected,
    telemetry: initial.telemetry.copyWith(rpm: rpm, coolant: coolant),
    checkedSensors: const {ObdMetricType.rpm, ObdMetricType.coolant, ObdMetricType.maf},
    supportedSensors: const {ObdMetricType.rpm, ObdMetricType.coolant},
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _ScriptedObd obd;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        obdServiceProvider.overrideWith((ref) => obd = _ScriptedObd(ref)),
      ],
    );
    container.read(obdServiceProvider);
  });

  Future<void> finish(WidgetTester tester) async {
    // ObdService schedules its startup auto-connect 3 s after creation.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    // Drift completes its close on real async work, not on fake time.
    await tester.runAsync(() async {
      container.dispose();
      await db.close();
    });
  }

  Future<void> pumpHost(
    WidgetTester tester,
    ValueNotifier<bool> onstage,
    Widget child,
  ) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: onstage,
            builder: (context, visible, _) =>
                TickerMode(enabled: visible, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('LiveMetric rebuilds for its own metric only', (tester) async {
    var builds = 0;
    MetricReading? shown;
    obd.emit(_connected());
    await pumpHost(
      tester,
      ValueNotifier(true),
      LiveMetric(
        type: ObdMetricType.rpm,
        builder: (context, reading, _) {
          builds++;
          shown = reading;
          return const SizedBox();
        },
      ),
    );
    expect(builds, 1);
    expect(shown, const MetricReading(value: 800));

    obd.emit(_connected(coolant: 95));
    await tester.pump();
    expect(builds, 1, reason: 'coolant changed, rpm did not');

    obd.emit(_connected(rpm: 1500, coolant: 95));
    await tester.pump();
    expect(builds, 2);
    expect(shown!.value, 1500);
    await finish(tester);
  });

  testWidgets('offstage: no rebuilds, fresh value on return', (tester) async {
    final onstage = ValueNotifier(true);
    var builds = 0;
    MetricReading? shown;
    obd.emit(_connected());
    await pumpHost(
      tester,
      onstage,
      LiveMetric(
        type: ObdMetricType.rpm,
        builder: (context, reading, _) {
          builds++;
          shown = reading;
          return const SizedBox();
        },
      ),
    );
    onstage.value = false;
    await tester.pump();
    final buildsWhenHidden = builds;

    for (var rpm = 900.0; rpm < 2000; rpm += 100) {
      obd.emit(_connected(rpm: rpm));
      await tester.pump();
    }
    expect(builds, buildsWhenHidden, reason: 'hidden: no rebuild per update');

    onstage.value = true;
    await tester.pump();
    expect(shown!.value, 1900, reason: 'latest value when shown again');

    obd.emit(_connected(rpm: 2500));
    await tester.pump();
    expect(shown!.value, 2500, reason: 'watching again after return');
    await finish(tester);
  });

  testWidgets('step hides changes finer than the display', (tester) async {
    var builds = 0;
    obd.emit(_connected(rpm: 800));
    await pumpHost(
      tester,
      ValueNotifier(true),
      LiveMetric(
        type: ObdMetricType.rpm,
        step: 10,
        builder: (context, reading, _) {
          builds++;
          return const SizedBox();
        },
      ),
    );
    obd.emit(_connected(rpm: 802.25));
    await tester.pump();
    expect(builds, 1);
    obd.emit(_connected(rpm: 812));
    await tester.pump();
    expect(builds, 2);
    await finish(tester);
  });

  testWidgets('ObdSelect rebuilds on selected value only', (tester) async {
    var builds = 0;
    obd.emit(_connected());
    await pumpHost(
      tester,
      ValueNotifier(true),
      ObdSelect<ObdStatus>(
        selector: (s) => s.status,
        builder: (context, status, _) {
          builds++;
          return const SizedBox();
        },
      ),
    );
    obd.emit(_connected(rpm: 3000));
    await tester.pump();
    expect(builds, 1);
    obd.emit(obd.state.copyWith(status: ObdStatus.error));
    await tester.pump();
    expect(builds, 2);
    await finish(tester);
  });

  test('readingOf flags pending and unsupported metrics', () {
    final state = _connected();
    expect(readingOf(state, ObdMetricType.rpm).hasValue, isTrue);
    expect(readingOf(state, ObdMetricType.maf).isUnsupported, isTrue);
    expect(readingOf(state, ObdMetricType.speed).isPending, isTrue);
    expect(readingOf(ObdState.initial(), ObdMetricType.rpm).isPending, isTrue);
  });

  test('ObdMetricConfig.of matches the enum order', () {
    for (final type in ObdMetricType.values) {
      expect(ObdMetricConfig.of(type).type, type);
    }
  });
}
