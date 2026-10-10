import 'dart:ui' show CheckedState, SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

void main() {
  testWidgets('red bean tab retains its screen-reader activation action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final changes = <int>[];
    await tester.pumpWidget(
      fieldApp(
        TdsTab(
          items: const [TdsTabItem(text: '소식', redBean: true)],
          onChanged: changes.add,
        ),
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('소식 (업데이트 있음)'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(changes, [0]);
    handle.dispose();
  });
  testWidgets('tab keyboard wraps focus without selecting until Enter', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      fieldApp(
        TdsTab(
          items: const [
            TdsTabItem(text: '첫째', selected: true),
            TdsTabItem(text: '둘째'),
            TdsTabItem(text: '셋째'),
          ],
          onChanged: changes.add,
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(changes, [1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(changes, [1, 0]);
  });
  testWidgets(
    'segmented keyboard skips disabled items and updates uncontrolled selection',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <String>[];
      await tester.pumpWidget(
        fieldApp(
          TdsSegmentedControl(
            defaultValue: 'a',
            items: const [
              TdsSegmentedControlItem(value: 'a', text: '첫째'),
              TdsSegmentedControlItem(value: 'b', text: '둘째', disabled: true),
              TdsSegmentedControlItem(value: 'c', text: '셋째'),
            ],
            onChanged: changes.add,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes, ['c']);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('셋째'))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      await tester.tap(find.text('둘째'));
      expect(changes, ['c']);
      semantics.dispose();
    },
  );
  testWidgets(
    'segmented controlled state and short tab widths remain bounded',
    (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        fieldApp(
          SizedBox(
            width: 160,
            child: TdsSegmentedControl(
              value: 'a',
              items: const [
                TdsSegmentedControlItem(value: 'a', text: '첫째'),
                TdsSegmentedControlItem(value: 'b', text: '둘째'),
              ],
              onChanged: changes.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('둘째'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('둘째'));
      expect(changes, ['b', 'b']);
      await tester.pumpWidget(
        fieldApp(
          SizedBox(
            width: 160,
            child: TdsTab(
              items: const [
                TdsTabItem(text: '매우 긴 제목이 들어갑니다', selected: true),
                TdsTabItem(text: '둘째 탭 제목'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TdsTab)).width, 160);
    },
  );
}
