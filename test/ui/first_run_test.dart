import 'package:autocare/app.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/navigation/router.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late ProviderContainer container;
  final asked = <int>[];

  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    asked.clear();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        if (call.method == 'requestPermissions') {
          final list = (call.arguments as List).cast<int>();
          asked.addAll(list);
          return {for (final p in list) p: 1};
        }
        return 1;
      },
    );
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    goRouter.go('/splash');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const AutoCareApp(),
    ));
    // Settings load from the database for real.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }

  Future<void> finish(WidgetTester tester) async {
    await settle(tester, 4000);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    container.dispose();
    db.close();
    await settle(tester, 500);
  }

  String path() => goRouter.routerDelegate.currentConfiguration.uri.path;

  testWidgets('splash leaves as soon as settings are loaded', (tester) async {
    await start(tester);
    await settle(tester, 300);
    expect(path(), '/obd_intro');
    expect(find.text('Selamat datang di AutoCare'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('simulator path asks for nothing and lands on Beranda',
      (tester) async {
    await start(tester);
    await settle(tester);
    await tester.tap(find.text('Coba dengan simulator'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester, 1500);
    expect(path(), '/health');
    expect(asked, isEmpty);
    expect(container.read(settingsProvider).isSimulatorMode, isTrue);
    expect(container.read(settingsProvider).hasCompletedObdIntro, isTrue);
    await finish(tester);
  });

  testWidgets('adapter path: permissions, plug-in guide, then the connection sheet',
      (tester) async {
    await start(tester);
    await settle(tester);
    await tester.tap(find.text('Pakai adapter OBD'));
    await settle(tester);
    expect(find.text('Izin untuk adapter'), findsOneWidget);

    await tester.tap(find.text('Berikan izin'));
    await settle(tester);
    expect(asked, isNotEmpty);
    expect(find.text('Pasang adapter'), findsOneWidget);

    await tester.tap(find.text('Hubungkan adapter'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester, 1500);
    expect(path(), '/health');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(container.read(settingsProvider).isSimulatorMode, isFalse);
    await finish(tester);
  });
}
