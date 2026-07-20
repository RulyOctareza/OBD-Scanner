import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../data/dtc_repository.dart';
import '../domain/dtc_model.dart';

class DiagnosticScannerScreen extends ConsumerStatefulWidget {
  const DiagnosticScannerScreen({super.key});

  @override
  ConsumerState<DiagnosticScannerScreen> createState() => _DiagnosticScannerScreenState();
}

class _DiagnosticScannerScreenState extends ConsumerState<DiagnosticScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatusText = 'Siap Melakukan Pemindaian';
  DiagnosticScanResult? _scanResult;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startDiagnosticScan() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.1;
      _scanStatusText = 'Menghubungkan ke Modul ECU...';
    });
    _pulseController.repeat();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.4;
      _scanStatusText = 'Membaca Kode Kerusakan Aktif (Mode 03)...';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.7;
      _scanStatusText = 'Membaca Kode Kerusakan Pending (Mode 07)...';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanProgress = 0.9;
      _scanStatusText = 'Memeriksa Uji Kesiapan Emisi (I/M Readiness)...';
    });

    final result = await ref.read(obdServiceProvider.notifier).performFullDiagnosticScan();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _pulseController.stop();

    setState(() {
      _isScanning = false;
      _scanProgress = 1.0;
      _scanStatusText = 'Pemindaian Diagnostik Selesai!';
      _scanResult = result;
    });
  }

  Future<void> _promptClearDtcs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Reset Check Engine?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'INSTRUKSI KEAMANAN ECU:\n• Pastikan Kunci Kontak pada posisi ON.\n• Mesin dalam KONDISI MATI (Engine OFF, Ignition ON).',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Perintah Mode 04 akan menghapus kode kesalahan (DTC) dan mematikan lampu Check Engine di instrumen mobil Anda.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, Hapus Kode', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mengirim perintah Reset DTC (Mode 04) ke ECU...')),
      );

      final success = await ref.read(obdServiceProvider.notifier).clearDtcCodes();

      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode DTC berhasil dihapus! Lampu Check Engine di-reset.'),
            backgroundColor: AppColors.success,
          ),
        );
        _startDiagnosticScan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus kode DTC. Pastikan ECU terhubung.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obdState = ref.watch(obdServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Diagnostik ECU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Kamus Kode DTC',
            icon: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
            onPressed: () => context.push('/dtc_lookup'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scanner Status Card with Radar Pulse animation
              _buildScannerHeroCard(obdState),
              const SizedBox(height: 20),

              // Scan Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isScanning ? null : _startDiagnosticScan,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.radar_rounded),
                      label: Text(
                        _scanResult == null ? 'Mulai Pemindaian ECU' : 'Pindai Ulang ECU',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Diagnostic Scan Results (if available)
              if (_scanResult != null) ...[
                _buildResultsSection(context, _scanResult!),
              ] else if (!_isScanning) ...[
                _buildEmptyScanPlaceholder(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerHeroCard(ObdState obdState) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isScanning)
                        Container(
                          width: 120 + (_pulseController.value * 30),
                          height: 120 + (_pulseController.value * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.3 * (1 - _pulseController.value)),
                          ),
                        ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isScanning
                              ? AppColors.primary.withOpacity(0.15)
                              : (_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                  ? AppColors.danger.withOpacity(0.15)
                                  : AppColors.success.withOpacity(0.15),
                          border: Border.all(
                            color: _isScanning
                                ? AppColors.primary
                                : (_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                    ? AppColors.danger
                                    : AppColors.success,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          _isScanning
                              ? Icons.radar_rounded
                              : (_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                  ? Icons.warning_amber_rounded
                                  : Icons.verified_rounded,
                          size: 48,
                          color: _isScanning
                              ? AppColors.primary
                              : (_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                  ? AppColors.danger
                                  : AppColors.success,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _scanStatusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_isScanning)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _scanProgress,
                  minHeight: 6,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            else
              Text(
                obdState.status == ObdStatus.connected
                    ? (obdState.isSimulatorMode ? 'Terhubung (Mode Simulator)' : 'Terhubung ke ECU (${obdState.connectedDeviceName})')
                    : 'Tidak Terhubung ke ELM327',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanPlaceholder(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.directions_car_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text(
                'Belum Ada Hasil Pemindaian',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tekan "Mulai Pemindaian ECU" di atas untuk memeriksa kode kesalahan aktif, kode pending, dan kesiapan emisi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/dtc_lookup'),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Buka Kamus Kode DTC'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, DiagnosticScanResult result) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Aktif'),
                    if (result.activeDtcs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.danger,
                        child: Text(
                          '${result.activeDtcs.length}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pending'),
                    if (result.pendingDtcs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.warning,
                        child: Text(
                          '${result.pendingDtcs.length}',
                          style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Readiness'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: TabBarView(
              children: [
                _buildActiveDtcsTab(context, result.activeDtcs),
                _buildPendingDtcsTab(context, result.pendingDtcs),
                _buildImReadinessTab(context, result.imReadiness),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clear DTCs Button if any DTC exists or available
          if (result.activeDtcs.isNotEmpty || result.pendingDtcs.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _promptClearDtcs(context),
                icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                label: const Text(
                  'Hapus Kode Kerusakan (Clear DTC / Reset MIL)',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveDtcsTab(BuildContext context, List<String> codes) {
    if (codes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
            SizedBox(height: 12),
            Text(
              'Sistem Bebas Kode Kerusakan (DTC)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
            ),
            SizedBox(height: 6),
            Text(
              'ECU kendaraan tidak mendeteksi adanya masalah aktif pada kompartemen mesin atau sensor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: codes.length,
      itemBuilder: (context, index) {
        final dtc = DtcRepository.getCodeInfo(codes[index]);
        return _buildDtcCard(context, dtc);
      },
    );
  }

  Widget _buildPendingDtcsTab(BuildContext context, List<String> codes) {
    if (codes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thumb_up_alt_rounded, color: AppColors.primary, size: 48),
            SizedBox(height: 12),
            Text(
              'Tidak Ada Kode Kerusakan Menunggu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Mode 07 tidak menemukan gejala kerusakan sporadis pada siklus mengemudi saat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: codes.length,
      itemBuilder: (context, index) {
        final dtc = DtcRepository.getCodeInfo(codes[index]);
        return _buildDtcCard(context, dtc);
      },
    );
  }

  Widget _buildImReadinessTab(BuildContext context, Map<String, bool> readiness) {
    final monitors = [
      {'key': 'misfire', 'label': 'Pengapian (Misfire System)'},
      {'key': 'fuelSystem', 'label': 'Sistem Bahan Bakar'},
      {'key': 'components', 'label': 'Komponen Komprehensif'},
      {'key': 'catalyst', 'label': 'Katalis (Catalytic Converter)'},
      {'key': 'evap', 'label': 'Sistem EVAP (Uap Bensin)'},
      {'key': 'o2Sensor', 'label': 'Sensor Oksigen (O2)'},
      {'key': 'o2Heater', 'label': 'Pemanas Sensor O2'},
      {'key': 'egr', 'label': 'Sistem Resirkulasi EGR'},
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          itemCount: monitors.length,
          separatorBuilder: (context, index) => const Divider(color: AppColors.surface, height: 1),
          itemBuilder: (context, index) {
            final monitor = monitors[index];
            final key = monitor['key'] as String;
            final label = monitor['label'] as String;
            final isComplete = readiness[key] ?? true;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  Icon(
                    isComplete ? Icons.check_circle_rounded : Icons.pending_rounded,
                    color: isComplete ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isComplete ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isComplete ? 'SIAP' : 'BELUM SIAP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isComplete ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDtcCard(BuildContext context, DtcCode dtc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dtc.code,
                    style: AppTheme.numberStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dtc.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dtc.descriptionIndo,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
