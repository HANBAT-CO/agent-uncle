import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/paragraph_scope.dart';
import '../foundation/line_box.dart';

enum TdsBadgeSize { xsmall, small, medium, large }

enum TdsBadgeVariant { fill, weak }

enum TdsBadgeColor { blue, teal, green, red, yellow, elephant }

class TdsBadge extends StatelessWidget {
  const TdsBadge({
    required this.child,
    required this.size,
    required this.color,
    required this.variant,
    super.key,
  });
  final Widget child;
  final TdsBadgeSize size;
  final TdsBadgeColor color;
  final TdsBadgeVariant variant;
  @override
  Widget build(BuildContext context) => TdsParagraphBadge(
    typography: switch (size) {
      TdsBadgeSize.xsmall => TdsTypography.t5,
      TdsBadgeSize.small => TdsTypography.t3,
      TdsBadgeSize.medium => TdsTypography.t2,
      TdsBadgeSize.large => TdsTypography.t1,
    },
    color: color,
    variant: variant,
    fontWeight: size == TdsBadgeSize.xsmall ? FontWeight.w600 : FontWeight.w700,
    child: child,
  );
}

class TdsParagraphBadge extends StatelessWidget {
  const TdsParagraphBadge({
    required this.child,
    required this.color,
    required this.variant,
    this.typography,
    this.fontWeight = FontWeight.w700,
    super.key,
  });
  final Widget child;
  final TdsBadgeColor color;
  final TdsBadgeVariant variant;
  final TdsTypography? typography;
  final FontWeight fontWeight;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final typeface =
        typography ??
        TdsParagraphScope.maybeOf(context)?.typography ??
        TdsTypography.st10;
    final metrics = tdsBadgeMetrics[theme.platform.size(typeface).toInt()]!;
    final name = '${color.name[0].toUpperCase()}${color.name.substring(1)}';
    final background = variant == TdsBadgeVariant.weak
        ? theme.color('t${name}BadgeBackground')
        : switch (color) {
            TdsBadgeColor.blue => TdsPalette.blue500,
            TdsBadgeColor.teal => TdsPalette.teal600,
            TdsBadgeColor.green => TdsPalette.green600,
            TdsBadgeColor.red => TdsPalette.red500,
            TdsBadgeColor.yellow => TdsPalette.yellow500,
            TdsBadgeColor.elephant => TdsPalette.grey700,
          };
    final foreground = variant == TdsBadgeVariant.weak
        ? theme.color('t${name}BadgeColor')
        : color == TdsBadgeColor.yellow
        ? TdsPalette.grey800
        : TdsPalette.white;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: metrics.$2,
        horizontal: metrics.$3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(metrics.$4),
      ),
      child: DefaultTextStyle(
        style: theme.textStyle().copyWith(
          fontSize: metrics.$1,
          height: 1.5,
          fontWeight: fontWeight,
          color: foreground,
        ),
        child: child is Text && (child as Text).style == null
            ? TdsLineBox(lineHeight: metrics.$1 * 1.5, child: child)
            : child,
      ),
    );
  }
}
