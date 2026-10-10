import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../foundation/portal.dart';
import '../foundation/motion.dart';
import '../foundation/line_box.dart';
import '../foundation/theme.dart';
import 'button.dart';

enum TdsBottomCTAAnimation { fade, scale, slide }

/// Native duration counterpart of `showAfterDelay` (source delay is seconds).
@immutable
class TdsBottomCTADelayedEntrance {
  const TdsBottomCTADelayedEntrance({
    required this.delay,
    required this.animation,
  });
  final Duration delay;
  final TdsBottomCTAAnimation animation;
}

class TdsBottomCTA extends StatefulWidget {
  const TdsBottomCTA({
    required this.child,
    this.disabledChild,
    this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.inert = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.color = TdsButtonColor.primary,
    this.variant = TdsButtonVariant.fill,
    this.topAccessory,
    this.bottomAccessory,
    this.background = true,
    this.backgroundColor,
    this.hasSafeAreaPadding = true,
    this.hasPaddingBottom = true,
    this.fixed = false,
    this.takeSpace,
    this.fixedAboveKeyboard = true,
    this.show = true,
    this.hideOnScroll = false,
    this.hideOnScrollDistanceThreshold = 1,
    this.scrollController,
    this.showAfterDelay,
    super.key,
  }) : leftButton = null,
       rightButton = null,
       _double = false,
       assert(hideOnScrollDistanceThreshold >= 0);

  const TdsBottomCTA.single({
    required Widget child,
    Widget? disabledChild,
    VoidCallback? onPressed,
    bool disabled = false,
    bool loading = false,
    bool inert = false,
    FocusNode? focusNode,
    bool autofocus = false,
    String? semanticLabel,
    TdsButtonColor color = TdsButtonColor.primary,
    TdsButtonVariant variant = TdsButtonVariant.fill,
    Widget? topAccessory,
    Widget? bottomAccessory,
    bool background = true,
    Color? backgroundColor,
    bool hasSafeAreaPadding = true,
    bool hasPaddingBottom = true,
    bool fixed = false,
    bool? takeSpace,
    bool fixedAboveKeyboard = true,
    bool show = true,
    bool hideOnScroll = false,
    double hideOnScrollDistanceThreshold = 1,
    ScrollController? scrollController,
    TdsBottomCTADelayedEntrance? showAfterDelay,
    Key? key,
  }) : this(
         child: child,
         disabledChild: disabledChild,
         onPressed: onPressed,
         disabled: disabled,
         loading: loading,
         inert: inert,
         focusNode: focusNode,
         autofocus: autofocus,
         semanticLabel: semanticLabel,
         color: color,
         variant: variant,
         topAccessory: topAccessory,
         bottomAccessory: bottomAccessory,
         background: background,
         backgroundColor: backgroundColor,
         hasSafeAreaPadding: hasSafeAreaPadding,
         hasPaddingBottom: hasPaddingBottom,
         fixed: fixed,
         takeSpace: takeSpace,
         fixedAboveKeyboard: fixedAboveKeyboard,
         show: show,
         hideOnScroll: hideOnScroll,
         hideOnScrollDistanceThreshold: hideOnScrollDistanceThreshold,
         scrollController: scrollController,
         showAfterDelay: showAfterDelay,
         key: key,
       );

  const TdsBottomCTA.double({
    required this.leftButton,
    required this.rightButton,
    this.topAccessory,
    this.bottomAccessory,
    this.background = true,
    this.backgroundColor,
    this.hasSafeAreaPadding = true,
    this.hasPaddingBottom = true,
    this.fixed = false,
    this.takeSpace,
    // Double retains padding and does not rise above the keyboard by default.
    this.fixedAboveKeyboard = false,
    this.show = true,
    this.hideOnScroll = false,
    this.hideOnScrollDistanceThreshold = 1,
    this.scrollController,
    this.showAfterDelay,
    super.key,
  }) : child = null,
       disabledChild = null,
       onPressed = null,
       disabled = false,
       loading = false,
       inert = false,
       focusNode = null,
       autofocus = false,
       semanticLabel = null,
       color = TdsButtonColor.primary,
       variant = TdsButtonVariant.fill,
       _double = true,
       assert(hideOnScrollDistanceThreshold >= 0);

  final Widget? child, disabledChild, leftButton, rightButton;
  final Widget? topAccessory, bottomAccessory;
  final VoidCallback? onPressed;
  final bool disabled, loading, background, hasSafeAreaPadding;

