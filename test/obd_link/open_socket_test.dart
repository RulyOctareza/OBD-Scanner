// Case B: a socket that opens after the timeout or after a cancel is disposed,
// and the next open waits for the previous native connect to settle.
import 'dart:async';

import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/dev/fake_elm327.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Makes every open hang until the test completes it.
class PendingOpens {
  PendingOpens(FakeElm327Connector adapter) {
    adapter.onOpen = (address, newLink) {
      final completer = Completer<ObdLink>();
      _completers.add(completer);
      _factories.add(newLink);
      return completer.future;
    };
  }

  final List<Completer<ObdLink>> _completers = [];
  final List<FakeElm327Link Function()> _factories = [];

  int get count => _completers.length;

  FakeElm327Link complete(int index) {
    final link = _factories[index]();
    _completers[index].complete(link);
    return link;
  }

  void fail(int index, Object error) => _completers[index].completeError(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B. orphan socket', () {
    obdTest('B1 socket that opens after the 40 s timeout is disposed', (h) {
      final opens = PendingOpens(h.adapter);
      h.boot();
      h.startConnect(deviceA, 1);

      h.seconds(39);
      expect(h.status, ObdStatus.connecting);
      expect(h.state.statusDetail, 'Membuka koneksi Bluetooth…');

      h.seconds(2);
      expect(h.status, ObdStatus.error);
      expect(h.state.errorMessage, 'OBDII tidak merespons.');
      expect(h.state.errorHelp, contains('Detail teknis'));

      final late = opens.complete(0);
      h.seconds(1);

      expect(late.disposeCount, 1);
      expect(late.sent, isEmpty);
      expect(h.status, ObdStatus.error);
      expect(h.adapter.openCount, 1);
    });

    obdTest('B2 socket that opens after Batal is disposed', (h) {
      final opens = PendingOpens(h.adapter);
      h.boot();
      h.startConnect();
      h.seconds(3);

      h.service.cancelConnect();
      expect(h.status, ObdStatus.disconnected);

      final late = opens.complete(0);
      h.seconds(1);

      expect(late.disposeCount, 1);
      expect(late.sent, isEmpty);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);

      h.seconds(60);
      expect(h.adapter.openCount, 1, reason: 'cancelled connect retried');
    });

    obdTest('B3 next connect waits until the previous open has settled', (h) {
      final opens = PendingOpens(h.adapter);
      h.boot();
      h.startConnect(deviceA);
      h.service.cancelConnect();

      h.startConnect(deviceB);
      h.seconds(5);
      expect(h.status, ObdStatus.connecting);
      expect(h.state.statusDetail, 'Menunggu koneksi sebelumnya ditutup…');
      expect(h.adapter.openCount, 1, reason: 'two native connects at once');

      final orphan = opens.complete(0);
      h.settle();
      expect(orphan.disposeCount, 1);
      expect(h.adapter.openCount, 2);
      expect(h.state.statusDetail, 'Membuka koneksi Bluetooth…');

      final link = opens.complete(1);
      h.seconds(2);
      expect(h.status, ObdStatus.connected);
      expect(h.state.connectedDeviceAddress, deviceB.address);
      expect(link.disposeCount, 0);
      expect(orphan.sent, isEmpty);
    });

    obdTest('B3b a previous open that fails also releases the next one', (h) {
      final opens = PendingOpens(h.adapter);
      h.boot();
      h.startConnect(deviceA);
      h.service.cancelConnect();
      h.startConnect(deviceB);
      expect(h.adapter.openCount, 1);

      opens.fail(0, Exception('read failed, socket might closed'));
      h.settle();
      expect(h.adapter.openCount, 2);

      opens.complete(1);
      h.seconds(2);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('B3c a previous open that never settles blocks for 40 s only', (h) {
      PendingOpens(h.adapter);
      h.boot();
      h.startConnect(deviceA);
      h.service.cancelConnect();
      h.startConnect(deviceB);

      h.seconds(39);
      expect(h.adapter.openCount, 1);
      h.seconds(2);
      expect(h.adapter.openCount, 2);
    });

    obdTest('B4 retry after a timeout disposes the late socket first', (h) {
      final opens = PendingOpens(h.adapter);
      h.boot();
      h.startConnect(deviceA, 2);

      h.seconds(41);
      expect(h.status, ObdStatus.connecting);
      expect(h.state.statusDetail, contains('Percobaan 1 dari 2 gagal'));

      // Attempt 2 starts 2 s later and must not open beside attempt 1.
      h.seconds(3);
      expect(h.adapter.openCount, 1);
      expect(h.state.statusDetail, 'Menunggu koneksi sebelumnya ditutup…');

      final late = opens.complete(0);
      h.settle();
      expect(late.disposeCount, 1);
      expect(h.adapter.openCount, 2);

      final link = opens.complete(1);
      h.seconds(2);
      expect(h.status, ObdStatus.connected);
      expect(link.disposeCount, 0);
      expect(late.sent, isEmpty);
    });

    obdTest('B5 failing opens show the attempt, then the error card', (h) {
      h.adapter.onOpen = (address, newLink) =>
          Future.error(Exception('read failed, socket might closed'));
      h.boot();
      h.startConnect(deviceA, 2);

      expect(h.status, ObdStatus.connecting);
      expect(h.state.statusDetail, 'Percobaan 1 dari 2 gagal, mencoba lagi…');
      expect(h.state.errorMessage, isNull);

      h.seconds(3);
      expect(h.status, ObdStatus.error);
      expect(h.state.statusDetail, isNull);
      expect(h.state.errorMessage, 'OBDII tidak merespons.');
      expect(h.state.errorHelp, contains('Torque'));
      expect(h.state.errorHelp, contains('read failed'));
      expect(h.adapter.openCount, 2);
      expect(h.adapter.cancelDiscoveryCount, 2);

      h.seconds(120);
      expect(h.adapter.openCount, 2);
    });

    obdTest('B6 socket open but ELM327 silent ends in the init error', (h) {
      h.adapter.autoReply = false;
      h.boot();
      h.startConnect(deviceA, 1);
      h.seconds(12);

      expect(h.status, ObdStatus.error);
      expect(
        h.state.errorMessage,
        'Adapter tersambung, tetapi tidak menjawab perintah ELM327.',
      );
      expect(h.link.disposeCount, 1);
      expect(h.link.sent, ['AT Z', 'AT Z']);
    });
  });
}
