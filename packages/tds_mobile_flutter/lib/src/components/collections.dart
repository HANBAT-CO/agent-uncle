import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'text.dart';

/// Controlled when [isOpened] is supplied; otherwise owns its expanded state.
class TdsBoardRow extends StatefulWidget {
  const TdsBoardRow({
    required this.title,
    required this.child,
    this.prefix,
    this.icon,
    this.initialOpened = false,
    this.isOpened,
    this.onOpen,
    this.onClose,
    this.showDivider = true,
    super.key,
  });
  final Widget title, child;
  final Widget? prefix, icon;
  final bool initialOpened, showDivider;
  final bool? isOpened;
  final VoidCallback? onOpen, onClose;
  @override
  State<TdsBoardRow> createState() => _TdsBoardRowState();
}

class _TdsBoardRowState extends State<TdsBoardRow> {
  late bool _opened = widget.initialOpened;
  bool get opened => widget.isOpened ?? _opened;
  void toggle() {
    final next = !opened;
    if (widget.isOpened == null) setState(() => _opened = next);
    (next ? widget.onOpen : widget.onClose)?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: opened,
          child: TdsPressable(
            onPressed: toggle,
            onPressStart: () =>
                tdsHapticOf(context).generate(TdsHapticType.softWeak),
            builder: (context, pressed, hovered, focused) => AnimatedScale(
              scale: pressed ? .96 : 1,
              duration: (pressed ? TdsMotion.rapid : TdsMotion.quick).duration,
              curve: pressed ? TdsMotion.rapid : TdsMotion.quick,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: DefaultTextStyle(
                  style: theme
                      .textStyle(
                        typography: TdsTypography.t5,
                        fontWeight: opened
                            ? TdsFontWeight.medium
                            : TdsFontWeight.regular,
                        color: theme.color(opened ? 'blue500' : 'grey900'),
                      )
                      .copyWith(height: 1.35),
                  child: Row(
                    children: [
                      if (widget.prefix != null) ...[
                        DefaultTextStyle.merge(
                          style: TextStyle(color: theme.color('blue500')),
                          child: widget.prefix!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: widget.title),
                      const SizedBox(width: 8),
                      widget.icon ?? TdsBoardRowArrowIcon(opened: opened),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: TdsMotion.small.duration,
            curve: TdsMotion.small,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: opened ? null : 0,
              child: ExcludeFocus(
                excluding: !opened,
                child: ExcludeSemantics(
                  excluding: !opened,
                  child: AnimatedOpacity(
                    opacity: opened ? 1 : 0,
                    duration:
                        (opened ? TdsMotion.basic : TdsMotion.quick).duration,
                    child: ColoredBox(
                      color: theme.color('blue500').withValues(alpha: .04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!opened && widget.showDivider)
          const TdsBorder(variant: TdsBorderVariant.padding24),
      ],
    );
  }
}

class TdsBoardRowArrowIcon extends StatelessWidget {
  const TdsBoardRowArrowIcon({this.opened = false, super.key});
  final bool opened;
  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: opened ? -.25 : .25,
    duration: TdsMotion.small.duration,
    curve: TdsMotion.small,
    child: TdsAssetIcon(
      name: 'arrow-rightwards',
      color: TdsTheme.of(context).color('grey500'),
    ),
  );
}

class TdsBoardRowPrefix extends StatelessWidget {
  const TdsBoardRowPrefix(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: TdsTheme.of(context).color('blue500')),
  );
}

class TdsBoardRowText extends StatelessWidget {
  const TdsBoardRowText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: TdsText(
      text,
      typography: TdsTypography.t6,
      style: const TextStyle(height: 1.5),
    ),
  );
}

class TdsGridList extends StatelessWidget {
  const TdsGridList({required this.children, this.columns = 3, super.key})
    : assert(columns >= 1 && columns <= 3);
  final List<Widget> children;
  final int columns;
  @override
  Widget build(BuildContext context) {
    final count = columns == 3 && TdsTheme.of(context).platform.fontScale >= 160
        ? 2
        : columns;
    // Rows use intrinsic height so large labels never get clipped by a fixed
    // aspect ratio. No nested scroll view is created.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i += count) ...[
            if (i > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < count; j++) ...[
                    if (j > 0) const SizedBox(width: 8),
                    Expanded(
                      child: i + j < children.length
                          ? children[i + j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TdsGridListItem extends StatelessWidget {
  const TdsGridListItem({
    required this.image,
    required this.label,
    this.onPressed,
    this.disabled = false,
    super.key,
  });
  final Widget image;
  final String label;
  final VoidCallback? onPressed;
  final bool disabled;
  @override
  Widget build(BuildContext context) => TdsPressable(
    enabled: !disabled,
    onPressed: onPressed,
    builder: (context, pressed, hovered, focused) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: TdsTheme.of(context).color(pressed ? 'grey100' : 'opacity50'),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 28),
            child: image,
          ),
          const SizedBox(height: 6),
          TdsText(
            label,
            typography: TdsTypography.st11,
            fontWeight: TdsFontWeight.medium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

enum TdsSelectorType { clear, arrow, underline }

class TdsSelector extends StatelessWidget {
  const TdsSelector({
    required this.text,
    required this.typography,
    this.type = TdsSelectorType.clear,
    this.fontWeight = TdsFontWeight.regular,
    this.color,
    this.disabled = false,
    this.onPressed,
    super.key,
  });
  final String text;
  final TdsTypography typography;
  final TdsSelectorType type;
  final TdsFontWeight fontWeight;
  final Color? color;
  final bool disabled;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final resolved = color ?? theme.color('grey600');
    final arrowSize = typography.index <= 2
        ? 31.0
        : typography.index <= 15
        ? 24.0
        : 20.0;
    return TdsPressable(
      enabled: !disabled,
      onPressed: onPressed,
      onPressStart: () => tdsHapticOf(context).generate(TdsHapticType.tickWeak),
      builder: (context, pressed, hovered, focused) => Opacity(
        opacity: disabled ? .38 : 1,
        child: AnimatedScale(
          scale: pressed ? .94 : 1,
          duration: (pressed ? TdsMotion.rapid : TdsMotion.quick).duration,
          curve: pressed ? TdsMotion.rapid : TdsMotion.quick,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: pressed
                  ? theme.color('greyOpacity100')
                  : const Color(0x00000000),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: TdsText(
                    text,
                    typography: typography,
                    color: resolved,
                    fontWeight: fontWeight,
                    style: TextStyle(
                      decoration: type == TdsSelectorType.underline
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ),
                if (type == TdsSelectorType.arrow)
                  RotatedBox(
                    quarterTurns: 1,
                    child: TdsAssetIcon(
                      name: 'arrow-rightwards',
                      size: arrowSize,
                      color: resolved,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
