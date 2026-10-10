import 'package:flutter/widgets.dart';
import 'motion.dart';

double wikiSpring(TdsSpringCurve curve, Duration elapsed, {int delayMs = 0}) {
  final micros = elapsed.inMicroseconds - delayMs * 1000;
  if (micros <= 0) return 0;
  return curve.transform((micros / curve.duration.inMicroseconds).clamp(0, 1));
}

/// _f and dimmer timelines do not share a single eased opacity.
@immutable
class TdsWikiPopupFrame {
  const TdsWikiPopupFrame({
    this.word = 0,
    this.box = 0,
    this.scale = .9,
    this.dimmer = 0,
  });
  final double word, box, scale, dimmer;
  static final duration = TdsMotion.large.duration > TdsMotion.basic.duration
      ? TdsMotion.large.duration
      : TdsMotion.basic.duration;
  TdsWikiPopupFrame animate(bool entering, Duration elapsed) {
    double mix(double a, double b, TdsSpringCurve curve) =>
        a + (b - a) * wikiSpring(curve, elapsed);
    return TdsWikiPopupFrame(
      word: mix(
        word,
        entering ? 1 : 0,
        entering ? TdsMotion.medium : TdsMotion.quick,
      ).clamp(0, 1),
      box: mix(box, entering ? 1 : 0, TdsMotion.basic).clamp(0, 1),
      scale: mix(scale, entering ? 1 : .9, TdsMotion.large),
      dimmer: mix(dimmer, entering ? .8 : 0, TdsMotion.basic).clamp(0, .8),
    );
  }
}

class TdsWikiPopupMotion extends StatefulWidget {
  const TdsWikiPopupMotion({
    required this.animation,
    required this.builder,
    super.key,
  });
  final Animation<double> animation;
  final Widget Function(BuildContext, TdsWikiPopupFrame) builder;
  @override
  State<TdsWikiPopupMotion> createState() => _TdsWikiPopupMotionState();
}

class _TdsWikiPopupMotionState extends State<TdsWikiPopupMotion>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: TdsWikiPopupFrame.duration,
  );
  TdsWikiPopupFrame _from = const TdsWikiPopupFrame();
  bool _entering = true;
  TdsWikiPopupFrame get _frame =>
      _from.animate(_entering, _clock.duration! * _clock.value);
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_status);
    _clock.forward();
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.reverse || !_entering) return;
    _from = _frame;
    _entering = false;
    _clock.forward(from: 0);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_status);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => widget.builder(context, _frame),
  );
}

/// Independent kf channels. Explicit `from` values deliberately restart on
/// reentry; the empty padding exit motion keeps the current spacer width.
@immutable
class TdsWikiInlineFrame {
  const TdsWikiInlineFrame({
    this.padding = 0,
    this.iconWidth = 0,
    this.iconOpacity = 0,
    this.iconX = -5,
    this.highlightOpacity = 0,
    this.highlightScale = 0,
  });
  final double padding, iconWidth, iconOpacity, iconX;
  final double highlightOpacity, highlightScale;

  TdsWikiInlineFrame animate({
    required bool entering,
    required Duration elapsed,
    required double targetPadding,
    required double targetIconWidth,
  }) {
    double mix(double a, double b, TdsSpringCurve c, [int delay = 0]) =>
        a + (b - a) * wikiSpring(c, elapsed, delayMs: delay);
    return TdsWikiInlineFrame(
      padding: entering ? mix(0, targetPadding, TdsMotion.quick) : padding,
      iconWidth: entering
          ? mix(0, targetIconWidth + targetPadding + 1, TdsMotion.quick)
          : mix(iconWidth.roundToDouble(), 0, TdsMotion.basic),
      iconOpacity:
          (entering
                  ? mix(0, 1, TdsMotion.basic, 250)
                  : mix(iconOpacity, 0, TdsMotion.quick))
              .clamp(0, 1),
      iconX: mix(iconX, entering ? 0 : -5, TdsMotion.basic, entering ? 150 : 0),
      highlightOpacity:
          (entering
                  ? mix(highlightOpacity, 1, TdsMotion.medium)
                  : mix(1, 0, TdsMotion.medium))
              .clamp(0, 1),
      highlightScale: entering
          ? mix(highlightScale, 1, TdsMotion.basic)
          : mix(1, 0, TdsMotion.medium),
    );
  }
}

class TdsWikiInlineMotion extends StatefulWidget {
  const TdsWikiInlineMotion({
    required this.inView,
    required this.padding,
    required this.iconWidth,
    required this.builder,
    super.key,
  });
  final bool inView;
  final double padding, iconWidth;
  final Widget Function(BuildContext, TdsWikiInlineFrame) builder;
  @override
  State<TdsWikiInlineMotion> createState() => _TdsWikiInlineMotionState();
}

class _TdsWikiInlineMotionState extends State<TdsWikiInlineMotion>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this);
  TdsWikiInlineFrame _from = const TdsWikiInlineFrame();
  bool _running = false, _entering = false;
  double _padding = 0, _iconWidth = 0;
  TdsWikiInlineFrame get _frame => !_running
      ? _from
      : _from.animate(
          entering: _entering,
          elapsed: _clock.duration! * _clock.value,
          targetPadding: _padding,
          targetIconWidth: _iconWidth,
        );
  @override
  void initState() {
    super.initState();
    if (widget.inView) _start();
  }

  void _start() {
    _from = _frame;
    _entering = widget.inView;
    _padding = widget.padding;
    _iconWidth = widget.iconWidth;
    _running = true;
    _clock.duration =
        TdsMotion.basic.duration + Duration(milliseconds: _entering ? 250 : 0);
    _clock.forward(from: 0);
  }

  @override
  void didUpdateWidget(TdsWikiInlineMotion old) {
    super.didUpdateWidget(old);
    if (old.inView != widget.inView ||
        (widget.inView &&
            (old.padding != widget.padding ||
                old.iconWidth != widget.iconWidth))) {
      _start();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => widget.builder(context, _frame),
  );
}
