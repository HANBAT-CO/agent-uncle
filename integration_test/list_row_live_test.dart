import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() => registerListRowLiveTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerListRowLiveTests(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('native ListRow live size, retarget and theme replacement', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    final shine = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is TdsListRowShinePainter,
    );
    TdsListRowShinePainter painter() =>
        tester.widget<CustomPaint>(shine).painter! as TdsListRowShinePainter;
    for (final initialDark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        var dark = initialDark;
        var width = 320.4, height = 80.4;
        late StateSetter update;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('list-row-live', initialDark, scale)),
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final before = painter();
        expect(before.dark, initialDark);
        expect(before.translateFromX, -312);
        expect(before.translateToX, 320);
        update(() {
          width = 240.6;
          height = 120.2;
        });
        await tester.pump();
        final resized = painter();
        expect(resized.elapsed, greaterThanOrEqualTo(before.elapsed));
        expect(resized.translateFromX, before.translateFromX);
        expect(resized.translateToX, before.translateToX);
        final size = tester.getSize(find.byType(TdsListRowEffects));
        expect(
          resized.boundsForSize(size).width,
          closeTo(initialDark ? size.width * 4 : size.height * 3, .001),
        );
        await binding.takeScreenshot(
          'tds-native-list-row-resized-${ios ? 'ios' : 'android'}-${initialDark ? 'dark' : 'light'}-${scale.toInt()}',
        );
        controller.shine(playCount: 2);
        await tester.pump();
        if (!initialDark) expect(painter().translateToX, 241);
        update(() => dark = !initialDark);
        await tester.pump(); // Apply replacement before settling its new clock.
        expect(painter().dark, !initialDark);
        expect(painter().elapsed, lessThan(before.elapsed));
        expect(painter().translateFromX, -432);
        expect(painter().translateToX, 241);
        await tester.pump(const Duration(milliseconds: 550));
        await binding.takeScreenshot(
          'tds-native-list-row-theme-${ios ? 'ios' : 'android'}-${initialDark ? 'dark-to-light' : 'light-to-dark'}-${scale.toInt()}',
        );
        // A one-cycle replacement would already be gone at this point.
        await tester.pump(const Duration(milliseconds: 2200));
        expect(shine, findsOneWidget);
        await tester.pumpAndSettle();
        expect(shine, findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
