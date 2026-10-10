import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
import 'text_field_test.dart' show fieldApp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native text line boxes measured against original fractional CSS metrics',
    () async {
      final fonts = FontLoader('packages/tds_mobile_flutter/Toss Product Sans')
        ..addFont(
          rootBundle.load(
            'packages/tds_mobile_flutter/assets/fonts/TossProductSans-400.ttf',
          ),
        );
      await fonts.load();
      for (final typography in [
        TdsTypography.t7,
        TdsTypography.t5,
        TdsTypography.t3,
        TdsTypography.t1,
      ]) {
        final theme = const TdsThemeData();
        final style = theme.textStyle(typography: typography);
        final painter = TextPainter(
          text: TextSpan(text: '토스 디자인', style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final strut = TextPainter(
          text: TextSpan(text: '토스 디자인', style: style),
          textDirection: TextDirection.ltr,
          strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
        )..layout();
        // The layout engine rounds a paragraph's outer box. Glyphs are not scaled.
        expect(
          painter.height,
          closeTo(theme.platform.lineHeight(typography), 1),
        );
        expect(strut.height, closeTo(theme.platform.lineHeight(typography), 1));
        painter.dispose();
        strut.dispose();
      }
    },
  );
  testWidgets(
    'fractional line box preserves CSS flow height without scaling text',
    (tester) async {
      await tester.pumpWidget(
        fieldApp(
          const TdsLineBox(
            lineHeight: 19.5,
            child: Text('이름', style: TextStyle(fontSize: 13, height: 1.5)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TdsLineBox)).height, 19.5);
      expect(tester.getSize(find.byType(Text)).height, 20);
    },
  );
  testWidgets('inline middle uses font metrics and the parent strut union', (
    tester,
  ) async {
    for (final height in [12.0, 24.0, 48.0, 72.0]) {
      await tester.pumpWidget(
        fieldApp(
          TdsInlineMiddle(
            child: SizedBox(
              key: const ValueKey('inline'),
              width: 100,
              height: height,
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(TdsInlineMiddle));
      expect(
        size.height,
        height == 12
            ? 24
            : height == 24
            ? 25.796875
            : height,
      );
      final delta =
          tester.getTopLeft(find.byKey(const ValueKey('inline'))).dy -
          tester.getTopLeft(find.byType(TdsInlineMiddle)).dy;
      expect(
        delta,
        height == 12
            ? 7.796875
            : height == 24
            ? 1.796875
            : 0,
      );
    }
  });
  testWidgets(
    'Bubble preserves source strut at 100 percent and scaled multiline height',
    (tester) async {
      for (final scale in [100.0, 200.0]) {
        await tester.pumpWidget(
          fieldApp(
            TdsTheme(
              data: TdsThemeData(
                platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
              ),
              child: const TdsBubble(
                background: TdsBubbleBackground.grey,
                child: Text('토스'),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(TdsBubble)).height,
          scale == 100 ? 49.796875 : 66,
        );
      }
    },
  );
}
