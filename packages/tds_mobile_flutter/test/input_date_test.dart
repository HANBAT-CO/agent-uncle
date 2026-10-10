import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'SearchField clears value, emits callback and keeps external controller alive',
    (tester) async {
      final controller = TextEditingController(text: '검색');
      var deletes = 0;
      String? value;
      await tester.pumpWidget(
        testApp(
          TdsSearchField(
            controller: controller,
            onChanged: (v) => value = v,
            onDeleteClick: () => deletes++,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('검색어 삭제'));
      await tester.pump();
      expect(deletes, 1);
      expect(value, '');
      expect(controller.text, '');
      await tester.enterText(find.byType(EditableText), '다음 검색');
      expect(value, '다음 검색');
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.text = 'still alive';
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Slider controlled value, snapping, keyboard and disabled boundaries',
    (tester) async {
      double? changed;
      await tester.pumpWidget(
        testApp(
          SizedBox(
            width: 200,
            child: TdsSlider(
              value: 10,
              minValue: 0,
              maxValue: 20,
              step: 5,
              onValueChange: (v) => changed = v,
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TdsSlider));
      await tester.tapAt(Offset(rect.right - 12, rect.top + 20));
      expect(changed, 20);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('^10')),
        findsNothing,
      ); // value is not a spoken label
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(changed, 5);
      changed = null;
      await tester.pumpWidget(
        testApp(
          TdsSlider(
            value: 10,
            disabled: true,
            onValueChange: (v) => changed = v,
          ),
        ),
      );
      await tester.tapAt(const Offset(100, 20));
      expect(changed, isNull);
      semantics.dispose();
    },
  );
  test('date-only clamping and range state follow source selection rules', () {
    expect(tdsDaysInMonth(2024, 2), 29);
    expect(tdsDaysInMonth(2025, 2), 28);
    final a = DateTime(2026, 10, 10),
        b = DateTime(2026, 10, 12),
        before = DateTime(2026, 10, 9);
    final range = TdsDateRange(a, null).select(b);
    expect(range.start, a);
    expect(range.end, b);
    expect(range.select(before).start, before);
    expect(range.select(before).end, isNull);
    expect(TdsDateRange(a, null).select(a).end, isNull);
    expect(TdsDateRange(a, null).select(a, allowSameDate: true).end, a);
    expect(tdsClampDate(before, min: a, max: b), a);
    expect(tdsClampDate(DateTime(2026, 10, 20), min: a, max: b), b);
  });
  testWidgets('Calendar disabled dates and reselect-to-clear', (tester) async {
    DateTime? selected;
    var callbacks = 0;
    await tester.pumpWidget(
      testApp(
        SizedBox(
          height: 440,
          child: TdsDatePicker(
            initialMonth: DateTime(2026, 10),
            maxVisibleMonth: DateTime(2026, 10),
            minSelectableDate: DateTime(2026, 10, 2),
            maxSelectableDate: DateTime(2026, 10, 5),
            disabledDate: (d) => d.day == 3,
            onDateChange: (d) {
              selected = d;
              callbacks++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('1'));
    await tester.tap(find.text('3'));
    expect(callbacks, 0);
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(selected, DateTime(2026, 10, 4));
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(selected, isNull);
    expect(callbacks, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Wheel updates options safely, empty options and looping selection',
    (tester) async {
      int? value;
      await tester.pumpWidget(
        testApp(
          TdsWheel(
            options: const [1, 2, 3],
            initialIndex: 2,
            onChange: (v) => value = v,
          ),
        ),
      );
      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, 70));
      await tester.pumpAndSettle();
      expect(value, isNotNull);
      await tester.pumpWidget(
        testApp(
          TdsWheel(
            options: const [8],
            initialIndex: 2,
            onChange: (v) => value = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        testApp(TdsWheel(options: const [], onChange: (v) => value = v)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListWheelScrollView), findsNothing);
    },
  );
  testWidgets(
    'Wheel date sheet clamps January 31 to leap-February and submits once',
    (tester) async {
      DateTime? date;
      var closes = 0;
      await tester.pumpWidget(
        testApp(
          TdsWheelDateSheet(
            open: true,
            title: '날짜',
            initialDate: DateTime(2024, 1, 31),
            min: DateTime(2024),
            max: DateTime(2024, 12, 31),
            onClose: () => closes++,
            onChange: (v) => date = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<TdsWheel>(find.byType(TdsWheel).at(1)).onChange(2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용'));
      expect(date, DateTime(2024, 2, 29));
      expect(closes, 1);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
