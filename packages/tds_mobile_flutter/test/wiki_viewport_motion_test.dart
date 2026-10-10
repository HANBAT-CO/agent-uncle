import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_inline.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_motion.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_viewport.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_description.dart';
import 'collections_feedback_test.dart' show testApp;

class _Haptic implements TdsHaptic {
  final calls = <TdsHapticType>[];
  @override
  Future<void> generate(TdsHapticType type) async => calls.add(type);
}

Widget _host(Widget child) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (_, navigator) => TdsMobileProvider(child: navigator!),
  home: child,
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, a, s) => builder(context),
  ),
);

void main() {
  test(
    'string descriptions collapse CSS whitespace but preserve nonbreaking spaces',
    () {
      expect(
        TdsWikiDescription.normalize(' \nfirst\tline\n  second\r\nline '),
        'first line second line',
      );
      expect(
        TdsWikiDescription.normalize('\u00a0a\u00a0\u00a0b\u00a0'),
        '\u00a0a\u00a0\u00a0b\u00a0',
      );
    },
  );
  testWidgets(
    'interrupted popup entry still runs a full exit and disposes safely',
    (tester) async {
      await tester.pumpWidget(
        testApp(const TdsWikiText('word', description: 'definition')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TdsWikiText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(700, 550));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(TdsWikiDescription), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(TdsWikiDescription), findsNothing);
      await tester.tap(find.byType(TdsWikiText));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled padding animation leaves zero inset through reentry', (
    tester,
  ) async {
    late StateSetter update;
    var inView = true;
    TdsWikiInlineFrame? frame;
    await tester.pumpWidget(
      testApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return TdsWikiInlineMotion(
              inView: inView,
              padding: 0,
              iconWidth: 12,
              builder: (_, value) {
                frame = value;
                return const SizedBox(width: 100, height: 24);
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(frame!.padding, 0);
    expect(frame!.iconWidth, 13);
    update(() => inView = false);
    await tester.pumpAndSettle();
    update(() => inView = true);
    await tester.pumpAndSettle();
    expect(frame!.padding, 0);
    expect(frame!.iconWidth, 13);
  });
  test(
    'kf channels preserve delays, retained padding and explicit from values',
    () {
      const hidden = TdsWikiInlineFrame();
      TdsWikiInlineFrame enter(int ms) => hidden.animate(
        entering: true,
        elapsed: Duration(milliseconds: ms),
        targetPadding: 3.519,
        targetIconWidth: 11.9,
      );
      expect(enter(100).iconX, -5);
      expect(enter(200).iconOpacity, 0);
      expect(enter(400).iconOpacity, inExclusiveRange(.5, .75));
      expect(enter(1200).iconWidth, closeTo(16.419, .001));
      final visible = enter(1200);
      final exited = visible.animate(
        entering: false,
        elapsed: const Duration(seconds: 2),
        targetPadding: 3.519,
        targetIconWidth: 11.9,
      );
      expect(exited.padding, visible.padding);
      expect(exited.iconWidth, 0);
      expect(exited.highlightOpacity, 0);
      final again = exited.animate(
        entering: true,
        elapsed: Duration.zero,
        targetPadding: 3.519,
        targetIconWidth: 11.9,
      );
      expect(again.padding, 0);
      expect(again.iconWidth, 0);
      final interrupted = enter(80).animate(
        entering: false,
        elapsed: Duration.zero,
        targetPadding: 3.519,
        targetIconWidth: 11.9,
      );
      expect(
        interrupted.highlightScale,
        1,
      ); // Original exit has explicit from:1.
      expect(interrupted.iconWidth, enter(80).iconWidth.roundToDouble());
    },
  );

  test(
    'popup uses independent medium, basic, large and quick spring clocks',
    () {
      const from = TdsWikiPopupFrame();
      const time = Duration(milliseconds: 100);
      final enter = from.animate(true, time);
      expect(enter.word, wikiSpring(TdsMotion.medium, time));
      expect(enter.box, wikiSpring(TdsMotion.basic, time));
      expect(
        enter.scale,
        closeTo(.9 + .1 * wikiSpring(TdsMotion.large, time), 1e-12),
      );
      expect(enter.dimmer, closeTo(enter.box * .8, 1e-12));
      final exit = enter.animate(false, time);
      expect(
        exit.word,
        closeTo(enter.word * (1 - wikiSpring(TdsMotion.quick, time)), 1e-12),
      );
      expect(
        exit.box,
        closeTo(enter.box * (1 - wikiSpring(TdsMotion.basic, time)), 1e-12),
      );
    },
  );

  testWidgets(
    'viewport gates touch, click, keyboard and replays entry after scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scroll = ScrollController();
      final haptic = _Haptic();
      var clicks = 0;
      await tester.pumpWidget(
        _host(
          TdsHostProvider(
            haptic: haptic,
            child: SizedBox(
              height: 650,
              child: SingleChildScrollView(
                controller: scroll,
                child: SizedBox(
                  height: 2000,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 520,
                        left: 24,
                        width: 230,
                        child: TdsWikiText(
                          'word',
                          description: const Text('definition'),
                          onClick: () => clicks++,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      TdsWikiInline inline() => tester.widget(find.byType(TdsWikiInline));
      final focus = tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byType(TdsWikiText),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!;
      expect(inline().iconSlotWidth, 0);
      await tester.tap(find.byType(TdsWikiText));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(clicks, 0);
      expect(haptic.calls, isEmpty);
      scroll.jumpTo(200);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(inline().iconOpacity, 0);
      expect(inline().highlightOpacity, greaterThan(0));
      await tester.pumpAndSettle();
      final padding = inline().padding;
      expect(inline().iconOpacity, 1);
      await tester.tap(find.byType(TdsWikiText));
      await tester.pumpAndSettle();
      expect(clicks, 1);
      expect(haptic.calls, [TdsHapticType.tickWeak]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(inline().iconSlotWidth, 0);
      expect(inline().padding, padding);
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      expect(inline().iconOpacity, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      scroll.dispose();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, false);
    },
  );

  testWidgets('end-of-document latch stays active after moving out of view', (
    tester,
  ) async {
    var top = 1850.0;
    late StateSetter update;
    bool? visible;
    await tester.pumpWidget(
      testApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return SizedBox(
              height: 2000,
              child: Stack(
                children: [
                  Positioned(
                    top: top,
                    child: TdsWikiViewport(
                      builder: (_, value) {
                        visible = value;
                        return const SizedBox(width: 40, height: 20);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(visible, true);
    update(() => top = 450);
    await tester.pumpAndSettle();
    expect(visible, true);
  });

  testWidgets(
    'first observation above viewport uses source first-callback guard',
    (tester) async {
      bool? visible;
      await tester.pumpWidget(
        testApp(
          Transform.translate(
            offset: const Offset(0, -100),
            child: TdsWikiViewport(
              builder: (_, value) {
                visible = value;
                return const SizedBox(width: 40, height: 20);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(visible, true);
    },
  );

  testWidgets(
    'ancestor clipping participates in the intersection observation',
    (tester) async {
      final scroll = ScrollController();
      bool? visible;
      await tester.pumpWidget(
        testApp(
          Padding(
            padding: const EdgeInsets.only(top: 280),
            child: SizedBox(
              height: 40,
              child: SingleChildScrollView(
                controller: scroll,
                child: SizedBox(
                  height: 1000,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 70),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: TdsWikiViewport(
                        builder: (_, value) {
                          visible = value;
                          return const SizedBox(width: 40, height: 20);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(visible, false); // y350 lies inside root but outside inner clip.
      scroll.jumpTo(50);
      await tester.pumpAndSettle();
      expect(visible, true);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );

  testWidgets(
    'Enter and Space activate on keydown, no duplicate keyup callback',
    (tester) async {
      var clicks = 0;
      await tester.pumpWidget(
        testApp(
          TdsWikiText(
            'word',
            description: const Text('definition'),
            onClick: () => clicks++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final focus = tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byType(TdsWikiText),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!;
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        focus.requestFocus();
        await tester.pump();
        final before = clicks;
        await tester.sendKeyDownEvent(key);
        await tester.pumpAndSettle();
        expect(clicks, before + 1);
        expect(find.text('definition'), findsOneWidget);
        await tester.sendKeyUpEvent(key);
        expect(clicks, before + 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(focus.hasFocus, true);
      }
    },
  );

  testWidgets(
    'string descriptions stagger rendered lines and unlock scroll on end',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsWikiText('word', description: 'first line\nsecond line'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TdsWikiText));
      await tester.pump();
      await tester.pump();
      final descriptionScroll = find
          .ancestor(
            of: find.byType(TdsWikiDescription),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      expect(
        tester.widget<SingleChildScrollView>(descriptionScroll).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final word = tester
          .widget<Opacity>(find.byKey(const ValueKey('tds-wiki-word-opacity')))
          .opacity;
      final box = tester
          .widget<Opacity>(find.byKey(const ValueKey('tds-wiki-box-opacity')))
          .opacity;
      expect(word, greaterThan(box));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SingleChildScrollView>(descriptionScroll).physics,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TdsWikiDescription), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
