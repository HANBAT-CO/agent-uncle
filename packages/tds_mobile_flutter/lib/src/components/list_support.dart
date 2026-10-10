import 'package:flutter/widgets.dart';
import '../foundation/activation_scope.dart';
import '../foundation/color_motion_dependencies.g.dart';
import '../foundation/host.dart';
import '../foundation/line_box.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/raw_press_region.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/touch_inset.dart';
import '../foundation/word_break.dart';
import 'asset.dart';
import 'list.dart';
import 'text.dart';
import 'collections.dart';
import 'icon_button.dart';
import 'text_button.dart';

enum TdsListHeaderSize { large, medium, small, xsmall }

enum TdsListHeaderVerticalPadding { small, medium }

enum TdsListHeaderDescriptionPosition { top, bottom }

enum TdsListHeaderRightAlignment { center, bottom }

class TdsListHeader extends StatelessWidget {
  const TdsListHeader({
    required this.title,
    this.description,
    this.right,
    this.size = TdsListHeaderSize.medium,
    this.titleWidthRatio = .6,
    this.fillTitle = false,
    this.descriptionPosition = TdsListHeaderDescriptionPosition.top,
    this.rightAlignment = TdsListHeaderRightAlignment.center,
    this.verticalPadding = TdsListHeaderVerticalPadding.medium,
    this.horizontalPadding = TdsListHorizontalPadding.medium,
    this.a11yRightReflow = true,
    super.key,
  }) : assert(titleWidthRatio >= 0 && titleWidthRatio <= 1);
  final Widget title;
  final Widget? description, right;
  final TdsListHeaderSize size;
  final double titleWidthRatio;
  final bool fillTitle, a11yRightReflow;
  final TdsListHeaderDescriptionPosition descriptionPosition;
  final TdsListHeaderRightAlignment rightAlignment;
  final TdsListHeaderVerticalPadding verticalPadding;
  final TdsListHorizontalPadding horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = TdsTheme.of(context).platform.fontScale;
    final reflow =
        a11yRightReflow &&
        ((width <= 360 && scale >= 135) ||
            (width > 360 && width < 560 && scale >= 160));
    final ratio = scale >= 200 ? .5 : titleWidthRatio;
    final compact = verticalPadding == TdsListHeaderVerticalPadding.small;
    final row = right == null
        ? title
        : reflow
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 4), right!],
          )
        : fillTitle
        ? Row(
            crossAxisAlignment:
                rightAlignment == TdsListHeaderRightAlignment.bottom
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              right!,
            ],
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth - 8;
              return Row(
                crossAxisAlignment:
                    rightAlignment == TdsListHeaderRightAlignment.bottom
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center,
                children: [
                  SizedBox(width: available * ratio, child: title),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: available * (1 - ratio),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: right,
                    ),
                  ),
                ],
              );
            },
          );
    final children = [
      description ?? const SizedBox.shrink(),
      SizedBox(height: compact ? 0 : 4),
      row,
    ];
    return _HeaderScope(
      size: size,
      reflow: reflow,
      rightAlignment: rightAlignment,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding == TdsListHorizontalPadding.small ? 20 : 24,
          compact ? 16 : 24,
          horizontalPadding == TdsListHorizontalPadding.small ? 20 : 24,
          compact ? 4 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: descriptionPosition == TdsListHeaderDescriptionPosition.top
              ? children
              : children.reversed.toList(),
        ),
      ),
    );
  }
}

class _HeaderScope extends InheritedWidget {
  const _HeaderScope({
    required this.size,
    required this.reflow,
    required this.rightAlignment,
    required super.child,
  });
  final TdsListHeaderSize size;
  final bool reflow;
  final TdsListHeaderRightAlignment rightAlignment;
  static _HeaderScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeaderScope>();
  @override
  bool updateShouldNotify(_HeaderScope oldWidget) =>
      size != oldWidget.size ||
      reflow != oldWidget.reflow ||
      rightAlignment != oldWidget.rightAlignment;
}

TdsTypography _titleType(TdsListHeaderSize size) => const [
  TdsTypography.t4,
  TdsTypography.t5,
  TdsTypography.t6,
  TdsTypography.t7,
][size.index];
TdsFontWeight _titleWeight(TdsListHeaderSize size) => const [
  TdsFontWeight.bold,
  TdsFontWeight.bold,
  TdsFontWeight.medium,
  TdsFontWeight.regular,
][size.index];
TdsTypography _rightType(TdsListHeaderSize size) =>
    size.index < 2 ? TdsTypography.t6 : TdsTypography.t7;

