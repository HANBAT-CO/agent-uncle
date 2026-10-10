import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Native counterparts of Gte (hasCTA) and sre (measured scrollability).
class TdsBottomSheetScope extends InheritedWidget {
  const TdsBottomSheetScope({
    required this.hasCTA,
    required this.scrollable,
    required super.child,
    super.key,
  });
  final bool hasCTA, scrollable;
  static TdsBottomSheetScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TdsBottomSheetScope>();
  @override
  bool updateShouldNotify(TdsBottomSheetScope oldWidget) =>
      hasCTA != oldWidget.hasCTA || scrollable != oldWidget.scrollable;
}

/// A CSS negative top margin: overlap participates in layout as well as paint.
/// Only the ignored gradient overlaps; the buttons remain inside our bounds.
class TdsSheetCTAOverlap extends SingleChildRenderObjectWidget {
  const TdsSheetCTAOverlap({
    required this.overlap,
    required super.child,
    super.key,
  });
  final double overlap;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSheetCTAOverlap(overlap);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSheetCTAOverlap).overlap = overlap;
  }
}

class _RenderSheetCTAOverlap extends RenderShiftedBox {
  _RenderSheetCTAOverlap(this._overlap) : super(null);
  double _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints value) =>
      value.copyWith(minHeight: 0, maxHeight: value.maxHeight + _overlap);
  Size _size(Size childSize, BoxConstraints value) => value.constrain(
    Size(childSize.width, math.max(0, childSize.height - _overlap)),
  );
  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _size(child!.getDryLayout(_childConstraints(constraints)), constraints);
  @override
  double computeMinIntrinsicWidth(double height) =>
      child!.getMinIntrinsicWidth(height + _overlap);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      child!.getMaxIntrinsicWidth(height + _overlap);
  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(0, child!.getMinIntrinsicHeight(width) - _overlap);
  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(0, child!.getMaxIntrinsicHeight(width) - _overlap);
  @override
  void performLayout() {
    child!.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _size(child!.size, constraints);
    (child!.parentData! as BoxParentData).offset = Offset(0, -_overlap);
  }
}
