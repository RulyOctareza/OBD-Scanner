import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

// The gauge is painted in two layers. The track (ring, background arc, unlit
// segments, ticks) depends only on the metric and is cached in its own layer.
// The value layer (lit segments, pointer) repaints from the animation without
// rebuilding any widget. Lit segments are opaque, so painting them over the
// unlit ones gives the same pixels as painting either alone.

const double _startAngle = 140.0 * (math.pi / 180);
const double _sweepAngle = 260.0 * (math.pi / 180);
const int _segmentsCount = 40;
const double _segmentGap = 0.03; // radians
const Color gaugeWarningColor = Color(0xFFFF3366);

double _radius(Size size) => math.min(size.width / 2, size.height / 2) - 12;

class GaugeTrackPainter extends CustomPainter {
  const GaugeTrackPainter({
    required this.minValue,
    required this.maxValue,
    required this.activeColor,
    required this.backgroundColor,
    required this.warningThreshold,
  });

  final double minValue;
  final double maxValue;
  final Color activeColor;
  final Color backgroundColor;
  final double warningThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = _radius(size);

    // Outer thin ring.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = activeColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Background arc.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = backgroundColor.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    // Unlit segments.
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.square
      ..color = backgroundColor.withOpacity(0.08);
    const segmentAngle = _sweepAngle / _segmentsCount;
    for (int i = 0; i < _segmentsCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle + i * segmentAngle,
        segmentAngle - _segmentGap,
        false,
        segmentPaint,
      );
    }

    // Ticks.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const tickCount = 10;
    for (int i = 0; i <= tickCount; i++) {
      final angle = _startAngle + (_sweepAngle * (i / tickCount));
      final innerRadius = radius - 18;
      final outerRadius = radius - 12;
      final isTickWarning =
          (minValue + (i / tickCount) * (maxValue - minValue)) >= warningThreshold;
      tickPaint.color = isTickWarning
          ? gaugeWarningColor.withOpacity(0.6)
          : activeColor.withOpacity(0.4);
      canvas.drawLine(
        Offset(
          center.dx + innerRadius * math.cos(angle),
          center.dy + innerRadius * math.sin(angle),
        ),
        Offset(
          center.dx + outerRadius * math.cos(angle),
          center.dy + outerRadius * math.sin(angle),
        ),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GaugeTrackPainter old) =>
      old.minValue != minValue ||
      old.maxValue != maxValue ||
      old.activeColor != activeColor ||
      old.backgroundColor != backgroundColor ||
      old.warningThreshold != warningThreshold;
}

class GaugeValuePainter extends CustomPainter {
  GaugeValuePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.activeColor,
    required this.warningThreshold,
  }) : super(repaint: value);

  /// Displayed value; every change repaints this layer only.
  final ValueListenable<double> value;
  final double minValue;
  final double maxValue;
  final Color activeColor;
  final double warningThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = _radius(size);

    final clampedValue = value.value.clamp(minValue, maxValue);
    final valuePercentage = (clampedValue - minValue) / (maxValue - minValue);
    final activeSweepAngle = _sweepAngle * valuePercentage;
    final currentActiveColor =
        clampedValue >= warningThreshold ? gaugeWarningColor : activeColor;

    // Lit segments.
    final activeSegmentsCount = (valuePercentage * _segmentsCount).floor();
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.square;
    const segmentAngle = _sweepAngle / _segmentsCount;
    for (int i = 0; i < activeSegmentsCount; i++) {
      final segmentValue = minValue + (i / _segmentsCount) * (maxValue - minValue);
      segmentPaint.color =
          segmentValue >= warningThreshold ? gaugeWarningColor : activeColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle + i * segmentAngle,
        segmentAngle - _segmentGap,
        false,
        segmentPaint,
      );
    }

    // Pointer with glow.
    if (activeSweepAngle > 0) {
      final pointerAngle = _startAngle + activeSweepAngle;
      final pointerPos = Offset(
        center.dx + radius * math.cos(pointerAngle),
        center.dy + radius * math.sin(pointerAngle),
      );
      canvas.drawCircle(
        pointerPos,
        8,
        Paint()..color = currentActiveColor.withOpacity(0.5),
      );
      canvas.drawCircle(
        pointerPos,
        4,
        Paint()
          ..color = currentActiveColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GaugeValuePainter old) =>
      old.value != value ||
      old.minValue != minValue ||
      old.maxValue != maxValue ||
      old.activeColor != activeColor ||
      old.warningThreshold != warningThreshold;
}

/// The dial of a gauge: a cached track layer under a value layer that follows
/// [value]. Takes explicit paint parameters, not a metric config.
class GaugeDial extends StatelessWidget {
  const GaugeDial({
    super.key,
    required this.value,
    required this.size,
    required this.minValue,
    required this.maxValue,
    required this.color,
    required this.backgroundColor,
    required this.warningThreshold,
  });

  final ValueListenable<double> value;
  final double size;
  final double minValue;
  final double maxValue;
  final Color color;
  final Color backgroundColor;
  final double warningThreshold;

  @override
  Widget build(BuildContext context) {
    final dimensions = Size(size, size);
    return Stack(
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: dimensions,
            painter: GaugeTrackPainter(
              minValue: minValue,
              maxValue: maxValue,
              activeColor: color,
              backgroundColor: backgroundColor,
              warningThreshold: warningThreshold,
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            size: dimensions,
            painter: GaugeValuePainter(
              value: value,
              minValue: minValue,
              maxValue: maxValue,
              activeColor: color,
              warningThreshold: warningThreshold,
            ),
          ),
        ),
      ],
    );
  }
}