class TdsListHeaderTitleParagraph extends StatelessWidget {
  const TdsListHeaderTitleParagraph(
    this.text, {
    this.typography,
    this.fontWeight,
    this.color,
    super.key,
  });
  final String text;
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final size = _HeaderScope.of(context)?.size ?? TdsListHeaderSize.medium;
    return Semantics(
      header: true,
      child: TdsText(
        text,
        typography: typography ?? _titleType(size),
        fontWeight: fontWeight ?? _titleWeight(size),
        color: color ?? TdsTheme.of(context).color('grey800'),
      ),
    );
  }
}

class TdsListHeaderTitleSelector extends StatelessWidget {
  const TdsListHeaderTitleSelector({
    required this.text,
    this.onPressed,
    this.typography,
    this.fontWeight,
    this.color,
    this.disabled = false,
    super.key,
  });
  final String text;
  final VoidCallback? onPressed;
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    final size = _HeaderScope.of(context)?.size ?? TdsListHeaderSize.medium;
    return TdsSelector(
      text: text,
      typography: typography ?? _titleType(size),
      fontWeight: fontWeight ?? _titleWeight(size),
      color: color ?? TdsTheme.of(context).color('grey800'),
      type: TdsSelectorType.arrow,
      onPressed: onPressed,
      disabled: disabled,
    );
  }
}

class TdsListHeaderRightIconButton extends StatelessWidget {
  const TdsListHeaderRightIconButton({
    required this.semanticLabel,
    this.name,
    this.child,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.variant = TdsIconButtonVariant.clear,
    this.iconSize,
    this.disabled = false,
    this.focusNode,
    super.key,
  }) : assert(name != null || child != null);
  final String semanticLabel;
  final String? name;
  final Widget? child;
  final VoidCallback? onPressed;
  final Color? color, backgroundColor;
  final TdsIconButtonVariant variant;
  final double? iconSize;
  final bool disabled;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final scope = _HeaderScope.of(context);
    final headerSize = scope?.size ?? TdsListHeaderSize.medium;
    final size = iconSize ?? (headerSize.index < 2 ? 20.0 : 16.0);
    final padding = size >= 18 && size <= 20 ? 9.0 : size / 2;
    // The source wrapper contributes no height before reflow; the button is
    // translated around the title line. Retain a native hit-testable line box
    // without enlarging the standard header title. Taller custom title slots
    // still determine the row height.
    final line = TdsTheme.of(
      context,
    ).platform.lineHeight(_titleType(headerSize));
    final excess = scope == null || scope.reflow
        ? 0.0
        : (size + 2 * padding - line).clamp(0.0, double.infinity);
    final bottomAligned =
        scope?.rightAlignment == TdsListHeaderRightAlignment.bottom;
    return TdsTouchInset(
      insets: EdgeInsets.only(
        right: padding,
        top: bottomAligned ? excess : excess / 2,
        bottom: bottomAligned ? 0 : excess / 2,
      ),
      child: TdsIconButton(
        semanticLabel: semanticLabel,
        name: name,
        onPressed: onPressed,
        color: color ?? TdsTheme.of(context).color('grey600'),
        backgroundColor: backgroundColor,
        variant: variant,
        iconSize: size,
        disabled: disabled,
        focusNode: focusNode,
        child: child,
      ),
    );
  }
}

class TdsListFooterHairline extends StatelessWidget {
  const TdsListFooterHairline({this.indent, this.indented, super.key});
  final double? indent;
  final bool? indented;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left:
              indent ??
              (indented == null
                  ? _FooterScope.of(context)?.hairlineIndent ?? 0
                  : indented!
                  ? 24
                  : 0),
          child: const TdsBorder(),
        ),
      ],
    ),
  );
}

class TdsListFooterShadow extends StatefulWidget {
  const TdsListFooterShadow({this.visible, this.height, super.key});
  final bool? visible;
  final double? height;
  @override
  State<TdsListFooterShadow> createState() => _TdsListFooterShadowState();
}

class _TdsListFooterShadowState
    extends _FooterScalarState<TdsListFooterShadow> {
  @override
  bool get isScale => false;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: scalar(
        context,
        cssValue: widget.visible == true ? 1 : 0,
      ).clamp(0, 1),
      duration: widget.visible == null && _FooterScope.of(context) != null
          ? Duration.zero
          : TdsMotion.rapid.duration,
      curve: TdsMotion.rapid,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height:
              widget.height ??
              (constraints.hasBoundedHeight ? constraints.maxHeight : 16),
          child: CustomPaint(
            painter: TdsListFooterShadowPainter(
              color: TdsTheme.of(context).isDark
                  ? TdsPalette.whiteOpacity50
                  : TdsPalette.grey100,
            ),
            child: const SizedBox(width: double.infinity),
          ),
        ),
      ),
    ),
  );
}

