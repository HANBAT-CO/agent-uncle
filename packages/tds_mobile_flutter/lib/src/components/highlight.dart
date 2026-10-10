import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/line_box.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'text.dart';

enum TdsHighlightXAlignment { left, center, right }

enum TdsHighlightYAlignment { top, bottom }

class TdsHighlight extends StatefulWidget {
  const TdsHighlight({
    required this.child,
    required this.open,
    this.padding = 0,
    this.message,
    this.messageColor,
    this.messageXAlignment,
    this.messageYAlignment,
    this.delay = Duration.zero,
    this.onClick,
    this.onClose,
    this.onExited,
    this.closeAriaLabel = '닫기',
    super.key,
  });
  final Widget child;
  final bool open;
  final double padding;
  final Widget? message;
  final Color? messageColor;
  final TdsHighlightXAlignment? messageXAlignment;
  final TdsHighlightYAlignment? messageYAlignment;
  final Duration delay;
  final VoidCallback? onClick, onClose, onExited;
  final String closeAriaLabel;
  @override
  State<TdsHighlight> createState() => _TdsHighlightState();
}

class _TdsHighlightState extends State<TdsHighlight> {
  final anchor = GlobalKey();
  final portal = OverlayPortalController();
  final focus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  Timer? delay, restoreFocus;
  FocusNode? previousFocus;
  ScrollPosition? scroll;
  double scrollOffset = 0;
  Rect? rect;
  TdsHighlight? snapshot;
  bool visible = false;
  int generation = 0;
  // Pqe's click callback is memoized with [], not a latest-ref callback.
  late final VoidCallback? onClick, onClose;

  @override
  void initState() {
    super.initState();
    onClick = widget.onClick;
    onClose = widget.onClose;
    if (widget.open) scheduleOpen();
  }

