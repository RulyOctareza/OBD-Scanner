import 'package:flutter/material.dart';

import '../obd/obd_metric.dart';
import '../theme/app_theme.dart';
import '../widgets/live_obd.dart';
import 'app_card.dart';
import 'format.dart';
import 'metric_display.dart';
import 'metric_status.dart';
import 'status.dart';
import 'status_chip.dart';
import 'tokens.dart';

enum MetricTileSize { compact, medium, large }

/// One value with its label, unit and status. A value that has not arrived
/// shows "—" and one the car does not report shows "Tidak didukung", never a
/// number. Colour appears only for a problem (waspada / kritis).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.assessment = const MetricAssessment(StatusLevel.ok),
    this.onTap,
    this.size = MetricTileSize.medium,
  });

  final String label;

  /// Formatted value without unit; ignored unless the level carries data.
  final String? value;
  final String? unit;
  final IconData? icon;
  final MetricAssessment assessment;

  /// Opens the metric's details (its chart).
  final VoidCallback? onTap;
  final MetricTileSize size;

  bool get _hasData =>
      assessment.level != StatusLevel.noData &&
      assessment.level != StatusLevel.unsupported &&
      value != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatusColors.of(context);
    final level = assessment.level;
    final problem = level.isProblem;
    final valueSize = switch (size) {
      MetricTileSize.compact => 22.0,
      MetricTileSize.medium => 28.0,
      MetricTileSize.large => 40.0,
    };
    final valueColor = !_hasData
        ? status.noData
        : problem
            ? status.foreground(level)
            : scheme.onSurface;

    final Widget reading = level == StatusLevel.unsupported
        ? Text(
            StatusLevel.unsupported.label,
            style: theme.textTheme.bodyLarge?.copyWith(color: status.noData),
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _hasData ? value : Fmt.pending,
                  style: AppTheme.numberStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
                if (_hasData && unit != null)
                  TextSpan(
                    text: unit == '%' ? unit : '${Fmt.nbsp}$unit',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          );

    final semantics = [
      label,
      if (level == StatusLevel.unsupported)
        StatusLevel.unsupported.label
      else if (_hasData)
        unit == null ? value! : Fmt.unit(value!, unit!)
      else
        StatusLevel.noData.label,
      if (_hasData && (problem || assessment.note != null))
        assessment.note ?? level.label,
    ].join(', ');

    return Semantics(
      container: true,
      button: onTap != null,
      label: semantics,
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.all(
          size == MetricTileSize.compact ? AppSpacing.md : AppSpacing.lg,
        ),
        borderColor: problem ? status.foreground(level) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(label, style: theme.textTheme.bodyMedium),
                ),
                if (onTap != null)
                  Icon(
                    Icons.show_chart_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            reading,
            if (_hasData && problem) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusChip(level, label: assessment.note),
            ],
          ],
        ),
      ),
    );
  }
}

/// [MetricTile] for a live metric: rebuilds only when the displayed value or
/// its status changes, in its own layer (values change several times a
/// second while driving).
class LiveMetricTile extends StatelessWidget {
  const LiveMetricTile(
    this.type, {
    super.key,
    this.onTap,
    this.size = MetricTileSize.medium,
  });

  final ObdMetricType type;
  final VoidCallback? onTap;
  final MetricTileSize size;

  Widget _tile(MetricReading reading, {bool engineRunning = false}) {
    final config = ObdMetricConfig.of(type);
    return MetricTile(
      label: config.label,
      value: reading.hasValue
          ? MetricDisplay.value(type, reading.value!)
          : null,
      unit: config.unit,
      icon: MetricDisplay.icon(type),
      assessment: assessReading(type, reading, engineRunning: engineRunning),
      onTap: onTap,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = MetricDisplay.step(type);
    return RepaintBoundary(
      child: assessmentNeedsRpm(type)
          ? ObdSelect<(MetricReading, bool)>(
              selector: (s) => (
                readingOf(s, type, step: step),
                isEngineRunning(s.telemetry.rpm),
              ),
              builder: (context, v, _) => _tile(v.$1, engineRunning: v.$2),
            )
          : LiveMetric(
              type: type,
              step: step,
              builder: (context, reading, _) => _tile(reading),
            ),
    );
  }
}

/// A metric as one list row: icon, label (and its technical name), value
/// with unit on the right, status chip under the value for a problem. Lists
/// show many metrics per screen, where tiles show four.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    this.detail,
    required this.value,
    this.unit,
    this.icon,
    this.assessment = const MetricAssessment(StatusLevel.ok),
    this.onTap,
  });

  final String label;

  /// Secondary line, e.g. the OBD name.
  final String? detail;
  final String? value;
  final String? unit;
  final IconData? icon;
  final MetricAssessment assessment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatusColors.of(context);
    final level = assessment.level;
    final hasData = level != StatusLevel.noData &&
        level != StatusLevel.unsupported &&
        value != null;
    final problem = hasData && level.isProblem;
    final valueText = level == StatusLevel.unsupported
        ? StatusLevel.unsupported.label
        : hasData
            ? (unit == null ? value! : Fmt.unit(value!, unit!))
            : Fmt.pending;
    final valueColor = !hasData
        ? status.noData
        : problem
            ? status.foreground(level)
            : scheme.onSurface;

    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      label: [
        label,
        if (hasData) valueText else (level == StatusLevel.unsupported
            ? StatusLevel.unsupported.label
            : StatusLevel.noData.label),
        if (problem) assessment.note ?? level.label,
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.bodyLarge),
                      if (detail != null)
                        Text(detail!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      valueText,
                      style: level == StatusLevel.unsupported
                          ? theme.textTheme.bodyMedium
                              ?.copyWith(color: status.noData)
                          : AppTheme.numberStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: valueColor,
                            ),
                    ),
                    if (problem) ...[
                      const SizedBox(height: AppSpacing.xs),
                      StatusChip(level, label: assessment.note),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [MetricRow] for a live metric, rebuilding only on its displayed value.
class LiveMetricRow extends StatelessWidget {
  const LiveMetricRow(this.type, {super.key, this.onTap});

  final ObdMetricType type;
  final VoidCallback? onTap;

  Widget _row(MetricReading reading, {bool engineRunning = false}) {
    final config = ObdMetricConfig.of(type);
    return MetricRow(
      label: config.label,
      detail: MetricDisplay.technicalName(type),
      value: reading.hasValue ? MetricDisplay.value(type, reading.value!) : null,
      unit: config.unit,
      icon: MetricDisplay.icon(type),
      assessment: assessReading(type, reading, engineRunning: engineRunning),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = MetricDisplay.step(type);
    // Own layer: rows sit in one card, and a changing value should not
    // re-record its neighbours.
    return RepaintBoundary(
      child: assessmentNeedsRpm(type)
          ? ObdSelect<(MetricReading, bool)>(
              selector: (s) => (
                readingOf(s, type, step: step),
                isEngineRunning(s.telemetry.rpm),
              ),
              builder: (context, v, _) => _row(v.$1, engineRunning: v.$2),
            )
          : LiveMetric(
              type: type,
              step: step,
              builder: (context, reading, _) => _row(reading),
            ),
    );
  }
}
