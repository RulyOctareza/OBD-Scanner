import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/router.dart';
import '../settings/presentation/settings_provider.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

// In branch order (AppTab).
const _destinations = [
  _Destination('Beranda', Icons.home_outlined, Icons.home_rounded),
  _Destination('Live', Icons.speed_outlined, Icons.speed_rounded),
  _Destination(
    'Diagnostik',
    Icons.troubleshoot_outlined,
    Icons.troubleshoot_rounded,
  ),
  _Destination('Riwayat', Icons.history_outlined, Icons.history_rounded),
  _Destination('Pengaturan', Icons.settings_outlined, Icons.settings_rounded),
];

/// Tells screens whether Pengaturan has its own tab. When five labels do not
/// fit (narrow screen or large text), the bar keeps four tabs and Beranda
/// shows a gear instead.
class ShellLayout extends InheritedWidget {
  const ShellLayout({
    super.key,
    required this.settingsInBar,
    required super.child,
  });

  final bool settingsInBar;

  static bool settingsInBarOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShellLayout>()
          ?.settingsInBar ??
      true;

  @override
  bool updateShouldNotify(ShellLayout oldWidget) =>
      oldWidget.settingsInBar != settingsInBar;
}

class ShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  /// Current location, to tell the Meter from the Sensor in the Live tab.
  final String location;

  const ShellScreen({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  bool get _onMeter => widget.location == '/dashboard';

  @override
  void initState() {
    super.initState();
    _leaveFullscreenIfAway();
  }

  @override
  void didUpdateWidget(covariant ShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location) _leaveFullscreenIfAway();
  }

  /// The landscape cockpit belongs to the Meter only.
  void _leaveFullscreenIfAway() {
    if (_onMeter) return;
    ref.read(settingsProvider.notifier).setFullscreenCockpit(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  /// Width of the widest label of [destinations] at text scale 1.
  double _widestLabel(BuildContext context, List<_Destination> destinations) {
    final theme = Theme.of(context);
    final style =
        theme.navigationBarTheme.labelTextStyle?.resolve({
          WidgetState.selected,
        }) ??
        theme.textTheme.labelMedium!;
    var widest = 0.0;
    for (final d in destinations) {
      final painter = TextPainter(
        text: TextSpan(text: d.label, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }

  void _select(int index) {
    final shell = widget.navigationShell;
    // Tapping the current tab returns it to its first screen.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final isFullscreen =
        ref.watch(settingsProvider.select((s) => s.isFullscreenCockpit)) &&
        _onMeter;

    ref.listen<bool>(settingsProvider.select((s) => s.isFullscreenCockpit), (
      previous,
      next,
    ) {
      if (next && _onMeter) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });

    // Five tabs when all labels fit at the user's text size; otherwise
    // Pengaturan moves to Beranda's gear. Labels of the tabs shown then grow
    // only as far as they fit, so none wraps onto a second line.
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    const room = 8.0;
    final settingsInBar =
        _widestLabel(context, _destinations) * scale + room <=
        width / _destinations.length;
    final shown = settingsInBar ? _destinations : _destinations.sublist(0, 4);
    final fitScale =
        (width / shown.length - room) / _widestLabel(context, shown);
    final labelScale = math.max(1.0, math.min(scale, fitScale));
    // Pengaturan reached through Beranda's gear keeps Beranda highlighted.
    final selected = shell.currentIndex < shown.length
        ? shell.currentIndex
        : AppTab.beranda;

    // A root sheet or dialog over the shell (the chart sheet is one) pauses
    // everything below it like an offstage tab: no animations and no live
    // rebuilds (watchVisible only reads); closing it rebuilds with fresh
    // values. Otherwise gauge frames under the sheet re-raster the whole
    // screen, the sheet included.
    return TickerMode(
      enabled: ModalRoute.of(context)?.isCurrent ?? true,
      child: PopScope(
        // Back on another tab returns to Beranda before leaving the app.
        canPop: shell.currentIndex == AppTab.beranda,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) shell.goBranch(AppTab.beranda);
        },
        child: Scaffold(
          body: ShellLayout(settingsInBar: settingsInBar, child: shell),
          bottomNavigationBar: isFullscreen
              ? null
              : MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(labelScale)),
                  child: NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: _select,
                    destinations: [
                      for (final d in shown)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
