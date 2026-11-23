import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/obd/obd_metric.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/performance_utils.dart';
import 'gauge_painter.dart';

export '../../../../core/obd/obd_metric.dart';

/// One metric as a dial with its readout. The value arc animates to each new
/// reading; the readout follows the animation in its own layer.
class GaugeWidget extends StatefulWidget {
  /// The reading, or null when it has not arrived (shown as "—").
  final double? value;
  final ObdMetricConfig config;
  final VoidCallback onTap;
  final bool compact;

  /// How the reading is judged; colours the readout and the arc for a problem.
  final MetricAssessment assessment;

  const GaugeWidget({
    super.key,
    required this.value,
    required this.config,
    required this.onTap,
    this.compact = false,
    this.assessment = const MetricAssessment(StatusLevel.ok),
  });

  @override
  State<GaugeWidget> createState() => _GaugeWidgetState();
}

class _GaugeWidgetState extends State<GaugeWidget>
    with SingleTickerProviderStateMixin {
  /// Highest reading since the gauge showed this metric. Taken from the raw
  /// readings, not from animation frames.
  double? _peakValue;
  late final AnimationController _controller;

  /// One curve for every animation: a CurvedAnimation registers a status
  /// listener on the controller until disposed, so one per value change
  /// would pile up listeners for as long as the gauge lives.
  late final CurvedAnimation _curve;
  Animation<double> _animation = const AlwaysStoppedAnimation(0);

  /// The displayed (animated) value. The dial and the readout listen to it,
  /// so animation frames repaint them without rebuilding the card.
  late final ValueNotifier<double> _shown;

  @override
  void initState() {
    super.initState();
    final start = widget.value ?? widget.config.minValue;
    _peakValue = widget.value;
    _shown = ValueNotifier(start);
    _animation = AlwaysStoppedAnimation(start);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => _shown.value = _animation.value);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant GaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value;
    if (widget.config.type != oldWidget.config.type) {
      _peakValue = next;
      _controller.stop();
      final start = next ?? widget.config.minValue;
      _animation = AlwaysStoppedAnimation(start);
      _shown.value = start;
      return;
    }
    if (next != null && (_peakValue == null || next > _peakValue!)) {
      _peakValue = next;
    }
    // Same target: a running animation goes on instead of restarting from
    // its midpoint, which kept gauges animating on every PID response.
    if (next == oldWidget.value) return;

    final target = next ?? widget.config.minValue;
    final previous = _shown.value;
    final shouldAnimate = next != null &&
        shouldAnimateGaugeValue(
          previous: previous,
          next: target,
          minValue: widget.config.minValue,
          maxValue: widget.config.maxValue,
        );
    if (!shouldAnimate) {
      _controller.stop();
      _animation = AlwaysStoppedAnimation(target);
      _shown.value = target;
      return;
    }
    _animation = Tween<double>(begin: previous, end: target).animate(_curve);
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatusColors.of(context);
    final config = widget.config;
    final type = config.type;
    final level = widget.assessment.level;
    final hasValue = widget.value != null &&
        level != StatusLevel.noData &&
        level != StatusLevel.unsupported;
    final problem = hasValue && level.isProblem;
    final zones = [
      for (final z in gaugeZoneSpec(type, max: config.maxValue))
        GaugeZone(z.from, z.to, status.foreground(z.level)),
    ];
    final readoutColor = problem ? status.foreground(level) : scheme.onSurface;

    final semantics = [
      config.label,
      if (level == StatusLevel.unsupported)
        StatusLevel.unsupported.label
      else if (hasValue)
        MetricDisplay.valueWithUnit(type, widget.value!)
      else
        StatusLevel.noData.label,
      if (problem) widget.assessment.note ?? level.label,
      if (hasValue && _peakValue != null)
        'puncak ${MetricDisplay.value(type, _peakValue!)}',
    ].join(', ');

    final padding = widget.compact ? AppSpacing.md : AppSpacing.lg;
    final headerHeight =
        MediaQuery.textScalerOf(context).scale(20) + AppSpacing.sm;

    return Semantics(
      container: true,
      button: true,
      label: semantics,
      onTap: widget.onTap,
      excludeSemantics: true,
      // The dial takes the room it is given: side by side in portrait, large
      // in the landscape cockpit, and never wider or taller than its card.
      child: LayoutBuilder(builder: (context, constraints) {
        // A wide card (landscape cockpit) puts name and peak on one line to
        // leave the height to the dial.
        final wide = constraints.maxHeight.isFinite &&
            constraints.maxWidth > constraints.maxHeight * 1.2;
        var dialSize = constraints.maxWidth.isFinite
            ? constraints.maxWidth - 2 * padding
            : 220.0;
        if (constraints.maxHeight.isFinite) {
          dialSize = math.min(
            dialSize,
            constraints.maxHeight -
                2 * padding -
                (wide ? 1 : 2) * headerHeight,
          );
        }
        dialSize = dialSize.clamp(96.0, 280.0);
        final readoutSize = (dialSize * 0.22).clamp(22.0, 52.0);
        final unitSize = (dialSize * 0.085).clamp(11.0, 16.0);
        final peakText = hasValue && _peakValue != null
            ? 'Puncak ${MetricDisplay.value(type, _peakValue!)}'
            : ' ';
        final peakStyle = AppTheme.numberStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        );
        return AppCard(
        onTap: widget.onTap,
        padding: EdgeInsets.all(padding),
        borderColor: problem ? status.foreground(level) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: LineFitText(
                    config.label,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
                if (wide) Text(peakText, style: peakStyle),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox.square(
              dimension: dialSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GaugeDial(
                    value: _shown,
                    size: dialSize,
                    minValue: config.minValue,
                    maxValue: config.maxValue,
                    color: problem ? status.foreground(level) : scheme.primary,
                    trackColor: scheme.surfaceContainerHighest,
                    tickColor: scheme.outline,
                    zones: zones,
                  ),
                  // The readout follows every animation frame in its own
                  // layer, so the rest of the screen is not re-recorded per
                  // frame and stays raster-cacheable. No text shadow: a blur
                  // would be recomputed every frame. It is sized by the dial,
                  // not by the system text size, which would push it onto
                  // the scale; the value also shows in Sensor and the chart.
                  _withDialTextSize(context, RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _shown,
                      builder: (context, displayValue, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (level == StatusLevel.unsupported)
                            Text(
                              StatusLevel.unsupported.label,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: status.noData),
                            )
                          else ...[
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxWidth: dialSize * 0.62),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  hasValue
                                      ? MetricDisplay.value(type, displayValue)
                                      : Fmt.pending,
                                  style: AppTheme.numberStyle(
                                    fontSize: readoutSize,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        hasValue ? readoutColor : status.noData,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              config.unit,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontSize: unitSize),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
            if (!wide) Text(peakText, style: peakStyle),
          ],
        ),
      );
      }),
    );
  }
}

Widget _withDialTextSize(BuildContext context, Widget readout) =>
    isTextEnlarged(context)
        ? MediaQuery.withClampedTextScaling(maxScaleFactor: 1, child: readout)
        : readout;
