import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'input_dispatch.dart';
import 'list_row_motion.dart';
import 'motion.dart';
import 'pressable.dart';
import 'raw_press_region.dart';
import 'theme.dart';
import 'tokens.g.dart';

enum _RowEffect { none, touch, blink, shine }

/// Native counterpart of ListRowRef. A controller attaches to one row at a time;
/// layout/scroll access is provided separately through the widget's GlobalKey.
/// Imperative calls in one event turn (including its microtasks) are batched:
/// the last accepted effect is rendered. Discrete input commits at a microtask
/// boundary. Blink checks committed state and keeps every accepted timeout.
class TdsListRowController extends ChangeNotifier {
  _RowEffect _effect = _RowEffect.none;
  Duration _duration = const Duration(milliseconds: 1500);
  int _playCount = 1;
  bool _active = false;
  void blink({Duration duration = const Duration(milliseconds: 1500)}) {
    if (_active) return;
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration');
    }
    _effect = _RowEffect.blink;
    _duration = duration;
    notifyListeners();
  }

  void shine({int playCount = 1}) {
    if (playCount < 1) throw ArgumentError.value(playCount, 'playCount');
    _effect = _RowEffect.shine;
    _playCount = playCount;
    notifyListeners();
  }
}

/// The child is the padded inner container, not the outer row. Blink is behind
/// it; shine is above it; the outer hairline/disabled backgrounds never scale.
class TdsListRowEffects extends StatefulWidget {
  const TdsListRowEffects({
    required this.child,
    required this.controller,
    this.pressed = false,
    this.handleInput = false,
    this.touchEffectEnabled = true,
    this.enabled = true,
    this.onPressed,
    super.key,
  });
  final Widget child;
  final TdsListRowController? controller;
  final bool pressed;
  final bool handleInput, touchEffectEnabled, enabled;
  final VoidCallback? onPressed;
  @override
  State<TdsListRowEffects> createState() => _TdsListRowEffectsState();
}

