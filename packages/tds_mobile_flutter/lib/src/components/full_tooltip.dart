import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/line_box.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/word_break.dart';

class TdsFullTooltip extends StatefulWidget {
  const TdsFullTooltip({
    required this.child,
    required this.message,
    this.open,
    this.floating = false,
    this.duration = const Duration(milliseconds: 2600),
    this.placement,
    this.messageAlign = TextAlign.center,
    this.offset,
    this.anchorOverlapped = false,
    this.anchorPositionByRatio,
    this.onClose,
    this.onClickOutside,
    super.key,
  }) : assert(
         placement == null ||
             placement == TdsOverlayPlacement.top ||
             placement == TdsOverlayPlacement.bottom,
       );
  final Widget child, message;
  final bool? open;
  final bool floating, anchorOverlapped;
  final Duration duration;
  // The original que only renders children for an explicit top/bottom. Floating
  // Oue defaults to bottom, but its visual g_ still receives undefined.
  final TdsOverlayPlacement? placement;
  final TextAlign messageAlign;
  final double? offset, anchorPositionByRatio;
  final VoidCallback? onClose, onClickOutside;
  @override
  State<TdsFullTooltip> createState() => _TdsFullTooltipState();
}

class _TdsFullTooltipState extends State<TdsFullTooltip> {
  bool internal = true;
  late bool present = open;
  late TdsFullTooltip retained = widget;
  int generation = 0;
  int treeGeneration = 0;
  bool unwrappedAfterReopen = false;
  Timer? timer;
  VoidCallback? initialOutside;
  bool get open => widget.open ?? internal;

  void pointer(PointerEvent event) {
    // Due installs its initial callback once. Xue does not pass interactive, so
    // every document pointerdown counts, even inside the tooltip or when closed.
    if (event is PointerDownEvent) initialOutside?.call();
  }

