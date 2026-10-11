import 'dart:async';
import 'package:flutter/widgets.dart';
import '../foundation/color.dart';
import '../foundation/line_box.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

enum TdsButtonColor { primary, danger, light, dark }

enum TdsButtonVariant { fill, weak }

enum TdsButtonDisplay { inline, block, full }

enum TdsButtonSize {
  small(13, 8, 52, 32, 10, 5, 3),
  medium(15, 10, 64, 38, 16, 5, 4),
  large(17, 14, 80, 48, 16, 8, 5),
  xlarge(17, 16, 96, 56, 28, 8, 7);

  const TdsButtonSize(
    this.fontSize,
    this.radius,
    this.minWidth,
    this.minHeight,
    this.padding,
    this.loaderSize,
    this.loaderGap,
  );
  final double fontSize,
      radius,
      minWidth,
      minHeight,
      padding,
      loaderSize,
      loaderGap;
}

class TdsButtonColors {
  const TdsButtonColors(
    this.background,
    this.foreground,
    this.dimmer,
    this.gradient,
    this.loader,
  );
  final Color background, foreground, dimmer, gradient, loader;
  factory TdsButtonColors.resolve(
    TdsThemeData theme,
    TdsButtonColor color,
    TdsButtonVariant variant,
  ) {
    final light = theme.colorScheme == TdsColorPreference.light;
    Color fill, text, weak, weakText;
    switch (color) {
      case TdsButtonColor.primary:
        fill = theme.primary;
        text = TdsPalette.whiteOpacity900;
        weak = (light ? TdsPalette.blue300 : TdsPalette.blue600).withValues(
          alpha: light ? .15 : .22,
        );
        weakText = light ? TdsPalette.blue600 : TdsPalette.blue400;
        if (fill != TdsPalette.blue500) {
          final original = fill, lab = TdsOklch.fromColor(fill);
          if (lab.l < .4 || lab.l >= .8) {
            weak = TdsPalette.grey700.withValues(alpha: .07);
            weakText = TdsPalette.grey700;
            text = lab.l >= .8 ? TdsPalette.greyOpacity800 : TdsPalette.white;
          } else {
            final opacity = lab.l <= .525
                ? .08
                : lab.l <= .645
                ? .09
                : lab.l < .7
                ? .11
                : lab.l <= .75
                ? .13
                : .15;
            weak = original.withValues(alpha: opacity);
            weakText = lab.l <= .525 ? original : lab.withLightness(.525);
            if (lab.l > .645) fill = lab.withLightness(.645);
            text = TdsPalette.white;
          }
        }
      case TdsButtonColor.danger:
        fill = TdsPalette.red500;
        text = TdsPalette.whiteOpacity900;
        weak = (light ? TdsPalette.red300 : TdsPalette.red600).withValues(
          alpha: light ? .15 : .22,
        );
        weakText = light ? TdsPalette.red600 : TdsPalette.red400;
      case TdsButtonColor.dark:
        fill = TdsPalette.grey700;
        text = TdsPalette.whiteOpacity900;
        weak = theme.color('greyOpacity100');
        weakText = theme.color('grey700');
      case TdsButtonColor.light:
        fill = TdsPalette.whiteOpacity900;
        text = TdsPalette.blue700;
        weak = TdsPalette.whiteOpacity200;
        weakText = TdsPalette.whiteOpacity900;
    }
    final lab = TdsOklch.fromColor(fill);
    if (variant == TdsButtonVariant.fill) {
      return TdsButtonColors(
        fill,
        text,
        const Color(0xff000000).withValues(alpha: lab.l >= .8 ? .5 : 1),
        lab.withLightness(lab.l - .134),
        lab.l >= .8 ? TdsPalette.greyOpacity600 : TdsPalette.white,
      );
    }
    final primaryLab = TdsOklch.fromColor(theme.primary);
    final neutralPrimary =
        color == TdsButtonColor.primary &&
        (primaryLab.l >= .8 || primaryLab.l < .4);
    final dim = neutralPrimary ? TdsPalette.grey700 : fill;
    return TdsButtonColors(
      weak,
      weakText,
      dim,
      dim,
      neutralPrimary || light ? dim : lab.withLightness(.7),
    );
  }
}