class _TdsListRowEffectsState extends State<TdsListRowEffects>
    with TickerProviderStateMixin {
  late final _content = AnimationController(vsync: this, value: 1);
  late final _touch = AnimationController(vsync: this);
  late final _blink = AnimationController(
    vsync: this,
    duration: TdsListRowMotion.blinkEntryDuration,
  );
  late final _blinkDimmer = AnimationController(vsync: this);
  late final AnimationController _blinkOpacity =
      AnimationController(vsync: this, value: 1)..addStatusListener((status) {
        if (status == AnimationStatus.completed && _blinkOpacity.value == 0) {
          _blink.stop();
          if (mounted) setState(() => _blinkVisible = false);
        }
      });
  late final _shine = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _effect == _RowEffect.shine) {
        setState(() => _change(_RowEffect.none));
      }
    });
  final _blinkTimers = <Timer>{};
  _RowEffect _effect = _RowEffect.none;
  _RowEffect? _pendingEffect;
  int _pendingShineCount = 1, _batchGeneration = 0;
  bool _flushScheduled = false, _discreteBatch = false;
  Timer? _batchTimer;
  int? _batchFrame;
  bool _blinkVisible = false, _darkShine = false;
  Size _rowSize = Size.zero;
  double _shineFromX = 0, _shineToX = 0;
  int _requestedShineCount = 1;
  double Function(double) _contentValue = (_) => 1;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);
  Duration _duration(Duration value) =>
      _reduceMotion ? const Duration(milliseconds: 1) : value;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_play);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = TdsTheme.of(context).isDark;
    if (_effect == _RowEffect.shine && dark != _darkShine) {
      // $Qe renders light/dark shine in different React child slots. Theme
      // changes remount that layer, with the latest requested repeat count.
      _startShine(dark);
    }
  }

  @override
  void didUpdateWidget(TdsListRowEffects old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_play);
      old.controller?._active = false;
      _reset();
      widget.controller?.addListener(_play);
    }
    if (!widget.handleInput && old.pressed != widget.pressed) {
      _change(widget.pressed ? _RowEffect.touch : _RowEffect.none);
    }
  }

  void _pressStart(PointerDownEvent event, Offset? firstTouch) {
    _scheduleEffectCommit(discrete: true);
    if (!widget.enabled || !widget.touchEffectEnabled) return;
    if (TdsTheme.of(context).platform.os == TdsOS.ios &&
        firstTouch != null &&
        firstTouch.dx <= 30) {
      return;
    }
    _queueEffect(_RowEffect.touch);
  }

  void _pressEnd() {
    // An already-started source press still ends if disabled changes while
    // held. IgnorePointer prevents fresh input; it must not strand this state.
    _scheduleEffectCommit(discrete: true);
    _queueEffect(_RowEffect.none);
  }

  void _scaleTo(double target, TdsSpringCurve curve) {
    final from = _contentValue(_content.value);
    _contentValue = (t) => from + (target - from) * curve.transform(t);
    _content.duration = _duration(curve.duration);
    _content.forward(from: 0);
  }

  void _change(_RowEffect effect) {
    if (effect == _effect) return;
    if (_effect == _RowEffect.blink && effect != _RowEffect.blink) {
      // Each source layer exits from its current opacity. In particular a
      // cancelled, still-delayed dimmer must not appear later during exit.
      for (final opacity in [_blinkOpacity, _blinkDimmer]) {
        opacity.animateTo(
          0,
          duration: _duration(TdsMotion.slow.duration),
          curve: TdsMotion.slow,
        );
      }
    }
    if (effect != _RowEffect.shine) _shine.stop();
    _effect = effect;
    widget.controller?._active = effect != _RowEffect.none;
    _touch.animateTo(
      effect == _RowEffect.touch ? 1 : 0,
      duration: _duration(
        effect == _RowEffect.touch
            ? TdsMotion.quick.duration
            : TdsMotion.rapid.duration,
      ),
      curve: effect == _RowEffect.touch ? TdsMotion.quick : TdsMotion.rapid,
    );
    switch (effect) {
      case _RowEffect.blink:
        if (_blinkVisible) {
          // AnimatePresence reuses the exiting layer. Its radius continues;
          // only opacity retargets, with the original independent delays.
          _enterBlinkOpacity(_blinkOpacity, const Duration(milliseconds: 80));
        } else {
          _blinkOpacity.value = 1;
          _blinkDimmer.value = 0;
          _blink.duration = _duration(TdsListRowMotion.blinkEntryDuration);
          _blink.forward(from: 0);
        }
        _blinkVisible = true;
        _enterBlinkOpacity(_blinkDimmer, const Duration(milliseconds: 480));
        _contentValue = (t) => TdsListRowMotion.blinkScale(
          TdsListRowMotion.blinkContentDuration * t,
        );
        _content.duration = _duration(TdsListRowMotion.blinkContentDuration);
        _content.forward(from: 0);
      case _RowEffect.touch:
        _scaleTo(.96, TdsMotion.quick);
      case _RowEffect.none:
        _scaleTo(1, TdsMotion.rapid);
      case _RowEffect.shine:
        // Original shine container variant is empty: do not interrupt scale.
        break;
    }
  }

  void _enterBlinkOpacity(AnimationController opacity, Duration delay) {
    final duration = delay + TdsMotion.basic.duration;
    opacity.animateTo(
      1,
      duration: _duration(duration),
      curve: Interval(
        delay.inMicroseconds / duration.inMicroseconds,
        1,
        curve: TdsMotion.basic,
      ),
    );
  }

  void _play() {
    final controller = widget.controller!;
    _queueEffect(controller._effect, playCount: controller._playCount);
    if (controller._effect == _RowEffect.blink) {
      late final Timer timer;
      timer = Timer(_duration(controller._duration), () {
        _blinkTimers.remove(timer);
        if (mounted) _queueEffect(_RowEffect.none);
      });
      // A React batch may accept several blinks before any state is committed.
      // Even a blink overwritten by shine keeps its timeout. Cancel ALL timers
      // on detach, including ones the source's single timeout ref loses.
      _blinkTimers.add(timer);
    }
  }

  void _queueEffect(_RowEffect effect, {int playCount = 1}) {
    _pendingEffect = effect;
    _pendingShineCount = playCount;
    _scheduleEffectCommit(discrete: _discreteBatch || TdsInputDispatch.active);
  }

  void _cancelDeferredCommit() {
    _batchTimer?.cancel();
    _batchTimer = null;
    final frame = _batchFrame;
    if (frame != null) WidgetsBinding.instance.cancelFrameCallbackWithId(frame);
    _batchFrame = null;
  }

  void _scheduleEffectCommit({bool discrete = false}) {
    if (_flushScheduled && (!discrete || _discreteBatch)) return;
    _cancelDeferredCommit();
    _flushScheduled = true;
    _discreteBatch = discrete;
    final generation = ++_batchGeneration;
    void flush() {
      if (!mounted || generation != _batchGeneration) return;
      _cancelDeferredCommit();
      _flushScheduled = false;
      _discreteBatch = false;
      final pending = _pendingEffect;
      _pendingEffect = null;
      if (pending != null) {
        setState(() => _applyEffect(pending, _pendingShineCount));
      }
    }

    if (discrete) {
      // React flushes discrete DOM input before Promise continuations. Upgrade
      // an imperative batch if child input queued it before our raw listener.
      WidgetsBinding.instance.ensureVisualUpdate();
      scheduleMicrotask(flush);
    } else {
      // Default-priority imperative updates include the current microtask
      // chain. Commit in the next event task, or before the next frame if that
      // arrives first (also gives deterministic widget-test frame semantics).
      _batchTimer = Timer(Duration.zero, flush);
      _batchFrame = WidgetsBinding.instance.scheduleFrameCallback(
        (_) => flush(),
      );
    }
  }

  void _applyEffect(_RowEffect effect, int playCount) {
    if (_effect == _RowEffect.shine && effect == _RowEffect.shine) {
      // L is memoized on playCount/state/theme, not row dimensions. Framer
      // only retargets when the resulting animate value (light's X) changes;
      // changing transition/repeat options alone does not restart a channel.
      if (_requestedShineCount == playCount) return;
      _requestedShineCount = playCount;
      final to = _rowSize.width.roundToDouble();
      if (_darkShine || to == _shineToX) return;
      _shineFromX = TdsListRowMotion.shineRect(
        _rowSize,
        _shine.duration! * _shine.value,
        dark: false,
        translateFromX: _shineFromX,
        translateToX: _shineToX,
      ).left;
      _shineToX = to;
      _shine.duration = _duration(
        TdsListRowMotion.shineDuration(false, _requestedShineCount),
      );
      _shine.forward(from: 0);
      return;
    }
    _change(effect);
    if (effect == _RowEffect.shine) {
      _startShine(TdsTheme.of(context).isDark, playCount: playCount);
    }
  }

  void _startShine(bool dark, {int? playCount}) {
    _darkShine = dark;
    _requestedShineCount = playCount ?? widget.controller!._playCount;
    // L reads integer clientWidth/clientHeight during render, before a size
    // change in the same commit is laid out. The gradient box itself uses live
    // CSS percentages; only light's pixel translation endpoints are captured.
    _shineFromX = -3 * _rowSize.height.roundToDouble();
    _shineToX = _rowSize.width.roundToDouble();
    _shine.duration = _duration(
      TdsListRowMotion.shineDuration(dark, _requestedShineCount),
    );
    _shine.forward(from: 0);
  }

  void _reset() {
    _batchGeneration++;
    _cancelDeferredCommit();
    _flushScheduled = false;
    _discreteBatch = false;
    _pendingEffect = null;
    for (final timer in _blinkTimers) {
      timer.cancel();
    }
    _blinkTimers.clear();
    for (final animation in [
      _content,
      _touch,
      _blink,
      _blinkOpacity,
      _blinkDimmer,
      _shine,
    ]) {
      animation.stop();
    }
    _effect = _RowEffect.none;
    _blinkVisible = false;
    _contentValue = (_) => 1;
    _touch.value = 0;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_play);
    widget.controller?._active = false;
    _reset();
    for (final animation in [
      _content,
      _touch,
      _blink,
      _blinkOpacity,
      _blinkDimmer,
      _shine,
    ]) {
      animation.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _visual(context);
    if (!widget.handleInput) return child;
    if (widget.onPressed != null || widget.touchEffectEnabled) {
      final content = child;
      child = TdsPressable(
        enabled: widget.enabled,
        button: widget.onPressed != null,
        skipTraversal: widget.onPressed == null,
        keyboardActivation: widget.onPressed != null,
        activateOnKeyDown: true,
        deferPointerActivation: true,
        onPressed: widget.onPressed,
        builder: (_, pressed, hovered, focused) => content,
      );
    }
    return TdsRawPressRegion(
      onPressStart: _pressStart,
      onPressEnd: _pressEnd,
      onPressCancel: _pressEnd,
      child: child,
    );
  }

  Widget _visual(BuildContext context) => _RecordRowSize(
    onSize: (size) => _rowSize = size,
    child: AnimatedBuilder(
      animation: Listenable.merge([
        _content,
        _touch,
        _blink,
        _blinkOpacity,
        _blinkDimmer,
        _shine,
      ]),
      child: widget.child,
      builder: (context, child) {
        final theme = TdsTheme.of(context);
        return ClipRect(
          child: Stack(
            children: [
              if (_blinkVisible)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: TdsListRowBlinkPainter(
                        elapsed:
                            TdsListRowMotion.blinkEntryDuration * _blink.value,
                        opacity: _blinkOpacity.value,
                        dimmerOpacity: .04 * _blinkDimmer.value,
                        color: theme.color('blue500'),
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: _contentValue(_content.value),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme
                              .color('greyOpacity100')
                              .withValues(
                                alpha:
                                    theme.color('greyOpacity100').a *
                                    _touch.value,
                              ),
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
              if (_effect == _RowEffect.shine)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: TdsListRowShinePainter(
                        elapsed: _shine.duration! * _shine.value,
                        dark: _darkShine,
                        translateFromX: _shineFromX,
                        translateToX: _shineToX,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

// Record completed layout without triggering a rebuild. Reading RenderBox.size
// during didChangeDependencies is unsafe inside an ancestor LayoutBuilder; the
// last completed size also matches the source's pre-commit DOM measurement.
class _RecordRowSize extends SingleChildRenderObjectWidget {
  const _RecordRowSize({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRecordRowSize(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRecordRowSize renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderRecordRowSize extends RenderProxyBox {
  _RenderRecordRowSize(this.onSize);
  ValueChanged<Size> onSize;
  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}

class TdsListRowBlinkPainter extends CustomPainter {
  const TdsListRowBlinkPainter({
    required this.elapsed,
    required this.opacity,
    required this.color,
    this.dimmerOpacity,
  });
  final Duration elapsed;
  final double opacity;

  /// The dimmer's current CSS opacity, independent of the radial layer's exit.
  /// Omitted for standalone sampling of the uninterrupted source timeline.
  final double? dimmerOpacity;

  /// Live dimmer color. The source radial gradient resolves light blue500 once.
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 * TdsListRowMotion.blinkRadius(elapsed);
    if (radius > 0) {
      // CSS radial-gradient defaults to farthest-corner. Its 75% transparent
      // stop is relative to the square's diagonal, not the circle radius.
      final circle = Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: radius,
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(circle));
      canvas.drawRect(
        circle,
        Paint()
          ..shader = RadialGradient(
            colors: [
              TdsPalette.blue500.withValues(alpha: .1 * opacity),
              TdsPalette.blue500.withValues(alpha: 0),
            ],
            stops: const [0, .75],
            radius: math.sqrt2 / 2,
          ).createShader(circle),
      );
      canvas.restore();
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = color.withValues(
          alpha:
              dimmerOpacity ??
              .04 * TdsListRowMotion.blinkDimmer(elapsed) * opacity,
        ),
    );
  }

  @override
  bool shouldRepaint(TdsListRowBlinkPainter old) =>
      elapsed != old.elapsed ||
      opacity != old.opacity ||
      dimmerOpacity != old.dimmerOpacity ||
      color != old.color;
}

class TdsListRowShinePainter extends CustomPainter {
  const TdsListRowShinePainter({
    required this.elapsed,
    required this.dark,
    this.translateFromX,
    this.translateToX,
  });
  final Duration elapsed;
  final bool dark;
  final double? translateFromX, translateToX;

  Rect boundsForSize(Size size) => TdsListRowMotion.shineRect(
    size,
    elapsed,
    dark: dark,
    translateFromX: translateFromX,
    translateToX: translateToX,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = boundsForSize(size);
    final opacity = TdsListRowMotion.shineOpacity(elapsed, dark: dark);
    // CSS angles run clockwise from up. Gradient length is the projection of
    // all four corners, not the bounding diagonal (Flutter's default).
    final angle = (dark ? 135 : 140) * math.pi / 180;
    final axis = Offset(math.sin(angle), -math.cos(angle));
    final length = rect.width * axis.dx.abs() + rect.height * axis.dy.abs();
    final half = axis * (length / 2);
    final color = dark ? const Color(0xff17171c) : const Color(0xffffffff);
    final colors = dark
        ? [
            color.withValues(alpha: .7 * opacity),
            color.withValues(alpha: 0),
            color.withValues(alpha: .7 * opacity),
          ]
        : [
            color.withValues(alpha: 0),
            color.withValues(alpha: .8),
            color.withValues(alpha: 0),
          ];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(
            -2 * half.dx / rect.width,
            -2 * half.dy / rect.height,
          ),
          end: Alignment(2 * half.dx / rect.width, 2 * half.dy / rect.height),
          colors: colors,
          stops: dark ? const [.4, .5, .6] : const [.3, .5, .7],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(TdsListRowShinePainter old) =>
      elapsed != old.elapsed ||
      dark != old.dark ||
      translateFromX != old.translateFromX ||
      translateToX != old.translateToX;
}
