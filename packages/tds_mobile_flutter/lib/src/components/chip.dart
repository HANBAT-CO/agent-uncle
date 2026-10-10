import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'asset_frames.g.dart';

enum TdsChipKind { select, action }

enum TdsChipShape { pill, square }

enum TdsChipSize { small, medium }

enum TdsChipVariant { fill, weak }

enum TdsChipMargin { none, small, medium, large }

class TdsChip extends StatelessWidget {
  const TdsChip({
    required this.children,
    this.kind = TdsChipKind.select,
    this.shape = TdsChipShape.pill,
    this.size = TdsChipSize.medium,
    this.variant = TdsChipVariant.fill,
    this.margin = TdsChipMargin.medium,
    this.wrap = false,
    this.withColorBackground = false,
    super.key,
  });
  final List<Widget> children;
  final TdsChipKind kind;
  final TdsChipShape shape;
  final TdsChipSize size;
  final TdsChipVariant variant;
  final TdsChipMargin margin;
  final bool wrap, withColorBackground;
  @override
  Widget build(BuildContext context) {
    final gap = shape == TdsChipShape.pill ? 6.0 : 7.0;
    final theme = TdsTheme.of(context);
    final height = math.max(
      size == TdsChipSize.small ? 32.0 : 38.0,
      theme.platform.size(
                size == TdsChipSize.small ? TdsTypography.t7 : TdsTypography.t6,
              ) *
              1.35 +
          5,
    );
    final rowGap = height >= 44
        ? 8.0
        : height > 40
        ? height.floorToDouble() - 36
        : height > 35
        ? math.max(
            size == TdsChipSize.small ? 0.0 : 2.0,
            height.floorToDouble() - 36,
          )
        : 0.0;
    return _ChipScope(
      chip: this,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: switch (margin) {
            TdsChipMargin.none => 0,
            TdsChipMargin.small => 16,
            TdsChipMargin.medium => 20,
            TdsChipMargin.large => 24,
          },
        ),
        child: wrap
            ? Wrap(spacing: gap, runSpacing: rowGap, children: children)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      children[i],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ChipScope extends InheritedWidget {
  const _ChipScope({required this.chip, required super.child});
  final TdsChip chip;
  static TdsChip of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChipScope>()?.chip ??
      const TdsChip(children: []);
  @override
  bool updateShouldNotify(_ChipScope oldWidget) => chip != oldWidget.chip;
}

class TdsChipItem extends StatelessWidget {
  const TdsChipItem({
    required this.text,
    this.selected = false,
    this.disabled = false,
    this.inert = false,
    this.redDot = false,
    this.redDotAriaLabel,
    this.left,
    this.right,
    this.onPressed,
    super.key,
  });
  final String text;
  final bool selected, disabled, inert, redDot;
  final String? redDotAriaLabel;
  final Widget? left, right;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final chip = _ChipScope.of(context), theme = TdsTheme.of(context);
    final small = chip.size == TdsChipSize.small,
        pill = chip.shape == TdsChipShape.pill;
    final active = selected && chip.kind == TdsChipKind.select;
    final dark = theme.colorScheme == TdsColorPreference.dark;
    final fgTheme = chip.withColorBackground
        ? theme.copyWith(colorScheme: TdsColorPreference.dark)
        : theme;
    var bg = chip.withColorBackground
        ? const Color(0x00000000)
        : theme.color('greyOpacity100');
    var border = fgTheme.color(
      chip.withColorBackground ? 'greyOpacity400' : 'greyOpacity50',
    );
    var fg = fgTheme.color('greyOpacity700');
    if (active) {
      if (chip.variant == TdsChipVariant.fill) {
        bg = fgTheme.color('greyOpacity800');
        border = fgTheme.color('greyOpacity500');
        fg = chip.withColorBackground
            ? const TdsThemeData().color('grey800')
            : theme.color('background');
      } else if (chip.withColorBackground) {
        bg = const TdsThemeData().color('greyOpacity300');
        border = fg = const Color(0xffffffff);
      } else {
        bg = theme
            .color(dark ? 'blue400' : 'blue500')
            .withValues(alpha: dark ? .24 : .10);
        border = theme.color('blue500').withValues(alpha: dark ? .52 : .32);
        fg = theme.color('blue800');
      }
    }
    final padding = small ? (pill ? 11.0 : 10.0) : (pill ? 13.0 : 12.0);
    return ExcludeSemantics(
      excluding: inert,
      child: IgnorePointer(
        ignoring: inert,
        child: Semantics(
          selected: chip.kind == TdsChipKind.select ? active : null,
          child: TdsPressable(
            enabled: !disabled && !inert,
            onPressed: onPressed,
            skipTraversal: onPressed == null || inert,
            button: onPressed != null,
            onPressStart: () =>
                tdsHapticOf(context).generate(TdsHapticType.tickWeak),
            builder: (context, pressed, hovered, focused) => AnimatedScale(
              scale: pressed ? .96 : 1,
              duration: (pressed ? TdsMotion.rapid : TdsMotion.quick).duration,
              curve: pressed ? TdsMotion.rapid : TdsMotion.quick,
              child: Opacity(
                opacity: disabled ? .5 : 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: TdsMotion.quick.duration,
                        curve: TdsMotion.quick,
                        constraints: BoxConstraints(
                          minWidth: small ? 52 : 64,
                          minHeight: small ? 32 : 38,
                        ),
                        padding: EdgeInsets.fromLTRB(
                          left == null ? padding : 0,
                          2,
                          right == null ? padding : 0,
                          2,
                        ),
                        decoration: BoxDecoration(
                          color: pressed
                              ? Color.alphaBlend(
                                  theme.color('greyOpacity100'),
                                  bg,
                                )
                              : bg,
                          border: Border.all(color: border, width: .66),
                          borderRadius: BorderRadius.circular(
                            pill
                                ? 999
                                : small
                                ? 8
                                : 10,
                          ),
                        ),
                        child: DefaultTextStyle(
                          style: theme
                              .textStyle(
                                typography: small
                                    ? TdsTypography.t7
                                    : TdsTypography.t6,
                                fontWeight: TdsFontWeight.semibold,
                                color: fg,
                              )
                              .copyWith(height: 1.35),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [?left, Text(text), ?right],
                          ),
                        ),
                      ),
                      if (redDot && !disabled)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Semantics(
                            label: redDotAriaLabel,
                            child: Container(
                              width: small ? 5 : 6,
                              height: small ? 5 : 6,
                              decoration: BoxDecoration(
                                color: theme.color('red500'),
                                shape: BoxShape.circle,
                              ),
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

class TdsChipItemLeftIcon extends StatelessWidget {
  const TdsChipItemLeftIcon({this.name, this.url, this.color, super.key})
    : assert(name != null || url != null);
  final String? name, url;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final small = _ChipScope.of(context).size == TdsChipSize.small;
    final size = small ? 16.0 : 18.0;
    return Padding(
      padding: EdgeInsets.only(
        left:
            (small ? 9 : 10) +
            (_ChipScope.of(context).shape == TdsChipShape.pill ? 1 : 0),
        right: small ? 5 : 6,
      ),
      child: url != null
          ? TdsAssetImage(
              src: url!,
              frameShape: TdsAssetFrameShape(width: size, height: size),
            )
          : TdsAssetIcon(name: name!, size: size, color: color),
    );
  }
}

class TdsChipItemLeftImage extends StatelessWidget {
  const TdsChipItemLeftImage({required this.src, super.key});
  final String src;
  @override
  Widget build(BuildContext context) {
    final small = _ChipScope.of(context).size == TdsChipSize.small;
    return Padding(
      padding: EdgeInsets.only(right: small ? 7 : 8),
      child: TdsAssetImage(
        src: src,
        frameShape: small
            ? TdsAssetFrames.circleXSmall
            : TdsAssetFrames.circleSmall,
      ),
    );
  }
}

class TdsChipItemLeftCard extends StatelessWidget {
  const TdsChipItemLeftCard({
    required this.src,
    this.rotateRight = false,
    super.key,
  });
  final String src;
  final bool rotateRight;
  @override
  Widget build(BuildContext context) {
    final small = _ChipScope.of(context).size == TdsChipSize.small;
    return Padding(
      padding: EdgeInsets.only(
        left:
            (small ? 11 : 12) +
            (_ChipScope.of(context).shape == TdsChipShape.pill ? 2 : 0),
        right: small ? 6 : 7,
      ),
      child: RotatedBox(
        quarterTurns: rotateRight ? 1 : 3,
        child: TdsAssetImage(
          src: src,
          frameShape: small
              ? TdsAssetFrames.cardXXXSmall
              : TdsAssetFrames.cardXXSmall,
        ),
      ),
    );
  }
}

enum TdsChipRightIconType { dropdown, close, custom }

class TdsChipItemRightIcon extends StatelessWidget {
  const TdsChipItemRightIcon({
    this.type = TdsChipRightIconType.dropdown,
    this.name,
    this.url,
    this.color,
    super.key,
  }) : assert(
         type != TdsChipRightIconType.custom || name != null || url != null,
       );
  final TdsChipRightIconType type;
  final String? name, url;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final small = _ChipScope.of(context).size == TdsChipSize.small;
    final pill = _ChipScope.of(context).shape == TdsChipShape.pill;
    final custom = type == TdsChipRightIconType.custom;
    final scale = TdsTheme.of(context).platform.fontScale;
    final size = !custom && scale >= (small ? 216 : 187)
        ? 24.0
        : !custom && scale >= (small ? 147 : 127)
        ? 22.0
        : small
        ? 16.0
        : 18.0;
    return Padding(
      padding: EdgeInsets.only(
        left: (small ? 3 : 4) + (custom ? 2 : 0),
        right: (small ? 8 : 9) + (pill ? 1 : 0) + (custom ? 1 : 0),
      ),
      child: url != null
          ? TdsAssetImage(
              src: url!,
              frameShape: TdsAssetFrameShape(width: size, height: size),
            )
          : TdsAssetIcon(
              name:
                  name ??
                  switch (type) {
                    TdsChipRightIconType.dropdown =>
                      'icon-chip-arrow-down-mono',
                    TdsChipRightIconType.close => 'icon-chip-x-mono',
                    TdsChipRightIconType.custom => '',
                  },
              size: size,
              color: color ?? DefaultTextStyle.of(context).style.color,
            ),
    );
  }
}

class TdsChipItemRightNumber extends StatelessWidget {
  const TdsChipItemRightNumber(this.text, {this.unit, super.key});
  final String text;
  final String? unit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 4,
      right: _ChipScope.of(context).size == TdsChipSize.small ? 11 : 13,
    ),
    child: Text(text, semanticsLabel: '$text${unit ?? ''}'),
  );
}
