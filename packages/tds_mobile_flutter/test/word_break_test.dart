import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';

void main() {
  test(
    'keep-all retains the source Text metadata as well as its rendering',
    () {
      const source = Text(
        '글자 확인',
        key: ValueKey('source'),
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
        strutStyle: StrutStyle(height: 1.8),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        locale: Locale('ko', 'KR'),
        softWrap: false,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        semanticsLabel: '원본 읽기',
        semanticsIdentifier: 'source-text',
        textWidthBasis: TextWidthBasis.longestLine,
        textHeightBehavior: TextHeightBehavior(applyHeightToLastDescent: false),
        selectionColor: Color(0xff3182f6),
      );
      final wrapped = TdsKeepAllText.from(source);
      expect(wrapped.data, source.data);
      expect(wrapped.key, source.key);
      expect(wrapped.style, source.style);
      expect(wrapped.strutStyle, source.strutStyle);
      expect(wrapped.textAlign, source.textAlign);
      expect(wrapped.textDirection, source.textDirection);
      expect(wrapped.locale, source.locale);
      expect(wrapped.softWrap, source.softWrap);
      expect(wrapped.maxLines, source.maxLines);
      expect(wrapped.overflow, source.overflow);
      expect(wrapped.textScaler, source.textScaler);
      expect(wrapped.semanticsLabel, source.semanticsLabel);
      expect(wrapped.semanticsIdentifier, source.semanticsIdentifier);
      expect(wrapped.textWidthBasis, source.textWidthBasis);
      expect(wrapped.textHeightBehavior, source.textHeightBehavior);
      expect(wrapped.selectionColor, source.selectionColor);
    },
  );
}
