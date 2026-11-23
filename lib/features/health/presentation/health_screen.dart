import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bluetooth/obd_service.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/obd/obd_metric.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/live_obd.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../splash/obd_intro_screen.dart';
import '../../shell/shell_screen.dart';
import '../../timeline/presentation/timeline_screen.dart';
import '../../trips/presentation/trip_provider.dart';
import '../domain/health_engine.dart';
import 'health_provider.dart';

/// Beranda: connection, health summary, what needs attention, the checks
/// behind the score and the last trip.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watchVisible: no rebuilds while this tab is offstage (TickerMode off).
    // Live values and trip progress rebuild only their own widgets below.
    final report = ref.watchVisible(context, healthProvider);
    final vehicleName = ref.watchVisible(
      context,
      settingsProvider.select((s) => s.vehicleName),
    );
    final isRecording = ref.watchVisible(
      context,
      tripRecorderProvider.select((t) => t.isRecording),
    );

    ref.listen(tripRecorderProvider.select((t) => t.lastCompletedTripId), (
      previous,
      next,
    ) {
      if (previous == null && next != null) {
        _showTripSummary(context, ref, next);
      }
    });
    ref.listen(obdServiceProvider.select((s) => s.status), (previous, next) {
      if (previous != ObdStatus.connected && next == ObdStatus.connected) {
        HapticFeedback.lightImpact();
      }
    });
    ref.listen(healthProvider.select((h) => h.warnings.length), (
      previous,
      next,
    ) {
      if (previous != null && next > previous) HapticFeedback.mediumImpact();
    });

    // The first-run adapter path ends here with the connection sheet open.
    if (ref.read(openConnectionSheetOnStartProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !ref.read(openConnectionSheetOnStartProvider)) {
          return;
        }
        ref.read(openConnectionSheetOnStartProvider.notifier).state = false;
        showObdConnectionSheet(context, ref);
      });
    }

    return Scaffold(
      appBar: AppBar(
        // A long name shrinks to fit instead of being cut off.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(vehicleName),
        ),
        actions: [
          if (!ShellLayout.settingsInBarOf(context))
            IconButton(
              tooltip: 'Pengaturan',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go('/settings'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.xs,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        children: [
          const ConnectionStatusBar(),
          const SizedBox(height: AppSpacing.md),
          _HealthSummaryCard(report: report),
          if (isRecording) ...[
            const SizedBox(height: AppSpacing.md),
            const _LiveTripRecordingCard(),
          ],
          if (report.warnings.isNotEmpty) ...[
            const SectionHeader('Perlu perhatian'),
            for (final warning in report.warnings) ...[
              _WarningCard(warning: warning),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const SectionHeader('Pemeriksaan'),
          _ChecksCard(checks: report.checks),
          if (!isRecording) ...[
            SectionHeader(
              'Perjalanan terakhir',
              actionLabel: 'Lihat riwayat',
              onAction: () => context.go('/timeline'),
            ),
            const _LastTripSection(),
          ],
        ],
      ),
    );
  }

  Future<void> _showTripSummary(
    BuildContext context,
    WidgetRef ref,
    int tripId,
  ) async {
    final db = ref.read(databaseProvider);
    final trip = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return;
    ref.read(tripRecorderProvider.notifier).clearLastCompletedTrip();
    if (!context.mounted) return;

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => AppSheet(
        title: 'Perjalanan selesai',
        subtitle: Fmt.relative(trip.startTime),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
        child: _TripStatsGrid(trip: trip),
      ),
    );
  }
}

/// Score ring with title and explanation. Without measurements the ring is
/// empty and says so: no data is never shown as a healthy score.
class _HealthSummaryCard extends StatelessWidget {
  const _HealthSummaryCard({required this.report});

  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scoreText = report.score == null
        ? 'belum ada data'
        : '${report.score} dari 100';
    return Semantics(
      container: true,
      label:
          'Skor kesehatan $scoreText. ${report.statusTitle}. '
          '${report.statusDescription}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            _ScoreRing(score: report.score, level: report.level),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.statusTitle, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(report.statusDescription, style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.level});

  final int? score;
  final StatusLevel level;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppStatusColors.of(context).foreground(level);
    final target = (score ?? 0) / 100;
    // The ring grows a little with the text size; its number and label scale
    // down to stay inside it.
    final size =
        _size *
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4).toDouble();
    // Counts up once when the score changes; nothing animates afterwards.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score == null ? Fmt.pending : '${(value * 100).round()}',
                      style: AppTheme.numberStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text('Skor', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final HealthWarning warning;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusIcon(warning.level, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(warning.title, style: text.titleSmall),
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(warning.detail, style: text.bodyMedium),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go(warning.action.route),
                    child: Text(warning.action.label),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.checks});

  final List<CheckItem> checks;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SettingsGroup(
      children: [
        for (final check in checks)
          ListTile(
            leading: StatusIcon(check.level, size: 32),
            title: Text(check.title),
            subtitle: check.note == null ? null : Text(check.note!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(check.detail, style: text.bodyMedium),
                if (check.action != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ],
            ),
            onTap: check.action == null
                ? null
                : () => context.go(check.action!.route),
          ),
      ],
    );
  }
}

