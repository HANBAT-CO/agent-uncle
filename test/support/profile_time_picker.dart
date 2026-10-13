import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Finder timeInput(String label) => find.byWidgetPredicate(
  (widget) => widget is TdsTextFieldButton && widget.label == label,
);

Future<void> openTimePicker(WidgetTester tester, String label) async {
  final field = timeInput(label);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
}

/// 실제 스크롤 위치를 바꿔 휠의 선택 콜백을 거친다.
Future<void> scrollTimeWheel(
  WidgetTester tester,
  int wheelIndex,
  int value,
) async {
  final wheel = find.byType(TdsWheel).at(wheelIndex);
  final view = tester.widget<ListWheelScrollView>(
    find.descendant(of: wheel, matching: find.byType(ListWheelScrollView)),
  );
  (view.controller! as FixedExtentScrollController).jumpToItem(value);
  await tester.pumpAndSettle();
}

Future<void> selectTime(WidgetTester tester, String label, String value) async {
  await openTimePicker(tester, label);
  final parts = value.split(':').map(int.parse).toList();
  await scrollTimeWheel(tester, 0, parts[0]);
  await scrollTimeWheel(tester, 1, parts[1]);
  await tester.tap(find.widgetWithText(TdsButton, '적용'));
  await tester.pumpAndSettle();
}
