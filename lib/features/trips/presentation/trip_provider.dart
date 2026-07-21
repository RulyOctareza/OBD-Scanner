import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/obd/obd_telemetry.dart';
import '../../settings/presentation/settings_provider.dart';

class TripRecorderState {
  final bool isRecording;
  final DateTime? startTime;
  final double currentTripDistance; // in km
  final double maxSpeed;
  final double maxRpm;
  final double maxCoolant;
  final int durationSeconds;
  final int idleSeconds;
  final double accumulatedSpeed;
  final int speedTicksCount;
  final int? lastCompletedTripId;
  final double tripADistance;
  final double tripBDistance;

  TripRecorderState({
    required this.isRecording,
    this.startTime,
    required this.currentTripDistance,
    required this.maxSpeed,
    required this.maxRpm,
    required this.maxCoolant,
    required this.durationSeconds,
    required this.idleSeconds,
    required this.accumulatedSpeed,
    required this.speedTicksCount,
    this.lastCompletedTripId,
    required this.tripADistance,
    required this.tripBDistance,
  });

  factory TripRecorderState.initial() {
    return TripRecorderState(
      isRecording: false,
      currentTripDistance: 0.0,
      maxSpeed: 0.0,
      maxRpm: 0.0,
      maxCoolant: 0.0,
      durationSeconds: 0,
      idleSeconds: 0,
      accumulatedSpeed: 0.0,
      speedTicksCount: 0,
      tripADistance: 0.0,
      tripBDistance: 0.0,
    );
  }

  TripRecorderState copyWith({
    bool? isRecording,
    DateTime? startTime,
    double? currentTripDistance,
    double? maxSpeed,
    double? maxRpm,
    double? maxCoolant,
    int? durationSeconds,
    int? idleSeconds,
    double? accumulatedSpeed,
    int? speedTicksCount,
    int? lastCompletedTripId,
    double? tripADistance,
    double? tripBDistance,
  }) {
    return TripRecorderState(
      isRecording: isRecording ?? this.isRecording,
      startTime: startTime ?? this.startTime,
      currentTripDistance: currentTripDistance ?? this.currentTripDistance,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      maxRpm: maxRpm ?? this.maxRpm,
      maxCoolant: maxCoolant ?? this.maxCoolant,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      idleSeconds: idleSeconds ?? this.idleSeconds,
      accumulatedSpeed: accumulatedSpeed ?? this.accumulatedSpeed,
      speedTicksCount: speedTicksCount ?? this.speedTicksCount,
      lastCompletedTripId: lastCompletedTripId ?? this.lastCompletedTripId,
      tripADistance: tripADistance ?? this.tripADistance,
      tripBDistance: tripBDistance ?? this.tripBDistance,
    );
  }
}

class TripRecorderNotifier extends StateNotifier<TripRecorderState> {
  final Ref _ref;
  Timer? _tripTimer;
  int _activeTripId = -1;
  DateTime? _lastTickTime;
  DateTime? _lastSpeedTime;
  DateTime? _lastDbSaveTime;
  double _accumulatedTripLiters = 0.0;
  SharedPreferences? _prefs;
  String _currentTripBDate = '';

  TripRecorderNotifier(this._ref) : super(TripRecorderState.initial()) {
    _initTrips();
    // Listen to OBD State changes
    _ref.listen(obdServiceProvider, (previous, next) {
      final isSimulatorMode = next.isSimulatorMode || _ref.read(settingsProvider).isSimulatorMode;
      if (isSimulatorMode) {
        if (state.isRecording) {
          _cancelTripWithoutSaving();
        }
        return;
      }

      final isEngineOn = next.telemetry.rpm > 500;
      final isVehicleMoving = next.telemetry.speed > 0.0 || next.telemetry.rpm >= 1100;
      final isConnected = next.status == ObdStatus.connected;
      
      if (isConnected && isEngineOn && isVehicleMoving && !state.isRecording) {
        _startTrip();
      } else if ((!isConnected || !isEngineOn) && state.isRecording) {
        _stopTrip();
      }

      if (state.isRecording && isEngineOn) {
        _updateTripData(next.telemetry);
      }
    });
  }

  Future<void> _cancelTripWithoutSaving() async {
    _tripTimer?.cancel();
    _tripTimer = null;

    if (_activeTripId != -1) {
      final db = _ref.read(databaseProvider);
      final idToDelete = _activeTripId;
      _activeTripId = -1;
      try {
        await (db.delete(db.trips)..where((t) => t.id.equals(idToDelete))).go();
        await (db.delete(db.tripPoints)..where((tp) => tp.tripId.equals(idToDelete))).go();
      } catch (_) {}
    }

    state = state.copyWith(
      isRecording: false,
    );
  }

