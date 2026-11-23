import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/features/timeline/presentation/timeline_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets drift's real async work (inserts, stream updates) finish.
  Future<void> flushDb(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
  }

  Future<void> pump(WidgetTester tester, {double width = 411, double scale = 1}) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = Size(width * 2.625, 2220);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const TimelineScreen()),
    ));
    await flushDb(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await settle(tester, 4000);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    container.dispose();
    db.close();
    await settle(tester, 500);
  }

  testWidgets('empty history explains how it fills', (tester) async {
    await pump(tester);
    expect(find.text('Riwayat masih kosong'), findsOneWidget);
    expect(find.text('Catat'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('refuel form validates, then logs with Indonesian numbers',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Catat'));
    await settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Isi BBM'),
    ));
    await settle(tester);

    await tester.tap(_button('Simpan'));
    await settle(tester);
    expect(find.text('Isi jumlah liter.'), findsOneWidget);
    expect(find.text('Isi total harga.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah'), '25,3');
    await tester.enterText(find.widgetWithText(TextFormField, 'Total harga'), '252.000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Odometer'), '161.380');
    await tester.tap(_button('Simpan'));
    await flushDb(tester);
    await flushDb(tester);

    expect(find.text('Isi BBM · Pertalite'), findsOneWidget);
    expect(find.text('25,3 L'), findsOneWidget);
    expect(find.textContaining('Rp252.000'), findsWidgets);
    expect(find.textContaining('161.380 km'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('delete is visible and can be undone', (tester) async {
    await tester.runAsync(() => db.into(db.maintenanceLogs).insert(
          MaintenanceLogsCompanion.insert(
            timestamp: DateTime(2026, 11, 13, 9),
            type: 'Ganti Oli',
            odometer: 158300,
            cost: const Value(385000),
          ),
        ));
    await pump(tester);
    expect(find.text('Ganti Oli Mesin'), findsOneWidget);

    await tester.tap(find.byTooltip('Pilihan'));
    await settle(tester);
    await tester.tap(find.text('Hapus'));
    await flushDb(tester);
    expect(find.text('Ganti Oli Mesin'), findsNothing);
    expect(find.text('Ganti Oli Mesin dihapus'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await flushDb(tester);
    await flushDb(tester);
    expect(find.text('Ganti Oli Mesin'), findsOneWidget);
    await finish(tester);
  });

  for (final (width, height, scale) in [(411.0, 846.0, 1.0), (320.0, 640.0, 1.3), (320.0, 640.0, 2.0)]) {
    for (final form in ['Isi BBM', 'Servis']) {
      testWidgets('$form form fits with system bars ($width dp, text ${scale}x)',
          (tester) async {
        tester.view.devicePixelRatio = 2.625;
        tester.view.physicalSize = Size(width * 2.625, height * 2.625);
        const insets = FakeViewPadding(top: 24 * 2.625, bottom: 48 * 2.625);
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.darkTheme, home: const TimelineScreen()),
        ));
        await flushDb(tester);
        await tester.tap(find.text('Catat'));
        await settle(tester);
        await tester.tap(find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(form),
        ));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_button('Simpan'));
        await settle(tester, 300);
        expect(tester.getRect(_button('Simpan')).bottom,
            lessThanOrEqualTo(height - 48 + 0.5));
        await finish(tester);
      });
    }
  }

  testWidgets('every type filter stays on screen at 320 dp and large text',
      (tester) async {
    await pump(tester, width: 320, scale: 1.3);
    for (final label in ['Semua', 'Perjalanan', 'Isi BBM', 'Servis']) {
      final rect = tester.getRect(find.widgetWithText(ChoiceChip, label));
      expect(rect.right, lessThanOrEqualTo(320), reason: label);
    }
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}