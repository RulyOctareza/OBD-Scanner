import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/utils/performance_utils.dart';
import 'package:autocare/features/live_data/presentation/telemetry_provider.dart';

void main() {
  group('isValidChartMetricValue', () {
    test('rejects zero coolant as empty/init data', () {
      expect(isValidChartMetricValue('coolant', 0), isFalse);
      expect(isValidChartMetricValue('coolant', 77), isTrue);
    });

    test('allows zero rpm and speed', () {
      expect(isValidChartMetricValue('rpm', 0), isTrue);
      expect(isValidChartMetricValue('speed', 0), isTrue);
    });

    test('rejects near-zero voltage', () {
      expect(isValidChartMetricValue('voltage', 0), isFalse);
      expect(isValidChartMetricValue('voltage', 12.4), isTrue);
    });
  });

  group('computeChartYBounds', () {
    test('expands flat series using metric full scale', () {
      final bounds = computeChartYBounds(
        minValue: 3131,
        maxValue: 3131,
        metricMin: 0,
        metricMax: 8000,
      );
      expect(bounds.maxY - bounds.minY, greaterThan(500));
      expect(bounds.minY, lessThan(3131));
      expect(bounds.maxY, greaterThan(3131));
    });

    test('coolant band stays elevated without zero floor', () {
      final bounds = computeChartYBounds(
        minValue: 65,
        maxValue: 88,
        metricMin: 50,
        metricMax: 130,
      );
      expect(bounds.minY, greaterThan(40));
      expect(bounds.maxY, lessThan(140));
      expect(bounds.minY, lessThan(65));
      expect(bounds.maxY, greaterThan(88));
    });
  });
}
