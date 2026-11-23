import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import '../settings/presentation/settings_provider.dart';

/// Shown only while settings load from the database, then routes to the
/// first-run intro or Beranda. Android's own splash comes first, so there is
/// no minimum display time here.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Never wait longer than this for settings; defaults are usable.
  static const _maxWait = Duration(milliseconds: 3500);
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await Future.any([
        _waitUntilSettingsLoaded(),
        Future<void>.delayed(_maxWait),
      ]);
    } catch (_) {}
    if (!mounted || _navigated) return;
    _navigated = true;
    final settings = ref.read(settingsProvider);
    context.go(settings.hasCompletedObdIntro ? '/health' : '/obd_intro');
  }

  Future<void> _waitUntilSettingsLoaded() async {
    if (ref.read(settingsProvider).isLoaded) return;
    final completer = Completer<void>();
    late final ProviderSubscription<SettingsState> sub;
    sub = ref.listenManual(settingsProvider, (previous, next) {
      if (next.isLoaded && !completer.isCompleted) {
        completer.complete();
        sub.close();
      }
    });
    // In case it loaded between read and listen.
    if (ref.read(settingsProvider).isLoaded && !completer.isCompleted) {
      completer.complete();
      sub.close();
    }
    await completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: AppRadius.cardBorder,
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 88,
                height: 88,
                cacheWidth: 264,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('AutoCare', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Teman setia mobil Anda', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
