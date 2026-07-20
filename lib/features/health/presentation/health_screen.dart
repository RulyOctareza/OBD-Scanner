import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../trips/presentation/trip_provider.dart';
import '../domain/health_engine.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import 'health_provider.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthReport = ref.watch(healthProvider);
    final obdState = ref.watch(obdServiceProvider);
    final settings = ref.watch(settingsProvider);
    final tripState = ref.watch(tripRecorderProvider);
    final historicalTrips = ref.watch(historicalTripsProvider);

    // Listen to trip completion to show summary dialog
    ref.listen(tripRecorderProvider, (previous, next) {
      if (previous?.lastCompletedTripId == null && next.lastCompletedTripId != null) {
        _showTripSummaryDialog(context, ref, next.lastCompletedTripId!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.vehicleName.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              obdState.isSimulatorMode ? Icons.bolt : Icons.bluetooth,
              color: obdState.status == ObdStatus.connected ? AppColors.success : AppColors.textSecondary,
            ),
            onPressed: () => _showConnectionBottomSheet(context, ref),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Banner
            _buildConnectionBanner(context, ref, obdState),
            const SizedBox(height: 16),

            // Health Score Ring Card
            _buildHealthHero(context, healthReport),
            const SizedBox(height: 16),

            // Diagnostic Scanner Banner Button
            _buildDiagnosticScannerCard(context, obdState),
            const SizedBox(height: 20),

            // Live Trip Recording Active Banner
            if (tripState.isRecording) ...[
              _buildLiveTripRecordingCard(tripState, obdState.telemetry),
              const SizedBox(height: 20),
            ],

            // Actionable Alerts / Warnings
            if (healthReport.warnings.isNotEmpty) ...[
              const Text(
                'Perhatian',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              ...healthReport.warnings.map((warning) => _buildWarningCard(warning)),
              const SizedBox(height: 20),
            ],

            // Systems Checklist
            const Text(
              'Pemeriksaan Sistem',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            _buildChecksCard(healthReport.checks),
            const SizedBox(height: 20),

            // Last Trip Summary (if trip recording is NOT active)
            if (!tripState.isRecording) ...[
              const Text(
                'Perjalanan Terakhir',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              historicalTrips.when(
                data: (trips) {
                  if (trips.isEmpty) {
                    return _buildEmptyTripCard();
                  }
                  final lastTrip = trips.first;
                  return _buildLastTripCard(lastTrip);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Gagal memuat perjalanan: $e'),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
     ),
    );
  }

  Widget _buildConnectionBanner(BuildContext context, WidgetRef ref, ObdState obdState) {
    Color bannerColor;
    String bannerText;
    IconData icon;

    switch (obdState.status) {
      case ObdStatus.connected:
        bannerColor = AppColors.success.withOpacity(0.15);
        bannerText = obdState.isSimulatorMode 
            ? 'Terhubung (Mode Simulator)' 
            : 'Terhubung ke ${obdState.connectedDeviceName}';
        icon = Icons.check_circle_outline_rounded;
        break;
      case ObdStatus.connecting:
      case ObdStatus.initializing:
        bannerColor = AppColors.warning.withOpacity(0.15);
        bannerText = 'Menghubungkan ke ELM327...';
        icon = Icons.radio_button_checked_rounded;
        break;
      case ObdStatus.error:
        bannerColor = AppColors.danger.withOpacity(0.15);
        bannerText = obdState.errorMessage ?? 'Koneksi Gagal';
        icon = Icons.error_outline_rounded;
        break;
      case ObdStatus.disconnected:
      default:
        bannerColor = AppColors.card;
        bannerText = 'Bluetooth Siaga (Ketuk untuk Hubungkan)';
        icon = Icons.bluetooth_disabled_rounded;
        break;
    }

    return InkWell(
      onTap: () => _showConnectionBottomSheet(context, ref),
      borderRadius: AppBorderRadius.mdBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: AppBorderRadius.mdBorder,
          border: Border.all(color: _getStatusColor(obdState.status).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _getStatusColor(obdState.status), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bannerText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _getStatusColor(obdState.status),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: _getStatusColor(obdState.status).withOpacity(0.5), size: 12),
          ],
        ),
      ),
    );
  }

  void _showConnectionBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final obdState = ref.watch(obdServiceProvider);
            
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.dragHandle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Koneksi OBD-II ELM327',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Toggle Mode Simulator
                  SwitchListTile(
                    title: const Text('Mode Simulator'),
                    subtitle: const Text('Simulasi data sensor tanpa ELM327 fisik'),
                    value: obdState.isSimulatorMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).setSimulatorMode(val);
                      ref.read(obdServiceProvider.notifier).toggleSimulatorMode(val);
                      setState(() {});
                    },
                  ),
                  const Divider(color: AppColors.card),
                  
                  if (!obdState.isSimulatorMode) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih Perangkat ELM327',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ref.watch(pairedDevicesProvider).when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal memuat: $err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => ref.refresh(pairedDevicesProvider),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Pindai Ulang'),
                            ),
                          ],
                        ),
                      ),
                      data: (devices) {
                        if (devices.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                const Icon(Icons.bluetooth_searching, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                const Text(
                                  'Perangkat tidak ditemukan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Pastikan Bluetooth aktif, izin lokasi/bluetooth disetujui, dan ELM327 sudah dipairing di settings HP.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => ref.refresh(pairedDevicesProvider),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Pindai Ulang'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: devices.length,
                            separatorBuilder: (context, idx) => const Divider(color: AppColors.card, height: 1),
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              final isConnected = obdState.connectedDeviceAddress == device.address &&
                                  obdState.status == ObdStatus.connected;
                              final isConnecting = obdState.connectedDeviceAddress == device.address &&
                                  (obdState.status == ObdStatus.connecting || obdState.status == ObdStatus.initializing);

                              return ListTile(
                                leading: Icon(
                                  Icons.bluetooth,
                                  color: isConnected ? AppColors.success : AppColors.textSecondary,
                                ),
                                title: Text(device.name ?? 'Perangkat Tanpa Nama'),
                                subtitle: Text(device.address),
                                trailing: isConnected
                                    ? OutlinedButton(
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                                        onPressed: () {
                                          ref.read(obdServiceProvider.notifier).disconnect();
                                        },
                                        child: const Text('Putus', style: TextStyle(color: AppColors.danger)),
                                      )
                                    : isConnecting
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : FilledButton(
                                            onPressed: () async {
                                              Navigator.pop(context); // Close bottom sheet
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Menghubungkan ke ${device.name ?? "ELM327"}...')),
                                              );
                                              await ref.read(obdServiceProvider.notifier).connectToDevice(device);
                                            },
                                            child: const Text('Hubungkan'),
                                          ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Aplikasi saat ini mensimulasikan data ECU mobil. Matikan Mode Simulator di atas untuk menghubungkan ke dongle Bluetooth ELM327 fisik Anda.',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(ObdStatus status) {
    switch (status) {
      case ObdStatus.connected:
        return AppColors.success;
      case ObdStatus.connecting:
      case ObdStatus.initializing:
        return AppColors.warning;
      case ObdStatus.error:
        return AppColors.danger;
      case ObdStatus.disconnected:
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildHealthHero(BuildContext context, HealthReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            // Circular Progress Score
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: report.score / 100,
                      strokeWidth: 12,
                      backgroundColor: AppColors.progressBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(report.statusColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${report.score}',
                        style: AppTheme.numberStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'HEALTH SCORE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              report.statusTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: report.statusColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              report.statusDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticScannerCard(BuildContext context, ObdState obdState) {
    final hasDtcs = obdState.telemetry.dtcs.isNotEmpty;

    return Card(
      color: hasDtcs ? AppColors.danger.withOpacity(0.12) : AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: hasDtcs ? AppColors.danger.withOpacity(0.5) : AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/diagnostics'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasDtcs ? AppColors.danger.withOpacity(0.2) : AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.radar_rounded,
                  color: hasDtcs ? AppColors.danger : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Pindai Diagnostik ECU',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (hasDtcs) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${obdState.telemetry.dtcs.length} DTC',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDtcs
                          ? 'Terdeteksi kode kesalahan aktif! Ketuk untuk diagnosa & reset.'
                          : 'Periksa DTC, status emisi (I/M Readiness), dan reset Check Engine.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: hasDtcs ? AppColors.danger : AppColors.textSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveTripRecordingCard(TripRecorderState trip, dynamic telemetry) {
    return Card(
      color: AppColors.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, color: AppColors.danger, size: 10),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SEDANG MEREKAM PERJALANAN',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11, letterSpacing: 1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(trip.durationSeconds),
                  style: AppTheme.numberStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTripLiveStat('Jarak', '${trip.currentTripDistance.toStringAsFixed(1)} km'),
                _buildTripLiveStat('Speed', '${telemetry.speed.toStringAsFixed(0)} km/h'),
                _buildTripLiveStat('RPM', '${telemetry.rpm.toStringAsFixed(0)}'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTripLiveStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTheme.numberStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildWarningCard(String text) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.danger.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.danger, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecksCard(List<CheckItem> checks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: checks.length,
          separatorBuilder: (context, index) => const Divider(color: AppColors.surface, height: 1),
          itemBuilder: (context, index) {
            final check = checks[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    check.isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: check.isOk ? AppColors.success : AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      check.title,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    check.detail,
                    style: AppTheme.numberStyle(
                      fontSize: 13,
                      color: check.isOk ? AppColors.textSecondary : AppColors.danger,
                      fontWeight: check.isOk ? FontWeight.normal : FontWeight.bold,
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

  Widget _buildLastTripCard(Trip trip) {
    final format = DateFormat('dd MMM yyyy, HH:mm');
    final formattedTime = format.format(trip.startTime);
    final distanceText = '${trip.distance.toStringAsFixed(1)} km';
    final fuelText = '${trip.fuelEconomy.toStringAsFixed(1)} km/L';
    final durationText = '${trip.durationMinutes} m';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Navigate to details (future v0.2)
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Score ${trip.tripHealthScore}',
                      style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTripStat('Jarak', distanceText),
                  _buildTripStat('Konsumsi', fuelText),
                  _buildTripStat('Durasi', durationText),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTripCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.directions_car_outlined, size: 40, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'Belum ada data perjalanan',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.numberStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showTripSummaryDialog(BuildContext context, WidgetRef ref, int tripId) async {
    final db = ref.read(databaseProvider);
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return;

    ref.read(tripRecorderProvider.notifier).clearLastCompletedTrip();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl + 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: AppBorderRadius.smBorder,
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.stars_rounded, color: AppColors.success, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Trip Selesai!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ringkasan perjalanan kendaraan hari ini',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              
              // Statistics Grid
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDialogStat('Jarak', '${trip.distance.toStringAsFixed(1)} km'),
                        _buildDialogStat('Durasi', '${trip.durationMinutes} menit'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDialogStat('Avg Speed', '${trip.avgSpeed.toStringAsFixed(0)} km/h'),
                        _buildDialogStat('Konsumsi', '${trip.fuelEconomy.toStringAsFixed(1)} km/L'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.surface, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDialogStat('Max Coolant', '${trip.maxCoolant}°C'),
                        _buildDialogStat('Max RPM', '${trip.maxRpm} RPM'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.numberStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
