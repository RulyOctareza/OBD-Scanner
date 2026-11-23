// ObdState.dtcsChecked: whether trouble codes were read on this link. Health
// shows "Belum dipindai" until it is true, so an empty code list is never
// presented as "no codes" before the car was asked.
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'obd_link/support/harness.dart';

void main() {
  obdTest('a polled mode 03 answer sets it; disconnect resets it', (h) {
    h.boot();
    expect(h.state.dtcsChecked, isFalse);

    final link = h.connect();
    expect(h.state.dtcsChecked, isFalse,
        reason: 'connected, but no mode 03 answer yet');

    // The sparse DTC slot comes after a number of live-PID cycles.
    h.seconds(60);
    expect(link.sent, contains('03'));
    expect(h.state.dtcsChecked, isTrue);
    expect(h.state.telemetry.dtcs, isEmpty);

    h.service.disconnect();
    h.settle();
    expect(h.state.dtcsChecked, isFalse);
  });

  obdTest('a diagnostic scan sets it; a new connect resets it', (h) {
    h.boot();
    h.adapter.dtcs = const ['0138']; // P0138
    h.connect();
    expect(h.state.dtcsChecked, isFalse);

    h.finish(h.service.performFullDiagnosticScan());
    expect(h.state.dtcsChecked, isTrue);
    expect(h.state.telemetry.dtcs, ['P0138']);

    h.service.connectToDevice(deviceB);
    h.settle();
    expect(h.state.dtcsChecked, isFalse);
  });

  obdTest('clearing codes sets it', (h) {
    h.boot();
    h.adapter.dtcs = const ['0138']; // P0138
    h.connect();

    expect(h.finish(h.service.clearDtcCodes()), isTrue);
    expect(h.state.dtcsChecked, isTrue);
    expect(h.state.telemetry.dtcs, isEmpty);
  });

  obdTest('cancelling a connect resets it', (h) {
    h.boot();
    h.connect();
    h.seconds(60);
    expect(h.state.dtcsChecked, isTrue);

    h.startConnect(deviceB);
    expect(h.status, isIn([ObdStatus.connecting, ObdStatus.initializing]));
    h.service.cancelConnect();
    h.settle();
    expect(h.state.dtcsChecked, isFalse);
  });

  obdTest('the simulator counts codes as read; leaving it resets', (h) {
    h.boot();
    h.service.applySimulatorMode(true);
    h.seconds(3);
    expect(h.state.isSimulatorMode, isTrue);
    expect(h.state.dtcsChecked, isTrue);

    h.service.applySimulatorMode(false);
    h.settle();
    expect(h.state.dtcsChecked, isFalse);
  });
}
