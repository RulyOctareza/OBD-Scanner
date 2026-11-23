import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/obd_telemetry.dart';
import '../../../core/widgets/live_obd.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import 'widgets/gauge_widget.dart';
import 'widgets/telemetry_chart_modal.dart';
import '../../../core/ui/segment_switch.dart';

/// One Sensor card: what it shows and how its value text and colour follow
/// the telemetry.
class _SensorCard {
  const _SensorCard(this.type, this.label, this.unit, this.icon, this.display);

  final ObdMetricType type;
  final String label;
  final String unit;
  final IconData icon;
  final (String, Color) Function(ObdTelemetry t) display;
}

final List<_SensorCard> _cards = [
  _SensorCard(
    ObdMetricType.rpm,
    'Putaran Mesin',
    'RPM',
    Icons.speed_rounded,
    (t) => (
      t.rpm.toStringAsFixed(0),
      t.rpm > 3500 ? AppColors.warning : AppColors.primary,
    ),
  ),
  _SensorCard(
    ObdMetricType.speed,
    'Kecepatan',
    'km/h',
    Icons.navigation_rounded,
    (t) => (
      t.speed.toStringAsFixed(0),
      t.speed > 100 ? AppColors.warning : AppColors.primary,
    ),
  ),
  _SensorCard(
    ObdMetricType.coolant,
    'Suhu Pendingin',
    '°C',
    Icons.thermostat_rounded,
    (t) => (
      '${t.coolant.toStringAsFixed(0)}°',
      t.coolant > 100
          ? AppColors.danger
          : (t.coolant > 95 ? AppColors.warning : AppColors.success),
    ),
  ),
  _SensorCard(
    ObdMetricType.voltage,
    'Tegangan Aki',
    'Volt',
    Icons.battery_charging_full_rounded,
    (t) => (
      '${t.voltage.toStringAsFixed(1)}V',
      t.voltage < 11.8 ? AppColors.danger : AppColors.success,
    ),
  ),
  _SensorCard(
    ObdMetricType.throttle,
    'Bukaan Gas',
    'Throttle',
    Icons.airline_seat_recline_extra_rounded,
    (t) => ('${t.throttle.toStringAsFixed(0)}%', AppColors.primary),
  ),
  _SensorCard(
    ObdMetricType.engineLoad,
    'Beban Mesin',
    'Engine Load',
    Icons.work_rounded,
    (t) => (
      '${t.engineLoad.toStringAsFixed(0)}%',
      t.engineLoad > 85 ? AppColors.warning : AppColors.primary,
    ),
  ),
  _SensorCard(
    ObdMetricType.map,
    'Tekanan Intake',
    'MAP · kPa',
    Icons.compress_rounded,
    (t) => (t.mapValue.toStringAsFixed(0), AppColors.primary),
  ),
  _SensorCard(
    ObdMetricType.intakeAirTemp,
    'Suhu Intake',
    '°C',
    Icons.ac_unit_rounded,
    (t) => (
      t.intakeAirTemp != null
          ? '${t.intakeAirTemp!.toStringAsFixed(0)}°'
          : '--',
      t.intakeAirTemp != null
          ? (t.intakeAirTemp! > 70
                ? AppColors.danger
                : t.intakeAirTemp! > 50
                ? AppColors.warning
                : AppColors.success)
          : AppColors.textSecondary,
    ),
  ),
  _SensorCard(
    ObdMetricType.maf,
    'Aliran Udara',
    'MAF · g/s',
    Icons.air_rounded,
    (t) =>
        (t.maf != null ? t.maf!.toStringAsFixed(1) : '--', AppColors.primary),
  ),
  _SensorCard(
    ObdMetricType.timingAdvance,
    'Timing Advance',
    '°',
    Icons.flash_on_rounded,
    (t) => (
      t.timingAdvance != null ? t.timingAdvance!.toStringAsFixed(1) : '--',
      AppColors.primary,
    ),
  ),
];

class LiveDataScreen extends ConsumerWidget {
  const LiveDataScreen({super.key});

  static bool _isMetricUnsupported(ObdMetricType type, ObdState state) {
    return state.checkedSensors.contains(type) &&
        !state.supportedSensors.contains(type);
  }

  /// Bit i set when card i's metric was asked and the car does not answer it.
  static int _hiddenCards(ObdState state) {
    var mask = 0;
    for (var i = 0; i < _cards.length; i++) {
      if (_isMetricUnsupported(_cards[i].type, state)) mask |= 1 << i;
    }
    return mask;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The grid rebuilds only when the link status or the set of hidden cards
    // changes; each card rebuilds when its own text or colour changes, and
    // nothing rebuilds while this tab is offstage.
    final status = ref.watchVisible(
      context,
      obdServiceProvider.select((s) => s.status),
    );
    final hidden = ref.watchVisible(
      context,
      obdServiceProvider.select(_hiddenCards),
    );

    return Scaffold(
      appBar: AppBar(
        title: const SegmentSwitch(
          segments: liveSegments,
          current: '/live_data',
        ),
      ),
      body: SafeArea(
        child: status != ObdStatus.connected && status != ObdStatus.initializing
            ? Consumer(
                builder: (context, ref, _) => ObdNotConnectedView(
                  state: ref.watchVisible(context, obdServiceProvider),
                  onConnect: () => showObdConnectionSheet(context, ref),
                ),
              )
            : GridView.count(
                padding: const EdgeInsets.all(AppSpacing.lg),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 1.15,
                children: [
                  for (var i = 0; i < _cards.length; i++)
                    if (hidden & (1 << i) == 0)
                      ObdSelect<(String, Color)>(
                        selector: (s) => _cards[i].display(s.telemetry),
                        builder: (context, shown, _) => _buildMetricCard(
                          context,
                          _cards[i].type,
                          _cards[i].label,
                          shown.$1,
                          _cards[i].unit,
                          icon: _cards[i].icon,
                          color: shown.$2,
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    ObdMetricType metricType,
    String label,
    String value,
    String unit, {
    required IconData icon,
    required Color color,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => TelemetryChartModal.show(context, metricType),
        splashColor: color.withOpacity(0.15),
        highlightColor: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        color: color.withOpacity(0.5),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Icon(icon, color: color.withOpacity(0.9), size: 18),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTheme.numberStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Ketuk untuk Grafik',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                          color: color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