class TdsButton extends StatelessWidget {
  const TdsButton({
    required this.child,
    this.onPressed,
    this.color = TdsButtonColor.primary,
    this.variant = TdsButtonVariant.fill,
    this.display = TdsButtonDisplay.inline,
    this.size = TdsButtonSize.xlarge,
    this.loading = false,
    this.disabled = false,
    this.inert = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final TdsButtonColor color;
  final TdsButtonVariant variant;
  final TdsButtonDisplay display;
  final TdsButtonSize size;
  final bool loading, disabled, inert, autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final colors = TdsButtonColors.resolve(theme, color, variant);
    final font = TdsTypography.values.firstWhere(
      (t) => t.baseSize == size.fontSize,
    );
    final vertical =
        size == TdsButtonSize.xlarge && display == TdsButtonDisplay.inline
        ? 15.0
        : 2.0;
    return ExcludeSemantics(
      excluding: inert,
      child: TdsPressable(
        enabled: !disabled && !loading && !inert,
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        focusNode: focusNode,
        autofocus: autofocus,
        activateOnEnterDown: true,
        keyboardPressEffect: false,
        builder: (context, pressed, hovered, focused) {
          final motion = pressed ? TdsMotion.rapid : TdsMotion.quick;
          return AnimatedScale(
            scale: pressed && display != TdsButtonDisplay.full ? .96 : 1,
            duration: motion.duration,
            curve: motion,
            child: AnimatedOpacity(
              opacity: disabled && variant == TdsButtonVariant.fill ? .3 : 1,
              duration: TdsMotion.quick.duration,
              curve: TdsMotion.quick,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  display == TdsButtonDisplay.full ? 0 : size.radius,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: colors.background),
                    ),
                    SizedBox(
                      width: display == TdsButtonDisplay.inline
                          ? null
                          : double.infinity,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: size.minWidth,
                          minHeight: size.minHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: size.padding,
                            vertical: vertical,
                          ),
                          child: Center(
                            widthFactor: display == TdsButtonDisplay.inline
                                ? 1
                                : null,
                            heightFactor: 1,
                            child: _ButtonLabelOpacity(
                              opacity: loading
                                  ? 0
                                  : disabled && variant == TdsButtonVariant.weak
                                  ? .3
                                  : 1,
                              delay: !loading && !disabled
                                  ? const Duration(milliseconds: 100)
                                  : Duration.zero,
                              child: DefaultTextStyle(
                                style: theme
                                    .textStyle(
                                      typography: font,
                                      fontWeight: TdsFontWeight.semibold,
                                      color: colors.foreground,
                                    )
                                    .copyWith(height: 1.252),
                                textAlign: TextAlign.center,
                                child:
                                    child is Text &&
                                        (child as Text).style == null &&
                                        (child as Text).data != null
                                    ? TdsLineBox(
                                        lineHeight:
                                            theme.platform.size(font) * 1.252,
                                        child: child,
                                      )
                                    : child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _LoadingGlow(
                          loading: loading,
                          color: colors.gradient,
                          maxOpacity: variant == TdsButtonVariant.fill
                              ? (disabled ? .2 : .7)
                              : (disabled ? .14 : .24),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _ButtonLoaderPresence(
                        loading: loading,
                        opacity: disabled && variant == TdsButtonVariant.weak
                            ? .4
                            : 1,
                        size: size,
                        color: colors.loader,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: motion.duration,
                          curve: motion,
                          color: colors.dimmer.withValues(
                            alpha: pressed
                                ? colors.dimmer.a * .26
                                : loading && !disabled
                                ? .26 * .13
                                : 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The source's initial label variant waits 100ms. A new state cancels that
/// delay and transitions from the current opacity, including during loading.
class _ButtonLabelOpacity extends StatefulWidget {
  const _ButtonLabelOpacity({
    required this.opacity,
    required this.delay,
    required this.child,
  });
  final double opacity;
  final Duration delay;
  final Widget child;
  @override
  State<_ButtonLabelOpacity> createState() => _ButtonLabelOpacityState();
}

class _ButtonLabelOpacityState extends State<_ButtonLabelOpacity>
    with SingleTickerProviderStateMixin {
  late final _opacity = AnimationController(vsync: this, value: widget.opacity);
  Timer? _delay;

  @override
  void didUpdateWidget(_ButtonLabelOpacity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opacity == widget.opacity &&
        oldWidget.delay == widget.delay) {
      return;
    }
    _delay?.cancel();
    _opacity.stop();
    if (_opacity.value == widget.opacity) return;
    void animate() => _opacity.animateTo(
      widget.opacity,
      duration: TdsMotion.quick.duration,
      curve: TdsMotion.quick,
    );
    if (widget.delay == Duration.zero) {
      animate();
    } else {
      _delay = Timer(widget.delay, animate);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

/// Keep the original dot instances alive through their exit, including an
/// interrupted exit. Like AnimatePresence, remove them only after fading out.
class _ButtonLoaderPresence extends StatefulWidget {
  const _ButtonLoaderPresence({
    required this.loading,
    required this.opacity,
    required this.size,
    required this.color,
  });
  final bool loading;
  final double opacity;
  final TdsButtonSize size;
  final Color color;
  @override
  State<_ButtonLoaderPresence> createState() => _ButtonLoaderPresenceState();
}

class _ButtonLoaderPresenceState extends State<_ButtonLoaderPresence> {
  late bool _present = widget.loading;
  @override
  void didUpdateWidget(_ButtonLoaderPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading) _present = true;
  }

  @override
  Widget build(BuildContext context) => !_present
      ? const SizedBox.shrink()
      : Center(
          child: AnimatedOpacity(
            opacity: widget.loading ? widget.opacity : 0,
            duration: TdsMotion.quick.duration,
            curve: TdsMotion.quick,
            onEnd: () {
              if (!widget.loading && mounted) setState(() => _present = false);
            },
            child: Semantics(
              liveRegion: true,
              label: 'loading',
              child: ExcludeSemantics(
                child: TdsButtonLoader(
                  size: widget.size.loaderSize,
                  gap: widget.size.loaderGap,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
}

class TdsButtonLoader extends StatefulWidget {
  const TdsButtonLoader({
    required this.size,
    required this.gap,
    required this.color,
    super.key,
  });
  final double size, gap;
  final Color color;
  @override
  State<TdsButtonLoader> createState() => _TdsButtonLoaderState();
}

class _TdsButtonLoaderState extends State<TdsButtonLoader>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: widget.gap,
      children: List.generate(3, (i) {
        final time =
            (_controller.lastElapsedDuration?.inMicroseconds ?? 0) / 1000000 -
            i * .1;
        final phase = time <= 0 ? 0.0 : (time % .6) / .3;
        final value = Curves.easeInOut.transform(
          phase <= 1 ? phase : 2 - phase,
        );
        return Opacity(
          opacity: .2 + .8 * value,
          child: Transform.scale(
            scale: .8 + .2 * value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class _LoadingGlow extends StatefulWidget {
  const _LoadingGlow({
    required this.loading,
    required this.color,
    required this.maxOpacity,
  });
  final bool loading;
  final Color color;
  final double maxOpacity;
  @override
  State<_LoadingGlow> createState() => _LoadingGlowState();
}

class _LoadingGlowState extends State<_LoadingGlow>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _pulsing = false;
  double _fadeFrom = 0;

  double _opacity(double maximum) => _pulsing
      ? TdsMotion.out.transform(_controller.value) * maximum
      : _fadeFrom * (1 - TdsMotion.quick.transform(_controller.value));

  void _pulse() {
    _pulsing = true;
    _controller
      ..stop()
      ..duration = const Duration(milliseconds: 600)
      ..value = 0
      ..repeat(reverse: true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.loading) _pulse();
  }

  @override
  void didUpdateWidget(_LoadingGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading &&
        (!oldWidget.loading || oldWidget.maxOpacity != widget.maxOpacity)) {
      _pulse();
    } else if (!widget.loading && oldWidget.loading) {
      _fadeFrom = _opacity(oldWidget.maxOpacity);
      _pulsing = false;
      _controller
        ..stop()
        ..duration = TdsMotion.quick.duration
        ..forward(from: 0);
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
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final dimension = constraints.maxWidth * 1.05;
        return OverflowBox(
          maxHeight: dimension,
          maxWidth: dimension,
          child: Opacity(
            opacity: _opacity(widget.maxOpacity),
            child: Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [widget.color, widget.color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class TdsCTAButton extends StatefulWidget {
  const TdsCTAButton({
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
    this.display = TdsButtonDisplay.block,
    super.key,
  });
  final Widget child;
  final Widget? disabledChild;
  final VoidCallback? onPressed;
  final bool disabled, loading, inert, autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;
  final TdsButtonColor color;
  final TdsButtonVariant variant;
  final TdsButtonDisplay display;
  @override
  State<TdsCTAButton> createState() => _TdsCTAButtonState();
}

class _TdsCTAButtonState extends State<TdsCTAButton>
    with SingleTickerProviderStateMixin {
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  // ge.wiggle({type:'small', direction:'x'}): four linear 87.5ms segments.
  static final _wiggleOffset = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 2), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 2, end: -2), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -2, end: 1), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
  ]);
  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    excludeFromSemantics: true,
    onTap: widget.disabled && !widget.inert
        ? () {
            if (!_wiggle.isAnimating &&
                !MediaQuery.disableAnimationsOf(context)) {
              _wiggle.forward(from: 0);
            }
          }
        : null,
    child: AnimatedBuilder(
      animation: _wiggle,
      builder: (context, child) => Transform.translate(
        offset: Offset(_wiggleOffset.transform(_wiggle.value), 0),
        child: child,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.disabled
              ? TdsTheme.of(context).color('background')
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(
            widget.display == TdsButtonDisplay.full ? 0 : 16,
          ),
        ),
        child: TdsButton(
          onPressed: widget.onPressed,
          disabled: widget.disabled,
          loading: widget.loading,
          inert: widget.inert,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          semanticLabel: widget.semanticLabel,
          display: widget.display,
          color: widget.color,
          variant: widget.variant,
          child: widget.disabled
              ? widget.disabledChild ?? widget.child
              : widget.child,
        ),
      ),
    ),
  );
}
