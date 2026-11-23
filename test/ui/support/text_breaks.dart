import 'package:flutter/rendering.dart';

// Large system text can make Flutter break a line inside a word ("Tegang|an",
// "0,0 k|m") or cut a one-line text at its right edge. Neither raises a
// FlutterError or sets didExceedMaxLines, so the layout tests look for them
// by laying the paragraph's text out again under the same constraints.

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

TextPainter _relayout(RenderParagraph p) {
  final wraps = p.softWrap || p.overflow == TextOverflow.ellipsis;
  return TextPainter(
    text: p.text,
    textAlign: p.textAlign,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '…' : null,
    locale: p.locale,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(
      minWidth: p.constraints.minWidth,
      maxWidth: wraps ? p.constraints.maxWidth : double.infinity,
    );
}

/// Every line break [p] placed between two letters or digits, as
/// "before|after" around the break.
List<String> midWordBreaks(RenderParagraph p) {
  if (!p.hasSize) return const [];
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  final painter = _relayout(p);
  final found = <String>[];
  final lines = painter.computeLineMetrics();
  for (var i = 1; i < lines.length; i++) {
    final start = painter
        .getPositionForOffset(Offset(lines[i].left + 0.01, lines[i].baseline))
        .offset;
    if (start <= 0 || start >= text.length) continue;
    if (_wordChar.hasMatch(text[start - 1]) && _wordChar.hasMatch(text[start])) {
      final from = (start - 8).clamp(0, text.length);
      final to = (start + 8).clamp(0, text.length);
      found.add('${text.substring(from, start)}|${text.substring(start, to)}');
    }
  }
  painter.dispose();
  return found;
}

/// Whether a text that does not wrap is wider than the box it got.
bool cutAtEdge(RenderParagraph p) {
  if (!p.hasSize || p.softWrap) return false;
  final painter = _relayout(p);
  final cut = painter.width > p.size.width + 0.5;
  painter.dispose();
  return cut;
}
