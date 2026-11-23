import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/obd_service.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/live_obd.dart';
import 'widgets/gauge_widget.dart';
import 'widgets/telemetry_chart_modal.dart';

/// Order of the Sensor list: what a driver checks first comes first.
const List<ObdMetricType> _order = [
  ObdMetricType.speed,
  ObdMetricType.rpm,
  ObdMetricType.coolant,
  ObdMetricType.voltage,
  ObdMetricType.fuel,
  ObdMetricType.fuelEconomy,
  ObdMetricType.engineLoad,
  ObdMetricType.throttle,
  ObdMetricType.map,
  ObdMetricType.intakeAirTemp,
  ObdMetricType.maf,
  ObdMetricType.timingAdvance,
];

/// Live › Sensor: every metric as one row, tap for its chart. Metrics this
/// car does not report move to the end and say so.
class LiveDataScreen extends ConsumerWidget {
  const LiveDataScreen({super.key});

  /// Bit i set when metric i of [_order] was asked and the car does not
  /// answer it.
  static int _unsupportedMask(ObdState state) {
    var mask = 0;
    for (var i = 0; i < _order.length; i++) {
      final type = _order[i];
      if (state.checkedSensors.contains(type) &&
          !state.supportedSensors.contains(type)) {
        mask |= 1 << i;
      }
    }
    return mask;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The list rebuilds only when the link status or the set of unsupported
    // metrics changes; each row rebuilds when its own value changes, and
    // nothing rebuilds while this tab is offstage.
    final status = ref.watchVisible(
      context,
      obdServiceProvider.select((s) => s.status),
    );
    final unsupported = ref.watchVisible(
      context,
      obdServiceProvider.select(_unsupportedMask),
    );
    final isLinkUp =
        status == ObdStatus.connected || status == ObdStatus.initializing;

    final reported = [
      for (var i = 0; i < _order.length; i++)
        if (unsupported & (1 << i) == 0) _order[i],
    ];
    final missing = [
      for (var i = 0; i < _order.length; i++)
        if (unsupported & (1 << i) != 0) _order[i],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const SegmentSwitch(
          segments: liveSegments,
          current: '/live_data',
        ),
      ),
      body: !isLinkUp
          ? const LivePlaceholder(
              icon: Icons.view_list_rounded,
              title: 'Sensor belum aktif',
              message: 'Nilai semua sensor tampil di sini setelah adapter '
                  'terhubung.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              children: [
                SettingsGroup(
                  children: [
                    for (final type in reported)
                      LiveMetricRow(
                        type,
                        onTap: () => TelemetryChartModal.show(context, type),
                      ),
                  ],
                ),
                if (missing.isNotEmpty) ...[
                  const SectionHeader('Tidak dilaporkan mobil ini'),
                  AppCard(
                    child: Text(
                      missing.map((t) => ObdMetricConfig.of(t).label).join(', '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
