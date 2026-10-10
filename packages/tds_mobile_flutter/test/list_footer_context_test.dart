import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;
import 'list_footer_color_test.dart' show textInk, iconInk;
import 'list_footer_replay_test.dart' show scaleOf, shadowOf;

Widget contextFooter({
  required bool dark,
  String textToken = 'grey200',
  String iconToken = 'green500',
  bool lateText = false,
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
            key: ValueKey('inherited-icon'),
            name: 'icon-arrow-right-mono',
          ),
          TdsListFooterIcon(
            key: const ValueKey('explicit-icon'),
            name: 'icon-arrow-right-mono',
            colorToken: iconToken,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TdsListFooterText(child: Text('상속')),
          TdsListFooterText(colorToken: textToken, child: const Text('명시')),
          if (lateText)
            TdsListFooterText(colorToken: textToken, child: const Text('추가')),
        ],
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    final theme = TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    );
    for (final icon in [false, true]) {
      Widget fixture(String token) => contextFooter(
        dark: dark,
        textToken: icon ? 'red500' : token,
        iconToken: icon ? token : 'green500',
      );

      testWidgets(
        'pressed-only dependency keeps the release snapshot dark=$dark icon=$icon',
        (tester) async {
          await tester.pumpWidget(fixture('grey200'));
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          final pressed = textInk(tester, '상속');
          await gesture.up();
          await tester.pumpAndSettle();
          await tester.pumpWidget(fixture('hairlineBorder'));
          await tester.pumpAndSettle();
          expect(scaleOf(tester), 1);
          expect(shadowOf(tester), 0);
          expect(
            textInk(tester, '상속'),
            theme.color(icon ? 'red500' : 'grey200'),
          );
          expect(
            iconInk(tester, 'inherited-icon'),
            theme.color(icon ? 'grey200' : 'green500'),
          );
          // Both contexts now change, but release must still own its old save.
          await tester.pumpWidget(fixture('blue500'));
          await tester.pumpAndSettle();
          expect(scaleOf(tester), .96);
          expect(shadowOf(tester), 1);
          expect(textInk(tester, '상속'), pressed);
          expect(textInk(tester, '명시'), pressed);
          expect(
            iconInk(tester, 'inherited-icon'),
            theme.color(icon ? 'blue500' : 'green500'),
          );
        },
      );

      testWidgets(
        'pressed-only change leaves the active release clock running dark=$dark icon=$icon',
        (tester) async {
          await tester.pumpWidget(fixture('grey200'));
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          final pressed = textInk(tester, '상속');
          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 35));
          await tester.pumpWidget(fixture('hairlineBorder'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 30));
          final progress = TdsMotion.rapid.transform(
            65000 / TdsMotion.rapid.duration.inMicroseconds,
          );
          expect(scaleOf(tester), closeTo(.96 + .04 * progress, 1e-8));
          expect(shadowOf(tester), closeTo(1 - progress, 1e-8));
          await tester.pumpAndSettle();
          expect(scaleOf(tester), 1);
          await tester.pumpWidget(fixture('blue500'));
          await tester.pumpAndSettle();
          expect(scaleOf(tester), .96);
          expect(textInk(tester, '상속'), pressed);
        },
      );

      testWidgets(
        'equal-valued semantic aliases still replace the press context dark=$dark icon=$icon',
        (tester) async {
          await tester.pumpWidget(fixture('greyBackground'));
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          expect(scaleOf(tester), .96);
          await tester.pumpWidget(fixture('backgroundLevelB01'));
          await tester.pumpAndSettle();
          expect(scaleOf(tester), 1);
          expect(shadowOf(tester), 0);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(scaleOf(tester), 1);
        },
      );
    }

    testWidgets('press and release keep independent target lists dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        contextFooter(dark: dark, textToken: 'hairlineBorder'),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(contextFooter(dark: dark, lateText: true));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsListFooter)),
      );
      await tester.pumpAndSettle();
      expect(textInk(tester, '추가'), theme.color('grey300'));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), theme.color('grey200'));
      expect(textInk(tester, '명시'), theme.color('grey200'));
      expect(textInk(tester, '추가'), theme.color('grey300'));
      await tester.pumpWidget(
        contextFooter(dark: dark, textToken: 'blue500', lateText: true),
      );
      await tester.pumpAndSettle();
      expect(textInk(tester, '상속'), theme.color('grey300'));
      expect(textInk(tester, '추가'), theme.color('blue500'));
    });

    for (final level in [800, 900]) {
      testWidgets(
        'context dependencies retain source CSS serialization dark=$dark level=$level',
        (tester) async {
          await tester.pumpWidget(
            contextFooter(dark: dark, textToken: 'opacity$level'),
          );
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(TdsListFooter)),
          );
          await tester.pumpAndSettle();
          if (level == 900) {
            await gesture.up();
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(
            contextFooter(dark: dark, textToken: 'greyOpacity$level'),
          );
          await tester.pumpAndSettle();
          final reset = level == 800 ? dark : !dark;
          expect(scaleOf(tester), reset ? 1 : .96);
          expect(shadowOf(tester), reset ? 0 : 1);
          if (level == 800) {
            await gesture.up();
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }
}
