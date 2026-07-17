import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/obd/obd_parser.dart';
import 'package:autocare/core/obd/obd_telemetry.dart';
import 'package:autocare/features/health/domain/health_engine.dart';

void main() {
  group('ObdParser Tests', () {
    test('Parse Voltage - normal value', () {
      expect(ObdParser.parseVoltage('13.8V'), 13.8);
      expect(ObdParser.parseVoltage('12.4V\r>'), 12.4);
    });

    test('Parse RPM - standard payload', () {
      // 41 0C 0B B8 -> RPM = ((0x0B * 256) + 0xB8) / 4 = ((11 * 256) + 184) / 4 = (2816 + 184) / 4 = 3000 / 4 = 750
      expect(ObdParser.parseRpm('41 0C 0B B8'), 750.0);
    });

    test('Parse Speed - standard payload', () {
      // 41 0D 32 -> Speed = 0x32 = 50 km/h
      expect(ObdParser.parseSpeed('41 0D 32'), 50.0);
    });

    test('Parse Coolant - standard payload', () {
      // 41 05 5A -> Coolant = 0x5A - 40 = 90 - 40 = 50 C
      expect(ObdParser.parseCoolant('41 05 5A'), 50.0);
    });

    test('Parse MAP - standard payload', () {
      // 41 0B 64 -> MAP = 0x64 = 100 kPa
      expect(ObdParser.parseMap('41 0B 64'), 100.0);
    });

    test('Parse DTC - empty and multiple faults', () {
      expect(ObdParser.parseDtc('43 00 00 00 00'), isEmpty);
      
      // 43 02 01 38 01 15 -> P0138 and P0115
      final dtcs = ObdParser.parseDtc('43 02 01 38 01 15');
      expect(dtcs, containsAll(['P0138', 'P0115']));
    });
  });

  group('HealthEngine Tests', () {
    test('Perfect health with normal inputs', () {
      final telemetry = ObdTelemetry(
        rpm: 800,
        speed: 0,
        coolant: 90,
        voltage: 14.0,
        mapValue: 35,
        throttle: 5,
        engineLoad: 15,
        dtcs: const [],
        fuelLevel: 80.0,
        timestamp: DateTime.now(),
      );

      final report = HealthEngine.calculate(
        telemetry,
        nextOilOdometer: 165000,
        currentOdometer: 160000,
      );

      expect(report.score, 100);
      expect(report.statusTitle, contains('PRIMA'));
      expect(report.warnings, isEmpty);
    });

    test('Reduced health with high coolant temperature', () {
      final telemetry = ObdTelemetry(
        rpm: 2000,
        speed: 50,
        coolant: 108, // Warning threshold (>105)
        voltage: 14.0,
        mapValue: 40,
        throttle: 15,
        engineLoad: 30,
        dtcs: const [],
        fuelLevel: 50.0,
        timestamp: DateTime.now(),
      );

      final report = HealthEngine.calculate(telemetry);

      expect(report.score, 85); // 100 - 15 = 85
      expect(report.warnings, contains(contains('Suhu mesin di atas batas normal')));
    });

    test('Severe health drop with check engine DTC', () {
      final telemetry = ObdTelemetry(
        rpm: 800,
        speed: 0,
        coolant: 90,
        voltage: 14.0,
        mapValue: 35,
        throttle: 5,
        engineLoad: 15,
        dtcs: const ['P0138'], // Active check engine code
        fuelLevel: 100.0,
        timestamp: DateTime.now(),
      );

      final report = HealthEngine.calculate(telemetry);

      expect(report.score, 80); // 100 - 20 = 80
      expect(report.warnings, contains(contains('Trouble Code [P0138]')));
    });
  });
}
