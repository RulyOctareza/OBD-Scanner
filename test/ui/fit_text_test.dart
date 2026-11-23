import 'package:autocare/core/ui/fit_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/text_breaks.dart';

const _style = TextStyle(fontFamily: 'Inter', fontSize: 14);

Widget _app(double scale, Widget child) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
      ),
    );

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a word wider than its box shrinks instead of breaking',
      (tester) async {
    await tester.pumpWidget(_app(
      2.0,
      const SizedBox(width: 90, child: WordFitText('Tegangan aki', style: _style)),
    ));
    final p = _paragraph(tester, 'Tegangan aki');
    expect(midWordBreaks(p), isEmpty);
    expect(tester.getSize(find.byType(WordFitText)).width, lessThanOrEqualTo(90));

    // The same text as a plain Text breaks inside the word: the check above
    // is not empty by construction.
    await tester.pumpWidget(_app(
      2.0,
      const SizedBox(width: 90, child: Text('Tegangan aki', style: _style)),
    ));
    expect(midWordBreaks(_paragraph(tester, 'Tegangan aki')), isNotEmpty);
  });

  testWidgets('text that fits keeps the size of a plain Text', (tester) async {
    await tester.pumpWidget(_app(
      1.0,
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 200, child: WordFitText('Tegangan aki', style: _style)),
          SizedBox(width: 200, child: Text('Tegangan aki', style: _style, key: Key('plain'))),
        ],
      ),
    ));
    expect(
      tester.getSize(find.byType(WordFitText)),
      tester.getSize(find.byKey(const Key('plain'))),
    );
  });

  testWidgets('a value with its unit stays on one line', (tester) async {
    await tester.pumpWidget(_app(
      2.0,
      const SizedBox(
        width: 80,
        child: LineFitText('161.420 km', style: _style, maxLines: 1),
      ),
    ));
    final p = _paragraph(tester, '161.420 km');
    expect(p.didExceedMaxLines, isFalse);
    expect(p.size.height, lessThan(p.preferredLineHeight * 1.5));
    expect(tester.getSize(find.byType(LineFitText)).width, lessThanOrEqualTo(80));
  });

  // Meter puts its tiles in IntrinsicHeight rows. A LayoutBuilder there has
  // no intrinsic size: debug builds throw and release builds collapse the row.
  testWidgets('works inside IntrinsicHeight at large text', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.pumpWidget(_app(
      2.0,
      const SizedBox(
        width: 200,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: WordFitText('Konsumsi BBM', style: _style)),
              Expanded(child: LineFitText('14,2 km/L', style: _style)),
            ],
          ),
        ),
      ),
    ));
    FlutterError.onError = original;
    expect(errors, isEmpty);
    final row = tester.getSize(find.byType(IntrinsicHeight));
    expect(row.height, greaterThan(0));
    expect(
      tester.getSize(find.byType(WordFitText)).height,
      lessThanOrEqualTo(row.height),
    );
  });
}
