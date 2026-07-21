import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/utils/performance_utils.dart';

void main() {
  group('shouldAnimateGaugeValue', () {
    test('skips tiny deltas within 0.5% of span', () {
      expect(
        shouldAnimateGaugeValue(
          previous: 1000,
          next: 1020,
          minValue: 0,
          maxValue: 8000,
        ),
        isFalse,
      );
    });

    test('animates meaningful deltas', () {
      expect(
        shouldAnimateGaugeValue(
          previous: 1000,
          next: 1500,
          minValue: 0,
          maxValue: 8000,
        ),
        isTrue,
      );
    });

    test('skips identical values', () {
      expect(
        shouldAnimateGaugeValue(
          previous: 50,
          next: 50,
          minValue: 0,
          maxValue: 100,
        ),
        isFalse,
      );
    });
  });

  group('downsamplePoints', () {
    test('returns original list when under cap', () {
      final points = List.generate(50, (i) => i);
      expect(downsamplePoints(points, maxPoints: 200), points);
    });

    test('caps large lists to maxPoints', () {
      final points = List.generate(1000, (i) => i);
      final sampled = downsamplePoints(points, maxPoints: 200);
      expect(sampled.length, lessThanOrEqualTo(200));
      expect(sampled.first, 0);
      expect(sampled.last, 999);
    });
  });
}
