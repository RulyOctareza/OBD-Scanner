// Case A: "Putus" ends in disconnected, and a closed link's late onDone never
// touches the state or the link that replaced it.
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A. disconnect and stale onDone', () {
    obdTest('A1 Putus ends in disconnected, also after the late onDone', (h) {
      h.adapter.onOpen = openWith((link, _) => link.deferCloseOnDispose = true);
      h.boot();
      final link = h.connect();

      h.service.disconnect();
      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(h.state.errorHelp, isNull);
      expect(link.disposeCount, 1);

      // The plugin delivers onDone some time after dispose().
      h.seconds(1);
      link.finishClose();
      h.seconds(1);

      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(link.disposeCount, 1);
    });

    obdTest('A1b Putus ends in disconnected when onDone arrives at once', (h) {
      h.boot();
      final link = h.connect();
      final written = link.sent.length;

      h.service.disconnect();
      h.seconds(5);

      expect(h.status, ObdStatus.disconnected);
      expect(h.state.errorMessage, isNull);
      expect(link.disposeCount, 1);
      expect(link.sent.length, written, reason: 'polling went on after Putus');
    });

    obdTest('A2 stale onDone of the old link leaves the new link alone', (h) {
      h.adapter.onOpen = openWith((link, _) => link.deferCloseOnDispose = true);
      h.boot();
      final first = h.connect();
      h.service.disconnect();

      final second = h.connect();
      expect(second, isNot(same(first)));

      first.finishClose();
      h.settle();
      final written = second.sent.length;
      h.seconds(2);

      expect(h.status, ObdStatus.connected);
      expect(h.state.errorMessage, isNull);
      expect(second.disposeCount, 0);
      expect(second.sent.length, greaterThan(written), reason: 'polling stopped');
    });

    obdTest('A3 stale onDone of a failed attempt does not kill the retry', (h) {
      // Attempt 1 opens a link that never answers, attempt 2 a healthy one.
      h.adapter.latency = const Duration(milliseconds: 200);
      h.adapter.onOpen = openWith((link, index) {
        link.deferCloseOnDispose = true;
        link.autoReply = index > 0;
      });
      h.boot();
      h.startConnect();
      final first = h.link;

      // AT Z times out twice (5 s each, 300 ms apart), then 2 s before retry.
      h.seconds(13);
      expect(h.links.length, 2);
      expect(first.disposeCount, 1);
      final second = h.link;
      expect(h.status, ObdStatus.initializing);

      first.finishClose();
      h.seconds(3);

      expect(h.status, ObdStatus.connected);
      expect(second.disposeCount, 0);
      expect(second.sent.take(4), initCommands);
    });

    obdTest('A5 adapter closing the live link ends in error "terputus"', (h) {
      h.boot();
      final link = h.connect();

      link.closeFromAdapter();
      h.settle();
      final written = link.sent.length;
      h.seconds(5);

      expect(h.status, ObdStatus.error);
      expect(h.state.errorMessage, contains('terputus'));
      expect(h.state.errorHelp, isNotNull);
      expect(link.disposeCount, 1);
      expect(link.sent.length, written);
      expect(h.adapter.openCount, 1);
    });

    obdTest('A6 adapter closing the link during init triggers the retry', (h) {
      h.adapter.onOpen = openWith((link, index) => link.autoReply = index > 0);
      h.boot();
      h.startConnect();
      final first = h.link;
      expect(h.status, ObdStatus.initializing);

      first.closeFromAdapter();
      h.seconds(1);
      expect(h.status, ObdStatus.connecting);
      expect(h.state.statusDetail, contains('Percobaan 1 dari 2 gagal'));

      h.seconds(4);
      expect(h.status, ObdStatus.connected);
      expect(h.adapter.openCount, 2);
      expect(first.disposeCount, 1);
    });

    obdTest('A7 Putus then connect again five times stays clean', (h) {
      h.adapter.onOpen = openWith((link, _) => link.deferCloseOnDispose = true);
      h.boot();
      for (var round = 0; round < 5; round++) {
        final link = h.connect();
        h.service.disconnect();
        expect(h.status, ObdStatus.disconnected);
        // Every older link reports its close late, in the middle of the next
        // round.
        h.ms(300);
        link.finishClose();
        h.settle();
        expect(h.state.errorMessage, isNull);
      }
      expect(h.adapter.openCount, 5);
      expect(h.links.map((l) => l.disposeCount), everyElement(1));
    });
  });
}
