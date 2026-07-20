import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autocare/main.dart';

void main() {
  testWidgets('App starts and shows Health Screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AutoCareApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('AGYA'), findsOneWidget);
  });
}
