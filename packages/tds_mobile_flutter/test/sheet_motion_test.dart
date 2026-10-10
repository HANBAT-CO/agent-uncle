import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/sheet_motion.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  Future<void> viewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder getHandler() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == '바텀시트 높이 조절',
  );

  test(
    'source drag uses logarithmic horizontal/up elasticity, linear down and dimmer thresholds',
    () {
      expect(TdsSheetMotion.dragTranslation(const Offset(5, -5)), Offset.zero);
      expect(
        TdsSheetMotion.dragTranslation(const Offset(50, -50)),
        Offset(5 * math.log(4), -15 * math.log(4)),
      );
      expect(
        TdsSheetMotion.dragTranslation(const Offset(-50, 50)),
        Offset(-5 * math.log(4), 50),
      );
      for (final dark in [false, true]) {
        final normal = dark ? .56 : .2;
        expect(TdsSheetMotion.dimmer(const Offset(0, -49), 300, dark), normal);
        expect(
          TdsSheetMotion.dimmer(const Offset(0, -50), 300, dark),
          dark ? .8 : .4,
        );
        expect(TdsSheetMotion.dimmer(const Offset(0, 9), 300, dark), normal);
        expect(
          TdsSheetMotion.dimmer(const Offset(0, 150), 300, dark),
          normal / 2,
        );
      }
    },
  );

  testWidgets(
    'sheet enters from fixed 150px + gap, exits with forward rapid while dimmer uses quick',
    (tester) async {
      await viewport(tester);
      var exits = 0;
      Widget view(bool open) => testApp(
        TdsBottomSheet(
          open: open,
          onExited: () => exits++,
          child: const SizedBox(height: 200),
        ),
      );
      await tester.pumpWidget(view(true));
      await tester.pump();
      FractionalTranslation translation() =>
          tester.widget<FractionalTranslation>(
            find
                .ancestor(
                  of: find.byType(TdsSheetDimmerScope),
                  matching: find.byType(FractionalTranslation),
                )
                .first,
          );
      expect(translation().translation, Offset.zero);
      expect((translation().child as Transform).transform.storage[13], 160);
      await tester.pump(const Duration(milliseconds: 100));
      final entered =
          1 -
          TdsMotion.quick.transform(
            100000 / TdsMotion.quick.duration.inMicroseconds,
          );
      expect(
        (translation().child as Transform).transform.storage[13],
        closeTo(160 * entered, .001),
      );
      await tester.pumpAndSettle();
      expect((translation().child as Transform).transform.storage[13], 0);
      await tester.pumpWidget(view(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final rapid = TdsMotion.rapid.transform(
        100000 / TdsMotion.rapid.duration.inMicroseconds,
      );
      expect(translation().translation.dy, closeTo(rapid, .001));
      expect(
        (translation().child as Transform).transform.storage[13],
        closeTo(-10 * rapid, .001),
      );
      final dimmer = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .firstWhere(
            (w) => w.color.r == 0 && w.color.g == 0 && w.color.b == 0,
          );
      expect(dimmer.color.a, closeTo(.2 * entered, .001));
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'handler supports two-axis drag, content fade, dimmer change and controlled-close rejection',
    (tester) async {
      await viewport(tester);
      var closes = 0, starts = 0, ends = 0;
      await tester.pumpWidget(
        testApp(
          TdsBottomSheet(
            open: true,
            onClose: () => closes++,
            onHandlerTouchStart: () => starts++,
            onHandlerTouchEnd: () => ends++,
            child: const SizedBox(height: 200, child: Text('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = tester.widget<TdsSheetDimmerScope>(
        find.byType(TdsSheetDimmerScope),
      );
      final gesture = await tester.startGesture(tester.getCenter(getHandler()));
      expect(starts, 1);
      await gesture.moveBy(
        const Offset(50, 50),
        timeStamp: const Duration(milliseconds: 20),
      );
      await tester.pumpAndSettle();
      final animated = find.ancestor(
        of: find.text('body'),
        matching: find.byType(TweenAnimationBuilder<Offset>),
      );
      final target = tester
          .widget<TweenAnimationBuilder<Offset>>(animated.first)
          .tween
          .end!;
      expect(target, Offset(5 * math.log(4), 50));
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('body'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacity.opacity, closeTo(1 - 50 / 216, .001));
      expect(scope.opacity.value, closeTo(.2 * (1 - 50 / 216), .001));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(ends, 1);
      expect(find.text('body'), findsOneWidget); // parent declined close
      expect(
        tester.widget<TweenAnimationBuilder<Offset>>(animated.first).tween.end,
        Offset.zero,
      );
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrollable body rejects touch drag even at scroll origin; source mouse has no target guard',
    (tester) async {
      await viewport(tester);
      var closes = 0;
      await tester.pumpWidget(
        testApp(
          TdsBottomSheet(
            open: true,
            onClose: () => closes++,
            maxHeight: const TdsBottomSheetHeight.pixels(400),
            child: const SizedBox(height: 1500, child: Text('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byType(TdsSheetDimmerScope),
        matching: find.byType(SingleChildScrollView),
      );
      for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        final gesture = await tester.startGesture(
          tester.getTopLeft(scroll) + const Offset(80, 30),
          kind: kind,
        );
        await gesture.moveBy(
          const Offset(0, 60),
          timeStamp: const Duration(milliseconds: 20),
        );
        await tester.pump(const Duration(milliseconds: 20));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(closes, kind == PointerDeviceKind.mouse ? 1 : 0);
      }
    },
  );

  testWidgets(
    'upward drag expands only overflowing sheets and handler callbacks are touch-only',
    (tester) async {
      await viewport(tester);
      var expands = 0, starts = 0;
      Widget view(double height) => testApp(
        TdsBottomSheet(
          key: ValueKey(height),
          open: true,
          onClose: () {},
          expandBottomSheet: true,
          onExpanded: () => expands++,
          onHandlerTouchStart: () => starts++,
          maxHeight: const TdsBottomSheetHeight.pixels(400),
          child: SizedBox(height: height, child: const Text('body')),
        ),
      );
      await tester.pumpWidget(view(100));
      await tester.pumpAndSettle();
      var gesture = await tester.startGesture(tester.getCenter(getHandler()));
      await gesture.moveBy(
        const Offset(0, -30),
        timeStamp: const Duration(milliseconds: 20),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(expands, 0);
      expect(starts, 1);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(view(1500));
      await tester.pumpAndSettle();
      gesture = await tester.startGesture(
        tester.getCenter(getHandler()),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(
        const Offset(0, -30),
        timeStamp: const Duration(milliseconds: 20),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(expands, 1);
      expect(starts, 1);
      expect(tester.getTopLeft(getHandler()).dy, closeTo(0, .01));
    },
  );

  testWidgets(
    'a first touch move expands when requested, even without onClose; cancellation never closes',
    (tester) async {
      await viewport(tester);
      var expands = 0;
      await tester.pumpWidget(
        testApp(
          TdsBottomSheet(
            open: true,
            expandBottomSheetWhenScroll: true,
            onExpanded: () => expands++,
            maxHeight: const TdsBottomSheetHeight.pixels(400),
            child: const SizedBox(height: 1500, child: Text('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byType(TdsSheetDimmerScope),
        matching: find.byType(SingleChildScrollView),
      );
      final gesture = await tester.startGesture(
        tester.getTopLeft(scroll) + const Offset(80, 30),
      );
      await gesture.moveBy(
        const Offset(0, -10),
        timeStamp: const Duration(milliseconds: 20),
      );
      await tester.pumpAndSettle();
      expect(expands, 1);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
