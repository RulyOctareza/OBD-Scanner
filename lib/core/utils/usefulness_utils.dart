import '../bluetooth/obd_service.dart';

/// Formats a diagnostic scan result for clipboard / share text.
String formatDtcReport(DiagnosticScanResult result) {
  final buffer = StringBuffer();
  buffer.writeln('Laporan Diagnostik AutoCare');
  buffer.writeln('Waktu: ${result.scanTimestamp.toIso8601String()}');
  buffer.writeln('Protokol: ${result.protocol}');
  if (result.vin.isNotEmpty) {
    buffer.writeln('VIN: ${result.vin}');
  }
  buffer.writeln('MIL: ${result.milStatus ? "ON" : "OFF"}');
  buffer.writeln('Jumlah DTC: ${result.dtcCount}');
  buffer.writeln();

  void writeList(String title, List<String> codes) {
    buffer.writeln(title);
    if (codes.isEmpty) {
      buffer.writeln('- (tidak ada)');
    } else {
      for (final code in codes) {
        buffer.writeln('- $code');
      }
    }
    buffer.writeln();
  }

  writeList('DTC Aktif:', result.activeDtcs);
  writeList('DTC Pending:', result.pendingDtcs);
  writeList('DTC Permanen:', result.permanentDtcs);

  if (result.imReadiness.isNotEmpty) {
    buffer.writeln('I/M Readiness:');
    result.imReadiness.forEach((key, ready) {
      buffer.writeln('- $key: ${ready ? "Siap" : "Belum"}');
    });
  }

  return buffer.toString().trim();
}
