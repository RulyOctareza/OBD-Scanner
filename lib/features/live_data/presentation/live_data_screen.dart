import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/bluetooth/obd_service.dart';
import 'widgets/gauge_widget.dart';

class LiveDataScreen extends ConsumerWidget {
  const LiveDataScreen({super.key});

  bool _isMetricUnsupported(ObdMetricType type, ObdState state) {
    return state.checkedSensors.contains(type) && !state.supportedSensors.contains(type);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obdState = ref.watch(obdServiceProvider);
    final telemetry = obdState.telemetry;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LIVE TELEMETRI',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child:
            obdState.status != ObdStatus.connected &&
                obdState.status != ObdStatus.initializing
            ? _buildNotConnected(obdState)
            : GridView.count(
                padding: const EdgeInsets.all(AppSpacing.lg),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 1.15,
                children: [
                  if (!_isMetricUnsupported(ObdMetricType.rpm, obdState))
                    _buildMetricCard(
                      'RPM',
                      telemetry.rpm.toStringAsFixed(0),
                      'rpm',
                      icon: Icons.speed_rounded,
                      color: telemetry.rpm > 3500
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.speed, obdState))
                    _buildMetricCard(
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
                      'Suhu Pendingin',
                      '${telemetry.coolant.toStringAsFixed(0)}°',
                      'Celsius',
                      icon: Icons.thermostat_rounded,
                      color: telemetry.coolant > 100
                          ? AppColors.danger
                          : (telemetry.coolant > 95
                                ? AppColors.warning
                                : AppColors.success),
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.voltage, obdState))
                    _buildMetricCard(
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
                      'Bukaan Gas',
                      '${telemetry.throttle.toStringAsFixed(0)}%',
                      'Throttle',
                      icon: Icons.airline_seat_recline_extra_rounded,
                      color: AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.engineLoad, obdState))
                    _buildMetricCard(
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
                      'Intake (MAP)',
                      '${telemetry.mapValue.toStringAsFixed(0)}',
                      'kPa',
                      icon: Icons.compress_rounded,
                      color: AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.intakeAirTemp, obdState))
                    _buildMetricCard(
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
                      'MAF',
                      telemetry.maf != null
                          ? telemetry.maf!.toStringAsFixed(1)
                          : '--',
                      'g/s',
                      icon: Icons.air_rounded,
                      color: AppColors.primary,
                    ),
                  if (!_isMetricUnsupported(ObdMetricType.timingAdvance, obdState))
                    _buildMetricCard(
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

  Widget _buildNotConnected(ObdState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mesin Belum Terhubung',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.status == ObdStatus.connecting
                  ? 'Menghubungkan ke ELM327...'
                  : 'Aktifkan Bluetooth mobil atau masuk ke menu Settings untuk mengaktifkan Simulator.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String unit, {
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(icon, color: color.withOpacity(0.8), size: 18),
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
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
