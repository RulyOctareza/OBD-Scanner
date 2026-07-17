import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/obd_telemetry.dart';
import 'widgets/gauge_widget.dart';
import '../../trips/presentation/trip_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  double _getValueForMetric(ObdMetricType type, ObdTelemetry telemetry) {
    switch (type) {
      case ObdMetricType.rpm:
        return telemetry.rpm;
      case ObdMetricType.speed:
        return telemetry.speed;
      case ObdMetricType.coolant:
        return telemetry.coolant;
      case ObdMetricType.voltage:
        return telemetry.voltage;
      case ObdMetricType.throttle:
        return telemetry.throttle;
      case ObdMetricType.engineLoad:
        return telemetry.engineLoad;
      case ObdMetricType.map:
        return telemetry.mapValue;
      case ObdMetricType.fuel:
        return telemetry.fuelLevel;
    }
  }

  void _showMetricSelector({
    required BuildContext context,
    required WidgetRef ref,
    required bool isLeft,
    required ObdMetricType currentSelection,
    required ObdTelemetry telemetry,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PILIH INDIKATOR METER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: ObdMetricConfig.all.map((config) {
                    final isSelected = config.type == currentSelection;
                    final val = _getValueForMetric(config.type, telemetry);
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: config.color.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: config.color,
                      ),
                      title: Text(
                        config.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '${val.toStringAsFixed(config.type == ObdMetricType.voltage ? 1 : 0)} ${config.unit}',
                        style: TextStyle(
                          color: config.color,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      onTap: () {
                        final leftVal = ref.read(settingsProvider).leftMetric;
                        final rightVal = ref.read(settingsProvider).rightMetric;

                        if (isLeft) {
                          if (config.type == rightVal) {
                            ref.read(settingsProvider.notifier).updateLeftMetric(config.type);
                            ref.read(settingsProvider.notifier).updateRightMetric(leftVal);
                          } else {
                            ref.read(settingsProvider.notifier).updateLeftMetric(config.type);
                          }
                        } else {
                          if (config.type == leftVal) {
                            ref.read(settingsProvider.notifier).updateRightMetric(config.type);
                            ref.read(settingsProvider.notifier).updateLeftMetric(rightVal);
                          } else {
                            ref.read(settingsProvider.notifier).updateRightMetric(config.type);
                          }
                        }
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obdState = ref.watch(obdServiceProvider);
    final telemetry = obdState.telemetry;
    
    final settings = ref.watch(settingsProvider);
    final leftMetricType = settings.leftMetric;
    final rightMetricType = settings.rightMetric;

    final leftConfig = ObdMetricConfig.all.firstWhere((c) => c.type == leftMetricType);
    final rightConfig = ObdMetricConfig.all.firstWhere((c) => c.type == rightMetricType);

    final isFullscreen = settings.isFullscreenCockpit;

    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              title: const Text(
                'OBD2 COCKPIT METER',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded),
                  tooltip: 'Fullscreen',
                  onPressed: () {
                    ref.read(settingsProvider.notifier).setFullscreenCockpit(true);
                  },
                ),
              ],
            ),
      body: SafeArea(
        child: Stack(
          children: [
            obdState.status != ObdStatus.connected &&
                    obdState.status != ObdStatus.initializing
                ? _buildNotConnected(obdState)
                : Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: isFullscreen ? 36.0 : 12.0,
                        bottom: 8.0,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  children: [
                                    if (obdState.status == ObdStatus.connected ||
                                        obdState.status == ObdStatus.initializing) ...[
                                      _buildTripHeaderRow(context, ref, telemetry),
                                      const SizedBox(height: 8),
                                    ],
                                    // 1. Main Gauges Row
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: GaugeWidget(
                                                value: _getValueForMetric(leftMetricType, telemetry),
                                                config: leftConfig,
                                                onTap: () => _showMetricSelector(
                                                  context: context,
                                                  ref: ref,
                                                  isLeft: true,
                                                  currentSelection: leftMetricType,
                                                  telemetry: telemetry,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: GaugeWidget(
                                                value: _getValueForMetric(rightMetricType, telemetry),
                                                config: rightConfig,
                                                onTap: () => _showMetricSelector(
                                                  context: context,
                                                  ref: ref,
                                                  isLeft: false,
                                                  currentSelection: rightMetricType,
                                                  telemetry: telemetry,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // 2. Small Stats Row (Secondary Indicators)
                                    SizedBox(
                                      height: 52,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildSmallStatCard(
                                            label: 'AKI VOLTS',
                                            value: '${telemetry.voltage.toStringAsFixed(1)} V',
                                            icon: Icons.battery_charging_full_rounded,
                                            color: Colors.purpleAccent,
                                          ),
                                          _buildSmallStatCard(
                                            label: 'SUHU MESIN',
                                            value: '${telemetry.coolant.toStringAsFixed(0)} °C',
                                            icon: Icons.thermostat_rounded,
                                            color: Colors.orangeAccent,
                                          ),
                                          _buildSmallStatCard(
                                            label: 'LEVEL BENSIN',
                                            value: '${telemetry.fuelLevel.toStringAsFixed(0)} %',
                                            icon: Icons.local_gas_station_rounded,
                                            color: Colors.amber,
                                          ),
                                          _buildSmallStatCard(
                                            label: 'KONSUMSI BBM',
                                            value: telemetry.fuelEconomy == 0.0
                                                ? '-- km/L'
                                                : '${telemetry.fuelEconomy.toStringAsFixed(1)} km/L',
                                            icon: Icons.analytics_rounded,
                                            color: Colors.greenAccent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            if (isFullscreen)
              Positioned(
                top: 16,
                right: 16,
                child: ClipOval(
                  child: Material(
                    color: Colors.black38,
                    child: InkWell(
                      onTap: () {
                        ref.read(settingsProvider.notifier).setFullscreenCockpit(false);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.fullscreen_exit_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeaderRow(BuildContext context, WidgetRef ref, ObdTelemetry telemetry) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: GestureDetector(
                      onLongPress: () => _showResetTripADialog(context, ref),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tekan lama untuk mereset Trip A'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.trip_origin_rounded, color: Colors.blueAccent, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                'TRIP A: ${ref.watch(tripRecorderProvider).tripADistance.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.today_rounded, color: Colors.orangeAccent, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              'TRIP B: ${ref.watch(tripRecorderProvider).tripBDistance.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: telemetry.isEcoMode ? 1.0 : 0.15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: telemetry.isEcoMode 
                    ? const Color(0xFF33FF33).withOpacity(0.15) 
                    : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: telemetry.isEcoMode 
                      ? const Color(0xFF33FF33) 
                      : Colors.white24,
                  width: 1.5,
                ),
                boxShadow: telemetry.isEcoMode ? [
                  BoxShadow(
                    color: const Color(0xFF33FF33).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco_rounded,
                    color: telemetry.isEcoMode ? const Color(0xFF33FF33) : Colors.white30,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ECO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: telemetry.isEcoMode ? const Color(0xFF33FF33) : Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
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
            const Icon(
              Icons.dashboard_customize_outlined,
              size: 64,
              color: Colors.white24,
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

  void _showResetTripADialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Reset Trip A?', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Apakah Anda ingin mereset jarak akumulasi Trip A kembali ke 0.0 km?', style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                ref.read(tripRecorderProvider.notifier).resetTripA();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip A berhasil di-reset')),
                );
              },
              child: const Text('RESET', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

}
