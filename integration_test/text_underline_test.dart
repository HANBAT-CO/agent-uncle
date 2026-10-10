import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
import 'package:tds_mobile_flutter/src/foundation/text_underline.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native underlines retain hard-break line indices', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    const labels = [
      '토스 Ag\n\n끝 gyp',
      '\n토스 Ag\n\n끝 gyp',
      '자세한 내용을 확인하고 다음 안내도 읽어요',
    ];
    for (final dark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: scale,
            fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        var clicks = 0;
        final suffix =
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}';
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(suffix),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: TdsMobileProvider(
              theme: theme,
              child: ColoredBox(
                color: theme.color('background'),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0; index < labels.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: SizedBox(
                              width: 160,
                              child: TdsTextButton(
                                key: ValueKey('underline-$index'),
                                size: TdsTextButtonSize.medium,
                                variant: TdsTextButtonVariant.underline,
                                onPressed: () => clicks++,
                                child: Text(labels[index]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Capture before assertions, so a failing-before run keeps evidence.
        await binding.takeScreenshot('tds-native-underline-$suffix');
        final fontSize = theme.platform.size(TdsTypography.t5);
        final lineHeight = tdsCssLineHeight(fontSize * 1.252);
        for (var index = 0; index < 2; index++) {
          final button = find.byKey(ValueKey('underline-$index'));
          final render = tester.renderObject<RenderTdsTextUnderline>(
            find.descendant(
              of: button,
              matching: find.byType(TdsTextUnderline),
            ),
          );
          final line = tester.renderObject<RenderBox>(
            find.descendant(of: button, matching: find.byType(TdsLineBox)),
          );
          final offset = render.localToGlobal(Offset.zero, ancestor: line);
          final rects = render.underlineRects;
          expect(rects, hasLength(2));
          for (var row = 0; row < rects.length; row++) {
            expect(
              rects[row].top + offset.dy,
              closeTo(
                tdsCssTextBaseline(fontSize, lineHeight) +
                    (index + row * 2) * lineHeight +
                    fontSize * 534 / 2564 +
                    1,
                .001,
              ),
            );
          }
        }
        await tester.tap(find.byKey(const ValueKey('underline-0')));
        await tester.pumpAndSettle();
        expect(clicks, 1);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native long underline advance records remaining glyph drift', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    const count = 100;
    for (final scale in [100.0, 160.0]) {
      final theme = TdsThemeData(
        colorScheme: TdsColorPreference.light,
        platform: TdsPlatform(
          os: ios ? TdsOS.ios : TdsOS.android,
          fontScale: scale,
          fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
        ),
      );
      await tester.pumpWidget(
        WidgetsApp(
          key: ValueKey(('long', scale)),
          color: theme.color('background'),
          debugShowCheckedModeBanner: false,
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
          home: TdsMobileProvider(
            theme: theme,
            child: ColoredBox(
              color: theme.color('background'),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TdsTextButton(
                        size: TdsTextButtonSize.medium,
                        variant: TdsTextButtonVariant.underline,
                        child: Text(List.filled(count, '토스 Ag').join('\n')),
                      ),
                      const SizedBox(
                        width: 160,
                        height: 8,
                        child: ColoredBox(color: Color(0xff3182f6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fontSize = theme.platform.size(TdsTypography.t5);
      final height = tdsCssLineHeight(fontSize * 1.252);
      final rects = tester
          .renderObject<RenderTdsTextUnderline>(find.byType(TdsTextUnderline))
          .underlineRects;
      expect(rects, hasLength(count));
      expect(rects.last.top - rects.first.top, closeTo(99 * height, .001));
      // Native glyphs still use rounded line advances. Do not disguise this
      // remaining mismatch as a source-parity pass for the complete label.
      expect(
        tester.getSize(find.byType(RichText)).height,
        100 * height.round(),
      );
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, .001),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await binding.takeScreenshot(
        'tds-native-underline-long-100-${ios ? 'ios' : 'android'}-light-${scale.toInt()}',
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