  void schedule() {
    timer?.cancel();
    if (!open || (widget.open != null && widget.onClose == null)) return;
    timer = Timer(
      widget.duration.isNegative ? Duration.zero : widget.duration,
      () {
        if (!mounted) return;
        if (widget.open == null) {
          // Sat overrides the caller's onClose with its internal state setter.
          setState(() => internal = false);
        } else {
          widget.onClose?.call();
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    initialOutside = widget.onClickOutside;
    GestureBinding.instance.pointerRouter.addGlobalRoute(pointer);
    schedule();
  }

  @override
  void didUpdateWidget(TdsFullTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged = (oldWidget.open == null) != (widget.open == null);
    if (modeChanged) {
      // Switching Sat/Xue in React remounts the subtree.
      internal = true;
      initialOutside = widget.onClickOutside;
      treeGeneration++;
    }
    if (modeChanged || oldWidget.floating != widget.floating) {
      // que/Yue are different component types, not an animated layout change.
      generation++;
      present = open;
      unwrappedAfterReopen = false;
    } else if (open && oldWidget.open == false) {
      // eo remounts an exiting child when its key reappears. Restart its local
      // effects, message measurements and delays even during a retained exit.
      // eo leaves this key in its exiting Set. An interrupted reopen renders
      // the raw child without sT, so the NEXT close has no retained exit.
      unwrappedAfterReopen = present;
      generation++;
    } else if (!open && oldWidget.open == true && unwrappedAfterReopen) {
      present = false;
      unwrappedAfterReopen = false;
    }
    if (open) {
      present = true;
      retained = widget;
    }
    if (widget.open == null ||
        modeChanged ||
        oldWidget.floating != widget.floating ||
        oldWidget.open != widget.open ||
        oldWidget.duration != widget.duration ||
        oldWidget.onClose != widget.onClose) {
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(pointer);
    super.dispose();
  }

  void removed(int owner) {
    if (mounted && !open && generation == owner) {
      setState(() {
        present = false;
        unwrappedAfterReopen = false;
      });
    }
  }

  Widget surface(BuildContext context) {
    final owner = generation;
    // eo keeps the previous React element while it exits. Closing and changing
    // the message/placement in one render must not replace the departing body.
    final body = retained;
    return _FullTooltipMotion(
      key: ValueKey(('full-tooltip-body', owner)),
      open: open,
      floating: body.floating,
      overlapped: body.anchorOverlapped,
      placement: body.placement,
      onRemoved: () => removed(owner),
      builder: (context, alpha) => TdsFullTooltipSurface._observed(
        message: body.message,
        placement: body.placement,
        messageAlign: body.messageAlign,
        floating: body.floating,
        alpha: alpha,
        anchorPositionByRatio: body.anchorPositionByRatio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.floating) {
      return KeyedSubtree(
        key: ValueKey(treeGeneration),
        child: TdsAnchoredOverlay(
          open: present,
          placement: widget.placement ?? TdsOverlayPlacement.bottom,
          margin: 0,
          shiftIntoView: false,
          offset: widget.offset ?? (widget.anchorOverlapped ? -12 : 0),
          overlayBuilder: (context, _) => SizedBox(
            width: MediaQuery.sizeOf(context).width,
            child: surface(context),
          ),
          child: widget.child,
        ),
      );
    }
    return KeyedSubtree(
      key: ValueKey(treeGeneration),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.placement == TdsOverlayPlacement.bottom) widget.child,
          if (present) surface(context),
          if (widget.placement == TdsOverlayPlacement.top) widget.child,
        ],
      ),
    );
  }
}

class _FullTooltipMotion extends StatefulWidget {
  const _FullTooltipMotion({
    required this.open,
    required this.floating,
    required this.overlapped,
    required this.placement,
    required this.onRemoved,
    required this.builder,
    super.key,
  });
  final bool open, floating, overlapped;
  final TdsOverlayPlacement? placement;
  final VoidCallback onRemoved;
  final Widget Function(BuildContext, double) builder;
  @override
  State<_FullTooltipMotion> createState() => _FullTooltipMotionState();
}

class _FullTooltipMotionState extends State<_FullTooltipMotion>
    with TickerProviderStateMixin {
  late final clock = AnimationController(vsync: this)
    ..addStatusListener(status);
  late final clip = _FullTooltipHeightMotion(this, status);
  late final footprint = _FullTooltipHeightMotion(this, status);
  Timer? resizeTimer;
  double? measuredHeight;

  double after(double delay, double duration, Curve curve) {
    final elapsed = clock.value * clock.duration!.inMicroseconds / 1000;
    if (elapsed <= delay + .000001) return 0;
    if (elapsed >= delay + duration - .000001) return 1;
    return curve.transform((elapsed - delay) / duration);
  }

  double get outerOpacity => widget.floating
      ? 1
      : widget.open
      ? after(500, 200, TdsMotion.out)
      : 1 - after(0, 200, TdsMotion.out);
  double get ink => widget.open
      ? after(widget.floating ? 500 : 700, 200, TdsMotion.out)
      : 1 - after(0, 200, TdsMotion.out);
  void start() {
    clock.duration = widget.open
        ? widget.floating
              ? const Duration(milliseconds: 700)
              : const Duration(milliseconds: 900)
        : const Duration(milliseconds: 200);
    clock.forward(from: 0);
  }

  void measure(double height) {
    if (!mounted || !widget.open) return;
    resizeTimer?.cancel();
    if (measuredHeight == null) {
      // The first layout is the synchronous d_ measurement. Later observer
      // notifications are debounced independently from g_'s message observer.
      measuredHeight = height;
      clip.initialize(height);
      footprint.initialize(height - (widget.overlapped ? 12 : 0));
      return;
    }
    resizeTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted || !widget.open || measuredHeight == height) return;
      measuredHeight = height;
      clip.enter(height);
      footprint.enter(height - (widget.overlapped ? 12 : 0));
    });
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(_FullTooltipMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) {
      resizeTimer?.cancel();
      if (!widget.open) {
        clip.exit();
        footprint.exit();
      }
      start();
    } else if (widget.open &&
        oldWidget.overlapped != widget.overlapped &&
        measuredHeight != null) {
      // Cat's second effect depends on s; its clip effect does not. Changing
      // overlap restarts only the document-flow spacer after a 400ms hold.
      footprint.enter(measuredHeight! - (widget.overlapped ? 12 : 0));
    }
  }

  void status(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        !widget.open &&
        clock.isCompleted &&
        (widget.floating ||
            (clip.controller.isCompleted &&
                footprint.controller.isCompleted))) {
      widget.onRemoved();
    }
  }

  @override
  void dispose() {
    resizeTimer?.cancel();
    clock.dispose();
    clip.controller.dispose();
    footprint.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([clock, clip.controller, footprint.controller]),
    builder: (context, _) {
      final content = Opacity(
        opacity: outerOpacity.clamp(0, 1),
        child: widget.builder(context, ink),
      );
      return widget.floating
          ? content
          : _FullTooltipReveal(
              clipHeight: clip.value,
              footprintHeight: footprint.value,
              onHeight: measure,
              translation:
                  widget.overlapped &&
                      widget.placement == TdsOverlayPlacement.bottom
                  ? -12
                  : 0,
              child: content,
            );
    },
  );
}

