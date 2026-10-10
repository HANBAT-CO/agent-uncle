import 'package:flutter/widgets.dart';

/// CSS keep-all for non-selectable labels. The original text remains available
/// to semantics and widget consumers; word joiners affect only paragraph layout.
String tdsKeepAllText(String text) {
  final runes = text.runes.toList();
  bool cjk(int rune) =>
      rune >= 0x1100 && rune <= 0x11ff ||
      rune >= 0x2e80 && rune <= 0xa4cf ||
      rune >= 0xac00 && rune <= 0xd7af ||
      rune >= 0xf900 && rune <= 0xfaff ||
      rune >= 0x20000 && rune <= 0x3134f;
  final word = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);
  final result = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    if (i > 0 &&
        (cjk(runes[i - 1]) || cjk(runes[i])) &&
        word.hasMatch(String.fromCharCode(runes[i - 1])) &&
        word.hasMatch(String.fromCharCode(runes[i]))) {
      result.write('\u2060');
    }
    result.writeCharCode(runes[i]);
  }
  return result.toString();
}

class TdsKeepAllText extends Text {
  TdsKeepAllText.from(this.source, {this.after = const []})
    : super(source.data ?? '', key: source.key);
  final Text source;
  final List<InlineSpan> after;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        if (source.data != null) TextSpan(text: tdsKeepAllText(source.data!)),
        if (source.textSpan != null) source.textSpan!,
        ...after,
      ],
    ),
    style: source.style,
    strutStyle: source.strutStyle,
    textAlign: source.textAlign,
    textDirection: source.textDirection,
    locale: source.locale,
    softWrap: source.softWrap,
    overflow: source.overflow,
    textScaler: source.textScaler,
    maxLines: source.maxLines,
    semanticsLabel: source.semanticsLabel ?? source.data,
    textWidthBasis: source.textWidthBasis,
    textHeightBehavior: source.textHeightBehavior,
    selectionColor: source.selectionColor,
  ).build(context);
}