  void scheduleOpen() {
    final ticket = ++generation, options = widget;
    delay?.cancel();
    restoreFocus?.cancel();
    previousFocus = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.open || ticket != generation) return;
      delay = Timer(options.delay, () {
        if (!mounted || !widget.open || ticket != generation) return;
        final box = anchor.currentContext?.findRenderObject(),
            overlay = Overlay.of(context).context.findRenderObject();
        if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) return;
        scroll?.removeListener(scrolled);
        scroll = Scrollable.maybeOf(context)?.position;
        scrollOffset = scroll?.pixels ?? 0;
        scroll?.addListener(scrolled);
        setState(() {
          rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
          snapshot = options;
          visible = true;
        });
        portal.show();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && visible) focus.requestFocus();
        });
      });
    });
  }

  void scrolled() {
    if (mounted && portal.isShowing) setState(() {});
  }

  void close() {
    onClick?.call();
    onClose?.call();
    // h(null) hides even if the owner leaves open=true. A false→true edge is
    // required to run the original measuring effect again.
    if (mounted && visible) setState(() => visible = false);
  }

  @override
  void didUpdateWidget(TdsHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    if (widget.open) {
      scheduleOpen();
    } else {
      ++generation;
      delay?.cancel();
      visible = false;
      restoreFocus?.cancel();
      final target = previousFocus;
      restoreFocus = Timer(const Duration(milliseconds: 500), () {
        if (mounted &&
            !widget.open &&
            target?.context != null &&
            target!.canRequestFocus) {
          target.requestFocus();
        }
      });
    }
  }

  void removed() {
    if (!mounted || visible) return;
    portal.hide();
    scroll?.removeListener(scrolled);
    scroll = null;
  }

  @override
  void dispose() {
    delay?.cancel();
    restoreFocus?.cancel();
    scroll?.removeListener(scrolled);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    child: KeyedSubtree(key: anchor, child: widget.child),
    overlayChildBuilder: (context) {
      final options = snapshot!;
      return Positioned.fill(
        child: BlockSemantics(
          child: PopScope(
            canPop: false,
            child: FocusScope(
              node: focus,
              child: Focus(
                skipTraversal: true,
                onKeyEvent: (_, event) =>
                    event.logicalKey == LogicalKeyboardKey.escape
                    ? KeyEventResult.handled
                    : KeyEventResult.ignored,
                child: Listener(
                  // The source marks the underlying app inert, including the target.
                  // The hole is visual, not interactive. Also consume wheel signals.
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (event) => GestureBinding
                      .instance
                      .pointerSignalResolver
                      .register(event, (_) {}),
                  child: TdsHighlightUI(
                    open: visible,
                    rect: rect!.shift(
                      Offset(
                        0,
                        scrollOffset - (scroll?.pixels ?? scrollOffset),
                      ),
                    ),
                    padding: options.padding,
                    message: options.message,
                    messageColor: options.messageColor,
                    messageXAlignment: options.messageXAlignment,
                    messageYAlignment: options.messageYAlignment,
                    closeAriaLabel: widget.closeAriaLabel,
                    onClick: close,
                    onExited: options.onExited,
                    onExitComplete: removed,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Wx/sne/tne: independent dimmer, cutout and message animation timelines.
/// [open] and [onExitComplete] provide native AnimatePresence ownership. The
/// source [onExited] fires when opacity finishes, before the slow cutout exit.
class TdsHighlightUI extends StatefulWidget {
  const TdsHighlightUI({
    required this.rect,
    this.open = true,
    this.padding = 0,
    this.message,
    this.messageColor,
    this.messageXAlignment,
    this.messageYAlignment,
    this.onClick,
    this.onExited,
    this.onExitComplete,
    this.closeAriaLabel = '닫기',
    super.key,
  });
  final Rect rect;
  final bool open;
  final double padding;
  final Widget? message;
  final Color? messageColor;
  final TdsHighlightXAlignment? messageXAlignment;
  final TdsHighlightYAlignment? messageYAlignment;
  final VoidCallback? onClick, onExited, onExitComplete;
  final String closeAriaLabel;
  @override
  State<TdsHighlightUI> createState() => _TdsHighlightUIState();
}

class _TdsHighlightUIState extends State<TdsHighlightUI>
    with TickerProviderStateMixin {
  late final opacity = AnimationController(
    vsync: this,
    duration: TdsMotion.basic.duration,
  )..addStatusListener(opacityStatus);
  late final cutout = AnimationController(
    vsync: this,
    duration: TdsMotion.basic.duration,
  )..addStatusListener(cutoutStatus);
  late final messageOpacity = AnimationController(
    vsync: this,
    duration: TdsMotion.quick.duration,
  );
  late final messageMotion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  double opacityFrom = 0, opacityTo = 1, messageFrom = 0, messageTo = 1;
  double? exitLength;
  Offset scaleStart = const Offset(.9, .9), radiusStart = const Offset(16, 16);
  bool initialized = false, reduced = false;
  Rect hole = Rect.zero;
  Size viewport = Size.zero;

  double get alpha =>
      opacityFrom +
      (opacityTo - opacityFrom) * TdsMotion.basic.transform(opacity.value);
  double get messageAlpha =>
      messageFrom +
      (messageTo - messageFrom) *
          (widget.open ? TdsMotion.quick : TdsMotion.rapid).transform(
            messageOpacity.value,
          );
  double get cutoutProgress =>
      (widget.open ? TdsMotion.basic : TdsMotion.slow).transform(cutout.value);
  Offset get scaleTarget => exitLength == null || reduced
      ? const Offset(1, 1)
      : Offset(
          hole.width == 0 ? 1 : exitLength! / hole.width,
          hole.height == 0 ? 1 : exitLength! / hole.height,
        );
  Offset get radiusTarget => exitLength == null || reduced
      ? const Offset(16, 16)
      : Offset(hole.width, hole.height);
  Offset get scales => Offset.lerp(scaleStart, scaleTarget, cutoutProgress)!;
  Offset get radii => Offset.lerp(radiusStart, radiusTarget, cutoutProgress)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (initialized) return;
    initialized = true;
    scaleStart = Offset(reduced ? 1 : .9, reduced ? 1 : .9);
    opacityTo = widget.open ? 1 : 0;
    messageTo = opacityTo;
    if (widget.open) {
      opacity.forward();
      cutout.forward();
      messageOpacity.forward();
      messageMotion.forward();
    }
  }

  @override
  void didUpdateWidget(TdsHighlightUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open == widget.open) return;
    // Sample the OLD curves before retargeting to avoid interruption jumps.
    final oldProgress = (oldWidget.open ? TdsMotion.basic : TdsMotion.slow)
        .transform(cutout.value);
    scaleStart = Offset.lerp(scaleStart, scaleTarget, oldProgress)!;
    radiusStart = Offset.lerp(radiusStart, radiusTarget, oldProgress)!;
    opacityFrom = alpha;
    messageFrom +=
        (messageTo - messageFrom) *
        (oldWidget.open ? TdsMotion.quick : TdsMotion.rapid).transform(
          messageOpacity.value,
        );
    opacityTo = widget.open ? 1 : 0;
    messageTo = opacityTo;
    exitLength = widget.open
        ? null
        : 2 * (hole.width > hole.height ? viewport.width : viewport.height);
    opacity.forward(from: 0);
    cutout.duration = widget.open || reduced
        ? TdsMotion.basic.duration
        : TdsMotion.slow.duration;
    cutout.forward(from: 0);
    messageOpacity.duration = widget.open
        ? TdsMotion.quick.duration
        : TdsMotion.rapid.duration;
    messageOpacity.forward(from: 0);
  }

  void opacityStatus(AnimationStatus value) {
    if (value == AnimationStatus.completed && !widget.open) {
      widget.onExited?.call();
    }
  }

  void cutoutStatus(AnimationStatus value) {
    if (value == AnimationStatus.completed && !widget.open) {
      widget.onExitComplete?.call();
    }
  }

  @override
  void dispose() {
    opacity.dispose();
    cutout.dispose();
    messageOpacity.dispose();
    messageMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = TdsTheme.of(context);
      viewport = constraints.biggest;
      hole = widget.rect.inflate(widget.padding);
      // Wx clamps negative origins only when padding is nonzero.
      if (widget.padding != 0) {
        hole = Rect.fromLTWH(
          math.max(0, hole.left),
          math.max(0, hole.top),
          hole.width,
          hole.height,
        );
      }
      if (hole.width >= viewport.width - 20) {
        hole = Rect.fromLTWH(
          10,
          hole.top,
          math.max(0, viewport.width - 20),
          hole.height,
        );
      }
      final above =
          (widget.messageYAlignment ??
              (hole.center.dy >= viewport.height / 2
                  ? TdsHighlightYAlignment.top
                  : TdsHighlightYAlignment.bottom)) ==
          TdsHighlightYAlignment.top;
      final x =
          widget.messageXAlignment ??
          ((hole.center.dx - viewport.width / 2).abs() <= 10
              ? TdsHighlightXAlignment.center
              : hole.center.dx < viewport.width / 2
              ? TdsHighlightXAlignment.left
              : TdsHighlightXAlignment.right);
      return AnimatedBuilder(
        animation: Listenable.merge([
          opacity,
          cutout,
          messageOpacity,
          messageMotion,
        ]),
        builder: (context, _) {
          final scale = scales, radius = radii;
          final drawnHole = RRect.fromRectXY(
            Rect.fromCenter(
              center: hole.center,
              width: hole.width * scale.dx,
              height: hole.height * scale.dy,
            ),
            radius.dx * scale.dx,
            radius.dy * scale.dy,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onTap: widget.open ? widget.onClick : null,
                  child: CustomPaint(
                    painter: _HighlightPainter(
                      drawnHole,
                      RRect.fromRectAndRadius(hole, const Radius.circular(16)),
                      theme.isDark
                          ? const Color.fromRGBO(33, 33, 38, .87)
                          : theme.color('greyOpacity700'),
                      alpha.clamp(0, 1),
                      theme.platform.os == TdsOS.android,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              if (widget.message != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: above ? null : hole.bottom + 12,
                  bottom: above ? viewport.height - hole.top + 12 : null,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (alpha * messageAlpha).clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          reduced
                              ? 0
                              : _messageOffset(messageMotion.value, above),
                        ),
                        child: _HighlightMessageLayout(
                          centerX: hole.center.dx,
                          above: above,
                          alignment: x,
                          color: widget.messageColor ?? const Color(0xffffffff),
                          child: widget.message!,
                        ),
                      ),
                    ),
                  ),
                ),
              // Visually hidden native close button, independent of visual opacity.
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: TdsPressable(
                  enabled: widget.open,
                  activateOnEnterDown: true,
                  semanticLabel: widget.closeAriaLabel,
                  onPressed: widget.onClick,
                  builder: (_, _, _, _) => const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

double _messageOffset(double progress, bool above) {
  final seconds = progress * 2.2, sign = above ? 1.0 : -1.0;
  if (seconds <= .6) {
    return sign * 10 * TdsMotion.out.transform((seconds / .6).clamp(0, 1));
  }
  if (seconds <= 1.4) {
    return sign *
        (10 - 20 * TdsMotion.out.transform(((seconds - .6) / .8).clamp(0, 1)));
  }
  return sign *
      (-10 + 20 * TdsMotion.out.transform(((seconds - 1.4) / .8).clamp(0, 1)));
}

class _HighlightMessageLayout extends StatelessWidget {
  const _HighlightMessageLayout({
    required this.centerX,
    required this.above,
    required this.alignment,
    required this.color,
    required this.child,
  });
  final double centerX;
  final bool above;
  final TdsHighlightXAlignment alignment;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final align = switch (alignment) {
      TdsHighlightXAlignment.left => TextAlign.left,
      TdsHighlightXAlignment.center => TextAlign.center,
      TdsHighlightXAlignment.right => TextAlign.right,
    };
    final message = DefaultTextStyle(
      textAlign: align,
      style: TdsTheme.of(context).textStyle(
        typography: TdsTypography.t6,
        fontWeight: TdsFontWeight.bold,
        color: color,
      ),
      child:
          child is Text &&
              (child as Text).data != null &&
              (child as Text).style == null
          ? TdsHighlightMessage(
              (child as Text).data!,
              color: color,
              textAlign: align,
            )
          : child,
    );
    final arrow = SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: centerX - 12,
            top: 0,
            child: Transform.rotate(
              angle: above ? math.pi : 0,
              child: TdsAssetIcon(
                name: 'icon-arrow-up-sidebar-mono',
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    final positionedMessage = alignment == TdsHighlightXAlignment.center
        ? Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(centerX, 0),
              child: FractionalTranslation(
                translation: const Offset(-.5, 0),
                child: message,
              ),
            ),
          )
        : SizedBox(width: double.infinity, child: message);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: above ? [positionedMessage, arrow] : [arrow, positionedMessage],
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(
    this.hole,
    this.hitHole,
    this.color,
    this.opacity,
    this.android,
  );
  final RRect hole, hitHole;
  final Color color;
  final double opacity;
  final bool android;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    if (android) {
      canvas.drawRRect(
        hole.shift(const Offset(0, 1)),
        Paint()
          // ine's feMerge references offsetblur directly, bypassing the
          // intervening feComponentTransfer(slope=.1). The blur is full alpha.
          ..color = const Color(0xff000000)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3)
          ..blendMode = BlendMode.dstOut,
      );
    }
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.dstOut);
    canvas.restore();
  }

  @override
  bool hitTest(Offset position) => !hitHole.contains(position);
  @override
  bool shouldRepaint(_HighlightPainter old) =>
      hole != old.hole ||
      hitHole != old.hitHole ||
      color != old.color ||
      opacity != old.opacity ||
      android != old.android;
}

class TdsHighlightMessage extends TdsText {
  const TdsHighlightMessage(
    super.text, {
    super.color,
    super.textAlign,
    super.key,
  }) : super(typography: TdsTypography.t6, fontWeight: TdsFontWeight.bold);
  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context);
    final resolved = TdsTheme.of(context).textStyle(
      typography: typography,
      fontWeight: fontWeight,
      color: color ?? inherited.style.color,
    );
    final lineHeight =
        (resolved.fontSize! * resolved.height! * 64).floorToDouble() / 64;
    final ascent = (resolved.fontSize! * 2030 / 2048).round(),
        descent = (resolved.fontSize! * 534 / 2048).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TdsLineBox(
        lineHeight: lineHeight,
        baseline: (ascent + (lineHeight - ascent - descent) / 2)
            .floorToDouble(),
        child: Text(
          data,
          style: resolved,
          textAlign: textAlign ?? inherited.textAlign,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
