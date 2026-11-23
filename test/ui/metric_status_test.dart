import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/core/ui/metric_status.dart';
import 'package:autocare/core/ui/status.dart';
import 'package:autocare/core/widgets/live_obd.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coolant', () {
    test('bands match the health score deductions', () {
      expect(assessCoolant(0).level, StatusLevel.noData);
      expect(assessCoolant(90), const MetricAssessment(StatusLevel.ok, 'Normal'));
      expect(assessCoolant(100).level, StatusLevel.ok);
      expect(assessCoolant(101),
          const MetricAssessment(StatusLevel.waspada, 'Hangat'));
      expect(assessCoolant(105).note, 'Hangat');
      expect(assessCoolant(108),
          const MetricAssessment(StatusLevel.waspada, 'Tinggi'));
      expect(assessCoolant(115).note, 'Tinggi');
      expect(assessCoolant(116),
          const MetricAssessment(StatusLevel.kritis, 'Sangat tinggi'));
    });
  });

  group('voltage', () {
    test('depends on whether the engine runs', () {
      expect(assessVoltage(12.5, engineRunning: true),
          const MetricAssessment(StatusLevel.waspada, 'Pengisian lemah'));
      expect(assessVoltage(13.9, engineRunning: true).level, StatusLevel.ok);
      expect(assessVoltage(12.5, engineRunning: false).level, StatusLevel.ok);
      expect(assessVoltage(11.7, engineRunning: false),
          const MetricAssessment(StatusLevel.waspada, 'Aki lemah'));
      expect(assessVoltage(0, engineRunning: true).level, StatusLevel.noData);
    });

    test('engine runs above 500 rpm', () {
      expect(isEngineRunning(0), isFalse);
      expect(isEngineRunning(500), isFalse);
      expect(isEngineRunning(780), isTrue);
    });
  });

  test('fuel level', () {
    expect(assessFuelLevel(6),
        const MetricAssessment(StatusLevel.kritis, 'Hampir habis'));
    expect(assessFuelLevel(10),
        const MetricAssessment(StatusLevel.waspada, 'Menipis'));
    expect(assessFuelLevel(50).level, StatusLevel.ok);
  });

  test('metrics without a health meaning are always ok', () {
    expect(assessMetric(ObdMetricType.speed, 180).level, StatusLevel.ok);
    expect(assessMetric(ObdMetricType.rpm, 6500).level, StatusLevel.ok);
  });

  test('a reading without a value is never judged as normal', () {
    const pending = MetricReading(value: 0, isPending: true);
    const unsupported = MetricReading(value: 0, isUnsupported: true);
    expect(assessReading(ObdMetricType.coolant, pending).level,
        StatusLevel.noData);
    expect(assessReading(ObdMetricType.speed, pending).level,
        StatusLevel.noData);
    expect(assessReading(ObdMetricType.coolant, unsupported).level,
        StatusLevel.unsupported);
    expect(
      assessReading(ObdMetricType.voltage, const MetricReading(value: 12.5),
              engineRunning: true)
          .level,
      StatusLevel.waspada,
    );
  });
}
