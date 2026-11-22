import 'package:flutter/material.dart';
import '../../../../core/obd/obd_metric.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/performance_utils.dart';
import 'gauge_painter.dart';

export '../../../../core/obd/obd_metric.dart';

class GaugeWidget extends StatefulWidget {
  final double? value;
  final ObdMetricConfig config;
  final VoidCallback onTap;
  final bool compact;

  const GaugeWidget({
    super.key,
    required this.value,
    required this.config,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<GaugeWidget> createState() => _GaugeWidgetState();
}

class _GaugeWidgetState extends State<GaugeWidget>
    with SingleTickerProviderStateMixin {
  double _peakValue = 0.0;
  late final AnimationController _controller;

  /// One curve for every animation: a CurvedAnimation registers a status
  /// listener on the controller until disposed, so one per value change
  /// would pile up listeners for as long as the gauge lives.
  late final CurvedAnimation _curve;
  Animation<double> _animation = const AlwaysStoppedAnimation(0);

  /// The displayed (animated) value. The dial and the readout listen to it,
  /// so animation frames repaint them without rebuilding the card.
  late final ValueNotifier<double> _shown;

  /// Warning state of the displayed value: the card border, glow and badge
  /// rebuild only when it flips.
  late final ValueNotifier<bool> _warning;

  @override
  void initState() {
    super.initState();
    final start = widget.value ?? 0.0;
    _peakValue = start;
    _shown = ValueNotifier(start);
    _warning = ValueNotifier(_isWarning(start));
    _animation = AlwaysStoppedAnimation(start);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => _show(_animation.value));
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  void _show(double displayValue) {
    _shown.value = displayValue;
    _warning.value = _isWarning(displayValue);
  }

  bool _isWarning(double displayValue) {
    if (widget.value == null) return false;
    final config = widget.config;
    return (config.type == ObdMetricType.fuel ||
            config.type == ObdMetricType.voltage)
        ? displayValue <= config.warningThreshold
        : displayValue >= config.warningThreshold;
  }

  @override
  void didUpdateWidget(covariant GaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentValue = widget.value ?? 0.0;
    if (widget.config.type != oldWidget.config.type) {
      _peakValue = currentValue;
      _controller.stop();
      _animation = AlwaysStoppedAnimation(currentValue);
      _show(currentValue);
      return;
    }
    if (widget.value != null && currentValue > _peakValue) {
      _peakValue = currentValue;
    }
    // Same target: a running animation goes on instead of restarting from
    // its midpoint, which kept gauges animating on every PID response.
    if (widget.value == oldWidget.value) return;

    final previousDisplayed = _shown.value;
    final shouldAnimate = shouldAnimateGaugeValue(
      previous: previousDisplayed,
      next: currentValue,
      minValue: widget.config.minValue,
      maxValue: widget.config.maxValue,
    );
    if (!shouldAnimate) {
      _controller.stop();
      _animation = AlwaysStoppedAnimation(currentValue);
      _show(currentValue);
      return;
    }
    _animation = Tween<double>(
      begin: previousDisplayed,
      end: currentValue,
    ).animate(_curve);
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    _shown.dispose();
    _warning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialSize = widget.compact ? 135.0 : 180.0;
    return GestureDetector(
      onTap: widget.onTap,
      child: ValueListenableBuilder<bool>(
        valueListenable: _warning,
        builder: (context, isWarning, content) => Container(
          width: double.infinity,
          padding: widget.compact
              ? const EdgeInsets.symmetric(vertical: 6, horizontal: 10)
              : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isWarning
                  ? const Color(0xFFFF3366).withOpacity(0.3)
                  : widget.config.color.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isWarning
                    ? const Color(0xFFFF3366).withOpacity(0.05)
                    : widget.config.color.withOpacity(0.02),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: content,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar showing Peak Info & Dynamic Warn indicator
            ValueListenableBuilder<bool>(
              valueListenable: _warning,
              builder: (context, isWarning, _) => FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: widget.config.color.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        widget.value == null
                            ? 'Puncak: --'
                            : 'Puncak: ${_peakValue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.config.color.withOpacity(0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (isWarning) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3366).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFFF3366),
                              size: 10,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'BATAS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF3366),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: widget.compact ? 4 : 8),
            // Futuristic Segmented Gauge Outer Frame
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: dialSize,
                height: dialSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GaugeDial(
                      value: _shown,
                      size: dialSize,
                      minValue: widget.config.minValue,
                      maxValue: widget.config.maxValue,
                      color: widget.config.color,
                      backgroundColor: AppColors.surface,
                      warningThreshold: widget.config.warningThreshold,
                    ),
                    // Center Digital Readout: follows every animation
                    // frame in its own layer, so the rest of the screen is
                    // not re-recorded per frame and stays raster-cacheable.
                    RepaintBoundary(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _shown,
                        builder: (context, displayValue, _) {
                          final isWarning = _isWarning(displayValue);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: widget.compact ? 6 : 12),
                              Text(
                                widget.value == null
                                    ? '--'
                                    : displayValue.toStringAsFixed(
                                        widget.config.type ==
                                                ObdMetricType.voltage
                                            ? 1
                                            : 0,
                                      ),
                                style: TextStyle(
                                  fontSize: widget.compact ? 30 : 38,
                                  fontWeight: FontWeight.w900,
                                  color: isWarning
                                      ? const Color(0xFFFF3366)
                                      : Colors.white,
                                  fontFamily: 'monospace',
                                  shadows: [
                                    Shadow(
                                      color: isWarning
                                          ? const Color(
                                              0xFFFF3366,
                                            ).withOpacity(0.6)
                                          : widget.config.color.withOpacity(
                                              0.4,
                                            ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                widget.config.unit,
                                style: TextStyle(
                                  fontSize: widget.compact ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.config.color.withOpacity(0.7),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: widget.compact ? 4 : 8),
            // Label showing metric name & tap instruction
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.config.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swap_horizontal_circle_outlined,
                    size: 12,
                    color: widget.config.color.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
