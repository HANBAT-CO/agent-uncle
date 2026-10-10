import 'dart:async';
import 'package:flutter/widgets.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'button.dart';
import 'text.dart';

class TdsStaggerIn extends StatefulWidget {
  const TdsStaggerIn({
    required this.child,
    this.play = true,
    this.delay = Duration.zero,
    super.key,
  });
  final Widget child;
  final bool play;
  final Duration delay;
  @override
  State<TdsStaggerIn> createState() => _TdsStaggerInState();
}

class _TdsStaggerInState extends State<TdsStaggerIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _timer;
  void start() {
    _timer?.cancel();
    if (widget.play) {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(TdsStaggerIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play != oldWidget.play) start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: widget.play
          ? TdsMotion.out.transform((_controller.value * 3).clamp(0, 1))
          : 1,
      child: Transform.translate(
        offset: Offset(
          0,
          widget.play
              ? 30 * (1 - TdsMotion.expo.transform(_controller.value))
              : 0,
        ),
        child: child,
      ),
    ),
  );
}

class TdsStepper extends StatelessWidget {
  const TdsStepper({
    required this.children,
    this.play = true,
    this.delay = Duration.zero,
    this.staggerDelay = const Duration(milliseconds: 100),
    super.key,
  });
  final List<TdsStepperRow> children;
  final bool play;
  final Duration delay, staggerDelay;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i++)
        TdsStaggerIn(
          play: play,
          delay: delay + staggerDelay * i,
          child: children[i],
        ),
    ],
  );
}

class TdsStepperRow extends StatelessWidget {
  const TdsStepperRow({
    required this.left,
    required this.center,
    this.right,
    this.hideLine = false,
    this.order,
    super.key,
  });
  final Widget left, center;
  final Widget? right;
  final bool hideLine;
  final int? order;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), scale = theme.platform.fontScale;
    final text = center is TdsStepperRowTexts
        ? center as TdsStepperRowTexts
        : null;
    final number = left is TdsStepperRowNumberIcon;
    final frameSize = left is TdsStepperRowAssetFrame
        ? (left as TdsStepperRowAssetFrame).shape.width
        : null;
    final pad = text == null || !number && text.description != null
        ? 0.0
        : frameSize == 40
        ? (text.type == TdsStepperTextType.b ? 6.0 : 7.0)
        : frameSize == 30 || number
        ? (text.type == TdsStepperTextType.b ? 1.0 : 2.0)
        : 0.0;
    final reflow = scale >= 200 && right is TdsStepperRowRightButton;
    final rightPad = right is TdsStepperRowRightArrow
        ? (frameSize == 40 ? 8.0 : 4.0)
        : frameSize == 40
        ? 4.0
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  left,
                  if (!hideLine)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 2,
                          constraints: const BoxConstraints(minHeight: 16),
                          decoration: BoxDecoration(
                            color: theme.color('grey200'),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: reflow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          center,
                          if (right != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: right!,
                            ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: scale >= 140 ? 0 : pad,
                              ),
                              child: center,
                            ),
                          ),
                          if (right != null)
                            Padding(
                              padding: EdgeInsets.only(left: 12, top: rightPad),
                              child: right!,
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum TdsStepperTextType { a, b, c }

class TdsStepperRowTexts extends StatelessWidget {
  const TdsStepperRowTexts({
    required this.title,
    required this.type,
    this.description,
    this.titleStyle,
    this.descriptionStyle,
    super.key,
  });
  final String title;
  final String? description;
  final TdsStepperTextType type;
  final TextStyle? titleStyle, descriptionStyle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: TdsText(
          title,
          typography: type == TdsStepperTextType.b
              ? TdsTypography.t4
              : TdsTypography.t5,
          fontWeight: TdsFontWeight.bold,
          color: TdsTheme.of(context).color('grey800'),
          style: titleStyle,
        ),
      ),
      if (description != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TdsText(
            description!,
            typography: type == TdsStepperTextType.c
                ? TdsTypography.t7
                : TdsTypography.t6,
            fontWeight: type == TdsStepperTextType.c
                ? TdsFontWeight.medium
                : TdsFontWeight.regular,
            color: TdsTheme.of(context).color('grey600'),
            style: descriptionStyle,
          ),
        ),
    ],
  );
}

