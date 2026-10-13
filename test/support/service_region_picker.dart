import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Future<void> openRegionPicker(WidgetTester tester, String field) async {
  final selector = find.byKey(ValueKey('$field-selector'));
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
}

Future<void> tapRegionChoice(WidgetTester tester, String label) async {
  final choice = find.widgetWithText(TdsChipItem, label);
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

Future<void> completeRegionSelection(WidgetTester tester) async {
  final done = find.ancestor(
    of: find.textContaining(RegExp(r'^선택 완료')),
    matching: find.byType(TdsButton),
  );
  await tester.tap(done);
  await tester.pumpAndSettle();
}

Future<void> selectRegion(
  WidgetTester tester,
  String field,
  String region, {
  String? city,
  String? district,
  bool replace = false,
}) async {
  await openRegionPicker(tester, field);
  if (replace) {
    final existing = tester
        .widgetList<TdsListRow>(
          find.byWidgetPredicate(
            (widget) =>
                widget is TdsListRow &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'selected-region-',
                ),
          ),
        )
        .map((widget) => widget.key!)
        .toList();
    for (final key in existing) {
      final remove = find.descendant(
        of: find.byKey(key),
        matching: find.byType(TdsTextButton),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
    }
  }
  await tapRegionChoice(tester, region);
  if (city != null) await tapRegionChoice(tester, city);
  if (district != null) {
    await tapRegionChoice(tester, district);
  } else if (city == null) {
    await tapRegionChoice(tester, '$region 전체');
  }
  await completeRegionSelection(tester);
}
