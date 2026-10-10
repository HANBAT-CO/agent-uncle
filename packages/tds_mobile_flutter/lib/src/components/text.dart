import 'package:flutter/widgets.dart';
import '../foundation/line_box.dart';
import '../foundation/paragraph_scope.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/pressable.dart';
import '../foundation/touch_inset.dart';
import '../foundation/word_break.dart';
import 'asset.dart';

class TdsText extends StatelessWidget {
  const TdsText(
    this.data, {
    this.typography = TdsTypography.st10,
    this.fontWeight = TdsFontWeight.regular,
    this.color,
    this.textAlign,
    this.ellipsisAfterLines,
    this.style,
    this.semanticsLabel,
    super.key,
  });
  final String data;
  final TdsTypography typography;
  final TdsFontWeight fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? ellipsisAfterLines;
  final TextStyle? style;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) {
    var resolved = TdsTheme.of(context)
        .textStyle(typography: typography, fontWeight: fontWeight, color: color)
        .merge(style);
    final lineHeight = tdsCssLineHeight(resolved.fontSize! * resolved.height!);
    resolved = resolved.copyWith(height: lineHeight / resolved.fontSize!);
    return TdsLineBox(
      lineHeight: lineHeight,
      baseline:
          resolved.fontFamily == 'packages/tds_mobile_flutter/Toss Product Sans'
          ? tdsCssTextBaseline(resolved.fontSize!, lineHeight)
          : null,
      child: TdsKeepAllText.from(
        Text(
          data,
          style: resolved,
          textAlign: textAlign,
          maxLines: ellipsisAfterLines,
          overflow: ellipsisAfterLines == null
              ? TextOverflow.clip
              : TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}

/// Typed inline text stays breakable and selectable in the containing paragraph.
/// Unlike a WidgetSpan, it is not an indivisible native text widget.
class TdsParagraphText extends TextSpan {
  const TdsParagraphText({
    super.text,
    super.children,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
    this.typography,
    this.fontWeight,
    this.color,
  });
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is TdsParagraphText &&
      super == other &&
      typography == other.typography &&
      fontWeight == other.fontWeight &&
      color == other.color;
  @override
  int get hashCode =>
      Object.hash(super.hashCode, typography, fontWeight, color);
}

/// Paragraph uses inline spans to keep mixed text/assets in a single text flow.
class TdsParagraph extends StatelessWidget {
  const TdsParagraph({
    required this.children,
    this.typography = TdsTypography.st10,
    this.fontWeight = TdsFontWeight.regular,
    this.color,
    this.textAlign = TextAlign.start,
    this.ellipsisAfterLines,
    super.key,
  });
  final List<InlineSpan> children;
  final TdsTypography typography;
  final TdsFontWeight fontWeight;
  final Color? color;
  final TextAlign textAlign;
  final int? ellipsisAfterLines;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final style = theme.textStyle(
      typography: typography,
      fontWeight: fontWeight,
      color: color,
    );
    InlineSpan resolve(
      InlineSpan span,
      TextStyle parent,
      TdsFontWeight weight,
    ) {
      if (span is TextSpan) {
        var resolved = parent;
        if (span is TdsParagraphText) {
          if (span.typography != null) {
            final metrics = theme.textStyle(typography: span.typography!);
            resolved = resolved.copyWith(
              fontSize: metrics.fontSize,
              height: metrics.height,
            );
          }
          weight = span.fontWeight ?? weight;
          resolved = resolved.copyWith(
            fontWeight: weight.value,
            color: span.color,
          );
        }
        resolved = resolved.merge(span.style);
        weight = TdsFontWeight.values.firstWhere(
          (candidate) => candidate.value == resolved.fontWeight,
          orElse: () => weight,
        );
        return TextSpan(
          text: span.text,
          style: resolved,
          children: span.children
              ?.map((child) => resolve(child, resolved, weight))
              .toList(),
          recognizer: span.recognizer,
          mouseCursor: span.mouseCursor,
          onEnter: span.onEnter,
          onExit: span.onExit,
          semanticsLabel: span.semanticsLabel,
          locale: span.locale,
          spellOut: span.spellOut,
        );
      }
      if (span is WidgetSpan) {
        return WidgetSpan(
          alignment: span.alignment,
          baseline: span.baseline,
          style: span.style,
          child: TdsParagraphScope(
            typography: typography,
            fontWeight: weight,
            color: parent.color!,
            textStyle: parent,
            child: DefaultTextStyle(style: parent, child: span.child),
          ),
        );
      }
      return span;
    }

    return Text.rich(
      TextSpan(
        children: children
            .map((span) => resolve(span, style, fontWeight))
            .toList(),
      ),
      style: style,
      textAlign: textAlign,
      maxLines: ellipsisAfterLines,
      overflow: ellipsisAfterLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
      textScaler: TextScaler.noScaling,
    );
  }
}

class TdsSpacing extends StatelessWidget {
  const TdsSpacing(this.size, {this.direction = Axis.vertical, super.key});
  final double size;
  final Axis direction;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: direction == Axis.horizontal ? size : null,
    height: direction == Axis.vertical ? size : null,
  );
}

class TdsParagraphIcon extends StatelessWidget {
  const TdsParagraphIcon({
    required this.name,
    this.alt,
    this.color,
    this.typography,
    super.key,
  });
  final String name;
  final String? alt;
  final Color? color;
  final TdsTypography? typography;
  @override
  Widget build(BuildContext context) => TdsAssetIcon(
    name: name,
    alt: alt,
    color: color,
    size:
        tdsIconHeights[TdsTheme.of(context).platform
            .size(
              typography ??
                  TdsParagraphScope.maybeOf(context)?.typography ??
                  TdsTypography.st10,
            )
            .toInt()]!,
  );
}

enum TdsParagraphLinkType { underline, clear }

/// Use in a WidgetSpan. Navigation is explicit and keeps router ownership in the app.
class TdsParagraphLink extends StatelessWidget {
  const TdsParagraphLink({
    required this.text,
    required this.onPressed,
    this.type = TdsParagraphLinkType.clear,
    this.typography,
    this.fontWeight,
    this.color,
    super.key,
  });
  final String text;
  final VoidCallback? onPressed;
  final TdsParagraphLinkType type;
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final inherited = TdsParagraphScope.maybeOf(context);
    final typeface = typography ?? inherited?.typography ?? TdsTypography.st10;
    final weight = fontWeight ?? inherited?.fontWeight ?? TdsFontWeight.regular;
    final theme = TdsTheme.of(context),
        metrics =
            tdsLinkMetrics[TdsTheme.of(
              context,
            ).platform.size(typeface).toInt()]!;
    final insets = EdgeInsets.symmetric(
      horizontal: metrics.$2,
      vertical: metrics.$1,
    );
    final ink =
        color ??
        inherited?.color ??
        (type == TdsParagraphLinkType.clear
            ? TdsPalette.blue500
            : theme.color('grey600'));
    return Semantics(
      link: true,
      child: TdsTouchInset(
        insets: insets,
        child: TdsPressable(
          button: false,
          onPressed: onPressed,
          builder: (context, pressed, hovered, focused) => Container(
            padding: insets,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(metrics.$3),
              color: pressed
                  ? theme.color('greyOpacity100')
                  : const Color(0x00000000),
            ),
            child: TdsText(
              text,
              typography: typeface,
              fontWeight: weight,
              color: ink,
              style: TextStyle(
                fontSize: typography == null
                    ? inherited?.textStyle.fontSize
                    : null,
                height: typography == null ? inherited?.textStyle.height : null,
                decoration: type == TdsParagraphLinkType.underline
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: ink,
                decorationThickness:
                    weight.index >= TdsFontWeight.semibold.index
                    ? metrics.$5
                    : metrics.$4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum TdsBorderVariant { full, padding24, height16 }

class TdsBorder extends StatelessWidget {
  const TdsBorder({
    this.variant = TdsBorderVariant.full,
    this.height,
    super.key,
  });
  final TdsBorderVariant variant;
  final double? height;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: variant == TdsBorderVariant.padding24 ? 24 : 0,
    ),
    child: SizedBox(
      height: variant == TdsBorderVariant.height16 ? height ?? 16 : 1,
      child: variant == TdsBorderVariant.height16
          ? ColoredBox(color: TdsTheme.of(context).color('greyBackground'))
          : Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: .5,
                child: ColoredBox(
                  color:
                      TdsTheme.of(context).colorScheme ==
                          TdsColorPreference.light
                      ? const Color.fromRGBO(0, 0, 33, .07)
                      : const Color.fromRGBO(222, 222, 255, .14),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
    ),
  );
}
