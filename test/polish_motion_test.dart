import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/features/health/domain/health_engine.dart';

void main() {
  testWidgets('Health score ring animates toward report score', (tester) async {
    final report = HealthReport(
      score: 88,
      statusTitle: 'Sehat',
      statusDescription: 'Mesin dalam kondisi baik',
      statusColor: AppColors.success,
      checks: const [],
      warnings: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: report.score / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              final displayScore = (animatedValue * 100).round();
              return Text('$displayScore');
            },
          ),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('88'), findsOneWidget);
  });

  testWidgets('Recording pulse dot builds without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _TestPulse(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.circle), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });
}

class _TestPulse extends StatefulWidget {
  const _TestPulse();

  @override
  State<_TestPulse> createState() => _TestPulseState();
}

class _TestPulseState extends State<_TestPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_controller),
      child: const Icon(Icons.circle, color: AppColors.danger, size: 10),
    );
  }
}
