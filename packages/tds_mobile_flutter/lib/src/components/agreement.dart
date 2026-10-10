import 'package:flutter/widgets.dart';
import 'dart:async';
import '../foundation/theme.dart';
import '../foundation/pressable.dart';
import '../foundation/motion.dart';
import '../foundation/host.dart';
import '../foundation/touch_inset.dart';
import 'asset.dart';
import 'checkbox.dart';
import 'text.dart';

enum TdsAgreementVariant {
  xLarge,
  large,
  medium,
  mediumTitle,
  small,
  smallLast,
}

enum TdsAgreementNecessityVariant { optional, mandatory }

enum TdsAgreementCheckboxVariant { checkbox, dot, hidden }

enum TdsAgreementMotionVariant { strong, weak }

class _AgreementScope extends InheritedWidget {
  const _AgreementScope({
    required this.variant,
    this.a11yText,
    required super.child,
  });
  final TdsAgreementVariant variant;
  final String? a11yText;
  static TdsAgreementVariant of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AgreementScope>()?.variant ??
      TdsAgreementVariant.medium;
  @override
  bool updateShouldNotify(_AgreementScope oldWidget) =>
      variant != oldWidget.variant || a11yText != oldWidget.a11yText;
}

extension on TdsAgreementVariant {
  TdsTypography get typography => switch (this) {
    TdsAgreementVariant.xLarge => TdsTypography.t5,
    TdsAgreementVariant.large => TdsTypography.t6,
    _ => TdsTypography.t7,
  };
  TdsFontWeight get weight => switch (this) {
    TdsAgreementVariant.xLarge => TdsFontWeight.bold,
    TdsAgreementVariant.small ||
    TdsAgreementVariant.smallLast => TdsFontWeight.medium,
    _ => TdsFontWeight.semibold,
  };
  String get color => switch (this) {
    TdsAgreementVariant.small || TdsAgreementVariant.smallLast => 'grey500',
    TdsAgreementVariant.medium => 'grey600',
    _ => 'grey700',
  };
  double get top => switch (this) {
    TdsAgreementVariant.xLarge => 8,
    TdsAgreementVariant.large => 4,
    TdsAgreementVariant.medium || TdsAgreementVariant.mediumTitle => 2,
    _ => 0,
  };
  double textTop(double scale) => switch (this) {
    TdsAgreementVariant.xLarge => scale < 235 ? 0 : 2,
    TdsAgreementVariant.large =>
      scale < 160
          ? 1
          : scale < 235
          ? 3
          : 4,
    TdsAgreementVariant.small || TdsAgreementVariant.smallLast =>
      scale < 160
          ? 2
          : scale < 235
          ? 4
          : 7,
    _ =>
      scale < 160
          ? 2
          : scale < 235
          ? 4
          : 6,
  };
}

