import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Finder quantityInput() => find.byWidgetPredicate(
  (widget) => widget is TdsTextFieldButton && widget.label == '요청 수량',
);

Future<void> openQuantityPicker(WidgetTester tester) async {
  await tester.ensureVisible(quantityInput());
  await tester.tap(quantityInput());
  await tester.pumpAndSettle();
}

Future<void> scrollQuantityWheel(WidgetTester tester, int quantity) async {
  final view = tester.widget<ListWheelScrollView>(
    find.descendant(
      of: find.byType(TdsWheel),
      matching: find.byType(ListWheelScrollView),
    ),
  );
  (view.controller! as FixedExtentScrollController).jumpToItem(quantity - 1);
  await tester.pumpAndSettle();
}

Future<void> selectQuantity(WidgetTester tester, int quantity) async {
  await openQuantityPicker(tester);
  await scrollQuantityWheel(tester, quantity);
  await tester.tap(find.widgetWithText(TdsButton, '적용'));
  await tester.pumpAndSettle();
}
