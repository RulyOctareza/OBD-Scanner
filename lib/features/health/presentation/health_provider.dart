import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/health_engine.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../../core/bluetooth/obd_service.dart';

final healthProvider = Provider<HealthReport>((ref) {
  final telemetry = ref.watch(
    obdServiceProvider.select((s) => s.telemetry),
  );
  final nextOilOdometer = ref.watch(
    settingsProvider.select((s) => s.nextOilOdometer),
  );
  final currentOdometer = ref.watch(
    settingsProvider.select((s) => s.currentOdometer),
  );
  final vehicleName = ref.watch(
    settingsProvider.select((s) => s.vehicleName),
  );
  final dtcsChecked = ref.watch(
    obdServiceProvider.select((s) => s.dtcsChecked),
  );

  return HealthEngine.calculate(
    telemetry,
    nextOilOdometer: nextOilOdometer,
    currentOdometer: currentOdometer,
    vehicleName: vehicleName,
    dtcsChecked: dtcsChecked,
  );
});
