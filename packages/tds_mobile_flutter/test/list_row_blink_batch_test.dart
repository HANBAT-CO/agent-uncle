import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/list_row_motion.dart';
import 'list_row_motion_test.dart' show ms, paintOf, row;

TdsListRowBlinkPainter blinkPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(paintOf<TdsListRowBlinkPainter>()).painter!
        as TdsListRowBlinkPainter;

double contentScale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('contents')),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[0];

Future<Color> paintedPixel(
  WidgetTester tester,
  CustomPainter painter, {
  int x = 100,
  int y = 30,
}) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(200, 60));
  final picture = recorder.endRecording();
  try {
    return (await tester.runAsync(() async {
      final image = await picture.toImage(200, 60);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        final offset = (y * 200 + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      } finally {
        image.dispose();
      }
    }))!;
  } finally {
    picture.dispose();
  }
}

void main() {
  testWidgets('blink radial color is fixed even when its dimmer color changes', (
    tester,
  ) async {
    final color = await paintedPixel(
      tester,
      TdsListRowBlinkPainter(
        elapsed: ms(3000),
        opacity: 1,
        color: const Color(0xffff0000),
      ),
    );
    // QQe resolves light blue500 at module load. Only ZQe uses the live color.
    expect(color.a, closeTo(.136, .008));
    expect(color.r, closeTo(.43, .02));
    expect(color.g, closeTo(.36, .02));
    expect(color.b, closeTo(.68, .02));
  });

  testWidgets(
    'blink geometry and dimmer theme remain live without restarting',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(row(controller, width: 320.4, height: 40.4));
      controller.blink();
      await tester.pump();
      await tester.pump(ms(650));
      final before = blinkPainter(tester);
      await tester.pumpWidget(
        row(controller, dark: true, width: 200.6, height: 70.2),
      );
      final resized = blinkPainter(tester);
      expect(resized.elapsed, before.elapsed);
      expect(resized.opacity, before.opacity);
      expect(resized.color, const Color(0xff3485fa));
      expect(tester.getSize(find.byType(TdsListRowEffects)).width, 200.6);
      expect(
        tester.getSize(find.byType(TdsListRowEffects)).height,
        closeTo(94.2, .001),
      );
      final center = await paintedPixel(tester, resized);
      // A dark radial layer would shift this channel above .97 instead.
      expect(center.b, lessThan(.973));
      await tester.pump(ms(850));
      await tester.pump(ms(200));
      final exiting = blinkPainter(tester);
      await tester.pumpWidget(row(controller, width: 300.2, height: 100.4));
      expect(blinkPainter(tester).elapsed, exiting.elapsed);
      expect(blinkPainter(tester).opacity, exiting.opacity);
      expect(blinkPainter(tester).color, TdsPalette.blue500);
      await tester.pumpAndSettle();
      expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    },
  );

  testWidgets('one synchronous shine then blink batch commits only blink', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller));
    controller.shine();
    controller.blink(duration: ms(500));
    await tester.pump();
    expect(paintOf<TdsListRowBlinkPainter>(), findsOneWidget);
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    await tester.pump(ms(200));
    expect(contentScale(tester), closeTo(1.02, 1e-9));
    await tester.pumpAndSettle();
  });

  testWidgets('blink then shine does not mount or scale a transient blink', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller));
    controller.blink(duration: ms(500));
    controller.shine();
    await tester.pump();
    expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pump(ms(200));
    expect(contentScale(tester), 1);
    // The accepted blink still registered its original wall-clock timeout.
    await tester.pump(ms(300));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'batched shine requests mount with the final count dark=$dark',
      (tester) async {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(row(controller, dark: dark));
        controller.shine();
        controller.shine(playCount: 3);
        await tester.pump();
        await tester.pump(ms(2600));
        expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
        await tester.pump(TdsListRowMotion.shineDuration(dark, 3) - ms(2599));
        expect(paintOf<TdsListRowShinePainter>(), findsNothing);
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('batched long then short blinks both retain their deadlines', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller));
    controller.blink(duration: ms(500));
    controller.blink(duration: ms(100));
    await tester.pump();
    await tester.pump(ms(100));
    await tester.pump(ms(100));
    expect(blinkPainter(tester).opacity, lessThan(1));
    controller.shine();
    await tester.pump();
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pump(ms(300));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('batched short then long blink keeps the second stale timeout', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller));
    controller.blink(duration: ms(100));
    controller.blink(duration: ms(500));
    await tester.pump();
    await tester.pump(ms(100));
    await tester.pump(ms(100));
    controller.shine();
    await tester.pump();
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pump(ms(300));
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a committed shine still blocks a later blink request', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(row(controller));
    controller.shine();
    await tester.pump();
    controller.blink(duration: ms(100));
    await tester.pump();
    await tester.pump(ms(200));
    expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pumpAndSettle();
  });

  for (final duration in [100, 600]) {
    testWidgets(
      'blink exit freezes dimmer and reentry retains radius $duration',
      (tester) async {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(row(controller));
        controller.blink(duration: ms(duration));
        await tester.pump();
        await tester.pump(ms(duration));
        await tester.pump(ms(550));
        final departing = blinkPainter(tester);
        final corner = await paintedPixel(tester, departing, x: 0, y: 0);
        if (duration == 100) expect(corner.a, 0);
        controller.blink();
        await tester.pump();
        final reentered = blinkPainter(tester);
        expect(reentered.elapsed, greaterThanOrEqualTo(departing.elapsed));
        expect(reentered.opacity, departing.opacity);
        await tester.pump(ms(50));
        expect(blinkPainter(tester).opacity, departing.opacity);
        final heldCorner = await paintedPixel(
          tester,
          blinkPainter(tester),
          x: 0,
          y: 0,
        );
        expect(heldCorner.a, corner.a);
        await tester.pump(ms(150));
        expect(blinkPainter(tester).opacity, greaterThan(departing.opacity));
        expect(blinkPainter(tester).opacity, lessThan(1));
        await tester.pump(ms(400));
        final enteringCorner = await paintedPixel(
          tester,
          blinkPainter(tester),
          x: 0,
          y: 0,
        );
        expect(enteringCorner.a, greaterThan(heldCorner.a));
        await tester.pumpAndSettle();
        expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
      },
    );
  }

  testWidgets('queued batches and every accepted timer are cleared on detach', (
    tester,
  ) async {
    final previous = TdsListRowController();
    final replacement = TdsListRowController();
    addTearDown(previous.dispose);
    addTearDown(replacement.dispose);
    await tester.pumpWidget(row(previous));
    previous.blink(duration: ms(100));
    previous.blink(duration: ms(500));
    previous.shine();
    await tester.pumpWidget(row(replacement));
    expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    replacement.shine(playCount: 3);
    await tester.pump();
    await tester.pump(ms(1000));
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(ms(8000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a queued effect cannot revive a row removed in the same build', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    var remove = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) {
          rebuild = setState;
          if (remove) {
            // Disposal happens before this turn's queued microtask is flushed.
            controller.blink(duration: ms(100));
            controller.shine();
            return const SizedBox();
          }
          return row(controller);
        },
      ),
    );
    rebuild(() => remove = true);
    await tester.pump();
    await tester.pump(ms(3000));
    expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    expect(paintOf<TdsListRowShinePainter>(), findsNothing);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
