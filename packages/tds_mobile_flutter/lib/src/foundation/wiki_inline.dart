import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Original Vpe geometry. Edges are original PNGs, not approximated slants.
@immutable
class TdsWikiHighlightGeometry {
  const TdsWikiHighlightGeometry(this.rect, this.leftEdge, this.rightEdge);
  final Rect rect;
  final bool leftEdge, rightEdge;
  static List<TdsWikiHighlightGeometry> fromRects(
    List<Rect> rects,
    double iconWidth,
  ) => [
    for (var i = 0; i < rects.length; i++)
      _line(rects[i], i == 0, i == rects.length - 1, iconWidth),
  ];
  static TdsWikiHighlightGeometry _line(
    Rect r,
    bool first,
    bool last,
    double icon,
  ) {
    final shrink = r.height * .05;
    final height = r.height * .46;
    final margin = shrink * ((first ? 1 : 0) + (last ? 1 : 0));
    final width = last
        ? r.width + icon + 2 - height / 2 * .6 - shrink
        : r.width;
    return TdsWikiHighlightGeometry(
      Rect.fromLTWH(
        r.left + margin / 2,
        r.top + r.height * .48,
        width - margin,
        height,
      ),
      first,
      last,
    );
  }
}

class TdsWikiInline extends StatefulWidget {
  const TdsWikiInline({
    required this.text,
    required this.style,
    required this.dark,
    required this.padding,
    required this.icon,
    required this.iconWidth,
    required this.highlightKey,
    this.iconSlotWidth,
    this.iconOpacity = 1,
    this.iconTranslation = 0,
    this.highlightOpacity = 1,
    this.highlightScale = 1,
    super.key,
  });
  final String text;
  final TextStyle style;
  final bool dark;
  final double padding, iconWidth;
  final double? iconSlotWidth;
  final double iconOpacity, iconTranslation, highlightOpacity, highlightScale;
  final Widget icon;
  final GlobalKey highlightKey;
  @override
  State<TdsWikiInline> createState() => _TdsWikiInlineState();
}