class TdsStepperRowNumberIcon extends StatelessWidget {
  const TdsStepperRowNumberIcon(this.number, {super.key})
    : assert(number >= 1 && number <= 9);
  final int number;
  @override
  Widget build(BuildContext context) => TdsAssetIcon(
    name: 'icon-step$number-rounded-${TdsTheme.of(context).colorScheme.name}',
    size: TdsTheme.of(context).platform.fontScale >= 160 ? 40 : 30,
    alt: '$number 단계',
  );
}

class TdsStepperRowAssetFrame extends StatelessWidget {
  const TdsStepperRowAssetFrame({
    required this.content,
    required this.shape,
    this.backgroundColor,
    super.key,
  });
  final Widget content;
  final TdsAssetFrameShape shape;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => TdsAssetFrame(
    content: content,
    shape: TdsTheme.of(context).platform.fontScale >= 160 && shape.width == 30
        ? TdsAssetFrameShape(
            width: 40,
            height: 40,
            radius: shape.radius == 9999 ? 9999 : 0,
          )
        : shape,
    backgroundColor: backgroundColor,
  );
}

class TdsStepperRowRightArrow extends StatelessWidget {
  const TdsStepperRowRightArrow({this.color, super.key});
  final Color? color;
  @override
  Widget build(BuildContext context) => TdsAssetIcon(
    name: 'icon-arrow-right-mono',
    color: color ?? TdsTheme.of(context).color('grey400'),
    size: TdsTheme.of(context).platform.fontScale >= 160 ? 32 : 24,
  );
}

