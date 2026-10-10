import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import '../foundation/bottom_sheet_scope.dart';
import '../foundation/line_box.dart';
import '../foundation/theme.dart';
import '../foundation/motion.dart';
import '../foundation/sheet_motion.dart';
import 'bottom_cta.dart';
import 'button.dart';
import 'checkbox.dart';
import 'modal.dart';
import 'text.dart';

class TdsBottomSheetHeight {
  const TdsBottomSheetHeight.pixels(double value)
    : pixels = value,
      fraction = null;
  const TdsBottomSheetHeight.viewport(double value)
    : fraction = value,
      pixels = null,
      assert(value > 0 && value <= 1);
  final double? pixels, fraction;
  double resolve(double available) =>
      math.min(available, pixels ?? available * fraction!);
}

class TdsBottomSheet extends StatelessWidget {
  const TdsBottomSheet({
    required this.open,
    required this.child,
    this.header,
    this.headerDescription,
    this.cta,
    this.onClose,
    this.onDimmerClick,
    this.onEntered,
    this.onExited,
    this.onExpanded,
    this.onHandlerTouchStart,
    this.onHandlerTouchEnd,
    this.disableDimmer = false,
    this.ignoreDimmerClick = false,
    this.ignoreBackEvent = false,
    this.disableChildrenDragging = false,
    this.a11yIncludeHeaderInScroll = true,
    this.expandBottomSheet = false,
    this.expandBottomSheetWhenScroll = false,
    this.maxHeight,
    this.expandedMaxHeight = const TdsBottomSheetHeight.viewport(1),
    this.ctaContentGap = 34,
    this.semanticLabel = '바텀시트',
    super.key,
  });
  final bool open,
      disableDimmer,
      ignoreDimmerClick,
      ignoreBackEvent,
      disableChildrenDragging,
      a11yIncludeHeaderInScroll,
      expandBottomSheet,
      expandBottomSheetWhenScroll;
  final Widget child;
  final Widget? header, headerDescription, cta;
  final VoidCallback? onClose, onDimmerClick, onEntered, onExited, onExpanded;
  final VoidCallback? onHandlerTouchStart, onHandlerTouchEnd;
  final TdsBottomSheetHeight? maxHeight;
  final TdsBottomSheetHeight expandedMaxHeight;
  final double ctaContentGap;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => _SheetEnteredObserver(
    open: open,
    onEntered: onEntered,
    child: TdsModal(
      open: open,
      sheet: true,
      disableDimmer: disableDimmer,
      closeOnDimmerClick: !ignoreDimmerClick,
      closeOnBackEvent: !ignoreBackEvent,
      onClose: onClose,
      onDimmerClick: onDimmerClick,
      onExited: onExited,
      semanticLabel: semanticLabel,
      child: _SheetContents(model: this),
    ),
  );
}

/// wre invokes onEntered from its open effect, not at animation completion.
class _SheetEnteredObserver extends StatefulWidget {
  const _SheetEnteredObserver({
    required this.open,
    required this.child,
    this.onEntered,
  });
  final bool open;
  final Widget child;
  final VoidCallback? onEntered;
  @override
  State<_SheetEnteredObserver> createState() => _SheetEnteredObserverState();
}

