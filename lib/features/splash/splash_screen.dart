import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../settings/presentation/settings_provider.dart';

/// Brand splash: waits for local prefs/DB, then routes to intro or home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _minDisplay = Duration(milliseconds: 1600);
  static const _maxWait = Duration(milliseconds: 3500);

  bool _navigated = false;
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _footerOpacity;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _glowPulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _enterController.forward();
    unawaited(_bootstrapAndNavigate());
  }

  Future<void> _bootstrapAndNavigate() async {
    final started = DateTime.now();

    // Wait until Drift/SharedPreferences preferences are loaded (or timeout).
    try {
      await Future.any([
        _waitUntilSettingsLoaded(),
        Future<void>.delayed(_maxWait),
      ]);
    } catch (_) {}

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minDisplay) {
      await Future<void>.delayed(_minDisplay - elapsed);
    }

    if (!mounted || _navigated) return;
    _goNext(ref.read(settingsProvider));
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

  void _goNext(SettingsState settings) {
    if (_navigated || !mounted) return;
    _navigated = true;
    if (!settings.hasCompletedObdIntro) {
      context.go('/obd_intro');
    } else {
      context.go('/health');
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF141821),
              AppColors.background,
              Color(0xFF0A0C10),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: AnimatedBuilder(
              animation: Listenable.merge([_enterController, _pulseController]),
              builder: (context, _) {
                return Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: _SplashLogo(glowStrength: _glowPulse.value),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleOpacity,
                        child: const Column(
                          children: [
                            Text(
                              'AutoCare',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'OBD-II',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 4,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Diagnostik & pemantauan kendaraan real-time',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF9EA7B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: _footerOpacity,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary.withValues(
                                  alpha: 0.55 + (_glowPulse.value * 0.45),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            ref.watch(
                              settingsProvider.select((s) => s.isLoaded),
                            )
                                ? 'Siap digunakan...'
                                : 'Memuat data lokal...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({required this.glowStrength});

  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final glow = AppColors.primary.withValues(alpha: 0.12 + glowStrength * 0.22);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25 + glowStrength * 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glow,
            blurRadius: 18 + glowStrength * 16,
            spreadRadius: 2 + glowStrength * 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.directions_car_filled_rounded,
            size: 56,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