/// GSAP's defaultImmediateRender=false leaves the previous height in place
/// during delay, then jumps to the explicit from:0. Clip and flow spacer are
/// separate source rallies. GSAP CSS height values are rounded to whole pixels.
class _FullTooltipHeightMotion {
  _FullTooltipHeightMotion(TickerProvider vsync, AnimationStatusListener status)
    : controller = AnimationController(
        vsync: vsync,
        duration: TdsMotion.basic.duration + const Duration(milliseconds: 400),
      )..addStatusListener(status) {
    controller.forward();
  }
  final AnimationController controller;
  double target = 0, from = 0, hold = 0;
  double delay = 400;
  double get value {
    final elapsed =
        controller.value * controller.duration!.inMicroseconds / 1000;
    final duration = TdsMotion.basic.duration.inMicroseconds / 1000;
    if (elapsed <= delay + .000001 && delay > 0) return hold;
    if (elapsed >= delay + duration - .000001) return target;
    final t = ((elapsed - delay) / duration).clamp(0.0, 1.0);
    return (from + (target - from) * TdsMotion.basic.transform(t))
        .roundToDouble();
  }

  void initialize(double height) => target = height;
  void enter(double height) {
    hold = value;
    from = 0;
    target = height;
    delay = 400;
    controller.duration =
        TdsMotion.basic.duration + const Duration(milliseconds: 400);
    controller.forward(from: 0);
  }

  void exit() {
    from = value;
    target = 0;
    delay = 0;
    controller.duration = TdsMotion.basic.duration;
    controller.forward(from: 0);
  }
}

/// Native counterpart of g_. Original static (not adaptive) teal colors and
/// mat's exact two-contour silhouette are shared by relative/floating variants.
class TdsFullTooltipSurface extends StatefulWidget {
  const TdsFullTooltipSurface({
    required this.message,
    this.placement,
    this.floating = false,
    this.alpha = 1,
    this.anchorPositionByRatio,
    this.messageAlign = TextAlign.center,
    super.key,
  }) : _observeResize = false;
  const TdsFullTooltipSurface._observed({
    required this.message,
    required this.placement,
    required this.floating,
    required this.alpha,
    required this.anchorPositionByRatio,
    required this.messageAlign,
  }) : _observeResize = true;
  final Widget message;
  final TdsOverlayPlacement? placement;
  final bool floating;
  final double alpha;
  final double? anchorPositionByRatio;
  final TextAlign messageAlign;
  final bool _observeResize;
  @override
  State<TdsFullTooltipSurface> createState() => _TdsFullTooltipSurfaceState();
}

class _TdsFullTooltipSurfaceState extends State<TdsFullTooltipSurface> {
  double? messageHeight;
  Timer? resizeTimer;

