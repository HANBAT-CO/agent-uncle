import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';
import 'highlight_test.dart' show host;

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/tds_mobile_flutter/Toss Product Sans');
    loader.addFont(
      rootBundle.load(
        'packages/tds_mobile_flutter/assets/fonts/TossProductSans-700.ttf',
      ),
    );
    await loader.load();
  });

  testWidgets(
    'omitted inline placement omits target; explicit placement orders retained children',
    (tester) async {
      Widget build(TdsOverlayPlacement? placement) => host(
        Align(
          alignment: Alignment.topLeft,
          child: TdsFullTooltip(
            open: true,
            placement: placement,
            message: const Text('메시지'),
            child: const SizedBox(height: 48, child: Text('대상')),
          ),
        ),
      );
      await tester.pumpWidget(build(null));
      await tester.pumpAndSettle();
      expect(find.text('대상'), findsNothing);
      expect(find.text('메시지'), findsOneWidget);
      await tester.pumpWidget(build(TdsOverlayPlacement.bottom));
      expect(tester.getTopLeft(find.text('대상')).dy, 0);
      expect(tester.getTopLeft(find.byType(TdsFullTooltipSurface)).dy, 48);
      await tester.pumpWidget(build(TdsOverlayPlacement.top));
      expect(tester.getTopLeft(find.byType(TdsFullTooltipSurface)).dy, 0);
      expect(tester.getTopLeft(find.text('대상')).dy, 64);
    },
  );

  testWidgets(
    '400/500/700ms inline entrances retain separate reveal and ink timelines',
    (tester) async {
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.topLeft,
            child: TdsFullTooltip(
              open: true,
              placement: TdsOverlayPlacement.bottom,
              message: const Text('메시지'),
              child: const SizedBox(height: 48),
            ),
          ),
        ),
      );
      final full = find.byType(TdsFullTooltip);
      expect(tester.getSize(full).height, 48);
      expect(
        tester
            .widget<TdsFullTooltipSurface>(find.byType(TdsFullTooltipSurface))
            .alpha,
        0,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(full).height, 48);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getSize(full).height,
        closeTo(
          48 +
              (64 *
                      TdsMotion.basic.transform(
                        200000 / TdsMotion.basic.duration.inMicroseconds,
                      ))
                  .round(),
          .001,
        ),
      );
      expect(
        tester
            .widget<TdsFullTooltipSurface>(find.byType(TdsFullTooltipSurface))
            .alpha,
        0,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<TdsFullTooltipSurface>(find.byType(TdsFullTooltipSurface))
            .alpha,
        closeTo(TdsMotion.out.transform(.5), .001),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(full).height, 112);
    },
  );

  testWidgets(
    'original rounded clientHeight, 1.35 line box and static teal colors at both scales/themes',
    (tester) async {
      for (final dark in [false, true]) {
        for (final scale in [100.0, 160.0]) {
          await tester.pumpWidget(
            host(
              Align(
                alignment: Alignment.topLeft,
                child: const SizedBox(
                  width: 390,
                  child: TdsFullTooltipSurface(
                    placement: TdsOverlayPlacement.bottom,
                    message: Text('새로운 기능을 확인하고\n안내를 계속 읽어 보세요'),
                  ),
                ),
              ),
              dark: dark,
              scale: scale,
            ),
          );
          final lineHeight = scale == 100 ? 20.25 : 32.390625;
          final expectedHeight = (lineHeight * 2).round() + 44;
          expect(
            tester.getSize(find.byType(TdsFullTooltipSurface)),
            Size(390, expectedHeight.toDouble()),
          );
          final box = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_FullTooltipMessageBox',
          );
          final render = tester.renderObject<RenderBox>(box);
          final child = (render as RenderShiftedBox).child!;
          expect(
            (child.parentData as BoxParentData).offset,
            Offset(24, (expectedHeight - lineHeight * 2) / 2 + 6),
          );
          final text = tester.widget<TdsKeepAllText>(
            find.byType(TdsKeepAllText),
          );
          expect(text.source.style!.color, TdsPalette.teal600);
          final fill = tester.widget<ColoredBox>(
            find.descendant(
              of: find.byType(TdsFullTooltipSurface),
              matching: find.byType(ColoredBox),
            ),
          );
          expect(fill.color, TdsPalette.teal400.withValues(alpha: .15));
          expect(find.byType(BackdropFilter), findsNothing);
        }
      }
    },
  );

  test(
    'original two-contour path preserves curved anchor, body seam, ratio overflow and vertical reflection',
    () {
      for (final ratio in [-.2, 0.0, .5, 1.0, 1.2]) {
        final anchor = 8 + ratio * (390 - 54);
        final down = TdsFullTooltipClipper(
          anchor: anchor,
          viewportWidth: 390,
          top: false,
        ).getClip(const Size(390, 64));
        final up = TdsFullTooltipClipper(
          anchor: anchor,
          viewportWidth: 390,
          top: true,
        ).getClip(const Size(390, 64));
        expect(down.computeMetrics().length, 2);
        expect(down.contains(Offset(anchor + 19.1, 1)), isTrue);
        expect(down.contains(Offset(anchor + 19.1, .4)), isFalse);
        expect(down.contains(const Offset(5, 12)), isTrue);
        expect(down.contains(const Offset(5, 11)), isFalse);
        for (var x = 0.0; x < 390; x += 7) {
          for (var y = 0.0; y < 64; y += 3) {
            expect(down.contains(Offset(x, y)), up.contains(Offset(x, 64 - y)));
          }
        }
      }
    },
  );

  testWidgets(
    'overlap reserves twelve fewer pixels; floating explicit offset overrides overlap',
    (tester) async {
      for (final placement in [
        TdsOverlayPlacement.top,
        TdsOverlayPlacement.bottom,
      ]) {
        await tester.pumpWidget(
          host(
            Align(
              alignment: Alignment.topLeft,
              child: TdsFullTooltip(
                key: ValueKey(placement),
                open: true,
                placement: placement,
                anchorOverlapped: true,
                offset: 100,
                message: const Text('메시지'),
                child: const SizedBox(height: 48),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(TdsFullTooltip)).height, 100);
        expect(
          tester.getTopLeft(find.byType(TdsFullTooltipSurface)).dy,
          placement == TdsOverlayPlacement.top ? 0 : 36,
        );
      }
      for (final offset in [null, 0.0, 9.0]) {
        await tester.pumpWidget(
          host(
            Center(
              child: TdsFullTooltip(
                key: ValueKey(offset),
                open: true,
                floating: true,
                anchorOverlapped: true,
                offset: offset,
                message: const Text('메시지'),
                child: const SizedBox(width: 100, height: 48),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final overlay = tester.widget<TdsAnchoredOverlay>(
          find.byType(TdsAnchoredOverlay),
        );
        expect(overlay.offset, offset ?? -12);
        expect(overlay.shiftIntoView, isFalse);
        expect(overlay.placement, TdsOverlayPlacement.bottom);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(
          tester.getSize(find.byType(TdsFullTooltip)),
          const Size(100, 48),
        );
      }
    },
  );

  testWidgets(
    'controlled timer does not hide, resets on callback replacement, allows zero and cancels on unmount',
    (tester) async {
      final calls = <String>[];
      void first() => calls.add('first');
      void second() => calls.add('second');
      Widget build(bool open, Duration duration, VoidCallback? onClose) => host(
        TdsFullTooltip(
          open: open,
          duration: duration,
          onClose: onClose,
          message: const Text('메시지'),
          child: const SizedBox(),
        ),
      );
      await tester.pumpWidget(build(true, const Duration(seconds: 2), first));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(build(true, const Duration(seconds: 2), second));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, ['second']);
      expect(find.text('메시지'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(calls, ['second']);
      await tester.pumpWidget(build(true, Duration.zero, first));
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, ['second', 'first']);
      await tester.pumpWidget(
        build(true, const Duration(milliseconds: 100), second),
      );
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pump(const Duration(seconds: 3));
      expect(calls, ['second', 'first']);
    },
  );

  testWidgets(
    'uncontrolled overrides external onClose; negative duration is immediate and exit remains mounted',
    (tester) async {
      var called = 0;
      await tester.pumpWidget(
        host(
          TdsFullTooltip(
            duration: const Duration(milliseconds: -1),
            onClose: () => called++,
            placement: TdsOverlayPlacement.top,
            message: const Text('메시지'),
            child: const Text('대상'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('메시지'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(called, 0);
      expect(find.text('메시지'), findsNothing);
      expect(find.text('대상'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onClickOutside uses initial callback on every pointerdown, including closed and inside',
    (tester) async {
      final events = <String>[];
      Widget build(bool open, String tag) => host(
        TdsFullTooltip(
          open: open,
          placement: TdsOverlayPlacement.bottom,
          onClickOutside: () => events.add(tag),
          message: const Text('메시지'),
          child: const SizedBox(height: 48, child: Text('대상')),
        ),
      );
      await tester.pumpWidget(build(true, 'initial'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('메시지')),
      );
      expect(events, ['initial']);
      await gesture.up();
      expect(events, ['initial']);
      await tester.pumpWidget(build(false, 'changed'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(500, 300));
      expect(events, ['initial', 'initial']);
      await tester.pumpWidget(host(const SizedBox()));
      await tester.tapAt(const Offset(500, 300));
      expect(events.length, 2);
    },
  );

  Widget inline({
    bool? open = true,
    bool floating = false,
    bool overlap = false,
    Widget message = const Text('메시지'),
    TdsOverlayPlacement placement = TdsOverlayPlacement.bottom,
    VoidCallback? onClose,
    VoidCallback? onClickOutside,
    Duration duration = const Duration(seconds: 30),
    double width = 390,
  }) => host(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: TdsFullTooltip(
          open: open,
          floating: floating,
          anchorOverlapped: overlap,
          message: message,
          placement: placement,
          onClose: onClose,
          onClickOutside: onClickOutside,
          duration: duration,
          child: const SizedBox(height: 48, child: Text('대상')),
        ),
      ),
    ),
  );

  double flowHeight(WidgetTester tester) =>
      tester.getSize(find.byType(TdsFullTooltip)).height - 48;
  double clipHeight(WidgetTester tester) {
    final render = tester.renderObject<RenderShiftedBox>(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_FullTooltipReveal',
      ),
    );
    return render.describeApproximatePaintClip(render.child!)!.height;
  }

  testWidgets(
    'message resize has two debounced measurements and a held 400ms reveal delay',
    (tester) async {
      await tester.pumpWidget(inline());
      await tester.pumpAndSettle();
      expect(flowHeight(tester), 64);
      await tester.pumpWidget(inline(message: const Text('첫 번째\n두 번째\n세 번째')));
      expect(tester.getSize(find.byType(TdsFullTooltipSurface)).height, 64);
      expect(flowHeight(tester), 64);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(find.byType(TdsFullTooltipSurface)).height, 105);
      expect(flowHeight(tester), 64);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(flowHeight(tester), 64);
      expect(clipHeight(tester), 64);
      await tester.pump(const Duration(milliseconds: 50));
      final expected =
          (105 *
                  TdsMotion.basic.transform(
                    50000 / TdsMotion.basic.duration.inMicroseconds,
                  ))
              .roundToDouble();
      expect(flowHeight(tester), expected);
      expect(clipHeight(tester), expected);
      // Resizing restarts only heights. It never fades the text again.
      expect(
        tester
            .widget<TdsFullTooltipSurface>(find.byType(TdsFullTooltipSurface))
            .alpha,
        1,
      );
      await tester.pumpAndSettle();
      expect(flowHeight(tester), 105);
    },
  );

  testWidgets(
    'overlap changes restart the flow spacer but preserve the clip and ink',
    (tester) async {
      await tester.pumpWidget(inline());
      await tester.pumpAndSettle();
      await tester.pumpWidget(inline(overlap: true));
      expect(flowHeight(tester), 64);
      expect(clipHeight(tester), 64);
      expect(tester.getTopLeft(find.byType(TdsFullTooltipSurface)).dy, 36);
      await tester.pump(const Duration(milliseconds: 400));
      expect(flowHeight(tester), 64);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        flowHeight(tester),
        (52 *
                TdsMotion.basic.transform(
                  50000 / TdsMotion.basic.duration.inMicroseconds,
                ))
            .round(),
      );
      expect(clipHeight(tester), 64);
      await tester.pumpAndSettle();
      expect(flowHeight(tester), 52);
      expect(clipHeight(tester), 64);
      await tester.pumpWidget(inline());
      expect(flowHeight(tester), 52);
      await tester.pumpAndSettle();
      expect(flowHeight(tester), 64);
    },
  );

  testWidgets('resize notifications debounce bursts and cancel on unmount', (
    tester,
  ) async {
    await tester.pumpWidget(inline());
    await tester.pumpAndSettle();
    await tester.pumpWidget(inline(message: const Text('첫 줄\n둘째 줄')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(inline(message: const Text('첫 줄\n둘째 줄\n셋째 줄')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(find.byType(TdsFullTooltipSurface)).height, 64);
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getSize(find.byType(TdsFullTooltipSurface)).height, 105);
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing retains the last message, placement and overlap while child order updates',
    (tester) async {
      await tester.pumpWidget(inline());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        inline(
          open: false,
          message: const Text('새 내용'),
          placement: TdsOverlayPlacement.top,
          overlap: true,
        ),
      );
      expect(find.text('새 내용'), findsNothing);
      expect(find.text('메시지'), findsOneWidget);
      final surface = tester.widget<TdsFullTooltipSurface>(
        find.byType(TdsFullTooltipSurface),
      );
      expect(surface.placement, TdsOverlayPlacement.bottom);
      expect(tester.getTopLeft(find.byType(TdsFullTooltipSurface)).dy, 0);
      expect(flowHeight(tester), 64);
      await tester.pumpAndSettle();
      expect(find.byType(TdsFullTooltipSurface), findsNothing);
      expect(find.text('대상'), findsOneWidget);
    },
  );

  testWidgets(
    'reopen during exit remounts and cannot be removed by the previous exit',
    (tester) async {
      await tester.pumpWidget(inline());
      await tester.pumpAndSettle();
      final before = tester.state(find.byType(TdsFullTooltipSurface));
      await tester.pumpWidget(inline(open: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(flowHeight(tester), lessThan(64));
      await tester.pumpWidget(inline(message: const Text('다시 열기')));
      expect(
        tester.state(find.byType(TdsFullTooltipSurface)),
        isNot(same(before)),
      );
      expect(flowHeight(tester), 0);
      expect(
        tester
            .widget<TdsFullTooltipSurface>(find.byType(TdsFullTooltipSurface))
            .alpha,
        0,
      );
      await tester.pumpAndSettle();
      expect(flowHeight(tester), 64);
      expect(find.text('다시 열기'), findsOneWidget);
      await tester.pumpWidget(inline(open: false));
      await tester.pumpAndSettle();
      expect(find.byType(TdsFullTooltipSurface), findsNothing);
    },
  );

  testWidgets(
    'controlled mode replacement resets presence, callback capture and timer ownership',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        inline(open: null, onClickOutside: () => events.add('uncontrolled')),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        inline(open: false, onClickOutside: () => events.add('controlled')),
      );
      expect(find.byType(TdsFullTooltipSurface), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      expect(events, ['controlled']);
      await tester.pumpWidget(
        inline(
          open: null,
          duration: const Duration(milliseconds: 10),
          onClose: () => events.add('wrong-close'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(find.byType(TdsFullTooltipSurface), findsNothing);
      expect(events, ['controlled']);
    },
  );

  for (final floating in [false, true]) {
    testWidgets(
      'interrupted ${floating ? "floating" : "inline"} reopen skips only the next retained exit',
      (tester) async {
        await tester.pumpWidget(inline(floating: floating));
        await tester.pumpAndSettle();
        await tester.pumpWidget(inline(open: false, floating: floating));
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        await tester.pumpWidget(inline(floating: floating));
        await tester.pumpAndSettle();
        // An unrelated open-state update must not reconstruct eo's lost wrapper.
        await tester.pumpWidget(inline(floating: floating, overlap: true));
        await tester.pumpWidget(
          inline(open: false, floating: floating, overlap: true),
        );
        await tester.pump(); // Floating overlay removal is post-frame.
        expect(find.byType(TdsFullTooltipSurface), findsNothing);
        expect(flowHeight(tester), 0);
        expect(find.text('대상'), findsOneWidget);
        // A fresh mount has a presence wrapper again and closes normally.
        await tester.pumpWidget(inline(floating: floating));
        await tester.pumpAndSettle();
        await tester.pumpWidget(inline(open: false, floating: floating));
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byType(TdsFullTooltipSurface), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'floating mode replacement restores retained exits after interrupted reopen',
    (tester) async {
      for (final floating in [false, true]) {
        await tester.pumpWidget(inline(floating: floating));
        await tester.pumpAndSettle();
        await tester.pumpWidget(inline(open: false, floating: floating));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpWidget(inline(floating: floating));
        await tester.pumpAndSettle();
        await tester.pumpWidget(inline(floating: !floating));
        await tester.pumpAndSettle();
        await tester.pumpWidget(inline(open: false, floating: !floating));
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'controlled mode replacement restores retained exit and cancels old timer',
    (tester) async {
      var closes = 0;
      await tester.pumpWidget(inline(onClose: () => closes++));
      await tester.pumpAndSettle();
      await tester.pumpWidget(inline(open: false));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(inline(onClose: () => closes++));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        inline(open: null, duration: const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(TdsFullTooltipSurface), findsNothing);
      expect(closes, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(closes, 0);
    },
  );

  testWidgets(
    'switching floating mode remounts visuals and resets only the auto-close timer',
    (tester) async {
      final events = <String>[];
      void close() => events.add('close');
      await tester.pumpWidget(
        inline(
          duration: const Duration(seconds: 2),
          onClose: close,
          onClickOutside: () => events.add('initial'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(
        inline(
          floating: true,
          duration: const Duration(seconds: 2),
          onClose: close,
          onClickOutside: () => events.add('replacement'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(events, isEmpty);
      await tester.tapAt(const Offset(10, 10));
      expect(events, ['initial']);
      await tester.pump(const Duration(seconds: 1));
      expect(events, ['initial', 'close']);
      expect(find.byType(BackdropFilter), findsOneWidget);
    },
  );
}
