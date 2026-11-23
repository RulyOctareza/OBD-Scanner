import 'package:drift/drift.dart' show OrderingMode, OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../trips/presentation/trip_provider.dart';

enum TimelineEventType { trip, fuel, maintenance }

class TimelineEvent {
  final int id;
  final DateTime timestamp;
  final TimelineEventType type;
  final String title;
  final String description;
  final String value;
  final String? subValue;
  // Raw values for the summary.
  final double? rawDistance;
  final double? rawCost;
  final double? rawFuelEconomy;

  TimelineEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.description,
    required this.value,
    this.subValue,
    this.rawDistance,
    this.rawCost,
    this.rawFuelEconomy,
  });
}

enum DateFilter { all, today, thisWeek, thisMonth, thisYear }

enum TypeFilter { all, trip, fuel, maintenance }

String _dateFilterLabel(DateFilter filter) => switch (filter) {
      DateFilter.all => 'Semua waktu',
      DateFilter.today => 'Hari ini',
      DateFilter.thisWeek => 'Minggu ini',
      DateFilter.thisMonth => 'Bulan ini',
      DateFilter.thisYear => 'Tahun ini',
    };

String _typeFilterLabel(TypeFilter filter) => switch (filter) {
      TypeFilter.all => 'Semua',
      TypeFilter.trip => 'Perjalanan',
      TypeFilter.fuel => 'Isi BBM',
      TypeFilter.maintenance => 'Servis',
    };

final selectedDateFilterProvider = StateProvider<DateFilter>(
  (ref) => DateFilter.all,
);
final selectedTypeFilterProvider = StateProvider<TypeFilter>(
  (ref) => TypeFilter.all,
);

/// A trip opened from Beranda's "Perjalanan terakhir", shown highlighted.
final timelineFocusTripIdProvider = StateProvider<int?>((ref) => null);

final fuelLogsProvider = StreamProvider<List<FuelLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.fuelLogs)..orderBy([
        (f) => OrderingTerm(expression: f.timestamp, mode: OrderingMode.desc),
      ]))
      .watch();
});

final maintenanceLogsProvider = StreamProvider<List<MaintenanceLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.maintenanceLogs)..orderBy([
        (m) => OrderingTerm(expression: m.timestamp, mode: OrderingMode.desc),
      ]))
      .watch();
});

String _serviceLabel(String type) => AppConstants.maintenanceTypes[type] ?? type;

