import 'dart:math' as math;
import 'package:flutter/material.dart';

class GaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final Color activeColor;
  final Color backgroundColor;
  final Color warningColor;
  final double warningThreshold;

  GaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.activeColor,
    required this.backgroundColor,
    this.warningColor = const Color(0xFFFF3366), // Hot pink / Neon Red
    required this.warningThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 12;

    // Angles: Start at 140 degrees, sweep 260 degrees (leaving 100 degrees at bottom)
    const startAngleDegrees = 140.0;
    const sweepAngleDegrees = 260.0;
    const startAngle = startAngleDegrees * (math.pi / 180);
    const sweepAngle = sweepAngleDegrees * (math.pi / 180);

    // 1. Draw Outer Glowing Ring (Thin Neon Ring)
    final outerRingPaint = Paint()
      ..color = activeColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      startAngle,
      sweepAngle,
      false,
      outerRingPaint,
    );

    // 2. Draw Background Segmented Arc (Cyberpunk dashed track)
    final bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 3. Draw Segmented Active Arc
    final clampedValue = value.clamp(minValue, maxValue);
    final valuePercentage = (clampedValue - minValue) / (maxValue - minValue);
    final activeSweepAngle = sweepAngle * valuePercentage;

    final isWarning = clampedValue >= warningThreshold;
    final currentActiveColor = isWarning ? warningColor : activeColor;

    // We draw segmented blocks for a digital/futuristic look
    final segmentsCount = 40;
    final segmentGap = 0.03; // gap in radians
    final totalSegmentAngle = sweepAngle / segmentsCount;
    final activeSegmentsCount = (valuePercentage * segmentsCount).floor();

    final activeSegmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.square;

    for (int i = 0; i < segmentsCount; i++) {
      final segmentStartAngle = startAngle + (i * totalSegmentAngle);
      final segmentSweepAngle = totalSegmentAngle - segmentGap;
      
      // Determine color for this segment
      final segmentValue = minValue + (i / segmentsCount) * (maxValue - minValue);
      final isSegmentWarning = segmentValue >= warningThreshold;
      
      Color segColor;
      if (i < activeSegmentsCount) {
        segColor = isSegmentWarning ? warningColor : activeColor;
      } else {
        segColor = backgroundColor.withOpacity(0.08); // Unfilled segments
      }

      activeSegmentPaint.color = segColor;

      // Draw segment arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segmentStartAngle,
        segmentSweepAngle,
        false,
        activeSegmentPaint,
      );
    }

    // 4. Draw Inner Grid/Ticks
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final tickCount = 10;
    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (sweepAngle * (i / tickCount));
      final innerRadius = radius - 18;
      final outerRadius = radius - 12;

      final isTickWarning = (minValue + (i / tickCount) * (maxValue - minValue)) >= warningThreshold;
      tickPaint.color = isTickWarning 
          ? warningColor.withOpacity(0.6) 
          : activeColor.withOpacity(0.4);

      final p1 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      canvas.drawLine(p1, p2, tickPaint);
    }

    // 5. Draw Digital Sweeping Indicator Dot / Pointer (glowing head)
    if (activeSweepAngle > 0) {
      final pointerAngle = startAngle + activeSweepAngle;
      final pointerRadius = radius;
      final pointerPos = Offset(
        center.dx + pointerRadius * math.cos(pointerAngle),
        center.dy + pointerRadius * math.sin(pointerAngle),
      );

      final pointerPaint = Paint()
        ..color = currentActiveColor
        ..style = PaintingStyle.fill;

      // Outer glow of the pointer
      canvas.drawCircle(pointerPos, 8, Paint()..color = currentActiveColor.withOpacity(0.5));
      // Inner solid point
      canvas.drawCircle(pointerPos, 4, pointerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.warningThreshold != warningThreshold;
  }
}
