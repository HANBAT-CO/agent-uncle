import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() => registerListFooterContextTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerListFooterContextTests(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  testWidgets('native footer keeps independent press and release contexts', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    final footer = find.byType(TdsListFooter);
    Color? textColor(String label) =>
        DefaultTextStyle.of(tester.element(find.text(label))).style.color;
    Color? iconColor() => tester
        .widget<TdsAssetIcon>(
          find.descendant(
            of: find.byKey(const ValueKey('inherited-icon')),
            matching: find.byType(TdsAssetIcon),
          ),
        )
        .color;
    double footerScale() => tester
        .widget<AnimatedScale>(
          find.descendant(of: footer, matching: find.byType(AnimatedScale)),
        )
        .scale;
    double shadow() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(TdsListFooterShadow),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    Future<void> capture(String name) async {
      // The live engine's raster surface can trail the already-asserted widget
      // state by one frame after post-frame descendant registration. Present a
      // stable frame before the platform copies that surface into the PNG.
      await tester.pump(const Duration(milliseconds: 100));
      await binding.takeScreenshot(name);
    }

    for (final dark in [false, true]) {
      for (final fontScale in [100.0, 160.0]) {
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: fontScale,
            fontA11y: fontScale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        var textToken = 'grey200', iconToken = 'green500', generation = 0;
        var lateText = false, showFooter = true;
        var phase = '누름 · 해제 독립 설정';
        late StateSetter update;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('footer-contexts', dark, fontScale)),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return TdsMobileProvider(
                  theme: theme,
                  child: ColoredBox(
                    color: theme.color('background'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TdsListHeader(
                            title: TdsListHeaderTitleParagraph(phase),
                          ),
                          const SizedBox(height: 24),
                          if (showFooter)
                            TdsListFooter(
                              key: ValueKey(generation),
                              onPressed: () {},
                              icon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const TdsListFooterIcon(
                                    key: ValueKey('inherited-icon'),
                                    name: 'icon-arrow-right-mono',
                                  ),
                                  TdsListFooterIcon(
                                    name: 'icon-arrow-right-mono',
                                    colorToken: iconToken,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const TdsListFooterText(child: Text('상속')),
                                  TdsListFooterText(
                                    colorToken: textToken,
                                    child: const Text('명시'),
                                  ),
                                  if (lateText)
                                    TdsListFooterText(
                                      colorToken: textToken,
                                      child: const Text('추가'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final suffix =
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${fontScale.toInt()}';

        for (final changeIcon in [false, true]) {
          void change(String token) => update(() {
            if (changeIcon) {
              iconToken = token;
            } else {
              textToken = token;
            }
          });
          void reset() => update(() {
            generation++;
            textToken = changeIcon ? 'red500' : 'grey200';
            iconToken = changeIcon ? 'grey200' : 'green500';
          });
          reset();
          await tester.pumpAndSettle();
          final press = await tester.startGesture(tester.getCenter(footer));
          await tester.pumpAndSettle();
          final savedText = textColor('상속');
          await press.up();
          await tester.pumpAndSettle();
          change('hairlineBorder');
          update(() => phase = '누름 설정만 초기화');
          await tester.pumpAndSettle();
          expect(footerScale(), 1);
          expect(shadow(), 0);
          expect(
            textColor('상속'),
            theme.color(changeIcon ? 'red500' : 'grey200'),
          );
          expect(iconColor(), theme.color(changeIcon ? 'grey200' : 'green500'));
          if (!changeIcon) {
            await capture('tds-native-footer-contexts-cleanup-$suffix');
          }

          change('blue500');
          update(() => phase = '해제 설정의 이전 상태 복원');
          await tester.pumpAndSettle();
          expect(footerScale(), .96);
          expect(shadow(), 1);
          expect(textColor('상속'), savedText);
          expect(textColor('명시'), savedText);
          expect(iconColor(), theme.color(changeIcon ? 'blue500' : 'green500'));
          if (!changeIcon) {
            await capture('tds-native-footer-contexts-restore-$suffix');
          }

          reset();
          await tester.pumpAndSettle();
          final running = await tester.startGesture(tester.getCenter(footer));
          await tester.pumpAndSettle();
          final runningSave = textColor('상속');
          await running.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 35));
          change('hairlineBorder');
          // Exact 65ms progress is asserted by the fake-clock widget test.
          // Here the real engine must finish the retained release and keep its
          // pre-release save available for the later dependency change.
          await tester.pumpAndSettle();
          expect(footerScale(), 1);
          expect(shadow(), 0);
          change('blue500');
          await tester.pumpAndSettle();
          expect(footerScale(), .96);
          expect(textColor('상속'), runningSave);
        }

        update(() {
          generation++;
          textToken = 'hairlineBorder';
          iconToken = 'green500';
          phase = '하위 텍스트의 독립 대상 목록';
        });
        await tester.pumpAndSettle();
        update(() {
          textToken = 'grey200';
          lateText = true;
        });
        await tester.pumpAndSettle();
        final latePress = await tester.startGesture(tester.getCenter(footer));
        await tester.pumpAndSettle();
        expect(textColor('추가'), theme.color('grey300'));
        await latePress.up();
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('grey200'));
        expect(textColor('명시'), theme.color('grey200'));
        expect(textColor('추가'), theme.color('grey300'));
        await capture('tds-native-footer-contexts-late-$suffix');
        update(() => textToken = 'blue500');
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('grey300'));
        expect(textColor('추가'), theme.color('blue500'));

        update(() {
          generation++;
          lateText = false;
          textToken = 'greyBackground';
          phase = '같은 색의 토큰 별칭 변경';
        });
        await tester.pumpAndSettle();
        final alias = await tester.startGesture(tester.getCenter(footer));
        await tester.pumpAndSettle();
        expect(footerScale(), .96);
        update(() => textToken = 'backgroundLevelB01');
        await tester.pumpAndSettle();
        expect(footerScale(), 1);
        expect(shadow(), 0);
        await alias.up();
        await tester.pumpAndSettle();
        await capture('tds-native-footer-contexts-alias-$suffix');

        final removed = await tester.startGesture(tester.getCenter(footer));
        update(() => showFooter = false);
        await tester.pump();
        await removed.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
