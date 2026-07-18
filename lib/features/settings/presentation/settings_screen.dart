import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/bluetooth/obd_service.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final obdState = ref.watch(obdServiceProvider);

    ref.listen<ObdState>(obdServiceProvider, (previous, next) {
      if (next.status == ObdStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.status == ObdStatus.connected && previous?.status != ObdStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terhubung ke ${next.connectedDeviceName ?? "OBD-II"}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PENGATURAN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // SIMULATOR MODE SECTION
            _buildSectionHeader('Simulator Mode'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Aktifkan Simulator'),
                      subtitle: const Text('Simulasi data mobil tanpa ELM327 asli'),
                      value: settings.isSimulatorMode,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setSimulatorMode(val);
                        ref.read(obdServiceProvider.notifier).toggleSimulatorMode(val);
                      },
                    ),
                    if (settings.isSimulatorMode) ...[
                      const Divider(color: AppColors.surface, height: 1),
                      SwitchListTile(
                        title: const Text('Kontak / Mesin Menyala'),
                        subtitle: const Text('Mengontrol RPM dan indikator hidup'),
                        value: settings.isIgnitionOn,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          ref.read(settingsProvider.notifier).setIgnitionOn(val);
                          ref.read(obdServiceProvider.notifier).simulator.configure(isEngineRunning: val);
                        },
                      ),
                      const Divider(color: AppColors.surface, height: 1),
                      _buildSimulatorTriggerRow(
                        ref, 
                        'Simulasikan Overheat (Coolant)', 
                        'Menaikkan suhu coolant ke 109°C',
                        (val) => ref.read(obdServiceProvider.notifier).simulator.configure(hasHighTemp: val),
                      ),
                      const Divider(color: AppColors.surface, height: 1),
                      _buildSimulatorTriggerRow(
                        ref, 
                        'Simulasikan Aki Lemah', 
                        'Menurunkan tegangan aki ke 11.4V',
                        (val) => ref.read(obdServiceProvider.notifier).simulator.configure(hasLowVoltage: val),
                      ),
                      const Divider(color: AppColors.surface, height: 1),
                      _buildSimulatorTriggerRow(
                        ref, 
                        'Simulasikan Check Engine (DTC)', 
                        'Menyuntikkan kode eror P0138 (O2 Sensor)',
                        (val) => ref.read(obdServiceProvider.notifier).simulator.configure(
                          injectedDtcs: val ? ['P0138'] : [],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // BLUETOOTH / REAL OBD CONNECTION SECTION
            if (!settings.isSimulatorMode) ...[
              _buildSectionHeader('Koneksi Bluetooth OBD-II'),
              Card(
                child: ref.watch(pairedDevicesProvider).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat Bluetooth: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  data: (devices) {
                    if (devices.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(Icons.bluetooth_searching_rounded, color: AppColors.textSecondary, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada perangkat Bluetooth berpasangan.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sandingkan ELM327 Anda terlebih dahulu di pengaturan Android.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      separatorBuilder: (context, index) => const Divider(color: AppColors.surface, height: 1),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isConnected = obdState.connectedDeviceAddress == device.address && 
                                             obdState.status == ObdStatus.connected;
                        final isConnecting = obdState.connectedDeviceAddress == device.address && 
                                             (obdState.status == ObdStatus.connecting || 
                                              obdState.status == ObdStatus.initializing);
                        final isAnyConnecting = obdState.status == ObdStatus.connecting || 
                                                obdState.status == ObdStatus.initializing;

                        return ListTile(
                          leading: Icon(
                            Icons.bluetooth_rounded, 
                            color: isConnected 
                                ? AppColors.success 
                                : (isConnecting ? AppColors.primary : AppColors.textSecondary)
                          ),
                          title: Text(device.name ?? 'Perangkat Tanpa Nama'),
                          subtitle: Text(device.address),
                          trailing: isConnected
                              ? OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.danger),
                                    foregroundColor: AppColors.danger,
                                  ),
                                  onPressed: () => ref.read(obdServiceProvider.notifier).disconnect(),
                                  child: const Text('Putus'),
                                )
                              : isConnecting
                                  ? FilledButton(
                                      onPressed: null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary.withOpacity(0.15),
                                      ),
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                        ),
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: isAnyConnecting
                                          ? null
                                          : () => ref.read(obdServiceProvider.notifier).connectToDevice(device),
                                      child: const Text('Hubungkan'),
                                    ),
                        );
                      },
                    );
                  },
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
                      (val) => ref.read(settingsProvider.notifier).updateVehicleName(val),
                    ),
                     const Divider(color: AppColors.surface, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Odometer Saat Ini', style: TextStyle(fontSize: 14)),
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
                          const Icon(Icons.sync_rounded, color: AppColors.success, size: 16),
                        ],
                      ),
                      subtitle: const Text('Sinkron otomatis dari OBD-II ECU', style: TextStyle(fontSize: 11, color: AppColors.success)),
                    ),
                    const Divider(color: AppColors.surface, height: 1),
                    _buildProfileEditRow(
                      context, 
                      'Target Ganti Oli', 
                      '${settings.nextOilOdometer.toStringAsFixed(0)} km', 
                      (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) {
                          ref.read(settingsProvider.notifier).updateNextOilOdometer(parsed);
                        }
                      },
                      isNumber: true,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSimulatorTriggerRow(WidgetRef ref, String title, String subtitle, Function(bool) onChanged) {
    return _TriggerTile(title: title, subtitle: subtitle, onChanged: onChanged);
  }

  Widget _buildProfileEditRow(
    BuildContext context, 
    String label, 
    String value, 
    Function(String) onSave, {
    bool isNumber = false
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
      onTap: () => _showEditDialog(context, label, value.replaceAll(' km', ''), onSave, isNumber),
    );
  }

  void _showEditDialog(
    BuildContext context, 
    String label, 
    String currentValue, 
    Function(String) onSave,
    bool isNumber
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
            decoration: InputDecoration(
              labelText: label,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
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

// Stateful tile wrapper to maintain internal switch state for simulator triggers
class _TriggerTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(bool) onChanged;

  const _TriggerTile({
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  State<_TriggerTile> createState() => _TriggerTileState();
}

class _TriggerTileState extends State<_TriggerTile> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      value: _value,
      activeColor: AppColors.danger,
      onChanged: (val) {
        setState(() {
          _value = val;
        });
        widget.onChanged(val);
      },
    );
  }
}
