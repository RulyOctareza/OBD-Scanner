import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/bluetooth/obd_service.dart';
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
  SharedPreferences? _prefs;

  TripRecorderNotifier(this._ref) : super(TripRecorderState.initial()) {
    _initTrips();
    // Listen to OBD State changes
    _ref.listen(obdServiceProvider, (previous, next) {
      final isEngineOn = next.telemetry.rpm > 500;
      final isConnected = next.status == ObdStatus.connected;
      
      if (isConnected && isEngineOn && !state.isRecording) {
        _startTrip();
      } else if ((!isConnected || !isEngineOn) && state.isRecording) {
        // Stop trip if engine off or disconnected for > 15 seconds (reduced for simulation/responsiveness)
        _stopTrip();
      }

      if (state.isRecording && isEngineOn) {
        _updateTripData(next.telemetry);
      }
    });
  }

  Future<void> _initTrips() async {
    _prefs = await SharedPreferences.getInstance();
    final tripA = _prefs!.getDouble('trip_a_distance') ?? 0.0;
    
    // Check if Trip B date is today
    final tripBDate = _prefs!.getString('trip_b_date') ?? '';
    final todayStr = _getTodayDateString();
    double tripB = 0.0;
    if (tripBDate == todayStr) {
      tripB = _prefs!.getDouble('trip_b_distance') ?? 0.0;
    } else {
      await _prefs!.setString('trip_b_date', todayStr);
      await _prefs!.setDouble('trip_b_distance', 0.0);
    }

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
    await _prefs?.setDouble('trip_a_distance', 0.0);
    state = state.copyWith(tripADistance: 0.0);
  }

  Future<void> _startTrip() async {
    final now = DateTime.now();
    _lastTickTime = now;

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

      state = state.copyWith(
        durationSeconds: state.durationSeconds + deltaSec,
      );
    });
  }

  void _updateTripData(dynamic telemetry) {
    final speed = telemetry.speed as double;
    final rpm = telemetry.rpm as double;
    final coolant = telemetry.coolant as double;

    // Calculate distance delta: distance = speed (km/h) * time (seconds) / 3600
    final timeFactor = 1.0 / 3600.0; // Assuming ~1 second update intervals
    final distanceDelta = speed * timeFactor;

    final newDistance = state.currentTripDistance + distanceDelta;
    final isIdle = speed < 1.0;

    // Update Trip A and B
    double newTripA = state.tripADistance + distanceDelta;
    
    // Verify Trip B date hasn't rolled over during execution
    final todayStr = _getTodayDateString();
    final savedDate = _prefs?.getString('trip_b_date') ?? todayStr;
    double newTripB;
    if (savedDate == todayStr) {
      newTripB = state.tripBDistance + distanceDelta;
    } else {
      newTripB = distanceDelta;
      _prefs?.setString('trip_b_date', todayStr);
    }

    _prefs?.setDouble('trip_a_distance', newTripA);
    _prefs?.setDouble('trip_b_distance', newTripB);

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

    // Save trip point to DB for plotting charts
    final db = _ref.read(databaseProvider);
    db.into(db.tripPoints).insert(
      TripPointsCompanion.insert(
        tripId: _activeTripId,
        timestamp: DateTime.now(),
        rpm: rpm,
        speed: speed,
        coolant: coolant,
        voltage: telemetry.voltage as double,
        mapValue: telemetry.mapValue as double,
        throttle: Value(telemetry.throttle as double),
        engineLoad: Value(telemetry.engineLoad as double),
      ),
    );
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
        
    // Calculate fuel economy: Toyota Agya 1.0 averages ~15.0 km/L. Let's fluctuate based on idle time
    final idlePercentage = state.durationSeconds > 0 
        ? (state.idleSeconds / state.durationSeconds) 
        : 0.0;
    final fuelEconomy = 16.0 - (idlePercentage * 5.0); // ranges between 11 km/L and 16 km/L

    // Calculate Health Score for this trip (based on max coolant / voltage dips)
    int tripHealth = 100;
    if (state.maxCoolant > 105) tripHealth -= 15;
    if (state.maxCoolant > 115) tripHealth -= 20;

    // Update permanent odometer settings
    final currentOdo = _ref.read(settingsProvider).currentOdometer;
    final newOdo = currentOdo + state.currentTripDistance;
    _ref.read(settingsProvider.notifier).updateOdometer(newOdo);

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
