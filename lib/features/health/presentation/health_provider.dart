import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/health_engine.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../../core/bluetooth/obd_service.dart';

final healthProvider = Provider<HealthReport>((ref) {
  final obdState = ref.watch(obdServiceProvider);
  final settings = ref.watch(settingsProvider);
  
  return HealthEngine.calculate(
    obdState.telemetry,
    nextOilOdometer: settings.nextOilOdometer,
    currentOdometer: settings.currentOdometer,
    vehicleName: settings.vehicleName,
  );
});
