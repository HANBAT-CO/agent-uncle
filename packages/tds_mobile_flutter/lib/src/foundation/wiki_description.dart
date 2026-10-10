import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'motion.dart';
import 'wiki_motion.dart';
import 'line_box.dart';
import 'word_break.dart';

/// Spe / Qr.slide.line. Paint slices of one laid-out paragraph so soft wrapping,
/// shaping and whitespace are not changed by splitting it into Text widgets.
class TdsWikiDescription extends StatefulWidget {
  const TdsWikiDescription(this.text, {required this.onEnd, super.key});
  final String text;
  final VoidCallback onEnd;
  // CSS white-space:normal collapses ASCII spaces/newlines, not NBSP.
  static String normalize(String text) => text
      .replaceAll(RegExp(r'[ \t\n\f\r]+'), ' ')
      .replaceAll(RegExp(r'^ | $'), '');
  @override
  State<TdsWikiDescription> createState() => _TdsWikiDescriptionState();
}

class _TdsWikiDescriptionState extends State<TdsWikiDescription>
    with SingleTickerProviderStateMixin {
  final _painter = TextPainter();
  late final _clock = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onEnd();
    });
  int _lineCount = -1, _generation = 0;

  void _configure(int count) {
    if (_lineCount == count) return;
    _lineCount = count;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _clock.duration =
          TdsMotion.slow.duration + Duration(milliseconds: 100 * count);
      _clock.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(TdsWikiDescription old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _lineCount = -1;
  }

  @override
  void dispose() {
    _clock.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _painter
        ..text = TextSpan(
          text: tdsKeepAllText(TdsWikiDescription.normalize(widget.text)),
          style: DefaultTextStyle.of(context).style,
        )
        ..textDirection = Directionality.of(context)
        ..textScaler = MediaQuery.textScalerOf(context)
        ..layout(maxWidth: constraints.maxWidth);
      final lines = _painter.computeLineMetrics();
      _configure(lines.length);
      return Semantics(
        label: TdsWikiDescription.normalize(widget.text),
        child: TdsLineBox(
          lineHeight:
              (DefaultTextStyle.of(context).style.fontSize ?? 16) *
              (DefaultTextStyle.of(context).style.height ?? 1.5),
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => CustomPaint(
              size: Size(
                constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : _painter.width,
                _painter.height,
              ),
              painter: _DescriptionPainter(
                _painter,
                lines,
                (_clock.duration ?? Duration.zero) * _clock.value,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DescriptionPainter extends CustomPainter {
  const _DescriptionPainter(this.text, this.lines, this.elapsed);
  final TextPainter text;
  final List<ui.LineMetrics> lines;
  final Duration elapsed;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < lines.length; i++) {
      final t = wikiSpring(TdsMotion.slow, elapsed, delayMs: 100 * (i + 1));
      if (t == 0) continue;
      final line = lines[i];
      final top = i == 0 ? 0.0 : line.baseline - line.ascent;
      final bottom = i == lines.length - 1
          ? size.height
          : lines[i + 1].baseline - lines[i + 1].ascent;
      final rect = Rect.fromLTRB(0, top, size.width, bottom);
      canvas.save();
      canvas.translate(0, line.height * .3 * (1 - t));
      canvas.clipRect(rect);
      canvas.saveLayer(
        rect,
        Paint()..color = Color.fromRGBO(255, 255, 255, t.clamp(0, 1)),
      );
      text.paint(canvas, Offset.zero);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DescriptionPainter old) => true;
}
