import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/widgets/obd_connection_sheet.dart';
import 'package:autocare/features/live_data/presentation/widgets/gauge_widget.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_completed_obd_intro': true,
      'is_simulator_mode': true,
      'vehicle_name': 'Agya',
      'current_odometer': 161420.0,
      'next_oil_odometer': 166420.0,
    });
  });

  test('Gauge metric labels are Indonesia-first', () {
    final labels = ObdMetricConfig.all.map((c) => c.label).toList();
    expect(labels, contains('Putaran Mesin'));
    expect(labels, contains('Kecepatan'));
    expect(labels, contains('Suhu Pendingin'));
    expect(labels, isNot(contains('TACHOMETER')));
    expect(labels, isNot(contains('SPEEDOMETER')));
  });

  testWidgets('Sensor empty state shows Hubungkan OBD CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ObdNotConnectedView(
          state: ObdState.initial(),
          onConnect: () {},
        ),
      ),
    );

    expect(find.text('Belum Terhubung ke Mobil'), findsOneWidget);
    expect(find.text('Hubungkan OBD'), findsOneWidget);
  });

  test('setObdIntroCompleted persists flag', () async {
    final database = AppDatabase.withExecutor(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    for (var i = 0; i < 50; i++) {
      if (container.read(settingsProvider).isLoaded) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final notifier = container.read(settingsProvider.notifier);
    await notifier.setObdIntroCompleted(true);

    expect(container.read(settingsProvider).hasCompletedObdIntro, isTrue);
    expect(await database.getBoolPreference('has_completed_obd_intro'), isTrue);
  });
}