  void measure(double height) {
    if (!mounted || !widget._observeResize) return;
    resizeTimer?.cancel();
    if (messageHeight == null) {
      messageHeight = height;
    } else {
      resizeTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && messageHeight != height) {
          setState(() => messageHeight = height);
        }
      });
    }
  }

  @override
  void dispose() {
    resizeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final placement = widget.placement;
    final alpha = widget.alpha;
    final width = MediaQuery.sizeOf(context).width;
    final clipper = TdsFullTooltipClipper(
      anchor: 8 + (widget.anchorPositionByRatio ?? .5) * (width - 54),
      viewportWidth: width,
      top: placement == TdsOverlayPlacement.top,
    );
    final style = TdsTheme.of(context)
        .textStyle(
          typography: TdsTypography.t6,
          fontWeight: TdsFontWeight.bold,
          color: TdsPalette.teal600,
        )
        .copyWith(height: 1.35);
    final line = (style.fontSize! * 1.35 * 64).floorToDouble() / 64;
    final ascent = (style.fontSize! * 2030 / 2048).round(),
        descent = (style.fontSize! * 534 / 2048).round();
    final text =
        message is Text && message.data != null && message.style == null
        ? TdsLineBox(
            lineHeight: line,
            baseline: (ascent + (line - ascent - descent) / 2).floorToDouble(),
            child: TdsKeepAllText.from(
              Text(
                message.data!,
                style: style,
                textAlign: widget.messageAlign,
                textScaler: TextScaler.noScaling,
              ),
            ),
          )
        : DefaultTextStyle(
            style: style,
            textAlign: widget.messageAlign,
            child: message,
          );
    return Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: clipper,
            child: ColoredBox(
              color: TdsPalette.teal400.withValues(alpha: .15 * alpha),
            ),
          ),
        ),
        if (widget.floating)
          Positioned.fill(
            child: ClipPath(
              clipper: clipper,
              child: Opacity(
                opacity: alpha,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        _FullTooltipMessageBox(
          placement: placement,
          messageHeight: widget._observeResize ? messageHeight : null,
          onHeight: widget._observeResize ? measure : null,
          child: Opacity(opacity: alpha, child: text),
        ),
      ],
    );
  }
}

class TdsFullTooltipClipper extends CustomClipper<Path> {
  const TdsFullTooltipClipper({
    required this.anchor,
    required this.viewportWidth,
    required this.top,
  });
  final double anchor, viewportWidth;
  final bool top;
  @override
  Path getClip(Size size) {
    final e = anchor;
    final path = Path()
      ..moveTo(17.8504945 + e, .995682408)
      ..cubicTo(
        18.5809318 + e,
        .41643879,
        19.6188374 + e,
        .41643879,
        20.3492747 + e,
        .995682408,
      )
      ..lineTo(30.8242648 + e, 9.30244762)
      ..cubicTo(
        32.945491 + e,
        10.9845999,
        35.5732019 + e,
        11.9000448,
        38.2804583 + e,
        11.9000448,
      )
      ..lineTo(46.0998846 + e, 11.9000448)
      ..lineTo(-8 + e, 11.9000448)
      ..lineTo(-.0806890684 + e, 11.9000448)
      ..cubicTo(
        2.62656729 + e,
        11.9000448,
        5.25427816 + e,
        10.9845999,
        7.37550439 + e,
        9.30244762,
      )
      ..lineTo(17.8504945 + e, .995682408)
      ..close()
      ..addRect(Rect.fromLTRB(0, 11.9, viewportWidth, size.height));
    if (!top) return path;
    return path.transform(
      (Matrix4.identity()
            ..translateByDouble(0, size.height, 0, 1)
            ..scaleByDouble(1, -1, 1, 1))
          .storage,
    );
  }

  @override
  bool shouldReclip(TdsFullTooltipClipper old) =>
      anchor != old.anchor ||
      viewportWidth != old.viewportWidth ||
      top != old.top;
}

class _FullTooltipMessageBox extends SingleChildRenderObjectWidget {
  const _FullTooltipMessageBox({
    required this.placement,
    required this.messageHeight,
    required this.onHeight,
    required super.child,
  });
  final TdsOverlayPlacement? placement;
  final double? messageHeight;
  final ValueChanged<double>? onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFullTooltipMessageBox(placement, messageHeight, onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFullTooltipMessageBox renderObject,
  ) => renderObject
    ..placement = placement
    ..messageHeight = messageHeight
    ..onHeight = onHeight;
}

