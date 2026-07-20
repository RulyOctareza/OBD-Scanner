import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/obd/obd_parser.dart';
import 'package:autocare/features/diagnostics/data/dtc_repository.dart';

void main() {
  group('Diagnostic ObdParser Extensions', () {
    test('Parse Pending DTC (Mode 07)', () {
      // 47 01 03 00 -> P0300 (Pending)
      final pending = ObdParser.parsePendingDtc('47 01 03 00');
      expect(pending, contains('P0300'));
    });

    test('Parse Permanent DTC (Mode 0A)', () {
      // 4A 01 01 71 -> P0171 (Permanent)
      final permanent = ObdParser.parsePermanentDtc('4A 01 01 71');
      expect(permanent, contains('P0171'));
    });

    test('Parse I/M Readiness (Mode 01 PID 01)', () {
      // 41 01 82 00 00 00 -> MIL on (0x82 & 0x80 != 0), 2 DTCs, tests ready
      final readiness = ObdParser.parseImReadiness('41 01 82 00 00 00');
      expect(readiness, isNotNull);
      expect(readiness!['mil'], isTrue);
      expect(readiness['misfire'], isTrue);
      expect(readiness['fuelSystem'], isTrue);
    });
  });

  group('DtcRepository Tests', () {
    test('Get Known DTC Info', () {
      final dtc = DtcRepository.getCodeInfo('P0300');
      expect(dtc.code, 'P0300');
      expect(dtc.category, 'Powertrain');
      expect(dtc.symptoms, isNotEmpty);
      expect(dtc.possibleCauses, isNotEmpty);
      expect(dtc.recommendations, isNotEmpty);
    });

    test('Get Unknown DTC Fallback Info', () {
      final dtc = DtcRepository.getCodeInfo('P9999');
      expect(dtc.code, 'P9999');
      expect(dtc.category, 'Powertrain');
      expect(dtc.title, contains('P9999'));
    });

    test('Search DTC Codes by Query', () {
      final results = DtcRepository.searchCodes('misfire');
      expect(results, isNotEmpty);
      expect(results.any((d) => d.code == 'P0300'), isTrue);
    });

    test('Filter DTC Codes by Category', () {
      final chassisCodes = DtcRepository.searchCodes('', categoryFilter: 'Chassis');
      expect(chassisCodes, isNotEmpty);
      expect(chassisCodes.every((d) => d.category == 'Chassis'), isTrue);
    });
  });
}
