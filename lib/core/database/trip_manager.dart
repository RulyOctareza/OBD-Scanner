import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:drift/drift.dart' as drift;
import '../bluetooth/obd_service.dart';
import '../obd/obd_telemetry.dart';
import 'database.dart';
import 'database_provider.dart';

final tripManagerProvider = Provider<TripManager>((ref) {
  final manager = TripManager(
    ref.read(databaseProvider),
    ref,
  );
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});

class TripManager {
  final AppDatabase _db;
  final Ref _ref;
  
  int? _currentTripId;
  Position? _lastPosition;
  double _currentTripDistance = 0.0;
  DateTime? _tripStartTime;
  
  StreamSubscription? _obdSubscription;
  Timer? _tripCheckTimer;

  TripManager(this._db, this._ref) {
    _init();
  }

  void _init() {
    _obdSubscription = _ref.read(obdServiceProvider.notifier).stream.listen((state) {
      _handleObdState(state);
    });

    _tripCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkTripStatus();
    });
  }

  Future<void> _handleObdState(ObdState state) async {
    if (state.status == ObdStatus.connected) {
      final rpm = state.telemetry.rpm;
      
      // Start trip if RPM > 0 and no trip is active
      if (rpm > 0 && _currentTripId == null) {
        await _startNewTrip();
      }

      // Record telemetry if trip is active
      if (_currentTripId != null) {
        await _recordTelemetry(state.telemetry);
        await _updateLocation();
      }
    } else {
      // If disconnected, end trip
      if (_currentTripId != null) {
        await _endCurrentTrip();
      }
    }
  }

  Future<void> _checkTripStatus() async {
    if (_currentTripId != null) {
      final state = _ref.read(obdServiceProvider);
      // If engine is off for a while, end trip
      if (state.telemetry.rpm == 0 && state.status == ObdStatus.connected) {
        // Here we could implement a delay, but for now we'll end it immediately if checked
        // Actually it's better to keep it alive if it's just 0 RPM (e.g. idle stop/start)
        // For simplicity, we just rely on disconnect or extreme idle time.
      }
    }
  }

  Future<void> _startNewTrip() async {
    _tripStartTime = DateTime.now();
    _currentTripDistance = 0.0;
    _lastPosition = null;

    final trip = await _db.into(_db.trips).insert(
      TripsCompanion.insert(
        startTime: _tripStartTime!,
      ),
    );
    _currentTripId = trip;
  }

  Future<void> _recordTelemetry(ObdTelemetry telemetry) async {
    if (_currentTripId == null) return;
    
    await _db.into(_db.tripPoints).insert(
      TripPointsCompanion.insert(
        tripId: _currentTripId!,
        timestamp: DateTime.now(),
        rpm: telemetry.rpm,
        speed: telemetry.speed,
        coolant: telemetry.coolant,
        voltage: telemetry.voltage,
        mapValue: telemetry.mapValue,
        throttle: drift.Value(telemetry.throttle),
        engineLoad: drift.Value(telemetry.engineLoad),
      ),
    );
  }

  Future<void> _updateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _currentTripDistance += (distance / 1000.0); // convert meters to km
      }
      
      _lastPosition = position;
    } catch (e) {
      // Handle location error gracefully
    }
  }

  Future<void> _endCurrentTrip() async {
    if (_currentTripId == null || _tripStartTime == null) return;

    final endTime = DateTime.now();
    final durationMins = endTime.difference(_tripStartTime!).inMinutes;

    // Calculate averages (Optional, could be done via SQL query later, but doing simple save here)
    await _db.update(_db.trips).replace(
      TripsCompanion(
        id: drift.Value(_currentTripId!),
        startTime: drift.Value(_tripStartTime!),
        endTime: drift.Value(endTime),
        distance: drift.Value(_currentTripDistance),
        durationMinutes: drift.Value(durationMins),
        // other fields like fuelEconomy, avgSpeed can be updated later based on TripPoints
      ),
    );

    _currentTripId = null;
    _tripStartTime = null;
    _currentTripDistance = 0.0;
  }

  void dispose() {
    _obdSubscription?.cancel();
    _tripCheckTimer?.cancel();
    _endCurrentTrip();
  }
}