  Future<void> _initTrips() async {
    final db = _ref.read(databaseProvider);
    _prefs = await SharedPreferences.getInstance();

    // 1. Try loading from SQLite
    double? tripA = await db.getDoublePreference('trip_a_distance');
    double? tripB = await db.getDoublePreference('trip_b_distance');
    String? tripBDate = await db.getPreference('trip_b_date');
    
    final todayStr = _getTodayDateString();

    // 2. Legacy fallback to SharedPreferences if null
    if (tripA == null) {
      tripA = _prefs!.getDouble('trip_a_distance') ?? 0.0;
      await db.setDoublePreference('trip_a_distance', tripA);
    }
    if (tripBDate == null) {
      tripBDate = _prefs!.getString('trip_b_date') ?? todayStr;
      await db.setPreference('trip_b_date', tripBDate);
    }
    if (tripB == null) {
      if (tripBDate == todayStr) {
        tripB = _prefs!.getDouble('trip_b_distance') ?? 0.0;
      } else {
        tripB = 0.0;
      }
      await db.setDoublePreference('trip_b_distance', tripB);
    }

    // 3. Roll over if dates differ
    if (tripBDate != todayStr) {
      tripB = 0.0;
      tripBDate = todayStr;
      await db.setPreference('trip_b_date', todayStr);
      await db.setDoublePreference('trip_b_distance', 0.0);
    }

    _currentTripBDate = tripBDate;

    state = state.copyWith(
      tripADistance: tripA,
      tripBDistance: tripB,
    );
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> resetTripA() async {
    final db = _ref.read(databaseProvider);
    await db.setDoublePreference('trip_a_distance', 0.0);
    state = state.copyWith(tripADistance: 0.0);
  }

  Future<void> resetTripB() async {
    final db = _ref.read(databaseProvider);
    await db.setDoublePreference('trip_b_distance', 0.0);
    state = state.copyWith(tripBDistance: 0.0);
  }

  void _saveTripPreferencesToDb() {
    final db = _ref.read(databaseProvider);
    db.setDoublePreference('trip_a_distance', state.tripADistance);
    db.setDoublePreference('trip_b_distance', state.tripBDistance);
    db.setPreference('trip_b_date', _currentTripBDate);
  }

  Future<void> _startTrip() async {
    final now = DateTime.now();
    _lastTickTime = now;
    _lastSpeedTime = now;
    _accumulatedTripLiters = 0.0;

    // Insert trip into DB
    final db = _ref.read(databaseProvider);
    final id = await db.into(db.trips).insert(
      TripsCompanion.insert(
        startTime: now,
        distance: const Value(0.0),
        avgSpeed: const Value(0.0),
        maxCoolant: const Value(0),
        maxRpm: const Value(0),
        tripHealthScore: const Value(100),
      ),
    );

    _activeTripId = id;
    state = state.copyWith(
      isRecording: true,
      startTime: now,
      currentTripDistance: 0.0,
      maxSpeed: 0.0,
      maxRpm: 0.0,
      maxCoolant: 0.0,
      durationSeconds: 0,
      idleSeconds: 0,
      accumulatedSpeed: 0.0,
      speedTicksCount: 0,
    );

    // Start 1Hz duration ticking
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRecording) {
        timer.cancel();
        return;
      }
      
      final nowTick = DateTime.now();
      final deltaSec = _lastTickTime != null 
          ? nowTick.difference(_lastTickTime!).inSeconds 
          : 1;
      _lastTickTime = nowTick;

      final newDuration = state.durationSeconds + deltaSec;
      state = state.copyWith(
        durationSeconds: newDuration,
      );

      // Periodically save preferences to DB every 5 seconds to reduce I/O
      if (newDuration % 5 == 0) {
        _saveTripPreferencesToDb();
      }
    });
  }

  void _updateTripData(ObdTelemetry telemetry) {
    final speed = telemetry.speed;
    final rpm = telemetry.rpm;
    final coolant = telemetry.coolant;
    final now = DateTime.now();

    double distanceDelta = 0.0;
    double litersDelta = 0.0;

    // Calculate exact distance & fuel consumed based on REAL timestamp delta
    if (_lastSpeedTime != null) {
      final deltaSeconds = now.difference(_lastSpeedTime!).inMilliseconds / 1000.0;
      // Guard against unrealistic deltas (e.g. initial start or connection pause > 10s)
      if (deltaSeconds > 0 && deltaSeconds < 10.0) {
        if (speed > 0) {
          distanceDelta = (speed * deltaSeconds) / 3600.0;
        }

        final realKml = telemetry.fuelEconomy;
        if (realKml > 0 && distanceDelta > 0) {
          litersDelta = distanceDelta / realKml;
        }
      }
    }
    _lastSpeedTime = now;

    final newDistance = state.currentTripDistance + distanceDelta;
    final isIdle = speed < 1.0;
    _accumulatedTripLiters += litersDelta;

    // Update Trip A and B
    double newTripA = state.tripADistance + distanceDelta;
    
    final todayStr = _getTodayDateString();
    double newTripB;
    if (_currentTripBDate == todayStr) {
      newTripB = state.tripBDistance + distanceDelta;
    } else {
      newTripB = distanceDelta;
      _currentTripBDate = todayStr;
    }

    state = state.copyWith(
      currentTripDistance: newDistance,
      maxSpeed: speed > state.maxSpeed ? speed : state.maxSpeed,
      maxRpm: rpm > state.maxRpm ? rpm : state.maxRpm,
      maxCoolant: coolant > state.maxCoolant ? coolant : state.maxCoolant,
      idleSeconds: state.idleSeconds + (isIdle ? 1 : 0),
      accumulatedSpeed: state.accumulatedSpeed + speed,
      speedTicksCount: state.speedTicksCount + 1,
      tripADistance: newTripA,
      tripBDistance: newTripB,
    );

    // Save trip point more frequently for better chart history (5s)
    if (_lastDbSaveTime == null || now.difference(_lastDbSaveTime!).inSeconds >= 5) {
      _lastDbSaveTime = now;
      final db = _ref.read(databaseProvider);
      db.into(db.tripPoints).insert(
        TripPointsCompanion.insert(
          tripId: Value(_activeTripId),
          timestamp: now,
          rpm: rpm,
          speed: speed,
          coolant: coolant,
          voltage: telemetry.voltage,
          mapValue: telemetry.mapValue,
          throttle: Value(telemetry.throttle),
          engineLoad: Value(telemetry.engineLoad),
          fuel: Value(telemetry.fuelLevel),
          fuelEconomy: Value(telemetry.fuelEconomy),
          intakeAirTemp: Value(telemetry.intakeAirTemp),
          maf: Value(telemetry.maf),
          timingAdvance: Value(telemetry.timingAdvance),
        ),
      );
    }
  }

  Future<void> _stopTrip() async {
    _tripTimer?.cancel();
    _tripTimer = null;

    if (_activeTripId == -1) return;

    final db = _ref.read(databaseProvider);
    final endTime = DateTime.now();
    
    // Average speed
    final avgSpeed = state.speedTicksCount > 0 
        ? state.accumulatedSpeed / state.speedTicksCount 
        : 0.0;
        
    // Calculate real fuel economy from accumulated liters or fallback to 15 km/L
    final fuelEconomy = _accumulatedTripLiters > 0 && state.currentTripDistance > 0
        ? state.currentTripDistance / _accumulatedTripLiters
        : 15.0;

    // Calculate Health Score for this trip (based on max coolant / voltage dips)
    int tripHealth = 100;
    if (state.maxCoolant > 105) tripHealth -= 15;
    if (state.maxCoolant > 115) tripHealth -= 20;

    // Update permanent odometer settings
    final currentOdo = _ref.read(settingsProvider).currentOdometer;
    final newOdo = currentOdo + state.currentTripDistance;
    _ref.read(settingsProvider.notifier).updateOdometer(newOdo);

    // Save preferences to DB
    _saveTripPreferencesToDb();

    // Update Trip record
    await (db.update(db.trips)..where((t) => t.id.equals(_activeTripId))).write(
      TripsCompanion(
        endTime: Value(endTime),
        distance: Value(state.currentTripDistance),
        avgSpeed: Value(avgSpeed),
        maxCoolant: Value(state.maxCoolant.toInt()),
        maxRpm: Value(state.maxRpm.toInt()),
        durationMinutes: Value(state.durationSeconds ~/ 60),
        idleMinutes: Value(state.idleSeconds ~/ 60),
        fuelEconomy: Value(fuelEconomy),
        tripHealthScore: Value(tripHealth),
      ),
    );

    final completedId = _activeTripId;
    _activeTripId = -1;

    state = state.copyWith(
      isRecording: false,
      lastCompletedTripId: completedId,
    );
  }

  void clearLastCompletedTrip() {
    state = state.copyWith(lastCompletedTripId: null);
  }
}

// Provider definitions
final tripRecorderProvider = StateNotifierProvider<TripRecorderNotifier, TripRecorderState>((ref) {
  return TripRecorderNotifier(ref);
});

final historicalTripsProvider = StreamProvider<List<Trip>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.trips)
    ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
    .watch();
});
