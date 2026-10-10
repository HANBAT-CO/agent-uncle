import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:agent_uncle/tds_gallery.dart'
    show TdsListFooterEdgesReferenceFixture;

void main() => registerListFooterEdgesTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerListFooterEdgesTests(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  testWidgets('native Footer handles from-only colors and nested selectors', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    Color? textColor(String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style.color;
    Color? iconColor(String id) => tester
        .widget<TdsAssetIcon>(
          find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(TdsAssetIcon),
          ),
        )
        .color;
    double scale(String id) => tester
        .widget<AnimatedScale>(
          find
              .descendant(
                of: find.byKey(ValueKey('$id-footer')),
                matching: find.byType(AnimatedScale),
              )
              .first,
        )
        .scale;
    double shadow(String id) => tester
        .widget<AnimatedOpacity>(
          find
              .descendant(
                of: find.byKey(ValueKey('$id-footer')),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    Future<void> control(String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
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
        Future<void> mount({required bool nested}) async {
          await tester.pumpWidget(
            WidgetsApp(
              key: ValueKey(('footer-edges', dark, fontScale, nested)),
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
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: TdsListFooterEdgesReferenceFixture(nested: nested),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String phase) async {
          await tester.pump(const Duration(milliseconds: 100));
          await binding.takeScreenshot(
            'tds-native-footer-edges-$phase-${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${fontScale.toInt()}',
          );
        }

        await mount(nested: false);
        final first = await tester.startGesture(
          tester.getCenter(find.text('명시')),
        );
        await tester.pumpAndSettle();
        expect(textColor('명시'), theme.color('red500'));
        expect(iconColor('different-icon'), const Color(0x00000000));
        expect(scale('undefined'), .96);
        expect(shadow('undefined'), 1);
        await capture('from-only');
        await first.up();
        await tester.pumpAndSettle();
        expect(textColor('명시'), theme.color('disabledBlue500'));
        expect(iconColor('different-icon'), theme.color('disabledBlue500'));
        final second = await tester.startGesture(
          tester.getCenter(find.text('명시')),
        );
        await tester.pumpAndSettle();
        expect(textColor('명시'), theme.color('disabledBlue500'));
        expect(iconColor('different-icon'), theme.color('disabledBlue500'));
        await capture('repress');
        await second.up();
        await tester.pumpAndSettle();
        await control('색상 변경');
        await control('색상 복원');
        final third = await tester.startGesture(
          tester.getCenter(find.text('명시')),
        );
        await tester.pumpAndSettle();
        expect(iconColor('different-icon'), const Color(0x00000000));
        await third.up();
        await tester.pumpAndSettle();

        await mount(nested: true);
        final outer = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        expect(textColor('안쪽'), theme.color('blue600'));
        expect(iconColor('inner-icon'), theme.color('green600'));
        expect(scale('inner'), .96);
        expect(shadow('inner'), 1);
        await capture('nested');
        await outer.up();
        await tester.pumpAndSettle();
        expect(textColor('안쪽'), theme.color('blue500'));
        await control('초기화');
        for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
          final inner = await tester.startGesture(
            tester.getCenter(find.text('안쪽')),
            kind: kind,
          );
          await tester.pumpAndSettle();
          expect(textColor('안쪽'), theme.color('blue600'));
          await inner.up();
          await tester.pumpAndSettle();
          expect(textColor('안쪽'), theme.color('blue500'));
          expect(find.text('순서 안쪽 → 바깥'), findsOneWidget);
          // Wait out ht's 300ms compatibility-mouse suppression.
          await tester.pump(const Duration(milliseconds: 320));
          if (kind == PointerDeviceKind.touch) await control('초기화');
        }
        await capture('bubbled');
        await control('초기화');
        await control('안쪽 숨기기');
        await control('안쪽 복원');
        final late = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        expect(textColor('바깥'), theme.color('blue600'));
        expect(textColor('안쪽'), theme.color('red500'));
        expect(scale('inner'), 1);
        expect(shadow('inner'), 0);
        await capture('late');
        await late.up();
        await tester.pumpAndSettle();
        await control('바깥 색상 변경');
        final recaptured = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        expect(textColor('안쪽'), theme.color('teal600'));
        expect(scale('inner'), .96);
        expect(shadow('inner'), 1);
        await capture('recaptured');
        await control('안쪽 숨기기');
        await recaptured.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
