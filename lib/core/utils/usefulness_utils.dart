import '../bluetooth/obd_service.dart';
import '../ui/format.dart';
import '../../features/diagnostics/presentation/dtc_display.dart';

/// The diagnostic scan as plain text for the clipboard, in the app's words,
/// to send to a workshop.
String formatDtcReport(DiagnosticScanResult result) {
  final buffer = StringBuffer();
  buffer.writeln('Laporan diagnostik AutoCare');
  buffer.writeln('Waktu: ${Fmt.dateTime(result.scanTimestamp)}');
  if (result.protocol.isNotEmpty) buffer.writeln('Protokol: ${result.protocol}');
  if (result.vin.isNotEmpty) buffer.writeln('VIN: ${result.vin}');
  if (result.odometerKm != null) {
    buffer.writeln('Odometer: ${Fmt.km(result.odometerKm!)}');
  }
  buffer.writeln(
    'Lampu Check Engine: ${result.milStatus ? 'Menyala' : 'Mati'}',
  );
  buffer.writeln();

  void writeList(String title, List<String> codes, {bool read = true}) {
    buffer.writeln(title);
    if (!read) {
      buffer.writeln('- belum terbaca (mobil tidak menjawab)');
    } else if (codes.isEmpty) {
      buffer.writeln('- tidak ada');
    } else {
      for (final code in codes) {
        buffer.writeln('- $code');
      }
    }
    buffer.writeln();
  }

  writeList('Kode aktif:', result.activeDtcs, read: result.activeDtcsRead);
  writeList('Kode tertunda:', result.pendingDtcs);
  writeList('Kode permanen:', result.permanentDtcs);

  final monitors = [
    for (final entry in readinessLabels.entries)
      if (result.imReadiness.containsKey(entry.key))
        '- ${entry.value}: ${result.imReadiness[entry.key]! ? 'Siap' : 'Belum siap'}',
  ];
  buffer.writeln('Kesiapan uji emisi (I/M):');
  if (monitors.isEmpty) {
    buffer.writeln('- tidak tersedia');
  } else {
    monitors.forEach(buffer.writeln);
  }

  return buffer.toString().trim();
}
