import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../live_data/presentation/dashboard_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  @override
  void initState() {
    super.initState();
    _handleOrientation(widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(covariant ShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != oldWidget.navigationShell.currentIndex) {
      _handleOrientation(widget.navigationShell.currentIndex);
    }
  }

  void _handleOrientation(int index) {
    if (index == 1) { // Dashboard index
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Turn off fullscreen when navigating away from dashboard
      ref.read(fullscreenProvider.notifier).state = false;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(fullscreenProvider);

    // Listen to changes in fullscreen state to trigger SystemChrome changes
    ref.listen<bool>(fullscreenProvider, (previous, next) {
      if (next) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: isFullscreen
          ? null
          : BottomNavigationBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => widget.navigationShell.goBranch(index),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              backgroundColor: AppColors.surface,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_rounded),
                  activeIcon: Icon(Icons.favorite_rounded, color: AppColors.primary),
                  label: 'Kesehatan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.speed_rounded),
                  activeIcon: Icon(Icons.speed_rounded, color: AppColors.primary),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_rounded),
                  activeIcon: Icon(Icons.analytics_rounded, color: AppColors.primary),
                  label: 'Data Langsung',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded),
                  activeIcon: Icon(Icons.history_rounded, color: AppColors.primary),
                  label: 'Linimasa',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  activeIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
                  label: 'Pengaturan',
                ),
              ],
            ),
    );
  }
}