class TdsAgreementV4 extends StatelessWidget {
  const TdsAgreementV4({
    required this.variant,
    this.indent,
    this.left,
    this.middle,
    this.right,
    this.onPressEnd,
    super.key,
  });
  final TdsAgreementVariant variant;
  final int? indent;
  final Widget? left, middle, right;
  final VoidCallback? onPressEnd;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final level = indent ?? _IndentScope.of(context);
    return _AgreementScope(
      variant: variant,
      a11yText: middle is TdsAgreementText
          ? (middle as TdsAgreementText).text
          : middle is Text
          ? (middle as Text).data
          : null,
      child: DefaultTextStyle(
        style: theme.textStyle(
          typography: variant.typography,
          fontWeight: variant.weight,
          color: theme.color(variant.color),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            variant.top,
            20,
            variant == TdsAgreementVariant.smallLast ? 6 : 0,
          ),
          child: TdsAgreementPressable(
            onPressEnd: onPressEnd,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: TdsMotion.basic.duration,
                  curve: TdsMotion.basic,
                  width:
                      level * 24 * theme.platform.size(TdsTypography.t5) / 17,
                ),
                ?left,
                if (middle != null) Expanded(child: middle!),
                ?right,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TdsAgreementText extends StatelessWidget {
  const TdsAgreementText(
    this.text, {
    this.necessity,
    this.onPressEnd,
    super.key,
  });
  final String text;
  final Widget? necessity;
  final VoidCallback? onPressEnd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: _AgreementScope.of(
        context,
      ).textTop(TdsTheme.of(context).platform.fontScale),
    ),
    child: TdsAgreementPressable(
      onPressEnd: onPressEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text.rich(
            TextSpan(
              children: [
                if (necessity != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: necessity!,
                  ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TdsAgreementNecessity extends StatelessWidget {
  const TdsAgreementNecessity({required this.variant, this.text, super.key});
  final TdsAgreementNecessityVariant variant;
  final String? text;
  @override
  Widget build(BuildContext context) {
    final small = [
      TdsAgreementVariant.small,
      TdsAgreementVariant.smallLast,
    ].contains(_AgreementScope.of(context));
    final optional = variant == TdsAgreementNecessityVariant.optional;
    return Text(
      '${text ?? (optional ? '선택' : '필수')}${optional && small ? ' ・ ' : ' '}',
      style: TextStyle(
        color: TdsTheme.of(context).color(optional ? 'grey500' : 'blue500'),
      ),
    );
  }
}

class TdsAgreementPressable extends StatelessWidget {
  const TdsAgreementPressable({
    required this.child,
    this.onPressEnd,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressEnd;
  @override
  Widget build(BuildContext context) => onPressEnd == null
      ? child
      : TdsPressable(
          onPressed: onPressEnd,
          builder: (context, pressed, hovered, focused) => DecoratedBox(
            decoration: BoxDecoration(
              color: pressed || focused
                  ? TdsTheme.of(context).color('greyOpacity100')
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: child,
          ),
        );
}

class TdsAgreementCheckbox extends StatefulWidget {
  const TdsAgreementCheckbox({
    this.checked,
    this.defaultChecked = false,
    this.variant = TdsAgreementCheckboxVariant.checkbox,
    this.motionVariant = TdsAgreementMotionVariant.weak,
    this.transitionDelay = Duration.zero,
    this.inert = false,
    this.onCheckedChange,
    this.semanticLabel,
    super.key,
  });
  final bool? checked;
  final bool defaultChecked, inert;
  final TdsAgreementCheckboxVariant variant;
  final TdsAgreementMotionVariant motionVariant;
  final Duration transitionDelay;
  final ValueChanged<bool>? onCheckedChange;
  final String? semanticLabel;
  @override
  State<TdsAgreementCheckbox> createState() => _TdsAgreementCheckboxState();
}

class _TdsAgreementCheckboxState extends State<TdsAgreementCheckbox> {
  late bool internal = widget.defaultChecked;
  late bool displayedChecked = checked;
  Timer? colorDelay;
  bool get checked => widget.checked ?? internal;
  void change(bool value) {
    if (widget.inert) return;
    if (widget.checked == null) {
      setState(() => internal = value);
      scheduleColor();
    }
    widget.onCheckedChange?.call(value);
    context.findAncestorWidgetOfExactType<_PushTrigger>()?.onChanged(value);
  }

  void scheduleColor() {
    colorDelay?.cancel();
    if (widget.transitionDelay == Duration.zero) {
      displayedChecked = checked;
    } else {
      colorDelay = Timer(widget.transitionDelay, () {
        if (mounted) setState(() => displayedChecked = checked);
      });
    }
  }

  @override
  void didUpdateWidget(TdsAgreementCheckbox old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked ||
        old.transitionDelay != widget.transitionDelay) {
      scheduleColor();
    }
  }

  @override
  void dispose() {
    colorDelay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), scale = theme.platform.fontScale;
    final size = (24 * theme.platform.size(TdsTypography.t5) / 17)
        .roundToDouble();
    final margin = scale < 120
        ? 2.0
        : scale < 190
        ? 1.0
        : 0.0;
    final label =
        widget.semanticLabel ??
        context.dependOnInheritedWidgetOfExactType<_AgreementScope>()?.a11yText;
    final hidden = widget.variant == TdsAgreementCheckboxVariant.hidden;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final entering =
        widget.motionVariant == TdsAgreementMotionVariant.strong &&
            widget.variant == TdsAgreementCheckboxVariant.checkbox
        ? TdsMotion.bounce
        : TdsMotion.small;
    final delay =
        widget.transitionDelay +
        (widget.variant == TdsAgreementCheckboxVariant.dot
            ? const Duration(milliseconds: 100)
            : Duration.zero);
    final total = entering.duration + delay;
    Widget mark(bool pressed) {
      final color = theme.color(
        displayedChecked
            ? pressed
                  ? (theme.isDark ? 'blue300' : 'blue700')
                  : 'blue500'
            : pressed
            ? 'grey400'
            : 'grey200',
      );
      return AnimatedSwitcher(
        duration: reduced ? Duration.zero : total,
        reverseDuration: reduced ? Duration.zero : TdsMotion.rapid.duration,
        transitionBuilder: (child, animation) {
          return AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (_, child) {
              final exiting = animation.status == AnimationStatus.reverse;
              final raw = exiting
                  ? animation.value
                  : ((animation.value * total.inMicroseconds -
                                delay.inMicroseconds) /
                            entering.duration.inMicroseconds)
                        .clamp(0.0, 1.0);
              final value = exiting
                  ? TdsMotion.rapid.transform(raw)
                  : entering.transform(raw);
              return Transform.scale(
                scale: value.clamp(0.0, 2.0),
                child: child,
              );
            },
          );
        },
        child: SizedBox.square(
          key: ValueKey(widget.variant),
          dimension: size,
          child: switch (widget.variant) {
            TdsAgreementCheckboxVariant.hidden => const SizedBox.shrink(),
            TdsAgreementCheckboxVariant.dot => Center(
              child: Container(
                width: size / 6,
                height: size / 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.color('grey200'),
                ),
              ),
            ),
            TdsAgreementCheckboxVariant.checkbox =>
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: reduced ? Duration.zero : TdsMotion.quick.duration,
                curve: TdsMotion.quick,
                builder: (_, color, _) =>
                    TdsCheckboxLineGraphic(size: size, color: color!),
              ),
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(margin),
      child: ExcludeSemantics(
        excluding: widget.inert || hidden,
        child: Semantics(
          checked: checked,
          label: label,
          child: TdsTouchInset(
            insets: EdgeInsets.only(right: hidden ? 0 : size),
            child: TdsPressable(
              button: false,
              enabled: !hidden && !widget.inert,
              onPressStart: () =>
                  tdsHapticOf(context).generate(TdsHapticType.tickWeak),
              onPressed: () => change(!checked),
              builder: (_, pressed, hovered, focused) => SizedBox(
                width: hidden ? size : size * 2,
                height: size,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedScale(
                    scale: pressed ? .8 : 1,
                    duration: reduced
                        ? Duration.zero
                        : (pressed ? TdsMotion.rapid : TdsMotion.bounce)
                              .duration,
                    curve: pressed ? TdsMotion.rapid : TdsMotion.bounce,
                    child: mark(pressed || hovered),
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

class TdsAgreementBadge extends StatelessWidget {
  const TdsAgreementBadge({
    required this.child,
    this.fill = true,
    this.textColor,
    this.backgroundColor,
    this.onPressed,
    super.key,
  });
  final Widget child;
  final bool fill;
  final Color? textColor, backgroundColor;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: TdsAgreementPressable(
      onPressEnd: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: fill ? backgroundColor : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: DefaultTextStyle(
          style: TdsTheme.of(context).textStyle(
            typography: TdsTypography.t7,
            fontWeight: TdsFontWeight.semibold,
            color: textColor,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class TdsAgreementHeader extends StatelessWidget {
  const TdsAgreementHeader({
    required this.child,
    required this.variant,
    this.indent = 0,
    super.key,
  });
  final Widget child;
  final TdsAgreementVariant variant;
  final int indent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20 + indent * 24, variant.top, 20, 0),
    child: Padding(
      padding: variant == TdsAgreementVariant.xLarge
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
          : EdgeInsets.zero,
      child: DefaultTextStyle(
        style: TdsTheme.of(
          context,
        ).textStyle(typography: variant.typography, fontWeight: variant.weight),
        child: child,
      ),
    ),
  );
}

class TdsAgreementDescription extends StatelessWidget {
  const TdsAgreementDescription(
    this.text, {
    this.indent = 0,
    this.box = false,
    super.key,
  });
  final String text;
  final int indent;
  final bool box;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: box ? 20 : 24, vertical: 6),
    child: Container(
      padding: EdgeInsets.fromLTRB(
        (box ? 12 : 0) + indent * 24,
        box ? 10 : 0,
        box ? 12 : 0,
        box ? 10 : 0,
      ),
      decoration: BoxDecoration(
        color: box ? TdsTheme.of(context).color('grey50') : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TdsText(
        text,
        typography: TdsTypography.t7,
        fontWeight: TdsFontWeight.medium,
        color: TdsTheme.of(context).color('grey500'),
      ),
    ),
  );
}

class TdsAgreementGroup extends StatelessWidget {
  const TdsAgreementGroup({
    required this.children,
    this.showGradient = true,
    super.key,
  });
  final List<Widget> children;
  final bool showGradient;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (showGradient)
        Positioned(
          top: 0,
          bottom: 0,
          left: 30,
          width: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x003182f6),
                  TdsTheme.of(context).color('blue500').withValues(alpha: .2),
                  TdsTheme.of(context).color('teal500').withValues(alpha: .2),
                  const Color(0x003182f6),
                ],
                stops: const [0, 1 / 3, 2 / 3, 1],
              ),
            ),
          ),
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ],
  );
}

class _BoolScope extends InheritedWidget {
  const _BoolScope({
    required this.value,
    required this.onChanged,
    required super.child,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  bool updateShouldNotify(_BoolScope oldWidget) =>
      value != oldWidget.value || onChanged != oldWidget.onChanged;
}

class TdsAgreementCollapsible extends StatefulWidget {
  const TdsAgreementCollapsible({
    required this.child,
    this.collapsed,
    this.defaultCollapsed = false,
    this.onCollapsedChange,
    super.key,
  });
  final Widget child;
  final bool? collapsed;
  final bool defaultCollapsed;
  final ValueChanged<bool>? onCollapsedChange;
  @override
  State<TdsAgreementCollapsible> createState() =>
      _TdsAgreementCollapsibleState();
}

class _TdsAgreementCollapsibleState extends State<TdsAgreementCollapsible> {
  late bool internal = widget.defaultCollapsed;
  @override
  Widget build(BuildContext context) => _BoolScope(
    value: widget.collapsed ?? internal,
    onChanged: (v) {
      if (widget.collapsed == null) setState(() => internal = v);
      widget.onCollapsedChange?.call(v);
    },
    child: widget.child,
  );
}

class TdsAgreementCollapsibleContent extends StatelessWidget {
  const TdsAgreementCollapsibleContent({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_BoolScope>();
    if (scope == null) {
      throw StateError('CollapsibleContent requires AgreementCollapsible');
    }
    return TdsAgreementV3Collapsible(open: !scope.value, child: child);
  }
}

class _CollapseTrigger extends _BoolScope {
  const _CollapseTrigger({
    required super.value,
    required super.onChanged,
    required super.child,
  });
}

class TdsAgreementCollapsibleTrigger extends StatelessWidget {
  const TdsAgreementCollapsibleTrigger({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_BoolScope>();
    if (scope == null) {
      throw StateError('CollapsibleTrigger requires AgreementCollapsible');
    }
    return _CollapseTrigger(
      value: scope.value,
      onChanged: scope.onChanged,
      child: child,
    );
  }
}

class TdsAgreementRightArrow extends StatelessWidget {
  const TdsAgreementRightArrow({this.collapsed, this.onArrowClick, super.key});
  final bool? collapsed;
  final VoidCallback? onArrowClick;
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CollapseTrigger>();
    final value = collapsed ?? scope?.value ?? false;
    return Semantics(
      expanded: !value,
      child: TdsPressable(
        semanticLabel: value ? '펼치기' : '접기',
        onPressed: () {
          onArrowClick?.call();
          scope?.onChanged(!value);
        },
        builder: (context, pressed, hovered, focused) => Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedRotation(
            turns: value ? 0 : .5,
            duration: TdsMotion.basic.duration,
            curve: TdsMotion.basic,
            child: TdsAssetIcon(
              name: 'icon-arrow-down-mono',
              color: TdsTheme.of(context).color('grey300'),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _IndentScope extends InheritedWidget {
  const _IndentScope({required this.indent, required super.child});
  final int indent;
  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_IndentScope>()?.indent ?? 0;
  @override
  bool updateShouldNotify(_IndentScope oldWidget) => indent != oldWidget.indent;
}

class _PushScope extends _BoolScope {
  const _PushScope({
    required super.value,
    required super.onChanged,
    required super.child,
  });
}

class _PushTrigger extends InheritedWidget {
  const _PushTrigger({required this.onChanged, required super.child});
  final ValueChanged<bool> onChanged;
  @override
  bool updateShouldNotify(_PushTrigger oldWidget) =>
      onChanged != oldWidget.onChanged;
}

class TdsAgreementIndentPushable extends StatefulWidget {
  const TdsAgreementIndentPushable({
    required this.child,
    this.pushed,
    this.defaultPushed = false,
    this.onPushedChange,
    super.key,
  });
  final Widget child;
  final bool? pushed;
  final bool defaultPushed;
  final ValueChanged<bool>? onPushedChange;
  @override
  State<TdsAgreementIndentPushable> createState() =>
      _TdsAgreementIndentPushableState();
}

class _TdsAgreementIndentPushableState
    extends State<TdsAgreementIndentPushable> {
  late bool internal = widget.defaultPushed;
  @override
  Widget build(BuildContext context) => _PushScope(
    value: widget.pushed ?? internal,
    onChanged: (v) {
      if (widget.pushed == null) setState(() => internal = v);
      widget.onPushedChange?.call(v);
    },
    child: widget.child,
  );
}

class TdsAgreementIndentPushableContent extends StatelessWidget {
  const TdsAgreementIndentPushableContent({
    required this.child,
    this.indent,
    super.key,
  });
  final Widget child;
  final int? indent;
  @override
  Widget build(BuildContext context) => _IndentScope(
    indent:
        indent ??
        _IndentScope.of(context) +
            ((context.dependOnInheritedWidgetOfExactType<_PushScope>()?.value ??
                    false)
                ? 1
                : 0),
    child: child,
  );
}

class TdsAgreementIndentPushableTrigger extends StatelessWidget {
  const TdsAgreementIndentPushableTrigger({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PushScope>();
    if (scope == null) {
      throw StateError('IndentPushableTrigger requires IndentPushable');
    }
    return _PushTrigger(onChanged: scope.onChanged, child: child);
  }
}

enum TdsAgreementV3Size { big, medium, mediumBold }

enum TdsAgreementV3Arrow { none, link, collapsible }

enum TdsAgreementV3Necessity { none, optional, mandatory }

class TdsAgreementV3SingleField extends StatelessWidget {
  const TdsAgreementV3SingleField(
    this.text, {
    required this.type,
    this.arrowType = TdsAgreementV3Arrow.none,
    this.withBorder = false,
    this.indent = 0,
    this.rightAddon,
    this.open = false,
    this.onPressEnd,
    this.onArrowPressEnd,
    this.left,
    super.key,
  });
  final String text;
  final TdsAgreementV3Size type;
  final TdsAgreementV3Arrow arrowType;
  final bool withBorder, open;
  final int indent;
  final Widget? rightAddon, left;
  final VoidCallback? onPressEnd, onArrowPressEnd;
  @override
  Widget build(BuildContext context) {
    final big = type == TdsAgreementV3Size.big;
    final theme = TdsTheme.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: 24 + indent * 16, right: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (left != null)
                Padding(
                  padding: EdgeInsets.only(top: big ? 20 : 5, right: 8),
                  child: left!,
                ),
              Expanded(
                child: TdsAgreementPressable(
                  onPressEnd: onPressEnd,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: big ? 20 : 8),
                    child: TdsText(
                      text,
                      typography: big ? TdsTypography.t5 : TdsTypography.t6,
                      fontWeight: type == TdsAgreementV3Size.medium
                          ? TdsFontWeight.regular
                          : TdsFontWeight.semibold,
                      color: theme.color(big ? 'grey800' : 'grey700'),
                    ),
                  ),
                ),
              ),
              ?rightAddon,
              if (arrowType != TdsAgreementV3Arrow.none)
                Padding(
                  padding: EdgeInsets.only(top: big ? 20 : 5),
                  child: arrowType == TdsAgreementV3Arrow.collapsible
                      ? TdsAgreementRightArrow(
                          collapsed: !open,
                          onArrowClick: onArrowPressEnd ?? onPressEnd,
                        )
                      : TdsAgreementPressable(
                          onPressEnd: onArrowPressEnd ?? onPressEnd,
                          child: TdsAssetIcon(
                            name: 'icon-arrow-right-mono',
                            size: 24,
                            color: theme.color('grey400'),
                          ),
                        ),
                ),
            ],
          ),
        ),
        if (withBorder) const TdsBorder(variant: TdsBorderVariant.padding24),
      ],
    );
  }
}

class TdsAgreementV3SingleCheckboxField extends StatefulWidget {
  const TdsAgreementV3SingleCheckboxField(
    this.text, {
    required this.type,
    this.checked,
    this.defaultChecked = false,
    this.onCheckedChange,
    this.necessity = TdsAgreementV3Necessity.none,
    this.arrowType = TdsAgreementV3Arrow.none,
    this.withBorder = false,
    this.indent = 0,
    this.open = false,
    this.rightAddon,
    this.onPressEnd,
    this.onArrowPressEnd,
    super.key,
  });
  final String text;
  final TdsAgreementV3Size type;
  final bool? checked;
  final bool defaultChecked, withBorder, open;
  final int indent;
  final ValueChanged<bool>? onCheckedChange;
  final TdsAgreementV3Necessity necessity;
  final TdsAgreementV3Arrow arrowType;
  final Widget? rightAddon;
  final VoidCallback? onPressEnd, onArrowPressEnd;
  @override
  State<TdsAgreementV3SingleCheckboxField> createState() =>
      _TdsAgreementV3SingleCheckboxFieldState();
}

class _TdsAgreementV3SingleCheckboxFieldState
    extends State<TdsAgreementV3SingleCheckboxField> {
  late bool internal = widget.defaultChecked;
  bool get checked => widget.checked ?? internal;
  void change(bool v) {
    if (widget.checked == null) setState(() => internal = v);
    widget.onPressEnd?.call();
    widget.onCheckedChange?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final text =
        '${switch (widget.necessity) {
          TdsAgreementV3Necessity.none => '',
          TdsAgreementV3Necessity.optional => '[선택] ',
          TdsAgreementV3Necessity.mandatory => '[필수] ',
        }}${widget.text}';
    return TdsAgreementV3SingleField(
      text,
      type: widget.type,
      arrowType: widget.arrowType,
      withBorder: widget.withBorder,
      indent: widget.indent,
      open: widget.open,
      rightAddon: widget.rightAddon,
      onPressEnd: () => change(!checked),
      onArrowPressEnd: widget.onArrowPressEnd,
      left: TdsCheckbox.line(
        checked: checked,
        onCheckedChange: change,
        semanticLabel: text,
      ),
    );
  }
}

class TdsAgreementV3Group extends StatelessWidget {
  const TdsAgreementV3Group({
    required this.children,
    this.indent = 0,
    super.key,
  });
  final List<Widget> children;
  final int indent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent * 16),
    child: Column(children: children),
  );
}

class TdsAgreementV3GroupItem extends TdsAgreementV3SingleCheckboxField {
  const TdsAgreementV3GroupItem(
    super.text, {
    required super.type,
    super.checked,
    super.onCheckedChange,
    super.arrowType,
    super.rightAddon,
    super.open,
    super.onPressEnd,
    super.onArrowPressEnd,
    super.key,
  });
}

class TdsAgreementV3Button extends StatelessWidget {
  const TdsAgreementV3Button(
    this.text, {
    this.checked,
    this.onCheckedChange,
    super.key,
  });
  final String text;
  final bool? checked;
  final ValueChanged<bool>? onCheckedChange;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    child: TdsCheckbox.line(
      checked: checked,
      onCheckedChange: onCheckedChange,
      semanticLabel: text,
      child: TdsText(
        text,
        typography: TdsTypography.st8,
        fontWeight: TdsFontWeight.semibold,
        color: TdsTheme.of(context).color('grey800'),
      ),
    ),
  );
}

class TdsAgreementV3Tag extends TdsText {
  const TdsAgreementV3Tag(super.text, {super.color, super.key})
    : super(typography: TdsTypography.t7);
}

class TdsAgreementV3Description extends StatelessWidget {
  const TdsAgreementV3Description(this.text, {this.indent = 0, super.key});
  final String text;
  final int indent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24 + indent * 16, 0, 16, 0),
    child: TdsText(
      text,
      typography: TdsTypography.t7,
      color: TdsTheme.of(context).color('grey500'),
    ),
  );
}

class TdsAgreementV3Collapsible extends StatelessWidget {
  const TdsAgreementV3Collapsible({
    required this.open,
    required this.child,
    super.key,
  });
  final bool open;
  final Widget child;
  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !open,
    child: ExcludeSemantics(
      excluding: !open,
      child: IgnorePointer(
        ignoring: !open,
        child: ClipRect(
          child: AnimatedAlign(
            alignment: Alignment.topCenter,
            heightFactor: open ? 1 : 0,
            duration: TdsMotion.basic.duration,
            curve: TdsMotion.basic,
            child: child,
          ),
        ),
      ),
    ),
  );
}

class TdsAgreementV3CollapsibleGroupController extends ValueNotifier<bool> {
  TdsAgreementV3CollapsibleGroupController({bool isOpen = false})
    : super(isOpen);
  bool get isOpen => value;
  void open() => value = true;
  void close() => value = false;
  void toggle() => value = !value;
}

class TdsAgreementV3CollapsibleGroup extends StatelessWidget {
  const TdsAgreementV3CollapsibleGroup({
    required this.header,
    required this.child,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.controller,
    super.key,
  }) : assert(
         controller == null || open == null,
         'Use a controller or open, not both.',
       );
  final Widget Function(BuildContext, bool, VoidCallback) header;
  final Widget child;
  final bool? open;
  final bool defaultOpen;
  final ValueChanged<bool>? onOpenChange;
  final TdsAgreementV3CollapsibleGroupController? controller;
  @override
  Widget build(BuildContext context) => controller == null
      ? _build(context)
      : ValueListenableBuilder<bool>(
          valueListenable: controller!,
          builder: (context, _, _) => _build(context),
        );
  Widget _build(BuildContext context) => TdsAgreementCollapsible(
    collapsed: controller != null
        ? !controller!.isOpen
        : open == null
        ? null
        : !open!,
    defaultCollapsed: !defaultOpen,
    onCollapsedChange: (v) {
      controller?.value = !v;
      onOpenChange?.call(!v);
    },
    child: Builder(
      builder: (context) {
        final scope = context.dependOnInheritedWidgetOfExactType<_BoolScope>()!;
        return Column(
          children: [
            header(context, !scope.value, () => scope.onChanged(!scope.value)),
            TdsAgreementCollapsibleContent(child: child),
          ],
        );
      },
    ),
  );
}

/// Namespace counterpart for source AgreementV3; native compounds are named widgets.
abstract final class TdsAgreementV3 {
  static Widget group({required List<Widget> children, int indent = 0}) =>
      TdsAgreementV3Group(indent: indent, children: children);
}
