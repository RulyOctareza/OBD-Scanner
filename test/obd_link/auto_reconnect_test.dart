// Case E, auto-reconnect: the periodic check leaves the link alone after a
// manual Batal or Putus, reconnects after a lost link, and backs off.
import 'dart:async';

import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _saved = '00:00:00:00:00:0A';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E. auto-reconnect timer', () {
    obdTest('R1 no reconnect after Putus until auto-connect is allowed again',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      h.connect(deviceA);
      h.service.disconnect();

      h.seconds(600);
      expect(h.status, ObdStatus.disconnected);
      expect(h.adapter.openCount, 1, reason: 'reconnected after manual Putus');

      // Settings "Sambung otomatis" switched on again.
      h.service.allowAutoReconnect();
      h.seconds(121);
      expect(h.adapter.openCount, 2);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('R2 no reconnect after Batal', savedAddress: _saved,
        reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      final pending = Completer<ObdLink>();
      h.adapter.onOpen = (address, newLink) => pending.future;
      h.startConnect(deviceA);
      h.service.cancelConnect();
      pending.completeError(Exception('read failed, socket might closed'));

      h.seconds(600);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(h.adapter.openCount, 1, reason: 'reconnected after Batal');
    });

    obdTest('R3 lost link is reconnected by the next check',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      final first = h.connect(deviceA);

      first.closeFromAdapter();
      h.settle();
      expect(h.status, ObdStatus.error);

      h.seconds(17);
      expect(h.adapter.openCount, 2);
      expect(h.status, ObdStatus.connected);
      expect(h.state.errorMessage, isNull);
      expect(h.state.connectedDeviceAddress, _saved);
    });

    obdTest('R4 failed attempts back off 15, 30, 60, 120 s and stay at 120 s',
        savedAddress: _saved, reconnectTimer: true, (h) {
      final attempts = <int>[];
      h.adapter.onOpen = (address, newLink) {
        attempts.add(h.async.elapsed.inSeconds);
        return Future.error(Exception('read failed, socket might closed'));
      };
      h.service;
      h.seconds(480);

      // Startup attempt at 3 s, then checks 15 s after start and 30, 60, 120,
      // 120 s apart.
      expect(attempts, [3, 15, 45, 105, 225, 345, 465]);
      expect(h.status, ObdStatus.error);
    });

    obdTest('R4b after a successful connect the next check comes within 15 s',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.adapter.onOpen = (address, newLink) =>
          Future.error(Exception('read failed, socket might closed'));
      h.service;
      // Attempts at 3, 15, 45 and 105 s: the next check is 120 s away.
      h.seconds(110);
      expect(h.adapter.openCount, 4);

      h.adapter.onOpen = null;
      final link = h.connect(deviceA);
      h.seconds(3);
      link.closeFromAdapter();
      h.settle();
      expect(h.status, ObdStatus.error);
      final opened = h.adapter.openCount;

      // Dongle lost its power for a moment while driving (defect F3).
      h.seconds(16);
      expect(h.adapter.openCount, opened + 1, reason: 'still waiting 120 s');
      expect(h.status, ObdStatus.connected);
    });

    obdTest('R4c switching "Sambung otomatis" back on resets a long backoff',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.adapter.onOpen = (address, newLink) =>
          Future.error(Exception('read failed, socket might closed'));
      h.service;
      h.seconds(110);
      expect(h.adapter.openCount, 4);

      h.adapter.onOpen = null;
      h.service.allowAutoReconnect();
      h.seconds(16);
      expect(h.adapter.openCount, 5);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('R5 "Sambung otomatis" off: the timer never attempts',
        savedAddress: _saved,
        prefs: {'auto_connect_obd': 'false'},
        reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      h.seconds(600);
      expect(h.adapter.openCount, 0);
      expect(h.status, ObdStatus.disconnected);
    });

    obdTest('R6 open connection sheet holds the timer attempts',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      h.service.holdAutoConnect();
      h.seconds(300);
      expect(h.adapter.openCount, 0);

      h.service.releaseAutoConnect();
      h.seconds(121);
      expect(h.adapter.openCount, 1);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('R7 simulator mode: the timer never attempts',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      h.service.applySimulatorMode(true);
      h.seconds(600);
      expect(h.adapter.openCount, 0);
      expect(h.state.isSimulatorMode, isTrue);
      h.service.applySimulatorMode(false);
    });

    obdTest('R8 Bluetooth off: checks go on, nothing is opened, no error shown',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.adapter.ready = false;
      h.boot();
      h.seconds(600);
      expect(h.adapter.openCount, 0);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);

      h.adapter.ready = true;
      h.seconds(121);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('R9 a connected link is left alone by the timer',
        savedAddress: _saved, reconnectTimer: true, (h) {
      h.bootWithoutStartupConnect();
      final link = h.connect(deviceA);
      h.seconds(600);
      expect(h.adapter.openCount, 1);
      expect(link.disposeCount, 0);
      expect(h.status, ObdStatus.connected);
    });
  });
}
