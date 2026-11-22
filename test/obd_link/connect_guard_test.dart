// Case E: a second connect is ignored while one is running, Batal ends in
// disconnected, and auto-connect respects the holds around it.
import 'dart:async';

import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/dev/fake_elm327.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Makes the first open hang until [complete] is called.
class HangingOpen {
  HangingOpen(FakeElm327Connector adapter) {
    adapter.onOpen = (address, newLink) {
      addresses.add(address);
      _newLink = newLink;
      return _completer.future;
    };
  }

  final Completer<ObdLink> _completer = Completer<ObdLink>();
  late FakeElm327Link Function() _newLink;
  final List<String> addresses = [];

  FakeElm327Link complete() {
    final link = _newLink();
    _completer.complete(link);
    return link;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E. double connect and Batal', () {
    obdTest('E1 second connect while connecting is ignored', (h) {
      final open = HangingOpen(h.adapter);
      h.boot();
      h.startConnect(deviceA);
      expect(h.status, ObdStatus.connecting);

      h.startConnect(deviceB);
      h.seconds(5);

      expect(h.adapter.openCount, 1);
      expect(open.addresses, [deviceA.address]);
      expect(h.state.connectedDeviceAddress, deviceA.address);
      expect(h.state.connectedDeviceName, deviceA.name);
      expect(h.status, ObdStatus.connecting);
    });

    obdTest('E1b second connect while initializing is ignored',
        autoReply: false, (h) {
      h.boot();
      h.startConnect(deviceA);
      expect(h.status, ObdStatus.initializing);

      h.startConnect(deviceB);
      h.seconds(2);

      expect(h.adapter.openCount, 1);
      expect(h.state.connectedDeviceAddress, deviceA.address);
      expect(h.link.sent, ['AT Z']);
      expect(h.link.disposeCount, 0);
    });

    obdTest('E2 Batal while connecting ends in disconnected, no retry', (h) {
      HangingOpen(h.adapter);
      h.boot();
      h.startConnect(deviceA);

      h.service.cancelConnect();
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.statusDetail, isNull);
      expect(h.state.errorMessage, isNull);
      expect(h.state.errorHelp, isNull);

      h.seconds(120);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(h.adapter.openCount, 1);
    });

    obdTest('E2b Batal while initializing disposes the link, writes no more',
        autoReply: false, (h) {
      h.boot();
      h.startConnect(deviceA);
      final link = h.link;
      expect(h.status, ObdStatus.initializing);

      h.service.cancelConnect();
      expect(h.status, ObdStatus.disconnected);
      expect(link.disposeCount, 1);

      h.seconds(120);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(link.sent, ['AT Z']);
      expect(link.disposeCount, 1);
      expect(h.adapter.openCount, 1);
    });

    obdTest('E2c Batal during the retry pause stops the retry', (h) {
      h.adapter.onOpen = (address, newLink) =>
          Future.error(Exception('read failed, socket might closed'));
      h.boot();
      h.startConnect(deviceA, 2);
      expect(h.state.statusDetail, contains('Percobaan 1 dari 2 gagal'));

      h.service.cancelConnect();
      h.seconds(60);

      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(h.adapter.openCount, 1);
    });

    obdTest('E3 a connect right after Batal works', autoReply: false, (h) {
      h.boot();
      h.startConnect(deviceA);
      final first = h.link;
      h.service.cancelConnect();

      h.adapter.autoReply = true;
      h.startConnect(deviceB);
      h.seconds(2);

      expect(h.status, ObdStatus.connected);
      expect(h.state.connectedDeviceAddress, deviceB.address);
      expect(first.disposeCount, 1);
      expect(h.link.disposeCount, 0);
    });

