import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/utils/usefulness_utils.dart';

void main() {
  group('formatDtcReport', () {
    test('includes active and pending codes', () {
      final report = formatDtcReport(
        DiagnosticScanResult(
          protocol: 'ISO 15765-4',
          vin: 'TESTVIN123',
          milStatus: true,
          dtcCount: 2,
          supportedSensorsCount: 10,
          activeDtcs: const ['P0300'],
          pendingDtcs: const ['P0171'],
          permanentDtcs: const [],
          imReadiness: const {'misfire': true},
          scanTimestamp: DateTime.utc(2026, 7, 20, 12),
        ),
      );

      expect(report, contains('Laporan Diagnostik AutoCare'));
      expect(report, contains('P0300'));
      expect(report, contains('P0171'));
      expect(report, contains('VIN: TESTVIN123'));
      expect(report, contains('MIL: ON'));
    });
  });

  group('warningActionRoute', () {
    test('routes coolant warnings to meter', () {
      expect(
        warningActionRoute('Suhu coolant kritis (115°C). Matikan mesin segera!'),
        '/dashboard',
      );
    });

    test('routes DTC warnings to diagnostics', () {
      expect(
        warningActionRoute('Trouble Code [P0300]: Misfire (High)'),
        '/diagnostics',
      );
    });

    test('routes oil warnings to timeline', () {
      expect(
        warningActionRoute('Oli mesin melewati batas ganti! Segera ganti oli.'),
        '/timeline',
      );
    });
  });
}
