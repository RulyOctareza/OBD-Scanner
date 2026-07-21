import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import '../../../core/utils/usefulness_utils.dart';
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
    final obdState = ref.read(obdServiceProvider);
    if (obdState.status != ObdStatus.connected) {
      _showDisconnectedDialog(context);
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0.05;
      _scanStatusText = 'Memulai Inisialisasi Pemindaian ECU...';
    });
    _pulseController.repeat();

    final result = await ref.read(obdServiceProvider.notifier).performFullDiagnosticScan(
      onProgress: (progress, statusText) {
        if (!mounted) return;
        setState(() {
          _scanProgress = progress;
          _scanStatusText = statusText;
        });
      },
    );

    if (!mounted) return;
    _pulseController.stop();

    setState(() {
      _isScanning = false;
      _scanProgress = 1.0;
      _scanStatusText = 'Pemindaian Diagnostik ECU Selesai!';
      _scanResult = result;
    });
  }

  void _showDisconnectedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled_rounded, color: AppColors.warning, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('OBD Tidak Terhubung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: const Text(
            'Pemindaian ECU hanya dapat dilakukan jika aplikasi terhubung ke perangkat OBD-II (atau Mode Simulator aktif).\n\nSilakan hubungkan perangkat Bluetooth OBD-II Anda terlebih dahulu.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(context);
                showObdConnectionSheet(context, ref);
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Hubungkan OBD'),
            ),
          ],
        );
      },
    );
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
    final isConnected = obdState.status == ObdStatus.connected;

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
              // Connection status warning banner if disconnected
              if (!isConnected) _buildDisconnectedBanner(context),

              // Scanner Status Card with Radar Pulse animation
              _buildScannerHeroCard(obdState, isConnected),
              const SizedBox(height: 20),

              // Scan Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isConnected ? AppColors.primary : AppColors.warning,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isScanning
                          ? null
                          : (isConnected ? _startDiagnosticScan : () => showObdConnectionSheet(context, ref)),
                      icon: _isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(isConnected ? Icons.radar_rounded : Icons.bluetooth_searching),
                      label: Text(
                        !isConnected
                            ? 'Hubungkan OBD-II untuk Memindai'
                            : (_scanResult == null ? 'Mulai Pemindaian ECU' : 'Pindai Ulang ECU'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: !isConnected ? Colors.black : Colors.white,
                        ),
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
                _buildEmptyScanPlaceholder(context, isConnected),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth_disabled_rounded, color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'OBD-II Tidak Terhubung',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warning),
                ),
                SizedBox(height: 2),
                Text(
                  'Pemindaian ECU hanya dapat dilakukan saat terhubung ke adaptor OBD-II.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showObdConnectionSheet(context, ref),
            child: const Text('Hubungkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerHeroCard(ObdState obdState, bool isConnected) {
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
                              : (!isConnected
                                  ? AppColors.warning.withOpacity(0.15)
                                  : ((_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                      ? AppColors.danger.withOpacity(0.15)
                                      : AppColors.success.withOpacity(0.15))),
                          border: Border.all(
                            color: _isScanning
                                ? AppColors.primary
                                : (!isConnected
                                    ? AppColors.warning
                                    : ((_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                        ? AppColors.danger
                                        : AppColors.success)),
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          _isScanning
                              ? Icons.radar_rounded
                              : (!isConnected
                                  ? Icons.bluetooth_disabled_rounded
                                  : ((_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                      ? Icons.warning_amber_rounded
                                      : Icons.verified_rounded)),
                          size: 48,
                          color: _isScanning
                              ? AppColors.primary
                              : (!isConnected
                                  ? AppColors.warning
                                  : ((_scanResult != null && _scanResult!.activeDtcs.isNotEmpty)
                                      ? AppColors.danger
                                      : AppColors.success)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning
                  ? _scanStatusText
                  : (!isConnected ? 'OBD-II Tidak Terhubung' : _scanStatusText),
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
                isConnected
                    ? (obdState.isSimulatorMode ? 'Terhubung (Mode Simulator)' : 'Terhubung ke ECU (${obdState.connectedDeviceName})')
                    : 'Koneksi OBD-II diperlukan untuk memindai ECU',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? AppColors.textSecondary : AppColors.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanPlaceholder(BuildContext context, bool isConnected) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                isConnected ? Icons.directions_car_rounded : Icons.bluetooth_searching_rounded,
                size: 48,
                color: isConnected ? AppColors.textSecondary : AppColors.warning,
              ),
              const SizedBox(height: 12),
              Text(
                isConnected ? 'Belum Ada Hasil Pemindaian' : 'Scanner Butuh Koneksi OBD-II',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                isConnected
                    ? 'Tekan "Mulai Pemindaian ECU" di atas untuk memeriksa kode kesalahan aktif, kode pending, dan kesiapan emisi.'
                    : 'Hubungkan Bluetooth ke ELM327 atau aktifkan Mode Simulator di Pengaturan agar dapat memindai ECU kendaraan Anda.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (!isConnected)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => showObdConnectionSheet(context, ref),
                  icon: const Icon(Icons.bluetooth, size: 18),
                  label: const Text('Hubungkan OBD Sekarang'),
                )
              else
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ECU Header & Vehicle Info Summary Card
        _buildEcuInfoSummaryCard(result),
        const SizedBox(height: 16),

        // Diagnostic Tabs Header & Views
        DefaultTabController(
          length: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(
                    child: Row(
                      children: [
                        const Text('Aktif (03)'),
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
                      children: [
                        const Text('Pending (07)'),
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
                  Tab(
                    child: Row(
                      children: [
                        const Text('Permanen (0A)'),
                        if (result.permanentDtcs.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Colors.purple,
                            child: Text(
                              '${result.permanentDtcs.length}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Kesiapan Emisi'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 360,
                child: TabBarView(
                  children: [
                    _buildActiveDtcsTab(context, result.activeDtcs),
                    _buildPendingDtcsTab(context, result.pendingDtcs),
                    _buildPermanentDtcsTab(context, result.permanentDtcs),
                    _buildImReadinessTab(context, result.imReadiness),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Action Buttons (Clear DTC & Full Diagnostic Report)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showDiagnosticReportSheet(context, result),
                      icon: const Icon(Icons.assignment_rounded, color: AppColors.primary),
                      label: const Text(
                        'Laporan Diagnostik',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.textSecondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final text = formatDtcReport(result);
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Laporan DTC disalin ke clipboard'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
                      label: const Text(
                        'Salin Laporan',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              if (result.activeDtcs.isNotEmpty || result.pendingDtcs.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _promptClearDtcs(context),
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                    label: const Text(
                      'Reset MIL / Clear DTC',
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEcuInfoSummaryCard(DiagnosticScanResult result) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.developer_board_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan Komunikasi ECU',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: result.milStatus
                        ? AppColors.danger.withOpacity(0.15)
                        : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: result.milStatus ? AppColors.danger : AppColors.success,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        result.milStatus ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        color: result.milStatus ? AppColors.danger : AppColors.success,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        result.milStatus ? 'MIL NYALA' : 'MIL NORMAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: result.milStatus ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.surface),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEcuDetailTile(
                    icon: Icons.memory_rounded,
                    label: 'Protokol ECU',
                    value: result.protocol,
                  ),
                ),
                Expanded(
                  child: _buildEcuDetailTile(
                    icon: Icons.directions_car_rounded,
                    label: 'VIN Kendaraan',
                    value: result.vin,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildEcuDetailTile(
                    icon: Icons.sensors_rounded,
                    label: 'Cakupan Sensor',
                    value: '${result.supportedSensorsCount} Parameter',
                  ),
                ),
                Expanded(
                  child: _buildEcuDetailTile(
                    icon: Icons.bug_report_rounded,
                    label: 'Total DTC Fungsional',
                    value: '${result.dtcCount} Kode Ditemukan',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEcuDetailTile({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermanentDtcsTab(BuildContext context, List<String> codes) {
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
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 48),
            SizedBox(height: 12),
            Text(
              'Tidak Ada Kode Kerusakan Permanen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Mode 0A tidak menemukan DTC permanen yang disimpan pada memori non-volatile ECU.',
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

  void _showDiagnosticReportSheet(BuildContext context, DiagnosticScanResult result) {
    final obdState = ref.read(obdServiceProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.article_rounded, color: AppColors.primary, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Laporan Hasil Diagnostik ECU',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Perangkat OBD: ${obdState.connectedDeviceName ?? "ELM327 Adaptive"}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Waktu Scan: ${result.scanTimestamp.toString().split('.')[0]}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Nomor VIN: ${result.vin}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Protokol ECU: ${result.protocol}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Status Lampu Check Engine (MIL): ${result.milStatus ? "MENYALA" : "NORMAL"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: result.milStatus ? AppColors.danger : AppColors.success,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Daftar Kode Kerusakan (DTC):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (result.activeDtcs.isEmpty && result.pendingDtcs.isEmpty && result.permanentDtcs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sistem ECU Bersih. Tidak ada DTC Aktif, Pending, maupun Permanen.',
                              style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (result.activeDtcs.isNotEmpty) ...[
                      const Text('• Kode Aktif (Mode 03):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger)),
                      ...result.activeDtcs.map((code) {
                        final dtc = DtcRepository.getCodeInfo(code);
                        return ListTile(
                          dense: true,
                          title: Text('${dtc.code} - ${dtc.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(dtc.descriptionIndo, style: const TextStyle(fontSize: 11)),
                        );
                      }),
                    ],
                    if (result.pendingDtcs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('• Kode Pending (Mode 07):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning)),
                      ...result.pendingDtcs.map((code) {
                        final dtc = DtcRepository.getCodeInfo(code);
                        return ListTile(
                          dense: true,
                          title: Text('${dtc.code} - ${dtc.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(dtc.descriptionIndo, style: const TextStyle(fontSize: 11)),
                        );
                      }),
                    ],
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup Laporan'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
