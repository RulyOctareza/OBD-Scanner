import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/obd_service.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/usefulness_utils.dart';
import '../../../core/widgets/live_obd.dart';
import '../data/dtc_repository.dart';
import '../domain/dtc_model.dart';
import 'diagnostic_scan_provider.dart';
import 'dtc_detail_sheet.dart';
import 'dtc_display.dart';

/// Plain words for the scan step at [progress]; the service's own step
/// texts name OBD modes.
String scanStepLabel(double progress) {
  if (progress < 0.3) return 'Menghubungi komputer mobil…';
  if (progress < 0.5) return 'Membaca identitas mobil…';
  if (progress < 0.7) return 'Memeriksa sensor yang didukung…';
  if (progress < 0.85) return 'Membaca kode kerusakan aktif…';
  if (progress < 0.95) return 'Membaca kode tertunda dan permanen…';
  return 'Memeriksa kesiapan uji emisi…';
}

/// Diagnostik › Pindai: scan, results that explain each code, emissions
/// readiness and the clear flow. The scan lives in [diagnosticScanProvider],
/// so leaving the screen neither stops it nor loses its result.
class DiagnosticScannerScreen extends ConsumerWidget {
  const DiagnosticScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watchVisible(
      context,
      obdServiceProvider.select((s) => s.status == ObdStatus.connected),
    );
    final scan = ref.watchVisible(context, diagnosticScanProvider);
    final result = scan.result;

    return Scaffold(
      appBar: AppBar(
        title: const SegmentSwitch(
          segments: diagnosticSegments,
          current: '/diagnostics',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.xs,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        children: [
          const ConnectionStatusBar(),
          const SizedBox(height: AppSpacing.md),
          _ScanCard(scan: scan, connected: connected),
          if (result != null) ...[
            _CodeSection(
              title: 'Kode aktif',
              note: 'Kode yang membuat lampu Check Engine menyala.',
              codes: result.activeDtcs,
              read: result.activeDtcsRead,
              emptyText: 'Tidak ada kode aktif',
            ),
            if (result.pendingDtcs.isNotEmpty)
              _CodeSection(
                title: 'Kode tertunda',
                note: 'Terdeteksi sekali dan belum menyalakan lampu Check '
                    'Engine.',
                codes: result.pendingDtcs,
              ),
            if (result.permanentDtcs.isNotEmpty)
              _CodeSection(
                title: 'Kode permanen',
                note: 'Baru hilang sendiri setelah diperbaiki dan beberapa '
                    'kali berkendara.',
                codes: result.permanentDtcs,
              ),
            _ReadinessSection(
              readiness: result.imReadiness,
              resetByClear: scan.readinessReset,
            ),
            _VehicleSection(result: result),
            if (connected &&
                (result.activeDtcs.isNotEmpty || result.pendingDtcs.isNotEmpty))
              _ClearSection(clearing: scan.clearing),
          ],
        ],
      ),
    );
  }
}

class _ScanCard extends ConsumerWidget {
  const _ScanCard({required this.scan, required this.connected});