class TdsListFooterShadowPainter extends CustomPainter {
  const TdsListFooterShadowPainter({required this.color});
  final Color color;

  /// Qne is 120% wide and padding-bottom:100% of the containing width.
  Rect bounds(Size parent) {
    // The percentage width is resolved to a layout unit before translateX(-50%).
    // Keeping 120% as an unrounded double shifts both ellipse edges at fractional
    // widths (342px -> 410.390625px, not 410.4px).
    final width = tdsCssLineHeight(parent.width * 1.2);
    return Rect.fromLTWH(
      tdsCssLineHeight(parent.width / 2) - width / 2,
      -parent.width / 2,
      width,
      parent.width,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = bounds(size);
    canvas.save();
    // closest-side is an ellipse with radii .6w/.5w, not a circular shader.
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(rect.width / rect.height, 1);
    final circle = Rect.fromCircle(
      center: Offset.zero,
      radius: rect.height / 2,
    );
    canvas.drawRect(
      circle,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(circle),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(TdsListFooterShadowPainter old) => color != old.color;
}

class TdsListHeaderDescriptionParagraph extends StatelessWidget {
  const TdsListHeaderDescriptionParagraph(
    this.text, {
    this.typography,
    this.fontWeight = TdsFontWeight.regular,
    this.color,
    super.key,
  });
  final String text;
  final TdsTypography? typography;
  final TdsFontWeight fontWeight;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final size = _HeaderScope.of(context)?.size ?? TdsListHeaderSize.medium;
    return TdsText(
      text,
      typography:
          typography ??
          switch (size) {
            TdsListHeaderSize.large => TdsTypography.t7,
            TdsListHeaderSize.medium => TdsTypography.st12,
            _ => TdsTypography.st10,
          },
      fontWeight: fontWeight,
      color: color ?? TdsTheme.of(context).color('grey600'),
    );
  }
}

class TdsListHeaderRightText extends StatelessWidget {
  const TdsListHeaderRightText(
    this.text, {
    this.typography,
    this.color,
    super.key,
  });
  final String text;
  final TdsTypography? typography;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scope = _HeaderScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: TdsText(
        text,
        typography:
            typography ?? _rightType(scope?.size ?? TdsListHeaderSize.medium),
        color: color ?? TdsTheme.of(context).color('grey700'),
        textAlign: scope?.reflow == true ? TextAlign.start : TextAlign.right,
      ),
    );
  }
}

