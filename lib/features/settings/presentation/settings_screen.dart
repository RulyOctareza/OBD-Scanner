import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/bluetooth/obd_service.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncingVehicle = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // ObdState changes many times per second while polling, so only status
    // transitions may raise a snackbar.
    ref.listen<ObdState>(obdServiceProvider, (previous, next) {
      if (next.status == previous?.status) return;
      if (next.status == ObdStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.status == ObdStatus.connected && !next.isSimulatorMode) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terhubung ke ${next.connectedDeviceName ?? "OBD-II"}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // CONNECTION MODE SECTION
            _buildSectionHeader('Mode Koneksi'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: settings.isSimulatorMode
                          ? AppColors.warning.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      settings.isSimulatorMode
                          ? Icons.science_rounded
                          : Icons.bluetooth_connected_rounded,
                      color: settings.isSimulatorMode
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    settings.isSimulatorMode
                        ? 'Mode Simulator (Demo)'
                        : 'Mode Bluetooth OBD-II',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    settings.isSimulatorMode
                        ? 'Sensor simulasi aktif (Uji coba tanpa adapter OBD).'
                        : 'Terhubung ke scanner Bluetooth fisik mobil (Default).',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: settings.isSimulatorMode,
                  activeThumbColor: AppColors.warning,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setSimulatorMode(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SIMULATOR CONTROLS SECTION (Only active in Simulator Mode)
            if (settings.isSimulatorMode) ...[
              _buildSectionHeader('Pengaturan Simulator Demo'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Kontak / Mesin Menyala'),
                        subtitle: const Text(
                          'Mengontrol RPM dan indikator hidup',
                        ),
                        value: settings.isIgnitionOn,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          ref
                              .read(settingsProvider.notifier)
                              .setIgnitionOn(val);
                        },
                      ),
                      const Divider(color: AppColors.surface, height: 1),
                      _buildSimulatorTriggerRow(
                        'Simulasikan Overheat (Coolant)',
                        'Menaikkan suhu coolant ke 109°C',
                        ref.watch(
                          obdServiceProvider.select((s) => s.simHighTemp),
                        ),
                        (val) => ref
                            .read(obdServiceProvider.notifier)
                            .configureSimulator(hasHighTemp: val),
                      ),
                      const Divider(color: AppColors.surface, height: 1),
                      _buildSimulatorTriggerRow(
                        'Simulasikan Aki Lemah',
                        'Menurunkan tegangan aki ke 11.4V',
                        ref.watch(
                          obdServiceProvider.select((s) => s.simLowVoltage),
                        ),
                        (val) => ref
                            .read(obdServiceProvider.notifier)
                            .configureSimulator(hasLowVoltage: val),
                      ),
                      const Divider(color: AppColors.surface, height: 1),
                      _buildSimulatorTriggerRow(
                        'Simulasikan Check Engine (DTC)',
                        'Menyuntikkan kode eror P0138 (O2 Sensor)',
                        ref.watch(
                          obdServiceProvider.select((s) => s.simHasDtc),
                        ),
                        (val) => ref
                            .read(obdServiceProvider.notifier)
                            .configureSimulator(
                              injectedDtcs: val ? ['P0138'] : [],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // BLUETOOTH / REAL OBD CONNECTION SECTION
            if (!settings.isSimulatorMode) ...[
              _buildSectionHeader('Koneksi Bluetooth OBD-II'),
              Card(
                child: Column(
                  children: [
                    _ObdLinkSummaryTile(
                      onManage: () => showObdConnectionSheet(context, ref),
                    ),
                    const Divider(color: AppColors.surface, height: 1),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      title: const Text('Sambung otomatis'),
                      subtitle: const Text(
                        'Sambungkan ke adapter terakhir saat aplikasi dibuka '
                        'atau koneksi terputus.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settings.autoConnectOBD,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => ref
                          .read(settingsProvider.notifier)
                          .setAutoConnectOBD(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ODOMETER & PROFILE CONFIG SECTION
            _buildSectionHeader('Informasi Kendaraan'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileEditRow(
                      context,
                      'Nama Mobil',
                      settings.vehicleName,
                      (val) => ref
                          .read(settingsProvider.notifier)
                          .updateVehicleName(val),
                    ),
                    if (settings.vehicleVin.isNotEmpty) ...[
                      const Divider(color: AppColors.surface, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'VIN (dari ECU)',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          settings.vehicleVin,
                          style: AppTheme.numberStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const Divider(color: AppColors.surface, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Odometer Saat Ini',
                        style: TextStyle(fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${settings.currentOdometer.toStringAsFixed(0)} km',
                            style: AppTheme.numberStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.sync_rounded,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ],
                      ),
                      subtitle: const Text(
                        'Dari ECU (PID 01A6) bila didukung, atau isi manual',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                      ),
                      onTap: () => _showEditDialog(
                        context,
                        'Odometer Saat Ini',
                        settings.currentOdometer.toStringAsFixed(0),
                        (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            ref
                                .read(settingsProvider.notifier)
                                .updateOdometer(parsed);
                          }
                        },
                        true,
                      ),
                    ),
                    const Divider(color: AppColors.surface, height: 1),
                    _buildProfileEditRow(
                      context,
                      'Target Ganti Oli',
                      '${settings.nextOilOdometer.toStringAsFixed(0)} km',
                      (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .updateNextOilOdometer(parsed);
                        }
                      },
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSyncingVehicle
                            ? null
                            : () => _syncVehicleFromEcu(context),
                        icon: _isSyncingVehicle
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bluetooth_searching_rounded),
                        label: Text(
                          _isSyncingVehicle
                              ? 'Membaca dari ECU...'
                              : 'Ambil Nama & Odometer dari ECU',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nama model diisi dari decode VIN (Mode 09). '
                      'Odometer dari PID 01A6 — tidak semua mobil mendukung.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Syncs vehicle name/VIN/odometer without Navigator dialogs.
  /// (Dialog + pop fights go_router shell and can blank the Settings tab.)
  Future<void> _syncVehicleFromEcu(BuildContext context) async {
    if (_isSyncingVehicle) return;
    setState(() => _isSyncingVehicle = true);

    EcuVehicleIdentityResult result;
    try {
      result = await ref
          .read(settingsProvider.notifier)
          .syncVehicleIdentityFromEcu();
    } catch (e) {
      result = EcuVehicleIdentityResult(
        success: false,
        message: 'Gagal membaca ECU: $e',
      );
    } finally {
      if (mounted) setState(() => _isSyncingVehicle = false);
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSimulatorTriggerRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: AppColors.danger,
      onChanged: onChanged,
    );
  }

  Widget _buildProfileEditRow(
    BuildContext context,
    String label,
    String value,
    Function(String) onSave, {
    bool isNumber = false,
  }) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTheme.numberStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
      onTap: () => _showEditDialog(
        context,
        label,
        value.replaceAll(' km', ''),
        onSave,
        isNumber,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String label,
    String currentValue,
    Function(String) onSave,
    bool isNumber,
  ) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Ubah $label'),
          content: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onSave(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}

/// One-line OBD link status for Settings; device choice, pairing and
/// troubleshooting live in the shared connection sheet.
class _ObdLinkSummaryTile extends ConsumerWidget {
  final VoidCallback onManage;

  const _ObdLinkSummaryTile({required this.onManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(
      obdServiceProvider.select(
        (s) => (
          status: s.status,
          name: s.connectedDeviceName,
          address: s.connectedDeviceAddress,
          detail: s.statusDetail,
          error: s.errorMessage,
        ),
      ),
    );
    final lastAddress = ref.watch(
      settingsProvider.select((s) => s.lastOBDAddress),
    );

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;
    switch (link.status) {
      case ObdStatus.connected:
        color = AppColors.success;
        icon = Icons.bluetooth_connected_rounded;
        title = 'Terhubung ke ${link.name ?? "OBD-II"}';
        subtitle = link.address ?? '';
      case ObdStatus.connecting:
      case ObdStatus.initializing:
        color = AppColors.primary;
        icon = Icons.bluetooth_searching_rounded;
        title = 'Menghubungkan ke ${link.name ?? "OBD-II"}…';
        subtitle = link.detail ?? '';
      case ObdStatus.error:
        color = AppColors.danger;
        icon = Icons.error_outline_rounded;
        title = link.error ?? 'Koneksi gagal';
        subtitle = 'Ketuk Kelola untuk langkah perbaikan.';
      case ObdStatus.disconnected:
        color = AppColors.textSecondary;
        icon = Icons.bluetooth_disabled_rounded;
        title = 'Belum terhubung';
        subtitle = lastAddress.isEmpty
            ? 'Pilih atau sandingkan adapter ELM327.'
            : 'Adapter terakhir: $lastAddress';
    }

    return ListTile(
      onTap: onManage,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: FilledButton.tonal(
        onPressed: onManage,
        child: const Text('Kelola'),
      ),
    );
  }
}
