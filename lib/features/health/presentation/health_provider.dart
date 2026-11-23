import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/health_engine.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../../core/bluetooth/obd_service.dart';

/// The health report for one OBD state and the settings. An odometer or oil
/// target of 0 is not entered yet and gives no oil reminder.
HealthReport healthReportFor(ObdState obd, SettingsState settings) =>
    HealthEngine.calculate(
      obd.telemetry,
      nextOilOdometer: settings.hasOilSchedule ? settings.nextOilOdometer : null,
      currentOdometer: settings.hasOdometer ? settings.currentOdometer : null,
      vehicleName: settings.vehicleName,
      dtcsChecked: obd.dtcsChecked,
    );

// Recomputed on every OBD answer while something listens to it. Every
// Riverpod refresh of a listened provider costs the whole screen a frame, so
// only Beranda watches it, and only while visible (watchVisible); nothing may
// keep it listened from an offstage tab.
final healthProvider = Provider<HealthReport>((ref) {
  final telemetry = ref.watch(
    obdServiceProvider.select((s) => s.telemetry),
  );
  final nextOilOdometer = ref.watch(
    settingsProvider.select((s) => s.hasOilSchedule ? s.nextOilOdometer : null),
  );
  final currentOdometer = ref.watch(
    settingsProvider.select((s) => s.hasOdometer ? s.currentOdometer : null),
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
