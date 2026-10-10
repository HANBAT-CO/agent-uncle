import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('subtitle Text/Icon/Badge/Link share parent metrics and color', (
    tester,
  ) async {
    var clicks = 0;
    for (final size in [13, 15, 17]) {
      final typography = {
        13: TdsTypography.t7,
        15: TdsTypography.t6,
        17: TdsTypography.t5,
      }[size]!;
      await tester.pumpWidget(
        testApp(
          TdsTopSubtitleParagraph.rich(
            size: size,
            color: const Color(0xffab1234),
            children: [
              const TdsParagraphText(text: '부제 '),
              const WidgetSpan(
                child: TdsParagraphIcon(name: 'icon-arrow-right-mono'),
              ),
              const WidgetSpan(
                child: TdsParagraphBadge(
                  color: TdsBadgeColor.blue,
                  variant: TdsBadgeVariant.weak,
                  child: Text('새 소식'),
                ),
              ),
              WidgetSpan(
                child: TdsParagraphLink(text: '자세히', onPressed: () => clicks++),
              ),
            ],
          ),
        ),
      );
      final platform = TdsTheme.of(
        tester.element(find.byType(TdsParagraph)),
      ).platform;
      final fontSize = platform.size(typography).toInt();
      expect(
        tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon)).size,
        tdsIconHeights[fontSize],
      );
      final badgeStyle = DefaultTextStyle.of(
        tester.element(find.text('새 소식')),
      ).style;
      expect(badgeStyle.fontSize, tdsBadgeMetrics[fontSize]!.$1);
      final linkText = tester.widget<TdsText>(
        find.descendant(
          of: find.byType(TdsParagraphLink),
          matching: find.byType(TdsText),
        ),
      );
      expect(linkText.typography, typography);
      expect(
        linkText.fontWeight,
        size == 17 ? TdsFontWeight.medium : TdsFontWeight.regular,
      );
      expect(linkText.color, const Color(0xffab1234));
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();
    }
    expect(clicks, 3);
  });

  testWidgets(
    'nested text overrides do not change inherited icon metric family',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsParagraph(
            typography: TdsTypography.t5,
            color: Color(0xff112233),
            children: [
              TdsParagraphText(
                text: '큰 글씨',
                typography: TdsTypography.t1,
                fontWeight: TdsFontWeight.bold,
                color: Color(0xffcc0000),
                children: [
                  TdsParagraphText(text: ' inherited'),
                  WidgetSpan(
                    child: TdsParagraphIcon(name: 'icon-arrow-right-mono'),
                  ),
                  WidgetSpan(
                    child: TdsParagraphLink(text: 'link', onPressed: null),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(TdsParagraph),
              matching: find.byType(Text),
            )
            .first,
      );
      final span = (text.textSpan! as TextSpan).children!.single as TextSpan;
      final theme = TdsTheme.of(tester.element(find.byType(TdsParagraph)));
      expect(span.style!.fontSize, theme.platform.size(TdsTypography.t1));
      expect(span.style!.fontWeight, FontWeight.w700);
      expect(span.style!.color, const Color(0xffcc0000));
      final nested = span.children!.first as TextSpan;
      expect(nested.style!.fontSize, span.style!.fontSize);
      expect(nested.style!.fontWeight, span.style!.fontWeight);
      final icon = tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon));
      expect(
        icon.size,
        tdsIconHeights[theme.platform.size(TdsTypography.t5).toInt()],
      );
      final link = tester.widget<TdsText>(find.byType(TdsText));
      expect(link.color, const Color(0xffcc0000));
      expect(link.fontWeight, TdsFontWeight.bold);
      expect(link.style!.fontSize, theme.platform.size(TdsTypography.t1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit compound metrics win and plain typed spans wrap', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const Center(
          child: SizedBox(
            width: 90,
            child: TdsTopSubtitleParagraph.rich(
              size: 13,
              children: [
                TdsParagraphText(text: '여러 줄에 걸쳐서 이어지는 부제목입니다'),
                WidgetSpan(
                  child: TdsParagraphIcon(
                    name: 'icon-arrow-right-mono',
                    typography: TdsTypography.t1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final theme = TdsTheme.of(tester.element(find.byType(TdsParagraph)));
    expect(
      tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon)).size,
      tdsIconHeights[theme.platform.size(TdsTypography.t1).toInt()],
    );
    expect(tester.getSize(find.byType(TdsParagraph)).height, greaterThan(40));
    expect(tester.takeException(), isNull);
  });
}
