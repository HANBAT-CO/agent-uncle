import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;
import 'list_row_motion_test.dart' show paintOf, ms;

Widget fixture(
  TdsListRowController controller, {
  VoidCallback? childDown,
  VoidCallback? ancestorDown,
  VoidCallback? childUp,
  VoidCallback? ancestorUp,
  VoidCallback? onPressed,
  bool? withTouchEffect,
  bool clickable = true,
  bool disabled = false,
  TdsOS os = TdsOS.android,
}) => testApp(
  TdsMobileProvider(
    theme: TdsThemeData(platform: TdsPlatform(os: os)),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 320,
        child: Listener(
          onPointerDown: (_) => ancestorDown?.call(),
          onPointerUp: (_) => ancestorUp?.call(),
          child: TdsListRow(
            controller: controller,
            disabled: disabled,
            withTouchEffect: withTouchEffect,
            onPressed: clickable ? onPressed ?? () {} : null,
            contents: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => childDown?.call(),
              onPointerUp: (_) => childUp?.call(),
              child: const SizedBox(
                key: Key('target'),
                height: 40,
                child: Text('입력 순서'),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

double contentScale(WidgetTester tester) => tester
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

void main() {
  testWidgets(
    'compatibility mouse starts are suppressed for 300ms after touch end',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(fixture(controller));
      final point = tester.getCenter(find.byKey(const Key('target')));
      final touch = await tester.startGesture(point);
      await tester.pump();
      await touch.up();
      await tester.pump();
      controller.shine();
      await tester.pump();
      final ignored = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await ignored.up();
      await tester.pump();
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await tester.pump(ms(301));
      final accepted = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
      await accepted.up();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'secondary mouse button has feedback but does not synthesize a click',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      var clicks = 0;
      await tester.pumpWidget(fixture(controller, onPressed: () => clicks++));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.down(tester.getCenter(find.byKey(const Key('target'))));
      await tester.pump();
      await tester.pump(ms(150));
      expect(contentScale(tester), lessThan(.97));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(contentScale(tester), 1);
      expect(clicks, 0);
    },
  );
  for (final edgeFirst in [false, true]) {
    testWidgets(
      'iOS suppression reads the first active touch, edgeFirst=$edgeFirst',
      (tester) async {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(fixture(controller, os: TdsOS.ios));
        final first = await tester.startGesture(
          Offset(edgeFirst ? 20 : 80, 20),
          pointer: 1,
        );
        await tester.pump();
        controller.shine();
        await tester.pump();
        final second = await tester.startGesture(
          Offset(edgeFirst ? 80 : 20, 20),
          pointer: 2,
        );
        await tester.pump();
        expect(
          paintOf<TdsListRowShinePainter>(),
          edgeFirst ? findsOneWidget : findsNothing,
        );
        await second.up();
        await first.up();
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('disabling an already held row does not strand its feedback', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    var clicks = 0;
    await tester.pumpWidget(fixture(controller, onPressed: () => clicks++));
    final mouse = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('target'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump(ms(150));
    await tester.pumpWidget(
      fixture(controller, disabled: true, onPressed: () => clicks++),
    );
    await mouse.up();
    await tester.pumpAndSettle();
    expect(contentScale(tester), 1);
    expect(clicks, 0);
  });
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final ancestor in [false, true]) {
      for (final blink in [false, true]) {
        testWidgets(
          '$kind ${ancestor ? 'ancestor' : 'child'} down ${blink ? 'blink' : 'shine'} respects bubbling order',
          (tester) async {
            final controller = TdsListRowController();
            addTearDown(controller.dispose);
            void command() => blink
                ? controller.blink(duration: ms(400))
                : controller.shine();
            await tester.pumpWidget(
              fixture(
                controller,
                childDown: ancestor ? null : command,
                ancestorDown: ancestor ? command : null,
              ),
            );
            final gesture = await tester.startGesture(
              tester.getCenter(find.byKey(const Key('target'))),
              kind: kind,
            );
            await tester.pump();
            await tester.pump(ms(150));
            expect(
              paintOf<TdsListRowShinePainter>(),
              ancestor && !blink ? findsOneWidget : findsNothing,
            );
            expect(
              paintOf<TdsListRowBlinkPainter>(),
              ancestor && blink ? findsOneWidget : findsNothing,
            );
            if (!ancestor) expect(contentScale(tester), lessThan(.97));
            if (ancestor && !blink) expect(contentScale(tester), 1);
            if (blink && !ancestor) {
              await tester.pump(ms(251));
              await tester.pump(TdsMotion.rapid.duration);
              // A blink superseded by touch still owns its accepted deadline.
              expect(contentScale(tester), closeTo(1, .001));
            }
            await gesture.up();
            await tester.pumpAndSettle();
          },
        );
      }
      testWidgets(
        '$kind ${ancestor ? 'ancestor' : 'child'} up shine follows source end phase',
        (tester) async {
          final controller = TdsListRowController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            fixture(
              controller,
              childUp: ancestor ? null : controller.shine,
              ancestorUp: ancestor ? controller.shine : null,
            ),
          );
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('target'))),
            kind: kind,
          );
          await tester.pump(ms(150));
          await gesture.up();
          await tester.pump();
          expect(
            paintOf<TdsListRowShinePainter>(),
            kind == PointerDeviceKind.touch && ancestor
                ? findsOneWidget
                : findsNothing,
          );
          await tester.pumpAndSettle();
        },
      );
    }
    testWidgets(
      '$kind suppressed touch still resets an active effect on release',
      (tester) async {
        for (final clickable in [false, true]) {
          final controller = TdsListRowController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            fixture(controller, clickable: clickable, withTouchEffect: false),
          );
          controller.shine();
          await tester.pump();
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('target'))),
            kind: kind,
          );
          await tester.pump(ms(150));
          expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
          await gesture.up();
          await tester.pump();
          expect(paintOf<TdsListRowShinePainter>(), findsNothing);
        }
      },
    );
    testWidgets(
      '$kind release callbacks retain the committed blink guard, click sees default',
      (tester) async {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        var clicks = 0;
        await tester.pumpWidget(
          fixture(
            controller,
            ancestorUp: controller.blink,
            onPressed: () {
              clicks++;
              controller.blink(duration: ms(400));
            },
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('target'))),
          kind: kind,
        );
        await tester.pump(ms(150));
        await gesture.up();
        await tester.pump();
        expect(clicks, 1);
        expect(paintOf<TdsListRowBlinkPainter>(), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'touch cancellation resets the effect and unmount removes pending mouse end',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fixture(controller, ancestorDown: controller.shine),
      );
      final touch = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump();
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await touch.cancel();
      await tester.pump();
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
      final mouse = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpWidget(const SizedBox());
      await mouse.up();
      await tester.pump(ms(1000));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Enter and Space activate on keydown and repeat without touch feedback',
    (tester) async {
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        var clicks = 0;
        await tester.pumpWidget(fixture(controller, onPressed: () => clicks++));
        final focus = Focus.of(tester.element(find.byKey(const Key('target'))));
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(key);
        await tester.pump(ms(150));
        expect(clicks, 1);
        expect(contentScale(tester), 1);
        await tester.sendKeyRepeatEvent(key);
        expect(clicks, 2);
        await tester.sendKeyUpEvent(key);
        expect(clicks, 2);
      }
    },
  );
}
