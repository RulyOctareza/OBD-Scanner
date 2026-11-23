// Case C: only one command is ever on the wire, through init, polling and the
// one-shot sequences (diagnostic scan, identity read, clear DTC).
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/dev/fake_elm327.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Connects, then silences the link so exactly one poll command is waiting
/// for its answer. Returns the link.
FakeElm327Link connectWithPollOutstanding(ObdHarness h) {
  final link = h.connect();
  link.autoReply = false;
  // The answer already scheduled arrives; the command after it gets none.
  h.ms(100);
  return link;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C. single flight', () {
    obdTest('C1 late answer to a timed-out init command starts no polling',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      final link = h.link;
      expect(link.sent, ['AT Z']);

      // AT Z times out after 5 s; its answer arrives in the 300 ms gap before
      // the second try, when nobody is waiting for a response.
      h.ms(5100);
      expect(link.sent, ['AT Z']);
      link.reply('ELM327 v1.5');
      h.ms(100);

      expect(link.sent, ['AT Z'], reason: 'late answer triggered a command');
      expect(h.status, ObdStatus.initializing);
      expect(h.state.checkedSensors, isEmpty);

      h.ms(200);
      expect(link.sent, ['AT Z', 'AT Z']);
      h.answerInit(link);
      expect(h.status, ObdStatus.connected);
      expect(link.sent, ['AT Z', 'AT Z', 'AT E0', 'AT SP 0', '0100', 'AT RV']);
    });

    obdTest('C1b late answer during the settle after AT Z is discarded',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      final link = h.link;
      link.reply('ELM327 v1.5');
      h.ms(100);
      // A clone repeats its banner while the chip is still resetting.
      link.reply('ELM327 v1.5');
      h.ms(600);
      expect(link.sent, ['AT Z', 'AT E0']);
      link.reply('OK');
      h.settle();
      expect(link.sent, ['AT Z', 'AT E0', 'AT SP 0']);
    });

    obdTest('C2 init then polling: never two commands without a prompt', (h) {
      final probe = SingleFlightProbe(h.adapter);
      h.boot();
      final link = h.connect();
      h.seconds(10);

      expect(probe.violations, isEmpty);
      expect(link.sent.take(5), [...initCommands, 'AT RV']);
      expect(link.sent.sublist(4, 16), [
        'AT RV',
        '010C',
        '010D',
        '0105',
        '010F',
        '010B',
        '0110',
        '010E',
        '0111',
        '0104',
        '01A6',
        '012F',
      ]);
      // Stored trouble codes are read once in the first cycle, so their state
      // is known about a second after connecting.
      expect(link.sent.sublist(16, 18), ['03', 'AT RV']);
    });

    obdTest('C2d mode 03 is polled in the first cycle, then every 20 cycles',
        (h) {
      final probe = SingleFlightProbe(h.adapter);
      h.boot();
      final link = h.connect();
      h.seconds(12);

      final dtcPolls = [
        for (var i = 0; i < link.sent.length; i++)
          if (link.sent[i] == '03') i,
      ];
      // 4 init commands, cycle 0 with 12 PIDs + 03, cycles 1 to 19 with 12
      // PIDs, cycle 20 with 12 PIDs + 03.
      const firstCycle = 4 + 12;
      const twentiethCycle = firstCycle + 1 + 19 * 12 + 12;
      expect(dtcPolls.take(2), [firstCycle, twentiethCycle]);
      expect(dtcPolls.length, lessThanOrEqualTo(3));
      expect(link.sent.length, greaterThan(twentiethCycle + 1));
      expect(probe.violations, isEmpty);
    });

    obdTest('C2e a one-shot sequence does not restart the mode 03 schedule',
        (h) {
      h.boot();
      final link = h.connect();
      h.seconds(1);
      h.finish(
        h.service.performFullDiagnosticScan(),
        within: const Duration(seconds: 3),
      );
      final resumed = link.sent.lastIndexOf('0101') + 1;
      h.seconds(1);

      // Two full cycles after the scan: live PIDs only. The scan has just
      // read the trouble codes itself.
      final afterScan = link.sent.sublist(resumed, resumed + 24);
      expect(afterScan.first, 'AT RV');
      expect(afterScan, isNot(contains('03')));
    });

    obdTest('C2b no poll command is written before init has finished',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      final link = h.link;
      link.reply('ELM327 v1.5');
      h.ms(600);
      link.reply('OK');
      h.settle();
      link.reply('OK');
      h.settle();
      expect(link.sent, initCommands);

      // Protocol search on a K-line car: seconds of SEARCHING before the
      // answer. The poll watchdog must not send anything into it.
      for (var i = 0; i < 6; i++) {
        link.inject('SEARCHING...'.codeUnits);
        h.seconds(2);
      }
      expect(link.sent, initCommands);
      expect(h.status, ObdStatus.initializing);
      expect(h.state.statusDetail, 'Mendeteksi protokol mobil…');

      link.reply('41 00 BE 3F B8 13');
      h.settle();
      expect(h.status, ObdStatus.connected);
      expect(link.sent.last, 'AT RV');
    });

    obdTest('C2c ignition off: silent 0100 warm-up still connects', (h) {
      h.adapter.responder = (command) => null;
      h.adapter.onOpen = openWith((link, _) => link.autoReply = false);
      h.boot();
      h.startConnect();
      final link = h.link;
      link.reply('ELM327 v1.5');
      h.ms(600);
      link.reply('OK');
      h.settle();
      link.reply('OK');
      h.settle();

      h.seconds(14);
      expect(h.status, ObdStatus.initializing);
      h.seconds(2);
      expect(h.status, ObdStatus.connected);
      expect(link.sent, [...initCommands, 'AT RV']);
    });

    obdTest('C3 scan waits for the poll answer already on the wire', (h) {
      h.boot();
      final link = connectWithPollOutstanding(h);
      final written = link.sent.length;
      final pollCommand = link.sent.last;

      final scan = h.service.performFullDiagnosticScan();
      h.seconds(1);
      expect(link.sent.length, written, reason: 'one-shot sent over $pollCommand');

      // The poll answer arrives; only then may AT DP go out.
      link.reply('41 0C 1A F8');
      h.ms(100);
      expect(link.sent.length, written + 1);
      expect(link.sent.last, 'AT DP');

      link.reply('ISO 9141-2');
      link.autoReply = true;
      final result = h.finish(scan);

      expect(result.protocol, 'ISO 9141-2', reason: 'AT DP got the poll answer');
      expect(result.vin, 'MHKM1502XK0198421');
      expect(link.sent.sublist(written), containsAllInOrder(
        ['AT DP', '0902', '01A6', '0100', '03', '07', '0A', '0101', 'AT RV'],
      ));
      expect(h.status, ObdStatus.connected);
    });

    obdTest('C3b scan starts after 3 s when the poll answer never comes', (h) {
      h.boot();
      final link = connectWithPollOutstanding(h);
      final written = link.sent.length;

      final scan = h.service.performFullDiagnosticScan();
      h.ms(2900);
      expect(link.sent.length, written);
      h.ms(300);
      expect(link.sent.last, 'AT DP');
      expect(link.sent.length, written + 1);

      link.reply('ISO 9141-2');
      link.autoReply = true;
      expect(h.finish(scan).protocol, 'ISO 9141-2');
    });

    obdTest('C4 scan, identity and clear DTC run one after the other', (h) {
      final probe = SingleFlightProbe(h.adapter);
      h.adapter.dtcs = const ['0133'];
      h.boot();
      final link = h.connect();
      h.seconds(1);
      final written = link.sent.length;

      final scan = h.service.performFullDiagnosticScan();
      final identity = h.service.fetchVehicleIdentity();
      final clear = h.service.clearDtcCodes();
      h.seconds(10);

      expect(probe.violations, isEmpty);
      final oneShots = link.sent
          .sublist(written)
          .where((c) => !pollCommands.contains(c) || c == '01A6')
          .toList();
      // 01A6 is both a poll PID and part of scan and identity, so the exact
      // order of the one-shot commands is checked on the raw log instead.
      expect(oneShots, containsAllInOrder(
        ['AT DP', '0902', '01A6', '0100', '03', '07', '0A', '0101'],
      ));
      final log = link.sent.sublist(written);
      final scanStart = log.indexOf('AT DP');
      expect(log.sublist(scanStart, scanStart + 8), [
        'AT DP',
        '0902',
        '01A6',
        '0100',
        '03',
        '07',
        '0A',
        '0101',
      ]);
      final identityStart = log.indexOf('0902', scanStart + 8);
      expect(identityStart, greaterThan(scanStart));
      expect(log.sublist(identityStart, identityStart + 2), ['0902', '01A6']);
      final clearAt = log.indexOf('04', identityStart);
      expect(clearAt, greaterThan(identityStart));

      expect(h.finish(scan).activeDtcs, ['P0133']);
      expect(h.finish(identity).vin, 'MHKM1502XK0198421');
      expect(h.finish(clear), isTrue);
      expect(h.state.telemetry.dtcs, isEmpty);

      // Polling runs again afterwards.
      final after = link.sent.length;
      h.seconds(2);
      expect(link.sent.length, greaterThan(after + 10));
      expect(probe.violations, isEmpty);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('C4b identity read is refused while init owns the link',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      expect(h.status, ObdStatus.initializing);

      final result = h.finish(h.service.fetchVehicleIdentity(),
          within: const Duration(milliseconds: 100));
      expect(result.success, isFalse);
      expect(h.link.sent, ['AT Z']);
    });

    obdTest('C5 SEARCHING counts as activity; a silent PID is skipped once',
        (h) {
      h.boot();
      final link = connectWithPollOutstanding(h);
      final written = link.sent.length;
      final stuck = link.sent.last;

      for (var i = 0; i < 5; i++) {
        link.inject('SEARCHING...'.codeUnits);
        h.seconds(2);
      }
      expect(link.sent.length, written, reason: 'watchdog cut into a search');

      // The 1 s watchdog skips a command after more than 3 s of silence, so
      // the skips fall 3 to 4 s apart. 4.5 s after the last byte: one skip.
      h.ms(2500);
      expect(link.sent.length, written + 1);
      expect(link.sent.last, isNot(stuck), reason: 'silent PID was re-sent');

      // 8.5 s after the last byte: exactly two.
      h.seconds(4);
      expect(link.sent.length, written + 2);
      expect(link.sent.last, isNot(link.sent[written]));
      expect(h.status, ObdStatus.connected);
    });

    obdTest('C6 link lost during a scan: scan returns, nothing is written', (h) {
      h.boot();
      final link = connectWithPollOutstanding(h);
      final scan = h.service.performFullDiagnosticScan();
      h.ms(500);

      link.closeFromAdapter();
      final result = h.finish(scan);

      expect(h.status, ObdStatus.error);
      expect(result.activeDtcs, isEmpty);
      expect(h.adapter.openCount, 1);
    });
  });
}

const pollCommands = [
  'AT RV',
  '010C',
  '010D',
  '0105',
  '010F',
  '010B',
  '0110',
  '010E',
  '0111',
  '0104',
  '01A6',
  '012F',
];
