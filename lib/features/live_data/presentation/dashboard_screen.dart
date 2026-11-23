import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/obd_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/live_obd.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../trips/presentation/trip_provider.dart';
import 'widgets/gauge_widget.dart';
import 'widgets/telemetry_chart_modal.dart';

enum _MeterAction { arrange, resetTripA, resetTripB }

/// Live › Meter: two gauges and four tiles the driver chooses, Trip A/B and
/// the ECO hint; landscape cockpit when fullscreen.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// "Atur tampilan": taps choose metrics instead of opening charts.
  bool _arranging = false;

  /// Slot indexes of SettingsNotifier.setMetricAt: 0–1 gauges, 2–5 tiles.
  void _onSlotTap(int slot, ObdMetricType current) {
    if (_arranging) {
      _pickMetric(slot, current);
    } else {
      TelemetryChartModal.show(context, current);
    }
  }

  Future<void> _pickMetric(int slot, ObdMetricType current) async {
    final state = ref.read(obdServiceProvider);
    final choice = await showAppSheet<ObdMetricType>(
      context: context,
      builder: (sheetContext) => AppSheet(
        title: slot < 2 ? 'Pilih isi meter' : 'Pilih isi kotak',
        subtitle: 'Data yang tidak dilaporkan mobil ini tidak ditampilkan.',
        child: Column(
          children: [
            for (final config in ObdMetricConfig.all)
              if (!(state.checkedSensors.contains(config.type) &&
                  !state.supportedSensors.contains(config.type)))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(MetricDisplay.icon(config.type)),
                  title: Text(config.label),
                  trailing: config.type == current
                      ? Icon(Icons.check_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary)
                      : null,
                  selected: config.type == current,
                  onTap: () => Navigator.of(sheetContext).pop(config.type),
                ),
          ],
        ),
      ),
    );
    if (choice != null && choice != current) {
      await ref.read(settingsProvider.notifier).setMetricAt(slot, choice);
    }
  }

  Future<void> _resetTrip({required bool tripA}) async {
    final name = tripA ? 'Trip A' : 'Trip B';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset $name?',
      message: 'Jarak $name kembali ke 0 km. Riwayat perjalanan tidak berubah.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed) return;
    final trips = ref.read(tripRecorderProvider.notifier);
    await (tripA ? trips.resetTripA() : trips.resetTripB());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name direset ke 0 km')));
  }

  void _onMenu(_MeterAction action) {
    switch (action) {
      case _MeterAction.arrange:
        setState(() => _arranging = true);
      case _MeterAction.resetTripA:
        _resetTrip(tripA: true);
      case _MeterAction.resetTripB:
        _resetTrip(tripA: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the link status and the chosen metrics are watched here; each
    // gauge, tile, the ECO hint and the trip counters rebuild on their own
    // values, and nothing rebuilds while this tab is offstage.
    final status = ref.watchVisible(
      context,
      obdServiceProvider.select((s) => s.status),
    );
    final isLinkUp =
        status == ObdStatus.connected || status == ObdStatus.initializing;
    final layout = ref.watchVisible(
      context,
      settingsProvider.select(
        (s) => (
          left: s.leftMetric,
          right: s.rightMetric,
          fullscreen: s.isFullscreenCockpit,
          tiles: [s.smallMetric1, s.smallMetric2, s.smallMetric3, s.smallMetric4],
        ),
      ),
    );
    final isFullscreen = layout.fullscreen;

    Widget gauge(int slot, ObdMetricType type, {required bool compact}) =>
        _LiveGauge(
          type: type,
          compact: compact,
          onTap: () => _onSlotTap(slot, type),
        );
    Widget tile(int index) {
      final type = layout.tiles[index];
      return LiveMetricTile(
        type,
        size: MetricTileSize.compact,
        onTap: () => _onSlotTap(index + 2, type),
      );
    }

    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              title: const SegmentSwitch(
                segments: liveSegments,
                current: '/dashboard',
              ),
              actions: [
                if (isLinkUp)
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded),
                    tooltip: 'Layar penuh',
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .setFullscreenCockpit(true),
                  ),
                PopupMenuButton<_MeterAction>(
                  tooltip: 'Lainnya',
                  onSelected: _onMenu,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MeterAction.arrange,
                      child: Text('Atur tampilan'),
                    ),
                    PopupMenuItem(
                      value: _MeterAction.resetTripA,
                      child: Text('Reset Trip A'),
                    ),
                    PopupMenuItem(
                      value: _MeterAction.resetTripB,
                      child: Text('Reset Trip B'),
                    ),
                  ],
                ),
              ],
            ),
      body: !isLinkUp
          ? const LivePlaceholder(
              icon: Icons.speed_rounded,
              title: 'Meter belum aktif',
              message: 'Meter live tampil setelah adapter terhubung.',
            )
          : SafeArea(
              child: isFullscreen
                  ? _clampCockpitText(
                      context,
                      _Cockpit(
                        left: gauge(0, layout.left, compact: false),
                        right: gauge(1, layout.right, compact: false),
                        tiles: [for (var i = 0; i < 4; i++) tile(i)],
                        onExit: () => ref
                            .read(settingsProvider.notifier)
                            .setFullscreenCockpit(false),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.xs,
                        AppSpacing.screen,
                        AppSpacing.xl,
                      ),
                      children: [
                        if (_arranging) ...[
                          _ArrangeBanner(
                            onDone: () => setState(() => _arranging = false),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        const _TripRow(),
                        const SizedBox(height: AppSpacing.md),
                        // No IntrinsicHeight here: the gauges size their
                        // dial with a LayoutBuilder, which has no intrinsics.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: gauge(0, layout.left, compact: true)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: gauge(1, layout.right, compact: true)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (var row = 0; row < 2; row++) ...[
                          if (row > 0) const SizedBox(height: AppSpacing.md),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: tile(row * 2)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: tile(row * 2 + 1)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
    );
  }
}

/// A gauge on one metric, rebuilt only on that metric's reading (and, for
/// voltage, on whether the engine runs).
class _LiveGauge extends StatelessWidget {
  const _LiveGauge({
    required this.type,
    required this.compact,
    required this.onTap,
  });

  final ObdMetricType type;
  final bool compact;
  final VoidCallback onTap;

  Widget _gauge(MetricReading reading, {bool engineRunning = false}) {
    return GaugeWidget(
      value: reading.hasValue ? reading.value : null,
      config: ObdMetricConfig.of(type),
      compact: compact,
      assessment: assessReading(type, reading, engineRunning: engineRunning),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A needle shows every change, so no display step here.
    return assessmentNeedsRpm(type)
        ? ObdSelect<(MetricReading, bool)>(
            selector: (s) => (readingOf(s, type), isEngineRunning(s.telemetry.rpm)),
            builder: (context, v, _) => _gauge(v.$1, engineRunning: v.$2),
          )
        : LiveMetric(
            type: type,
            builder: (context, reading, _) => _gauge(reading),
          );
  }
}

class _ArrangeBanner extends StatelessWidget {
  const _ArrangeBanner({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_customize_rounded,
              color: scheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Ketuk meter atau kotak untuk menggantinya.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          TextButton(onPressed: onDone, child: const Text('Selesai')),
        ],
      ),
    );
  }
}

/// Trip A, Trip B and the ECO hint, each in its own layer.
class _TripRow extends StatelessWidget {
  const _TripRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _TripCounter(tripA: true)),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: _TripCounter(tripA: false)),
        const SizedBox(width: AppSpacing.sm),
        RepaintBoundary(
          child: ObdSelect<bool>(
            selector: (s) => s.telemetry.isEcoMode,
            // The slot keeps its size, so nothing shifts when ECO toggles.
            builder: (context, eco, _) => Visibility(
              visible: eco,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: const _EcoChip(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TripCounter extends ConsumerWidget {
  const _TripCounter({required this.tripA});

  final bool tripA;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final km = ref.watchVisible(
      context,
      tripRecorderProvider.select(
        (t) => ((tripA ? t.tripADistance : t.tripBDistance) * 10).round() / 10,
      ),
    );
    final label = tripA ? 'Trip A' : 'Trip B';
    final value = Fmt.km(km, decimals: 1);
    return RepaintBoundary(
      child: Semantics(
        container: true,
        label: '$label $value',
        excludeSemantics: true,
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordFitText(label, style: text.bodySmall),
              LineFitText(
                value,
                style: AppTheme.numberStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcoChip extends StatelessWidget {
  const _EcoChip();

  @override
  Widget build(BuildContext context) {
    final status = AppStatusColors.of(context);
    return Semantics(
      label: 'Mode hemat BBM',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: status.okContainer,
          borderRadius: AppRadius.chipBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_rounded, size: 18, color: status.ok),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Hemat',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: status.ok),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cockpit fills one landscape screen without scrolling; above 1.3x
/// system text its tiles leave the gauges too little height, so its text
/// stops growing there.
Widget _clampCockpitText(BuildContext context, Widget cockpit) =>
    MediaQuery.textScalerOf(context).scale(100) > 130
        ? MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: cockpit)
        : cockpit;

/// Landscape fullscreen: trips on top, two large gauges, four tiles below.
class _Cockpit extends StatelessWidget {
  const _Cockpit({
    required this.left,
    required this.right,
    required this.tiles,
    required this.onExit,
  });

  final Widget left;
  final Widget right;
  final List<Widget> tiles;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: _TripRow()),
              const SizedBox(width: AppSpacing.md),
              IconButton.filledTonal(
                tooltip: 'Keluar layar penuh',
                icon: const Icon(Icons.fullscreen_exit_rounded),
                onPressed: onExit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: left),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: right),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