/// Live speed, RPM and trip progress: rebuilds alone, on its own values, in
/// its own layer. The recording mark is static: a pulsing dot would force a
/// frame every vsync for the whole drive.
class _LiveTripRecordingCard extends ConsumerWidget {
  const _LiveTripRecordingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = AppStatusColors.of(context);
    final durationSeconds = ref.watchVisible(
      context,
      tripRecorderProvider.select((t) => t.durationSeconds),
    );
    final distanceKm = ref.watchVisible(
      context,
      tripRecorderProvider.select(
        (t) => (t.currentTripDistance * 10).roundToDouble() / 10,
      ),
    );
    return RepaintBoundary(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fiber_manual_record_rounded,
                  size: 14,
                  color: status.kritis,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Merekam perjalanan', style: text.titleSmall),
                ),
                Text(
                  _clock(durationSeconds),
                  style: AppTheme.numberStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Jarak',
                    value: Fmt.km(distanceKm, decimals: 1),
                  ),
                ),
                Expanded(
                  child: LiveMetric(
                    type: ObdMetricType.speed,
                    step: 1,
                    builder: (context, reading, _) => _Stat(
                      label: 'Kecepatan',
                      value: reading.hasValue
                          ? Fmt.speed(reading.value!)
                          : Fmt.pending,
                    ),
                  ),
                ),
                Expanded(
                  child: LiveMetric(
                    type: ObdMetricType.rpm,
                    step: 1,
                    builder: (context, reading, _) => _Stat(
                      label: 'Putaran mesin',
                      value: reading.hasValue
                          ? Fmt.rpm(reading.value!)
                          : Fmt.pending,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600 ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h.$m.$s' : '$m.$s';
  }
}

class _LastTripSection extends ConsumerWidget {
  const _LastTripSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watchVisible(context, historicalTripsProvider);
    return trips.when(
      data: (list) => list.isEmpty
          ? const AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.directions_car_outlined,
                title: 'Belum ada perjalanan',
                message:
                    'Perjalanan terekam otomatis saat mobil berjalan '
                    'dengan adapter terhubung.',
              ),
            )
          : _LastTripCard(trip: list.first),
      loading: () => const SizedBox(height: 120),
      error: (e, _) => AppCard(
        child: Text(
          'Perjalanan gagal dimuat.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LastTripCard extends ConsumerWidget {
  const _LastTripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () {
        ref.read(timelineFocusTripIdProvider.notifier).state = trip.id;
        ref.read(selectedTypeFilterProvider.notifier).state = TypeFilter.trip;
        context.go('/timeline');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.relative(trip.startTime),
                  style: text.bodyMedium,
                ),
              ),
              StatusChip(
                tripScoreLevel(trip.tripHealthScore),
                label: 'Skor ${trip.tripHealthScore}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Jarak',
                  value: Fmt.km(trip.distance, decimals: 1),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Konsumsi BBM',
                  value: Fmt.kmPerLiter(trip.fuelEconomy),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Durasi',
                  value: Fmt.minutes(trip.durationMinutes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Same bands as the live health score.
StatusLevel tripScoreLevel(int score) => score >= 95
    ? StatusLevel.ok
    : score >= 80
    ? StatusLevel.waspada
    : StatusLevel.kritis;

class _TripStatsGrid extends StatelessWidget {
  const _TripStatsGrid({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat(label: 'Jarak', value: Fmt.km(trip.distance, decimals: 1)),
      _Stat(label: 'Durasi', value: Fmt.minutes(trip.durationMinutes)),
      _Stat(label: 'Kecepatan rata-rata', value: Fmt.speed(trip.avgSpeed)),
      _Stat(label: 'Konsumsi BBM', value: Fmt.kmPerLiter(trip.fuelEconomy)),
      _Stat(label: 'Suhu mesin tertinggi', value: Fmt.celsius(trip.maxCoolant)),
      _Stat(label: 'Putaran tertinggi', value: Fmt.rpm(trip.maxRpm)),
    ];
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          for (var i = 0; i < stats.length; i += 2) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stats[i]),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: stats[i + 1]),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.numberStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