class _RenderFullTooltipMessageBox extends RenderShiftedBox {
  _RenderFullTooltipMessageBox(
    this._placement,
    this._messageHeight,
    this.onHeight,
  ) : super(null);
  TdsOverlayPlacement? _placement;
  ValueChanged<double>? onHeight;
  double? _messageHeight, _last;
  bool scheduled = false;
  set messageHeight(double? value) {
    if (value != _messageHeight) {
      _messageHeight = value;
      markNeedsLayout();
    }
  }

  set placement(TdsOverlayPlacement? value) {
    if (value != _placement) {
      _placement = value;
      markNeedsLayout();
    }
  }

  BoxConstraints childConstraints(BoxConstraints c) =>
      BoxConstraints.tightFor(width: math.max(0, c.maxWidth - 48));
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final s = child!.getDryLayout(childConstraints(constraints));
    return constraints.constrain(
      Size(
        constraints.maxWidth,
        (_messageHeight ?? s.height.roundToDouble()) + 44,
      ),
    );
  }

  @override
  void performLayout() {
    child!.layout(childConstraints(constraints), parentUsesSize: true);
    final measured = child!.size.height.roundToDouble();
    if (measured != _last) {
      _last = measured;
      if (!scheduled && onHeight != null) {
        scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduled = false;
          if (attached) onHeight?.call(_last!);
        });
      }
    }
    size = constraints.constrain(
      Size(constraints.maxWidth, (_messageHeight ?? measured) + 44),
    );
    (child!.parentData! as BoxParentData).offset = Offset(
      24,
      (size.height - child!.size.height) / 2 +
          (_placement == TdsOverlayPlacement.top
              ? -6
              : _placement == TdsOverlayPlacement.bottom
              ? 6
              : 0),
    );
  }
}

class _FullTooltipReveal extends SingleChildRenderObjectWidget {
  const _FullTooltipReveal({
    required this.clipHeight,
    required this.footprintHeight,
    required this.onHeight,
    required this.translation,
    required super.child,
  });
  final double clipHeight, footprintHeight, translation;
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFullTooltipReveal(
        clipHeight,
        footprintHeight,
        translation,
        onHeight,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFullTooltipReveal renderObject,
  ) => renderObject
    ..onHeight = onHeight
    ..update(clipHeight, footprintHeight, translation);
}

class _RenderFullTooltipReveal extends RenderShiftedBox {
  _RenderFullTooltipReveal(
    this.clipHeight,
    this.footprintHeight,
    this.translation,
    this.onHeight,
  ) : super(null);
  double clipHeight, footprintHeight, translation;
  ValueChanged<double> onHeight;
  double? _last;
  bool scheduled = false;
  void update(double next, double footprint, double shift) {
    if (next == clipHeight &&
        footprint == footprintHeight &&
        shift == translation) {
      return;
    }
    clipHeight = next;
    footprintHeight = footprint;
    translation = shift;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final s = child!.getDryLayout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
    );
    return constraints.constrain(Size(s.width, math.max(0, footprintHeight)));
  }

  @override
  void performLayout() {
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    if (_last != child!.size.height) {
      _last = child!.size.height;
      if (!scheduled) {
        scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduled = false;
          if (attached) onHeight(_last!);
        });
      }
    }
    size = constraints.constrain(
      Size(child!.size.width, math.max(0, footprintHeight)),
    );
    (child!.parentData! as BoxParentData).offset = Offset(0, translation);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(0, translation, size.width, math.max(0, clipHeight)),
      super.paint,
    );
  }

  @override
  Rect describeApproximatePaintClip(RenderObject child) =>
      Rect.fromLTWH(0, translation, size.width, math.max(0, clipHeight));

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!Rect.fromLTWH(
      0,
      translation,
      size.width,
      math.max(0, clipHeight),
    ).contains(position)) {
      return false;
    }
    return super.hitTestChildren(result, position: position);
  }
}
