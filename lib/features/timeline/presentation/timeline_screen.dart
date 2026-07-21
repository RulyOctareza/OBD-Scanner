import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../trips/presentation/trip_provider.dart';
import '../../settings/presentation/settings_provider.dart';

enum TimelineEventType { trip, fuel, maintenance }

class TimelineEvent {
  final int id;
  final DateTime timestamp;
  final TimelineEventType type;
  final String title;
  final String description;
  final String value;
  final String? subValue;
  // Raw values for dashboard metrics
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

final selectedDateFilterProvider = StateProvider<DateFilter>((ref) => DateFilter.all);
final selectedTypeFilterProvider = StateProvider<TypeFilter>((ref) => TypeFilter.all);
final timelineFocusTripIdProvider = StateProvider<int?>((ref) => null);

final fuelLogsProvider = StreamProvider<List<FuelLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.fuelLogs)
    ..orderBy([(f) => OrderingTerm(expression: f.timestamp, mode: OrderingMode.desc)]))
    .watch();
});

final maintenanceLogsProvider = StreamProvider<List<MaintenanceLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.maintenanceLogs)
    ..orderBy([(m) => OrderingTerm(expression: m.timestamp, mode: OrderingMode.desc)]))
    .watch();
});

final timelineEventsProvider = Provider<AsyncValue<List<TimelineEvent>>>((ref) {
  final tripsAsync = ref.watch(historicalTripsProvider);
  final fuelAsync = ref.watch(fuelLogsProvider);
  final maintAsync = ref.watch(maintenanceLogsProvider);

  if (tripsAsync.isLoading || fuelAsync.isLoading || maintAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (tripsAsync.hasError) return AsyncValue.error(tripsAsync.error!, tripsAsync.stackTrace!);
  if (fuelAsync.hasError) return AsyncValue.error(fuelAsync.error!, fuelAsync.stackTrace!);
  if (maintAsync.hasError) return AsyncValue.error(maintAsync.error!, maintAsync.stackTrace!);

  final trips = tripsAsync.value ?? [];
  final fuels = fuelAsync.value ?? [];
  final maints = maintAsync.value ?? [];

  final events = <TimelineEvent>[];

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  for (final trip in trips) {
    events.add(TimelineEvent(
      id: trip.id,
      timestamp: trip.startTime,
      type: TimelineEventType.trip,
      title: "Perjalanan Selesai",
      description: "${trip.durationMinutes} menit • ${trip.avgSpeed.toStringAsFixed(0)} km/h • Max Coolant ${trip.maxCoolant}°C",
      value: "${trip.distance.toStringAsFixed(1)} km",
      subValue: "${trip.fuelEconomy.toStringAsFixed(1)} km/L",
      rawDistance: trip.distance,
      rawFuelEconomy: trip.fuelEconomy,
    ));
  }

  for (final fuel in fuels) {
    events.add(TimelineEvent(
      id: fuel.id,
      timestamp: fuel.timestamp,
      type: TimelineEventType.fuel,
      title: "Isi BBM (${fuel.fuelType})",
      description: "Harga: ${currencyFormat.format(fuel.price)} • Odo: ${fuel.odometer.toStringAsFixed(0)} km",
      value: "${fuel.liters.toStringAsFixed(1)} Liter",
      subValue: fuel.economy != null ? "${fuel.economy!.toStringAsFixed(1)} km/L" : null,
      rawCost: fuel.price,
    ));
  }

  for (final maint in maints) {
    events.add(TimelineEvent(
      id: maint.id,
      timestamp: maint.timestamp,
      type: TimelineEventType.maintenance,
      title: maint.type,
      description: maint.description ?? "Perawatan berkala kendaraan",
      value: currencyFormat.format(maint.cost),
      subValue: "Odo: ${maint.odometer.toStringAsFixed(0)} km",
      rawCost: maint.cost,
    ));
  }

  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return AsyncValue.data(events);
});

final filteredTimelineEventsProvider = Provider<AsyncValue<List<TimelineEvent>>>((ref) {
  final eventsAsync = ref.watch(timelineEventsProvider);
  final dateFilter = ref.watch(selectedDateFilterProvider);
  final typeFilter = ref.watch(selectedTypeFilterProvider);

  return eventsAsync.whenData((events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return events.where((event) {
      // Type Filter
      if (typeFilter != TypeFilter.all) {
        if (typeFilter == TypeFilter.trip && event.type != TimelineEventType.trip) return false;
        if (typeFilter == TypeFilter.fuel && event.type != TimelineEventType.fuel) return false;
        if (typeFilter == TypeFilter.maintenance && event.type != TimelineEventType.maintenance) return false;
      }

      // Date Filter
      final eventDate = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
      switch (dateFilter) {
        case DateFilter.all:
          return true;
        case DateFilter.today:
          return eventDate.isAtSameMomentAs(today);
        case DateFilter.thisWeek:
          final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
          return eventDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
        case DateFilter.thisMonth:
          return event.timestamp.year == now.year && event.timestamp.month == now.month;
        case DateFilter.thisYear:
          return event.timestamp.year == now.year;
      }
    }).toList();
  });
});

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(filteredTimelineEventsProvider);
    final dateFilter = ref.watch(selectedDateFilterProvider);
    final typeFilter = ref.watch(selectedTypeFilterProvider);

    // Calculate stats re-filtered
    double totalDistance = 0;
    double totalCost = 0;
    double totalFuelEconomySum = 0;
    int tripCountWithEconomy = 0;

    eventsAsync.whenData((events) {
      for (final event in events) {
        if (event.type == TimelineEventType.trip) {
          totalDistance += event.rawDistance ?? 0.0;
          if (event.rawFuelEconomy != null && event.rawFuelEconomy! > 0) {
            totalFuelEconomySum += event.rawFuelEconomy!;
            tripCountWithEconomy++;
          }
        } else {
          totalCost += event.rawCost ?? 0.0;
        }
      }
    });

    final isSimulatorMode = ref.watch(
      settingsProvider.select((s) => s.isSimulatorMode),
    );
    final focusTripId = ref.watch(timelineFocusTripIdProvider);
    final avgFuelEconomy = tripCountWithEconomy > 0 ? totalFuelEconomySum / tripCountWithEconomy : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linimasa Kendaraan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllHistory(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('Hapus Semua Riwayat', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActionSheet(context, ref),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Catat Aktivitas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isSimulatorMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_rounded, size: 16, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode Simulasi Aktif — Perjalanan simulasi tidak dicatat ke linimasa.',
                        style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Ringkasan Dashboard Dinamis
            _buildStatsDashboard(
              context,
              totalDistance,
              totalCost,
              avgFuelEconomy,
              dateFilter: dateFilter,
            ),

            const SizedBox(height: 4),

            // Combined Filter Bar (Date Dropdown & Type Pills)
            _buildFilterSection(context, ref, dateFilter, typeFilter),
            
            const SizedBox(height: 6),
            
            // Timeline list
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Dismissible(
                        key: Key('${event.type.name}_${event.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Hapus',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.delete_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await _showDeleteConfirmDialog(
                            context,
                            'Hapus Aktivitas?',
                            'Apakah Anda yakin ingin menghapus aktivitas "${event.title}" ini?'
                          );
                        },
                        onDismissed: (direction) async {
                          await _deleteEvent(context, ref, event);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${event.title}" berhasil dihapus'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: _buildTimelineItem(
                          context,
                          event,
                          index == events.length - 1,
                          highlighted: focusTripId != null &&
                              event.type == TimelineEventType.trip &&
                              event.id == focusTripId,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsDashboard(
    BuildContext context,
    double distance,
    double cost,
    double economy, {
    required DateFilter dateFilter,
  }) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final periodLabel = switch (dateFilter) {
      DateFilter.today => 'hari ini',
      DateFilter.thisWeek => 'minggu ini',
      DateFilter.thisMonth => 'bulan ini',
      DateFilter.thisYear => 'tahun ini',
      DateFilter.all => 'seluruh periode',
    };
    final insight = distance > 0
        ? 'Ringkasan $periodLabel: ${distance.toStringAsFixed(1)} km'
            '${economy > 0 ? ', rata-rata ${economy.toStringAsFixed(1)} km/L' : ''}.'
        : 'Belum ada perjalanan tercatat untuk $periodLabel.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.card.withOpacity(0.9),
            AppColors.surface.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Jarak Tempuh', '${distance.toStringAsFixed(1)} km', Icons.directions_car_rounded, AppColors.primary),
              _buildStatDivider(),
              _buildStatColumn('Pengeluaran', currencyFormat.format(cost), Icons.payments_rounded, AppColors.success),
              _buildStatDivider(),
              _buildStatColumn('Konsumsi BBM', '${economy.toStringAsFixed(1)} km/L', Icons.local_gas_station_rounded, AppColors.warning),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.numberStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9EA7B8), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, WidgetRef ref, DateFilter activeDate, TypeFilter activeType) {
    final dateFilters = {
      DateFilter.all: 'Semua Waktu',
      DateFilter.today: 'Hari Ini',
      DateFilter.thisWeek: 'Minggu Ini',
      DateFilter.thisMonth: 'Bulan Ini',
      DateFilter.thisYear: 'Tahun Ini',
    };

    final typeFilters = {
      TypeFilter.all: 'Semua',
      TypeFilter.trip: 'Perjalanan',
      TypeFilter.fuel: 'BBM',
      TypeFilter.maintenance: 'Servis',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Time filter dropdown button
          PopupMenuButton<DateFilter>(
            initialValue: activeDate,
            onSelected: (val) {
              ref.read(selectedDateFilterProvider.notifier).state = val;
            },
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: activeDate != DateFilter.all
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeDate != DateFilter.all ? AppColors.primary : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: activeDate != DateFilter.all ? AppColors.primary : const Color(0xFFA0AEC0),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateFilters[activeDate] ?? 'Waktu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: activeDate != DateFilter.all ? FontWeight.bold : FontWeight.w500,
                      color: activeDate != DateFilter.all ? AppColors.primary : const Color(0xFFA0AEC0),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: activeDate != DateFilter.all ? AppColors.primary : const Color(0xFFA0AEC0),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => dateFilters.entries.map((entry) {
              return PopupMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: entry.key == activeDate ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: entry.key == activeDate ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: Colors.white.withOpacity(0.1)),
          const SizedBox(width: 8),

          // Category Pills
          ...typeFilters.entries.map((entry) {
            final isSelected = entry.key == activeType;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: InkWell(
                onTap: () {
                  ref.read(selectedTypeFilterProvider.notifier).state = entry.key;
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFA0AEC0),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Icon(Icons.history_toggle_off_rounded, size: 52, color: AppColors.primary.withOpacity(0.85)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Riwayat Aktivitas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Catat pengisian BBM atau servis kendaraan Anda untuk memantau pengeluaran dan efisiensi konsumsi bahan bakar.',
              style: TextStyle(color: Color(0xFF9EA7B8), fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.local_gas_station_rounded, size: 18),
                  label: const Text('Catat BBM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _showAddFuelDialog(context, ref),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning.withOpacity(0.15),
                    foregroundColor: AppColors.warning,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.build_rounded, size: 18),
                  label: const Text('Catat Servis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _showAddMaintDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddActionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tambah Catatan Kendaraan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppColors.card,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_gas_station_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Isi Bahan Bakar (BBM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Catat volume, harga, dan odometer pengisian', style: TextStyle(fontSize: 11, color: Color(0xFF9EA7B8))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddFuelDialog(context, ref);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppColors.card,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_rounded, color: AppColors.warning),
                  ),
                  title: const Text('Servis / Perawatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Catat ganti oli, perbaikan, atau biaya perawatan', style: TextStyle(fontSize: 11, color: Color(0xFF9EA7B8))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddMaintDialog(context, ref);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    TimelineEvent event,
    bool isLast, {
    bool highlighted = false,
  }) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (event.type) {
      case TimelineEventType.trip:
        icon = Icons.directions_car_rounded;
        iconBg = AppColors.primary.withOpacity(0.12);
        iconColor = AppColors.primary;
        break;
      case TimelineEventType.fuel:
        icon = Icons.local_gas_station_rounded;
        iconBg = AppColors.success.withOpacity(0.12);
        iconColor = AppColors.success;
        break;
      case TimelineEventType.maintenance:
        icon = Icons.build_rounded;
        iconBg = AppColors.warning.withOpacity(0.12);
        iconColor = AppColors.warning;
        break;
    }

    final timeFormat = DateFormat('dd MMM yyyy, HH:mm');
    final formattedTime = timeFormat.format(event.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator line
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.timelineTrack,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                margin: EdgeInsets.zero,
                color: highlighted ? AppColors.primary.withOpacity(0.08) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: highlighted
                        ? AppColors.primary.withOpacity(0.55)
                        : Colors.white.withOpacity(0.04),
                    width: highlighted ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.description,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formattedTime,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            event.value,
                            style: AppTheme.numberStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          if (event.subValue != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.subValue!,
                              style: AppTheme.numberStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref, TimelineEvent event) async {
    final db = ref.read(databaseProvider);
    switch (event.type) {
      case TimelineEventType.trip:
        await (db.delete(db.trips)..where((t) => t.id.equals(event.id))).go();
        break;
      case TimelineEventType.fuel:
        await (db.delete(db.fuelLogs)..where((f) => f.id.equals(event.id))).go();
        break;
      case TimelineEventType.maintenance:
        await (db.delete(db.maintenanceLogs)..where((m) => m.id.equals(event.id))).go();
        break;
    }
  }

  Future<void> _clearAllHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showDeleteConfirmDialog(
      context,
      'Hapus Semua Riwayat?',
      'Tindakan ini akan menghapus semua data perjalanan, pengisian BBM, dan servis secara permanen. Tindakan ini tidak dapat dibatalkan.'
    );
    if (confirmed) {
      final db = ref.read(databaseProvider);
      await db.delete(db.trips).go();
      await db.delete(db.fuelLogs).go();
      await db.delete(db.maintenanceLogs).go();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua riwayat berhasil dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _showAddFuelDialog(BuildContext context, WidgetRef ref) {
    final odoController = TextEditingController(text: ref.read(settingsProvider).currentOdometer.toStringAsFixed(0));
    final litersController = TextEditingController();
    final priceController = TextEditingController();
    String fuelType = 'Pertalite';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Catat Pengisian BBM', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: fuelType,
                  decoration: const InputDecoration(labelText: 'Jenis BBM'),
                  items: AppConstants.fuelTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) fuelType = val;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: litersController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Jumlah (Liter)', suffixText: 'L'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Harga (Rupiah)', prefixText: 'Rp '),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: odoController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Odometer (km)',
                    helperText: 'Diisi otomatis dari ECU / Simulator',
                    helperStyle: TextStyle(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                final liters = double.tryParse(litersController.text) ?? 0.0;
                final price = double.tryParse(priceController.text) ?? 0.0;
                final odo = double.tryParse(odoController.text) ?? 0.0;

                if (liters > 0 && price > 0 && odo > 0) {
                  final db = ref.read(databaseProvider);
                  
                  // Estimate economy based on last fuel log if odometer increased
                  double? economy;
                  final fuelLogs = await (db.select(db.fuelLogs)
                    ..orderBy([(f) => OrderingTerm(expression: f.odometer, mode: OrderingMode.desc)])
                    ..limit(1))
                    .get();
                  if (fuelLogs.isNotEmpty) {
                    final prevOdo = fuelLogs.first.odometer;
                    final odoDiff = odo - prevOdo;
                    if (odoDiff > 0) {
                      economy = odoDiff / liters; // km/L
                    }
                  }

                  await db.into(db.fuelLogs).insert(
                    FuelLogsCompanion.insert(
                      timestamp: DateTime.now(),
                      fuelType: fuelType,
                      liters: liters,
                      price: price,
                      odometer: odo,
                      economy: Value(economy),
                    ),
                  );

                  // Update odometer in settings
                  await ref.read(settingsProvider.notifier).updateOdometer(odo);

                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showAddMaintDialog(BuildContext context, WidgetRef ref) {
    final odoController = TextEditingController(text: ref.read(settingsProvider).currentOdometer.toStringAsFixed(0));
    final costController = TextEditingController();
    final descController = TextEditingController();
    String maintType = AppConstants.defaultMaintenanceType;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Catat Servis / Perawatan', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: maintType,
                  decoration: const InputDecoration(labelText: 'Jenis Servis'),
                  items: AppConstants.maintenanceTypes.entries.map((entry) {
                    return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) maintType = val;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Deskripsi Tambahan (e.g. Merk Oli)', hintText: 'Opsional'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Biaya Servis', prefixText: 'Rp '),
                ),
                 const SizedBox(height: 12),
                TextField(
                  controller: odoController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Odometer Saat Ini (km)',
                    helperText: 'Diisi otomatis dari ECU / Simulator',
                    helperStyle: TextStyle(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                final cost = double.tryParse(costController.text) ?? 0.0;
                final odo = double.tryParse(odoController.text) ?? 0.0;
                final desc = descController.text;

                if (odo > 0) {
                  final db = ref.read(databaseProvider);
                  await db.into(db.maintenanceLogs).insert(
                    MaintenanceLogsCompanion.insert(
                      timestamp: DateTime.now(),
                      type: maintType,
                      description: Value(desc.isNotEmpty ? desc : null),
                      odometer: odo,
                      cost: Value(cost),
                    ),
                  );

                  // Update settings odometer & oil target (if oil changed, set next oil target to odo + 5000 km)
                  await ref.read(settingsProvider.notifier).updateOdometer(odo);
                  if (maintType == AppConstants.maintenanceTypes.keys.first) {
                    await ref.read(settingsProvider.notifier).updateNextOilOdometer(odo + 5000.0);
                  }

                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}
