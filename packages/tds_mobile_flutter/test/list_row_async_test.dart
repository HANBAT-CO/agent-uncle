import 'dart:ui' show SemanticsAction;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;
import 'list_row_input_order_test.dart' show fixture, contentScale;
import 'list_row_motion_test.dart' show paintOf, ms;

void main() {
  for (final microtasks in [1, 5]) {
    testWidgets(
      'imperative calls share a batch across $microtasks microtasks',
      (tester) async {
        final controller = TdsListRowController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(fixture(controller));
        controller.shine();
        for (var i = 0; i < microtasks; i++) {
          await Future<void>.value();
        }
        controller.blink(duration: ms(300));
        await tester.pump();
        expect(paintOf<TdsListRowBlinkPainter>(), findsOneWidget);
        expect(paintOf<TdsListRowShinePainter>(), findsNothing);
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('a rendered imperative effect blocks a later blink', (
    tester,
  ) async {
    final controller = TdsListRowController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(fixture(controller));
    controller.shine();
    await tester.pump();
    controller.blink(duration: ms(300));
    await tester.pump();
    expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
    expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
    await tester.pumpAndSettle();
  });
  testWidgets(
    'a microtask overwrite does not mount blink but keeps its deadline',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(fixture(controller));
      controller.blink(duration: ms(300));
      await Future<void>.value();
      controller.shine();
      await tester.pump();
      expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
      expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
      await tester.pump(ms(150));
      expect(contentScale(tester), 1);
      await tester.pump(ms(150));
      expect(paintOf<TdsListRowShinePainter>(), findsNothing);
      await tester.pumpAndSettle();
    },
  );
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('discrete input commits before the next microtask kind=$kind', (
      tester,
    ) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(fixture(controller));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
        kind: kind,
      );
      await Future<void>.value();
      controller.blink(duration: ms(300));
      await tester.pump();
      await tester.pump(ms(150));
      expect(paintOf<TdsListRowBlinkPainter>(), findsNothing);
      expect(contentScale(tester), lessThan(.97));
      await gesture.up();
      await Future<void>.value();
      controller.blink(duration: ms(300));
      await tester.pump();
      expect(paintOf<TdsListRowBlinkPainter>(), findsOneWidget);
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'unmount clears imperative work still pending across microtasks',
    (tester) async {
      final controller = TdsListRowController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(fixture(controller));
      controller.shine();
      await Future<void>.value();
      controller.blink(duration: ms(300));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(ms(600));
      expect(tester.takeException(), isNull);
    },
  );
  for (final blinkFirst in [false, true]) {
    for (final input in ['pointer', 'keyboard', 'semantics']) {
      testWidgets(
        'external TDS activation ends its batch before await blinkFirst=$blinkFirst input=$input',
        (tester) async {
          final controller = TdsListRowController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            testApp(
              Column(
                children: [
                  TdsListRow(
                    controller: controller,
                    contents: const Text('효과 대상'),
                  ),
                  TdsTextButton(
                    size: TdsTextButtonSize.medium,
                    onPressed: () async {
                      if (blinkFirst) {
                        controller.blink(duration: ms(300));
                      } else {
                        controller.shine();
                      }
                      await Future<void>.value();
                      if (blinkFirst) {
                        controller.shine();
                      } else {
                        controller.blink(duration: ms(300));
                      }
                    },
                    child: const Text('비동기 실행'),
                  ),
                ],
              ),
            ),
          );
          if (input == 'keyboard') {
            Focus.of(tester.element(find.text('비동기 실행'))).requestFocus();
            await tester.pump();
            await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
          } else if (input == 'semantics') {
            final semantics = tester.ensureSemantics();
            try {
              await tester.pump();
              final node = tester.getSemantics(find.bySemanticsLabel('비동기 실행'));
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
              );
              node.owner!.performAction(node.id, SemanticsAction.tap);
              await Future<void>.value();
            } finally {
              semantics.dispose();
            }
          } else {
            await tester.tap(find.text('비동기 실행'));
          }
          await tester.pump();
          expect(paintOf<TdsListRowShinePainter>(), findsOneWidget);
          expect(
            paintOf<TdsListRowBlinkPainter>(),
            blinkFirst ? findsOneWidget : findsNothing,
          );
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
