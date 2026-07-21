import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/obd_telemetry.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import 'widgets/gauge_widget.dart';
import 'widgets/telemetry_chart_modal.dart';
import '../../trips/presentation/trip_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  double? _getValueForMetric(ObdMetricType type, ObdTelemetry telemetry) {
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
      case ObdMetricType.fuelEconomy:
        return telemetry.fuelEconomy;
      case ObdMetricType.intakeAirTemp:
        return telemetry.intakeAirTemp;
      case ObdMetricType.maf:
        return telemetry.maf;
      case ObdMetricType.timingAdvance:
        return telemetry.timingAdvance;
    }
  }

  bool _isMetricUnsupported(ObdMetricType type, ObdState state) {
    return state.checkedSensors.contains(type) &&
        !state.supportedSensors.contains(type);
  }

  void _showMetricSelector({
    required BuildContext context,
    required WidgetRef ref,
    required int spotIndex,
    required ObdMetricType currentSelection,
    required ObdTelemetry telemetry,
  }) {
    final obdState = ref.read(obdServiceProvider);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Indikator Meter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      TelemetryChartModal.show(context, currentSelection);
                    },
                    icon: const Icon(Icons.show_chart_rounded, size: 18, color: AppColors.primary),
                    label: const Text(
                      'Grafik',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: ObdMetricConfig.all
                      .where((config) {
                        final isChecked = obdState.checkedSensors.contains(
                          config.type,
                        );
                        final isSupported = obdState.supportedSensors.contains(
                          config.type,
                        );
                        return !(isChecked && !isSupported);
                      })
                      .map((config) {
                        final isSelected = config.type == currentSelection;
                        final val = _getValueForMetric(config.type, telemetry);
                        final isVoltageOrFuelEco =
                            config.type == ObdMetricType.voltage ||
                            config.type == ObdMetricType.fuelEconomy;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: config.color.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: config.color,
                          ),
                          title: Text(
                            config.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Text(
                            val == null
                                ? '-- ${config.unit}'
                                : (config.type == ObdMetricType.fuelEconomy &&
                                      val == 0.0)
                                ? '-- ${config.unit}'
                                : '${val.toStringAsFixed(isVoltageOrFuelEco ? 1 : 0)} ${config.unit}',
                            style: TextStyle(
                              color: config.color,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          onTap: () {
                            ref
                                .read(settingsProvider.notifier)
                                .setMetricAt(spotIndex, config.type);
                            Navigator.pop(context);
                          },
                        );
                      })
                      .toList(),
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

    final settings = ref.watch(settingsProvider.select((s) => (
          left: s.leftMetric,
          right: s.rightMetric,
          fullscreen: s.isFullscreenCockpit,
          sm1: s.smallMetric1,
          sm2: s.smallMetric2,
          sm3: s.smallMetric3,
          sm4: s.smallMetric4,
        )));
    final leftMetricType = settings.left;
    final rightMetricType = settings.right;

    final leftConfig = ObdMetricConfig.all.firstWhere(
      (c) => c.type == leftMetricType,
    );
    final rightConfig = ObdMetricConfig.all.firstWhere(
      (c) => c.type == rightMetricType,
    );

    final isFullscreen = settings.fullscreen;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait &&
        !isFullscreen;

    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              title: const Text(
                'Meter Cockpit',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded),
                  tooltip: 'Layar Penuh',
                  onPressed: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setFullscreenCockpit(true);
                  },
                ),
              ],
            ),
      body: SafeArea(
        child: Stack(
          children: [
            obdState.status != ObdStatus.connected &&
                    obdState.status != ObdStatus.initializing
                ? ObdNotConnectedView(
                    state: obdState,
                    onConnect: () => showObdConnectionSheet(context, ref),
                  )
                : Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 12.0,
                        right: 12.0,
                        top: isFullscreen ? 36.0 : 8.0,
                        bottom: 4.0,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showTripHeader =
                              obdState.status == ObdStatus.connected ||
                              obdState.status == ObdStatus.initializing;

                          Widget leftGauge({required bool compact}) {
                            return GaugeWidget(
                              value: _getValueForMetric(
                                leftMetricType,
                                telemetry,
                              ),
                              config: leftConfig,
                              compact: compact,
                              onTap: () => _showMetricSelector(
                                context: context,
                                ref: ref,
                                spotIndex: 0,
                                currentSelection: leftMetricType,
                                telemetry: telemetry,
                              ),
                            );
                          }

                          Widget rightGauge({required bool compact}) {
                            return GaugeWidget(
                              value: _getValueForMetric(
                                rightMetricType,
                                telemetry,
                              ),
                              config: rightConfig,
                              compact: compact,
                              onTap: () => _showMetricSelector(
                                context: context,
                                ref: ref,
                                spotIndex: 1,
                                currentSelection: rightMetricType,
                                telemetry: telemetry,
                              ),
                            );
                          }

                          Widget flexibleGauge(Widget gauge) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: gauge,
                                  ),
                                ),
                              ),
                            );
                          }

                          final statsGrid = isPortrait
                              ? SizedBox(
                                  height: 100,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (!_isMetricUnsupported(
                                              settings.sm1,
                                              obdState,
                                            ))
                                              _buildInteractiveSmallStatCard(
                                                context: context,
                                                ref: ref,
                                                spotIndex: 2,
                                                metricType: settings.sm1,
                                                telemetry: telemetry,
                                              ),
                                            if (!_isMetricUnsupported(
                                              settings.sm2,
                                              obdState,
                                            ))
                                              _buildInteractiveSmallStatCard(
                                                context: context,
                                                ref: ref,
                                                spotIndex: 3,
                                                metricType: settings.sm2,
                                                telemetry: telemetry,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (!_isMetricUnsupported(
                                              settings.sm3,
                                              obdState,
                                            ))
                                              _buildInteractiveSmallStatCard(
                                                context: context,
                                                ref: ref,
                                                spotIndex: 4,
                                                metricType: settings.sm3,
                                                telemetry: telemetry,
                                              ),
                                            if (!_isMetricUnsupported(
                                              settings.sm4,
                                              obdState,
                                            ))
                                              _buildInteractiveSmallStatCard(
                                                context: context,
                                                ref: ref,
                                                spotIndex: 5,
                                                metricType: settings.sm4,
                                                telemetry: telemetry,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SizedBox(
                                  height: 52,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      if (!_isMetricUnsupported(
                                        settings.sm1,
                                        obdState,
                                      ))
                                        _buildInteractiveSmallStatCard(
                                          context: context,
                                          ref: ref,
                                          spotIndex: 2,
                                          metricType: settings.sm1,
                                          telemetry: telemetry,
                                        ),
                                      if (!_isMetricUnsupported(
                                        settings.sm2,
                                        obdState,
                                      ))
                                        _buildInteractiveSmallStatCard(
                                          context: context,
                                          ref: ref,
                                          spotIndex: 3,
                                          metricType: settings.sm2,
                                          telemetry: telemetry,
                                        ),
                                      if (!_isMetricUnsupported(
                                        settings.sm3,
                                        obdState,
                                      ))
                                        _buildInteractiveSmallStatCard(
                                          context: context,
                                          ref: ref,
                                          spotIndex: 4,
                                          metricType: settings.sm3,
                                          telemetry: telemetry,
                                        ),
                                      if (!_isMetricUnsupported(
                                        settings.sm4,
                                        obdState,
                                      ))
                                        _buildInteractiveSmallStatCard(
                                          context: context,
                                          ref: ref,
                                          spotIndex: 5,
                                          metricType: settings.sm4,
                                          telemetry: telemetry,
                                        ),
                                    ],
                                  ),
                                );

                          // Fit gauges + 4 indicators on one screen (no scroll).
                          return Column(
                            children: [
                              if (showTripHeader) ...[
                                _buildTripHeaderRow(
                                  context,
                                  ref,
                                  telemetry,
                                  isPortrait: isPortrait,
                                ),
                                SizedBox(height: isPortrait ? 6 : 8),
                              ],
                              if (isPortrait) ...[
                                flexibleGauge(leftGauge(compact: true)),
                                const SizedBox(height: 4),
                                flexibleGauge(rightGauge(compact: true)),
                              ] else
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: leftGauge(compact: false),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: rightGauge(compact: false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(height: isPortrait ? 8 : 10),
                              statsGrid,
                            ],
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
                        ref
                            .read(settingsProvider.notifier)
                            .setFullscreenCockpit(false);
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

  Widget _buildTripHeaderRow(
    BuildContext context,
    WidgetRef ref,
    ObdTelemetry telemetry, {
    required bool isPortrait,
  }) {
    final ecoBadge = AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: telemetry.isEcoMode ? 1.0 : 0.2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
          boxShadow: telemetry.isEcoMode
              ? [
                  BoxShadow(
                    color: const Color(0xFF33FF33).withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.eco_rounded,
              color: telemetry.isEcoMode
                  ? const Color(0xFF33FF33)
                  : Colors.white30,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'ECO MODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: telemetry.isEcoMode
                    ? const Color(0xFF33FF33)
                    : Colors.white30,
              ),
            ),
          ],
        ),
      ),
    );

    final tripARecord = GestureDetector(
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
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
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
              const Icon(
                Icons.trip_origin_rounded,
                color: Colors.blueAccent,
                size: 12,
              ),
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
    );

    final tripBRecord = GestureDetector(
      onLongPress: () => _showResetTripBDialog(context, ref),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tekan lama untuk mereset Trip B'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
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
              const Icon(
                Icons.today_rounded,
                color: Colors.orangeAccent,
                size: 12,
              ),
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
    );

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: ecoBadge),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: tripARecord),
              const SizedBox(width: 8),
              Expanded(child: tripBRecord),
            ],
          ),
        ],
      );
    }

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
                    child: tripARecord,
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
                    child: tripBRecord,
                  ),
                ),
              ),
            ),
          ],
        ),
        Align(alignment: Alignment.center, child: ecoBadge),
      ],
    );
  }

  Widget _buildInteractiveSmallStatCard({
    required BuildContext context,
    required WidgetRef ref,
    required int spotIndex,
    required ObdMetricType metricType,
    required ObdTelemetry telemetry,
  }) {
    final config = ObdMetricConfig.all.firstWhere((c) => c.type == metricType);
    final value = _getValueForMetric(metricType, telemetry);
    final isVoltageOrFuelEco =
        metricType == ObdMetricType.voltage ||
        metricType == ObdMetricType.fuelEconomy;
    final valueText = value == null
        ? '-- ${config.unit}'
        : (metricType == ObdMetricType.fuelEconomy && value == 0.0)
        ? '-- ${config.unit}'
        : '${value.toStringAsFixed(isVoltageOrFuelEco ? 1 : 0)} ${config.unit}';

    return Expanded(
      child: GestureDetector(
        onTap: () => TelemetryChartModal.show(context, metricType),
        onLongPress: () => _showMetricSelector(
          context: context,
          ref: ref,
          spotIndex: spotIndex,
          currentSelection: metricType,
          telemetry: telemetry,
        ),
        child: _buildSmallStatCard(
          label: config.label,
          value: valueText,
          icon: _getMetricIcon(metricType),
          color: config.color,
        ),
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

  Widget _buildSmallStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 7.5,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.1,
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

  void _showResetTripADialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Reset Trip A?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Apakah Anda ingin mereset jarak akumulasi Trip A kembali ke 0.0 km?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'BATAL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(tripRecorderProvider.notifier).resetTripA();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip A berhasil di-reset')),
                );
              },
              child: const Text(
                'RESET',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResetTripBDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Reset Trip B?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Apakah Anda ingin mereset jarak akumulasi Trip B kembali ke 0.0 km?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'BATAL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(tripRecorderProvider.notifier).resetTripB();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip B berhasil di-reset')),
                );
              },
              child: const Text(
                'RESET',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
