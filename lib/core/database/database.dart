import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  RealColumn get odometer => real().withDefault(const Constant(0.0))();
}

class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get distance => real().withDefault(const Constant(0.0))(); // in km
  RealColumn get fuelEconomy => real().withDefault(const Constant(0.0))(); // in km/L
  RealColumn get avgSpeed => real().withDefault(const Constant(0.0))(); // in km/h
  IntColumn get maxCoolant => integer().withDefault(const Constant(0))(); // in C
  IntColumn get maxRpm => integer().withDefault(const Constant(0))();
  IntColumn get tripHealthScore => integer().withDefault(const Constant(100))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  IntColumn get idleMinutes => integer().withDefault(const Constant(0))();
}

class TripPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer().nullable().references(Trips, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get rpm => real()();
  RealColumn get speed => real()();
  RealColumn get coolant => real()();
  RealColumn get voltage => real()();
  RealColumn get mapValue => real()();
  RealColumn get throttle => real().nullable()();
  RealColumn get engineLoad => real().nullable()();
  RealColumn get fuel => real().nullable()();
  RealColumn get fuelEconomy => real().nullable()();
  RealColumn get intakeAirTemp => real().nullable()();
  RealColumn get maf => real().nullable()();
  RealColumn get timingAdvance => real().nullable()();
}

class FuelLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get fuelType => text().withLength(min: 1, max: 20)();
  RealColumn get liters => real()();
  RealColumn get price => real()();
  RealColumn get odometer => real()();
  RealColumn get economy => real().nullable()(); // calculated km/L
}

class MaintenanceLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()(); // Oil Change, Air Filter, Coolant Flush, etc.
  TextColumn get description => text().nullable()();
  RealColumn get odometer => real()();
  RealColumn get cost => real().withDefault(const Constant(0.0))();
}

class DtcLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get code => text().withLength(min: 5, max: 10)();
  TextColumn get description => text()();
  TextColumn get category => text()(); // Engine, Transmission, Body, etc.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get resolvedTime => dateTime().nullable()();
}

class UserPreferences extends Table {
  TextColumn get key => text().withLength(min: 1, max: 100)();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Vehicles, Trips, TripPoints, FuelLogs, MaintenanceLogs, DtcLogs, UserPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.withExecutor(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(userPreferences);
      }
      if (from < 3) {
        await m.addColumn(tripPoints, tripPoints.fuel);
        await m.addColumn(tripPoints, tripPoints.fuelEconomy);
        await m.addColumn(tripPoints, tripPoints.intakeAirTemp);
        await m.addColumn(tripPoints, tripPoints.maf);
        await m.addColumn(tripPoints, tripPoints.timingAdvance);
      }
    },
  );

  Future<String?> getPreference(String key) async {
    try {
      final query = select(userPreferences)..where((t) => t.key.equals(key));
      final row = await query.getSingleOrNull();
      return row?.value;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPreference(String key, String value) async {
    try {
      await into(userPreferences).insertOnConflictUpdate(
        UserPreferencesCompanion(
          key: Value(key),
          value: Value(value),
        ),
      );
    } catch (e) {
      debugPrint('UserPreferences write failed ($key): $e');
    }
  }

  Future<double?> getDoublePreference(String key) async {
    final val = await getPreference(key);
    return val != null ? double.tryParse(val) : null;
  }

  Future<void> setDoublePreference(String key, double value) async {
    await setPreference(key, value.toString());
  }

  Future<bool?> getBoolPreference(String key) async {
    final val = await getPreference(key);
    return val != null ? val == 'true' : null;
  }

  Future<void> setBoolPreference(String key, bool value) async {
    await setPreference(key, value.toString());
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'autocare.db'));
    return NativeDatabase(file);
  });
}
