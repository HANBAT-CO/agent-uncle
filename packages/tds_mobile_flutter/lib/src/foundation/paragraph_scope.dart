import 'package:flutter/widgets.dart';
import 'theme.dart';

/// Native equivalent of Paragraph's inherited CSS metric/color variables.
/// Text spans may override text metrics without changing icon/badge metrics.
class TdsParagraphScope extends InheritedWidget {
  const TdsParagraphScope({
    required this.typography,
    required this.fontWeight,
    required this.color,
    required this.textStyle,
    required super.child,
    super.key,
  });
  final TdsTypography typography;
  final TdsFontWeight fontWeight;
  final Color color;
  final TextStyle textStyle;
  static TdsParagraphScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TdsParagraphScope>();
  @override
  bool updateShouldNotify(TdsParagraphScope oldWidget) =>
      typography != oldWidget.typography ||
      fontWeight != oldWidget.fontWeight ||
      color != oldWidget.color ||
      textStyle != oldWidget.textStyle;
}
