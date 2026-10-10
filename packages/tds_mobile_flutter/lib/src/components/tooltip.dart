import 'dart:async';
import 'dart:math' as math;
export 'full_tooltip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/line_box.dart';
import '../foundation/css_shadow.dart';
import '../foundation/theme.dart';
import '../foundation/motion.dart';
import '../foundation/tokens.g.dart';

enum TdsBubbleBackground { blue, grey }

class TdsBubble extends StatelessWidget {
  const TdsBubble({
    required this.child,
    required this.background,
    this.withTail = true,
    this.parentFontSize = 16,
    this.parentLineHeight = 24,
    super.key,
  });
  final Widget child;
  final TdsBubbleBackground background;
  final bool withTail;

  /// CSS host strut, separate from the scaled inner TDS text. Override when the
  /// bubble's native ancestor corresponds to a differently styled HTML host.
  final double parentFontSize, parentLineHeight;
  @override
  Widget build(BuildContext context) {
    final blue = background == TdsBubbleBackground.blue,
        theme = TdsTheme.of(context);
    final color = blue ? TdsPalette.blue500 : theme.color('grey200');
    return Padding(
      padding: EdgeInsets.only(left: blue ? 0 : 5, right: blue ? 5 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 253),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TdsInlineMiddle(
              parentFontSize: parentFontSize,
              parentLineHeight: parentLineHeight,
              child: TdsLineBox(
                lineHeight: theme.platform.lineHeight(TdsTypography.st10),
                child: DefaultTextStyle(
                  style: theme.textStyle(
                    typography: TdsTypography.st10,
                    color: blue
                        ? const Color(0xffffffff)
                        : theme.color('grey800'),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
          if (withTail)
            Positioned(
              bottom: 0,
              left: blue ? null : -5,
              right: blue ? -5 : null,
              child: Transform.flip(
                flipX: !blue,
                child: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="13" height="17" viewBox="0 0 13 17"><path d="M11.992 17c1.102.007 1.404-1.512.383-1.926-2.652-1.078-4.503-3.718-4.521-6.63V0h-2v.892C5.854 5.405 3.8 9.56.386 12.206c-.559.433-.504 1.293.105 1.652C3.898 15.865 7.922 16.974 11.992 17z"/></svg>',
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum TdsTooltipSize { small, medium, large }

enum TdsTooltipMotion { weak, strong }

enum TdsTooltipClip { none, left, right }

class TdsTooltip extends StatefulWidget {
  const TdsTooltip({
    required this.child,
    this.message,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.size = TdsTooltipSize.medium,
    this.placement = TdsOverlayPlacement.bottom,
    this.messageAlign = TextAlign.left,
    this.motionVariant = TdsTooltipMotion.weak,
    this.offset,
    this.anchorPositionByRatio = .5,
    this.openOnHover = false,
    this.openOnFocus = false,
    this.dismissible = false,
    this.autoFlip = false,
    this.clipToEnd = TdsTooltipClip.none,
    super.key,
  });
  final Widget child;
  final Widget? message;
  final bool? open;
  final bool defaultOpen, openOnHover, openOnFocus, dismissible, autoFlip;
  final ValueChanged<bool>? onOpenChange;
  final TdsTooltipSize size;
  final TdsOverlayPlacement placement;
  final TextAlign messageAlign;
  final TdsTooltipMotion motionVariant;
  final double? offset;
  final double anchorPositionByRatio;
  final TdsTooltipClip clipToEnd;
  @override
  State<TdsTooltip> createState() => _TdsTooltipState();
}

class _TdsTooltipState extends State<TdsTooltip> {
  late bool internal = widget.defaultOpen;
  Timer? hoverClose;
  bool get open => widget.open ?? internal;
  void change(bool value) {
    hoverClose?.cancel();
    if (open == value) return;
    if (widget.open == null) setState(() => internal = value);
    widget.onOpenChange?.call(value);
  }

  void leave() {
    hoverClose?.cancel();
    hoverClose = Timer(const Duration(milliseconds: 100), () {
      if (mounted) change(false);
    });
  }

  @override
  void dispose() {
    hoverClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TdsAnchoredOverlay(
    open: open,
    closeDelay: TdsMotion.medium.duration,
    placement: widget.placement,
    offset: widget.offset ?? (widget.size == TdsTooltipSize.small ? 18 : 24),
    autoFlip: widget.autoFlip,
    maxWidth: math.max(58, MediaQuery.sizeOf(context).width - 96),
    onDismiss: widget.dismissible ? () => change(false) : null,
    overlayBuilder: (context, placement) => MouseRegion(
      onEnter: widget.openOnHover ? (_) => hoverClose?.cancel() : null,
      onExit: widget.openOnHover ? (_) => leave() : null,
      child: TdsTooltipMotionSurface(
        open: open,
        variant: widget.motionVariant,
        placement: placement,
        anchorPositionByRatio: widget.anchorPositionByRatio,
        child: TdsTooltipContent(
          size: widget.size,
          placement: placement,
          clipToEnd: widget.clipToEnd,
          anchorPositionByRatio: widget.anchorPositionByRatio,
          messageAlign: widget.messageAlign,
          child: widget.message ?? const SizedBox(),
        ),
      ),
    ),
    child: Focus(
      onFocusChange: widget.openOnFocus ? change : null,
      canRequestFocus: false,
      child: MouseRegion(
        onEnter: widget.openOnHover ? (_) => change(true) : null,
        onExit: widget.openOnHover ? (_) => leave() : null,
        child: widget.child,
      ),
    ),
  );
}

/// Original 0→1 weak spring and 0→1.25→1 strong sequence. Kept mounted during
/// exit by the anchor host; interrupted transitions start at their visible value.
class TdsTooltipMotionSurface extends StatefulWidget {
  const TdsTooltipMotionSurface({
    required this.open,
    required this.child,
    required this.variant,
    required this.placement,
    this.anchorPositionByRatio = .5,
    super.key,
  });
  final bool open;
  final Widget child;
  final TdsTooltipMotion variant;
  final TdsOverlayPlacement placement;
  final double anchorPositionByRatio;
  @override
  State<TdsTooltipMotionSurface> createState() =>
      _TdsTooltipMotionSurfaceState();
}

class _TdsTooltipMotionSurfaceState extends State<TdsTooltipMotionSurface>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  bool _opening = true, _reduced = false, _initialized = false;
  double _fromScale = 0, _fromOpacity = 0;
  TdsTooltipMotion _variant = TdsTooltipMotion.weak;
  ({double scale, double opacity}) _sample() {
    final t = _animation.value;
    double scale, opacity;
    if (!_opening) {
      final k = TdsMotion.medium.transform(t);
      scale = _fromScale * (1 - k);
      opacity = _fromOpacity * (1 - k);
    } else if (_variant == TdsTooltipMotion.strong && !_reduced) {
      final quick = TdsMotion.quick.duration.inMicroseconds.toDouble();
      final bounce = TdsMotion.bounce.duration.inMicroseconds.toDouble();
      final elapsed = t * (quick + bounce);
      scale = elapsed < quick
          ? _fromScale +
                (1.25 - _fromScale) * TdsMotion.quick.transform(elapsed / quick)
          : 1.25 -
                .25 *
                    TdsMotion.bounce.transform(
                      ((elapsed - quick) / bounce).clamp(0.0, 1.0),
                    );
      opacity =
          _fromOpacity +
          (1 - _fromOpacity) *
              TdsMotion.quick.transform((elapsed / quick).clamp(0.0, 1.0));
    } else {
      final k = TdsMotion.medium.transform(t);
      scale = _fromScale + (1 - _fromScale) * k;
      opacity = _fromOpacity + (1 - _fromOpacity) * k;
    }
    return (
      scale: _reduced ? 1 : math.max(0, scale),
      opacity: opacity.clamp(0.0, 1.0),
    );
  }

  void _start() {
    final current = _sample();
    _fromScale = current.scale;
    _fromOpacity = current.opacity;
    _opening = widget.open;
    _variant = widget.variant;
    _animation.duration =
        _opening && _variant == TdsTooltipMotion.strong && !_reduced
        ? TdsMotion.quick.duration + TdsMotion.bounce.duration
        : TdsMotion.medium.duration;
    _animation.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_initialized) {
      _initialized = true;
      _start();
    }
  }

  @override
  void didUpdateWidget(TdsTooltipMotionSurface old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open || old.variant != widget.variant) _start();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      final value = _sample();
      return Opacity(
        opacity: value.opacity,
        child: Transform.scale(
          scale: value.scale,
          alignment: Alignment(
            widget.anchorPositionByRatio * 2 - 1,
            widget.placement.name.startsWith('bottom') ? -1 : 1,
          ),
          child: child,
        ),
      );
    },
  );
}

class TdsTooltipContent extends StatelessWidget {
  const TdsTooltipContent({
    required this.child,
    this.size = TdsTooltipSize.medium,
    this.placement = TdsOverlayPlacement.bottom,
    this.clipToEnd = TdsTooltipClip.none,
    this.anchorPositionByRatio = .5,
    this.messageAlign = TextAlign.left,
    super.key,
  });
  final Widget child;
  final TdsTooltipSize size;
  final TdsOverlayPlacement placement;
  final TdsTooltipClip clipToEnd;
  final double anchorPositionByRatio;
  final TextAlign messageAlign;
  @override
  Widget build(BuildContext context) {
    final small = size == TdsTooltipSize.small,
        top = placement.name.startsWith('top'),
        theme = TdsTheme.of(context);
    final radius = small
        ? 12.0
        : size == TdsTooltipSize.medium
        ? 16.0
        : 18.0;
    final border = Radius.circular(radius),
        color = theme.color('floatBackground');
    return Semantics(
      liveRegion: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 58),
            padding: EdgeInsets.symmetric(
              horizontal: small
                  ? 12
                  : size == TdsTooltipSize.medium
                  ? 16
                  : 20,
              vertical: small ? 8 : 13,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: !top && clipToEnd == TdsTooltipClip.left
                    ? Radius.zero
                    : border,
                topRight: !top && clipToEnd == TdsTooltipClip.right
                    ? Radius.zero
                    : border,
                bottomLeft: top && clipToEnd == TdsTooltipClip.left
                    ? Radius.zero
                    : border,
                bottomRight: top && clipToEnd == TdsTooltipClip.right
                    ? Radius.zero
                    : border,
              ),
              boxShadow: [
                TdsCssBoxShadow(
                  color: theme.color(
                    theme.isDark ? 'greyOpacity900' : 'greyOpacity300',
                  ),
                  blurRadius: 60,
                  offset: Offset(
                    clipToEnd == TdsTooltipClip.none
                        ? 0
                        : clipToEnd == TdsTooltipClip.left
                        ? -20
                        : 20,
                    clipToEnd == TdsTooltipClip.none ? 16 : 6,
                  ),
                ),
              ],
            ),
            child: DefaultTextStyle(
              textAlign: messageAlign,
              style: theme.textStyle(
                typography: small
                    ? TdsTypography.t7
                    : size == TdsTooltipSize.medium
                    ? TdsTypography.t6
                    : TdsTypography.t5,
                fontWeight: small ? TdsFontWeight.semibold : TdsFontWeight.bold,
                color: theme.color('grey800'),
              ),
              child: child is Text && (child as Text).style == null
                  ? TdsLineBox(
                      lineHeight: theme.platform.lineHeight(
                        small
                            ? TdsTypography.t7
                            : size == TdsTooltipSize.medium
                            ? TdsTypography.t6
                            : TdsTypography.t5,
                      ),
                      child: child,
                    )
                  : child,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _TooltipArrow(
                size: size,
                placement: placement,
                clipToEnd: clipToEnd,
                ratio: anchorPositionByRatio,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Original qat SVG silhouettes and FloatingArrow's square SVG coordinate
/// system. Clipped arrows are asymmetric, not a narrowed centered triangle.
class _TooltipArrow extends StatelessWidget {
  const _TooltipArrow({
    required this.size,
    required this.placement,
    required this.clipToEnd,
    required this.ratio,
    required this.color,
  });
  final TdsTooltipSize size;
  final TdsOverlayPlacement placement;
  final TdsTooltipClip clipToEnd;
  final double ratio;
  final Color color;
  static const paths = {
    'none-small':
        'M13.5596838,13.22903875 L20.6626545,19.70673862 C21.5749984,20.53876935 22.7652342,21 24,21 L24,21 L24,21 L0,21 C1.50765571,20.99907116 2.96068864,20.43548861 4.0746657,19.41957439 L10.8643362,13.22903875 C11.6278693,12.53271909 12.7961507,12.53271909 13.5596838,13.22903875 Z M0,21 L24,21 L24,24 L0,24 L0,21 Z',
    'none-medium':
        'M20.1757594,23.9995121 L30.6394015,32.3704257 C32.7671581,34.072631 35.4108841,35 38.1357421,35 L44,35 L44,35 L-7,35 L-0.283003359,35 C2.44185458,35 5.08558063,34.072631 7.21333721,32.3704257 L17.6769793,23.9995121 C18.4074166,23.4151622 19.4453221,23.4151622 20.1757594,23.9995121 Z M0,35 L38,35 L38,38 L0,38 L0,35 Z',
    'left-small':
        'M14,9c-.9,0-1.8-.3-2.5-.8L2.1,1.5c-.9-.6-2.1,0-2.1,1.1v6.5h14Z',
    'left-medium':
        'M19,12c-2.5,0-4.9-.8-6.9-2.4L2.1,1.7C1.3,1,0,1.6,0,2.7v9.3h19Z',
    'right-small':
        'M0,9c.9,0,1.8-.3,2.5-.8L11.9,1.5c.9-.6,2.1,0,2.1,1.1v6.5H0Z',
    'right-medium':
        'M0,12c2.5,0,4.9-.8,6.9-2.4L16.9,1.7c.9-.7,2.1,0,2.1,1v9.3H0Z',
  };
  @override
  Widget build(BuildContext context) {
    final top = placement.name.startsWith('top');
    final small = size == TdsTooltipSize.small;
    // Xat compares exact placements; aligned top-start/end use the normal path.
    final shape =
        (clipToEnd == TdsTooltipClip.left &&
                placement == TdsOverlayPlacement.bottom) ||
            (clipToEnd == TdsTooltipClip.right &&
                placement == TdsOverlayPlacement.top)
        ? 'left'
        : (clipToEnd == TdsTooltipClip.right &&
                  placement == TdsOverlayPlacement.bottom) ||
              (clipToEnd == TdsTooltipClip.left &&
                  placement == TdsOverlayPlacement.top)
        ? 'right'
        : 'none';
    final width = shape == 'none'
        ? (small ? 24.0 : 38.0)
        : (small ? 14.0 : 19.0);
    final translate = shape == 'none' ? 4.0 : (small ? 5.0 : 7.0);
    final path = paths['$shape-${small ? 'small' : 'medium'}']!;
    return LayoutBuilder(
      builder: (context, bounds) {
        final padding = clipToEnd == TdsTooltipClip.none ? 16.0 : 0.0;
        final candidate = bounds.maxWidth * ratio - width / 2;
        // CSS clamp keeps its minimum even when max < min.
        final x = ratio == .5
            ? (bounds.maxWidth - width) / 2
            : math.max(
                padding,
                math.min(candidate, bounds.maxWidth - width - padding),
              );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: x,
              top: top ? null : translate - width,
              bottom: top ? translate - width : null,
              child: Transform.rotate(
                angle: top ? math.pi : 0,
                child: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$width" viewBox="0 0 $width $width"><path d="$path"/></svg>',
                  width: width,
                  height: width,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
