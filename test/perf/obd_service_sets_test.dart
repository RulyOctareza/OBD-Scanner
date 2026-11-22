import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/dev/fake_elm327.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sensor sets keep their identity while membership is unchanged', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final adapter = FakeElm327Connector(
        latency: const Duration(milliseconds: 20),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = AppDatabase.withExecutor(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          obdLinkConnectorProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);

      container.read(obdServiceProvider.notifier).connectToDevice(
            const BluetoothDevice(address: '00:00:00:00:00:01', name: 'Fake'),
          );
      // Init (AT Z, AT E0, AT SP 0, 0100) and two full poll cycles.
      async.elapse(const Duration(seconds: 3));
      expect(container.read(obdServiceProvider).status, ObdStatus.connected);
      expect(adapter.links.single.sent.take(4), [
        'AT Z',
        'AT E0',
        'AT SP 0',
        '0100',
      ]);

      final settled = container.read(obdServiceProvider);
      expect(settled.checkedSensors, isNotEmpty);
      var updates = 0;
      container.listen<ObdState>(obdServiceProvider, (previous, next) {
        updates++;
        expect(identical(next.checkedSensors, settled.checkedSensors), isTrue);
        expect(
          identical(next.supportedSensors, settled.supportedSensors),
          isTrue,
        );
      });
      async.elapse(const Duration(seconds: 2));
      expect(updates, greaterThan(20));
      expect(adapter.answers, greaterThan(40));
    });
  });
}