  /// Native counterpart of the source container background CSS variable.
  final Color? backgroundColor;
  final bool inert, autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;
  final bool hasPaddingBottom, fixed, fixedAboveKeyboard, show, hideOnScroll;
  final bool _double;
  final bool? takeSpace;
  final double hideOnScrollDistanceThreshold;

  /// Explicit target, or root scroll notifications from TdsMobileProvider.
  final ScrollController? scrollController;
  final TdsBottomCTADelayedEntrance? showAfterDelay;
  final TdsButtonColor color;
  final TdsButtonVariant variant;
  @override
  State<TdsBottomCTA> createState() => _TdsBottomCTAState();
}

class _TdsBottomCTAState extends State<TdsBottomCTA> {
  ScrollNotificationObserverState? _observer;
  ScrollController? _scrollController;
  Timer? _scrollTimer;
  double _latestOffset = 0, _previousOffset = 0;
  bool? _scrollVisible;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScroll();
  }

  @override
  void didUpdateWidget(TdsBottomCTA oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) _scrollVisible = null;
    if (oldWidget.hideOnScroll != widget.hideOnScroll ||
        oldWidget.scrollController != widget.scrollController) {
      _scrollVisible = null;
      _attachScroll();
    }
  }

  void _attachScroll() {
    final controller = widget.hideOnScroll ? widget.scrollController : null;
    final observer = widget.hideOnScroll && controller == null
        ? ScrollNotificationObserver.maybeOf(context)
        : null;
    if (controller == _scrollController && observer == _observer) return;
    _detachScroll();
    _scrollController = controller;
    _observer = observer;
    controller?.addListener(_onControllerScroll);
    observer?.addListener(_onScrollNotification);
  }

  void _detachScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollController?.removeListener(_onControllerScroll);
    _observer?.removeListener(_onScrollNotification);
    _previousOffset = _latestOffset = 0;
  }

  void _onControllerScroll() {
    if (_scrollController!.hasClients) {
      _scheduleScroll(_scrollController!.offset);
    }
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return;
    }
    if (notification is ScrollUpdateNotification) {
      _scheduleScroll(notification.metrics.pixels);
    }
  }

  void _scheduleScroll(double offset) {
    _latestOffset = offset;
    if (_scrollTimer != null) return;
    _sampleScroll();
    // Source uses a 50ms leading/trailing throttle and a strict > threshold.
    _scrollTimer = Timer(const Duration(milliseconds: 50), () {
      _scrollTimer = null;
      _sampleScroll();
    });
  }

  void _sampleScroll() {
    if ((_latestOffset - _previousOffset).abs() <=
        widget.hideOnScrollDistanceThreshold) {
      return;
    }
    final visible = _latestOffset < _previousOffset;
    _previousOffset = _latestOffset;
    if (_scrollVisible != visible) setState(() => _scrollVisible = visible);
  }

  @override
  void dispose() {
    _detachScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), media = MediaQuery.of(context);
    final full = !widget._double && media.viewInsets.bottom > 0;
    final bottom = !widget.hasPaddingBottom || full
        ? 0.0
        : widget.hasSafeAreaPadding
        ? math.max(20.0, media.viewPadding.bottom)
        : 20.0;
    final surface = widget.backgroundColor ?? theme.color('background');
    final visible = widget.show && _scrollVisible != false;
    Widget accessory(Widget child) => DefaultTextStyle(
      style: theme.textStyle(
        typography: TdsTypography.t6,
        color: theme.color('grey600'),
      ),
      textAlign: TextAlign.center,
      child: Center(
        child: child is Text
            ? TdsLineBox(
                lineHeight: theme.platform.lineHeight(TdsTypography.t6),
                child: child,
              )
            : child,
      ),
    );
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.background)
          IgnorePointer(
            child: _CTAEntrance(
              entrance: widget.showAfterDelay,
              gradient: true,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface.withValues(alpha: 0), surface, surface],
                    stops: const [0, .75, 1],
                  ),
                ),
              ),
            ),
          ),
        _CTAEntrance(
          entrance: widget.showAfterDelay,
          child: Container(
            color: widget.background ? surface : null,
            padding: EdgeInsets.fromLTRB(
              full ? 0 : 20,
              0,
              full ? 0 : 20,
              bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.topAccessory != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: accessory(widget.topAccessory!),
                  ),
                if (widget._double)
                  _CTAButtons(
                    // CSS round(100vw/2 +/- .01px) changes gap at odd widths.
                    gap:
                        8 -
                        ((media.size.width / 2 + .01).round() -
                                (media.size.width / 2 - .01).round())
                            .toDouble(),
                    textDirection: Directionality.of(context),
                    children: [
                      if (widget.leftButton != null) widget.leftButton!,
                      if (widget.rightButton != null) widget.rightButton!,
                    ],
                  )
                else
                  TdsCTAButton(
                    onPressed: widget.onPressed,
                    disabled: widget.disabled,
                    disabledChild: widget.disabledChild,
                    loading: widget.loading,
                    inert: widget.inert,
                    focusNode: widget.focusNode,
                    autofocus: widget.autofocus,
                    semanticLabel: widget.semanticLabel,
                    color: widget.color,
                    variant: widget.variant,
                    display: full
                        ? TdsButtonDisplay.full
                        : TdsButtonDisplay.block,
                    child: widget.child!,
                  ),
                if (widget.bottomAccessory != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: accessory(widget.bottomAccessory!),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    content = IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: visible ? 1 : 0, end: visible ? 1 : 0),
            duration: media.disableAnimations
                ? Duration.zero
                : TdsMotion.quick.duration,
            curve: TdsMotion.quick,
            builder: (context, progress, child) => Transform.translate(
              offset: Offset(0, 50 * (1 - progress)),
              child: Opacity(opacity: progress.clamp(0, 1), child: child),
            ),
            child: content,
          ),
        ),
      ),
    );
    final takeSpace = widget.takeSpace ?? widget.fixed;
    if (widget.fixed) {
      return TdsFixedPanel(
        takeSpace: takeSpace,
        aboveKeyboard: widget.fixedAboveKeyboard,
        child: content,
      );
    }
    // React renders its measured spacer even for explicitly non-fixed takeSpace.
    return takeSpace ? TdsMeasuredFlowSpacer(child: content) : content;
  }
}

