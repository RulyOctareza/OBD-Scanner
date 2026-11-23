import '../../../core/ui/status.dart';
import '../data/dtc_repository.dart';
import '../domain/dtc_model.dart';

/// Status colour of a trouble code by its severity.
StatusLevel dtcLevel(DtcSeverity severity) => switch (severity) {
      DtcSeverity.info || DtcSeverity.warning => StatusLevel.waspada,
      DtcSeverity.danger || DtcSeverity.critical => StatusLevel.kritis,
    };

/// System of a code in plain words, with its OBD letter.
String dtcCategoryLabel(String category) => switch (category.toLowerCase()) {
      'powertrain' => 'Mesin & transmisi (P)',
      'chassis' => 'Sasis (C)',
      'body' => 'Bodi (B)',
      'network' => 'Jaringan (U)',
      _ => category,
    };

/// What a driver reads first about [code]: the Indonesian explanation, or a
/// plain note when the dictionary has no entry for it.
String dtcSummary(String code) => DtcRepository.isKnown(code)
    ? DtcRepository.getCodeInfo(code).descriptionIndo
    : 'Belum ada penjelasan untuk kode ini di kamus. Tunjukkan kodenya ke '
        'bengkel.';

/// Readiness monitors in plain words (keys of ObdParser.parseImReadiness).
const Map<String, String> readinessLabels = {
  'misfire': 'Pembakaran (misfire)',
  'fuelSystem': 'Sistem bahan bakar',
  'components': 'Komponen',
  'catalyst': 'Katalis',
  'evap': 'Penguapan BBM (EVAP)',
  'o2Sensor': 'Sensor oksigen',
  'o2Heater': 'Pemanas sensor oksigen',
  'egr': 'Resirkulasi gas buang (EGR)',
};
