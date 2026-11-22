// Case D: stray non-ASCII bytes from clone adapters never cost the `>` prompt.
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D. non-ASCII bytes around the prompt', () {
    obdTest('D1 garbage before, inside and after the AT Z prompt chunk',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      final link = h.link;
      expect(link.sent, ['AT Z']);

      // Reset noise, then the banner with invalid UTF-8 in the same chunk as
      // the prompt, then a trailing stray byte.
      link.inject([0xFF, 0xFE, 0x00]);
      link.inject([
        0xC3,
        ...'\r\rELM327 v1.5'.codeUnits,
        0xFF,
        ...'\r\r'.codeUnits,
        0x80,
        ...'>'.codeUnits,
        0xFE,
      ]);
      link.inject([0xF8]);
      h.ms(600);

      expect(link.sent, ['AT Z', 'AT E0'], reason: 'prompt after AT Z lost');
      expect(h.status, ObdStatus.initializing);

      link.reply('OK');
      h.settle();
      link.reply('OK');
      h.settle();
      link.reply('41 00 BE 3F B8 13');
      h.settle();
      expect(h.status, ObdStatus.connected);
      expect(h.state.errorMessage, isNull);
    });

    obdTest('D1b a lone invalid byte in the prompt chunk of every init step',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      final link = h.link;

      link.inject([...'ELM327 v1.5\r\r'.codeUnits, 0xFF, 0x3E]);
      h.ms(600);
      link.inject([0x9D, ...'OK\r\r>'.codeUnits]);
      h.settle();
      link.inject([...'OK\r'.codeUnits, 0xE2, 0x82, ...'\r>'.codeUnits]);
      h.settle();
      link.inject([...'41 00 BE 3F B8 13\r\r>'.codeUnits, 0xFF]);
      h.settle();

      expect(link.sent, [...initCommands, 'AT RV']);
      expect(h.status, ObdStatus.connected);
    });

    obdTest('D2 invalid bytes inside a poll answer: value parsed, poll goes on',
        autoReply: false, (h) {
      h.boot();
      h.startConnect();
      final link = h.link;
      h.answerInit(link);
      expect(link.sent.last, 'AT RV');

      // The answer arrives in two chunks, each with bytes UTF-8 rejects.
      link.inject([0xFF, ...'12'.codeUnits]);
      link.inject([...'.6V'.codeUnits, 0x80, ...'\r\r'.codeUnits, 0xC0, 0x3E]);
      h.settle();

      expect(h.state.telemetry.voltage, 12.6);
      expect(link.sent.last, '010C');

      link.inject([...'41 0C 1A F8'.codeUnits, 0xFF, ...'\r\r>'.codeUnits]);
      h.settle();
      expect(h.state.telemetry.rpm, 1726);
      expect(link.sent.last, '010D');
    });

    obdTest('D3 a chunk of garbage only changes nothing', autoReply: false,
        (h) {
      h.boot();
      h.startConnect();
      final link = h.link;
      h.answerInit(link);
      final before = h.state;

      link.inject([0xFF, 0x80, 0x00, 0x1B, 0x7F]);
      h.settle();

      expect(link.sent.last, 'AT RV');
      expect(identical(h.state, before), isTrue);
      expect(h.status, ObdStatus.connected);

      link.reply('12.4V');
      h.settle();
      expect(h.state.telemetry.voltage, 12.4);
    });
  });
}
