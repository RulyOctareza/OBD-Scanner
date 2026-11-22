import 'package:autocare/core/bluetooth/obd_link.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/dev/fake_elm327.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const deviceA = BluetoothDevice(address: '00:00:00:00:00:0A', name: 'OBDII');
const deviceB = BluetoothDevice(address: '00:00:00:00:00:0B', name: 'V-LINK');

const initCommands = ['AT Z', 'AT E0', 'AT SP 0', '0100'];

/// One [ObdService] on a fake adapter, with time under the test's control.
class ObdHarness {
  ObdHarness._(this.async, this.adapter, this.db, this.container);

  final FakeAsync async;
  final FakeElm327Connector adapter;
  final AppDatabase db;
  final ProviderContainer container;

  ObdService get service => container.read(obdServiceProvider.notifier);
  ObdState get state => container.read(obdServiceProvider);
  ObdStatus get status => state.status;
  List<FakeElm327Link> get links => adapter.links;
  FakeElm327Link get link => adapter.links.last;

  void elapse(Duration duration) => async.elapse(duration);
  void ms(int milliseconds) => elapse(Duration(milliseconds: milliseconds));
  void seconds(int seconds) => elapse(Duration(seconds: seconds));

  /// Lets pending microtasks and zero-delay timers run.
  void settle() => ms(1);

  /// Creates the service and lets its startup auto-connect window (3 s) pass.
  /// With no saved adapter that auto-connect does nothing.
  ///
  /// Settings are loaded too, as in the running app: the settings notifier
  /// applies the stored simulator preference to the service once it has
  /// loaded, which would otherwise happen in the middle of a test.
  void boot() {
    service;
    container.read(settingsProvider);
    seconds(4);
    expect(container.read(settingsProvider).isLoaded, isTrue);
  }

  /// Like [boot], but with the adapter reported as not ready during the
  /// startup window, so the startup auto-connect does not use a saved adapter.
  void bootWithoutStartupConnect() {
    adapter.ready = false;
    boot();
    adapter.ready = true;
    expect(adapter.openCount, 0);
  }

  /// Starts a connect and returns without waiting for it.
  void startConnect([BluetoothDevice device = deviceA, int maxRetries = 2]) {
    service.connectToDevice(device, maxRetries: maxRetries);
    settle();
  }

  /// Connects through an auto-replying adapter and checks the link is up.
  FakeElm327Link connect([BluetoothDevice device = deviceA]) {
    startConnect(device);
    seconds(2);
    expect(status, ObdStatus.connected, reason: 'connect did not finish');
    return link;
  }

  /// Answers the init sequence by hand on a silent link.
  void answerInit(FakeElm327Link link) {
    link.reply('ELM327 v1.5');
    ms(600); // 500 ms settle after AT Z
    link.reply('OK'); // AT E0
    settle();
    link.reply('OK'); // AT SP 0
    settle();
    link.reply('41 00 BE 3F B8 13'); // 0100
    settle();
  }

  /// Reads a preference from the database.
  String? pref(String key) {
    String? value;
    db.getPreference(key).then((v) => value = v);
    settle();
    return value;
  }

  /// Runs [future] to completion under fake time and returns its value.
  T finish<T>(Future<T> future, {Duration within = const Duration(seconds: 60)}) {
    T? value;
    Object? error;
    var done = false;
    future.then(
      (v) {
        value = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    elapse(within);
    expect(done, isTrue, reason: 'future did not complete within $within');
    if (error != null) throw error!;
    return value as T;
  }
}

/// Counts commands that are on the wire at the moment each answer leaves the
/// adapter. The ELM327 cannot multiplex, so that count must always be one.
class SingleFlightProbe {
  SingleFlightProbe(this.adapter) {
    adapter.responder = (command) {
      final link = adapter.links.last;
      final answered = _answered[link] ?? 0;
      final outstanding = link.sent.length - answered;
      if (outstanding != 1) {
        violations.add(
          '$outstanding commands outstanding when "$command" was answered: '
          '${link.sent.sublist(answered)}',
        );
      }
      _answered[link] = answered + 1;
      return null;
    };
  }

  final FakeElm327Connector adapter;
  final Map<FakeElm327Link, int> _answered = {};
  final List<String> violations = [];
}

/// Declares a test that runs [body] inside fake time with a fresh harness.
///
/// [savedAddress] seeds the adapter remembered for auto-connect, [prefs] any
/// other preference, before the service is created. [skip] names an open
/// defect the test proves; `flutter test --run-skipped` runs it anyway.
/// [reconnectTimer] turns on the periodic auto-reconnect check.
void obdTest(
  String description,
  void Function(ObdHarness h) body, {
  bool autoReply = true,
  Duration latency = const Duration(milliseconds: 20),
  String? savedAddress,
  Map<String, String> prefs = const {},
  bool reconnectTimer = false,
  String? skip,
}) {
  test(description, skip: skip, () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final adapter = FakeElm327Connector(
        latency: latency,
        autoReply: autoReply,
      );
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          obdLinkConnectorProvider.overrideWithValue(adapter),
          // Off under flutter test unless a test asks for it.
          obdAutoReconnectTimerProvider.overrideWithValue(reconnectTimer),
        ],
      );
      final h = ObdHarness._(async, adapter, db, container);

      final seed = {
        if (savedAddress != null) ...{
          'last_obd_device_address': savedAddress,
          'last_obd_device_name': 'OBDII',
        },
        ...prefs,
      };
      for (final entry in seed.entries) {
        db.setPreference(entry.key, entry.value);
      }
      h.settle();

      try {
        body(h);
      } finally {
        container.dispose();
        db.close();
        async.elapse(const Duration(seconds: 1));
      }
    });
  });
}

/// An `onOpen` handler that opens at once and lets the test shape each link
/// before the service sees it.
Future<ObdLink> Function(String, FakeElm327Link Function()) openWith(
  void Function(FakeElm327Link link, int index) configure,
) {
  var index = 0;
  return (address, newLink) {
    final link = newLink();
    configure(link, index++);
    return Future.value(link);
  };
}
