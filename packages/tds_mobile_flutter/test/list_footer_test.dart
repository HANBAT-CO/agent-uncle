import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'hairline inherits indentation, explicit zero and negative offsets override it',
    (tester) async {
      for (final indent in [null, 0.0, 40.0, -10.0]) {
        await tester.pumpWidget(
          testApp(
            SizedBox(
              width: 300,
              child: TdsListFooter(
                border: TdsListFooterBorder.indented,
                hairline: TdsListFooterHairline(indent: indent),
                child: const Text('더 보기'),
              ),
            ),
          ),
        );
        final root = tester.getTopLeft(find.byType(TdsListFooter));
        final line = tester.getRect(find.byType(TdsBorder));
        expect(line.left - root.dx, indent ?? 24);
        expect(line.right, tester.getTopRight(find.byType(TdsListFooter)).dx);
        expect(line.height, 1);
      }
    },
  );
  testWidgets(
    'minimum row height includes arbitrary hairline and centers unwrapped custom content',
    (tester) async {
      for (final lineHeight in [0.0, 1.0, 8.0]) {
        await tester.pumpWidget(
          testApp(
            TdsListFooter(
              hairline: SizedBox(height: lineHeight),
              child: const SizedBox(key: Key('custom'), width: 80, height: 20),
            ),
          ),
        );
        expect(tester.getSize(find.byType(TdsListFooter)).height, 59);
        expect(
          tester.getTopLeft(find.byKey(const Key('custom'))).dy,
          lineHeight + (59 - lineHeight - 20) / 2,
        );
        expect(find.byType(TdsListFooterText), findsNothing);
        expect(find.byType(TdsListFooterShadow), findsNothing);
      }
    },
  );
  testWidgets(
    'interactive footer owns clipped ellipse shadow and rapid press/release transitions',
    (tester) async {
      var calls = 0;
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          testApp(
            TdsMobileProvider(
              theme: TdsThemeData(
                colorScheme: dark
                    ? TdsColorPreference.dark
                    : TdsColorPreference.light,
              ),
              child: TdsListFooter(
                onPressed: () => calls++,
                child: const Text('더 보기'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shadow = find.byType(TdsListFooterShadow);
        final paint = tester.widget<CustomPaint>(
          find.descendant(of: shadow, matching: find.byType(CustomPaint)),
        );
        final painter = paint.painter! as TdsListFooterShadowPainter;
        expect(
          painter.color,
          dark ? TdsPalette.whiteOpacity50 : TdsPalette.grey100,
        );
        expect(
          painter.bounds(const Size(300, 58)),
          const Rect.fromLTWH(-30, -150, 360, 300),
        );
        final opacity = find.descendant(
          of: shadow,
          matching: find.byType(AnimatedOpacity),
        );
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('더 보기')),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(TdsMotion.rapid.duration);
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scale.scale, .96);
        // The shared motion clock now supplies the already-interpolated scale.
        expect(scale.duration, Duration.zero);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
      }
      expect(calls, 2);
    },
  );
}
