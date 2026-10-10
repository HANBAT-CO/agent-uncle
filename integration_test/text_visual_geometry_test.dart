import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
import 'package:agent_uncle/tds_gallery.dart'
    show TdsVisualTypographyFixture, TdsVisualFooterFixture;

void main() => registerTextVisualGeometryTests(
  IntegrationTestWidgetsFlutterBinding.ensureInitialized(),
);

void registerTextVisualGeometryTests(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  testWidgets(
    'native original-font baselines, wrapping, arrows and shadow bounds',
    (tester) async {
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      if (!ios) await binding.convertFlutterSurfaceToImage();
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
          final suffix =
              '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}';
          Future<void> mount(Widget child, String phase) async {
            await tester.pumpWidget(
              WidgetsApp(
                key: ValueKey((suffix, phase)),
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
                        padding: const EdgeInsets.only(top: 80),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
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
            await binding.takeScreenshot('tds-native-visual-$phase-$suffix');
          }

          for (final multiline in [false, true]) {
            final phase = multiline ? 'type-multiline' : 'type';
            await mount(
              TdsVisualTypographyFixture(
                weight: TdsFontWeight.medium,
                multiline: multiline,
              ),
              phase,
            );
            for (final type in [
              TdsTypography.t7,
              TdsTypography.t5,
              TdsTypography.t2,
              TdsTypography.t1,
            ]) {
              final render = tester.renderObject<RenderBox>(
                find.descendant(
                  of: find.byKey(ValueKey('type-${type.name}')),
                  matching: find.byType(TdsLineBox),
                ),
              );
              final size = theme.platform.size(type),
                  line = theme.platform.lineHeight(type);
              expect(
                render.size.height,
                closeTo(line * (multiline ? 2 : 1), .001),
              );
              expect(
                render.getDryBaseline(
                  render.constraints,
                  TextBaseline.alphabetic,
                ),
                closeTo(tdsCssTextBaseline(size, line), .001),
              );
            }
            await capture(phase);
          }

          await mount(const TdsVisualFooterFixture(), 'footer');
          expect(tester.getSize(find.byType(TdsListFooter)).height, 59);
          expect(
            tester.getSize(find.byType(TdsListFooterIcon)),
            const Size(24, 24),
          );
          await capture('footer');
          final press = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
            .96,
          );
          expect(
            tester
                .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
                .opacity,
            1,
          );
          await capture('footer-pressed');
          await press.up();
          await tester.pumpAndSettle();

          await mount(
            const TdsVisualFooterFixture(variant: 'multiline', width: 210),
            'footer-multiline',
          );
          final paragraph = tester.widget<RichText>(find.byType(RichText));
          expect(
            paragraph.text.toPlainText(),
            contains('화\u2060살\u2060표\u2060의'),
          );
          final line = tdsCssLineHeight(
            theme.platform.size(TdsTypography.t5) * 1.252,
          );
          final height = tester.getSize(find.byType(TdsLineBox)).height;
          expect(height, greaterThan(line * 2));
          expect(height / line, closeTo((height / line).roundToDouble(), .001));
          await capture('footer-multiline');

          for (final count in [40, 100]) {
            final phase = 'footer-long-$count';
            await mount(
              SizedBox(
                width: 342,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TdsListFooterText(
                      child: Text(List.filled(count, '토스 Ag').join('\n')),
                    ),
                    SizedBox(
                      key: const ValueKey('following-long-label'),
                      height: 8,
                      child: ColoredBox(color: theme.color('blue500')),
                    ),
                  ],
                ),
              ),
              phase,
            );
            final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
            // Exact expanding CSS flow is safe. Rounded-up painted advances
            // retain the old flow so the fix cannot introduce a new overlap.
            final expectedFlow = line.round() > line
                ? (count * line.round() / line).round() * line
                : count * line;
            expect(box.size.height, closeTo(expectedFlow, .001));
            expect(
              box.getDryLayout(box.constraints).height,
              closeTo(expectedFlow, .001),
            );
            expect(
              tester
                      .getTopLeft(
                        find.byKey(const ValueKey('following-long-label')),
                      )
                      .dy -
                  tester.getTopLeft(find.byType(TdsLineBox)).dy,
              closeTo(expectedFlow, .001),
            );
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable),
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            // Inspect the tail and the following flow marker. This is not a
            // painted-baseline parity assertion; later line advances differ.
            await capture(phase);
          }

          for (final width in [342.0, 333.25]) {
            final phase = width == 342 ? 'shadow' : 'shadow-fractional';
            await mount(
              TdsVisualFooterFixture(variant: 'shadow', width: width),
              phase,
            );
            final paint = tester.widget<CustomPaint>(
              find.descendant(
                of: find.byType(TdsListFooterShadow),
                matching: find.byType(CustomPaint),
              ),
            );
            final painter = paint.painter! as TdsListFooterShadowPainter;
            expect(
              painter.bounds(Size(width, 120)).width,
              tdsCssLineHeight(width * 1.2),
            );
            expect(
              painter.color,
              dark ? TdsPalette.whiteOpacity50 : TdsPalette.grey100,
            );
            await capture(phase);
          }
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