class TdsListHeaderTitleTextButton extends StatelessWidget {
  const TdsListHeaderTitleTextButton({
    required this.child,
    this.onPressed,
    this.disabled = false,
    this.variant = TdsTextButtonVariant.underline,
    this.size,
    this.fontWeight,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled;
  final TdsTextButtonVariant variant;
  final TdsTextButtonSize? size;
  final TdsFontWeight? fontWeight;
  @override
  Widget build(BuildContext context) {
    final headerSize =
        _HeaderScope.of(context)?.size ?? TdsListHeaderSize.medium;
    return TdsTextButton(
      onPressed: onPressed,
      disabled: disabled,
      variant: variant,
      color: TdsTheme.of(context).color('grey800'),
      fontWeight: fontWeight ?? _titleWeight(headerSize),
      size:
          size ??
          TdsTextButtonSize.values.firstWhere((s) => s.name == headerSize.name),
      child: child,
    );
  }
}

class TdsListHeaderRightArrow extends StatelessWidget {
  const TdsListHeaderRightArrow({
    this.child,
    this.onPressed,
    this.color,
    this.textColor,
    this.typography,
    super.key,
  });
  final Widget? child;
  final VoidCallback? onPressed;
  final Color? color, textColor;
  final TdsTypography? typography;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final type =
        typography ??
        _rightType(_HeaderScope.of(context)?.size ?? TdsListHeaderSize.medium);
    return TdsTouchInset(
      insets: const EdgeInsets.only(right: 8),
      child: TdsPressable(
        onPressed: onPressed,
        onPressStart: onPressed == null
            ? null
            : () => tdsHapticOf(context).generate(TdsHapticType.tickWeak),
        builder: (_, pressed, hovered, focused) => AnimatedScale(
          scale: pressed && onPressed != null ? .94 : 1,
          duration: pressed
              ? TdsMotion.rapid.duration
              : TdsMotion.quick.duration,
          curve: pressed ? TdsMotion.rapid : TdsMotion.quick,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -3,
                bottom: -3,
                left: -8,
                right: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: pressed && onPressed != null
                        ? theme.color('greyOpacity100')
                        : const Color(0x00000000),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (child != null)
                      Flexible(
                        child: DefaultTextStyle(
                          style: theme.textStyle(
                            typography: type,
                            color: textColor ?? theme.color('grey700'),
                          ),
                          child: child!,
                        ),
                      ),
                    const SizedBox(width: 4),
                    TdsAssetIcon(
                      name: 'icon-arrow-right-mono',
                      color: color ?? theme.color('grey400'),
                      frameShape: const TdsAssetFrameShape(
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TdsListFooterBorder { full, indented, none }

class TdsListFooter extends StatefulWidget {
  const TdsListFooter({
    required this.child,
    this.onPressed,
    this.icon,
    this.iconName,
    this.border = TdsListFooterBorder.full,
    this.hairline,
    this.shadow,
    this.textColor,
    this.iconColor,
    this.textColorToken,
    this.iconColorToken,
    super.key,
  }) : assert(icon == null || iconName == null),
       assert(textColor == null || textColorToken == null),
       assert(iconColor == null || iconColorToken == null);
  final Widget child;
  final Widget? icon, hairline, shadow;
  final VoidCallback? onPressed;
  final TdsListFooterBorder border;
  final Color? textColor, iconColor;

  /// Token identity is retained for adaptive pressed colors. Literal colors
  /// remain static; parent color props are initial values, as in the source.
  final String? textColorToken, iconColorToken;

  /// Native counterpart of the source's string icon shorthand, which follows
  /// the registered text color rather than the independent icon color.
  final String? iconName;
  @override
  State<TdsListFooter> createState() => _TdsListFooterState();
}

class _TdsListFooterState extends State<TdsListFooter>
    with SingleTickerProviderStateMixin {
  late _FooterInk _textInk, _iconInk;
  late final _colorMotion = AnimationController(
    vsync: this,
    duration: TdsMotion.rapid.duration,
  )..addListener(_advanceMotion);
  final _targets = <_FooterColorTarget>{};
  final _shapes = <_FooterScalarTarget>{};
  final _pressTimeline = _FooterTimeline(pressed: true);
  final _releaseTimeline = _FooterTimeline(pressed: false);
  _FooterTimeline? _activeTimeline;
  TdsActivationController? _parentActivation;
  late final _descendantActivation = TdsActivationController((source) {
    widget.onPressed?.call();
    _parentActivation?.activate(source);
  });
  bool? _lastDark;
  int _motionRevision = 0;

  @override
  void initState() {
    super.initState();
    _textInk = _FooterInk(widget.textColor, widget.textColorToken ?? 'blue500');
    _iconInk = _FooterInk(widget.iconColor, widget.iconColorToken ?? 'blue500');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parentActivation = TdsActivationScope.maybeOf(context);
    final dark = TdsTheme.of(context).isDark;
    if (_lastDark != null && dark != _lastDark) {
      // iie keys its provider subtree by color scheme. Child registrations and
      // inline motion styles remount, while the parent's useState colors stay.
      _colorMotion.stop();
      _activeTimeline = null;
      _pressTimeline.clear();
      _releaseTimeline.clear();
      _motionRevision = 0;
    }
    _lastDark = dark;
  }

  void _registerText(_FooterInk ink) {
    if (mounted && _textInk != ink) setState(() => _textInk = ink);
  }

  void _registerIcon(_FooterInk ink) {
    if (mounted && _iconInk != ink) setState(() => _iconInk = ink);
  }

  void _detachTarget(_FooterColorTarget target) {
    _targets.remove(target);
    for (final timeline in [_pressTimeline, _releaseTimeline]) {
      timeline.targets.remove(target);
      timeline.saves.remove(target);
      timeline.tweens.remove(target);
    }
  }

  void _detachShape(_FooterScalarTarget target) {
    _shapes.remove(target);
    for (final timeline in [_pressTimeline, _releaseTimeline]) {
      timeline.shapes.remove(target);
      timeline.shapeSaves.remove(target);
      timeline.shapeTweens.remove(target);
    }
  }

  void _configureMotion(_FooterTimeline timeline, Object dependencies) {
    if (timeline == _activeTimeline) {
      _colorMotion.stop();
      _activeTimeline = null;
    }
    // wt creates two GSAP contexts. Cleanup is ordered: press, then release.
    // Recreate only this context: an unchanged release keeps its clock, target
    // snapshot and saved styles even while press cleanup writes to its targets.
    for (final entry in timeline.saves.entries) {
      // GSAP restores ordinary color but removes the --icon-color variable.
      entry.key.inlineColor = entry.key.icon ? null : entry.value;
    }
    for (final entry in timeline.shapeSaves.entries) {
      entry.key.inlineValue = entry.value;
    }
    timeline.clear();
    timeline.dependencies = dependencies;
    _motionRevision++;
    final generation = timeline.generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != timeline.generation) return;
      // Each context has its OWN selector snapshot. A press-only dependency
      // change may include new children without enrolling them in release.
      timeline.targets = _targets.toList();
      timeline.shapes = _shapes.toList();
    });
  }

  void _press(bool pressed) {
    _colorMotion.stop();
    final timeline = pressed ? _pressTimeline : _releaseTimeline;
    final restartAtNonzeroTime = timeline.playhead > 0;
    timeline.saves.clear();
    timeline.tweens.clear();
    timeline.shapeSaves.clear();
    timeline.shapeTweens.clear();
    timeline.playhead = 0;
    _activeTimeline = timeline;
    // GSAP invalidate().restart() at an untouched zero playhead is lazy.
    // A down/up pair before the first tick must not invent inline press styles
    // for the release context to save. Rewinding an advanced timeline does
    // render immediately, even when that restart is interrupted in this turn.
    timeline.pending = !restartAtNonzeroTime;
    if (restartAtNonzeroTime) {
      _initializeMotion(timeline);
      _renderMotion(timeline, 0);
    }
    setState(() => _motionRevision++);
    _colorMotion.forward(from: 0);
  }

  void _advanceMotion() {
    final timeline = _activeTimeline;
    if (timeline == null) return;
    timeline.playhead = _colorMotion.value;
    if (timeline.pending) {
      if (_colorMotion.value == 0) return;
      timeline.pending = false;
      _initializeMotion(timeline);
    }
    _renderMotion(timeline, TdsMotion.rapid.transform(_colorMotion.value));
    _motionRevision++;
  }

  void _initializeMotion(_FooterTimeline timeline) {
    final theme = TdsTheme.of(context);
    final pressed = timeline.pressed;
    for (final target in timeline.targets) {
      final previousInline = target.inlineColor;
      timeline.saves[target] = previousInline;
      final ink = target.icon ? _iconInk : _textInk;
      final current =
          previousInline ??
          (target.icon ? const Color(0x00000000) : target.cssColor);
      // tie specifies from on press; release starts at the rendered value.
      // An unset custom property is different from the SVG's CSS fallback:
      // GSAP interpolates the missing --icon-color from transparent black.
      timeline.tweens[target] = ColorTween(
        begin: pressed ? ink.resolve(theme) : current,
        // aa can return undefined (disabledBlue500 -> disabledBlue600).
        // j4 then creates GSAP.from, not a static or omitted color tween.
        // Its destination is this target's current rendered property, including
        // transparent black for an unset --icon-color custom property.
        end: pressed
            ? ink.resolvePressed(theme) ?? current
            : ink.resolve(theme),
      );
    }
    for (final target in timeline.shapes) {
      timeline.shapeSaves[target] = target.inlineValue;
      timeline.shapeTweens[target] = Tween<double>(
        begin: pressed ? (target.scale ? 1 : 0) : target.value,
        end: target.scale ? (pressed ? .96 : 1) : (pressed ? 1 : 0),
      );
    }
  }

  void _renderMotion(_FooterTimeline timeline, double progress) {
    // Styles are written on a tick, not derived every time they're read. A
    // different context may revert them between ticks without destroying this
    // timeline's interpolation; its next tick writes the retained tween again.
    for (final entry in timeline.tweens.entries) {
      entry.key.render(entry.value.lerp(progress)!);
    }
    for (final entry in timeline.shapeTweens.entries) {
      entry.key.inlineValue = entry.value.transform(progress);
    }
  }

  @override
  void dispose() {
    _descendantActivation.dispose();
    _colorMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final parentScope = _FooterScope.of(context);
    final normalText = _textInk.motionDependency(theme);
    final normalIcon = _iconInk.motionDependency(theme);
    final pressDependencies = (
      normalText,
      normalIcon,
      _textInk.motionDependency(theme, pressed: true),
      _iconInk.motionDependency(theme, pressed: true),
    );
    final releaseDependencies = (normalText, normalIcon);
    if (_pressTimeline.dependencies != pressDependencies) {
      _configureMotion(_pressTimeline, pressDependencies);
    }
    if (_releaseTimeline.dependencies != releaseDependencies) {
      _configureMotion(_releaseTimeline, releaseDependencies);
    }
    final child = widget.child, onPressed = widget.onPressed;
    final border = widget.border,
        hairline = widget.hairline,
        shadow = widget.shadow;
    final icon =
        widget.icon ??
        (widget.iconName == null
            ? null
            : TdsListFooterIcon(
                name: widget.iconName!,
                color: _textInk.literal,
                colorToken: _textInk.literal == null ? _textInk.token : null,
              ));
    Widget body() => _FooterScope(
      owner: this,
      parent: parentScope,
      textInk: _textInk,
      iconInk: _iconInk,
      registerText: _registerText,
      registerIcon: _registerIcon,
      motionValue: _colorMotion.value,
      motionRevision: _motionRevision,
      hairlineIndent: border == TdsListFooterBorder.indented ? 24 : 0,
      child: TdsActivationScope(
        controller: _descendantActivation,
        child: ClipRect(
          child: ColoredBox(
            color: theme.color('background'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 59),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (border != TdsListFooterBorder.none)
                      hairline ?? const TdsListFooterHairline(),
                    Expanded(
                      child: _FooterContent(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (onPressed != null)
                              Positioned.fill(
                                child: shadow ?? const TdsListFooterShadow(),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: child is Text
                                        ? TdsListFooterText(child: child)
                                        : child,
                                  ),
                                  ?icon,
                                ],
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
    );
    return KeyedSubtree(
      key: ValueKey(theme.isDark),
      child: TdsRawPressRegion(
        onPressStart: (_, firstTouch) => _press(true),
        onPressEnd: () => _press(false),
        // Source tie supplies no onPressCancel; a cancelled touch retains the
        // pressed appearance until another accepted press/end or theme remount.
        child: TdsPressable(
          button: onPressed != null,
          skipTraversal: onPressed == null,
          keyboardActivation: false,
          onPressed: onPressed,
          builder: (_, pressed, hovered, focused) => AnimatedBuilder(
            animation: _colorMotion,
            builder: (_, child) => body(),
          ),
        ),
      ),
    );
  }
}

class _FooterTimeline {
  _FooterTimeline({required this.pressed});
  final bool pressed;
  Object? dependencies;
  int generation = 0;
  List<_FooterColorTarget> targets = [];
  final saves = <_FooterColorTarget, Color?>{};
  final tweens = <_FooterColorTarget, ColorTween>{};
  List<_FooterScalarTarget> shapes = [];
  final shapeSaves = <_FooterScalarTarget, double?>{};
  final shapeTweens = <_FooterScalarTarget, Tween<double>>{};
  double playhead = 0;
  bool pending = false;

  void clear() {
    generation++;
    dependencies = null;
    targets = [];
    saves.clear();
    tweens.clear();
    shapes = [];
    shapeSaves.clear();
    shapeTweens.clear();
    playhead = 0;
    pending = false;
  }
}

@immutable
class _FooterInk {
  const _FooterInk(this.literal, this.token);
  final Color? literal;
  final String token;

  String? motionDependency(TdsThemeData theme, {bool pressed = false}) {
    if (literal == null) {
      final source = tdsAdaptiveMotionDependencies[token];
      if (source != null) {
        if (pressed) return theme.isDark ? source.$4 : source.$3;
        return theme.isDark ? source.$2 : source.$1;
      }
    }
    final color = resolve(theme);
    final source = color.a == 1
        ? '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}'
        : 'rgba(${(color.r * 255).round()},${(color.g * 255).round()},${(color.b * 255).round()},${color.a})';
    return pressed ? tdsStaticMotionDependencies[source] ?? source : source;
  }

  Color resolve(TdsThemeData theme) => literal ?? theme.color(token);

  Color? resolvePressed(TdsThemeData theme) {
    if (literal != null) return tdsStaticPressColors[literal] ?? literal!;
    if (motionDependency(theme, pressed: true) == null) return null;
    final match = RegExp(r'^([^\d]+)(50|[1-9]00)$').firstMatch(token);
    if (match == null) return theme.color(token);
    const levels = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
    final index = levels.indexOf(int.parse(match[2]!));
    return theme.color('${match[1]}${levels[(index + 1).clamp(0, 9)]}');
  }

  @override
  bool operator ==(Object other) =>
      other is _FooterInk &&
      literal == other.literal &&
      (literal != null || token == other.token);
  @override
  int get hashCode => literal?.hashCode ?? token.hashCode;
}

class _FooterScope extends InheritedWidget {
  const _FooterScope({
    required this.owner,
    required this.parent,
    required this.textInk,
    required this.iconInk,
    required this.registerText,
    required this.registerIcon,
    required this.motionValue,
    required this.motionRevision,
    required this.hairlineIndent,
    required super.child,
  });
  final _TdsListFooterState owner;
  final _FooterScope? parent;
  Iterable<_TdsListFooterState> get owners sync* {
    yield owner;
    if (parent != null) yield* parent!.owners;
  }

  final _FooterInk textInk, iconInk;
  final ValueChanged<_FooterInk> registerText, registerIcon;
  final double motionValue;
  final int motionRevision;
  final double hairlineIndent;
  static _FooterScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FooterScope>();
  @override
  bool updateShouldNotify(_FooterScope oldWidget) =>
      owner != oldWidget.owner ||
      parent != oldWidget.parent ||
      textInk != oldWidget.textInk ||
      iconInk != oldWidget.iconInk ||
      motionValue != oldWidget.motionValue ||
      motionRevision != oldWidget.motionRevision ||
      hairlineIndent != oldWidget.hairlineIndent;
}

// Selectors walk every matching DOM descendant, through nested providers.
// Keep each content/shadow node separate, with the same mount lifetime as its
// source element. A late node must not join an already-captured timeline.
class _FooterScalarTarget {
  _FooterScalarTarget({required this.scale});
  final bool scale;
  double cssValue = 0;
  double? inlineValue;
  double get value => inlineValue ?? cssValue;
}

abstract class _FooterScalarState<T extends StatefulWidget> extends State<T> {
  bool get isScale;
  late final _target = _FooterScalarTarget(scale: isScale);
  Set<_TdsListFooterState> _owners = {};

  double scalar(BuildContext context, {required double cssValue}) {
    final owners =
        _FooterScope.of(context)?.owners.toSet() ?? <_TdsListFooterState>{};
    for (final owner in _owners.difference(owners)) {
      owner._detachShape(_target);
    }
    for (final owner in owners.difference(_owners)) {
      owner._shapes.add(_target);
    }
    _owners = owners;
    _target.cssValue = cssValue;
    return _target.value;
  }

  @override
  void dispose() {
    for (final owner in _owners) {
      owner._detachShape(_target);
    }
    super.dispose();
  }
}

class _FooterContent extends StatefulWidget {
  const _FooterContent({required this.child});
  final Widget child;
  @override
  State<_FooterContent> createState() => _FooterContentState();
}

class _FooterContentState extends _FooterScalarState<_FooterContent> {
  @override
  bool get isScale => true;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: scalar(context, cssValue: 1),
    // The source clock already interpolates this value, including reversion.
    duration: Duration.zero,
    curve: TdsMotion.rapid,
    child: widget.child,
  );
}

class _FooterColorTarget {
  bool icon = false;
  Color cssColor = const Color(0xff000000);
  Color? inlineColor;
  void render(Color color) {
    // The source CSSPlugin writes integer RGB channels. A subsequent release
    // reads those rendered channels, not the previous tween's hidden fraction.
    inlineColor = Color.from(
      alpha: (color.a * 10000).round() / 10000,
      red: (color.r * 255).round() / 255,
      green: (color.g * 255).round() / 255,
      blue: (color.b * 255).round() / 255,
    );
  }
}

/// Mirrors each compound's useEffect registration, including sibling order and
/// retention after unmount. A newly inserted child has no old inline animation.
abstract class _FooterColoredState<T extends StatefulWidget> extends State<T> {
  _FooterInk? _registeredInk;
  _TdsListFooterState? _owner;
  Set<_TdsListFooterState> _owners = {};
  final _target = _FooterColorTarget();
  int _registrationGeneration = 0;

  @override
  void dispose() {
    for (final owner in _owners) {
      owner._detachTarget(_target);
    }
    super.dispose();
  }

  Color ink(
    BuildContext context,
    Color? literal,
    String? token, {
    bool icon = false,
  }) {
    final scope = _FooterScope.of(context);
    final inherited =
        (icon ? scope?.iconInk : scope?.textInk) ??
        const _FooterInk(null, 'blue500');
    final value = literal != null || token != null
        ? _FooterInk(literal, token ?? '')
        : inherited;
    if (_owner != scope?.owner) {
      _owner = scope?.owner;
      _registeredInk = null;
      _target.inlineColor = null;
    }
    final owners = scope?.owners.toSet() ?? <_TdsListFooterState>{};
    for (final owner in _owners.difference(owners)) {
      owner._detachTarget(_target);
    }
    for (final owner in owners.difference(_owners)) {
      owner._targets.add(_target);
    }
    _owners = owners;
    if (_registeredInk != value) {
      _registeredInk = value;
      final generation = ++_registrationGeneration;
      if (scope != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _registrationGeneration) return;
          (icon ? scope.registerIcon : scope.registerText)(value);
        });
      }
    }
    _target.icon = icon;
    _target.cssColor = value.resolve(TdsTheme.of(context));
    return _target.inlineColor ?? _target.cssColor;
  }
}

class TdsListFooterText extends StatefulWidget {
  const TdsListFooterText({
    required this.child,
    this.color,
    this.colorToken,
    this.fontWeight = TdsFontWeight.medium,
    super.key,
  }) : assert(color == null || colorToken == null);
  final Widget child;
  final Color? color;
  final String? colorToken;
  final TdsFontWeight fontWeight;
  @override
  State<TdsListFooterText> createState() => _TdsListFooterTextState();
}

class _TdsListFooterTextState extends _FooterColoredState<TdsListFooterText> {
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    var style = theme.textStyle(
      typography: TdsTypography.t5,
      fontWeight: widget.fontWeight,
      color: ink(context, widget.color, widget.colorToken),
    );
    final lineHeight = tdsCssLineHeight(style.fontSize! * 1.252);
    style = style.copyWith(height: lineHeight / style.fontSize!);
    final child = widget.child;
    final uniform = child is Text && child.data != null && child.style == null;
    return TdsLineBox(
      lineHeight: lineHeight,
      baseline: uniform
          ? tdsCssTextBaseline(style.fontSize!, lineHeight)
          : null,
      child: DefaultTextStyle(
        style: style,
        child: child is Text ? TdsKeepAllText.from(child) : child,
      ),
    );
  }
}

class TdsListFooterIcon extends StatefulWidget {
  const TdsListFooterIcon({
    required this.name,
    this.color,
    this.colorToken,
    super.key,
  }) : assert(color == null || colorToken == null);
  final String name;
  final Color? color;
  final String? colorToken;
  @override
  State<TdsListFooterIcon> createState() => _TdsListFooterIconState();
}

class _TdsListFooterIconState extends _FooterColoredState<TdsListFooterIcon> {
  @override
  Widget build(BuildContext context) {
    return TdsAssetIcon(
      name: widget.name,
      color: ink(context, widget.color, widget.colorToken, icon: true),
      frameShape: const TdsAssetFrameShape(width: 24, height: 24),
    );
  }
}

enum TdsTableRowAlign { left, spaceBetween }

class TdsTableRow extends StatelessWidget {
  const TdsTableRow({
    required this.left,
    required this.right,
    required this.align,
    this.leftRatio,
    this.leftBackgroundColor,
    this.rightBackgroundColor,
    this.leftFontWeight = TdsFontWeight.regular,
    this.rightFontWeight = TdsFontWeight.regular,
    super.key,
  }) : assert(leftRatio == null || (leftRatio >= 0 && leftRatio <= 100));
  final Widget left, right;
  final TdsTableRowAlign align;
  final double? leftRatio;
  final Color? leftBackgroundColor, rightBackgroundColor;
  final TdsFontWeight leftFontWeight, rightFontWeight;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final stack =
        theme.platform.fontScale >= 160 &&
        MediaQuery.sizeOf(context).width < 560;
    final padding = stack
        ? 8.0
        : align == TdsTableRowAlign.left
        ? 16.0
        : 10.0;
    Widget cell(Widget child, bool leading) {
      final style = theme
          .textStyle(
            typography: TdsTypography.st10,
            fontWeight: leading ? leftFontWeight : rightFontWeight,
            color: theme.color(leading ? 'grey700' : 'grey900'),
          )
          .copyWith(height: 1.35);
      Widget text = DefaultTextStyle(
        style: style,
        textAlign: !leading && align == TdsTableRowAlign.spaceBetween
            ? TextAlign.right
            : TextAlign.left,
        child: child,
      );
      if (child is Text) {
        text = TdsLineBox(lineHeight: style.fontSize! * 1.35, child: text);
      }
      return ColoredBox(
        color:
            (leading ? leftBackgroundColor : rightBackgroundColor) ??
            const Color(0x00000000),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            leading || stack ? 24 : 8,
            padding,
            !leading || stack ? 24 : 8,
            padding,
          ),
          child: text,
        ),
      );
    }

    if (stack) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cell(left, true), cell(right, false)],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: align == TdsTableRowAlign.spaceBetween
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leftRatio != null && leftRatio != 0)
            SizedBox(
              width: constraints.maxWidth * leftRatio! / 100,
              child: cell(left, true),
            )
          else
            cell(left, true),
          Flexible(child: cell(right, false)),
        ],
      ),
    );
  }
}
