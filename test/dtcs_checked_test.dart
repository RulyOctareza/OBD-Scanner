// ObdState.dtcsChecked: whether trouble codes were read on this link. Health
// shows "Belum dipindai" until it is true, so an empty code list is never
// presented as "no codes" before the car was asked.
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'obd_link/support/harness.dart';

void main() {
  obdTest('the first polling cycle reads codes; disconnect resets it', (h) {
    h.boot();
    expect(h.state.dtcsChecked, isFalse);

    h.startConnect();
    expect(h.state.dtcsChecked, isFalse, reason: 'connecting, nothing read');

    // Mode 03 is part of the first live-PID cycle of each link.
    h.seconds(2);
    expect(h.status, ObdStatus.connected);
    expect(h.link.sent, contains('03'));
    expect(h.state.dtcsChecked, isTrue);
    expect(h.state.telemetry.dtcs, isEmpty);

    h.service.disconnect();
    h.settle();
    expect(h.state.dtcsChecked, isFalse);
  });

  obdTest('a new connect resets it until its own first cycle', (h) {
    h.boot();
    h.connect();
    expect(h.state.dtcsChecked, isTrue);

    h.service.connectToDevice(deviceB);
    expect(h.state.dtcsChecked, isFalse);

    h.seconds(2);
    expect(h.status, ObdStatus.connected);
    expect(h.state.dtcsChecked, isTrue);
  });

  obdTest('a diagnostic scan keeps it and reports the codes', (h) {
    h.boot();
    h.adapter.dtcs = const ['0138']; // P0138
    h.connect();

    h.finish(h.service.performFullDiagnosticScan());
    expect(h.state.dtcsChecked, isTrue);
    expect(h.state.telemetry.dtcs, ['P0138']);
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