class TdsStepperRowRightButton extends StatelessWidget {
  const TdsStepperRowRightButton({
    required this.child,
    this.onPressed,
    this.disabled = false,
    this.loading = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled, loading;
  @override
  Widget build(BuildContext context) => TdsButton(
    size: TdsButtonSize.small,
    onPressed: onPressed,
    disabled: disabled,
    loading: loading,
    child: child,
  );
}

enum TdsProgressStepperVariant { compact, icon }

class TdsProgressStepper extends StatelessWidget {
  const TdsProgressStepper({
    required this.children,
    this.variant = TdsProgressStepperVariant.compact,
    this.activeStepIndex = 0,
    this.checkForFinish = false,
    this.a11yVerticalReflow = true,
    this.widePaddingTop = false,
    super.key,
  });
  final List<TdsProgressStep> children;
  final TdsProgressStepperVariant variant;
  final int activeStepIndex;
  final bool checkForFinish, a11yVerticalReflow, widePaddingTop;
  @override
  Widget build(BuildContext context) {
    final vertical =
        a11yVerticalReflow &&
        children.any((step) => step.title != null) &&
        TdsTheme.of(context).platform.fontScale >= 275;
    final steps = [
      for (var i = 0; i < children.length; i++)
        _ProgressContext(
          variant: variant,
          index: i,
          count: children.length,
          active: activeStepIndex == i,
          done: checkForFinish && i < activeStepIndex,
          vertical: vertical,
          child: children[i],
        ),
    ];
    if (steps.isEmpty) return const SizedBox();
    final theme = TdsTheme.of(context);
    final compact = variant == TdsProgressStepperVariant.compact;
    final trackSize = compact
        ? (vertical ? 10.0 : 8.0)
        : (vertical ? 38.0 : 28.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, widePaddingTop ? 24 : 16, 24, 8),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: vertical ? null : 0,
            bottom: vertical ? 0 : null,
            width: vertical ? trackSize : null,
            height: vertical ? null : trackSize,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final length = vertical
                    ? constraints.maxHeight
                    : constraints.maxWidth;
                final index = activeStepIndex.clamp(0, steps.length - 1);
                var extent = steps.length == 1
                    ? length
                    : index / (steps.length - 1) * length;
                if (!compact) {
                  extent = steps.length == 1
                      ? length
                      : (length - 28 * steps.length) /
                                (steps.length - 1) *
                                index +
                            28 * (index + 1);
                } else if (index == steps.length - 1) {
                  extent = length;
                } else if (steps.length <= 3 && !vertical) {
                  if (index == 1) extent += 4;
                } else if (children.any((step) => step.title != null)) {
                  extent += switch (index) {
                    0 => 28,
                    1 => steps.length == 5 ? 16 : 12,
                    2 => steps.length == 4 ? -4 : 4,
                    3 => -8,
                    _ => 0,
                  };
                } else if (index == 1) {
                  extent += 48 / 9;
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? theme.color('opacity50')
                          : const Color(0xffedeff2),
                      border: Border.all(
                        color: theme.color('greyOpacity100'),
                        width: compact ? .5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: vertical ? trackSize : extent.clamp(0, length),
                        height: vertical ? extent.clamp(0, length) : trackSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: theme.isDark
                              ? const Color(0xff171717)
                              : const Color(0xffffffff),
                          gradient: LinearGradient(
                            begin: vertical
                                ? Alignment.topCenter
                                : Alignment.centerLeft,
                            end: vertical
                                ? Alignment.bottomCenter
                                : Alignment.centerRight,
                            colors: [
                              Color.alphaBlend(
                                theme
                                    .color('blue500')
                                    .withValues(alpha: compact ? .24 : .15),
                                theme.color('background'),
                              ),
                              Color.alphaBlend(
                                theme
                                    .color('blue500')
                                    .withValues(alpha: compact ? .29 : .25),
                                theme.color('background'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      steps[i],
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final step in steps) Expanded(child: step)],
                ),
        ],
      ),
    );
  }
}

class _ProgressContext extends InheritedWidget {
  const _ProgressContext({
    required this.variant,
    required this.index,
    required this.count,
    required this.active,
    required this.done,
    required this.vertical,
    required super.child,
  });
  final TdsProgressStepperVariant variant;
  final int index, count;
  final bool active, done, vertical;
  @override
  bool updateShouldNotify(_ProgressContext oldWidget) =>
      index != oldWidget.index ||
      count != oldWidget.count ||
      active != oldWidget.active ||
      done != oldWidget.done ||
      vertical != oldWidget.vertical ||
      variant != oldWidget.variant;
}

class TdsProgressStep extends StatelessWidget {
  const TdsProgressStep({this.title, this.icon, super.key});
  final String? title;
  final Widget? icon;
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ProgressContext>();
    if (scope == null) {
      throw StateError('ProgressStep must be inside ProgressStepper');
    }
    final theme = TdsTheme.of(context),
        compact = scope.variant == TdsProgressStepperVariant.compact;
    final size = compact
        ? (scope.vertical ? 10.0 : 8.0)
        : scope.vertical
        ? 38.0
        : 28.0;
    final dot = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scope.active
            ? theme.color('blue500')
            : compact
            ? null
            : theme.color('background'),
        boxShadow: compact && scope.active
            ? [
                BoxShadow(
                  color: theme
                      .color('blue500')
                      .withValues(alpha: theme.isDark ? .3 : .2),
                  spreadRadius: size / 2,
                ),
              ]
            : null,
      ),
      child: compact
          ? scope.active
                ? null
                : Center(
                    child: Container(
                      width: size - 3,
                      height: size - 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.isDark
                            ? theme.color('background')
                            : const Color(0xccffffff),
                      ),
                    ),
                  )
          : icon ??
                TdsText(
                  scope.done ? '✓' : '${scope.index + 1}',
                  typography: TdsTypography.t6,
                  color: scope.active
                      ? const Color(0xffffffff)
                      : theme.color(scope.done ? 'blue500' : 'grey600'),
                  fontWeight: TdsFontWeight.semibold,
                ),
    );
    final text = title == null
        ? null
        : TdsText(
            title!,
            typography: TdsTypography.t7,
            color: theme.color(scope.active ? 'grey800' : 'grey600'),
            fontWeight: scope.active
                ? TdsFontWeight.bold
                : TdsFontWeight.semibold,
            textAlign: scope.vertical || (scope.count <= 3 && scope.index == 0)
                ? TextAlign.start
                : scope.count <= 3 && scope.index == scope.count - 1
                ? TextAlign.end
                : TextAlign.center,
          );
    return Semantics(
      label:
          '${scope.count}단계 중 ${scope.index + 1}단계${title == null ? '' : ', $title'}',
      selected: scope.active,
      child: ExcludeSemantics(
        child: scope.vertical
            ? Row(
                children: [
                  dot,
                  if (text != null) ...[
                    const SizedBox(width: 12),
                    Expanded(child: text),
                  ],
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: scope.count > 3
                    ? CrossAxisAlignment.center
                    : scope.index == 0
                    ? CrossAxisAlignment.start
                    : scope.index == scope.count - 1
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center,
                children: [
                  dot,
                  if (text != null) ...[
                    SizedBox(height: compact ? 6 : 8),
                    text,
                  ],
                ],
              ),
      ),
    );
  }
}
