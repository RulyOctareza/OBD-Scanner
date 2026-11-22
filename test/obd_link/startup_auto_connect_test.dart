// Case E, startup auto-connect: the attempt 3 s after app start obeys the
// "Sambung otomatis" switch and a manual Batal or Putus (defects F1 and F2,
// fixed in fcabdeb).
import 'dart:async';

import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _saved = '00:00:00:00:00:0A';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E. startup auto-connect rules', () {
    obdTest(
      'F1 "Sambung otomatis" off: no auto-connect at app start',
      savedAddress: _saved,
      prefs: {'auto_connect_obd': 'false'},
      (h) {
        h.service;
        h.seconds(10);
        expect(h.adapter.openCount, 0);
        expect(h.status, ObdStatus.disconnected);
      },
    );

    obdTest(
      'F2 Batal in the first 3 s is not undone by the startup auto-connect',
      savedAddress: _saved,
      (h) {
        h.adapter.onOpen = (address, newLink) => Completer<ObdLink>().future;
        h.service;
        h.seconds(1);
        h.startConnect(deviceA);
        h.service.cancelConnect();
        expect(h.status, ObdStatus.disconnected);

        h.seconds(10);
        expect(h.status, ObdStatus.disconnected);
      },
    );

    obdTest(
      'F2b Putus in the first 3 s is not undone by the startup auto-connect',
      savedAddress: _saved,
      (h) {
        h.service;
        h.ms(500);
        h.connect(deviceA);
        h.service.disconnect();

        h.seconds(10);
        expect(h.status, ObdStatus.disconnected);
        expect(h.adapter.openCount, 1);
      },
    );
  });
}
