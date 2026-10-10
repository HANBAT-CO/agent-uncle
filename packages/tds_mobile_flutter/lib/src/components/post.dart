import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import 'text.dart';

/// Namespace counterpart; each member is also a normal composable Dart widget.
abstract final class TdsPost {
  static Widget h1(String text, {double paddingBottom = 0}) =>
      TdsPostH1(text, paddingBottom: paddingBottom);
  static Widget h2(String text, {double paddingBottom = 0}) =>
      TdsPostH2(text, paddingBottom: paddingBottom);
  static Widget h3(String text, {double paddingBottom = 0}) =>
      TdsPostH3(text, paddingBottom: paddingBottom);
  static Widget h4(String text, {double paddingBottom = 0}) =>
      TdsPostH4(text, paddingBottom: paddingBottom);
}

class TdsPostHeading extends StatelessWidget {
  const TdsPostHeading(
    this.text, {
    required this.level,
    this.typography,
    this.color,
    this.paddingBottom = 0,
    super.key,
  }) : assert(level >= 1 && level <= 4);
  final String text;
  final int level;
  final TdsTypography? typography;
  final Color? color;
  final double paddingBottom;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: EdgeInsets.fromLTRB(24, level <= 2 ? 16 : 8, 24, paddingBottom),
      child: TdsText(
        text,
        typography:
            typography ??
            [
              TdsTypography.t2,
              TdsTypography.t3,
              TdsTypography.st8,
              TdsTypography.t5,
            ][level - 1],
        fontWeight: TdsFontWeight.bold,
        color: color ?? TdsTheme.of(context).color('grey700'),
        style: const TextStyle(height: 1.35),
      ),
    ),
  );
}

class TdsPostH1 extends TdsPostHeading {
  const TdsPostH1(
    super.text, {
    super.typography,
    super.color,
    super.paddingBottom,
    super.key,
  }) : super(level: 1);
}

class TdsPostH2 extends TdsPostHeading {
  const TdsPostH2(
    super.text, {
    super.typography,
    super.color,
    super.paddingBottom,
    super.key,
  }) : super(level: 2);
}

class TdsPostH3 extends TdsPostHeading {
  const TdsPostH3(
    super.text, {
    super.typography,
    super.color,
    super.paddingBottom,
    super.key,
  }) : super(level: 3);
}

class TdsPostH4 extends TdsPostHeading {
  const TdsPostH4(
    super.text, {
    super.typography,
    super.color,
    super.paddingBottom,
    super.key,
  }) : super(level: 4);
}

class TdsPostParagraph extends StatelessWidget {
  const TdsPostParagraph(
    this.text, {
    this.typography = TdsTypography.t5,
    this.fontWeight = TdsFontWeight.regular,
    this.color,
    this.paddingBottom = 0,
    this.textAlign,
    super.key,
  });
  final String text;
  final TdsTypography typography;
  final TdsFontWeight fontWeight;
  final Color? color;
  final double paddingBottom;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, 0, 24, paddingBottom),
    child: TdsText(
      text,
      typography: typography,
      fontWeight: fontWeight,
      textAlign: textAlign,
      color: color ?? TdsTheme.of(context).color('grey700'),
      style: const TextStyle(height: 1.5),
    ),
  );
}

class TdsPostList extends StatelessWidget {
  const TdsPostList({
    required this.children,
    this.ordered = false,
    this.typography = TdsTypography.t5,
    this.paddingBottom = 0,
    super.key,
  });
  final List<Widget> children;
  final bool ordered;
  final TdsTypography typography;
  final double paddingBottom;
  @override
  Widget build(BuildContext context) => TdsFontScaleLimit(
    limit: 160,
    child: Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(ordered ? 16 : 24, 0, 24, paddingBottom),
        child: DefaultTextStyle(
          style: TdsTheme.of(context)
              .textStyle(
                typography: typography,
                color: TdsTheme.of(context).color('grey700'),
              )
              .copyWith(height: 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _PostListContext(
                  number: ordered ? i + 1 : null,
                  child: children[i] is TdsPostLi
                      ? children[i]
                      : TdsPostLi(child: children[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class TdsPostOl extends TdsPostList {
  const TdsPostOl({
    required super.children,
    super.typography,
    super.paddingBottom,
    super.key,
  }) : super(ordered: true);
}

class TdsPostUl extends TdsPostList {
  const TdsPostUl({
    required super.children,
    super.typography,
    super.paddingBottom,
    super.key,
  });
}

class _PostListContext extends InheritedWidget {
  const _PostListContext({required this.number, required super.child});
  final int? number;
  @override
  bool updateShouldNotify(_PostListContext oldWidget) =>
      number != oldWidget.number;
}

class TdsPostLi extends StatelessWidget {
  const TdsPostLi({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final number = context
        .dependOnInheritedWidgetOfExactType<_PostListContext>()
        ?.number;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: number == null ? 16 : 24,
          child: Text(
            number == null ? '•' : '$number.',
            textAlign: number == null ? TextAlign.center : TextAlign.right,
            style: TextStyle(
              fontWeight: number == null ? null : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class TdsPostHr extends StatelessWidget {
  const TdsPostHr({this.paddingBottom = 24, super.key});
  final double paddingBottom;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: paddingBottom),
    child: const TdsBorder(variant: TdsBorderVariant.padding24),
  );
}
