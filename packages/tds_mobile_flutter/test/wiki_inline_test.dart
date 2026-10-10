import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_inline.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'definition scroll fades use 5px thresholds, 40/80px sizes and ignore input',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsWikiText(
            'word',
            description: SizedBox(height: 1200, child: Text('description')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TdsWikiText));
      await tester.pumpAndSettle();
      final top = find.byKey(const ValueKey('tds-wiki-fade-top'));
      final bottom = find.byKey(const ValueKey('tds-wiki-fade-bottom'));
      expect(top, findsNothing);
      expect(tester.getSize(bottom).height, 80);
      final scroll = tester
          .widget<SingleChildScrollView>(
            find
                .ancestor(
                  of: find.text('description'),
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          )
          .controller!;
      scroll.jumpTo(4);
      await tester.pump();
      expect(top, findsNothing);
      scroll.jumpTo(5);
      await tester.pump();
      expect(tester.getSize(top).height, 40);
      expect(bottom, findsOneWidget);
      scroll.jumpTo(scroll.position.maxScrollExtent - 5);
      await tester.pump();
      expect(top, findsOneWidget);
      expect(bottom, findsNothing);
      expect(
        find.ancestor(of: top, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Vpe highlight widths, shrink and edge flags match original line formulas',
    () {
      final lines = TdsWikiHighlightGeometry.fromRects([
        const Rect.fromLTWH(28, 26, 211.84375, 21),
        const Rect.fromLTWH(24, 51.5, 139.265625, 21),
      ], 11.9);
      expect(
        lines[0].rect,
        rectMoreOrLessEquals(
          const Rect.fromLTWH(28.525, 36.08, 210.79375, 9.66),
        ),
      );
      expect(lines[0].leftEdge, true);
      expect(lines[0].rightEdge, false);
      expect(
        lines[1].rect,
        rectMoreOrLessEquals(
          const Rect.fromLTWH(24.525, 61.58, 148.167625, 9.66),
        ),
      );
      expect(lines[1].leftEdge, false);
      expect(lines[1].rightEdge, true);
      final single = TdsWikiHighlightGeometry.fromRects([
        const Rect.fromLTWH(0, 0, 100, 20),
      ], 14).single;
      expect(single.leftEdge && single.rightEdge, true);
      expect(
        single.rect,
        rectMoreOrLessEquals(const Rect.fromLTWH(1, 9.6, 110.24, 9.2)),
      );
    },
  );
  testWidgets(
    'multiline text has a highlight for each line and an inline final icon',
    (tester) async {
      const text = 'long financial words wrap across several lines';
      await tester.pumpWidget(
        testApp(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 17, height: 1.5),
                child: TdsWikiText(text, description: Text('description')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final render = tester.allRenderObjects
          .whereType<RenderTdsWikiHighlight>()
          .toSet()
          .single;
      expect(render.wordRects.length, greaterThan(1));
      expect(render.highlights.length, render.wordRects.length);
      expect(render.highlights.where((g) => g.leftEdge).length, 1);
      expect(render.highlights.where((g) => g.rightEdge).length, 1);
      final paragraph = render.child! as RenderParagraph;
      final span = paragraph.text as TextSpan;
      expect(span.children!.first, isA<WidgetSpan>());
      expect(span.children!.last, isA<WidgetSpan>());
      final first = render.wordRects.first;
      final second = render.wordRects[1];
      expect(first.left, 4); // rounded CSS spring padding at 25.5px line height
      expect(
        second.left,
        0,
      ); // inline leading padding does not indent every line
      await tester.tap(find.byType(TdsWikiText));
      await tester.pumpAndSettle();
      expect(find.text('description'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('font, theme, width and text updates recompute line highlights', (
    tester,
  ) async {
    Widget view(bool dark, double width, double font, String text) => testApp(
      TdsMobileProvider(
        theme: TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: DefaultTextStyle(
              style: TextStyle(fontSize: font, height: 1.5),
              child: TdsWikiText(
                text,
                hasPaddingAnimation: false,
                description: const Text('description'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view(false, 400, 14, 'word'));
    await tester.pumpAndSettle();
    final first = tester.allRenderObjects
        .whereType<RenderTdsWikiHighlight>()
        .toSet()
        .single;
    expect(first.wordRects.length, 1);
    expect(first.wordRects.single.left, 0);
    final initialHeight = first.wordRects.single.height;
    await tester.pumpWidget(
      view(true, 150, 26, 'much longer words over several lines'),
    );
    await tester.pumpAndSettle();
    final next = tester.allRenderObjects
        .whereType<RenderTdsWikiHighlight>()
        .toSet()
        .single;
    expect(next, same(first));
    expect(next.wordRects.length, greaterThan(1));
    expect(next.wordRects.first.height, greaterThan(initialHeight));
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
