import 'package:autocare/app.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/navigation/router.dart';
import 'package:autocare/features/diagnostics/presentation/diagnostic_scanner_screen.dart';
import 'package:autocare/features/diagnostics/presentation/dtc_lookup_screen.dart';
import 'package:autocare/features/health/presentation/health_screen.dart';
import 'package:autocare/features/live_data/presentation/dashboard_screen.dart';
import 'package:autocare/features/live_data/presentation/live_data_screen.dart';
import 'package:autocare/features/settings/presentation/settings_screen.dart';
import 'package:autocare/features/timeline/presentation/timeline_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

/// The whole app on an in-memory database, intro done, opened at [path].
Future<({AppDatabase db, ProviderContainer container})> _pumpApp(
  WidgetTester tester, {
  String path = '/health',
}) async {
  SharedPreferences.setMockInitialValues({});
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  final db = AppDatabase.withExecutor(NativeDatabase.memory());
  await tester.runAsync(
    () => db.setBoolPreference('has_completed_obd_intro', true),
  );
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const AutoCareApp(),
  ));
  goRouter.go(path);
  await _settle(tester);
  return (db: db, container: container);
}

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _teardown(
  WidgetTester tester,
  ({AppDatabase db, ProviderContainer container}) app,
) async {
  await _settle(tester, 4000);
  await tester.pumpWidget(const SizedBox());
  await _settle(tester, 1000);
  app.container.dispose();
  // Closed inside fake time: under runAsync the close waits on fake-zone work.
  app.db.close();
  await _settle(tester, 1000);
}

void _phone(WidgetTester tester, {double widthDp = 411, double textScale = 1.0}) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = Size(widthDp * 2.625, 2220);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('five tabs fit at phone width', (tester) async {
    _phone(tester);
    final app = await _pumpApp(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in ['Beranda', 'Live', 'Diagnostik', 'Riwayat', 'Pengaturan']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.widgetWithIcon(IconButton, Icons.settings_outlined), findsNothing);
    await _teardown(tester, app);
  });

  testWidgets('narrow screen with large text: four tabs and a gear',
      (tester) async {
    _phone(tester, widthDp: 320, textScale: 1.3);
    final app = await _pumpApp(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    final gear = find.widgetWithIcon(IconButton, Icons.settings_outlined);
    expect(gear, findsOneWidget);

    await tester.tap(gear);
    await _settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await _teardown(tester, app);
  });

  testWidgets('Live switches between Meter and Sensor', (tester) async {
    _phone(tester);
    final app = await _pumpApp(tester, path: '/dashboard');
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.tap(find.text('Sensor'));
    await _settle(tester);
    expect(find.byType(LiveDataScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(
      goRouter.routerDelegate.currentConfiguration.uri.path,
      '/live_data',
    );
    await _teardown(tester, app);
  });

  testWidgets('back on another tab returns to Beranda', (tester) async {
    _phone(tester);
    final app = await _pumpApp(tester, path: '/timeline');
    expect(find.byType(TimelineScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(goRouter.routerDelegate.currentConfiguration.uri.path, '/health');
    expect(find.byType(HealthScreen), findsOneWidget);
    await _teardown(tester, app);
  });

  testWidgets('every path the benchmark opens is a route', (tester) async {
    _phone(tester);
    final app = await _pumpApp(tester);
    final screens = <String, Type>{
      '/health': HealthScreen,
      '/dashboard': DashboardScreen,
      '/live_data': LiveDataScreen,
      '/timeline': TimelineScreen,
      '/settings': SettingsScreen,
      '/diagnostics': DiagnosticScannerScreen,
      '/dtc_lookup': DtcLookupScreen,
    };
    for (final entry in screens.entries) {
      goRouter.go(entry.key);
      await _settle(tester);
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
    }
    await _teardown(tester, app);
  });
}
