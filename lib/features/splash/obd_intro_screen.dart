import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../settings/presentation/settings_provider.dart';

/// First-run intro: permissions → connection mode → view health score.
class ObdIntroScreen extends ConsumerStatefulWidget {
  const ObdIntroScreen({super.key});

  @override
  ConsumerState<ObdIntroScreen> createState() => _ObdIntroScreenState();
}

class _ObdIntroScreenState extends ConsumerState<ObdIntroScreen> {
  int _step = 0;
  bool _requestingPermission = false;

  Future<void> _requestPermissions() async {
    setState(() => _requestingPermission = true);
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
      ].request();
    } catch (_) {
      // Best-effort; user can grant later in system settings.
    }
    if (!mounted) return;
    setState(() {
      _requestingPermission = false;
      _step = 1;
    });
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setObdIntroCompleted(true);
    if (!mounted) return;
    context.go('/health');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Lewati'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(3, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildStep(settings)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(SettingsState settings) {
    switch (_step) {
      case 0:
        return _IntroStep(
          icon: Icons.security_rounded,
          title: 'Izin Bluetooth & Lokasi',
          body:
              'AutoCare membutuhkan izin Bluetooth dan lokasi agar dapat menemukan adapter OBD-II ELM327 di mobil Anda.',
          primaryLabel: _requestingPermission ? 'Meminta izin...' : 'Berikan Izin',
          onPrimary: _requestingPermission ? null : _requestPermissions,
        );
      case 1:
        return _IntroStep(
          icon: Icons.cable_rounded,
          title: 'Pilih Cara Koneksi',
          body:
              'Pakai adapter Bluetooth di mobil, atau coba Mode Simulator untuk melihat demo tanpa perangkat.',
          primaryLabel: 'Lanjut',
          onPrimary: () => setState(() => _step = 2),
          extra: Column(
            children: [
              _ModeCard(
                selected: !settings.isSimulatorMode,
                icon: Icons.bluetooth_connected_rounded,
                title: 'Adapter OBD-II',
                subtitle: 'Hubungkan ELM327 fisik',
                onTap: () {
                  ref.read(settingsProvider.notifier).setSimulatorMode(false);
                },
              ),
              const SizedBox(height: 12),
              _ModeCard(
                selected: settings.isSimulatorMode,
                icon: Icons.science_rounded,
                title: 'Mode Simulator',
                subtitle: 'Demo sensor tanpa adapter',
                accent: AppColors.warning,
                onTap: () {
                  ref.read(settingsProvider.notifier).setSimulatorMode(true);
                },
              ),
            ],
          ),
        );
      default:
        return _IntroStep(
          icon: Icons.favorite_rounded,
          title: 'Lihat Skor Kesehatan',
          body:
              'Setelah terhubung, layar Kesehatan menampilkan skor mesin, peringatan, dan pintasan pindai diagnostik.',
          primaryLabel: 'Mulai AutoCare',
          onPrimary: _finish,
        );
    }
  }
}

class _IntroStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Widget? extra;

  const _IntroStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        if (extra != null) ...[
          const SizedBox(height: 24),
          extra!,
        ],
        const Spacer(),
        FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            primaryLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? accent : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
