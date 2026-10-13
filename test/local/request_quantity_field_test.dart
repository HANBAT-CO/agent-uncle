import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/request_quantity_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../support/request_quantity_picker.dart';
import 'brand_surfaces_test.dart' show branded;

void main() {
  testWidgets('수량 휠은 1~50개를 선택하며 취소는 원래 값을 유지한다', (tester) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    var changes = 0;
    await tester.pumpWidget(
      branded(
        StatefulBuilder(
          builder: (context, setState) => PageFrame(
            title: '수량',
            children: [
              RequestQuantityField(
                controller: controller,
                directInput: false,
                onDirectInputChanged: (_) {},
                onChanged: () => setState(() => changes++),
              ),
            ],
          ),
        ),
      ),
    );
    await openQuantityPicker(tester);
    final wheel = tester.widget<TdsWheel>(find.byType(TdsWheel));
    expect(wheel.options, List.generate(50, (i) => i + 1));
    expect(wheel.loop, isFalse);
    await scrollQuantityWheel(tester, 50);
    expect(controller.text, '1');
    await tester.tap(find.widgetWithText(TdsButton, '취소'));
    await tester.pumpAndSettle();
    expect(controller.text, '1');
    expect(changes, 0);
    await selectQuantity(tester, 50);
    expect(controller.text, '50');
    expect(changes, 1);
    await openQuantityPicker(tester);
    expect(tester.widget<TdsWheel>(find.byType(TdsWheel)).initialIndex, 49);
    await scrollQuantityWheel(tester, 1);
    await tester.tap(find.widgetWithText(TdsButton, '적용'));
    await tester.pumpAndSettle();
    expect(controller.text, '1');
    expect(changes, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('직접 입력은 숫자만 남기고 모드를 전환해도 각 수량을 유지한다', (tester) async {
    final controller = TextEditingController(text: '25');
    addTearDown(controller.dispose);
    var directInput = false;
    await tester.pumpWidget(
      branded(
        StatefulBuilder(
          builder: (context, setState) => PageFrame(
            title: '수량',
            children: [
              RequestQuantityField(
                controller: controller,
                directInput: directInput,
                onDirectInputChanged: (value) =>
                    setState(() => directInput = value),
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void> toggle() async {
      await tester.tap(find.widgetWithText(TdsCheckbox, '50개 초과 직접 입력'));
      await tester.pumpAndSettle();
    }

    await toggle();
    expect(quantityInput(), findsNothing);
    expect(controller.text, isEmpty);
    final input = find.descendant(
      of: find.byType(Field),
      matching: find.byType(EditableText),
    );
    await tester.enterText(input, '한글a1,2-3.개');
    await tester.pumpAndSettle();
    expect(controller.text, '123');
    await toggle();
    expect(controller.text, '25');
    expect(quantityInput(), findsOneWidget);
    await toggle();
    expect(controller.text, '123');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
