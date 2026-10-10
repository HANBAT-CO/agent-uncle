import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() => registerListRowBlinkTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerListRowBlinkTests(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('native ListRow blink batches, live theme and retained reentry', (
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
    TdsListRowBlinkPainter painter() =>
        tester.widget<CustomPaint>(blink).painter! as TdsListRowBlinkPainter;
    for (final initialDark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        var dark = initialDark;
        var width = 320.4, height = 80.4;
        late StateSetter update;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('list-row-blink', initialDark, scale)),
            color: const Color(0xffffffff),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
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
                return TdsMobileProvider(
                  theme: theme,
                  child: ColoredBox(
                    color: theme.color('background'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: width,
                          child: TdsListRow(
                            controller: controller,
                            border: TdsListRowBorder.indented,
                            contents: SizedBox(
                              height: height,
                              child: const TdsListRowTexts(
                                type: TdsListRowTextType.row2TypeA,
                                top: Text('토스뱅크'),
                                bottom: Text('입출금 통장'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.shine();
        controller.blink(duration: const Duration(milliseconds: 1800));
        await tester.pump();
        expect(shine, findsNothing);
        expect(blink, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 650));
        final before = painter();
        update(() {
          dark = !initialDark;
          width = 240.6;
          height = 120.2;
        });
        await tester.pump();
        expect(painter().elapsed, greaterThanOrEqualTo(before.elapsed));
        expect(painter().dimmerOpacity, greaterThan(0));
        expect(
          painter().color,
          dark ? const Color(0xff3485fa) : TdsPalette.blue500,
        );
        expect(
          tester.getSize(find.byType(TdsListRowEffects)).width,
          closeTo(240.6, .001),
        );
        // Android's converted screenshot surface can still hold the previous
        // raster frame immediately after a logical layout/theme update.
        await tester.pump(const Duration(milliseconds: 100));
        await binding.takeScreenshot(
          'tds-native-list-row-blink-resized-${ios ? 'ios' : 'android'}-${initialDark ? 'dark-to-light' : 'light-to-dark'}-${scale.toInt()}',
        );
        await tester.pump(const Duration(milliseconds: 2000));
        await tester.pumpAndSettle();
        expect(blink, findsNothing);

        controller.blink(duration: const Duration(milliseconds: 300));
        controller.shine();
        await tester.pump();
        expect(blink, findsNothing);
        expect(shine, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 350));
        expect(shine, findsNothing);
        await tester.pumpAndSettle();

        controller.blink(duration: const Duration(milliseconds: 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        final departing = painter();
        expect(departing.dimmerOpacity, 0);
        expect(departing.opacity, inExclusiveRange(0, 1));
        controller.blink();
        await tester.pump();
        expect(painter().elapsed, greaterThanOrEqualTo(departing.elapsed));
        // Keep generous native timing bounds; exact 80/480ms delay samples
        // live in the deterministic widget tests, not screenshot timing.
        expect(painter().opacity, lessThan(.75));
        expect(painter().dimmerOpacity, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(painter().opacity, greaterThan(departing.opacity));
        expect(painter().dimmerOpacity, 0);
        await tester.pump(const Duration(milliseconds: 400));
        expect(painter().dimmerOpacity, greaterThan(0));
        await binding.takeScreenshot(
          'tds-native-list-row-blink-reentry-${ios ? 'ios' : 'android'}-${initialDark ? 'dark-to-light' : 'light-to-dark'}-${scale.toInt()}',
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pumpAndSettle();
        expect(blink, findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
