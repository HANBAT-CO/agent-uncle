import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() => registerListInputColorTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerListInputColorTests(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('native mixed input order and descendant footer color lifecycle', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    final shine = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is TdsListRowShinePainter,
    );
    final blink = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is TdsListRowBlinkPainter,
    );
    Color? textColor(String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style.color;
    Color? iconColor() => tester
        .widget<TdsAssetIcon>(
          find.descendant(
            of: find.byKey(const Key('inherited-icon')),
            matching: find.byType(TdsAssetIcon),
          ),
        )
        .color;
    double footerScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    for (final initialDark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        var dark = initialDark, showExplicit = true;
        var inputMode = 0, clicks = 0;
        var token = 'red500';
        late StateSetter update;
        late TdsThemeData theme;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('list-input-color', initialDark, scale)),
            color: const Color(0xffffffff),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                theme = TdsThemeData(
                  colorScheme: dark
                      ? TdsColorPreference.dark
                      : TdsColorPreference.light,
                  platform: TdsPlatform(
                    os: ios ? TdsOS.ios : TdsOS.android,
                    fontScale: scale,
                    fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
                  ),
                );
                return TdsMobileProvider(
                  theme: theme,
                  child: ColoredBox(
                    color: theme.color('background'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const TdsListHeader(
                            title: TdsListHeaderTitleParagraph('혼합 입력 순서'),
                          ),
                          Listener(
                            onPointerDown: (_) {
                              if (inputMode == 1) controller.shine();
                            },
                            onPointerUp: (_) {
                              if (inputMode == 1) controller.shine();
                            },
                            child: TdsListRow(
                              controller: controller,
                              border: TdsListRowBorder.indented,
                              onPressed: () {
                                clicks++;
                                if (inputMode == 2) {
                                  controller.blink(
                                    duration: const Duration(
                                      milliseconds: 1800,
                                    ),
                                  );
                                }
                              },
                              contents: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (_) {
                                  if (inputMode == 0) controller.shine();
                                },
                                child: const SizedBox(
                                  key: Key('input-target'),
                                  height: 90,
                                  child: TdsListRowTexts(
                                    type: TdsListRowTextType.row2TypeA,
                                    top: Text('토스뱅크'),
                                    bottom: Text('입출금 통장'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const TdsListHeader(
                            title: TdsListHeaderTitleParagraph('하위 색상 전파'),
                          ),
                          TdsListFooter(
                            onPressed: () {},
                            icon: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TdsListFooterIcon(
                                  key: Key('inherited-icon'),
                                  name: 'icon-arrow-right-mono',
                                ),
                                TdsListFooterIcon(
                                  name: 'icon-arrow-right-mono',
                                  colorToken: 'green500',
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const TdsListFooterText(child: Text('상속')),
                                if (showExplicit)
                                  Padding(
                                    padding: EdgeInsets.zero,
                                    child: TdsListFooterText(
                                      colorToken: token,
                                      child: const Text('명시'),
                                    ),
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
        final target = tester.getCenter(find.byKey(const Key('input-target')));
        final childPress = await tester.startGesture(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(shine, findsNothing);
        final rowTransform = find
            .descendant(
              of: find.byType(TdsListRowEffects),
              matching: find.byType(Transform),
            )
            .first;
        expect(
          tester.widget<Transform>(rowTransform).transform.entry(0, 0),
          lessThan(.98),
        );
        await childPress.up();
        await tester.pumpAndSettle();
        update(() => inputMode = 1);
        await tester.pump();
        final ancestorPress = await tester.startGesture(target);
        await tester.pump();
        expect(shine, findsOneWidget);
        await ancestorPress.up();
        await tester.pump();
        // Touch end runs before the ancestor's command. Unlike window mouseup,
        // it must leave that shine active after the pointer has been released.
        expect(shine, findsOneWidget);
        await tester.pumpAndSettle();
        update(() => inputMode = 2);
        await tester.pump();
        final before = clicks;
        await tester.tapAt(target);
        await tester.pump();
        expect(clicks, before + 1);
        expect(blink, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();
        expect(blink, findsNothing);

        final suffix =
            '${ios ? 'ios' : 'android'}-${initialDark ? 'dark' : 'light'}-${scale.toInt()}';
        expect(textColor('상속'), theme.color('red500'));
        expect(iconColor(), theme.color('green500'));
        final footer = find.byType(TdsListFooter);
        final press = await tester.startGesture(tester.getCenter(footer));
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('red600'));
        expect(textColor('명시'), theme.color('red600'));
        expect(iconColor(), theme.color('green600'));
        expect(footerScale(), .96);
        await binding.takeScreenshot(
          'tds-native-list-input-color-press-$suffix',
        );
        await press.up();
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('red500'));
        expect(footerScale(), 1);

        update(() => token = 'green500');
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('red600'));
        expect(iconColor(), theme.color('green500'));
        expect(footerScale(), .96);
        await tester.pump(const Duration(milliseconds: 100));
        await binding.takeScreenshot(
          'tds-native-list-input-color-revert-$suffix',
        );

        update(() => dark = !initialDark);
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('green500'));
        expect(iconColor(), theme.color('green500'));
        expect(footerScale(), 1);
        update(() => showExplicit = false);
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('green500'));
        await tester.pump(const Duration(milliseconds: 100));
        await binding.takeScreenshot(
          'tds-native-list-input-color-theme-$suffix',
        );
        final cancel = await tester.startGesture(tester.getCenter(footer));
        await tester.pumpAndSettle();
        await cancel.cancel();
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('green600'));
        expect(footerScale(), .96);
        await binding.takeScreenshot(
          'tds-native-list-input-color-cancel-$suffix',
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
