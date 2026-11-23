// Defect F6: only a valid mode 03 answer may change the stored trouble codes
// or mark them as read. Garbage, adapter errors and the NO DATA of a car with
// the ignition off must leave both alone.
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _both = ['P0133', 'P0420'];

bool _isObdRequest(String command) =>
    command == '03' || (command.length == 4 && command.startsWith('01'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F6. polled mode 03', () {
    obdTest('P1 ignition off (everything NO DATA): codes stay unread', (h) {
      h.adapter.dtcs = const ['0133', '0420'];
      h.adapter.responder =
          (command) => _isObdRequest(command) ? 'NO DATA' : null;
      h.boot();
      h.startConnect();
      h.seconds(10);

      expect(h.status, ObdStatus.connected);
      expect(h.link.sent, contains('03'));
      expect(h.state.dtcsChecked, isFalse);
      expect(h.state.telemetry.dtcs, isEmpty);
    });

    obdTest('P1b ignition turned on later: the next valid 03 is taken', (h) {
      h.adapter.dtcs = const ['0133', '0420'];
      h.adapter.responder =
          (command) => _isObdRequest(command) ? 'NO DATA' : null;
      h.boot();
      h.startConnect();
      h.seconds(3);
      expect(h.state.dtcsChecked, isFalse);

      h.adapter.responder = null;
      // Mode 03 comes round again after 20 poll cycles.
      h.seconds(12);
      expect(h.state.dtcsChecked, isTrue);
      expect(h.state.telemetry.dtcs, _both);
    });

    for (final garbage in ['CAN ERROR', '?', 'BUS INIT: ERROR', 'SEARCHING...']) {
      obdTest('P2 codes read, later 03 answered "$garbage": codes kept', (h) {
        h.adapter.dtcs = const ['0133', '0420'];
        h.boot();
        h.connect();
        expect(h.state.telemetry.dtcs, _both);
        expect(h.state.dtcsChecked, isTrue);

        var polls = 0;
        h.adapter.responder = (command) {
          if (command != '03') return null;
          polls++;
          return garbage;
        };
        h.seconds(12);

        expect(polls, greaterThan(0), reason: '03 was not polled again');
        expect(h.state.telemetry.dtcs, _both);
        expect(h.state.dtcsChecked, isTrue);
      });
    }

    obdTest('P3 ECU alive, 03 answers NO DATA: read, no codes', (h) {
      h.adapter.responder = (command) => command == '03' ? 'NO DATA' : null;
      h.boot();
      h.connect();
      h.seconds(1);

      expect(h.link.sent, contains('03'));
      expect(h.state.telemetry.rpm, greaterThan(0));
      expect(h.state.dtcsChecked, isTrue);
      expect(h.state.telemetry.dtcs, isEmpty);
    });

    obdTest('P4 03 answers 43 00: read, no codes', (h) {
      h.boot();
      final link = h.connect();
      h.seconds(1);

      expect(link.sent, contains('03'));
      expect(h.state.dtcsChecked, isTrue);
      expect(h.state.telemetry.dtcs, isEmpty);
    });

    obdTest('P5 codes gone on a later valid 03: list is emptied', (h) {
      h.adapter.dtcs = const ['0133', '0420'];
      h.boot();
      h.connect();
      expect(h.state.telemetry.dtcs, _both);

      // Cleared with another tool, or the fault healed.
      h.adapter.dtcs = const [];
      h.seconds(12);

      expect(h.state.telemetry.dtcs, isEmpty);
      expect(h.state.dtcsChecked, isTrue);
    });

    obdTest('P7 scan with the ignition off: codes not read, known codes kept',
        (h) {
      h.adapter.dtcs = const ['0133', '0420'];
      h.boot();
      h.connect();
      expect(h.state.telemetry.dtcs, _both);

      // Key turned off: the adapter still answers AT commands, the ECU none.
      h.adapter.responder = (command) =>
          command.startsWith('AT') ? null : 'NO DATA';
      final result = h.finish(h.service.performFullDiagnosticScan());

      expect(result.activeDtcsRead, isFalse);
      expect(result.activeDtcs, _both);
      expect(h.state.telemetry.dtcs, _both);
      expect(h.state.dtcsChecked, isTrue);
    });

    obdTest('P7b scan with a live ECU and no codes: read, empty', (h) {
      h.boot();
      h.connect();

      final result = h.finish(h.service.performFullDiagnosticScan());

      expect(result.activeDtcsRead, isTrue);
      expect(result.activeDtcs, isEmpty);
      expect(h.state.telemetry.dtcs, isEmpty);
    });

    obdTest('P7c scan answers 03 with garbage: known codes are not overwritten',
        (h) {
      h.adapter.dtcs = const ['0133', '0420'];
      h.boot();
      h.connect();
      h.adapter.responder = (command) => command == '03' ? 'CAN ERROR' : null;

      final result = h.finish(h.service.performFullDiagnosticScan());

      expect(result.activeDtcsRead, isFalse);
      expect(result.activeDtcs, _both);
      expect(h.state.telemetry.dtcs, _both);
    });

    obdTest('P7d scan reads the codes of a live ECU', (h) {
      h.adapter.dtcs = const ['0133', '0420'];
      h.boot();
      h.connect();

      final result = h.finish(h.service.performFullDiagnosticScan());

      expect(result.activeDtcsRead, isTrue);
      expect(result.activeDtcs, _both);
    });

    obdTest('P6 a 03 answer with invalid bytes around a valid frame is taken',
        (h) {
      h.adapter.responder = (command) =>
          command == '03' ? 'SEARCHING...\r43 01 01 33' : null;
      h.boot();
      h.connect();
      h.seconds(1);

      expect(h.state.dtcsChecked, isTrue);
      expect(h.state.telemetry.dtcs, ['P0133']);
    });
  });
}
