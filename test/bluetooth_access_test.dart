import 'package:autocare/core/bluetooth/bluetooth_access.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLikelyObdAdapter', () {
    test('matches common ELM327 names', () {
      for (final name in ['OBDII', 'OBD2', 'V-LINK', 'Vgate iCar Pro', 'KONNWEI', 'ELM327 v1.5']) {
        expect(isLikelyObdAdapter(name), isTrue, reason: name);
      }
    });

    test('rejects audio devices and empty names', () {
      for (final name in ['JBL Flip 5', 'Galaxy Buds', 'TOYOTA AUDIO', '', null]) {
        expect(isLikelyObdAdapter(name), isFalse, reason: '$name');
      }
    });
  });

  group('ObdDeviceList.fromBonded', () {
    const lastUsed = BluetoothDevice(name: 'MyDongle', address: '00:00:00:00:00:03');
    const obd = BluetoothDevice(name: 'OBDII', address: '00:00:00:00:00:02');
    const headset = BluetoothDevice(name: 'Galaxy Buds', address: '00:00:00:00:00:01');
    const watch = BluetoothDevice(
      name: 'Watch',
      address: '00:00:00:00:00:04',
      type: BluetoothDeviceType.le,
    );

    test('puts last used first, OBD-looking next, and drops BLE-only', () {
      final list = ObdDeviceList.fromBonded(
        [headset, obd, watch, lastUsed],
        lastUsedAddress: lastUsed.address,
      );

      expect(list.likely.map((d) => d.address), [lastUsed.address, obd.address]);
      expect(list.others.map((d) => d.address), [headset.address]);
      expect(list.readiness, BluetoothReadiness.ready);
    });
  });
}
