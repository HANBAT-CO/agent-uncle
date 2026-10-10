import 'dart:math';
import 'dart:ui' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/pressable.dart';
import 'package:tds_mobile_flutter/src/foundation/secure_keypad_layout.dart';
import 'collections_feedback_test.dart' show testApp;

Finder keyButton(String label) => find.byWidgetPredicate(
  (w) => w is TdsPressable && w.semanticLabel == label,
);

Widget keypad({
  TdsSecureKeypadController? controller,
  bool disabled = false,
  ValueChanged<String>? onKey,
  VoidCallback? onBackspace,
  VoidCallback? onSpace,
  VoidCallback? onSubmit,
}) => SizedBox(
  width: 390,
  child: TdsFullSecureKeypad(
    controller: controller,
    submitDisabled: disabled,
    onKeyClick: onKey ?? (_) {},
    onBackspaceClick: onBackspace ?? () {},
    onSpaceClick: onSpace ?? () {},
    onSubmit: onSubmit ?? () {},
  ),
);

class _ScriptedRandom implements Random {
  _ScriptedRandom(this.indices);
  final List<int> indices;
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return indices.removeAt(0);
  }

  @override
  bool nextBool() => throw UnsupportedError('not used');
  @override
  double nextDouble() => throw UnsupportedError('not used');
}