  final DiagnosticScanState scan;
  final bool connected;

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(diagnosticScanProvider.notifier).scan();
    } catch (_) {
      if (!context.mounted) return;
      await showInfoDialog(
        context,
        title: 'Pemindaian berhenti',
        message: 'Adapter tidak menjawab. Periksa koneksi, lalu pindai lagi.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final result = scan.result;

    if (scan.phase == ScanPhase.scanning) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Memindai…', style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(scanStepLabel(scan.progress), style: text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            // Determinate: it moves only when a step finishes.
            LinearProgressIndicator(value: scan.progress),
          ],
        ),
      );
    }

    if (result == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pindai kode kerusakan', style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Membaca kode kerusakan, lampu Check Engine dan kesiapan uji '
              'emisi dari mobil. Sekitar 10–20 detik, kunci kontak ON.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: connected ? () => _scan(context, ref) : null,
              icon: const Icon(Icons.troubleshoot_rounded),
              label: const Text('Pindai sekarang'),
            ),
            if (!connected) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Hubungkan adapter dulu.', style: text.bodySmall),
            ],
          ],
        ),
      );
    }

    final active = result.activeDtcs.length;
    final StatusLevel level;
    final String title;
    if (!result.activeDtcsRead) {
      level = StatusLevel.noData;
      title = 'Kode aktif belum terbaca';
    } else if (active > 0) {
      level = StatusLevel.kritis;
      title = '$active kode kerusakan aktif';
    } else {
      level = StatusLevel.ok;
      title = 'Tidak ada kode kerusakan aktif';
    }
    final mil = result.milStatus
        ? 'Lampu Check Engine menyala'
        : 'Lampu Check Engine mati';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusIcon(level),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(
                      '$mil · Dipindai ${Fmt.relative(result.scanTimestamp)}',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: connected ? () => _scan(context, ref) : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Pindai ulang'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: formatDtcReport(result)),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Laporan disalin')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Salin laporan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeSection extends StatelessWidget {
  const _CodeSection({
    required this.title,
    required this.note,
    required this.codes,
    this.read = true,
    this.emptyText,
  });

  final String title;
  final String note;
  final List<String> codes;

  /// False when the car gave no real answer for this list.
  final bool read;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Widget body;
    if (!read) {
      body = AppCard(
        child: Row(
          children: [
            const StatusIcon(StatusLevel.noData, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Belum terbaca: mobil tidak menjawab permintaan kode. '
                'Pastikan kunci kontak ON, lalu pindai ulang.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    } else if (codes.isEmpty) {
      body = AppCard(
        child: Row(
          children: [
            const StatusIcon(StatusLevel.ok, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(emptyText ?? 'Tidak ada', style: text.bodyLarge)),
          ],
        ),
      );
    } else {
      body = SettingsGroup(
        children: [for (final code in codes) DtcRow(code: code)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Text(note, style: text.bodySmall),
        ),
        body,
      ],
    );
  }
}

/// One trouble code: its plain explanation first, the code and severity
/// second; tap for symptoms, causes and what to do.
class DtcRow extends StatelessWidget {
  const DtcRow({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final dtc = DtcRepository.getCodeInfo(code);
    return ListTile(
      leading: StatusIcon(dtcLevel(dtc.severity), size: 32),
      title: WordFitText(dtcSummary(code)),
      subtitle: WordFitText('${dtc.code} · ${dtc.severity.label}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showDtcDetailSheet(context, code),
    );
  }
}

class _ReadinessSection extends StatelessWidget {
  const _ReadinessSection({required this.readiness, this.resetByClear = false});

  final Map<String, bool> readiness;

  /// Codes were cleared since the scan: the monitors restarted, so an empty
  /// map means "not read again yet", not "the car does not report this".
  final bool resetByClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final monitors = [
      for (final entry in readinessLabels.entries)
        if (readiness.containsKey(entry.key)) (entry.value, readiness[entry.key]!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Kesiapan uji emisi (I/M)'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Text(
            'Monitor yang belum siap biasanya siap sendiri setelah beberapa '
            'kali berkendara, misalnya sesudah kode dihapus atau aki dilepas.',
            style: text.bodySmall,
          ),
        ),
        if (monitors.isEmpty)
          AppCard(
            child: Row(
              children: [
                const StatusIcon(StatusLevel.noData, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    resetByClear
                        ? 'Direset karena kode baru saja dihapus. Pindai '
                            'ulang untuk melihat statusnya.'
                        : 'Tidak tersedia: mobil tidak melaporkan data ini.',
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          SettingsGroup(
            children: [
              for (final (label, ready) in monitors)
                ListTile(
                  title: Text(label),
                  trailing: StatusChip(
                    ready ? StatusLevel.ok : StatusLevel.waspada,
                    label: ready ? 'Siap' : 'Belum siap',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _VehicleSection extends StatelessWidget {
  const _VehicleSection({required this.result});

  final DiagnosticScanResult result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(String label, String value) => ListTile(
          title: Text(label),
          trailing: Text(value, style: text.bodyMedium),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Info mobil'),
        SettingsGroup(
          children: [
            row('Protokol', result.protocol.isEmpty ? Fmt.pending : result.protocol),
            if (result.vin.isNotEmpty) row('VIN', result.vin),
            if (result.odometerKm != null)
              row('Odometer (dari mobil)', Fmt.km(result.odometerKm!)),
            row('Sensor yang didukung', '${result.supportedSensorsCount}'),
          ],
        ),
      ],
    );
  }
}

class _ClearSection extends ConsumerWidget {
  const _ClearSection({required this.clearing});

  final bool clearing;

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus kode kerusakan?',
      message: 'Lampu Check Engine akan mati, tetapi kerusakannya belum tentu '
          'hilang: kode yang sama bisa muncul lagi. Data kesiapan uji emisi '
          'ikut terhapus.\n\nNyalakan kunci kontak (ON) dengan mesin mati '
          'sebelum menghapus.',
      confirmLabel: 'Hapus kode',
      destructive: true,
    );
    if (!confirmed) return;
    final result =
        await ref.read(diagnosticScanProvider.notifier).clearCodes();
    if (!context.mounted) return;
    switch (result.outcome) {
      case DtcClearOutcome.cleared:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode kerusakan terhapus. Lampu Check Engine mati.'),
          ),
        );
      case DtcClearOutcome.partial:
        await showInfoDialog(
          context,
          title: 'Sebagian kode masih ada',
          message: 'Masih ada: ${result.remaining.join(', ')}. Kode itu '
              'biasanya muncul lagi karena kerusakannya masih ada. Periksakan '
              'ke bengkel.',
        );
      case DtcClearOutcome.rejected:
        await showInfoDialog(
          context,
          title: 'Mobil menolak menghapus kode',
          message: 'Banyak mobil hanya mengizinkan penghapusan saat kunci '
              'kontak ON dan mesin mati. Matikan mesin, nyalakan kontak, '
              'lalu coba lagi.',
        );
      case DtcClearOutcome.failed:
        await showInfoDialog(
          context,
          title: 'Hasilnya tidak bisa dipastikan',
          message: 'Adapter tidak menjawab setelah perintah hapus. Pindai '
              'ulang untuk melihat keadaan kode sebenarnya.',
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Hapus kode kerusakan'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hapus kode hanya setelah kerusakannya diperbaiki. Bengkel '
                'membutuhkan kode ini untuk memeriksa mobil.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                ),
                onPressed: clearing ? null : () => _clear(context, ref),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(clearing ? 'Menghapus…' : 'Hapus kode kerusakan'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
