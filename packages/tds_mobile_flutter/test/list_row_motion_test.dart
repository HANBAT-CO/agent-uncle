import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/list_row_motion.dart';
import 'collections_feedback_test.dart' show testApp;

Finder paintOf<T>() =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is T);
Duration ms(int n) => Duration(milliseconds: n);
Widget row(
  TdsListRowController controller, {
  bool dark = false,
  bool interactive = false,
  double? width,
  double height = 40,
}) => testApp(
  TdsMobileProvider(
    theme: TdsThemeData(
      colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
    ),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: TdsListRow(
          controller: controller,
          onPressed: interactive ? () {} : null,
          border: TdsListRowBorder.indented,
          contents: SizedBox(
            key: const Key('contents'),
            height: height,
            child: const Text('내 계좌'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TdsListRowShinePainter shinePainter(WidgetTester tester) =>
      tester.widget<CustomPaint>(paintOf<TdsListRowShinePainter>()).painter!
          as TdsListRowShinePainter;

  for (final initialDark in [false, true]) {
    testWidgets('live theme replacement restarts shine from $initialDark', (
      tester,
    ) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(row(controller, dark: initialDark));
      controller.shine();
      await tester.pump();
      await tester.pump(ms(600));
      await tester.pumpWidget(row(controller, dark: !initialDark));
      expect(shinePainter(tester).dark, !initialDark);
      expect(shinePainter(tester).elapsed, Duration.zero);
      final duration = TdsListRowMotion.shineDuration(!initialDark, 1);
      await tester.pump(duration - ms(1));
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await tester.pump(ms(2));
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    });
  }

  testWidgets('changed repeat count retargets a resized light shine', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller, width: 320.4, height: 40.4));
    controller.shine();
    await tester.pump();
    await tester.pump(ms(550));
    final previousX = shinePainter(
      tester,
    ).boundsForSize(const Size(320.4, 64.4)).left;
    await tester.pumpWidget(row(controller, width: 200.6, height: 70.2));
    controller.shine(playCount: 2);
    await tester.pump();
    expect(shinePainter(tester).elapsed, Duration.zero);
    expect(shinePainter(tester).translateFromX, closeTo(previousX, 1e-9));
    expect(shinePainter(tester).translateToX, 201);
    expect(
      shinePainter(tester).boundsForSize(const Size(200.6, 94.2)).left,
      closeTo(previousX, 1e-9),
    );
    await tester.pump(ms(2300));
    // The next loop starts at the retargeted current value, not at -3 * height.
    expect(
      shinePainter(tester).boundsForSize(const Size(200.6, 94.2)).left,
      closeTo(previousX, 1e-9),
    );
    await tester.pump(ms(2100));
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pump(ms(101));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
  });

  testWidgets('light shine freezes integer translation, not its gradient box', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller, width: 320.4, height: 40.4));
    controller.shine();
    await tester.pump();
    await tester.pump(ms(550));
    expect(shinePainter(tester).translateFromX, -192);
    expect(shinePainter(tester).translateToX, 320);
    await tester.pumpWidget(row(controller, width: 200.6, height: 70.2));
    controller.shine(); // Same count does not invalidate the source memo.
    await tester.pump();
    final painter = shinePainter(tester);
    expect(painter.elapsed, ms(550));
    expect(painter.translateFromX, -192);
    expect(painter.translateToX, 320);
    final bounds = painter.boundsForSize(const Size(200.6, 94.2));
    expect(bounds.left, -128); // -.192k + (.320k + .192k) * .125
    expect(bounds.top, -94.2);
    expect(bounds.width, closeTo(282.6, 1e-9));
    await tester.pump(ms(1651));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    // A clean invocation measures the resized row.
    controller.shine();
    await tester.pump();
    expect(shinePainter(tester).translateFromX, -282);
    expect(shinePainter(tester).translateToX, 201);
    await tester.pumpAndSettle();
  });

  testWidgets('height-only change cannot restart a light shine channel', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller, width: 320.4, height: 40.4));
    controller.shine();
    await tester.pump();
    await tester.pump(ms(550));
    await tester.pumpWidget(row(controller, width: 320.4, height: 70.2));
    controller.shine(playCount: 3);
    await tester.pump();
    expect(shinePainter(tester).elapsed, ms(550));
    expect(shinePainter(tester).translateFromX, -192);
    await tester.pump(ms(1651));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
  });

  testWidgets('dark shine follows live percentages without restarting', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller, dark: true, width: 200));
    controller.shine();
    await tester.pump();
    await tester.pump(ms(625));
    await tester.pumpWidget(
      row(controller, dark: true, width: 300, height: 80),
    );
    controller.shine(playCount: 3);
    await tester.pump();
    final painter = shinePainter(tester);
    expect(painter.elapsed, ms(625));
    expect(
      painter.boundsForSize(const Size(300, 104)),
      const Rect.fromLTWH(-787.5, 0, 1200, 104),
    );
    await tester.pump(ms(1876));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
  });

  for (final initialDark in [false, true]) {
    testWidgets('theme restart uses latest repeat request from $initialDark', (
      tester,
    ) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(row(controller, dark: initialDark));
      controller.shine();
      await tester.pump();
      await tester.pump(ms(550));
      controller.shine(playCount: 2);
      await tester.pump();
      expect(shinePainter(tester).elapsed, ms(550));
      await tester.pumpWidget(row(controller, dark: !initialDark));
      expect(shinePainter(tester).elapsed, Duration.zero);
      final duration = TdsListRowMotion.shineDuration(!initialDark, 2);
      await tester.pump(duration - ms(1));
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await tester.pump(ms(2));
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    });
  }

  testWidgets('same-commit theme and size change measures pre-commit layout', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    Widget subject(bool dark, double width, double height) => LayoutBuilder(
      builder: (_, _) =>
          row(controller, dark: dark, width: width, height: height),
    );
    await tester.pumpWidget(subject(true, 300.2, 90.4));
    controller.shine();
    await tester.pump();
    await tester.pump(ms(550));
    await tester.pumpWidget(subject(false, 240.6, 50.2));
    final painter = shinePainter(tester);
    expect(painter.dark, false);
    expect(painter.translateFromX, -342);
    expect(painter.translateToX, 300);
    expect(
      painter.boundsForSize(const Size(240.6, 74.2)).width,
      closeTo(222.6, 1e-9),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('theme restart does not discard pending blink timeout or leak', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller));
    controller.blink();
    await tester.pump();
    await tester.pump(ms(400));
    controller.shine();
    await tester.pump();
    await tester.pumpWidget(row(controller, dark: true));
    await tester.pump(ms(1101));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    controller.shine();
    await tester.pump();
    await tester.pumpWidget(row(controller));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(ms(10000));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repeated shine with an unchanged target keeps its in-flight repeat count',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(row(controller));
      controller.shine();
      await tester.pump();
      await tester.pump(ms(600));
      controller.shine(playCount: 3);
      await tester.pump();
      final painter =
          tester.widget<CustomPaint>(paintOf<TdsListRowShinePainter>()).painter!
              as TdsListRowShinePainter;
      expect(painter.elapsed, ms(600));
      await tester.pump(ms(1601));
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    },
  );
  testWidgets(
    'iOS edge touches suppress effect, not click; other pointers still animate',
    (tester) async {
      var clicks = 0;
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        testApp(
          TdsMobileProvider(
            theme: const TdsThemeData(platform: TdsPlatform(os: TdsOS.ios)),
            child: TdsListRow(
              controller: controller,
              onPressed: () => clicks++,
              contents: const Text('계좌'),
            ),
          ),
        ),
      );
      for (final pointer in [
        (ui.PointerDeviceKind.touch, 30.0, false),
        (ui.PointerDeviceKind.touch, 31.0, true),
        (ui.PointerDeviceKind.mouse, 20.0, true),
      ]) {
        final gesture = await tester.startGesture(
          Offset(pointer.$2, 20),
          kind: pointer.$1,
        );
        await tester.pump();
        await tester.pump(ms(150));
        final scale = tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(TdsListRowEffects),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .entry(0, 0);
        expect(scale, pointer.$3 ? lessThan(.97) : 1);
        await gesture.up();
        await tester.pumpAndSettle();
        // Each case is independent of ht's 300ms compatibility-mouse guard.
        await tester.pump(ms(301));
      }
      expect(clicks, 3);
    },
  );
  test(
    'blink has independent 80/480ms delays and 200ms rise + slow return',
    () {
      expect(TdsListRowMotion.blinkRadius(ms(79)), 0);
      expect(TdsListRowMotion.blinkRadius(ms(200)), greaterThan(0));
      expect(TdsListRowMotion.blinkDimmer(ms(480)), 0);
      expect(TdsListRowMotion.blinkDimmer(ms(680)), greaterThan(0));
      expect(TdsListRowMotion.blinkScale(Duration.zero), 1);
      expect(
        TdsListRowMotion.blinkScale(ms(100)),
        closeTo(1 + .02 * TdsMotion.out.transform(.5), 1e-9),
      );
      expect(TdsListRowMotion.blinkScale(ms(200)), 1.02);
      expect(
        TdsListRowMotion.blinkScale(TdsListRowMotion.blinkContentDuration),
        1,
      );
    },
  );
  test(
    'shine uses runtime quadratic easing, theme geometry and no final delay',
    () {
      const size = Size(342, 69);
      expect(TdsListRowMotion.shineDuration(false, 1), ms(2200));
      expect(TdsListRowMotion.shineDuration(false, 3), ms(6800));
      expect(TdsListRowMotion.shineDuration(true, 3), ms(7500));
      expect(
        TdsListRowMotion.shineRect(size, ms(550), dark: false),
        Rect.fromLTWH(-207 + 549 * .125, -69, 207, 207),
      );
      expect(
        TdsListRowMotion.shineRect(size, ms(1100), dark: false).left,
        67.5,
      );
      expect(TdsListRowMotion.shineProgress(ms(2250), dark: false), 1);
      expect(TdsListRowMotion.shineProgress(ms(2300), dark: false), 0);
      expect(
        TdsListRowMotion.shineRect(size, ms(625), dark: true),
        Rect.fromLTWH(-1026 * .875, 0, 1368, 69),
      );
      expect(TdsListRowMotion.shineOpacity(ms(450), dark: true), .5);
      expect(TdsListRowMotion.shineOpacity(ms(900), dark: true), 1);
      expect(
        TdsListRowMotion.shineOpacity(ms(1700), dark: true),
        closeTo(.5, 1e-9),
      );
    },
  );
  testWidgets(
    'blink layers are behind content, only inner content scales, with retained exit',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(row(controller));
      controller.blink();
      await tester.pump();
      await tester.pump(ms(200));
      final transform = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(const Key('contents')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.storage[0], closeTo(1.02, 1e-9));
      expect(
        find.ancestor(
          of: find.byType(TdsBorder),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      final effectStack = tester.widget<Stack>(
        find
            .ancestor(
              of: paintOf<TdsListRowBlinkPainter>(),
              matching: find.byType(Stack),
            )
            .first,
      );
      expect(effectStack.children.first, isA<Positioned>());
      expect(effectStack.children.last, isA<Transform>());
      await tester.pump(ms(1300));
      await tester.pump(ms(100));
      final exiting =
          tester.widget<CustomPaint>(paintOf<TdsListRowBlinkPainter>()).painter!
              as TdsListRowBlinkPainter;
      expect(exiting.opacity, lessThan(1));
      expect(exiting.opacity, greaterThan(0));
      // State is already default during exit. A new blink is accepted, but the
      // retained layer resumes opacity after 80ms without resetting its radius.
      controller.blink();
      await tester.pump();
      expect(
        (tester.widget<CustomPaint>(paintOf<TdsListRowBlinkPainter>()).painter!
                as TdsListRowBlinkPainter)
            .opacity,
        exiting.opacity,
      );
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(ms(5000));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('shine completes at 2200/4500ms light and 2500/5000ms dark', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    for (final dark in [false, true]) {
      for (final count in [1, 2]) {
        await tester.pumpWidget(row(controller, dark: dark));
        controller.shine(playCount: count);
        await tester.pump();
        final total = TdsListRowMotion.shineDuration(dark, count);
        await tester.pump(total - ms(1));
        expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
        await tester.pump(ms(1));
        // Flutter completes its interpolation on the first tick AFTER the
        // duration (isDone uses >), just as browser completion is frame-based.
        await tester.pump(const Duration(microseconds: 1));
        expect(
          paintOf<TdsListRowShinePainter>(),
          findsNothing,
          reason: 'dark=$dark count=$count',
        );
        await tester.pumpAndSettle();
      }
    }
  });
  testWidgets(
    'press blocks blink, and pending blink timeout still interrupts shine',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(row(controller, interactive: true));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('내 계좌')),
      );
      await tester.pump(ms(150));
      controller.blink();
      await tester.pump();
      expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      controller.blink();
      await tester.pump();
      await tester.pump(ms(500));
      controller.shine();
      await tester.pump();
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await tester.pump(ms(1000));
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
      await tester.pumpAndSettle();
      expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    },
  );
  testWidgets('theme-correct blink and CSS shine colors are actually painted', (
    tester,
  ) async {
    final key = GlobalKey();
    Future<Color> center(CustomPainter painter) async {
      await tester.pumpWidget(
        testApp(
          Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 200,
                height: 60,
                child: CustomPaint(painter: painter),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        image.dispose();
        return bytes!;
      });
      final offset = (30 * 200 + 100) * 4;
      return Color.fromARGB(
        pixels!.getUint8(offset + 3),
        pixels.getUint8(offset),
        pixels.getUint8(offset + 1),
        pixels.getUint8(offset + 2),
      );
    }

    final light = await center(
      TdsListRowShinePainter(elapsed: ms(1100), dark: false),
    );
    expect(light.r, 1);
    expect(light.g, 1);
    expect(light.b, 1);
    expect(light.a, closeTo(.8, .02));
    final dark = await center(
      TdsListRowBlinkPainter(
        elapsed: ms(3000),
        opacity: 1,
        color: const Color(0xff3485fa),
      ),
    );
    expect(dark.b, greaterThan(.9));
    expect(dark.r, lessThan(.3));
    expect(dark.a, closeTo(.136, .015));
  });
}
