import 'package:autocare/core/obd/obd_simulator.dart';
import 'package:autocare/core/obd/obd_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('out-of-band emits do not advance odometer or fuel', () async {
    final sim = ObdSimulator();
    final emitted = <ObdTelemetry>[];
    final sub = sim.telemetryStream.listen(emitted.add);

    // A tick interval far longer than the test, so only out-of-band emits run.
    sim.start(intervalMs: 3600 * 1000);
    sim.configure(isEngineRunning: true, hasHighTemp: true);
    sim.injectDtc('P0138');
    sim.clearDtcs();
    await Future<void>.delayed(Duration.zero);

    sim.stop();
    await sub.cancel();

    expect(emitted, hasLength(4));
    for (final t in emitted) {
      expect(t.odometer, 161420.0);
      expect(t.fuelLevel, 72.5);
    }
  });

  test('timer ticks advance odometer while driving', () async {
    final sim = ObdSimulator();
    final emitted = <ObdTelemetry>[];
    final sub = sim.telemetryStream.listen(emitted.add);

    sim.start(intervalMs: 20);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    sim.stop();
    await sub.cancel();

    expect(emitted.first.odometer, 161420.0);
    expect(emitted.last.odometer!, greaterThan(161420.0));
  });
}
