// Every screen at 320 and 411 dp wide, text 1.0, 1.3 and 2.0, with a status
// bar and a navigation bar: no layout error, and no label, title or value
// cut off. An ellipsis raises no error, so every paragraph is checked for
// didExceedMaxLines; only free text that the screen deliberately clips (a
// trouble code's explanation, which its sheet shows in full) may clip. No
// paragraph may break a line inside a word or cut a one-line text at its
// edge (support/text_breaks.dart).
import 'package:autocare/app.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/navigation/router.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';
import 'support/text_breaks.dart';

typedef _Device = ({double width, double height, double scale});

const List<_Device> _devices = [
  (width: 411, height: 846, scale: 1.0),
  (width: 411, height: 846, scale: 1.3),
  (width: 411, height: 846, scale: 2.0),
  (width: 320, height: 640, scale: 1.0),
  (width: 320, height: 640, scale: 1.3),
  (width: 320, height: 640, scale: 2.0),
];

const List<String> _routes = [
  '/health',
  '/dashboard',
  '/live_data',
  '/diagnostics',
  '/dtc_lookup',
  '/timeline',
  '/settings',
];

/// Texts a screen clips on purpose: long explanations whose full text is one
/// tap away.
bool _mayClip(String text) => text.length > 60;

Future<void> _seed(AppDatabase db) async {
  await db.setBoolPreference('has_completed_obd_intro', true);
  await db.setPreference('vehicle_name', 'Toyota Agya 1.2 G (2019)');
  await db.setDoublePreference('current_odometer', 161420);
  await db.setDoublePreference('next_oil_odometer', 163300);
  final now = DateTime(2026, 11, 22, 18, 30);
  await db.into(db.trips).insert(TripsCompanion.insert(
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: Value(now.subtract(const Duration(hours: 1))),
        distance: const Value(18.4),
        fuelEconomy: const Value(14.2),
        avgSpeed: const Value(37),
        maxCoolant: const Value(92),
        maxRpm: const Value(3120),
        tripHealthScore: const Value(100),
        durationMinutes: const Value(34),
        idleMinutes: const Value(6),
      ));
  await db.into(db.fuelLogs).insert(FuelLogsCompanion.insert(
        timestamp: now.subtract(const Duration(days: 1)),
        fuelType: 'Pertamax Turbo',
        liters: 25.3,
        price: 352000,
        odometer: 161380,
        economy: const Value(14.6),
      ));
  await db.into(db.maintenanceLogs).insert(MaintenanceLogsCompanion.insert(
        timestamp: now.subtract(const Duration(days: 10)),
        type: 'Kuras Radiator',
        description: const Value('Coolant Toyota Super Long Life'),
        odometer: 158300,
        cost: const Value(385000),
      ));
}

void main() {
  setUpAll(loadAppFonts);

  for (final d in _devices) {
    final tag = '${d.width.toInt()} dp, text ${d.scale}x';
    testWidgets('every screen fits ($tag)', (tester) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = Size(d.width * 2.625, d.height * 2.625);
      const insets = FakeViewPadding(top: 24 * 2.625, bottom: 48 * 2.625);
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      tester.platformDispatcher.textScaleFactorTestValue = d.scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      SharedPreferences.setMockInitialValues({});

      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      await tester.runAsync(() => _seed(db));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final problems = <String>[];
      var where = 'start';
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        problems.add('[$where] ${details.exceptionAsString().split('\n').first}');
      };

      Future<void> settle([int ms = 800]) async {
        for (var i = 0; i < ms ~/ 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // Tabs keep their screens mounted offstage; only what shows counts.
      bool onstage(RenderObject r) {
        for (RenderObject? o = r; o != null; o = o.parent) {
          if (o is RenderOffstage && o.offstage) return false;
        }
        return true;
      }

      void checkClipping() {
        for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
          if (!p.attached || !onstage(p)) continue;
          final text = p.text.toPlainText();
          for (final b in midWordBreaks(p)) {
            problems.add('[$where] word broken: "$b"');
          }
          if (cutAtEdge(p)) problems.add('[$where] cut at edge: "$text"');
          if (!p.didExceedMaxLines || _mayClip(text)) continue;
          problems.add('[$where] clipped: "$text"');
        }
      }

      goRouter.go('/splash');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const AutoCareApp(),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await settle();
      where = '/health (start)';
      container.read(settingsProvider.notifier).setSimulatorMode(true);
      await settle(3000);

      for (final route in _routes) {
        where = route;
        goRouter.go(route);
        await settle(1500);
        checkClipping();
      }

      where = 'teardown';
      container.read(settingsProvider.notifier).setSimulatorMode(false);
      await settle(4000);
      await tester.pumpWidget(const SizedBox());
      await settle(1000);
      container.dispose();
      db.close();
      await settle(1000);
      FlutterError.onError = original;

      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    testWidgets('first run fits ($tag)', (tester) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = Size(d.width * 2.625, d.height * 2.625);
      const insets = FakeViewPadding(top: 24 * 2.625, bottom: 48 * 2.625);
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      tester.platformDispatcher.textScaleFactorTestValue = d.scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => call.method == 'requestPermissions'
            ? {for (final p in (call.arguments as List).cast<int>()) p: 1}
            : 1,
      );
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final problems = <String>[];
      var where = 'splash';
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        problems.add('[$where] ${details.exceptionAsString().split('\n').first}');
      };
      Future<void> settle([int ms = 800]) async {
        for (var i = 0; i < ms ~/ 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      void checkClipping() {
        for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
          if (!p.attached) continue;
          final text = p.text.toPlainText();
          for (final b in midWordBreaks(p)) {
            problems.add('[$where] word broken: "$b"');
          }
          if (cutAtEdge(p)) problems.add('[$where] cut at edge: "$text"');
          if (p.didExceedMaxLines) problems.add('[$where] clipped: "$text"');
        }
      }

      goRouter.go('/splash');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const AutoCareApp(),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await settle();
      for (final (step, tap) in [
        ('mode', 'Pakai adapter OBD'),
        ('permissions', 'Berikan izin'),
        ('plug-in', null),
      ]) {
        where = step;
        checkClipping();
        if (tap != null) {
          if (find.text(tap).evaluate().isEmpty) {
            final shown = tester.allWidgets.whereType<Text>().map((t) => t.data).whereType<String>().take(12).join(' | ');
            problems.add('[$where] missing "$tap"; shows: $shown');
            break;
          }
          await tester.ensureVisible(find.text(tap));
          await settle(300);
          await tester.tap(find.text(tap));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await settle();
        }
      }

      where = 'teardown';
      await settle(4000);
      await tester.pumpWidget(const SizedBox());
      await settle(1000);
      container.dispose();
      db.close();
      await settle(1000);
      FlutterError.onError = original;
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
