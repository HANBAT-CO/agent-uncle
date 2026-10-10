import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import 'text.dart';
import 'asset.dart';
import 'badge.dart';
import 'button.dart';
import 'collections.dart';
import 'text_button.dart';

class TdsTop extends StatelessWidget {
  const TdsTop({
    required this.title,
    this.upper,
    this.subtitleTop,
    this.subtitleBottom,
    this.lower,
    this.right,
    this.upperGap = 24,
    this.lowerGap = 24,
    this.rightVerticalAlign = CrossAxisAlignment.center,
    super.key,
  });
  final Widget title;
  final Widget? upper, subtitleTop, subtitleBottom, lower, right;
  final double upperGap, lowerGap;
  final CrossAxisAlignment rightVerticalAlign;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: upperGap, bottom: lowerGap),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (upper != null) ...[upper!, const SizedBox(height: 16)],
        Row(
          crossAxisAlignment: rightVerticalAlign,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: right == null ? 24 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitleTop != null) ...[
                      Semantics(header: true, child: subtitleTop!),
                      const SizedBox(height: 4),
                    ],
                    Semantics(header: true, child: title),
                    if (subtitleBottom != null) ...[
                      const SizedBox(height: 4),
                      Semantics(header: true, child: subtitleBottom!),
                    ],
                  ],
                ),
              ),
            ),
            ?right,
          ],
        ),
        if (lower != null) ...[const SizedBox(height: 16), lower!],
      ],
    ),
  );
}

class TdsTopLowerButton extends TdsButton {
  const TdsTopLowerButton({
    required super.child,
    super.onPressed,
    super.color,
    super.variant,
    super.loading,
    super.disabled,
    super.size = TdsButtonSize.small,
    super.semanticLabel,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 20),
      child: super.build(context),
    ),
  );
}

class TdsTopLowerCTA extends StatelessWidget {
  const TdsTopLowerCTA({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      spacing: 8,
      children: [for (final child in children) Flexible(child: child)],
    ),
  );
}

class TdsTopLowerCTAButton extends TdsButton {
  const TdsTopLowerCTAButton({
    required super.child,
    super.onPressed,
    super.color,
    super.variant,
    super.loading,
    super.disabled,
    super.size = TdsButtonSize.large,
    super.display = TdsButtonDisplay.inline,
    super.semanticLabel,
    super.key,
  });
}

class TdsTopRightButton extends TdsButton {
  const TdsTopRightButton({
    required super.child,
    super.onPressed,
    super.color,
    super.variant,
    super.loading,
    super.disabled,
    super.size = TdsButtonSize.medium,
    super.semanticLabel,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: TdsTheme.of(context).platform.fontScale >= 200
        ? EdgeInsets.zero
        : const EdgeInsets.only(left: 8, right: 24),
    child: super.build(context),
  );
}

class TdsTopRightAssetContent extends StatelessWidget {
  const TdsTopRightAssetContent({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(left: 8, right: 24), child: child);
}

class TdsTopUpperAssetContent extends StatelessWidget {
  const TdsTopUpperAssetContent({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: child,
  );
}

class TdsTopRightArrow extends StatelessWidget {
  const TdsTopRightArrow({this.color, super.key});
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, right: 16),
    child: TdsAssetIcon(
      name: 'icon-arrow-right-small-mono',
      color: color ?? TdsTheme.of(context).color('grey600'),
    ),
  );
}

class TdsTopTitleTextButton extends TdsTextButton {
  const TdsTopTitleTextButton({
    required super.child,
    super.onPressed,
    super.disabled,
    super.color,
    super.fontWeight = TdsFontWeight.bold,
    super.size = TdsTextButtonSize.xlarge,
    super.variant = TdsTextButtonVariant.arrow,
    super.arrowPlacement = TdsArrowPlacement.inline,
    super.key,
  });
  @override
  Widget build(BuildContext context) => TdsTextButton(
    size: size,
    onPressed: onPressed,
    disabled: disabled,
    color: color,
    colorToken: color == null ? 'grey800' : null,
    fontWeight: fontWeight,
    variant: variant,
    arrowPlacement: arrowPlacement,
    child: child,
  );
}

class TdsTopSubtitleTextButton extends TdsTextButton {
  const TdsTopSubtitleTextButton({
    required super.child,
    super.onPressed,
    super.disabled,
    super.color,
    super.fontWeight,
    super.size = TdsTextButtonSize.medium,
    super.variant = TdsTextButtonVariant.arrow,
    super.arrowPlacement = TdsArrowPlacement.inline,
    super.key,
  });
  @override
  Widget build(BuildContext context) => TdsTextButton(
    size: size,
    onPressed: onPressed,
    disabled: disabled,
    color: color,
    colorToken: color == null ? 'grey700' : null,
    fontWeight: fontWeight,
    variant: variant,
    arrowPlacement: arrowPlacement,
    child: child,
  );
}

class TdsTopTitleSelector extends StatelessWidget {
  const TdsTopTitleSelector({
    required this.text,
    this.size = 22,
    this.typography,
    this.fontWeight = TdsFontWeight.bold,
    this.color,
    this.disabled = false,
    this.onPressed,
    super.key,
  }) : assert(size == 22 || size == 28);
  final String text;
  final int size;
  final TdsTypography? typography;
  final TdsFontWeight fontWeight;
  final Color? color;
  final bool disabled;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TdsSelector(
    text: text,
    typography:
        typography ?? (size == 22 ? TdsTypography.t3 : TdsTypography.st2),
    fontWeight: fontWeight,
    type: TdsSelectorType.arrow,
    disabled: disabled,
    color: color ?? TdsTheme.of(context).color('grey800'),
    onPressed: onPressed,
  );
}

class TdsTopSubtitleSelector extends StatelessWidget {
  const TdsTopSubtitleSelector({
    required this.text,
    this.size = 17,
    this.typography,
    this.fontWeight,
    this.color,
    this.disabled = false,
    this.onPressed,
    super.key,
  }) : assert(size == 13 || size == 15 || size == 17);
  final String text;
  final int size;
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;
  final bool disabled;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TdsSelector(
    text: text,
    typography:
        typography ??
        switch (size) {
          13 => TdsTypography.t7,
          15 => TdsTypography.t6,
          _ => TdsTypography.t5,
        },
    fontWeight:
        fontWeight ??
        (size == 17 ? TdsFontWeight.medium : TdsFontWeight.regular),
    type: TdsSelectorType.arrow,
    disabled: disabled,
    color: color ?? TdsTheme.of(context).color('grey700'),
    onPressed: onPressed,
  );
}

class TdsTopSubtitleBadge {
  const TdsTopSubtitleBadge({
    required this.text,
    required this.color,
    required this.variant,
  });
  final String text;
  final TdsBadgeColor color;
  final TdsBadgeVariant variant;
}

class TdsTopSubtitleBadges extends StatelessWidget {
  const TdsTopSubtitleBadges({required this.badges, super.key});
  final List<TdsTopSubtitleBadge> badges;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final badge in badges)
        TdsBadge(
          size: TdsBadgeSize.small,
          color: badge.color,
          variant: badge.variant,
          child: Text(badge.text),
        ),
    ],
  );
}

