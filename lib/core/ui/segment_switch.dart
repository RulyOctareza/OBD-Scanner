import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One segment of a tab that holds two screens, e.g. Live: Meter | Sensor.
class SegmentRoute {
  const SegmentRoute(this.label, this.path, this.icon);

  final String label;

  /// Route path of the segment's screen (a real route, so links and the
  /// benchmark can open it directly).
  final String path;
  final IconData icon;
}

const liveSegments = [
  SegmentRoute('Meter', '/dashboard', Icons.speed_rounded),
  SegmentRoute('Sensor', '/live_data', Icons.view_list_rounded),
];

const diagnosticSegments = [
  SegmentRoute('Pindai', '/diagnostics', Icons.troubleshoot_rounded),
  SegmentRoute('Kamus kode', '/dtc_lookup', Icons.menu_book_rounded),
];

/// Switches between the screens of one tab. Each segment is its own route in
/// the tab's branch, so only the visible screen is built.
class SegmentSwitch extends StatelessWidget {
  const SegmentSwitch({
    super.key,
    required this.segments,
    required this.current,
  });

  final List<SegmentRoute> segments;

  /// Path of the screen showing this switch.
  final String current;

  @override
  Widget build(BuildContext context) {
    // Sits in the app bar: labels grow with the text size up to 1.3x, then
    // the control shrinks to fit rather than overflow the bar.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _switch(context),
      ),
    );
  }

  Widget _switch(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final s in segments)
          ButtonSegment<String>(
            value: s.path,
            label: Text(s.label),
            icon: Icon(s.icon, size: 18),
          ),
      ],
      selected: {current},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        final path = selection.first;
        if (path != current) context.go(path);
      },
    );
  }
}
