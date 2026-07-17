import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/features/settings/presentation/settings_provider.dart';

void main() {
  // Mock SharedPreferences before running tests
  SharedPreferences.setMockInitialValues({
    'current_odometer': 161420.0,
    'next_oil_odometer': 166420.0,
    'vehicle_name': 'Toyota Agya',
    'is_simulator_mode': true,
    'is_ignition_on': true,
  });

  group('Database CRUD Tests', () {
    late AppDatabase database;

    setUp(() {
      // Use an in-memory database for testing
      database = AppDatabase.withExecutor(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('Insert and query vehicle details', () async {
      final id = await database.into(database.vehicles).insert(
        VehiclesCompanion.insert(
          name: 'Agya 2013',
          odometer: const drift.Value(162541.0),
        ),
      );

      final vehicle = await (database.select(database.vehicles)..where((v) => v.id.equals(id))).getSingle();
      expect(vehicle.name, 'Agya 2013');
      expect(vehicle.odometer, 162541.0);
    });

    test('Insert and log trip data', () async {
      final tripId = await database.into(database.trips).insert(
        TripsCompanion.insert(
          startTime: DateTime.now(),
          distance: const drift.Value(42.3),
          fuelEconomy: const drift.Value(15.6),
          avgSpeed: const drift.Value(45.0),
          maxCoolant: const drift.Value(92),
          maxRpm: const drift.Value(3000),
          tripHealthScore: const drift.Value(98),
          durationMinutes: const drift.Value(45),
        ),
      );

      final trip = await (database.select(database.trips)..where((t) => t.id.equals(tripId))).getSingle();
      expect(trip.distance, 42.3);
      expect(trip.fuelEconomy, 15.6);
      expect(trip.maxCoolant, 92);
      expect(trip.tripHealthScore, 98);
    });

    test('Insert and log refuels', () async {
      final logId = await database.into(database.fuelLogs).insert(
        FuelLogsCompanion.insert(
          timestamp: DateTime.now(),
          fuelType: 'Pertalite',
          liters: 30.0,
          price: 300000.0,
          odometer: 162580.0,
        ),
      );

      final log = await (database.select(database.fuelLogs)..where((f) => f.id.equals(logId))).getSingle();
      expect(log.fuelType, 'Pertalite');
      expect(log.liters, 30.0);
      expect(log.price, 300000.0);
    });
  });

  group('SettingsNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      final database = AppDatabase.withExecutor(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Loads initial SharedPreferences settings state', () async {
      while (container.read(settingsProvider).vehicleName != 'Toyota Agya') {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      final updatedSettings = container.read(settingsProvider);
      expect(updatedSettings.currentOdometer, 161420.0);
      expect(updatedSettings.nextOilOdometer, 166420.0);
      expect(updatedSettings.vehicleName, 'Toyota Agya');
    });

    test('Updates vehicle odometer and details', () async {
      while (container.read(settingsProvider).vehicleName != 'Toyota Agya') {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      final notifier = container.read(settingsProvider.notifier);
      await notifier.updateVehicleName('Agya TRD');
      await notifier.updateOdometer(163000.0);
      await notifier.updateNextOilOdometer(168000.0);

      final state = container.read(settingsProvider);
      expect(state.vehicleName, 'Agya TRD');
      expect(state.currentOdometer, 163000.0);
      expect(state.nextOilOdometer, 168000.0);
    });
  });
}


