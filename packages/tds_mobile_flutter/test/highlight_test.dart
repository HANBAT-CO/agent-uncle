import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Widget host(
  Widget child, {
  bool reduced = false,
  bool dark = false,
  TdsOS os = TdsOS.android,
  double scale = 100,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  builder: (context, navigator) => TdsMobileProvider(
    theme: TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
      platform: TdsPlatform(os: os, fontScale: scale),
    ),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: navigator!,
    ),
  ),
  home: child,
);

dynamic painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_HighlightPainter',
      ),
    )
    .painter;
Finder get arrow => find.byWidgetPredicate(
  (w) => w is TdsAssetIcon && w.name == 'icon-arrow-up-sidebar-mono',
);

Future<void> ready(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/tds_mobile_flutter/Toss Product Sans');
    for (final weight in [400, 700]) {
      loader.addFont(
        rootBundle.load(
          'packages/tds_mobile_flutter/assets/fonts/TossProductSans-$weight.ttf',
        ),
      );
    }
    await loader.load();
  });

  testWidgets(
    'cutout padding, zero-padding negatives, viewport clamp and rounded hit geometry',
    (tester) async {
      for (final sample in [
        (
          const Rect.fromLTWH(40, 160, 160, 48),
          8.0,
          const Rect.fromLTWH(32, 152, 176, 64),
        ),
        (
          const Rect.fromLTWH(-4, -3, 50, 20),
          0.0,
          const Rect.fromLTWH(-4, -3, 50, 20),
        ),
        (
          const Rect.fromLTWH(4, 3, 50, 20),
          8.0,
          const Rect.fromLTWH(0, 0, 66, 36),
        ),
        (
          const Rect.fromLTWH(100, 40, 790, 50),
          0.0,
          const Rect.fromLTWH(10, 40, 780, 50),
        ),
      ]) {
        await tester.pumpWidget(
          host(TdsHighlightUI(rect: sample.$1, padding: sample.$2)),
        );
        await tester.pumpAndSettle();
        final RRect hole = painter(tester).hole;
        expect(hole.outerRect, sample.$3);
        expect(hole.tlRadiusX, 16);
        expect(painter(tester).hitTest(hole.center), isFalse);
        expect(
          painter(tester).hitTest(hole.outerRect.topLeft + const Offset(1, 1)),
          isTrue,
        );
      }
    },
  );

  testWidgets(
    'message keyframes, fixed SVG arrow, basic mask scale and independent opacity',
    (tester) async {
      await tester.pumpWidget(
        host(
          const TdsHighlightUI(
            rect: Rect.fromLTWH(40, 160, 160, 48),
            padding: 8,
            message: Text('안내'),
            messageXAlignment: TdsHighlightXAlignment.left,
          ),
        ),
      );
      expect(painter(tester).opacity, 0);
      expect((painter(tester).hole as RRect).width, closeTo(176 * .9, .001));
      expect(tester.getSize(arrow), const Size(24, 24));
      expect(tester.getTopLeft(arrow), const Offset(108, 228));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getTopLeft(arrow).dy, closeTo(218, .001));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.getTopLeft(arrow).dy, closeTo(238, .001));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.getTopLeft(arrow).dy, closeTo(218, .001));
      expect(
        (painter(tester).hole as RRect).outerRect,
        const Rect.fromLTWH(32, 152, 176, 64),
      );
      expect(painter(tester).opacity, 1);
    },
  );

  testWidgets(
    'all message alignments and sides preserve anchor arrow center and newline metrics',
    (tester) async {
      for (final scale in [100.0, 160.0]) {
        for (final x in TdsHighlightXAlignment.values) {
          for (final y in TdsHighlightYAlignment.values) {
            await tester.pumpWidget(
              host(
                TdsHighlightUI(
                  rect: const Rect.fromLTWH(40, 200, 160, 48),
                  padding: 8,
                  messageXAlignment: x,
                  messageYAlignment: y,
                  message: const Text('새로운 기능\n확인하기'),
                ),
                scale: scale,
                reduced: true,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.getCenter(arrow).dx, 120);
            expect(tester.getSize(arrow), const Size(24, 24));
            final message = find.byType(TdsHighlightMessage);
            expect(tester.getSize(message).height, scale == 100 ? 45 : 66);
            final render = tester.renderObject<RenderParagraph>(
              find.descendant(of: message, matching: find.byType(RichText)),
            );
            expect(
              render.textAlign,
              [TextAlign.left, TextAlign.center, TextAlign.right][x.index],
            );
            expect(render.text.toPlainText(), '새로운 기능\n확인하기');
            if (x == TdsHighlightXAlignment.center) {
              expect(tester.getCenter(message).dx, 120);
            }
            if (y == TdsHighlightYAlignment.top) {
              expect(tester.getCenter(arrow).dy + 12, 180);
            } else {
              expect(tester.getTopLeft(arrow).dy, 268);
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'theme, Android mask filter and reduced motion retain their separate contracts',
    (tester) async {
      await tester.pumpWidget(
        host(
          const TdsHighlightUI(
            rect: Rect.fromLTWH(40, 100, 100, 50),
            message: Text('안내'),
          ),
          reduced: true,
          dark: true,
        ),
      );
      expect((painter(tester).hole as RRect).width, 100);
      expect(painter(tester).android, isTrue);
      expect(painter(tester).color, const Color.fromRGBO(33, 33, 38, .87));
      final before = tester.getTopLeft(arrow);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getTopLeft(arrow), before);
      await tester.pumpWidget(
        host(
          const TdsHighlightUI(rect: Rect.fromLTWH(40, 100, 100, 50)),
          os: TdsOS.ios,
        ),
      );
      expect(painter(tester).android, isFalse);
    },
  );

  testWidgets(
    'exit expands with slow motion, not reverse entrance; interruption retains current values',
    (tester) async {
      var exited = 0, removed = 0;
      Widget build(bool open) => host(
        TdsHighlightUI(
          open: open,
          rect: const Rect.fromLTWH(40, 100, 160, 48),
          message: const Text('안내'),
          onExited: () => exited++,
          onExitComplete: () => removed++,
        ),
      );
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 100));
      final RRect before = painter(tester).hole;
      final double alpha = painter(tester).opacity;
      await tester.pumpWidget(build(false));
      expect(painter(tester).hole, before);
      expect(painter(tester).opacity, alpha);
      await tester.pump(const Duration(milliseconds: 200));
      final RRect during = painter(tester).hole;
      expect(during.width, greaterThan(before.width));
      expect(during.tlRadiusX, greaterThan(before.tlRadiusX));
      await tester.pumpWidget(build(true));
      expect(painter(tester).hole, during);
      await tester.pumpAndSettle();
      expect(exited, 0);
      expect(removed, 0);
      await tester.pumpWidget(build(false));
      await tester.pump();
      // Flutter's interpolation simulation completes on t > duration, not ==.
      await tester.pump(
        TdsMotion.basic.duration + const Duration(milliseconds: 1),
      );
      expect(exited, 1);
      expect(removed, 0);
      await tester.pump(TdsMotion.slow.duration);
      expect(removed, 1);
      expect((painter(tester).hole as RRect).width, 1600);
      expect((painter(tester).hole as RRect).height, 1600);
    },
  );

  testWidgets(
    'full Highlight target is inert; Escape ignored; closed-loop focus activates hidden close',
    (tester) async {
      var target = 0;
      final events = <String>[];
      await tester.pumpWidget(
        host(
          Center(
            child: TdsHighlight(
              open: true,
              onClick: () => events.add('click'),
              onClose: () => events.add('close'),
              onExited: () => events.add('exited'),
              message: const Text('안내'),
              child: GestureDetector(
                onTap: () => target++,
                child: const SizedBox(
                  width: 100,
                  height: 40,
                  child: Text('대상'),
                ),
              ),
            ),
          ),
        ),
      );
      await ready(tester);
      await tester.tapAt(tester.getCenter(find.text('대상')));
      expect(target, 0);
      expect(events, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(events, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(events, ['click', 'close']);
      await tester.pumpAndSettle();
      expect(events, ['click', 'close', 'exited']);
      expect(find.byType(TdsHighlightUI), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(TdsHighlightUI), findsNothing);
    },
  );

  testWidgets(
    'delay cancellation, snapshot props, captured callbacks and false-to-true reopening',
    (tester) async {
      final events = <String>[];
      Widget build(bool open, String text) => host(
        Center(
          child: TdsHighlight(
            open: open,
            delay: const Duration(milliseconds: 100),
            message: Text(text),
            onClick: () => events.add(text),
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );
      await tester.pumpWidget(build(true, 'initial'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(false, 'cancelled'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TdsHighlightUI), findsNothing);
      await tester.pumpWidget(build(true, 'snapshot'));
      await tester.pump(const Duration(milliseconds: 100));
      await ready(tester);
      await tester.pumpWidget(build(true, 'updated'));
      expect(find.text('snapshot'), findsOneWidget);
      expect(find.text('updated'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      expect(events, ['initial']);
      await tester.pumpAndSettle();
      expect(find.byType(TdsHighlightUI), findsNothing);
      await tester.pumpWidget(build(true, 'still true'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TdsHighlightUI), findsNothing);
      await tester.pumpWidget(build(false, 'off'));
      await tester.pumpWidget(build(true, 'reopened'));
      await tester.pump(const Duration(milliseconds: 100));
      await ready(tester);
      expect(find.text('reopened'), findsOneWidget);
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standalone UI hole passes through while rounded corner dismisses',
    (tester) async {
      var target = 0, dismiss = 0;
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              Positioned(
                left: 40,
                top: 100,
                width: 160,
                height: 48,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => target++,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: TdsHighlightUI(
                  rect: const Rect.fromLTWH(40, 100, 160, 48),
                  onClick: () => dismiss++,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(100, 120));
      expect(target, 1);
      expect(dismiss, 0);
      await tester.tapAt(const Offset(41, 101));
      expect(target, 1);
      expect(dismiss, 1);
    },
  );
}
