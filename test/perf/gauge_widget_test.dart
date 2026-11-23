import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/features/live_data/presentation/widgets/gauge_painter.dart';
import 'package:autocare/features/live_data/presentation/widgets/gauge_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _gauge(double? value) => MaterialApp(
      home: Scaffold(
        body: GaugeWidget(
          value: value,
          config: ObdMetricConfig.of(ObdMetricType.rpm),
          onTap: () {},
        ),
      ),
    );

void main() {
  testWidgets('a rebuild with the same value does not restart the animation',
      (tester) async {
    await tester.pumpWidget(_gauge(1000));
    await tester.pumpWidget(_gauge(3000)); // starts the 220 ms animation
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(_gauge(3000)); // another PID answered, rpm same
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('3.000'), findsOneWidget); // id_ID grouping
  });

  testWidgets('a new value animates once and then stops', (tester) async {
    await tester.pumpWidget(_gauge(800));
    await tester.pumpWidget(_gauge(2400));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 230));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('2.400'), findsOneWidget);
  });

  testWidgets('dial is a cached track layer under a value layer', (tester) async {
    await tester.pumpWidget(_gauge(1200));
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .toList();
    expect(painters.whereType<GaugeTrackPainter>(), hasLength(1));
    expect(painters.whereType<GaugeValuePainter>(), hasLength(1));
    expect(
      find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is GaugeTrackPainter,
        ),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