class _CTAEntrance extends StatefulWidget {
  const _CTAEntrance({
    required this.child,
    this.entrance,
    this.gradient = false,
  });
  final Widget child;
  final TdsBottomCTADelayedEntrance? entrance;
  final bool gradient;
  @override
  State<_CTAEntrance> createState() => _CTAEntranceState();
}

class _CTAEntranceState extends State<_CTAEntrance>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, value: 1);
  Timer? _delay;
  bool? _reducedMotion;
  TdsBottomCTAAnimation? get _kind =>
      widget.gradient &&
          widget.entrance?.animation == TdsBottomCTAAnimation.scale
      ? TdsBottomCTAAnimation.fade
      : widget.entrance?.animation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    _start();
  }

  @override
  void didUpdateWidget(_CTAEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entrance?.animation != widget.entrance?.animation ||
        oldWidget.entrance?.delay != widget.entrance?.delay ||
        oldWidget.gradient != widget.gradient) {
      _start();
    }
  }

  void _start() {
    _delay?.cancel();
    _animation.stop();
    if (_kind == null || _reducedMotion == true) {
      _animation.value = 1;
      return;
    }
    _animation.duration = Duration(
      milliseconds: _kind == TdsBottomCTAAnimation.fade ? 600 : 800,
    );
    _animation.value = 0;
    if (widget.entrance!.delay == Duration.zero) {
      _animation.forward();
    } else {
      _delay = Timer(widget.entrance!.delay, () => _animation.forward());
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      final value =
          (_kind == TdsBottomCTAAnimation.fade
                  ? const Cubic(.6, 0, 0, .6)
                  : TdsMotion.expo)
              .transform(_animation.value);
      final invisible = value == 0;
      return IgnorePointer(
        ignoring: invisible,
        child: ExcludeFocus(
          excluding: invisible,
          child: ExcludeSemantics(
            excluding: invisible,
            child: Opacity(
              opacity: value,
              child: switch (_kind) {
                TdsBottomCTAAnimation.scale => Transform.scale(
                  scale: .6 + .4 * value,
                  child: child,
                ),
                TdsBottomCTAAnimation.slide => Transform.translate(
                  offset: Offset(0, 80 * (1 - value)),
                  child: child,
                ),
                _ => child,
              },
            ),
          ),
        ),
      );
    },
  );
}

/// CSS flex-basis:auto, flex-grow:1, min-width:calc(50% - gap), wrap-reverse.
class _CTAButtons extends MultiChildRenderObjectWidget {
  const _CTAButtons({
    required this.gap,
    required this.textDirection,
    required super.children,
  });
  final double gap;
  final TextDirection textDirection;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCTAButtons(gap, textDirection);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCTAButtons renderObject,
  ) {
    renderObject
      ..gap = gap
      ..textDirection = textDirection;
  }
}

