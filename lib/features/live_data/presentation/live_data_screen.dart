import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import 'widgets/gauge_widget.dart';
import 'widgets/telemetry_chart_modal.dart';

class LiveDataScreen extends ConsumerWidget {
  const LiveDataScreen({super.key});

  bool _isMetricUnsupported(ObdMetricType type, ObdState state) {
    return state.checkedSensors.contains(type) &&
        !state.supportedSensors.contains(type);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obdState = ref.watch(obdServiceProvider);
    final telemetry = obdState.telemetry;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Semua Sensor',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: obdState.status != ObdStatus.connected &&
                obdState.status != ObdStatus.initializing
            ? ObdNotConnectedView(
                state: obdState,
                onConnect: () => showObdConnectionSheet(context, ref),
              )
            : GridView.count(
                padding: const EdgeInsets.all(AppSpacing.lg),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 1.15,
                children: [
                  if (!_isMetricUnsupported(ObdMetricType.rpm, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.rpm,
                      'Putaran Mesin',
                      telemetry.rpm.toStringAsFixed(0),
                      'RPM',
                      icon: Icons.speed_rounded,
                      color: telemetry.rpm > 3500
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.speed, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.speed,
                      'Kecepatan',
                      telemetry.speed.toStringAsFixed(0),
                      'km/h',
                      icon: Icons.navigation_rounded,
                      color: telemetry.speed > 100
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.coolant, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.coolant,
                      'Suhu Pendingin',
                      '${telemetry.coolant.toStringAsFixed(0)}°',
                      '°C',
                      icon: Icons.thermostat_rounded,
                      color: telemetry.coolant > 100
                          ? AppColors.danger
                          : (telemetry.coolant > 95
                              ? AppColors.warning
                              : AppColors.success),
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.voltage, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.voltage,
                      'Tegangan Aki',
                      '${telemetry.voltage.toStringAsFixed(1)}V',
                      'Volt',
                      icon: Icons.battery_charging_full_rounded,
                      color: telemetry.voltage < 11.8
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.throttle, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.throttle,
                      'Bukaan Gas',
                      '${telemetry.throttle.toStringAsFixed(0)}%',
                      'Throttle',
                      icon: Icons.airline_seat_recline_extra_rounded,
                      color: AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.engineLoad, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.engineLoad,
                      'Beban Mesin',
                      '${telemetry.engineLoad.toStringAsFixed(0)}%',
                      'Engine Load',
                      icon: Icons.work_rounded,
                      color: telemetry.engineLoad > 85
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.map, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.map,
                      'Tekanan Intake',
                      '${telemetry.mapValue.toStringAsFixed(0)}',
                      'MAP · kPa',
                      icon: Icons.compress_rounded,
                      color: AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(
                    ObdMetricType.intakeAirTemp,
                    obdState,
                  ))
                    _buildMetricCard(
                      context,
                      ObdMetricType.intakeAirTemp,
                      'Suhu Intake',
                      telemetry.intakeAirTemp != null
                          ? '${telemetry.intakeAirTemp!.toStringAsFixed(0)}°'
                          : '--',
                      '°C',
                      icon: Icons.ac_unit_rounded,
                      color: telemetry.intakeAirTemp != null
                          ? (telemetry.intakeAirTemp! > 70
                              ? AppColors.danger
                              : telemetry.intakeAirTemp! > 50
                                  ? AppColors.warning
                                  : AppColors.success)
                          : AppColors.textSecondary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.maf, obdState))
                    _buildMetricCard(
                      context,
                      ObdMetricType.maf,
                      'Aliran Udara',
                      telemetry.maf != null
                          ? telemetry.maf!.toStringAsFixed(1)
                          : '--',
                      'MAF · g/s',
                      icon: Icons.air_rounded,
                      color: AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(
                    ObdMetricType.timingAdvance,
                    obdState,
                  ))
                    _buildMetricCard(
                      context,
                      ObdMetricType.timingAdvance,
                      'Timing Advance',
                      telemetry.timingAdvance != null
                          ? telemetry.timingAdvance!.toStringAsFixed(1)
                          : '--',
                      '°',
                      icon: Icons.flash_on_rounded,
                      color: AppColors.primary,
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
