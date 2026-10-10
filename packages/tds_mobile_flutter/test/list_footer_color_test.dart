import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

Widget footerFixture({
  bool explicitLast = true,
  bool dark = false,
  bool showExplicit = true,
  Color? childColor = TdsPalette.red500,
  String? childColorToken,
  Color? rootColor,
}) => testApp(
  TdsMobileProvider(
    theme: TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    ),
    child: TdsListFooter(
      onPressed: () {},
      textColor: rootColor,
      icon: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TdsListFooterIcon(
            key: ValueKey('inherited-icon'),
            name: 'icon-arrow-right-mono',
          ),
          TdsListFooterIcon(
            key: ValueKey('explicit-icon'),
            name: 'icon-arrow-right-mono',
            color: TdsPalette.green500,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (explicitLast)
            const TdsListFooterText(
              key: ValueKey('inherited'),
              child: Text('상속'),
            ),
          if (showExplicit)
            Padding(
              padding: EdgeInsets.zero,
              child: TdsListFooterText(
                key: const ValueKey('explicit'),
                color: childColor,
                colorToken: childColorToken,
                child: const Text('명시'),
              ),
            ),
          if (!explicitLast)
            const TdsListFooterText(
              key: ValueKey('inherited'),
              child: Text('상속'),
            ),
        ],
      ),
    ),
  ),
);

Color? textInk(WidgetTester tester, String label) {
  final element = tester.element(find.text(label));
  return (element.widget as Text).style?.color ??
      DefaultTextStyle.of(element).style.color;
}

Color? iconInk(WidgetTester tester, String key) => tester
    .widget<TdsAssetIcon>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TdsAssetIcon),
      ),
    )
    .color;