class _SheetEnteredObserverState extends State<_SheetEnteredObserver> {
  void _entered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.open) widget.onEntered?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.open) _entered();
  }

  @override
  void didUpdateWidget(_SheetEnteredObserver old) {
    super.didUpdateWidget(old);
    if (!old.open && widget.open) _entered();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SheetContents extends StatefulWidget {
  const _SheetContents({required this.model});
  final TdsBottomSheet model;
  @override
  State<_SheetContents> createState() => _SheetContentsState();
}

class _SheetContentsState extends State<_SheetContents>
    with SingleTickerProviderStateMixin {
  bool expanded = false;
  final _scroll = ScrollController();
  bool _scrollable = false;
  final _surfaceKey = GlobalKey(), _bodyKey = GlobalKey();
  final _headerKey = GlobalKey(), _handlerKey = GlobalKey();
  int? _pointer;
  Offset _start = Offset.zero,
      _displacement = Offset.zero,
      _translation = Offset.zero;
  bool _draggable = false, _moving = false, _headerPressed = false;
  bool _touchingHandler = false,
      _firstContentTouch = true,
      _expandOnMove = false;
  Duration? _lastMove;
  double _contentsOpacity = 1;
  late final AnimationController _dimmerAnimation;
  ValueNotifier<double?>? _dimmer;
  double _dimmerFrom = .2, _dimmerTo = .2;

  @override
  void initState() {
    super.initState();
    _dimmerAnimation = AnimationController(
      vsync: this,
      duration: TdsMotion.quick.duration,
    )..addListener(_updateDimmer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dimmer = TdsSheetDimmerScope.maybeOf(context);
  }

  void _updateDimmer() {
    _dimmer?.value =
        _dimmerFrom +
        (_dimmerTo - _dimmerFrom) *
            TdsMotion.quick.transform(_dimmerAnimation.value);
  }

  void _animateDimmer(double value) {
    _dimmerFrom =
        _dimmer?.value ??
        TdsSheetMotion.normalDimmer(TdsTheme.of(context).isDark);
    _dimmerTo = value;
    if (MediaQuery.disableAnimationsOf(context)) {
      _dimmerAnimation.stop();
      _dimmer?.value = value;
    } else {
      _dimmerAnimation.forward(from: 0);
    }
  }

  bool _contains(GlobalKey key, Offset position) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(position));
  }

  void _pointerDown(PointerDownEvent event) {
    if (_pointer != null || event.buttons != 1) return;
    final body = _contains(_bodyKey, event.position);
    final touch = event.kind == PointerDeviceKind.touch;
    _pointer = event.pointer;
    _start = event.position;
    _displacement = Offset.zero;
    _lastMove = null;
    // ti passes no event target for mouse gestures; touch has the body guard.
    _draggable =
        widget.model.onClose != null &&
        (!touch ||
            !body ||
            (!_scrollable && !widget.model.disableChildrenDragging));
    _expandOnMove =
        touch &&
        body &&
        _scrollable &&
        _firstContentTouch &&
        widget.model.expandBottomSheetWhenScroll;
    _touchingHandler = touch && _contains(_handlerKey, event.position);
    setState(
      () => _headerPressed =
          _contains(_handlerKey, event.position) ||
          _contains(_headerKey, event.position),
    );
    if (_touchingHandler) widget.model.onHandlerTouchStart?.call();
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (_expandOnMove) expand();
    if (!_draggable) return;
    if (_lastMove != null &&
        event.timeStamp - _lastMove! < const Duration(milliseconds: 10)) {
      return;
    }
    _lastMove = event.timeStamp;
    final delta = event.position - _start;
    final surface =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    final height = surface?.size.height ?? 0;
    setState(() {
      _displacement = delta;
      _translation = TdsSheetMotion.dragTranslation(delta);
      _moving = true;
      if (delta.dy > 0 && height > 0) {
        _contentsOpacity = (1 - delta.dy / height).clamp(0, 1);
      }
    });
    _animateDimmer(
      TdsSheetMotion.dimmer(delta, height, TdsTheme.of(context).isDark),
    );
  }

  void _pointerEnd(PointerEvent event, {bool canceled = false}) {
    if (event.pointer != _pointer) return;
    final close = !canceled && _draggable && _displacement.dy >= 50;
    final grow =
        !canceled &&
        _draggable &&
        _displacement.dy <= -10 &&
        _scrollable &&
        widget.model.expandBottomSheet;
    if (_touchingHandler) widget.model.onHandlerTouchEnd?.call();
    if (_expandOnMove) _firstContentTouch = false;
    _pointer = null;
    setState(() {
      _moving = false;
      _headerPressed = false;
      _translation = Offset.zero;
      _contentsOpacity = 1;
    });
    if (close) {
      widget.model.onClose?.call();
    } else if (grow) {
      expand();
    } else {
      _animateDimmer(TdsSheetMotion.normalDimmer(TdsTheme.of(context).isDark));
    }
  }

  bool _measureScroll(ScrollMetricsNotification event) {
    if (event.depth != 0) return false;
    final next = event.metrics.maxScrollExtent > 0;
    if (next != _scrollable) setState(() => _scrollable = next);
    return false;
  }

  @override
  void didUpdateWidget(_SheetContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.model.expandBottomSheet &&
        !widget.model.expandBottomSheetWhenScroll) {
      expanded = false;
    }
  }

  void expand() {
    if (expanded) return;
    final model = widget.model;
    final media = MediaQuery.of(context), theme = TdsTheme.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.viewPadding.top;
    final initial =
        model.maxHeight ??
        TdsBottomSheetHeight.viewport(theme.platform.fontScale > 150 ? .9 : .7);
    if (initial.resolve(available) ==
        model.expandedMaxHeight.resolve(available)) {
      return;
    }
    setState(() => expanded = true);
    widget.model.onExpanded?.call();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _dimmerAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model,
        media = MediaQuery.of(context),
        theme = TdsTheme.of(context);
    final available = math.max(
      0.0,
      media.size.height - media.viewInsets.bottom - media.viewPadding.top,
    );
    final bottomGap = math.max(10.0, media.viewPadding.bottom);
    final maxHeight =
        (expanded
                ? model.expandedMaxHeight
                : model.maxHeight ??
                      TdsBottomSheetHeight.viewport(
                        theme.platform.fontScale > 150 ? .9 : .7,
                      ))
            .resolve(available) -
        (expanded ? bottomGap : 0);
    final header = model.header != null || model.headerDescription != null
        ? Padding(
            key: _headerKey,
            padding: const EdgeInsets.only(top: 21, bottom: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [?model.header, ?model.headerDescription],
            ),
          )
        : null;
    final scrollHeader =
        model.a11yIncludeHeaderInScroll && theme.platform.fontScale >= 160;
    final contentIndex =
        (model.header != null ? 1 : 0) +
        (model.headerDescription != null ? 1 : 0);
    final body = NotificationListener<ScrollMetricsNotification>(
      onNotification: _measureScroll,
      child: NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (model.expandBottomSheetWhenScroll && event.metrics.pixels > 0) {
            expand();
          }
          return false;
        },
        child: SingleChildScrollView(
          key: _bodyKey,
          controller: _scroll,
          physics:
              !expanded &&
                  _firstContentTouch &&
                  _scrollable &&
                  model.expandBottomSheetWhenScroll
              ? const NeverScrollableScrollPhysics()
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (scrollHeader) ?header,
              _SheetSlideEntrance(
                animation: true,
                delay: Duration(milliseconds: contentIndex * 30),
                contentLength: contentIndex + 1,
                child: model.child,
              ),
              if (model.cta != null) SizedBox(height: model.ctaContentGap),
            ],
          ),
        ),
      ),
    );
    return TdsBottomSheetScope(
      hasCTA: model.cta != null,
      scrollable: _scrollable,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, bottomGap),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerEnd,
          onPointerCancel: (event) => _pointerEnd(event, canceled: true),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: Offset.zero, end: _translation),
            duration: media.disableAnimations
                ? Duration.zero
                : _moving
                ? Duration(milliseconds: _displacement.dy < 0 ? 100 : 10)
                : TdsMotion.quick.duration,
            curve: _moving ? Curves.linear : TdsMotion.quick,
            builder: (context, offset, child) =>
                Transform.translate(offset: offset, child: child),
            child: AnimatedScale(
              scale: _moving || _headerPressed ? .98 : 1,
              duration: media.disableAnimations
                  ? Duration.zero
                  : TdsMotion.rapid.duration,
              curve: TdsMotion.rapid,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ColoredBox(
                  color: theme.color('layeredBackground'),
                  child: AnimatedContainer(
                    key: _surfaceKey,
                    duration: media.disableAnimations
                        ? Duration.zero
                        : TdsMotion.rapid.duration,
                    curve: TdsMotion.rapid,
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    height: expanded ? maxHeight : null,
                    width: double.infinity,
                    child: AnimatedOpacity(
                      opacity: _contentsOpacity,
                      duration: media.disableAnimations
                          ? Duration.zero
                          : _moving
                          ? TdsMotion.rapid.duration
                          : const Duration(milliseconds: 500),
                      curve: _moving ? TdsMotion.rapid : TdsMotion.out,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: '바텀시트 높이 조절',
                            onIncrease: model.expandBottomSheet && _scrollable
                                ? expand
                                : null,
                            child: SizedBox(
                              key: _handlerKey,
                              height: 16,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 48,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.color('grey200'),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!scrollHeader) ?header,
                          Flexible(child: body),
                          ?model.cta,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TdsBottomSheetHeader extends StatelessWidget {
  const TdsBottomSheetHeader(this.text, {super.key}) : child = null;
  const TdsBottomSheetHeader.child(this.child, {super.key}) : text = null;
  final String? text;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final style = TdsTheme.of(
      context,
    ).textStyle(typography: TdsTypography.t4, fontWeight: TdsFontWeight.bold);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: DefaultTextStyle(
        style: style,
        child: text != null
            ? Semantics(
                header: true,
                child: TdsText(
                  text!,
                  typography: TdsTypography.t4,
                  fontWeight: TdsFontWeight.bold,
                ),
              )
            : child is Text
            ? TdsLineBox(
                lineHeight: style.fontSize! * style.height!,
                child: child!,
              )
            : child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class TdsBottomSheetHeaderDescription extends StatelessWidget {
  const TdsBottomSheetHeaderDescription(this.text, {super.key}) : child = null;
  const TdsBottomSheetHeaderDescription.child(this.child, {super.key})
    : text = null;
  final String? text;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final style = TdsTheme.of(context).textStyle(
      typography: TdsTypography.t6,
      color: TdsTheme.of(context).color('grey600'),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 44, 0),
      child: DefaultTextStyle(
        style: style,
        child: text != null || child is Text
            ? TdsLineBox(
                lineHeight: style.fontSize! * style.height!,
                child: child ?? Text(text!, textScaler: TextScaler.noScaling),
              )
            : child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class TdsBottomSheetCTA extends StatelessWidget {
  const TdsBottomSheetCTA({
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
    this.background,
    this.hasSafeAreaPadding = false,
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
  });
  final Widget child;
  final Widget? disabledChild, topAccessory, bottomAccessory;
  final VoidCallback? onPressed;
  final bool disabled, loading, inert, autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;
  final TdsButtonColor color;
  final TdsButtonVariant variant;

  /// null resolves to the sheet's measured scrollability, like source DR.
  final bool? background, takeSpace;
  final bool hasSafeAreaPadding, hasPaddingBottom, fixed, fixedAboveKeyboard;
  final bool show, hideOnScroll;
  final double hideOnScrollDistanceThreshold;
  final ScrollController? scrollController;
  final TdsBottomCTADelayedEntrance? showAfterDelay;
  @override
  Widget build(BuildContext context) {
    final resolved =
        background ?? TdsBottomSheetScope.maybeOf(context)?.scrollable ?? false;
    return _SheetCTAFade(
      child: TdsSheetCTAOverlap(
        overlap: resolved ? 34 : 0,
        child: TdsBottomCTA.single(
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
          background: resolved,
          backgroundColor: TdsTheme.of(context).color('layeredBackground'),
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
          child: child,
        ),
      ),
    );
  }
}

class TdsBottomSheetDoubleCTA extends StatelessWidget {
  const TdsBottomSheetDoubleCTA({
    required this.leftButton,
    required this.rightButton,
    this.topAccessory,
    this.bottomAccessory,
    this.background,
    this.hasSafeAreaPadding = false,
    this.hasPaddingBottom = true,
    this.fixed = false,
    this.takeSpace,
    this.fixedAboveKeyboard = false,
    this.show = true,
    this.hideOnScroll = false,
    this.hideOnScrollDistanceThreshold = 1,
    this.scrollController,
    this.showAfterDelay,
    super.key,
  });
  final Widget? leftButton, rightButton, topAccessory, bottomAccessory;
  final bool? background, takeSpace;
  final bool hasSafeAreaPadding, hasPaddingBottom, fixed, fixedAboveKeyboard;
  final bool show, hideOnScroll;
  final double hideOnScrollDistanceThreshold;
  final ScrollController? scrollController;
  final TdsBottomCTADelayedEntrance? showAfterDelay;
  @override
  Widget build(BuildContext context) {
    final resolved =
        background ?? TdsBottomSheetScope.maybeOf(context)?.scrollable ?? false;
    return _SheetCTAFade(
      child: TdsSheetCTAOverlap(
        overlap: resolved ? 34 : 0,
        child: TdsBottomCTA.double(
          leftButton: leftButton,
          rightButton: rightButton,
          topAccessory: topAccessory,
          bottomAccessory: bottomAccessory,
          background: resolved,
          backgroundColor: TdsTheme.of(context).color('layeredBackground'),
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
        ),
      ),
    );
  }
}

/// xre/ge.fade(in, fast): 600ms with the source ease cubic, not a spring.
class _SheetCTAFade extends StatelessWidget {
  const _SheetCTAFade({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 600),
    curve: const Cubic(.6, 0, 0, .6),
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: child,
  );
}

class TdsBottomSheetSelectOption {
  const TdsBottomSheetSelectOption({
    required this.name,
    required this.value,
    this.disabled = false,
    this.hideUncheckedCheckbox = false,
  });
  final String name, value;
  final bool disabled, hideUncheckedCheckbox;
}

class TdsBottomSheetSelect extends StatelessWidget {
  const TdsBottomSheetSelect({
    required this.options,
    required this.onChange,
    this.value,
    this.animation = true,
    this.animationDelay = Duration.zero,
    this.onCheckedChange,
    super.key,
  });
  final List<TdsBottomSheetSelectOption> options;
  final String? value;
  final ValueChanged<String> onChange;
  final void Function(String value, bool checked)? onCheckedChange;
  final bool animation;
  final Duration animationDelay;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: 8,
      bottom: (TdsBottomSheetScope.maybeOf(context)?.hasCTA ?? true) ? 0 : 16,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < options.length; index++)
          _SheetSlideEntrance(
            key: ValueKey(options[index].value),
            animation: animation,
            delay: animationDelay + Duration(milliseconds: index * 30),
            contentLength: options.length,
            child: _SheetSelectRow(
              option: options[index],
              selected: value == options[index].value,
              onChange: () {
                onChange(options[index].value);
                onCheckedChange?.call(
                  options[index].value,
                  value != options[index].value,
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _SheetSlideEntrance extends StatefulWidget {
  const _SheetSlideEntrance({
    required this.animation,
    required this.delay,
    required this.contentLength,
    required this.child,
    super.key,
  });
  final bool animation;
  final Duration delay;
  final int contentLength;
  final Widget child;
  @override
  State<_SheetSlideEntrance> createState() => _SheetSlideEntranceState();
}

class _SheetSlideEntranceState extends State<_SheetSlideEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _controller.duration = widget.delay + const Duration(milliseconds: 800);
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(_SheetSlideEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delay != widget.delay ||
        oldWidget.contentLength != widget.contentLength) {
      _start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final elapsed = _controller.value * _controller.duration!.inMicroseconds;
      final progress = ((elapsed - widget.delay.inMicroseconds) / 800000).clamp(
        0.0,
        1.0,
      );
      final y = !widget.animation || MediaQuery.disableAnimationsOf(context)
          ? 0.0
          : 80 * (1 - TdsMotion.expo.transform(progress));
      return Transform.translate(offset: Offset(0, y), child: child);
    },
  );
}

class _SheetSelectRow extends StatefulWidget {
  const _SheetSelectRow({
    required this.option,
    required this.selected,
    required this.onChange,
  });
  final TdsBottomSheetSelectOption option;
  final bool selected;
  final VoidCallback onChange;
  @override
  State<_SheetSelectRow> createState() => _SheetSelectRowState();
}

class _SheetSelectRowState extends State<_SheetSelectRow> {
  int? _pointer;
  bool _pressed = false;
  void _end() {
    _pointer = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), option = widget.option;
    final motion = _pressed ? TdsMotion.rapid : TdsMotion.quick;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : motion.duration;
    return Semantics(
      container: true,
      checked: widget.selected,
      enabled: !option.disabled,
      inMutuallyExclusiveGroup: true,
      label: option.name,
      onTap: option.disabled ? null : widget.onChange,
      child: Focus(
        canRequestFocus: !option.disabled,
        // Source labels are tabbable, but have no Enter/Space/arrow handler.
        child: MouseRegion(
          child: Listener(
            onPointerDown: (event) {
              if (_pointer != null || event.buttons != 1) return;
              _pointer = event.pointer;
              setState(() => _pressed = true);
            },
            onPointerUp: (event) {
              if (_pointer == event.pointer) _end();
            },
            onPointerCancel: (event) {
              if (_pointer == event.pointer) _end();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: option.disabled ? null : widget.onChange,
              child: AnimatedScale(
                scale: _pressed ? .96 : 1,
                duration: duration,
                curve: motion,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: _pressed ? 1 : 0,
                          duration: duration,
                          curve: motion,
                          child: ColoredBox(color: theme.color('opacity100')),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Expanded(
                                child: TdsText(
                                  option.name,
                                  typography: TdsTypography.t5,
                                  fontWeight: TdsFontWeight.medium,
                                  color: theme.color('grey700'),
                                ),
                              ),
                              Opacity(
                                opacity:
                                    option.hideUncheckedCheckbox &&
                                        !widget.selected
                                    ? 0
                                    : option.disabled
                                    ? .4
                                    : 1,
                                child: TdsCheckboxLineGraphic(
                                  size: 24,
                                  color: theme.color(
                                    widget.selected ? 'blue500' : 'grey300',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