final timelineEventsProvider = Provider<AsyncValue<List<TimelineEvent>>>((ref) {
  final tripsAsync = ref.watch(historicalTripsProvider);
  final fuelAsync = ref.watch(fuelLogsProvider);
  final maintAsync = ref.watch(maintenanceLogsProvider);

  if (tripsAsync.isLoading || fuelAsync.isLoading || maintAsync.isLoading) {
    return const AsyncValue.loading();
  }
  for (final async in [tripsAsync, fuelAsync, maintAsync]) {
    if (async.hasError) return AsyncValue.error(async.error!, async.stackTrace!);
  }

  final events = <TimelineEvent>[
    for (final trip in tripsAsync.value ?? const <Trip>[])
      TimelineEvent(
        id: trip.id,
        timestamp: trip.startTime,
        type: TimelineEventType.trip,
        title: 'Perjalanan',
        description: '${Fmt.minutes(trip.durationMinutes)} · rata-rata '
            '${Fmt.speed(trip.avgSpeed)} · suhu mesin maks '
            '${Fmt.celsius(trip.maxCoolant)}',
        value: Fmt.km(trip.distance, decimals: 1),
        subValue: Fmt.kmPerLiter(trip.fuelEconomy),
        rawDistance: trip.distance,
        rawFuelEconomy: trip.fuelEconomy,
      ),
    for (final fuel in fuelAsync.value ?? const <FuelLog>[])
      TimelineEvent(
        id: fuel.id,
        timestamp: fuel.timestamp,
        type: TimelineEventType.fuel,
        title: 'Isi BBM · ${fuel.fuelType}',
        description: '${Fmt.rupiah(fuel.price)} · odometer '
            '${Fmt.km(fuel.odometer)}',
        value: Fmt.liters(fuel.liters),
        subValue: fuel.economy == null ? null : Fmt.kmPerLiter(fuel.economy!),
        rawCost: fuel.price,
      ),
    for (final maint in maintAsync.value ?? const <MaintenanceLog>[])
      TimelineEvent(
        id: maint.id,
        timestamp: maint.timestamp,
        type: TimelineEventType.maintenance,
        title: _serviceLabel(maint.type),
        description: [
          if (maint.description != null && maint.description!.isNotEmpty)
            maint.description!,
          'odometer ${Fmt.km(maint.odometer)}',
        ].join(' · '),
        value: Fmt.rupiah(maint.cost),
        rawCost: maint.cost,
      ),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return AsyncValue.data(events);
});

final filteredTimelineEventsProvider =
    Provider<AsyncValue<List<TimelineEvent>>>((ref) {
  final eventsAsync = ref.watch(timelineEventsProvider);
  final dateFilter = ref.watch(selectedDateFilterProvider);
  final typeFilter = ref.watch(selectedTypeFilterProvider);

  return eventsAsync.whenData((events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events.where((event) {
      final typeOk = switch (typeFilter) {
        TypeFilter.all => true,
        TypeFilter.trip => event.type == TimelineEventType.trip,
        TypeFilter.fuel => event.type == TimelineEventType.fuel,
        TypeFilter.maintenance => event.type == TimelineEventType.maintenance,
      };
      if (!typeOk) return false;
      final day = DateTime(
        event.timestamp.year,
        event.timestamp.month,
        event.timestamp.day,
      );
      return switch (dateFilter) {
        DateFilter.all => true,
        DateFilter.today => day == today,
        DateFilter.thisWeek =>
          !day.isBefore(today.subtract(Duration(days: now.weekday - 1))),
        DateFilter.thisMonth =>
          event.timestamp.year == now.year && event.timestamp.month == now.month,
        DateFilter.thisYear => event.timestamp.year == now.year,
      };
    }).toList();
  });
});

/// Riwayat: trips, refuels and services in one list, with a summary, filters,
/// forms to log a refuel or a service, and delete with undo.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(filteredTimelineEventsProvider);
    final dateFilter = ref.watch(selectedDateFilterProvider);
    final typeFilter = ref.watch(selectedTypeFilterProvider);
    final isSimulatorMode = ref.watch(
      settingsProvider.select((s) => s.isSimulatorMode),
    );
    final focusTripId = ref.watch(timelineFocusTripIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Lainnya',
            onSelected: (value) {
              if (value == 'clear_all') _clearAllHistory(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear_all', child: Text('Hapus semua riwayat')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat'),
      ),
      body: eventsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Riwayat gagal dimuat',
          message: 'Tutup aplikasi lalu buka lagi.',
        ),
        data: (events) => ListView.builder(
          // Room under the last item for the floating button.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            96,
          ),
          itemCount: events.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _Header(
                events: events,
                dateFilter: dateFilter,
                typeFilter: typeFilter,
                isSimulatorMode: isSimulatorMode,
              );
            }
            final event = events[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Dismissible(
                key: ValueKey('${event.type.name}_${event.id}'),
                direction: DismissDirection.endToStart,
                background: const _DeleteBackground(),
                confirmDismiss: (_) async {
                  await _deleteWithUndo(context, ref, event);
                  return false;
                },
                child: _EventCard(
                  event: event,
                  focused: event.type == TimelineEventType.trip &&
                      event.id == focusTripId,
                  onDelete: () => _deleteWithUndo(context, ref, event),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) {
    return showAppSheet<void>(
      context: context,
      builder: (sheetContext) => AppSheet(
        title: 'Catat',
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_gas_station_rounded),
              title: const Text('Isi BBM'),
              subtitle: const Text('Liter, harga dan odometer di SPBU'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAppSheet<void>(
                  context: context,
                  builder: (_) => const _FuelForm(),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.build_rounded),
              title: const Text('Servis'),
              subtitle: const Text('Ganti oli, filter, rem, aki…'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAppSheet<void>(
                  context: context,
                  builder: (_) => const _ServiceForm(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Deletes at once and offers "Urungkan": the removed row is kept and put
  /// back with its own id.
  Future<void> _deleteWithUndo(
    BuildContext context,
    WidgetRef ref,
    TimelineEvent event,
  ) async {
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    Future<void> Function()? restore;
    switch (event.type) {
      case TimelineEventType.trip:
        final row = await (db.select(db.trips)
              ..where((t) => t.id.equals(event.id)))
            .getSingleOrNull();
        if (row == null) return;
        await (db.delete(db.trips)..where((t) => t.id.equals(event.id))).go();
        restore = () => db.into(db.trips).insert(row.toCompanion(true));
      case TimelineEventType.fuel:
        final row = await (db.select(db.fuelLogs)
              ..where((f) => f.id.equals(event.id)))
            .getSingleOrNull();
        if (row == null) return;
        await (db.delete(db.fuelLogs)..where((f) => f.id.equals(event.id))).go();
        restore = () => db.into(db.fuelLogs).insert(row.toCompanion(true));
      case TimelineEventType.maintenance:
        final row = await (db.select(db.maintenanceLogs)
              ..where((m) => m.id.equals(event.id)))
            .getSingleOrNull();
        if (row == null) return;
        await (db.delete(db.maintenanceLogs)
              ..where((m) => m.id.equals(event.id)))
            .go();
        restore = () => db.into(db.maintenanceLogs).insert(row.toCompanion(true));
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${event.title} dihapus'),
        action: SnackBarAction(label: 'Urungkan', onPressed: () => restore?.call()),
      ));
  }

  Future<void> _clearAllHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus semua riwayat?',
      message: 'Semua perjalanan, catatan isi BBM dan servis dihapus dan '
          'tidak bisa dikembalikan.',
      confirmLabel: 'Hapus semua',
      destructive: true,
    );
    if (!confirmed) return;
    final db = ref.read(databaseProvider);
    await db.delete(db.trips).go();
    await db.delete(db.fuelLogs).go();
    await db.delete(db.maintenanceLogs).go();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Riwayat dihapus')),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.events,
    required this.dateFilter,
    required this.typeFilter,
    required this.isSimulatorMode,
  });

  final List<TimelineEvent> events;
  final DateFilter dateFilter;
  final TypeFilter typeFilter;
  final bool isSimulatorMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    var distance = 0.0;
    var cost = 0.0;
    var economySum = 0.0;
    var economyCount = 0;
    for (final e in events) {
      if (e.type == TimelineEventType.trip) {
        distance += e.rawDistance ?? 0;
        if ((e.rawFuelEconomy ?? 0) > 0) {
          economySum += e.rawFuelEconomy!;
          economyCount++;
        }
      } else {
        cost += e.rawCost ?? 0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSimulatorMode) ...[
          AppCard(
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.science_rounded,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Mode simulator: perjalanan contoh tidak dicatat ke '
                    'riwayat.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    // The end padding keeps a gap to the period menu when
                    // large text fills the row; at normal size it is unused.
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                      child: WordFitText('Ringkasan',
                          style: theme.textTheme.titleSmall),
                    ),
                  ),
                  PopupMenuButton<DateFilter>(
                    tooltip: 'Pilih periode',
                    initialValue: dateFilter,
                    onSelected: (f) =>
                        ref.read(selectedDateFilterProvider.notifier).state = f,
                    itemBuilder: (_) => [
                      for (final f in DateFilter.values)
                        PopupMenuItem(value: f, child: Text(_dateFilterLabel(f))),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dateFilterLabel(dateFilter),
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // End padding rather than gaps between the columns, so the
                  // columns keep their places and large text still leaves
                  // room between two values.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                      child: _Stat('Jarak', Fmt.km(distance, decimals: 1)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                      child: _Stat('Biaya', Fmt.rupiah(cost)),
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      'Konsumsi rata-rata',
                      economyCount == 0
                          ? Fmt.pending
                          : Fmt.kmPerLiter(economySum / economyCount),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Wraps instead of scrolling sideways, so no filter hides off-screen.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final f in TypeFilter.values)
              ChoiceChip(
                label: Text(_typeFilterLabel(f)),
                selected: f == typeFilter,
                onSelected: (_) =>
                    ref.read(selectedTypeFilterProvider.notifier).state = f,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (events.isEmpty)
          EmptyState(
            icon: Icons.history_rounded,
            title: typeFilter == TypeFilter.all && dateFilter == DateFilter.all
                ? 'Riwayat masih kosong'
                : 'Tidak ada catatan untuk filter ini',
            message: 'Perjalanan terekam otomatis saat adapter terhubung. '
                'Isi BBM dan servis dicatat lewat tombol Catat.',
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WordFitText(label, style: text.bodySmall),
        const SizedBox(height: 2),
        LineFitText(
          value,
          style: AppTheme.numberStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.focused,
    required this.onDelete,
  });

  final TimelineEvent event;
  final bool focused;
  final VoidCallback onDelete;

  IconData get _icon => switch (event.type) {
        TimelineEventType.trip => Icons.route_rounded,
        TimelineEventType.fuel => Icons.local_gas_station_rounded,
        TimelineEventType.maintenance => Icons.build_rounded,
      };

  Widget _titleRow(BuildContext context, double maxWidth) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueStyle = AppTheme.numberStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    // Card padding, icon, gaps and the menu button around title and value.
    const fixed = AppSpacing.lg + AppSpacing.xs + 40 + AppSpacing.md +
        AppSpacing.sm + 48;
    // With large text the amount can leave the title less room than its
    // longest word; the amount then goes under the title instead.
    final stacked = maxWidth.isFinite &&
        fixed +
                measureWidestWord(
                    context, event.title, theme.textTheme.titleSmall) +
                measureTextWidth(context, event.value, valueStyle) >
            maxWidth;
    final title = <Widget>[
      WordFitText(event.title, style: theme.textTheme.titleSmall),
      WordFitText(Fmt.relative(event.timestamp),
          style: theme.textTheme.bodySmall),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(_icon, size: 22, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        if (stacked)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...title,
                const SizedBox(height: AppSpacing.xs),
                LineFitText(event.value, style: valueStyle),
                if (event.subValue != null)
                  WordFitText(event.subValue!,
                      style: theme.textTheme.bodySmall),
              ],
            ),
          )
        else ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: title,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(event.value, style: valueStyle),
              if (event.subValue != null)
                Text(event.subValue!, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
        PopupMenuButton<String>(
          tooltip: 'Pilihan',
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      borderColor: focused ? scheme.primary : null,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTextEnlarged(context))
            LayoutBuilder(
              builder: (context, constraints) =>
                  _titleRow(context, constraints.maxWidth),
            )
          else
            _titleRow(context, double.infinity),
          // Details take the card's full width under the title row.
          Padding(
            padding: const EdgeInsets.only(
              left: 40 + AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.xs,
            ),
            child: Text(event.description, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final status = AppStatusColors.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      decoration: BoxDecoration(
        color: status.kritisContainer,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: status.kritis),
          const SizedBox(width: AppSpacing.sm),
          Text('Hapus', style: TextStyle(color: status.kritis)),
        ],
      ),
    );
  }
}

/// Reads "25,3" or "25.3"; null when it is not a number.
double? _parseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.'));

/// Reads "252.000", "252000" or "Rp252.000" as whole rupiah or kilometres.
double? _parseWhole(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : double.tryParse(digits);
}

final _decimalInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
final _wholeInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

/// The odometer to record: what the driver typed, prefilled with the app's
/// value. The app's odometer moves forward only.
Future<void> _recordOdometer(WidgetRef ref, double odometer) async {
  final current = ref.read(settingsProvider).currentOdometer;
  if (odometer > current) {
    await ref.read(settingsProvider.notifier).updateOdometer(odometer);
  }
}

class _FuelForm extends ConsumerStatefulWidget {
  const _FuelForm();

  @override
  ConsumerState<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<_FuelForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _odometer;
  final _liters = TextEditingController();
  final _price = TextEditingController();
  String _fuelType = AppConstants.fuelTypes.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odometer = TextEditingController(
      text: Fmt.number(ref.read(settingsProvider).currentOdometer),
    );
  }

  @override
  void dispose() {
    _odometer.dispose();
    _liters.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final liters = _parseDecimal(_liters.text)!;
    final price = _parseWhole(_price.text)!;
    final odometer = _parseWhole(_odometer.text)!;
    final db = ref.read(databaseProvider);
    // km/L from the distance since the previous refuel (full-to-full).
    double? economy;
    final previous = await (db.select(db.fuelLogs)
          ..orderBy([
            (f) => OrderingTerm(expression: f.odometer, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();
    if (previous.isNotEmpty && odometer > previous.first.odometer) {
      economy = (odometer - previous.first.odometer) / liters;
    }
    await db.into(db.fuelLogs).insert(FuelLogsCompanion.insert(
          timestamp: DateTime.now(),
          fuelType: _fuelType,
          liters: liters,
          price: price,
          odometer: odometer,
          economy: Value(economy),
        ));
    await _recordOdometer(ref, odometer);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Isi BBM dicatat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AppSheet(
        title: 'Catat isi BBM',
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Simpan'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final type in AppConstants.fuelTypes)
                  ChoiceChip(
                    label: Text(type),
                    selected: type == _fuelType,
                    onSelected: (_) => setState(() => _fuelType = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _liters,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimalInput],
              decoration: const InputDecoration(
                labelText: 'Jumlah',
                suffixText: 'liter',
                hintText: 'mis. 25,3',
              ),
              validator: (v) {
                final liters = _parseDecimal(v ?? '');
                if (liters == null || liters <= 0) return 'Isi jumlah liter.';
                if (liters > 200) return 'Terlalu banyak untuk satu pengisian.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [_wholeInput],
              decoration: const InputDecoration(
                labelText: 'Total harga',
                prefixText: 'Rp',
                hintText: 'mis. 252.000',
              ),
              validator: (v) {
                final price = _parseWhole(v ?? '');
                if (price == null || price <= 0) return 'Isi total harga.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              inputFormatters: [_wholeInput],
              decoration: const InputDecoration(
                labelText: 'Odometer',
                suffixText: 'km',
                helperText: 'Samakan dengan angka di dasbor mobil.',
              ),
              validator: (v) {
                final km = _parseWhole(v ?? '');
                if (km == null || km <= 0) return 'Isi odometer.';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm();

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _odometer;
  final _cost = TextEditingController();
  final _note = TextEditingController();
  String _type = AppConstants.defaultMaintenanceType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odometer = TextEditingController(
      text: Fmt.number(ref.read(settingsProvider).currentOdometer),
    );
  }

  @override
  void dispose() {
    _odometer.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final odometer = _parseWhole(_odometer.text)!;
    final cost = _parseWhole(_cost.text) ?? 0;
    final db = ref.read(databaseProvider);
    await db.into(db.maintenanceLogs).insert(MaintenanceLogsCompanion.insert(
          timestamp: DateTime.now(),
          type: _type,
          description: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
          odometer: odometer,
          cost: Value(cost),
        ));
    await _recordOdometer(ref, odometer);
    if (_type == 'Ganti Oli') {
      // The app's fixed oil interval; see biblio book health/health_score.
      await ref.read(settingsProvider.notifier).updateNextOilOdometer(odometer + 5000);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_type == 'Ganti Oli'
            ? 'Ganti oli dicatat. Pengingat berikutnya di ${Fmt.km(odometer + 5000)}.'
            : 'Servis dicatat'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AppSheet(
        title: 'Catat servis',
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Simpan'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in AppConstants.maintenanceTypes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: entry.key == _type,
                    onSelected: (_) => setState(() => _type = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'mis. merek oli',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [_wholeInput],
              decoration: const InputDecoration(
                labelText: 'Biaya (opsional)',
                prefixText: 'Rp',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              inputFormatters: [_wholeInput],
              decoration: const InputDecoration(
                labelText: 'Odometer',
                suffixText: 'km',
                helperText: 'Samakan dengan angka di dasbor mobil.',
              ),
              validator: (v) {
                final km = _parseWhole(v ?? '');
                if (km == null || km <= 0) return 'Isi odometer.';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