class _CTAButtonData extends ContainerBoxParentData<RenderBox> {}

class _RenderCTAButtons extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CTAButtonData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CTAButtonData> {
  _RenderCTAButtons(this._gap, this._textDirection);
  double _gap;
  TextDirection _textDirection;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CTAButtonData) {
      child.parentData = _CTAButtonData();
    }
  }

  List<double> _widths(double width) {
    final bases = <double>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      bases.add(child.getMaxIntrinsicWidth(double.infinity));
    }
    if (bases.length < 2) return bases.isEmpty ? [] : [width];
    final minWidth = math.max(0.0, width / 2 - _gap);
    if (math.max(minWidth, bases[0]) + math.max(minWidth, bases[1]) + _gap >
        width) {
      return [width, width];
    }
    // Flex distributes free space using the UNCLAMPED auto basis. If an item
    // violates min-width it is frozen there and free space is redistributed.
    final extra = (width - bases[0] - bases[1] - _gap) / 2;
    if (bases[0] + extra < minWidth) return [minWidth, width - _gap - minWidth];
    if (bases[1] + extra < minWidth) return [width - _gap - minWidth, minWidth];
    return [bases[0] + extra, bases[1] + extra];
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth, widths = _widths(constraints.maxWidth);
    if (widths.isEmpty) return constraints.constrain(Size(width, 0));
    final a = firstChild!.getDryLayout(
      BoxConstraints.tightFor(width: widths[0]),
    );
    if (widths.length == 1) return constraints.constrain(Size(width, a.height));
    final b = lastChild!.getDryLayout(
      BoxConstraints.tightFor(width: widths[1]),
    );
    return constraints.constrain(
      Size(
        width,
        widths[0] + widths[1] + _gap > width
            ? a.height + b.height + _gap
            : math.max(a.height, b.height),
      ),
    );
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    assert(width.isFinite, 'BottomCTA requires a bounded viewport width.');
    final widths = _widths(width);
    if (widths.isEmpty) {
      size = constraints.constrain(Size(width, 0));
      return;
    }
    final first = firstChild!;
    first.layout(
      BoxConstraints.tightFor(width: widths[0]),
      parentUsesSize: true,
    );
    final firstData = first.parentData! as _CTAButtonData;
    firstData.offset = Offset.zero;
    if (widths.length == 1) {
      size = constraints.constrain(Size(width, first.size.height));
      return;
    }
    final last = lastChild!;
    last.layout(
      BoxConstraints.tightFor(width: widths[1]),
      parentUsesSize: true,
    );
    final lastData = last.parentData! as _CTAButtonData;
    final stacked = widths[0] + widths[1] + _gap > width;
    double height;
    if (stacked) {
      lastData.offset = Offset.zero;
      firstData.offset = Offset(0, last.size.height + _gap);
      height = first.size.height + last.size.height + _gap;
    } else {
      height = math.max(first.size.height, last.size.height);
      first.layout(BoxConstraints.tightFor(width: widths[0], height: height));
      last.layout(BoxConstraints.tightFor(width: widths[1], height: height));
      firstData.offset = Offset(
        _textDirection == TextDirection.ltr ? 0 : widths[1] + _gap,
        0,
      );
      lastData.offset = Offset(
        _textDirection == TextDirection.ltr ? widths[0] + _gap : 0,
        0,
      );
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class TdsFixedBottomCTA extends TdsBottomCTA {
  const TdsFixedBottomCTA({
    required super.child,
    super.disabledChild,
    super.onPressed,
    super.disabled,
    super.loading,
    super.inert,
    super.focusNode,
    super.autofocus,
    super.semanticLabel,
    super.color,
    super.variant,
    super.topAccessory,
    super.bottomAccessory,
    super.background,
    super.hasSafeAreaPadding,
    super.hasPaddingBottom,
    super.takeSpace,
    super.fixedAboveKeyboard,
    super.show,
    super.hideOnScroll,
    super.hideOnScrollDistanceThreshold,
    super.scrollController,
    super.showAfterDelay,
    super.key,
  }) : super(fixed: true);
  const TdsFixedBottomCTA.double({
    required super.leftButton,
    required super.rightButton,
    super.topAccessory,
    super.bottomAccessory,
    super.background,
    super.hasSafeAreaPadding,
    super.hasPaddingBottom,
    super.takeSpace,
    super.fixedAboveKeyboard,
    super.show,
    super.hideOnScroll,
    super.hideOnScrollDistanceThreshold,
    super.scrollController,
    super.showAfterDelay,
    super.key,
  }) : super.double(fixed: true);
}