void main() {
  testWidgets(
    'adaptive tokens follow theme while static palette colors stay static',
    (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          footerFixture(
            dark: dark,
            childColor: null,
            childColorToken: 'red500',
          ),
        );
        await tester.pumpAndSettle();
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
        );
        expect(textInk(tester, '상속'), theme.color('red500'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TdsListFooter)),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '명시'), theme.color('red600'));
        await gesture.up();
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'string icon shorthand follows registered text, not initial icon color',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsMobileProvider(
            child: TdsListFooter(
              iconName: 'icon-arrow-right-mono',
              iconColor: TdsPalette.green500,
              child: TdsListFooterText(
                color: TdsPalette.red500,
                child: Text('문자 아이콘'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon)).color,
        TdsPalette.red500,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon)).color,
        TdsPalette.red600,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'touchcancel retains source appearance, theme remount clears it',
    (tester) async {
      await tester.pumpWidget(footerFixture());
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pumpAndSettle();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), TdsPalette.red600);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .96,
      );
      await tester.pumpWidget(footerFixture(dark: true));
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), TdsPalette.red500);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    },
  );
  for (final changesColor in [false, true]) {
    testWidgets(
      'late child and source selector snapshot changeColor=$changesColor',
      (tester) async {
        Widget fixture(bool late) => testApp(
          TdsMobileProvider(
            child: TdsListFooter(
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TdsListFooterText(
                    key: ValueKey('first'),
                    color: TdsPalette.red500,
                    child: Text('처음'),
                  ),
                  if (late)
                    TdsListFooterText(
                      key: const ValueKey('late'),
                      color: changesColor ? TdsPalette.blue500 : null,
                      child: const Text('나중'),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(fixture(false));
        await tester.pumpAndSettle();
        final first = await tester.startGesture(
          tester.getCenter(find.byType(TdsListFooter)),
        );
        await tester.pumpAndSettle();
        await first.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(fixture(true));
        await tester.pumpAndSettle();
        expect(
          textInk(tester, '처음'),
          changesColor ? TdsPalette.red600 : TdsPalette.red500,
        );
        expect(
          textInk(tester, '나중'),
          changesColor ? TdsPalette.blue500 : TdsPalette.red500,
        );
        final next = await tester.startGesture(
          tester.getCenter(find.byType(TdsListFooter)),
        );
        await tester.pumpAndSettle();
        expect(
          textInk(tester, '처음'),
          changesColor ? TdsPalette.blue600 : TdsPalette.red600,
        );
        expect(
          textInk(tester, '나중'),
          changesColor ? TdsPalette.blue600 : TdsPalette.red500,
        );
        await next.up();
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'shared rapid clock interpolates color, scale and shadow and resumes release',
    (tester) async {
      await tester.pumpWidget(footerFixture());
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final progress = TdsMotion.rapid.transform(
        60000 / TdsMotion.rapid.duration.inMicroseconds,
      );
      final pressedColor = Color.lerp(
        TdsPalette.red500,
        TdsPalette.red600,
        progress,
      )!;
      expect(textInk(tester, '상속')!.toARGB32(), pressedColor.toARGB32());
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        closeTo(1 - .04 * progress, 1e-8),
      );
      final shadow = find.descendant(
        of: find.byType(TdsListFooterShadow),
        matching: find.byType(AnimatedOpacity),
      );
      expect(
        tester.widget<AnimatedOpacity>(shadow).opacity,
        closeTo(progress, 1e-8),
      );
      await gesture.up();
      await tester.pump();
      expect(textInk(tester, '상속')!.toARGB32(), pressedColor.toARGB32());
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), TdsPalette.red500);
    },
  );
  testWidgets(
    'color dependency change reverts the two source motion contexts in order',
    (tester) async {
      await tester.pumpWidget(footerFixture());
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), TdsPalette.red500);
      await tester.pumpWidget(footerFixture(childColor: TdsPalette.blue500));
      await tester.pumpAndSettle();
      // GSAP release-context cleanup restores its saved pre-release inline
      // styles, after the press context reverted. This surprising source state
      // is not a newly pressed pointer and must not be "corrected" to blue.
      expect(textInk(tester, '상속'), TdsPalette.red600);
      expect(textInk(tester, '명시'), TdsPalette.red600);
      // GSAP's CSS-variable cleanup removes --icon-color, unlike its saved
      // ordinary `color` property. The icon falls back to its registered CSS.
      expect(iconInk(tester, 'inherited-icon'), TdsPalette.green500);
      expect(iconInk(tester, 'explicit-icon'), TdsPalette.green500);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .96,
      );
      final shadow = find.descendant(
        of: find.byType(TdsListFooterShadow),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(shadow).opacity, 1);
    },
  );
  testWidgets(
    'a fresh held-press reconfiguration restores CSS without a release snapshot',
    (tester) async {
      await tester.pumpWidget(footerFixture());
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(footerFixture(childColor: TdsPalette.green500));
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), TdsPalette.green500);
      expect(textInk(tester, '명시'), TdsPalette.green500);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
  for (final dark in [false, true]) {
    for (final explicitLast in [false, true]) {
      testWidgets(
        'wrapped registration and common motion dark=$dark explicitLast=$explicitLast',
        (tester) async {
          await tester.pumpWidget(
            footerFixture(dark: dark, explicitLast: explicitLast),
          );
          await tester.pumpAndSettle();
          final theme = TdsThemeData(
            colorScheme: dark
                ? TdsColorPreference.dark
                : TdsColorPreference.light,
          );
          final registered = explicitLast
              ? TdsPalette.red500
              : theme.color('blue500');
          final pressed = explicitLast
              ? TdsPalette.red600
              : theme.color('blue600');
          expect(textInk(tester, '명시'), TdsPalette.red500);
          expect(textInk(tester, '상속'), registered);
          // Text and icon have independent registration slots.
          expect(iconInk(tester, 'inherited-icon'), TdsPalette.green500);
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pump();
          await tester.pump(TdsMotion.rapid.duration);
          expect(textInk(tester, '상속'), pressed);
          expect(textInk(tester, '명시'), pressed);
          expect(iconInk(tester, 'inherited-icon'), TdsPalette.green600);
          expect(iconInk(tester, 'explicit-icon'), TdsPalette.green600);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(textInk(tester, '상속'), registered);
          // The source's shared inline animation now overrides the explicit CSS
          // color too, until this child remounts or another motion is applied.
          expect(textInk(tester, '명시'), registered);
        },
      );
    }
  }
  testWidgets('last descendant color survives descendant removal', (
    tester,
  ) async {
    await tester.pumpWidget(footerFixture());
    await tester.pumpAndSettle();
    await tester.pumpWidget(footerFixture(showExplicit: false));
    await tester.pumpAndSettle();
    expect(textInk(tester, '상속'), TdsPalette.red500);
  });
  testWidgets('parent color props are initial values, not controlled updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      footerFixture(showExplicit: false, rootColor: TdsPalette.blue500),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      footerFixture(showExplicit: false, rootColor: TdsPalette.red500),
    );
    await tester.pumpAndSettle();
    expect(textInk(tester, '상속'), TdsPalette.blue500);
  });
  testWidgets('arbitrary raw color propagates but is not inventedly darkened', (
    tester,
  ) async {
    const literal = Color(0xff123456);
    await tester.pumpWidget(footerFixture(childColor: literal));
    await tester.pumpAndSettle();
    expect(textInk(tester, '상속'), literal);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TdsListFooter)),
    );
    await tester.pumpAndSettle();
    expect(textInk(tester, '상속'), literal);
    expect(textInk(tester, '명시'), literal);
    await gesture.up();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'registration is isolated to its nearest footer and safe on teardown',
    (tester) async {
      Widget footer(String label, Color color) => TdsListFooter(
        child: Column(
          children: [
            TdsListFooterText(child: Text(label)),
            TdsListFooterText(color: color, child: const Text('등록')),
          ],
        ),
      );
      await tester.pumpWidget(
        testApp(
          TdsMobileProvider(
            child: Column(
              children: [
                footer('첫째', TdsPalette.red500),
                footer('둘째', TdsPalette.green500),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(textInk(tester, '첫째'), TdsPalette.red500);
      expect(textInk(tester, '둘째'), TdsPalette.green500);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
