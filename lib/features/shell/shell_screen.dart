import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../settings/presentation/settings_provider.dart';

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
      final isFullscreen = ref.read(settingsProvider).isFullscreenCockpit;
      if (isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    } else {
      // Turn off fullscreen when navigating away from dashboard
      ref.read(settingsProvider.notifier).setFullscreenCockpit(false);
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
    final isFullscreen = ref.watch(settingsProvider.select((s) => s.isFullscreenCockpit)) &&
        widget.navigationShell.currentIndex == 1;

    // Listen to changes in fullscreen state to trigger SystemChrome changes
    ref.listen<bool>(
      settingsProvider.select((s) => s.isFullscreenCockpit),
      (previous, next) {
        if (next && widget.navigationShell.currentIndex == 1) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        }
      },
    );

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: isFullscreen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: BottomNavigationBar(
                        currentIndex: widget.navigationShell.currentIndex,
                        onTap: (index) => widget.navigationShell.goBranch(index),
                        selectedItemColor: AppColors.primary,
                        unselectedItemColor: AppColors.textSecondary,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
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
                            label: 'Data',
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
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
