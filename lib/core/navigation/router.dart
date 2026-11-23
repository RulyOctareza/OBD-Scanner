import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/live_data/presentation/live_data_screen.dart';
import '../../features/live_data/presentation/dashboard_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/diagnostics/presentation/diagnostic_scanner_screen.dart';
import '../../features/diagnostics/presentation/dtc_lookup_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/obd_intro_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'beranda');
final GlobalKey<NavigatorState> _liveNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'live');
final GlobalKey<NavigatorState> _diagnosticsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'diagnostik');
final GlobalKey<NavigatorState> _timelineNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'riwayat');
final GlobalKey<NavigatorState> _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'pengaturan');

/// Branch order of the shell; ShellScreen's destinations follow it.
abstract final class AppTab {
  static const int beranda = 0;
  static const int live = 1;
  static const int diagnostik = 2;
  static const int riwayat = 3;
  static const int pengaturan = 4;
}

// Every path here is a real route and stays so: the dev benchmark
// (lib/dev/bench) and in-app links open screens by path. A tab that holds two
// screens has both as routes of its branch, switched with SegmentSwitch.
final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: kDebugMode,
  routes: [
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/obd_intro',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ObdIntroScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScreen(
          navigationShell: navigationShell,
          location: state.uri.path,
        );
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/health',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HealthScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _liveNavigatorKey,
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
            GoRoute(
              path: '/live_data',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LiveDataScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _diagnosticsNavigatorKey,
          routes: [
            GoRoute(
              path: '/diagnostics',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DiagnosticScannerScreen(),
              ),
            ),
            GoRoute(
              path: '/dtc_lookup',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DtcLookupScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _timelineNavigatorKey,
          routes: [
            GoRoute(
              path: '/timeline',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TimelineScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
