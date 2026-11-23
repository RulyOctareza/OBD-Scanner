import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/ui/ui.dart';
import '../settings/presentation/settings_provider.dart';

/// Set by the intro's adapter path: Beranda opens the connection sheet once
/// when it first shows.
final openConnectionSheetOnStartProvider = StateProvider<bool>((ref) => false);

enum _Step { mode, permissions, plugIn }

/// First run: choose adapter or simulator first; the adapter path asks only
/// for what connecting needs, shows how to plug the adapter in and then
/// opens the connection sheet. The simulator path asks for nothing.
class ObdIntroScreen extends ConsumerStatefulWidget {
  const ObdIntroScreen({super.key});

  @override
  ConsumerState<ObdIntroScreen> createState() => _ObdIntroScreenState();
}

class _ObdIntroScreenState extends ConsumerState<ObdIntroScreen> {
  _Step _step = _Step.mode;
  bool _requesting = false;

  Future<void> _useSimulator() async {
    final settings = ref.read(settingsProvider.notifier);
    await settings.setSimulatorMode(true);
    await settings.setObdIntroCompleted(true);
    if (!mounted) return;
    context.go('/health');
  }

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);
    try {
      // Nearby devices on Android 12+ (granted without a prompt on 11 and
      // older). Location is declared only up to Android 11, where finding
      // new adapters needs it; on 12+ the request ends without a dialog.
      await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
      ].request();
      // Optional: the connection service's notification on Android 13+.
      await Permission.notification.request();
    } catch (_) {
      // Best effort: the connection sheet asks again when it needs to.
    }
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _step = _Step.plugIn;
    });
  }

  Future<void> _connect() async {
    final settings = ref.read(settingsProvider.notifier);
    await settings.setSimulatorMode(false);
    await settings.setObdIntroCompleted(true);
    ref.read(openConnectionSheetOnStartProvider.notifier).state = true;
    if (!mounted) return;
    context.go('/health');
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      _Step.mode => _ModeStep(
          onAdapter: () => setState(() => _step = _Step.permissions),
          onSimulator: _useSimulator,
        ),
      _Step.permissions => _PermissionStep(
          requesting: _requesting,
          onGrant: _requestPermissions,
          onSkip: () => setState(() => _step = _Step.plugIn),
        ),
      _Step.plugIn => _PlugInStep(onConnect: _connect),
    };
    return PopScope(
      canPop: _step == _Step.mode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _step =
              _step == _Step.plugIn ? _Step.permissions : _Step.mode);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [body],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, required this.text});

  final String? step;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step != null) ...[
          Text(step!, style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(text, style: theme.textTheme.bodyLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _ModeStep extends StatelessWidget {
  const _ModeStep({required this.onAdapter, required this.onSimulator});

  final VoidCallback onAdapter;
  final VoidCallback onSimulator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          step: null,
          title: 'Selamat datang di AutoCare',
          text: 'Pantau kondisi mobil dari HP lewat adapter OBD Bluetooth. '
              'Mulai dengan cara yang Anda punya.',
        ),
        _ModeCard(
          icon: Icons.bluetooth_rounded,
          title: 'Pakai adapter OBD',
          text: 'Adapter ELM327 Bluetooth yang dicolok ke port OBD mobil.',
          onTap: onAdapter,
        ),
        const SizedBox(height: AppSpacing.md),
        _ModeCard(
          icon: Icons.science_outlined,
          title: 'Coba dengan simulator',
          text: 'Lihat cara kerja aplikasi dengan data contoh, tanpa adapter. '
              'Bisa dimatikan nanti di Pengaturan.',
          onTap: onSimulator,
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.requesting,
    required this.onGrant,
    required this.onSkip,
  });

  final bool requesting;
  final VoidCallback onGrant;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(text, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          step: 'Langkah 1 dari 2',
          title: 'Izin untuk adapter',
          text: 'Android akan menanyakan izin ini sekali.',
        ),
        item(
          Icons.bluetooth_searching_rounded,
          'Perangkat di sekitar',
          'Untuk menemukan dan menghubungkan adapter. Di Android 11 ke bawah, '
              'Android menyebutnya izin Lokasi; AutoCare tidak melacak posisi '
              'Anda.',
        ),
        item(
          Icons.notifications_none_rounded,
          'Notifikasi (boleh ditolak)',
          'Menampilkan status koneksi saat aplikasi berjalan di latar.',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: requesting ? null : onGrant,
          child: Text(requesting ? 'Menunggu jawaban…' : 'Berikan izin'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: requesting ? null : onSkip, child: const Text('Nanti saja')),
      ],
    );
  }
}

class _PlugInStep extends StatelessWidget {
  const _PlugInStep({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(int n, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text('$n', style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(text, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          step: 'Langkah 2 dari 2',
          title: 'Pasang adapter',
          text: 'Lakukan ini sekali di mobil, lalu hubungkan.',
        ),
        step(1, 'Colok adapter', 'Port OBD ada di bawah dasbor, biasanya dekat '
            'setir atau pedal.'),
        step(2, 'Kunci kontak ON', 'Mesin boleh mati atau hidup. Lampu adapter '
            'menyala saat mendapat daya.'),
        step(3, 'Hubungkan', 'Pilih adapter di daftar. Bila diminta PIN, coba '
            '1234 atau 0000.'),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onConnect, child: const Text('Hubungkan adapter')),
      ],
    );
  }
}
