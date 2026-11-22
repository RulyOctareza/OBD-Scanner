// Dev-only benchmark data (see lib/dev/bench/bench_main.dart).
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/database.dart';

/// Own file in the bench package's own sandbox: a bench run never opens the
/// app's autocare.db.
const benchDatabaseFile = 'autocare_bench.db';

/// Deletes the previous bench database and seeds about a month of use:
/// 28 past trips with ~10k trip points, fuel and service logs, a cleared DTC.
/// Every run starts from the same data.
Future<AppDatabase> openSeededBenchDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final file = File(p.join(dir.path, '$benchDatabaseFile$suffix'));
    if (file.existsSync()) file.deleteSync();
  }
  final db = AppDatabase(fileName: benchDatabaseFile);

  final now = DateTime.now();
  final random = math.Random(42);
  await db.transaction(() async {
    for (final entry in {
      'has_completed_obd_intro': 'true',
      'auto_connect_obd': 'false',
      'is_simulator_mode': 'false',
      'is_ignition_on': 'true',
      'vehicle_name': 'Agya',
      'current_odometer': '45678.9',
      'next_oil_odometer': '50000.0',
    }.entries) {
      await db.setPreference(entry.key, entry.value);
    }

    for (var trip = 0; trip < 28; trip++) {
      final start = now.subtract(Duration(days: 28 - trip, hours: 2));
      final minutes = 20 + random.nextInt(20);
      final distance = minutes * 0.55;
      final tripId = await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              startTime: start,
              endTime: Value(start.add(Duration(minutes: minutes))),
              distance: Value(distance),
              fuelEconomy: Value(12 + random.nextDouble() * 4),
              avgSpeed: Value(distance / minutes * 60),
              maxCoolant: Value(90 + random.nextInt(5)),
              maxRpm: Value(3000 + random.nextInt(1500)),
              tripHealthScore: Value(85 + random.nextInt(15)),
              durationMinutes: Value(minutes),
              idleMinutes: Value(random.nextInt(5)),
            ),
          );
      await db.batch((batch) {
        batch.insertAll(db.tripPoints, [
          for (var i = 0; i < minutes * 12; i++)
            TripPointsCompanion.insert(
              tripId: Value(tripId),
              timestamp: start.add(Duration(seconds: i * 5)),
              rpm: 900 + 1800 * (0.5 + 0.5 * math.sin(i / 9)),
              speed: 35 + 30 * math.sin(i / 40),
              coolant: 88 + random.nextDouble() * 4,
              voltage: 14 + random.nextDouble() * 0.3,
              mapValue: 40 + 30 * random.nextDouble(),
              throttle: Value(15 + 20 * random.nextDouble()),
              engineLoad: Value(25 + 30 * random.nextDouble()),
              fuel: Value(70 - trip * 1.5),
              fuelEconomy: Value(10 + 6 * random.nextDouble()),
              intakeAirTemp: Value(33 + random.nextDouble() * 4),
              maf: Value(4 + 10 * random.nextDouble()),
              timingAdvance: Value(8 + 10 * random.nextDouble()),
            ),
        ]);
      });
    }

    for (var i = 0; i < 12; i++) {
      await db
          .into(db.fuelLogs)
          .insert(
            FuelLogsCompanion.insert(
              timestamp: now.subtract(Duration(days: 60 - i * 5)),
              fuelType: 'Pertalite',
              liters: 25 + random.nextDouble() * 10,
              price: 10000,
              odometer: 44000.0 + i * 140,
              economy: Value(13 + random.nextDouble() * 3),
            ),
          );
    }
    for (var i = 0; i < 6; i++) {
      await db
          .into(db.maintenanceLogs)
          .insert(
            MaintenanceLogsCompanion.insert(
              timestamp: now.subtract(Duration(days: 180 - i * 30)),
              type: i.isEven ? 'Ganti Oli' : 'Filter Udara',
              description: const Value('Bengkel resmi'),
              odometer: 40000.0 + i * 1000,
              cost: const Value(450000),
            ),
          );
    }
    await db
        .into(db.dtcLogs)
        .insert(
          DtcLogsCompanion.insert(
            timestamp: now.subtract(const Duration(days: 9)),
            code: 'P0133',
            description: 'O2 Sensor Circuit Slow Response',
            category: 'Powertrain',
            active: const Value(false),
            resolvedTime: Value(now.subtract(const Duration(days: 8))),
          ),
        );
  });
  return db;
}
