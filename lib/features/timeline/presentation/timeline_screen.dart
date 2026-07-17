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
  final DateTime timestamp;
  final TimelineEventType type;
  final String title;
  final String description;
  final String value;
  final String? subValue;

  TimelineEvent({
    required this.timestamp,
    required this.type,
    required this.title,
    required this.description,
    required this.value,
    this.subValue,
  });
}

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
      timestamp: trip.startTime,
      type: TimelineEventType.trip,
      title: "Perjalanan Selesai",
      description: "${trip.durationMinutes} menit • ${trip.avgSpeed.toStringAsFixed(0)} km/h • Max Coolant ${trip.maxCoolant}°C",
      value: "${trip.distance.toStringAsFixed(1)} km",
      subValue: "${trip.fuelEconomy.toStringAsFixed(1)} km/L",
    ));
  }

  for (final fuel in fuels) {
    events.add(TimelineEvent(
      timestamp: fuel.timestamp,
      type: TimelineEventType.fuel,
      title: "Isi BBM (${fuel.fuelType})",
      description: "Harga: ${currencyFormat.format(fuel.price)} • Odo: ${fuel.odometer.toStringAsFixed(0)} km",
      value: "${fuel.liters.toStringAsFixed(1)} Liter",
      subValue: fuel.economy != null ? "${fuel.economy!.toStringAsFixed(1)} km/L" : null,
    ));
  }

  for (final maint in maints) {
    events.add(TimelineEvent(
      timestamp: maint.timestamp,
      type: TimelineEventType.maintenance,
      title: maint.type,
      description: maint.description ?? "Perawatan berkala kendaraan",
      value: currencyFormat.format(maint.cost),
      subValue: "Odo: ${maint.odometer.toStringAsFixed(0)} km",
    ));
  }

  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return AsyncValue.data(events);
});

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(timelineEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LINIMASA KENDARAAN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Action Buttons Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.local_gas_station_rounded, color: AppColors.primary),
                      label: const Text('Isi BBM', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      onPressed: () => _showAddFuelDialog(context, ref),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.build_rounded, color: AppColors.primary),
                      label: const Text('Servis', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      onPressed: () => _showAddMaintDialog(context, ref),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Timeline list
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _buildTimelineItem(context, event, index == events.length - 1);
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 12),
          const Text(
            'Belum ada riwayat aktivitas',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, TimelineEvent event, bool isLast) {
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
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
