// Accessibility guidelines on every screen with data: Android tap targets
// of at least 48 dp, and every tappable element labelled for a screen
// reader. Text contrast is checked on the theme (test/ui/theme_test.dart).
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

const _routes = [
  '/health',
  '/dashboard',
  '/live_data',
  '/diagnostics',
  '/dtc_lookup',
  '/timeline',
  '/settings',
];

void main() {
  setUpAll(loadAppFonts);

  testWidgets('every screen meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    await tester.runAsync(() => db.setBoolPreference('has_completed_obd_intro', true));
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    Future<void> settle([int ms = 1500]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    goRouter.go('/splash');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const AutoCareApp(),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle();
    container.read(settingsProvider.notifier).setSimulatorMode(true);
    await settle(3000);

    for (final route in _routes) {
      goRouter.go(route);
      await settle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
          reason: '$route tap targets');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
          reason: '$route labels');
    }

    container.read(settingsProvider.notifier).setSimulatorMode(false);
    await settle(4000);
    await tester.pumpWidget(const SizedBox());
    await settle(1000);
    container.dispose();
    db.close();
    await settle(1000);
    semantics.dispose();
  });
}
