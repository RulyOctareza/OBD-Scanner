import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/features/settings/presentation/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

class _ScriptedObd extends ObdService {
  _ScriptedObd(super.ref);
}

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
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      obdServiceProvider.overrideWith((ref) => _ScriptedObd(ref)),
    ]);
  });

  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flushDb(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2220);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const SettingsScreen()),
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

  testWidgets('sections in plain words; a switch keeps its title', (tester) async {
    await pump(tester);
    for (final section in ['Mobil', 'Koneksi', 'Simulator']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(find.text('Hubungkan otomatis'), findsOneWidget);
    expect(find.text('Mode simulator'), findsWidgets);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Mode simulator'));
    await flushDb(tester);
    expect(find.widgetWithText(SwitchListTile, 'Mode simulator'), findsOneWidget);
    expect(find.text('Mesin hidup'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('odometer is edited in a sheet with validation', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Odometer'));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(_button('Simpan'));
    await settle(tester);
    expect(find.text('Tidak boleh kosong.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '162.000');
    await tester.tap(_button('Simpan'));
    await flushDb(tester);
    expect(find.text('162.000 km'), findsOneWidget);
    await finish(tester);
  });
}
