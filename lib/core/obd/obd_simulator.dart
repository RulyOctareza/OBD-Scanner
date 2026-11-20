import 'dart:async';
import 'dart:math';
import 'obd_telemetry.dart';

class ObdSimulator {
  final _controller = StreamController<ObdTelemetry>.broadcast();
  Timer? _timer;
  double _tick = 0;
  
  // Simulator configuration states
  bool _isEngineRunning = true;
  bool _hasHighTemp = false;
  bool _hasLowVoltage = false;
  List<String> _injectedDtcs = [];
  
  // Current values to smoothly interpolate
  double _currentCoolant = 65.0;
  double _currentVoltage = 14.1;
  double _currentSpeed = 0.0;
  double _currentRpm = 850.0;
  double _currentOdometer = 161420.0;
  double _currentFuelLevel = 72.5;

  Stream<ObdTelemetry> get telemetryStream => _controller.stream;

  bool get isRunning => _timer != null;
  bool get isEngineRunning => _isEngineRunning;
  bool get hasHighTemp => _hasHighTemp;
  bool get hasLowVoltage => _hasLowVoltage;
  List<String> get injectedDtcs => List.unmodifiable(_injectedDtcs);

  /// Seconds of simulated time one timer tick represents.
  double _intervalSeconds = 0.5;

  void start({int intervalMs = 500}) {
    _timer?.cancel();
    _intervalSeconds = intervalMs / 1000.0;
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      _tick += 0.05;
      _step();
      _emit();
    });
    // Emit immediately so UI leaves "disconnected" without waiting a tick.
    _emit();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Clears demo triggers so switches / ECU state don't stay stuck after exit.
  void resetDemoTriggers({bool engineRunning = true}) {
    _isEngineRunning = engineRunning;
    _hasHighTemp = false;
    _hasLowVoltage = false;
    _injectedDtcs = [];
  }

  void configure({
    bool? isEngineRunning,
    bool? hasHighTemp,
    bool? hasLowVoltage,
    List<String>? injectedDtcs,
  }) {
    if (isEngineRunning != null) _isEngineRunning = isEngineRunning;
    if (hasHighTemp != null) _hasHighTemp = hasHighTemp;
    if (hasLowVoltage != null) _hasLowVoltage = hasLowVoltage;
    if (injectedDtcs != null) _injectedDtcs = injectedDtcs;
    if (isRunning) _emit();
  }

  void clearDtcs() {
    _injectedDtcs = [];
    _emit();
  }

  void injectDtc(String code) {
    if (!_injectedDtcs.contains(code)) {
      _injectedDtcs = [..._injectedDtcs, code];
      _emit();
    }
  }

  /// Advances the simulation by one timer interval. Only the periodic timer
  /// may call this: odometer, fuel drain and smoothing all assume a full
  /// interval elapsed, so stepping on an out-of-band emit (start, a demo
  /// switch) would add phantom distance that Settings then persists as the
  /// odometer.
  void _step() {
    if (!_isEngineRunning) {
      // cool down slowly
      if (_currentCoolant > 35) _currentCoolant -= 0.5;
      return;
    }

    // 1. Coolant simulation (heats up to ~90C, or >105C if high temp requested)
    final targetCoolant = _hasHighTemp ? 109.0 : 90.0;
    _currentCoolant += (targetCoolant - _currentCoolant) * 0.03; // smooth approach

    // 2. Voltage simulation (fluctuates around 13.8V-14.2V, or drops to 11.5V)
    final targetVoltage = _hasLowVoltage ? 11.4 : (13.9 + sin(_tick) * 0.1);
    _currentVoltage += (targetVoltage - _currentVoltage) * 0.1;

    // 3. Driving Speed & RPM simulation (simulates acceleration cycles)
    // Speed cycles up and down using a sine wave
    final speedWave = (sin(_tick) + 1.0) / 2.0; // 0.0 to 1.0
    final targetSpeed = speedWave * 75.0; // Speed fluctuates between 0 and 75 km/h
    _currentSpeed += (targetSpeed - _currentSpeed) * 0.15;
    if (_currentSpeed < 1.0) _currentSpeed = 0.0;

    // RPM relates to speed (shifts gears)
    double targetRpm = 850.0; // Idle
    if (_currentSpeed > 0.5) {
      // Simple gear shifting simulation
      final speedInt = _currentSpeed.toInt();
      final gear = (speedInt ~/ 25) + 1; // 1st gear, 2nd gear, 3rd gear...
      final gearSpeed = speedInt % 25; // 0 to 25
      targetRpm = 1000.0 + (gearSpeed * 80.0) + (gear * 200.0);

      // Add acceleration bumps
      if (sin(_tick * 2) > 0.7) {
        targetRpm += 300.0; // Accel spike
      }
    } else {
      // Idle vibration
      targetRpm += (Random().nextDouble() - 0.5) * 40.0;
    }
    _currentRpm += (targetRpm - _currentRpm) * 0.25;

    // 4. Odometer: distance = speed (km/h) × interval (s) / 3600
    _currentOdometer += _currentSpeed * (_intervalSeconds / 3600.0);

    // 5. Fuel level drains very slowly based on engine load
    _currentFuelLevel -= (0.00005 + (_engineLoad() / 100.0) * 0.0001);
    if (_currentFuelLevel < 0.0) _currentFuelLevel = 0.0;
  }

  double _engineLoad() => max(10.0, (_currentRpm / 4000.0) * 75.0 + 8.0);

  /// Publishes the current state without advancing time.
  void _emit() {
    if (!_isEngineRunning) {
      // Engine Off: 0 RPM, 0 Speed, ~12.2V, ambient coolant
      _currentRpm = 0;
      _currentSpeed = 0;
      _currentVoltage = _hasLowVoltage ? 11.0 : 12.3;
      _controller.add(
        ObdTelemetry(
          rpm: 0,
          speed: 0,
          coolant: _currentCoolant,
          voltage: _currentVoltage,
          mapValue: 101.0, // Ambient pressure
          throttle: 0,
          engineLoad: 0,
          dtcs: _injectedDtcs,
          odometer: _currentOdometer,
          fuelLevel: _currentFuelLevel,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    // MAP, Throttle, and Engine Load based on RPM
    final rpmRatio = _currentRpm / 4000.0;
    final throttle = max(4.0, rpmRatio * 50.0 + (sin(_tick * 3) > 0.5 ? 15.0 : 0.0));
    final mapValue = 30.0 + rpmRatio * 50.0;

    _controller.add(
      ObdTelemetry(
        rpm: _currentRpm,
        speed: _currentSpeed,
        coolant: _currentCoolant,
        voltage: _currentVoltage,
        mapValue: mapValue,
        throttle: throttle,
        engineLoad: _engineLoad(),
        dtcs: _injectedDtcs,
        odometer: _currentOdometer,
        fuelLevel: _currentFuelLevel,
        timestamp: DateTime.now(),
      ),
    );
  }
}
