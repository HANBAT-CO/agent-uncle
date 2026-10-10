import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() => registerListReplayAsyncTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerListReplayAsyncTests(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  testWidgets('native footer interrupted replay and async input batches', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    final blink = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is TdsListRowBlinkPainter,
    );
    final shine = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is TdsListRowShinePainter,
    );
    Color? textColor(String label) =>
        DefaultTextStyle.of(tester.element(find.text(label))).style.color;
    double footerScale() => tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(TdsListFooter),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    for (final dark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
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
        var token = 'red500', generation = 0;
        var showFooter = true;
        late StateSetter update;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('list-replay', dark, scale)),
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
                          const TdsListHeader(
                            title: TdsListHeaderTitleParagraph('비동기 입력 검증'),
                          ),
                          TdsListRow(
                            controller: controller,
                            border: TdsListRowBorder.indented,
                            contents: const SizedBox(
                              height: 90,
                              child: TdsListRowTexts(
                                type: TdsListRowTextType.row2TypeA,
                                top: Text('토스뱅크'),
                                bottom: Text('입출금 통장'),
                              ),
                            ),
                          ),
                          TdsTextButton(
                            size: TdsTextButtonSize.medium,
                            onPressed: () async {
                              controller.shine();
                              await Future<void>.value();
                              controller.blink();
                            },
                            child: const Text('비동기 빛 → 깜빡임'),
                          ),
                          const SizedBox(height: 24),
                          const TdsListHeader(
                            title: TdsListHeaderTitleParagraph('반복 누름 · 색상 복원'),
                          ),
                          if (showFooter)
                            TdsListFooter(
                              key: ValueKey(generation),
                              onPressed: () {},
                              icon: const TdsListFooterIcon(
                                name: 'icon-arrow-right-mono',
                                colorToken: 'green500',
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const TdsListFooterText(child: Text('상속')),
                                  TdsListFooterText(
                                    colorToken: token,
                                    child: const Text('명시'),
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
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}';

        controller.shine();
        for (var i = 0; i < 5; i++) {
          await Future<void>.value();
        }
        controller.blink(duration: const Duration(milliseconds: 1800));
        await tester.pump();
        expect(blink, findsOneWidget);
        expect(shine, findsNothing);
        await tester.pump(const Duration(milliseconds: 200));
        await binding.takeScreenshot('tds-native-list-replay-batch-$suffix');
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        await tester.tap(find.text('비동기 빛 → 깜빡임'));
        await tester.pump();
        expect(shine, findsOneWidget);
        expect(blink, findsNothing);
        await tester.pump(const Duration(milliseconds: 250));
        await binding.takeScreenshot('tds-native-list-replay-discrete-$suffix');
        await tester.pumpAndSettle();

        final footer = find.byType(TdsListFooter);
        final fastTap = await tester.startGesture(tester.getCenter(footer));
        await fastTap.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final fadingIcon = tester
            .widget<TdsAssetIcon>(
              find.descendant(of: footer, matching: find.byType(TdsAssetIcon)),
            )
            .color!;
        expect(fadingIcon.a, greaterThan(0));
        expect(fadingIcon.a, lessThan(1));
        await tester.pumpAndSettle();
        update(() => token = 'blue500');
        await tester.pumpAndSettle();
        expect(textColor('상속'), theme.color('blue500'));
        expect(textColor('명시'), theme.color('blue500'));
        expect(footerScale(), 1);
        await tester.pump(const Duration(milliseconds: 100));
        await binding.takeScreenshot('tds-native-list-replay-fast-tap-$suffix');

        update(() {
          token = 'red500';
          generation++;
        });
        await tester.pumpAndSettle();
        final first = await tester.startGesture(tester.getCenter(footer));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await first.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        final second = await tester.startGesture(tester.getCenter(footer));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final savedColor = textColor('상속'), savedScale = footerScale();
        await second.up();
        await tester.pumpAndSettle();
        update(() => token = 'green500');
        await tester.pumpAndSettle();
        expect(textColor('상속'), savedColor);
        expect(textColor('명시'), savedColor);
        expect(footerScale(), savedScale);
        await tester.pump(const Duration(milliseconds: 100));
        await binding.takeScreenshot('tds-native-list-replay-revert-$suffix');

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