class _TdsWikiInlineState extends State<TdsWikiInline> {
  final _streams = <ImageStream>[];
  final _listeners = <ImageStreamListener>[];
  final _images = <ImageInfo?>[null, null];
  bool? _loadedDark;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(TdsWikiInline old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _clear() {
    for (var i = 0; i < _streams.length; i++) {
      _streams[i].removeListener(_listeners[i]);
      _images[i]?.dispose();
      _images[i] = null;
    }
    _streams.clear();
    _listeners.clear();
  }

  void _load() {
    if (_loadedDark == widget.dark) return;
    _clear();
    _loadedDark = widget.dark;
    for (var i = 0; i < 2; i++) {
      final name =
          'wiki-highlight-${i == 0 ? 'L' : 'R'}${widget.dark ? '-dark' : ''}.png';
      final stream = AssetImage(
        'assets/wiki/$name',
        package: 'tds_mobile_flutter',
      ).resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener((info, sync) {
        _images[i]?.dispose();
        _images[i] = info;
        if (!sync && mounted) setState(() {});
      });
      _streams.add(stream);
      _listeners.add(listener);
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _WikiHighlight(
    key: widget.highlightKey,
    textLength: widget.text.length,
    fontSize: widget.style.fontSize ?? 16,
    iconWidth: widget.iconWidth,
    opacity: widget.highlightOpacity,
    scale: widget.highlightScale,
    dark: widget.dark,
    left: _images[0]?.image,
    right: _images[1]?.image,
    child: RichText(
      textDirection: Directionality.of(context),
      textWidthBasis: TextWidthBasis.longestLine,
      text: TextSpan(
        style: widget.style,
        children: [
          // Inline spacers affect only their line, unlike Padding around a block.
          WidgetSpan(child: SizedBox(width: widget.padding.roundToDouble())),
          TextSpan(text: widget.text),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(
              height: widget.iconWidth,
              width:
                  (widget.iconSlotWidth ??
                          (widget.iconWidth + widget.padding + 1))
                      .roundToDouble(),
              child: Opacity(
                opacity: widget.iconOpacity,
                child: Transform.translate(
                  offset: Offset(widget.iconTranslation, 0),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: widget.iconWidth + 1,
                    maxWidth: widget.iconWidth + 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: widget.icon,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WikiHighlight extends SingleChildRenderObjectWidget {
  const _WikiHighlight({
    required this.textLength,
    required this.fontSize,
    required this.iconWidth,
    required this.opacity,
    required this.scale,
    required this.dark,
    this.left,
    this.right,
    required super.child,
    super.key,
  });
  final int textLength;
  final double fontSize, iconWidth;
  final double opacity, scale;
  final bool dark;
  final ui.Image? left, right;
  @override
  RenderTdsWikiHighlight createRenderObject(BuildContext context) =>
      RenderTdsWikiHighlight()..update(
        textLength,
        fontSize,
        iconWidth,
        dark,
        left,
        right,
        opacity,
        scale,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    RenderTdsWikiHighlight renderObject,
  ) => renderObject.update(
    textLength,
    fontSize,
    iconWidth,
    dark,
    left,
    right,
    opacity,
    scale,
  );
}

class RenderTdsWikiHighlight extends RenderProxyBox {
  int _textLength = 0;
  double _fontSize = 16, _iconWidth = 0;
  double _opacity = 1, _scale = 1;
  bool _dark = false;
  ui.Image? _left, _right;
  void update(
    int length,
    double fontSize,
    double iconWidth,
    bool dark,
    ui.Image? left,
    ui.Image? right,
    double opacity,
    double scale,
  ) {
    _textLength = length;
    _fontSize = fontSize;
    _iconWidth = iconWidth;
    _dark = dark;
    _left = left;
    _right = right;
    _opacity = opacity;
    _scale = scale;
    markNeedsPaint();
  }

  List<Rect> get wordRects {
    if (!hasSize || child is! RenderParagraph || _textLength == 0) return [];
    final paragraph = child! as RenderParagraph;
    // The original inline span client rect is the font box, not the full line
    // box. Toss Product Sans hhea metrics are 2030/-534 at 2048 units per em.
    final height =
        (_fontSize * 2030 / 2048).roundToDouble() +
        (_fontSize * 534 / 2048).roundToDouble();
    return paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 1, extentOffset: 1 + _textLength),
        )
        .where((box) => box.right > box.left)
        .map(
          (box) => Rect.fromLTWH(
            box.left,
            box.top + (box.bottom - box.top - height) / 2,
            box.right - box.left,
            height,
          ),
        )
        .toList();
  }

  List<TdsWikiHighlightGeometry> get highlights =>
      TdsWikiHighlightGeometry.fromRects(wordRects, _iconWidth);
  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final gradient = LinearGradient(
      colors: _dark
          ? const [
              Color.fromRGBO(38, 110, 217, .4),
              Color.fromRGBO(12, 63, 136, .2),
            ]
          : const [
              Color.fromRGBO(173, 208, 255, .8),
              Color.fromRGBO(217, 234, 255, .6),
            ],
    );
    void edge(ui.Image? image, Rect r, bool left) {
      if (image == null) return;
      final width = r.height * image.width / image.height;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(left ? r.left - width : r.right, r.top, width, r.height),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    for (final geometry in highlights) {
      if (_opacity == 0) break;
      final rect = geometry.rect.shift(offset);
      canvas.save();
      final origin = rect.left - (geometry.leftEdge ? rect.height / 2 : 0);
      canvas.translate(origin, rect.center.dy);
      canvas.scale(_scale, 1);
      canvas.translate(-origin, -rect.center.dy);
      if (_opacity < 1) {
        canvas.saveLayer(
          rect.inflate(rect.height),
          Paint()..color = Color.fromRGBO(255, 255, 255, _opacity),
        );
      }
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
      if (geometry.leftEdge) edge(_left, rect, true);
      if (geometry.rightEdge) edge(_right, rect, false);
      if (_opacity < 1) canvas.restore();
      canvas.restore();
    }
    super.paint(context, offset);
  }
}
