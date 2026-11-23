import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Large system text can make a single word wider than its line. Flutter then
// breaks inside the word ("Tegang / an aki", "0,0 k / m"), which reads worse
// than slightly smaller text. These widgets shrink the text just enough for
// the widest word (WordFitText) or the whole line (LineFitText) to fit.
//
// The shrinking happens in layout (_ShrinkToFit), not with a LayoutBuilder:
// these texts sit inside IntrinsicHeight rows (Meter tiles), and a
// LayoutBuilder has no intrinsic size; in a release build such a row silently
// collapses.
//
// When the text fits, the box paints the Text as it is, so at the default
// text size the screens look exactly as with a plain Text.

/// Whether the user's text size is above the default.
bool isTextEnlarged(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) > 100.5;

final Map<(String, TextStyle?, TextScaler), double> _widthCache = {};

double _measure(
  String text,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
) {
  final key = (text, style, scaler);
  final cached = _widthCache[key];
  if (cached != null) return cached;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  if (_widthCache.length > 512) _widthCache.clear();
  _widthCache[key] = width;
  return width;
}

/// Width of [text] on one line at the current text size.
double measureTextWidth(BuildContext context, String text, TextStyle? style) =>
    _measure(
      text,
      DefaultTextStyle.of(context).style.merge(style),
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );

/// Width of the widest word of [text]. Words split at plain spaces and line
/// breaks only: a no-break space keeps a value and its unit together.
double measureWidestWord(
  BuildContext context,
  String text,
  TextStyle? style,
) {
  var widest = 0.0;
  for (final word in text.split(RegExp(r'[ \n]+'))) {
    if (word.isEmpty) continue;
    widest = math.max(widest, measureTextWidth(context, word, style));
  }
  return widest;
}

enum _Fit { widestWord, wholeLine }

/// Lays out a Text at the width its widest word or whole line needs and
/// paints it scaled down to the width it was given. Text drawn under a scale
/// transform stays sharp. Its intrinsic size comes from the Text's own, so it
/// works inside IntrinsicHeight.
class _ShrinkToFit extends SingleChildRenderObjectWidget {
  const _ShrinkToFit({required this.fit, required Widget super.child});

  final _Fit fit;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShrinkToFit(fit);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShrinkToFit renderObject,
  ) {
    renderObject.fit = fit;
  }
}

class _RenderShrinkToFit extends RenderProxyBox {
  _RenderShrinkToFit(this._fit);

  _Fit _fit;
  set fit(_Fit value) {
    if (value == _fit) return;
    _fit = value;
    markNeedsLayout();
  }

  double _scale = 1;

  double _needed(RenderBox child) => _fit == _Fit.widestWord
      ? child.getMinIntrinsicWidth(double.infinity)
      : child.getMaxIntrinsicWidth(double.infinity);

  /// Scale at which the child fits [maxWidth]; 1 when it fits as it is.
  double _scaleFor(RenderBox child, double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) return 1;
    final needed = _needed(child);
    return needed > maxWidth ? maxWidth / needed : 1;
  }

  static BoxConstraints _unscaled(BoxConstraints c, double scale) =>
      scale == 1 ? c : c / scale;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (c, w) => c.getMaxIntrinsicHeight(w));

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) height,
  ) {
    final child = this.child;
    if (child == null) return 0;
    final scale = _scaleFor(child, width);
    return height(child, width / scale) * scale;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final scale = _scaleFor(child, constraints.maxWidth);
    return constraints
        .constrain(child.getDryLayout(_unscaled(constraints, scale)) * scale);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    _scale = _scaleFor(child, constraints.maxWidth);
    child.layout(_unscaled(constraints, _scale), parentUsesSize: true);
    size = constraints.constrain(child.size * _scale);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = child?.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance * _scale;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_scale == 1) {
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(Matrix4.diagonal3Values(_scale, _scale, 1));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}

/// Text that wraps between words but never inside one.
class WordFitText extends StatelessWidget {
  const WordFitText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final plain = Text(
      text,
      style: style,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: overflow,
    );
    return _ShrinkToFit(fit: _Fit.widestWord, child: plain);
  }
}

/// Text that stays on one line, e.g. a value with its unit ("161.420 km",
/// "Rp450.000"), shrinking when the line is wider than the room it has.
class LineFitText extends StatelessWidget {
  const LineFitText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.overflow,
  }) : span = null;

  /// Several styles on one line, e.g. a large value with a small unit.
  const LineFitText.rich(
    InlineSpan this.span, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.overflow,
  })  : text = null,
        style = null;

  final String? text;
  final InlineSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Passed through to the Text, which keeps them at the default text size.
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final plain = span != null
        ? Text.rich(
            span!,
            textAlign: textAlign,
            maxLines: maxLines,
            softWrap: softWrap,
            overflow: overflow,
          )
        : Text(
            text!,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            softWrap: softWrap,
            overflow: overflow,
          );
    return _ShrinkToFit(fit: _Fit.wholeLine, child: plain);
  }
}
