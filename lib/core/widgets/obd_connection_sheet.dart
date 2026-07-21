import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../bluetooth/obd_service.dart';
import '../../features/settings/presentation/settings_provider.dart';

/// Shared OBD connection bottom sheet used across Health, Meter, Sensor, Diagnostics.
Future<void> showObdConnectionSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
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
                      'Koneksi OBD-II',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode Simulator'),
                  subtitle: const Text('Demo sensor tanpa adapter ELM327'),
                  value: ref.watch(
                    settingsProvider.select((s) => s.isSimulatorMode),
                  ),
                  activeColor: AppColors.warning,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setSimulatorMode(val);
                  },
                ),
                const Divider(color: AppColors.card),
                const SizedBox(height: 8),
                if (obdState.isSimulatorMode) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.science_rounded, color: AppColors.warning, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Mode Simulator Aktif',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Aplikasi menggunakan data sensor demo. Ubah mode koneksi di Pengaturan.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              context.go('/settings');
                            },
                            icon: const Icon(Icons.settings_rounded, size: 18),
                            label: const Text('Buka Pengaturan Mode'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Pilih perangkat ELM327 yang sudah dipasangkan',
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
                              const Icon(
                                Icons.bluetooth_searching,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Perangkat tidak ditemukan',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Pastikan Bluetooth aktif, izin lokasi/Bluetooth disetujui, '
                                'dan ELM327 sudah dipasangkan di pengaturan HP.',
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
                          separatorBuilder: (context, idx) =>
                              const Divider(color: AppColors.card, height: 1),
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            final isConnected =
                                obdState.connectedDeviceAddress == device.address &&
                                obdState.status == ObdStatus.connected;
                            final isConnecting =
                                obdState.connectedDeviceAddress == device.address &&
                                (obdState.status == ObdStatus.connecting ||
                                    obdState.status == ObdStatus.initializing);

                            return ListTile(
                              leading: Icon(
                                Icons.bluetooth,
                                color: isConnected
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              title: Text(device.name ?? 'Perangkat Tanpa Nama'),
                              subtitle: Text(device.address),
                              trailing: isConnected
                                  ? OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.danger),
                                      ),
                                      onPressed: () {
                                        ref.read(obdServiceProvider.notifier).disconnect();
                                      },
                                      child: const Text(
                                        'Putus',
                                        style: TextStyle(color: AppColors.danger),
                                      ),
                                    )
                                  : isConnecting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : FilledButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Menghubungkan ke ${device.name ?? "ELM327"}...',
                                                ),
                                              ),
                                            );
                                            await ref
                                                .read(obdServiceProvider.notifier)
                                                .connectToDevice(device);
                                          },
                                          child: const Text('Hubungkan'),
                                        ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/settings');
                      },
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text('Pengaturan Mode Koneksi'),
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

/// Empty-state CTA when OBD is not connected.
class ObdNotConnectedView extends StatelessWidget {
  final ObdState state;
  final VoidCallback onConnect;

  const ObdNotConnectedView({
    super.key,
    required this.state,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnecting = state.status == ObdStatus.connecting ||
        state.status == ObdStatus.initializing;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.35),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Terhubung ke Mobil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConnecting
                  ? 'Menghubungkan ke adapter OBD-II...'
                  : 'Hubungkan adapter ELM327 atau aktifkan mode simulator untuk melihat data live.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (!isConnecting)
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const Text('Hubungkan OBD'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (isConnecting)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      ),
    );
  }
}
