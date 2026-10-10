import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';
import '../foundation/line_box.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'asset.dart';

enum TdsToastPosition { top, bottom }

/// Controlled, non-modal overlay. [persistent] maps the original Infinity
/// duration to Dart, disabling both timer and gesture dismissal. It does not
/// prevent the owner from setting [open] to false.
class TdsToast extends StatefulWidget {
  const TdsToast({
    required this.open,
    required this.text,
    this.position = TdsToastPosition.bottom,
    this.leftAddon,
    this.button,
    this.duration,
    this.persistent = false,
    this.higherThanCTA = false,
    this.liveRegion = true,
    this.gap = 0,
    this.onClose,
    this.onExited,
    super.key,
  }) : assert(position != TdsToastPosition.top || button == null);

  final bool open, persistent, higherThanCTA, liveRegion;
  final String text;
  final TdsToastPosition position;
  final Widget? leftAddon, button;
  final Duration? duration;
  final double gap;
  final VoidCallback? onClose, onExited;

  @override
  State<TdsToast> createState() => _TdsToastState();
}

class _TdsToastState extends State<TdsToast>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final AnimationController _animation;
  Timer? _timer;
  Offset? _start;
  Offset _delta = Offset.zero;
  Offset _drag = Offset.zero;
  bool _dragExit = false;
  double _exitX = 0;
  Duration _startTime = Duration.zero;
  int? _pointer;
  bool _requestedOpen = false;

  TdsSpringCurve get _curve => widget.position == TdsToastPosition.top
      ? TdsMotion.small
      : TdsMotion.quick;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: _curve.duration)
      ..addStatusListener(_status);
    _requestedOpen = widget.open;
    _scheduleSync();
  }

  @override
  void didUpdateWidget(TdsToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = _curve.duration;
    if (widget.open) _requestedOpen = true;
    if (oldWidget.open != widget.open) _scheduleSync();
    if (oldWidget.duration != widget.duration ||
        oldWidget.persistent != widget.persistent ||
        oldWidget.onClose != widget.onClose ||
        (oldWidget.button == null) != (widget.button == null)) {
      _startTimer();
    }
  }

  void _scheduleSync() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (widget.open) {
      _dragExit = false;
      _exitX = 0;
      _drag = Offset.zero;
      _portal.show();
      _animation.forward();
      _startTimer();
    } else {
      _timer?.cancel();
      if (_animation.isDismissed) {
        _hide();
      } else {
        _animation.reverse();
      }
    }
  });

  void _startTimer() {
    _timer?.cancel();
    if (!mounted ||
        !widget.open ||
        widget.persistent ||
        widget.onClose == null ||
        _pointer != null) {
      return;
    }
    _timer = Timer(
      widget.duration ?? Duration(seconds: widget.button == null ? 3 : 5),
      () {
        if (mounted && widget.open) widget.onClose?.call();
      },
    );
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.open) _hide();
  }

  void _hide() {
    if (!_portal.isShowing && !_requestedOpen) return;
    if (_portal.isShowing) _portal.hide();
    _requestedOpen = false;
    widget.onExited?.call();
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null || !widget.open) return;
    _timer?.cancel();
    _pointer = e.pointer;
    _start = e.position;
    _startTime = e.timeStamp;
    _delta = Offset.zero;
  }

  void _move(PointerMoveEvent e) {
    if (_pointer != e.pointer || _start == null) return;
    _delta = e.position - _start!;
    // Original drag resistance uses logarithmic displacement with the same
    // five-pixel neutral threshold. Native pointer dispatch replaces 10ms DOM
    // throttling, so intermediate samples are not claimed to be identical.
    double resisted(double delta, double multiplier) => delta == 0
        ? 0
        : delta.sign * (math.log(delta.abs() + 10) - math.log(15)) * multiplier;
    setState(
      () => _drag = Offset(resisted(_delta.dx, 5), resisted(_delta.dy, 10)),
    );
  }

  void _end(PointerEvent e, {bool cancel = false}) {
    if (_pointer != e.pointer) return;
    final width = MediaQuery.sizeOf(context).width;
    final android = TdsTheme.of(context).platform.os == TdsOS.android;
    final quick = e.timeStamp - _startTime < const Duration(milliseconds: 400);
    final dismissed =
        !cancel &&
        (widget.position == TdsToastPosition.top
            ? _delta.dy < -10
            : android
            ? _delta.dy > 10
            : (quick && _delta.dx.abs() / width > .1) ||
                  _delta.dx.abs() / width > .35);
    _pointer = null;
    _start = null;
    setState(() {
      _drag = Offset.zero;
      if (dismissed && !widget.persistent) {
        _dragExit = widget.position == TdsToastPosition.bottom;
        _exitX = android ? 0 : (_delta.dx < 0 ? -width * 1.3 : width);
      }
    });
    if (dismissed && !widget.persistent) {
      widget.onClose?.call();
    } else {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (context) {
      final top = widget.position == TdsToastPosition.top;
      return Positioned(
        top: top ? 46 + widget.gap : null,
        bottom: top ? null : 20 + (widget.higherThanCTA ? 76 : 0) + widget.gap,
        left: 0,
        right: 0,
        child: Center(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final closing = _animation.status == AnimationStatus.reverse;
              final progress = closing
                  ? 1 - _curve.transform(1 - _animation.value)
                  : _curve.transform(_animation.value);
              final android = TdsTheme.of(context).platform.os == TdsOS.android;
              final raised = widget.higherThanCTA ? 76.0 : 0.0;
              final dragExit = closing && _dragExit;
              final fraction = top
                  ? -1.0
                  : dragExit
                  ? (android ? 2.0 : 0.0)
                  : 1.0;
              final offset = Offset(
                dragExit ? _exitX : 0,
                top
                    ? -46
                    : dragExit && !android
                    ? -10
                    : (closing ? 20 : 30) + raised,
              );
              return Opacity(
                opacity: dragExit ? 1 : (progress * 1.1).clamp(0, 1),
                child: FractionalTranslation(
                  translation: Offset(0, fraction * (1 - progress)),
                  child: Transform.translate(
                    offset: offset * (1 - progress),
                    child: child,
                  ),
                ),
              );
            },
            child: Listener(
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _end,
              onPointerCancel: (e) => _end(e, cancel: true),
              child: AnimatedContainer(
                duration: _pointer == null
                    ? TdsMotion.quick.duration
                    : const Duration(milliseconds: 100),
                curve: _pointer == null ? TdsMotion.quick : Curves.linear,
                transform: Matrix4.translationValues(_drag.dx, _drag.dy, 0),
                child: Semantics(
                  container: true,
                  liveRegion: widget.liveRegion,
                  child: TdsToastContent(
                    text: widget.text,
                    position: widget.position,
                    leftAddon: widget.leftAddon,
                    button: widget.button,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: const SizedBox.shrink(),
  );
}

/// Non-overlay surface, also used by the comparison fixture.
class TdsToastContent extends StatelessWidget {
  const TdsToastContent({
    required this.text,
    this.position = TdsToastPosition.bottom,
    this.leftAddon,
    this.button,
    super.key,
  });
  final String text;
  final TdsToastPosition position;
  final Widget? leftAddon, button;

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final top = position == TdsToastPosition.top;
    final dark = theme.colorScheme == TdsColorPreference.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = top ? math.min(375.0, screenWidth - 36) : screenWidth - 40;
    final action = top ? null : button;
    final stacked =
        action != null && theme.platform.fontScale >= 200 && screenWidth < 550;
    final label = TdsLineBox(
      lineHeight: theme.platform.lineHeight(TdsTypography.t6),
      child: Text(
        text,
        style: theme.textStyle(
          typography: TdsTypography.t6,
          fontWeight: TdsFontWeight.semibold,
          color: top
              ? (dark ? const Color(0xffffffff) : TdsPalette.greyOpacity800)
              : TdsPalette.floatBackground,
        ),
      ),
    );
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leftAddon != null) ...[
          SizedBox.square(dimension: 24, child: leftAddon),
          SizedBox(width: top ? 8 : 12),
        ],
        Flexible(
          child: action == null
              ? label
              : stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 8), action],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 20),
                    action,
                  ],
                ),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(0, width)),
      child: SizedBox(
        width: action != null ? width : null,
        child: CustomPaint(
          painter: top ? const _ToastShadow() : null,
          child: ClipPath(
            clipper: const _ToastClipper(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: ColoredBox(
                color: top
                    ? (dark
                          ? TdsPalette.darkThemeGrey200
                          : const Color(0xffffffff))
                    : (dark ? theme.color('grey200') : TdsPalette.grey500),
                child: Padding(
                  padding: top
                      ? EdgeInsets.fromLTRB(
                          leftAddon == null ? 16 : 12,
                          12,
                          16,
                          12,
                        )
                      : EdgeInsets.fromLTRB(
                          leftAddon == null && action == null ? 20 : 16,
                          14,
                          action == null ? 20 : 14,
                          14,
                        ),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

RRect _toastRect(Size size) => RRect.fromRectAndRadius(
  Offset.zero & size,
  Radius.circular(size.height > 65 ? 20 : 100),
);

class _ToastClipper extends CustomClipper<Path> {
  const _ToastClipper();
  @override
  Path getClip(Size size) => Path()..addRRect(_toastRect(size));
  @override
  bool shouldReclip(_ToastClipper oldClipper) => false;
}

class _ToastShadow extends CustomPainter {
  const _ToastShadow();
  @override
  void paint(Canvas canvas, Size size) {
    const shadow = BoxShadow(
      color: TdsPalette.greyOpacity200,
      offset: Offset(0, 2),
      blurRadius: 30,
    );
    canvas.drawRRect(_toastRect(size).shift(shadow.offset), shadow.toPaint());
  }

  @override
  bool shouldRepaint(_ToastShadow oldDelegate) => false;
}

class TdsToastButton extends StatelessWidget {
  const TdsToastButton({
    required this.child,
    this.onPressed,
    this.disabled = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return TdsPressable(
      enabled: !disabled,
      onPressed: onPressed,
      builder: (context, pressed, hovered, focused) => AnimatedScale(
        scale: pressed ? .96 : 1,
        duration: pressed ? TdsMotion.rapid.duration : TdsMotion.quick.duration,
        curve: pressed ? TdsMotion.rapid : TdsMotion.quick,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme == TdsColorPreference.dark
                ? TdsPalette.whiteOpacity100
                : TdsPalette.greyOpacity400,
            borderRadius: BorderRadius.circular(100),
          ),
          child: AnimatedContainer(
            duration: pressed || hovered
                ? TdsMotion.rapid.duration
                : TdsMotion.quick.duration,
            curve: pressed || hovered ? TdsMotion.rapid : TdsMotion.quick,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: pressed || hovered
                  ? const Color(0x1a000000)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(100),
            ),
            child: TdsLineBox(
              lineHeight: theme.platform.lineHeight(TdsTypography.t7),
              child: DefaultTextStyle(
                style: theme.textStyle(
                  typography: TdsTypography.t7,
                  fontWeight: TdsFontWeight.semibold,
                  color: TdsPalette.whiteOpacity800,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TdsToastIcon extends StatelessWidget {
  const TdsToastIcon({
    required this.name,
    this.color,
    this.frameShape = const TdsAssetFrameShape(width: 24, height: 24),
    super.key,
  });
  final String name;
  final Color? color;
  final TdsAssetFrameShape frameShape;
  @override
  Widget build(BuildContext context) => TdsAssetIcon(
    name: name,
    color: color,
    frameShape: frameShape.withDefaultSize(24, 24),
  );
}

class TdsToastLottie extends StatelessWidget {
  const TdsToastLottie({
    required this.src,
    this.frameShape = const TdsAssetFrameShape(width: 24, height: 24),
    super.key,
  });
  final String src;
  final TdsAssetFrameShape frameShape;
  @override
  Widget build(BuildContext context) => TdsAssetLottie(
    src: src,
    frameShape: frameShape.withDefaultSize(24, 24),
    repeat: false,
  );
}