    obdTest('E4 disconnect() during a connect behaves as Batal', (h) {
      final open = HangingOpen(h.adapter);
      h.boot();
      h.startConnect(deviceA);

      h.service.disconnect();
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);

      final late = open.complete();
      h.seconds(60);
      expect(late.disposeCount, 1);
      expect(h.status, ObdStatus.disconnected);
      expect(h.adapter.openCount, 1);
    });

    obdTest('E5 cancelConnect with no connect running changes nothing', (h) {
      h.boot();
      final link = h.connect();

      h.service.cancelConnect();
      h.seconds(1);

      expect(h.status, ObdStatus.connected);
      expect(link.disposeCount, 0);
    });

    obdTest('E6 switching adapters tears the first link down', (h) {
      h.boot();
      final first = h.connect(deviceA);

      final second = h.connect(deviceB);

      expect(first.disposeCount, 1);
      expect(second.disposeCount, 0);
      expect(h.state.connectedDeviceAddress, deviceB.address);
      expect(h.state.errorMessage, isNull);
    });

    obdTest('E7 successful connect remembers the adapter', (h) {
      h.boot();
      h.connect(deviceB);
      h.settle();

      expect(h.pref('last_obd_device_address'), deviceB.address);
      expect(h.pref('last_obd_device_name'), deviceB.name);
    });
  });

  group('E. simulator and real link', () {
    obdTest('E8 entering simulator during a connect abandons the connect', (h) {
      final open = HangingOpen(h.adapter);
      h.boot();
      h.startConnect(deviceA);

      h.service.applySimulatorMode(true);
      h.seconds(2);
      expect(h.state.isSimulatorMode, isTrue);
      expect(h.state.connectedDeviceName, 'Simulator');

      final late = open.complete();
      h.seconds(5);

      expect(late.disposeCount, 1);
      expect(late.sent, isEmpty);
      expect(h.state.isSimulatorMode, isTrue);
      expect(h.state.connectedDeviceAddress, isNull);
      expect(h.state.errorMessage, isNull);

      h.service.applySimulatorMode(false);
    });

    obdTest('E9 entering simulator while connected closes the real link', (h) {
      h.boot();
      final link = h.connect();

      h.service.applySimulatorMode(true);
      h.seconds(2);

      expect(link.disposeCount, 1);
      expect(h.state.isSimulatorMode, isTrue);
      expect(h.status, ObdStatus.connected);
      expect(h.state.errorMessage, isNull);

      h.service.applySimulatorMode(false);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.isSimulatorMode, isFalse);
      expect(h.state.connectedDeviceName, isNull);
    });

    obdTest('E10 connecting from simulator mode leaves simulator mode', (h) {
      h.boot();
      h.service.applySimulatorMode(true);
      h.seconds(2);
      expect(h.state.isSimulatorMode, isTrue);

      final link = h.connect(deviceA);

      expect(h.state.isSimulatorMode, isFalse);
      expect(h.state.connectedDeviceName, deviceA.name);
      expect(link.sent.take(4), initCommands);
      expect(h.pref('is_simulator_mode'), 'false');
    });
  });

  group('E. startup auto-connect', () {
    obdTest('E11 connects to the remembered adapter after 3 s, one attempt',
        savedAddress: '00:00:00:00:00:0A', (h) {
      h.service;
      h.ms(2900);
      expect(h.adapter.openCount, 0);

      h.seconds(3);
      expect(h.adapter.openCount, 1);
      expect(h.status, ObdStatus.connected);
      expect(h.state.connectedDeviceAddress, '00:00:00:00:00:0A');
    });

    obdTest('E11b one attempt only: a failed auto-connect ends in error',
        savedAddress: '00:00:00:00:00:0A', (h) {
      h.adapter.onOpen = (address, newLink) =>
          Future.error(Exception('read failed, socket might closed'));
      h.service;
      h.seconds(10);

      expect(h.adapter.openCount, 1);
      expect(h.status, ObdStatus.error);
    });

    obdTest('E12 no remembered adapter: nothing is opened', (h) {
      h.service;
      h.seconds(10);
      expect(h.adapter.openCount, 0);
      expect(h.status, ObdStatus.disconnected);
    });

    obdTest('E13 Bluetooth off or permission missing: nothing is opened',
        savedAddress: '00:00:00:00:00:0A', (h) {
      h.adapter.ready = false;
      h.service;
      h.seconds(10);
      expect(h.adapter.openCount, 0);
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
    });

    obdTest('E14 open connection sheet holds auto-connect',
        savedAddress: '00:00:00:00:00:0A', (h) {
      h.service.holdAutoConnect();
      h.seconds(10);
      expect(h.adapter.openCount, 0);

      h.service.releaseAutoConnect();
      h.seconds(10);
      expect(h.adapter.openCount, 0, reason: 'startup window already passed');
    });

    obdTest('E15 simulator preference on: no Bluetooth auto-connect',
        savedAddress: '00:00:00:00:00:0A',
        prefs: {'is_simulator_mode': 'true'}, (h) {
      h.service;
      h.seconds(10);
      expect(h.adapter.openCount, 0);
      expect(h.state.isSimulatorMode, isTrue);
      h.service.applySimulatorMode(false);
    });

    obdTest('E16 a manual connect in progress is not doubled by auto-connect',
        savedAddress: '00:00:00:00:00:0A', (h) {
      HangingOpen(h.adapter);
      h.service;
      h.seconds(1);
      h.startConnect(deviceB);

      h.seconds(10);
      expect(h.adapter.openCount, 1);
      expect(h.state.connectedDeviceAddress, deviceB.address);
    });
  });
}
