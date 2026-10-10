import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'theme.dart';
import 'tokens.g.dart';

/// Internal native equivalent of ListRow's compound context. Source Sr uses
/// unrounded, capped font sizes times 1.35, even on the mobile component path.
class TdsListRowSlotScope extends InheritedWidget {
  const TdsListRowSlotScope({
    required this.inLeft,
    required this.inRight,
    required this.alignTop,
    required this.firstTypography,
    required super.child,
    super.key,
  });
  final bool inLeft, inRight, alignTop;
  final TdsTypography firstTypography;
  static TdsListRowSlotScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TdsListRowSlotScope>();

  static double marginFor(BuildContext context, double height) {
    final scope = maybeOf(context);
    final scale = TdsTheme.of(context).platform.fontScale;
    if (scope?.alignTop != true || scale < 135) return 0;
    final type = scope!.firstTypography;
    final firstLine =
        math.min(type.baseSize * scale / 100, tdsWebFontSizeCaps[type.index]) *
        1.35;
    return math.max(0, (firstLine - height) / 2);
  }

  @override
  bool updateShouldNotify(TdsListRowSlotScope oldWidget) =>
      inLeft != oldWidget.inLeft ||
      inRight != oldWidget.inRight ||
      alignTop != oldWidget.alignTop ||
      firstTypography != oldWidget.firstTypography;
}
