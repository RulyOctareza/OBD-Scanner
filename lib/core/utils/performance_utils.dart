/// Pure helpers for gauge animation throttling and chart downsampling.

/// Returns true when the gauge needle should animate to [next].
bool shouldAnimateGaugeValue({
  required double previous,
  required double next,
  required double minValue,
  required double maxValue,
  double thresholdFraction = 0.005,
}) {
  if (previous == next) return false;
  final span = (maxValue - minValue).abs();
  if (span <= 0) return true;
  final threshold = span * thresholdFraction;
  return (next - previous).abs() >= threshold;
}

/// Downsamples [points] to at most [maxPoints], keeping first and last.
List<T> downsamplePoints<T>(List<T> points, {int maxPoints = 200}) {
  if (points.length <= maxPoints || maxPoints < 2) {
    return List<T>.from(points);
  }

  final result = <T>[];
  final step = (points.length - 1) / (maxPoints - 1);
  for (var i = 0; i < maxPoints; i++) {
    final index = (i * step).round().clamp(0, points.length - 1);
    result.add(points[index]);
  }
  return result;
}

/// Whether a telemetry sample is meaningful for charting.
///
/// Zero often means "no ECU data yet" for temperatures / voltage / MAP,
/// which would pin the Y-axis to the bottom and distort the graph.
bool isValidChartMetricValue(String metricKey, double value) {
  switch (metricKey) {
    case 'coolant':
    case 'intakeAirTemp':
      // Ambient cold start can be low, but 0 (or below) is empty/init data.
      return value > 0;
    case 'voltage':
      return value > 5;
    case 'map':
      return value > 5;
    case 'maf':
      return value >= 0;
    case 'fuelEconomy':
      return value > 0;
    case 'rpm':
    case 'speed':
    case 'throttle':
    case 'engineLoad':
    case 'fuel':
    case 'timingAdvance':
      return value >= 0;
    default:
      return value >= 0;
  }
}
