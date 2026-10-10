import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// CSS padding + negative margin counterpart. The visible child's flow size is
/// unchanged; expanded hit-testing remains bounded by ancestor hit-test bounds.
class TdsTouchInset extends SingleChildRenderObjectWidget {
  const TdsTouchInset({required this.insets, required super.child, super.key});
  final EdgeInsets insets;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTouchInset(insets);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTouchInset).insets = insets;
  }
}

class _RenderTouchInset extends RenderShiftedBox {
  _RenderTouchInset(this._insets) : super(null);
  EdgeInsets _insets;
  set insets(EdgeInsets value) {
    if (_insets == value) return;
    _insets = value;
    markNeedsLayout();
  }

  BoxConstraints _expanded(BoxConstraints c) => BoxConstraints(
    minWidth: c.minWidth + _insets.horizontal,
    maxWidth: c.maxWidth + _insets.horizontal,
    minHeight: c.minHeight + _insets.vertical,
    maxHeight: c.maxHeight + _insets.vertical,
  );
  Size _contract(Size s) => Size(
    (s.width - _insets.horizontal).clamp(0, double.infinity),
    (s.height - _insets.vertical).clamp(0, double.infinity),
  );
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    _contract(child!.getDryLayout(_expanded(constraints))),
  );
  @override
  double computeMinIntrinsicWidth(double height) =>
      (child!.getMinIntrinsicWidth(height) - _insets.horizontal).clamp(
        0,
        double.infinity,
      );
  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child!.getMaxIntrinsicWidth(height) - _insets.horizontal).clamp(
        0,
        double.infinity,
      );
  @override
  double computeMinIntrinsicHeight(double width) =>
      (child!.getMinIntrinsicHeight(width) - _insets.vertical).clamp(
        0,
        double.infinity,
      );
  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child!.getMaxIntrinsicHeight(width) - _insets.vertical).clamp(
        0,
        double.infinity,
      );
  @override
  void performLayout() {
    child!.layout(_expanded(constraints), parentUsesSize: true);
    size = constraints.constrain(_contract(child!.size));
    (child!.parentData! as BoxParentData).offset = Offset(
      -_insets.left,
      -_insets.top,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (Rect.fromLTRB(
      -_insets.left,
      -_insets.top,
      size.width + _insets.right,
      size.height + _insets.bottom,
    ).contains(position)) {
      return hitTestChildren(result, position: position);
    }
    return false;
  }
}
