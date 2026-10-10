import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;
import 'list_footer_color_test.dart' show textInk, iconInk;
import 'list_footer_replay_test.dart' show scaleOf, shadowOf;

Widget undefinedFooter({
  required bool dark,
  String textToken = 'disabledBlue500',
  String iconToken = 'disabledBlue500',
}) => testApp(
  TdsMobileProvider(
    theme: TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    ),
    child: TdsListFooter(
      onPressed: () {},
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TdsListFooterIcon(
            key: ValueKey('inherit-icon'),
            name: 'icon-arrow-right-mono',
          ),
          const TdsListFooterIcon(
            key: ValueKey('different-icon'),
            name: 'icon-arrow-right-mono',
            colorToken: 'red500',
          ),
          TdsListFooterIcon(
            key: const ValueKey('last-icon'),
            name: 'icon-arrow-right-mono',
            colorToken: iconToken,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TdsListFooterText(child: Text('상속')),
          const TdsListFooterText(colorToken: 'red500', child: Text('명시')),
          TdsListFooterText(colorToken: textToken, child: const Text('마지막')),
        ],
      ),
    ),
  ),
);

Color roundedColor(Color color) => Color.from(
  alpha: (color.a * 10000).round() / 10000,
  red: (color.r * 255).round() / 255,
  green: (color.g * 255).round() / 255,
  blue: (color.b * 255).round() / 255,
);

void main() {
  for (final dark in [false, true]) {
    final theme = TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    );
    final disabled = theme.color('disabledBlue500');
    for (final target in ['text', 'icon', 'both']) {
      final textToken = target == 'icon' ? 'green500' : 'disabledBlue500';
      final iconToken = target == 'text' ? 'green500' : 'disabledBlue500';
      testWidgets('from-only Footer colors replay dark=$dark target=$target', (
        tester,
      ) async {
        await tester.pumpWidget(
          undefinedFooter(
            dark: dark,
            textToken: textToken,
            iconToken: iconToken,
          ),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '명시'), theme.color('red500'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TdsListFooter)),
        );
        await tester.pumpAndSettle();
        expect(scaleOf(tester), .96);
        expect(shadowOf(tester), 1);
        expect(
          textInk(tester, '명시'),
          theme.color(target == 'icon' ? 'green600' : 'red500'),
        );
        expect(
          iconInk(tester, 'different-icon'),
          target == 'text' ? theme.color('green600') : const Color(0x00000000),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(textInk(tester, '명시'), theme.color(textToken));
        expect(iconInk(tester, 'different-icon'), theme.color(iconToken));
        final second = await tester.startGesture(
          tester.getCenter(find.byType(TdsListFooter)),
        );
        await tester.pumpAndSettle();
        // Invalidate reads the new inline destination, not first-press CSS.
        expect(
          textInk(tester, '명시'),
          theme.color(target == 'icon' ? 'green600' : textToken),
        );
        expect(
          iconInk(tester, 'different-icon'),
          theme.color(target == 'text' ? 'green600' : iconToken),
        );
        await second.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'from-only Footer contexts revert dark=$dark target=$target',
        (tester) async {
          Widget initial() => undefinedFooter(
            dark: dark,
            textToken: textToken,
            iconToken: iconToken,
          );
          await tester.pumpWidget(initial());
          await tester.pumpAndSettle();
          final first = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          final firstPressedText = textInk(tester, '명시');
          await first.up();
          await tester.pumpAndSettle();
          final second = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            undefinedFooter(
              dark: dark,
              textToken: 'blue500',
              iconToken: 'green500',
            ),
          );
          await tester.pumpAndSettle();
          expect(scaleOf(tester), .96);
          expect(textInk(tester, '명시'), firstPressedText);
          // Icon context reversion removes the variable; explicit CSS wins.
          expect(iconInk(tester, 'different-icon'), theme.color('red500'));
          await second.up();
          await tester.pumpAndSettle();
          expect(textInk(tester, '명시'), theme.color('blue500'));
          await tester.pumpWidget(initial());
          await tester.pumpAndSettle();
          expect(textInk(tester, '명시'), firstPressedText);
          final third = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          expect(textInk(tester, '명시'), firstPressedText);
          expect(
            iconInk(tester, 'different-icon'),
            target == 'text'
                ? theme.color('green600')
                : const Color(0x00000000),
          );
          await third.up();
          await tester.pumpAndSettle();
        },
      );
    }

    testWidgets('from-only tweens begin at registered color dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(undefinedFooter(dark: dark));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 65));
      final progress = TdsMotion.rapid.transform(
        65000 / TdsMotion.rapid.duration.inMicroseconds,
      );
      expect(
        textInk(tester, '명시'),
        roundedColor(Color.lerp(disabled, theme.color('red500'), progress)!),
      );
      expect(
        iconInk(tester, 'different-icon'),
        roundedColor(Color.lerp(disabled, const Color(0x00000000), progress)!),
      );
      final textAtRelease = textInk(tester, '명시')!;
      final iconAtRelease = iconInk(tester, 'different-icon')!;
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 65));
      expect(
        textInk(tester, '명시'),
        roundedColor(Color.lerp(textAtRelease, disabled, progress)!),
      );
      expect(
        iconInk(tester, 'different-icon'),
        roundedColor(Color.lerp(iconAtRelease, disabled, progress)!),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('same RGBA static color still has a to target dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          TdsMobileProvider(
            theme: theme,
            child: const TdsListFooter(
              child: TdsListFooterText(
                color: TdsPalette.blue100,
                child: Text('static'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pumpAndSettle();
      expect(textInk(tester, 'static'), TdsPalette.blue200);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }
}
