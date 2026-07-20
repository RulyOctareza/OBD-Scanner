enum DtcSeverity {
  info,
  warning,
  danger,
  critical,
}

extension DtcSeverityX on DtcSeverity {
  String get label {
    switch (this) {
      case DtcSeverity.info:
        return 'Informasi';
      case DtcSeverity.warning:
        return 'Peringatan';
      case DtcSeverity.danger:
        return 'Bahaya';
      case DtcSeverity.critical:
        return 'Kritis';
    }
  }
}

class DtcCode {
  final String code;
  final String title;
  final String category; // Powertrain (P), Chassis (C), Body (B), Network (U)
  final DtcSeverity severity;
  final String descriptionIndo;
  final List<String> symptoms;
  final List<String> possibleCauses;
  final List<String> recommendations;

  const DtcCode({
    required this.code,
    required this.title,
    required this.category,
    required this.severity,
    required this.descriptionIndo,
    required this.symptoms,
    required this.possibleCauses,
    required this.recommendations,
  });
}
