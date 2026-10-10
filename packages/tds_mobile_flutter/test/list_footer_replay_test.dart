import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'list_footer_color_test.dart' show footerFixture, textInk, iconInk;

double scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

double shadowOf(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(TdsListFooterShadow),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  for (final dark in [false, true]) {
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets(
        'unrendered press does not leave a color snapshot dark=$dark kind=$kind',
        (tester) async {
          await tester.pumpWidget(footerFixture(dark: dark));
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
            kind: kind,
          );
          // No frame is rendered between the two events. The source's lazy
          // press tween never initialized, so release saves the CSS fallback.
          await gesture.up();
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            footerFixture(dark: dark, childColor: TdsPalette.blue500),
          );
          await tester.pumpAndSettle();
          expect(textInk(tester, '상속'), TdsPalette.blue500);
          expect(textInk(tester, '명시'), TdsPalette.blue500);
          expect(iconInk(tester, 'inherited-icon'), TdsPalette.green500);
          expect(scaleOf(tester), 1);
          expect(shadowOf(tester), 0);
        },
      );
    }
    testWidgets(
      'unrendered release cannot overwrite the next press cleanup dark=$dark',
      (tester) async {
        await tester.pumpWidget(footerFixture(dark: dark));
        await tester.pumpAndSettle();
        final point = tester.getCenter(find.byType(TdsListFooter));
        final first = await tester.startGesture(point);
        await first.up();
        final second = await tester.startGesture(point);
        await tester.pumpAndSettle();
        expect(textInk(tester, '상속'), TdsPalette.red600);
        await tester.pumpWidget(
          footerFixture(dark: dark, childColor: TdsPalette.blue500),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '상속'), TdsPalette.blue500);
        expect(textInk(tester, '명시'), TdsPalette.blue500);
        expect(scaleOf(tester), 1);
        expect(shadowOf(tester), 0);
        await second.up();
        await tester.pumpAndSettle();
      },
    );
    testWidgets(
      'advanced press rewinds immediately before an unrendered repeat dark=$dark',
      (tester) async {
        await tester.pumpWidget(footerFixture(dark: dark));
        await tester.pumpAndSettle();
        final point = tester.getCenter(find.byType(TdsListFooter));
        final first = await tester.startGesture(point);
        await tester.pumpAndSettle();
        await first.up();
        await tester.pumpAndSettle();
        final second = await tester.startGesture(point);
        await second.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          footerFixture(dark: dark, childColor: TdsPalette.blue500),
        );
        await tester.pumpAndSettle();
        // Unlike the fresh same-turn tap, this press rewound an advanced source
        // timeline at time zero. Its inline base color was actually rendered.
        expect(textInk(tester, '상속'), TdsPalette.red500);
        expect(textInk(tester, '명시'), TdsPalette.red500);
        expect(scaleOf(tester), 1);
        expect(shadowOf(tester), 0);
      },
    );
    testWidgets(
      'repeated down keeps its latest initialized snapshot dark=$dark',
      (tester) async {
        await tester.pumpWidget(footerFixture(dark: dark));
        await tester.pumpAndSettle();
        final point = tester.getCenter(find.byType(TdsListFooter));
        final first = await tester.startGesture(point, pointer: 1);
        await tester.pumpAndSettle();
        final second = await tester.startGesture(point, pointer: 2);
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          footerFixture(dark: dark, childColor: TdsPalette.blue500),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '상속'), TdsPalette.red600);
        expect(scaleOf(tester), .96);
        expect(shadowOf(tester), 1);
        expect(iconInk(tester, 'inherited-icon'), TdsPalette.green500);
        await second.up();
        await first.up();
        await tester.pumpAndSettle();
      },
    );
    testWidgets(
      'repeated partial releases save the latest rendered press dark=$dark',
      (tester) async {
        await tester.pumpWidget(footerFixture(dark: dark));
        await tester.pumpAndSettle();
        final point = tester.getCenter(find.byType(TdsListFooter));
        final first = await tester.startGesture(point);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final firstColor = textInk(tester, '상속');
        await first.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        final second = await tester.startGesture(point);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final savedColor = textInk(tester, '상속');
        final savedScale = scaleOf(tester), savedShadow = shadowOf(tester);
        expect(savedColor, isNot(firstColor));
        await second.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          footerFixture(dark: dark, childColor: TdsPalette.blue500),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '상속'), savedColor);
        expect(textInk(tester, '명시'), savedColor);
        expect(scaleOf(tester), savedScale);
        expect(shadowOf(tester), savedShadow);
        expect(iconInk(tester, 'inherited-icon'), TdsPalette.green500);
      },
    );
  }
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final cancel in [false, true]) {
      testWidgets('unmounted raw input is inert kind=$kind cancel=$cancel', (
        tester,
      ) async {
        await tester.pumpWidget(footerFixture());
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TdsListFooter)),
          kind: kind,
        );
        await tester.pumpWidget(const SizedBox());
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('release interpolates from the source rounded RGB channels', (
    tester,
  ) async {
    await tester.pumpWidget(footerFixture());
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TdsListFooter)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    // CSSPlugin rounds RGB on each render; release reads that rendered value,
    // not the hidden fractional channel from the old interpolation.
    final renderedPress = Color(textInk(tester, '상속')!.toARGB32());
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final progress = TdsMotion.rapid.transform(
      20000 / TdsMotion.rapid.duration.inMicroseconds,
    );
    final expected = Color.lerp(renderedPress, TdsPalette.red500, progress)!;
    expect(textInk(tester, '상속')!.toARGB32(), expected.toARGB32());
    await tester.pumpAndSettle();
  });
  testWidgets('fresh fast release starts from each descendant CSS color', (
    tester,
  ) async {
    await tester.pumpWidget(footerFixture(explicitLast: false));
    await tester.pumpAndSettle();
    expect(textInk(tester, '명시'), TdsPalette.red500);
    expect(textInk(tester, '상속'), TdsPalette.blue500);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TdsListFooter)),
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final progress = TdsMotion.rapid.transform(
      60000 / TdsMotion.rapid.duration.inMicroseconds,
    );
    final expected = Color.lerp(
      TdsPalette.red500,
      TdsPalette.blue500,
      progress,
    )!;
    expect(textInk(tester, '명시')!.toARGB32(), expected.toARGB32());
    expect(textInk(tester, '상속'), TdsPalette.blue500);
    await tester.pumpAndSettle();
  });
  testWidgets(
    'a fresh release initializes an absent icon variable from transparent black',
    (tester) async {
      await tester.pumpWidget(footerFixture());
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final progress = TdsMotion.rapid.transform(
        60000 / TdsMotion.rapid.duration.inMicroseconds,
      );
      // GSAP reads the unset --icon-color variable, not the SVG's fallback color.
      final expected = Color.lerp(
        const Color(0x00000000),
        TdsPalette.green500,
        progress,
      )!;
      expect(
        iconInk(tester, 'inherited-icon')!.toARGB32(),
        expected.toARGB32(),
      );
      expect(iconInk(tester, 'explicit-icon')!.toARGB32(), expected.toARGB32());
      await tester.pumpAndSettle();
      expect(iconInk(tester, 'inherited-icon'), TdsPalette.green500);
    },
  );
}
