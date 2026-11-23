import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bluetooth/obd_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../telemetry_provider.dart';
import 'gauge_widget.dart';

String _rangeLabel(TelemetryTimeRange range) => switch (range) {
      TelemetryTimeRange.oneMin => '1 mnt',
      TelemetryTimeRange.fiveMin => '5 mnt',
      TelemetryTimeRange.fifteenMin => '15 mnt',
      TelemetryTimeRange.oneHour => '1 jam',
      TelemetryTimeRange.all => 'Semua',
    };

/// The history of one metric as a sheet: range, line chart and statistics.
class TelemetryChartModal extends ConsumerWidget {
  final ObdMetricType metricType;

  const TelemetryChartModal({
    super.key,
    required this.metricType,
  });

  /// Opens on the root navigator, above the navigation bar. The dev
  /// benchmark calls this and closes the sheet through its own navigator.
  static void show(BuildContext context, ObdMetricType metricType) {
    showAppSheet<void>(
      context: context,
      builder: (context) => TelemetryChartModal(metricType: metricType),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config = ObdMetricConfig.of(metricType);
    final historyAsync = ref.watch(telemetryHistoryProvider(metricType));
    final selectedRange = ref.watch(telemetryTimeRangeProvider);
    final isConnected = ref.watch(
      obdServiceProvider.select((s) => s.status == ObdStatus.connected),
    );
    final technical = MetricDisplay.technicalName(metricType);

    final chartHeight =
        (MediaQuery.sizeOf(context).height * 0.32).clamp(180.0, 320.0);
    // Scrolls as a whole: at large text sizes or on a short screen the
    // statistics stay reachable instead of ending under the screen edge.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MetricDisplay.icon(metricType),
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(config.label, style: theme.textTheme.titleLarge),
                      ),
                      if (technical != null)
                        Text(technical, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (isConnected)
                  const StatusChip(StatusLevel.ok, label: 'Live'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final range in TelemetryTimeRange.values)
                  ChoiceChip(
                    label: Text(_rangeLabel(range)),
                    selected: range == selectedRange,
                    onSelected: (_) => ref
                        .read(telemetryTimeRangeProvider.notifier)
                        .state = range,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          historyAsync.when(
              // Stored trip points still loading and no live samples yet.
              loading: () => SizedBox(
                height: chartHeight,
                child: Center(
                  child: Text('Memuat data grafik…',
                      style: theme.textTheme.bodyMedium),
                ),
              ),
              error: (e, _) => EmptyState(
                compact: true,
                icon: Icons.error_outline_rounded,
                title: 'Grafik gagal dimuat',
                message: 'Tutup lalu buka lagi grafiknya.',
              ),
              data: (data) {
                if (data.points.isEmpty) {
                  return SizedBox(
                    height: chartHeight,
                    child: EmptyState(
                      compact: true,
                      icon: Icons.show_chart_rounded,
                      title: 'Belum ada data grafik',
                      message: isConnected
                          ? 'Grafik terisi beberapa detik setelah nilai '
                              'pertama masuk.'
                          : 'Hubungkan adapter untuk merekam data. Grafik '
                              'juga memakai perjalanan yang sudah terekam.',
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.isStable)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          0,
                          AppSpacing.xl,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          'Nilainya stabil pada rentang ini.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    SizedBox(
                      height: chartHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.xl,
                          0,
                        ),
                        child: _Chart(
                          points: data.points,
                          config: config,
                          lineColor: scheme.primary,
                          gridColor: scheme.outlineVariant,
                          range: selectedRange,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.xl,
                      ),
                      child: _Stats(data: data, type: metricType),
                    ),
                  ],
                );
              },
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.points,
    required this.config,
    required this.lineColor,
    required this.gridColor,
    required this.range,
  });

  final List<TelemetryPoint> points;
  final ObdMetricConfig config;
  final Color lineColor;
  final Color gridColor;
  final TelemetryTimeRange range;

  String _timeLabel(DateTime time, Duration span) {
    if (span > const Duration(days: 1)) return Fmt.date(time);
    if (span > const Duration(minutes: 15)) return Fmt.time(time);
    return Fmt.timeWithSeconds(time);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall;
    final firstTime = points.first.timestamp;
    final span = points.last.timestamp.difference(firstTime);
    final spots = <FlSpot>[];
    var lastX = -1.0;
    for (final p in points) {
      var x = p.timestamp.difference(firstTime).inMilliseconds / 1000.0;
      if (x <= lastX) x = lastX + 0.05;
      spots.add(FlSpot(x, p.value));
      lastX = x;
    }

    var minY = points.first.value;
    var maxY = points.first.value;
    for (final p in points) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    final bounds = computeChartYBounds(
      minValue: minY,
      maxValue: maxY,
      metricMin: config.minValue,
      metricMax: config.maxValue,
    );
    // Round the scale out to a readable step (1, 2, 2,5 or 5 times a power
    // of ten), so grid labels read 40 · 50 · 60 rather than 44 · 53 · 62.
    final yInterval = _niceStep((bounds.maxY - bounds.minY) / 4);
    final chartMinY = (bounds.minY / yInterval).floorToDouble() * yInterval;
    final chartMaxY = (bounds.maxY / yInterval).ceilToDouble() * yInterval;
    final decimals = yInterval < 1 ? 1 : 0;

    return LineChart(
      // Updates arrive once a second; a tween would animate every one of them.
      duration: Duration.zero,
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (spots.last.x / 2).clamp(1.0, double.infinity),
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox.shrink();
                final time =
                    firstTime.add(Duration(milliseconds: (value * 1000).toInt()));
                // fitInside keeps the first and last label within the chart
                // instead of centring them on (and past) its edges.
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: AppSpacing.sm,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(_timeLabel(time, span), style: text),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                // The scale's own ends can sit a few pixels from a grid
                // label and overlap it.
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(Fmt.number(value, decimals: decimals), style: text);
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

double _niceStep(double raw) {
  if (raw <= 0 || !raw.isFinite) return 1;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (raw <= m * magnitude) return m * magnitude;
  }
  return 10 * magnitude;
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data, required this.type});

  final TelemetryHistoryData data;
  final ObdMetricType type;

  @override
  Widget build(BuildContext context) {
    String show(double? v) =>
        v == null ? Fmt.pending : MetricDisplay.valueWithUnit(type, v);
    final items = [
      ('Saat ini', show(data.currentValue)),
      ('Tertinggi', show(data.maxValue)),
      ('Terendah', show(data.minValue)),
      ('Rata-rata', show(data.avgValue)),
    ];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in items.sublist(i, i + 2))
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: text.bodySmall),
                        Text(
                          value,
                          style: AppTheme.numberStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