void main() {
  test('blank insertion uses original key-group bound on every draw', () {
    final random = _ScriptedRandom([3, 3]);
    expect(secureKeypadRow(5, 2, random), [0, 1, 2, null, null, 3, 4]);
    expect(random.bounds, [5, 5]);
    final end = _ScriptedRandom([4, 4]);
    expect(secureKeypadRow(5, 2, end), [0, 1, 2, 3, null, null, 4]);
    for (var seed = 0; seed < 100; seed++) {
      final row = secureKeypadRow(8, 2, Random(seed));
      expect(row.whereType<int>(), List.generate(8, (i) => i));
      expect(row.where((i) => i == null).length, 2);
      expect(row.last, 7);
    }
  });

  testWidgets(
    'secure keypad keeps 272px height, grid widths and 2:2:5:5 controls',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final scale in [100.0, 160.0, 200.0]) {
        await tester.pumpWidget(
          testApp(
            Align(alignment: Alignment.topLeft, child: keypad()),
            scale: scale,
          ),
        );
        expect(
          tester.getSize(find.byType(TdsFullSecureKeypad)),
          const Size(390, 272),
        );
        for (final label in ['1', 'q']) {
          expect(
            tester.getSize(keyButton(label)).width,
            closeTo(370 / 11, .001),
          );
          expect(tester.getSize(keyButton(label)).height, 50);
        }
        expect(tester.getSize(keyButton('a')).width, 37);
        expect(tester.getSize(keyButton('지우기')).width, 74);
        expect(
          tester.getTopRight(keyButton('0')),
          offsetMoreOrLessEquals(const Offset(380, 6)),
        );
        expect(
          tester.getTopRight(keyButton('지우기')),
          offsetMoreOrLessEquals(const Offset(380, 156)),
        );
        for (final entry in {
          'shift': 2,
          '특수로 전환': 2,
          'space': 5,
          '입력 완료': 5,
        }.entries) {
          expect(
            tester.getSize(keyButton(entry.key)).width,
            closeTo(390 * entry.value / 14, .001),
          );
          expect(tester.getSize(keyButton(entry.key)).height, 56);
          expect(tester.getTopLeft(keyButton(entry.key)).dy, 216);
        }
        expect(tester.getTopLeft(find.text('q')).dy, 59.5);
        expect(
          tester.getTopLeft(find.text('ㅂ')).dy,
          86.25,
        ); // 19.5px CSS line vs rounded 20px paragraph.
        expect(tester.widget<Text>(find.text('q')).style!.height, 1.5);
        expect(tester.widget<Text>(find.text('ㅂ')).style!.fontSize, 13);
        expect(tester.widget<Text>(find.text('Space')).style!.fontSize, 17);
        expect(find.bySemanticsLabel('ㅂ'), findsNothing);
        await tester.tap(keyButton('특수로 전환'));
        await tester.pump();
        expect(tester.getSize(keyButton('!')).width, closeTo(370 / 11, .001));
        expect(tester.getSize(keyButton('.')).width, 37);
        expect(
          tester.getTopRight(keyButton('지우기')),
          offsetMoreOrLessEquals(const Offset(380, 156)),
        );
        await tester.tap(keyButton('영문으로 전환'));
        await tester.pump();
      }
      semantics.dispose();
      await tester.pumpWidget(testApp(const SizedBox()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all secure actions dispatch at press start exactly once', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      testApp(
        keypad(
          onKey: events.add,
          onBackspace: () => events.add('back'),
          onSpace: () => events.add('space'),
          onSubmit: () => events.add('submit'),
        ),
      ),
    );
    for (final entry in {
      'q': 'q',
      '지우기': 'back',
      'space': 'space',
      '입력 완료': 'submit',
    }.entries) {
      final before = events.length;
      final pointer = await tester.startGesture(
        tester.getCenter(keyButton(entry.key)),
      );
      expect(events.length, before + 1);
      expect(events.last, entry.value);
      await pointer.up();
      expect(events.length, before + 1);
    }
    final cancelled = await tester.startGesture(
      tester.getCenter(keyButton('q')),
    );
    expect(events.length, 5);
    await cancelled.cancel();
    expect(events.length, 5);
    final shift = await tester.startGesture(
      tester.getCenter(keyButton('shift')),
    );
    await tester.pump();
    expect(find.text('Q'), findsOneWidget);
    await shift.up();
    await tester.pump();
    expect(find.text('Q'), findsOneWidget);
    Focus.of(tester.element(find.text('Q'))).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(events.last, 'Q');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(events.length, 6);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    final node = tester.getSemantics(keyButton('Q'));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    expect(events.length, 7);
    semantics.dispose();
    await tester.pumpWidget(testApp(const SizedBox()));
  });

  testWidgets(
    'disabled shift keeps dark background; only submit becomes blue100',
    (tester) async {
      var submits = 0;
      await tester.pumpWidget(
        testApp(keypad(disabled: true, onSubmit: () => submits++)),
      );
      await tester.tap(keyButton('특수로 전환'));
      await tester.pump();
      Container surface(String label) => tester.widget<Container>(
        find
            .descendant(of: keyButton(label), matching: find.byType(Container))
            .first,
      );
      expect(
        (surface('shift').decoration! as BoxDecoration).color,
        const Color(0xff283447),
      );
      expect(surface('shift').foregroundDecoration, isNotNull);
      expect(
        (surface('입력 완료').decoration! as BoxDecoration).color,
        TdsPalette.blue100,
      );
      expect(surface('입력 완료').foregroundDecoration, isNull);
      final shift = tester.widget<SvgPicture>(
        find.descendant(
          of: keyButton('shift'),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(shift.width, 21);
      expect(shift.height, 20);
      expect(
        shift.colorFilter,
        const ColorFilter.mode(TdsPalette.grey500, BlendMode.srcIn),
      );
      await tester.tap(keyButton('shift'));
      await tester.tap(keyButton('입력 완료'));
      await tester.pump();
      expect(submits, 0);
      expect(find.text('!'), findsOneWidget);
      final back = tester.widget<SvgPicture>(
        find.descendant(
          of: keyButton('지우기'),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(back.width, 20);
      expect(back.height, 20);
      await tester.pumpWidget(testApp(const SizedBox()));
    },
  );

  testWidgets(
    'case changes reuse blank positions; imperative reorder does not render immediately',
    (tester) async {
      final controller = TdsSecureKeypadController();
      await tester.pumpWidget(testApp(keypad(controller: controller)));
      final before = [
        for (final label in 'qwertyuiop'.split(''))
          tester.getTopLeft(keyButton(label)),
      ];
      await tester.tap(keyButton('shift'));
      await tester.pump();
      expect([
        for (final label in 'QWERTYUIOP'.split(''))
          tester.getTopLeft(keyButton(label)),
      ], before);
      controller.reorderEmptyCells();
      await tester.pump();
      expect([
        for (final label in 'QWERTYUIOP'.split(''))
          tester.getTopLeft(keyButton(label)),
      ], before);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.reorderEmptyCells();
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'security announcement appears at 200ms, clears at 1s, and cancels on unmount',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const label = '보안 키패드가 화면에 표시됐어요.';
      await tester.pumpWidget(testApp(keypad()));
      expect(find.bySemanticsLabel(label), findsNothing);
      await tester.pump(const Duration(milliseconds: 199));
      expect(find.bySemanticsLabel(label), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.bySemanticsLabel(label), findsNothing);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpWidget(testApp(keypad()));
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
