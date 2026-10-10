import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Blink stores used CSS dimensions in 1/64px layout units. Use the same value
/// for text/shape geometry. SkParagraph can still round its painted line advance;
/// quantizing a TextStyle alone does not correct every later glyph baseline.
double tdsCssLineHeight(double height) => (height * 64).floorToDouble() / 64;

/// First-line baseline for the bundled Toss Product Sans faces. Their hhea
/// ascent/descent are 2030/-534 at 2048 units/em. Chromium rounds those metrics
/// to px, splits leading evenly, then floors the first baseline within a line.
/// Do not apply this to arbitrary replacement fonts or mixed-size spans.
double tdsCssTextBaseline(double fontSize, double lineHeight) {
  final ascent = (fontSize * 2030 / 2048).round();
  final descent = (fontSize * 534 / 2048).round();
  return (ascent + (tdsCssLineHeight(lineHeight) - ascent - descent) / 2)
      .floorToDouble();
}

/// Flutter rounds native line advances to logical pixels; CSS preserves
/// fractional line boxes. This wrapper adjusts flow/centering and optionally
/// the first baseline, never glyph scale or each later line's paint position.
/// Use only for uniform text with a known line height (not mixed-size spans).
class TdsLineBox extends SingleChildRenderObjectWidget {
  const TdsLineBox({
    required this.lineHeight,
    required super.child,
    this.baseline,
    super.key,
  }) : assert(lineHeight > 0 && lineHeight < double.infinity);
  final double lineHeight;

  /// Optional first-line CSS baseline; other consumers keep native centering.
  final double? baseline;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLineBox(lineHeight, baseline);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderLineBox)
      ..lineHeight = lineHeight
      ..baseline = baseline;
  }
}

class _RenderLineBox extends RenderShiftedBox {
  _RenderLineBox(this._lineHeight, this._baseline) : super(null);
  double _lineHeight;
  double? _baseline;
  set baseline(double? value) {
    if (_baseline == value) return;
    _baseline = value;
    markNeedsLayout();
  }

  set lineHeight(double value) {
    if (_lineHeight == value) return;
    _lineHeight = value;
    markNeedsLayout();
  }

  double _height(double original) =>
      (original / _lineHeight).round() * _lineHeight;
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final s = child!.getDryLayout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
    );
    return constraints.constrain(Size(s.width, _height(s.height)));
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final childConstraints = constraints.copyWith(
      minHeight: 0,
      maxHeight: double.infinity,
    );
    final nativeBaseline = child!.getDryBaseline(childConstraints, baseline);
    if (nativeBaseline == null) return null;
    if (_baseline != null) return _baseline;
    final childSize = child!.getDryLayout(childConstraints);
    final height = constraints
        .constrain(Size(childSize.width, _height(childSize.height)))
        .height;
    return nativeBaseline + (height - childSize.height) / 2;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child!.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      child!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      _height(child!.getMinIntrinsicHeight(width));
  @override
  double computeMaxIntrinsicHeight(double width) =>
      _height(child!.getMaxIntrinsicHeight(width));
  @override
  void performLayout() {
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(child!.size.width, _height(child!.size.height)),
    );
    final nativeBaseline = _baseline == null
        ? null
        : child!.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
    (child!.parentData! as BoxParentData).offset = Offset(
      0,
      nativeBaseline == null
          ? (size.height - child!.size.height) / 2
          : _baseline! - nativeBaseline,
    );
  }
}

/// Inline-block `vertical-align: middle` includes the parent's zero-width strut.
/// Its center is the parent baseline minus half the x-height, not the center of
/// the parent's line box. Metrics below come from the bundled regular font:
/// head.unitsPerEm=2048, hhea.ascent=2030, descent=-534, glyph x.yMax=1075.
/// Chromium rounds ascent/descent to px and truncates line offsets to 1/64px.
/// A taller/multiline child can enclose the entire strut, adding no extra height.
class TdsInlineMiddle extends SingleChildRenderObjectWidget {
  const TdsInlineMiddle({
    required super.child,
    this.parentFontSize = 16,
    this.parentLineHeight = 24,
    super.key,
  });
  final double parentFontSize, parentLineHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInlineMiddle(parentFontSize, parentLineHeight);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderInlineMiddle).update(
      parentFontSize,
      parentLineHeight,
    );
  }
}

class _RenderInlineMiddle extends RenderShiftedBox {
  _RenderInlineMiddle(this._fontSize, this._lineHeight) : super(null);
  double _fontSize, _lineHeight;
  void update(double fontSize, double lineHeight) {
    if (_fontSize == fontSize && _lineHeight == lineHeight) return;
    _fontSize = fontSize;
    _lineHeight = lineHeight;
    markNeedsLayout();
  }

  (double height, double offset) _geometry(double childHeight) {
    final ascent = (_fontSize * 2030 / 2048).roundToDouble();
    final descent = (_fontSize * 534 / 2048).roundToDouble();
    final baseline = ascent + (_lineHeight - ascent - descent) / 2;
    final center = baseline - _fontSize * 1075 / 2048 / 2;
    final top = ((center - childHeight / 2) * 64).truncate() / 64;
    final minY = math.min(0.0, top);
    return (math.max(_lineHeight, top + childHeight) - minY, top - minY);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(
      Size(childSize.width, _geometry(childSize.height).$1),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child!.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      child!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      _geometry(child!.getMinIntrinsicHeight(width)).$1;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      _geometry(child!.getMaxIntrinsicHeight(width)).$1;
  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    final geometry = _geometry(child!.size.height);
    size = constraints.constrain(Size(child!.size.width, geometry.$1));
    (child!.parentData! as BoxParentData).offset = Offset(0, geometry.$2);
  }
}
