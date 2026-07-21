import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/bluetooth/obd_service.dart';
import '../telemetry_provider.dart';
import 'gauge_widget.dart';

class TelemetryChartModal extends ConsumerWidget {
  final ObdMetricType metricType;

  const TelemetryChartModal({
    super.key,
    required this.metricType,
  });

  static void show(BuildContext context, ObdMetricType metricType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TelemetryChartModal(metricType: metricType),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ObdMetricConfig.all.firstWhere((c) => c.type == metricType);
    final historyAsync = ref.watch(telemetryHistoryProvider(metricType));
    final selectedRange = ref.watch(telemetryTimeRangeProvider);
    final obdState = ref.watch(obdServiceProvider);

    final isVoltageOrFuelEco =
        metricType == ObdMetricType.voltage ||
        metricType == ObdMetricType.fuelEconomy;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: config.color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: config.color.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: config.color.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(_getMetricIcon(metricType), color: config.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              config.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (obdState.status == ObdStatus.connected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF33FF33).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF33FF33), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: Color(0xFF33FF33),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF33FF33),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Grafik Historis Telemetri (${config.unit})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Time Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TelemetryTimeRange.values.map((range) {
                  final isSelected = range == selectedRange;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        range.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: config.color.withOpacity(0.8),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: isSelected ? config.color : Colors.white12,
                        width: 1,
                      ),
                      onSelected: (val) {
                        if (val) {
                          ref.read(telemetryTimeRangeProvider.notifier).state = range;
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Content body
          Expanded(
            child: historyAsync.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Gagal memuat data: $err',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (data) {
                if (data.points.isEmpty) {
                  return _buildEmptyState(config);
                }

                return Column(
                  children: [
                    // Main Chart View
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 24, 8),
                        child: _buildLineChart(
                          data.points,
                          config,
                          isVoltageOrFuelEco,
                          isStable: data.isStable,
                        ),
                      ),
                    ),

                    // KPI Stats Cards
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'SAAT INI',
                                  value: data.currentValue != null
                                      ? '${data.currentValue!.toStringAsFixed(isVoltageOrFuelEco ? 1 : 0)} ${config.unit}'
                                      : '--',
                                  icon: Icons.speed_rounded,
                                  accentColor: config.color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'PUNCAK',
                                  value: data.maxValue != null
                                      ? '${data.maxValue!.toStringAsFixed(isVoltageOrFuelEco ? 1 : 0)} ${config.unit}'
                                      : '--',
                                  icon: Icons.north_east_rounded,
                                  accentColor: Colors.orangeAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'TERENDAH',
                                  value: data.minValue != null
                                      ? '${data.minValue!.toStringAsFixed(isVoltageOrFuelEco ? 1 : 0)} ${config.unit}'
                                      : '--',
                                  icon: Icons.south_east_rounded,
                                  accentColor: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'RATA-RATA',
                                  value: data.avgValue != null
                                      ? '${data.avgValue!.toStringAsFixed(isVoltageOrFuelEco ? 1 : 0)} ${config.unit}'
                                      : '--',
                                  icon: Icons.functions_rounded,
                                  accentColor: Colors.purpleAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ObdMetricConfig config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 54,
              color: config.color.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Merekam Telemetri...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data sampel lokal sedang dikumpulkan secara realtime dari koneksi OBD atau Simulator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(
    List<TelemetryPoint> points,
    ObdMetricConfig config,
    bool isPrecisionDecimal, {
    bool isStable = false,
  }) {
    final firstTime = points.first.timestamp;
    final List<FlSpot> spots = [];
    double lastX = -1.0;

    for (final p in points) {
      double xSecs = p.timestamp.difference(firstTime).inMilliseconds / 1000.0;
      if (xSecs <= lastX) {
        xSecs = lastX + 0.05;
      }
      spots.add(FlSpot(xSecs, p.value));
      lastX = xSecs;
    }

    final minYRaw = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxYRaw = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final bounds = computeChartYBounds(
      minValue: minYRaw,
      maxValue: maxYRaw,
      metricMin: config.minValue,
      metricMax: config.maxValue,
    );
    final finalMinY = bounds.minY;
    final finalMaxY = bounds.maxY;

    final timeFormat = DateFormat('HH:mm:ss');
    final yInterval = ((finalMaxY - finalMinY) / 4).clamp(0.1, double.infinity);

    return Column(
      children: [
        if (isStable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Nilai relatif stabil — grafik akan bergerak saat sensor berubah.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: config.color.withOpacity(0.85),
              ),
            ),
          ),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: finalMinY,
              maxY: finalMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (val) => FlLine(
                  color: Colors.white.withOpacity(0.06),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (val) => FlLine(
                  color: Colors.white.withOpacity(0.04),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (spots.last.x / 3).clamp(1.0, double.infinity),
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || spots.isEmpty) return const SizedBox.shrink();
                      final targetTime = firstTime.add(
                        Duration(milliseconds: (value * 1000).toInt()),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          timeFormat.format(targetTime),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(isPrecisionDecimal ? 1 : 0),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white10, width: 1),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppColors.surface.withOpacity(0.9),
                  tooltipBorder: BorderSide(color: config.color, width: 1),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final targetTime = firstTime.add(
                        Duration(milliseconds: (spot.x * 1000).toInt()),
                      );
                      final valStr = spot.y.toStringAsFixed(
                        isPrecisionDecimal ? 1 : 0,
                      );
                      return LineTooltipItem(
                        '${timeFormat.format(targetTime)}\n$valStr ${config.unit}',
                        TextStyle(
                          color: config.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  color: config.color,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: spots.length < 40,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: config.color,
                      strokeWidth: 1.5,
                      strokeColor: Colors.black,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        config.color.withOpacity(0.35),
                        config.color.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMetricIcon(ObdMetricType type) {
    switch (type) {
      case ObdMetricType.rpm:
        return Icons.speed_rounded;
      case ObdMetricType.speed:
        return Icons.navigation_rounded;
      case ObdMetricType.coolant:
        return Icons.thermostat_rounded;
      case ObdMetricType.voltage:
        return Icons.battery_charging_full_rounded;
      case ObdMetricType.throttle:
        return Icons.input_rounded;
      case ObdMetricType.engineLoad:
        return Icons.work_rounded;
      case ObdMetricType.map:
        return Icons.compress_rounded;
      case ObdMetricType.fuel:
        return Icons.local_gas_station_rounded;
      case ObdMetricType.fuelEconomy:
        return Icons.analytics_rounded;
      case ObdMetricType.intakeAirTemp:
        return Icons.ac_unit_rounded;
      case ObdMetricType.maf:
        return Icons.air_rounded;
      case ObdMetricType.timingAdvance:
        return Icons.flash_on_rounded;
    }
  }
}