class TdsTopTitleParagraph extends StatelessWidget {
  const TdsTopTitleParagraph(
    this.text, {
    this.size = 22,
    this.typography,
    this.color,
    this.fontWeight = TdsFontWeight.bold,
    super.key,
  }) : assert(size == 22 || size == 28);
  final String text;
  final int size;
  final TdsTypography? typography;
  final Color? color;
  final TdsFontWeight fontWeight;
  @override
  Widget build(BuildContext context) => TdsText(
    text,
    typography:
        typography ?? (size == 22 ? TdsTypography.t3 : TdsTypography.st2),
    fontWeight: fontWeight,
    color: color ?? TdsTheme.of(context).color('grey800'),
  );
}

class TdsTopSubtitleParagraph extends StatelessWidget {
  const TdsTopSubtitleParagraph(
    this.text, {
    this.size = 17,
    this.typography,
    this.color,
    this.fontWeight,
    this.textAlign = TextAlign.start,
    this.ellipsisAfterLines,
    super.key,
  }) : children = null,
       assert(size == 13 || size == 15 || size == 17);

  /// Text/Icon/Badge/Link are the original Paragraph compounds, not new
  /// subtitle-specific controls. WidgetSpans inherit this paragraph's metrics.
  const TdsTopSubtitleParagraph.rich({
    required this.children,
    this.size = 17,
    this.typography,
    this.color,
    this.fontWeight,
    this.textAlign = TextAlign.start,
    this.ellipsisAfterLines,
    super.key,
  }) : text = null,
       assert(size == 13 || size == 15 || size == 17);
  final String? text;
  final List<InlineSpan>? children;
  final int size;
  final TdsTypography? typography;
  final Color? color;
  final TdsFontWeight? fontWeight;
  final TextAlign textAlign;
  final int? ellipsisAfterLines;
  @override
  Widget build(BuildContext context) {
    final typeface =
        typography ??
        switch (size) {
          13 => TdsTypography.t7,
          15 => TdsTypography.t6,
          _ => TdsTypography.t5,
        };
    final weight =
        fontWeight ??
        (size == 17 ? TdsFontWeight.medium : TdsFontWeight.regular);
    final ink = color ?? TdsTheme.of(context).color('grey700');
    if (children != null) {
      return TdsParagraph(
        children: children!,
        typography: typeface,
        fontWeight: weight,
        color: ink,
        textAlign: textAlign,
        ellipsisAfterLines: ellipsisAfterLines,
      );
    }
    return TdsText(
      text!,
      typography: typeface,
      fontWeight: weight,
      color: ink,
      textAlign: textAlign,
      ellipsisAfterLines: ellipsisAfterLines,
    );
  }
}

class TdsBottomInfo extends StatelessWidget {
  const TdsBottomInfo({
    required this.child,
    this.bottomGradient = true,
    this.gradient,
    super.key,
  });
  final Widget child;
  final bool bottomGradient;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    final color = TdsTheme.of(context).color('greyBackground');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: color,
          child: Padding(padding: const EdgeInsets.only(top: 24), child: child),
        ),
        if (bottomGradient)
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient:
                  gradient ??
                  LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, const Color(0x00ffffff)],
                  ),
            ),
          )
        else
          ColoredBox(color: color, child: const SizedBox(height: 24)),
      ],
    );
  }
}
