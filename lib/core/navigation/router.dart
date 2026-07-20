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

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _healthNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'health');
final GlobalKey<NavigatorState> _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final GlobalKey<NavigatorState> _liveDataNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'live_data');
final GlobalKey<NavigatorState> _timelineNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'timeline');
final GlobalKey<NavigatorState> _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/health',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/diagnostics',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DiagnosticScannerScreen(),
    ),
    GoRoute(
      path: '/dtc_lookup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DtcLookupScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Health (Home) Branch
        StatefulShellBranch(
          navigatorKey: _healthNavigatorKey,
          routes: [
            GoRoute(
              path: '/health',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HealthScreen(),
              ),
            ),
          ],
        ),
        // Dashboard Branch (OBD2 Meter)
        StatefulShellBranch(
          navigatorKey: _dashboardNavigatorKey,
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
          ],
        ),
        // Live Data Branch
        StatefulShellBranch(
          navigatorKey: _liveDataNavigatorKey,
          routes: [
            GoRoute(
              path: '/live_data',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LiveDataScreen(),
              ),
            ),
          ],
        ),
        // Timeline Branch
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
        // Settings Branch
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
