import 'package:autocare/core/obd/obd_telemetry.dart';
import 'package:autocare/features/health/domain/health_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = ObdTelemetry.empty().copyWith(
    rpm: 800,
    speed: 0,
    coolant: 90,
    voltage: 14.1,
  );

  test('same inputs give equal reports, so healthProvider does not notify', () {
    final a = HealthEngine.calculate(base);
    final b = HealthEngine.calculate(
      base.copyWith(timestamp: DateTime(2030), rpm: 2500, speed: 60),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a changed check gives a different report', () {
    final ok = HealthEngine.calculate(base);
    final hot = HealthEngine.calculate(base.copyWith(coolant: 118));
    expect(ok == hot, isFalse);
  });

  test('CheckItem compares by value', () {
    expect(
      CheckItem(title: 'Aki', isOk: true, detail: '14.1 V'),
      CheckItem(title: 'Aki', isOk: true, detail: '14.1 V'),
    );
    expect(
      CheckItem(title: 'Aki', isOk: true, detail: '14.1 V') ==
          CheckItem(title: 'Aki', isOk: false, detail: '14.1 V'),
      isFalse,
    );
  });
}
