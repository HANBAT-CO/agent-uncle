import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'line_box.dart';

/// Uniform Toss Product Sans counterpart of text-underline-position: under.
/// CSS auto thickness is font-size / 10, not the font's post-table thickness.
/// The under edge uses normalized OS/2 typo descent, not the native default
/// underline offset. Mixed fonts/spans must not use this uniform-font adapter.
class TdsTextUnderline extends SingleChildRenderObjectWidget {
  const TdsTextUnderline({
    required this.fontSize,
    required this.color,
    required super.child,
    this.thickness,
    super.key,
  });
  final double fontSize;
  final Color color;
  final double? thickness;
  @override
  RenderTdsTextUnderline createRenderObject(BuildContext context) =>
      RenderTdsTextUnderline()..update(fontSize, color, thickness);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderTdsTextUnderline renderObject,
  ) => renderObject.update(fontSize, color, thickness);
}

class RenderTdsTextUnderline extends RenderProxyBox {
  double _fontSize = 17;
  Color _color = const Color(0xff000000);
  double? _thickness;
  double _baseline = 0;
  @override
  void performLayout() {
    super.performLayout();
    _baseline =
        child?.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true) ??
        0;
  }

  void update(double fontSize, Color color, double? thickness) {
    _fontSize = fontSize;
    _color = color;
    _thickness = thickness;
    markNeedsPaint();
  }

  List<Rect> get underlineRects {
    if (!hasSize) return const [];
    RenderParagraph? paragraph;
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        paragraph ??= node;
      } else {
        node.visitChildren(visit);
      }
    }

    if (child != null) visit(child!);
    final text = paragraph;
    if (text == null) return const [];
    final boxes = text.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: text.text
            .toPlainText(includeSemanticsLabels: false)
            .length,
      ),
    );
    final lines = <Rect>[];
    for (final box in boxes) {
      final rect = box.toRect();
      final index = lines.indexWhere(
        (line) => (line.top - rect.top).abs() < .01,
      );
      if (index < 0) {
        lines.add(rect);
      } else if (rect.width > 0) {
        // A newline's zero-width box reserves its line index, but must not
        // enlarge a visible line's underline (including aligned/RTL labels).
        lines[index] = lines[index].width > 0
            ? lines[index].expandToInclude(rect)
            : rect;
      }
    }
    if (lines.isEmpty) return const [];
    lines.sort((a, b) => a.top.compareTo(b.top));
    final lineHeight = tdsCssLineHeight(_fontSize * 1.252);
    // Normalize OS/2 sTypoDescender against ascent + descent to one em.
    final underline = _baseline + _fontSize * 534 / (2030 + 534) + 1;
    final thickness = math.max(
      1.0,
      _thickness?.roundToDouble() ?? (_fontSize / 10).floorToDouble(),
    );
    final origin = text.localToGlobal(Offset.zero, ancestor: this);
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].width > 0)
          Rect.fromLTWH(
            lines[i].left + origin.dx,
            i * lineHeight + underline,
            lines[i].width,
            thickness,
          ),
    ];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    for (final rect in underlineRects) {
      final target = rect.shift(offset);
      context.canvas.drawRect(
        Rect.fromLTWH(
          target.left,
          target.top.floorToDouble(),
          target.width,
          target.height,
        ),
        Paint()..color = _color,
      );
    }
  }
}
