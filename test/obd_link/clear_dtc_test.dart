// Defect F5: "Hapus kode" must report what the ECU really did. Mode 04 is
// followed by a read-back of mode 03, and only codes that are gone count as
// cleared.
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _both = ['P0133', 'P0420'];

/// Connects to a car that stores P0133 and P0420 and lets the first poll cycle
/// read them.
void _connectWithTwoCodes(ObdHarness h) {
  h.adapter.dtcs = const ['0133', '0420'];
  h.boot();
  h.connect();
  expect(h.state.telemetry.dtcs, _both);
}

List<DtcLog> _logs(ObdHarness h) => h.finish(
      h.db.select(h.db.dtcLogs).get(),
      within: const Duration(milliseconds: 50),
    );

DtcClearResult _clear(ObdHarness h) => h.finish(
      h.service.clearTroubleCodes(),
      within: const Duration(seconds: 20),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F5. clear trouble codes', () {
    obdTest('K1 ECU clears everything: cleared, both codes logged', (h) {
      final probe = SingleFlightProbe(h.adapter);
      _connectWithTwoCodes(h);
      final written = h.link.sent.length;

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.cleared);
      expect(result.removed, _both);
      expect(result.remaining, isEmpty);
      expect(h.state.telemetry.dtcs, isEmpty);
      expect(_logs(h).map((l) => l.code), unorderedEquals(_both));
      expect(_logs(h).every((l) => !l.active), isTrue);

      // Read, clear, read back, as one uninterrupted sequence, then polling.
      final log = h.link.sent.sublist(written);
      final start = log.indexOf('03');
      expect(log.sublist(start, start + 3), ['03', '04', '03']);
      expect(log.sublist(start + 3), isNotEmpty);
      expect(log[start + 3], 'AT RV');
      expect(probe.violations, isEmpty);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('K2 ECU refuses with 7F 04 22: rejected, nothing changes', (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) => command == '04' ? '7F 04 22' : null;

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.rejected);
      expect(result.removed, isEmpty);
      expect(result.remaining, _both);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
      expect(h.status, ObdStatus.connected);
    });

    for (final answer in ['NO DATA', 'ERROR', '?']) {
      obdTest('K2b adapter answers 04 with "$answer": rejected', (h) {
        _connectWithTwoCodes(h);
        h.adapter.responder = (command) => command == '04' ? answer : null;

        final result = _clear(h);

        expect(result.outcome, DtcClearOutcome.rejected);
        expect(h.state.telemetry.dtcs, _both);
        expect(_logs(h), isEmpty);
      });
    }

    obdTest('K2c ECU acknowledges 04 but the codes are still there: rejected',
        (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) => command == '04' ? '44' : null;

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.rejected);
      expect(result.remaining, _both);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
    });

    obdTest('K3 one code comes back: partial, only the gone code is logged',
        (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) {
        if (command != '04') return null;
        h.adapter.dtcs = const ['0420'];
        return '44';
      };

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.partial);
      expect(result.removed, ['P0133']);
      expect(result.remaining, ['P0420']);
      expect(h.state.telemetry.dtcs, ['P0420']);
      expect(_logs(h).map((l) => l.code), ['P0133']);
    });

    obdTest('K4 read-back never answers: failed, state and log untouched', (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) {
        if (command != '04') return null;
        // The adapter falls silent right after acknowledging the clear.
        h.link.autoReply = false;
        return '44';
      };

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.failed);
      expect(result.removed, isEmpty);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
    });

    obdTest('K4b link lost during the clear: failed, state and log untouched',
        (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) {
        if (command != '04') return null;
        h.link.closeFromAdapter();
        return '44';
      };

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.failed);
      expect(_logs(h), isEmpty);
      expect(h.status, ObdStatus.error);
    });

    obdTest('K4c read-back answers ERROR after a positive 04: failed', (h) {
      _connectWithTwoCodes(h);
      var cleared = false;
      h.adapter.responder = (command) {
        if (command == '04') {
          cleared = true;
          return '44';
        }
        // Only the read-back fails; later polls of 03 answer normally.
        if (command == '03' && cleared) {
          cleared = false;
          return 'CAN ERROR';
        }
        return null;
      };

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.failed);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
    });

    obdTest('K4d read-back never answers after a refused 04: rejected', (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) {
        if (command != '04') return null;
        h.link.autoReply = false;
        return '7F 04 22';
      };

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.rejected);
      expect(result.remaining, _both);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
    });

    obdTest('K4e first read fails: the codes already known are the baseline',
        (h) {
      _connectWithTwoCodes(h);
      var reads = 0;
      h.adapter.responder = (command) {
        if (command == '03' && reads++ == 0) return 'BUS INIT: ERROR';
        return null;
      };

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.cleared);
      expect(result.removed, _both);
      expect(_logs(h).map((l) => l.code), unorderedEquals(_both));
    });

    obdTest('K4f ignition switched off during the clear: not reported cleared',
        (h) {
      _connectWithTwoCodes(h);
      var off = false;
      h.adapter.responder = (command) {
        if (command == '04') {
          off = true;
          return 'NO DATA';
        }
        // A dead ECU answers nothing: NO DATA for every request.
        if (off && (command == '03' || command.startsWith('01'))) {
          return 'NO DATA';
        }
        return null;
      };

      final result = _clear(h);

      expect(result.outcome, isNot(DtcClearOutcome.cleared));
      expect(result.outcome, isNot(DtcClearOutcome.partial));
      expect(result.removed, isEmpty);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
    });

    obdTest('K5 04 gets no answer, read-back shows the codes: rejected', (h) {
      _connectWithTwoCodes(h);
      final link = h.link;
      link.autoReply = false;
      h.ms(100);
      final pending = h.service.clearTroubleCodes();
      // The poll command on the wire is answered first.
      link.reply('41 0C 1A F8');
      h.ms(100);
      expect(link.sent.last, '03');
      link.reply('43 02 01 33 04 20');
      h.ms(100);
      expect(link.sent.last, '04');

      // No answer to 04 within its 5 s, then the read-back.
      h.ms(5600);
      expect(link.sent.last, '03');
      link.reply('43 02 01 33 04 20');
      link.autoReply = true;
      final result = h.finish(pending, within: const Duration(seconds: 2));

      expect(result.outcome, DtcClearOutcome.rejected);
      expect(h.state.telemetry.dtcs, _both);
      expect(_logs(h), isEmpty);
    });

    obdTest('K6 clearDtcCodes is true only when everything was cleared', (h) {
      _connectWithTwoCodes(h);
      h.adapter.responder = (command) => command == '04' ? '7F 04 22' : null;
      expect(
        h.finish(h.service.clearDtcCodes(),
            within: const Duration(seconds: 20)),
        isFalse,
      );

      h.adapter.responder = null;
      expect(
        h.finish(h.service.clearDtcCodes(),
            within: const Duration(seconds: 20)),
        isTrue,
      );
      expect(h.state.telemetry.dtcs, isEmpty);
      expect(_logs(h).map((l) => l.code), unorderedEquals(_both));
    });

    obdTest('K7 no codes stored: cleared, nothing logged', (h) {
      h.boot();
      h.connect();

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.cleared);
      expect(result.removed, isEmpty);
      expect(_logs(h), isEmpty);
    });

    obdTest('K8 not connected: nothing is cleared, nothing is written', (h) {
      h.boot();

      final result = _clear(h);

      expect(result.outcome, isNot(DtcClearOutcome.cleared));
      expect(
        h.finish(h.service.clearDtcCodes(),
            within: const Duration(seconds: 1)),
        isFalse,
      );
      expect(h.adapter.openCount, 0);
      expect(_logs(h), isEmpty);
    });

    obdTest('K9 simulator: injected codes are cleared and logged', (h) {
      h.boot();
      h.service.applySimulatorMode(true);
      h.service.configureSimulator(injectedDtcs: ['P0300']);
      h.seconds(3);
      expect(h.state.telemetry.dtcs, ['P0300']);

      final result = _clear(h);

      expect(result.outcome, DtcClearOutcome.cleared);
      expect(result.removed, ['P0300']);
      expect(h.state.telemetry.dtcs, isEmpty);
      expect(_logs(h).map((l) => l.code), ['P0300']);
      expect(h.adapter.openCount, 0);
      h.service.applySimulatorMode(false);
    });
  });
}
