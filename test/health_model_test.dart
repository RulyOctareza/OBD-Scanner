import 'package:autocare/core/obd/obd_telemetry.dart';
import 'package:autocare/core/ui/status.dart';
import 'package:autocare/features/health/domain/health_engine.dart';
import 'package:flutter_test/flutter_test.dart';

ObdTelemetry _live({
  double rpm = 800,
  double speed = 0,
  double coolant = 90,
  double voltage = 14.0,
  List<String> dtcs = const [],
}) =>
    ObdTelemetry.empty().copyWith(
      rpm: rpm,
      speed: speed,
      coolant: coolant,
      voltage: voltage,
      dtcs: dtcs,
    );

void main() {
  test('nothing measured: no score, never a healthy one', () {
    final report = HealthEngine.calculate(ObdTelemetry.empty());
    expect(report.score, isNull);
    expect(report.hasData, isFalse);
    expect(report.level, StatusLevel.noData);
    expect(report.statusTitle, 'Belum ada data');
    expect(report.checks.map((c) => c.level),
        everyElement(StatusLevel.noData));
  });

  test('codes not read yet are "Belum dipindai", never "no codes"', () {
    final unread = HealthEngine.calculate(_live());
    final dtc = unread.checks.singleWhere((c) => c.title == 'Kode kerusakan');
    expect(dtc.level, StatusLevel.noData);
    expect(dtc.detail, 'Belum dipindai');

    final read = HealthEngine.calculate(_live(), dtcsChecked: true);
    final none = read.checks.singleWhere((c) => c.title == 'Kode kerusakan');
    expect(none.level, StatusLevel.ok);
    expect(none.detail, 'Tidak ada kode');
  });

  test('checks are judged by the shared thresholds', () {
    final report = HealthEngine.calculate(_live(coolant: 108, voltage: 12.5));
    final coolant = report.checks.singleWhere((c) => c.title == 'Suhu mesin');
    final volts = report.checks.singleWhere((c) => c.title == 'Tegangan aki');
    expect(coolant.level, StatusLevel.waspada);
    expect(coolant.note, 'Tinggi');
    expect(volts.level, StatusLevel.waspada);
    expect(volts.note, 'Pengisian lemah');

    // Engine off: 12,5 V is a normal resting battery.
    final off = HealthEngine.calculate(_live(rpm: 0, voltage: 12.5));
    expect(off.checks.singleWhere((c) => c.title == 'Tegangan aki').level,
        StatusLevel.ok);
  });

  test('every warning kind leads to its screen', () {
    final cases = <HealthWarningKind, ObdTelemetry>{
      HealthWarningKind.coolant: _live(coolant: 118),
      HealthWarningKind.charging: _live(voltage: 12.4),
      HealthWarningKind.battery: _live(rpm: 0, voltage: 11.5),
      HealthWarningKind.dtc: _live(dtcs: ['P0300']),
      HealthWarningKind.idle: _live(rpm: 1400),
    };
    final routes = <HealthWarningKind, String>{
      HealthWarningKind.coolant: '/live_data',
      HealthWarningKind.charging: '/live_data',
      HealthWarningKind.battery: '/live_data',
      HealthWarningKind.dtc: '/diagnostics',
      HealthWarningKind.idle: '/live_data',
    };
    for (final entry in cases.entries) {
      final warning = HealthEngine.calculate(entry.value)
          .warnings
          .singleWhere((w) => w.kind == entry.key);
      expect(warning.action.route, routes[entry.key], reason: '${entry.key}');
    }

    final oil = HealthEngine.calculate(
      _live(),
      nextOilOdometer: 160000,
      currentOdometer: 160500,
    ).warnings.single;
    expect(oil.kind, HealthWarningKind.oilOverdue);
    expect(oil.action, HealthAction.openRiwayat);
    expect(oil.action.route, '/timeline');
  });

  test('oil reminder appears without a live link', () {
    final report = HealthEngine.calculate(
      ObdTelemetry.empty(),
      nextOilOdometer: 161000,
      currentOdometer: 160000,
    );
    expect(report.score, isNull);
    expect(report.warnings.single.kind, HealthWarningKind.oilDue);
  });

  test('critical warnings come first', () {
    final report = HealthEngine.calculate(
      _live(coolant: 118, dtcs: ['P0138']),
      nextOilOdometer: 161000,
      currentOdometer: 160000,
    );
    expect(report.warnings.first.level, StatusLevel.kritis);
    expect(report.warnings.last.level, StatusLevel.waspada);
  });

  test('score bands keep the deductions of the health book', () {
    expect(HealthEngine.calculate(_live()).score, 100);
    expect(HealthEngine.calculate(_live(coolant: 102)).score, 95);
    expect(HealthEngine.calculate(_live(coolant: 118)).score, 65);
    expect(HealthEngine.calculate(_live(dtcs: ['P0138', 'P0300'])).score, 60);
    expect(HealthEngine.calculate(_live(dtcs: ['P0138'])).level,
        StatusLevel.waspada);
    expect(HealthEngine.calculate(_live(dtcs: ['P0138', 'P0300'])).level,
        StatusLevel.kritis);
  });
}
