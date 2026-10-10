import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;
import 'list_footer_color_test.dart' show textInk, iconInk;

Widget nestedFooter({
  required bool dark,
  String outer = 'blue500',
  String inner = 'red500',
  bool showInner = true,
  List<String>? events,
}) => testApp(
  TdsMobileProvider(
    theme: TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    ),
    child: SizedBox(
      width: 342,
      child: TdsListFooter(
        key: const ValueKey('outer-footer'),
        onPressed: () => events?.add('outer'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TdsListFooterText(colorToken: outer, child: const Text('바깥')),
                const TdsListFooterIcon(
                  key: ValueKey('outer-icon'),
                  name: 'icon-arrow-right-mono',
                  colorToken: 'green500',
                ),
              ],
            ),
            if (showInner)
              TdsListFooter(
                key: const ValueKey('inner-footer'),
                onPressed: () => events?.add('inner'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TdsListFooterText(
                      colorToken: inner,
                      child: const Text('안쪽'),
                    ),
                    const TdsListFooterIcon(
                      key: ValueKey('inner-icon'),
                      name: 'icon-arrow-right-mono',
                      colorToken: 'orange500',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);

double nestedScale(WidgetTester tester, String id) => tester
    .widget<AnimatedScale>(
      find
          .descendant(
            of: find.byKey(ValueKey('$id-footer')),
            matching: find.byType(AnimatedScale),
          )
          .first,
    )
    .scale;

double nestedShadow(WidgetTester tester, String id) => tester
    .widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byKey(ValueKey('$id-footer')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

void main() {
  for (final dark in [false, true]) {
    final theme = TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    );
    testWidgets('outer selector crosses nested Footer providers dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(nestedFooter(dark: dark));
      await tester.pumpAndSettle();
      expect(textInk(tester, '바깥'), theme.color('blue500'));
      expect(textInk(tester, '안쪽'), theme.color('red500'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('바깥')),
      );
      await tester.pumpAndSettle();
      for (final id in ['outer', 'inner']) {
        expect(nestedScale(tester, id), .96);
        expect(nestedShadow(tester, id), 1);
        expect(iconInk(tester, '$id-icon'), theme.color('green600'));
      }
      expect(textInk(tester, '안쪽'), theme.color('blue600'));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(textInk(tester, '안쪽'), theme.color('blue500'));
      expect(iconInk(tester, 'inner-icon'), theme.color('green500'));
      expect(nestedScale(tester, 'inner'), 1);
      expect(nestedShadow(tester, 'inner'), 0);
    });

    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets(
        'nested Footer raw input and clicks bubble dark=$dark kind=$kind',
        (tester) async {
          final events = <String>[];
          await tester.pumpWidget(nestedFooter(dark: dark, events: events));
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(
            tester.getCenter(find.text('안쪽')),
            kind: kind,
          );
          await tester.pumpAndSettle();
          expect(textInk(tester, '바깥'), theme.color('blue600'));
          expect(textInk(tester, '안쪽'), theme.color('blue600'));
          expect(iconInk(tester, 'inner-icon'), theme.color('green600'));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(textInk(tester, '안쪽'), theme.color('blue500'));
          expect(events, ['inner', 'outer']);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'unused inner contexts leave ancestor inline styles intact dark=$dark',
      (tester) async {
        await tester.pumpWidget(nestedFooter(dark: dark));
        await tester.pumpAndSettle();
        final first = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        await first.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(nestedFooter(dark: dark, inner: 'purple500'));
        await tester.pumpAndSettle();
        expect(textInk(tester, '안쪽'), theme.color('blue500'));
        final second = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          nestedFooter(dark: dark, inner: 'purple500', outer: 'teal500'),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '안쪽'), theme.color('blue600'));
        expect(iconInk(tester, 'inner-icon'), theme.color('orange500'));
        expect(nestedScale(tester, 'inner'), .96);
        await second.up();
        await tester.pumpAndSettle();
        expect(textInk(tester, '안쪽'), theme.color('teal500'));
        expect(nestedScale(tester, 'inner'), 1);
      },
    );

    testWidgets(
      'reinserted nested Footer joins only new selector snapshots dark=$dark',
      (tester) async {
        await tester.pumpWidget(nestedFooter(dark: dark));
        await tester.pumpAndSettle();
        await tester.pumpWidget(nestedFooter(dark: dark, showInner: false));
        await tester.pumpAndSettle();
        await tester.pumpWidget(nestedFooter(dark: dark));
        await tester.pumpAndSettle();
        final first = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '바깥'), theme.color('blue600'));
        expect(textInk(tester, '안쪽'), theme.color('red500'));
        expect(nestedScale(tester, 'inner'), 1);
        expect(nestedShadow(tester, 'inner'), 0);
        await first.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(nestedFooter(dark: dark, outer: 'teal500'));
        await tester.pumpAndSettle();
        final second = await tester.startGesture(
          tester.getCenter(find.text('바깥')),
        );
        await tester.pumpAndSettle();
        expect(textInk(tester, '안쪽'), theme.color('teal600'));
        expect(nestedScale(tester, 'inner'), .96);
        expect(nestedShadow(tester, 'inner'), 1);
        await second.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('overlapping releases save each rendered target dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(nestedFooter(dark: dark));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('안쪽')),
      );
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pump();
      // Inner listeners render before outer listeners. The parent's release
      // saves that first rendered inner frame, not the original pressed state.
      await tester.pump(const Duration(milliseconds: 5));
      final progress = TdsMotion.rapid.transform(
        5000 / TdsMotion.rapid.duration.inMicroseconds,
      );
      final savedScale = .96 + .04 * progress;
      final savedColor = Color.lerp(
        theme.color('blue600'),
        theme.color('red500'),
        progress,
      )!;
      await tester.pumpAndSettle();
      await tester.pumpWidget(nestedFooter(dark: dark, inner: 'purple500'));
      await tester.pumpAndSettle();
      expect(nestedScale(tester, 'outer'), 1);
      expect(nestedScale(tester, 'inner'), .96);
      expect(textInk(tester, '안쪽'), theme.color('blue600'));
      await tester.pumpWidget(
        nestedFooter(dark: dark, inner: 'purple500', outer: 'teal500'),
      );
      await tester.pumpAndSettle();
      expect(nestedScale(tester, 'outer'), .96);
      expect(nestedScale(tester, 'inner'), closeTo(savedScale, 1e-8));
      expect(nestedShadow(tester, 'inner'), closeTo(1 - progress, 1e-8));
      expect(textInk(tester, '안쪽')!.toARGB32(), savedColor.toARGB32());
    });

    testWidgets('nested Footer targets detach during a held press dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(nestedFooter(dark: dark));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('안쪽')),
      );
      await tester.pump(const Duration(milliseconds: 65));
      await tester.pumpWidget(nestedFooter(dark: dark, showInner: false));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(textInk(tester, '바깥'), theme.color('blue500'));
    });
  }
}
