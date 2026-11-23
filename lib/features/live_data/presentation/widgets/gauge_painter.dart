import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/material.dart';

// The dial is one layer: the track (background arc, zone bands, ticks) and
// the value arc are drawn together in one CustomPaint inside one
// RepaintBoundary, repainted from the animation without rebuilding any widget.
// A separate cached track layer measured no better on the SM-A605G (Skia GL
// re-rasterizes both layers every frame anyway), so it was dropped. The value
// arc allocates nothing per frame.

const double _startAngle = 135.0 * (math.pi / 180);
const double _sweepAngle = 270.0 * (math.pi / 180);
const double _strokeWidth = 10;
const double _zoneWidth = 3;
const double _zoneGap = 4;
const int _tickCount = 10;

double _radius(Size size) =>
    math.min(size.width, size.height) / 2 -
    _strokeWidth / 2 -
    _zoneGap -
    _zoneWidth;

/// A band of the scale drawn in a status colour, e.g. the coolant range above
/// 100 °C. The value arc takes the colour of the band it ends in.
@immutable
class GaugeZone {
  const GaugeZone(this.from, this.to, this.color);

  final double from;
  final double to;
  final Color color;

  bool contains(double value) => value >= from && value <= to;

  @override
  bool operator ==(Object other) =>
      other is GaugeZone &&
      other.from == from &&
      other.to == to &&
      other.color == color;

  @override
  int get hashCode => Object.hash(from, to, color);
}

double _fraction(double value, double minValue, double maxValue) {
  final span = maxValue - minValue;
  if (span <= 0) return 0;
  return ((value.clamp(minValue, maxValue) - minValue) / span).toDouble();
}

class GaugeTrackPainter extends CustomPainter {
  const GaugeTrackPainter({
    required this.minValue,
    required this.maxValue,
    required this.trackColor,
    required this.tickColor,
    required this.zones,
  });

  final double minValue;
  final double maxValue;
  final Color trackColor;
  final Color tickColor;
  final List<GaugeZone> zones;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = _radius(size);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Zone bands just outside the track.
    final zonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _zoneWidth
      ..strokeCap = StrokeCap.butt;
    final zoneRect = Rect.fromCircle(
      center: center,
      radius: radius + _strokeWidth / 2 + _zoneGap + _zoneWidth / 2,
    );
    for (final zone in zones) {
      final from = _fraction(zone.from, minValue, maxValue);
      final to = _fraction(zone.to, minValue, maxValue);
      if (to <= from) continue;
      zonePaint.color = zone.color;
      canvas.drawArc(
        zoneRect,
        _startAngle + _sweepAngle * from,
        _sweepAngle * (to - from),
        false,
        zonePaint,
      );
    }

    // Ticks every tenth of the scale, inside the track; a small dial keeps
    // the room for its readout.
    if (radius < 64) return;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final outer = radius - _strokeWidth / 2 - 4;
    for (var i = 0; i <= _tickCount; i++) {
      final angle = _startAngle + _sweepAngle * (i / _tickCount);
      final inner = outer - (i % 5 == 0 ? 8 : 4);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GaugeTrackPainter old) =>
      old.minValue != minValue ||
      old.maxValue != maxValue ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor ||
      !listEquals(old.zones, zones);
}

class GaugeValuePainter extends CustomPainter {
  GaugeValuePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.color,
    required this.zones,
  }) : super(repaint: value);

  /// Displayed value; every change repaints the dial (not the card).
  final ValueListenable<double> value;
  final double minValue;
  final double maxValue;
  final Color color;
  final List<GaugeZone> zones;

  // Built once per size: paint() runs every animation frame.
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth
    ..strokeCap = StrokeCap.round;
  Size? _size;
  Rect _rect = Rect.zero;

  Color _colorFor(double v) {
    for (final zone in zones) {
      if (zone.contains(v)) return zone.color;
    }
    return color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_size != size) {
      _size = size;
      _rect = Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: _radius(size),
      );
    }
    final v = value.value;
    final fraction = _fraction(v, minValue, maxValue);
    if (fraction <= 0) return;
    _paint.color = _colorFor(v);
    canvas.drawArc(_rect, _startAngle, _sweepAngle * fraction, false, _paint);
  }

  @override
  bool shouldRepaint(covariant GaugeValuePainter old) =>
      old.value != value ||
      old.minValue != minValue ||
      old.maxValue != maxValue ||
      old.color != color ||
      !listEquals(old.zones, zones);
}

/// The dial of a gauge: track and value arc in one repaint boundary that
/// follows [value]. Takes explicit paint parameters, not a metric config.
class GaugeDial extends StatelessWidget {
  const GaugeDial({
    super.key,
    required this.value,
    required this.size,
    required this.minValue,
    required this.maxValue,
    required this.color,
    required this.trackColor,
    required this.tickColor,
    this.zones = const [],
  });

  final ValueListenable<double> value;
  final double size;
  final double minValue;
  final double maxValue;

  /// Colour of the value arc outside any zone.
  final Color color;
  final Color trackColor;
  final Color tickColor;
  final List<GaugeZone> zones;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: GaugeTrackPainter(
          minValue: minValue,
          maxValue: maxValue,
          trackColor: trackColor,
          tickColor: tickColor,
          zones: zones,
        ),
        // The value painter's repaint listenable repaints this whole
        // CustomPaint, track included.
        foregroundPainter: GaugeValuePainter(
          value: value,
          minValue: minValue,
          maxValue: maxValue,
          color: color,
          zones: zones,
        ),
      ),
    );
  }
}
