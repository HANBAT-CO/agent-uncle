import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/profile_time_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../support/profile_time_picker.dart';
import 'brand_surfaces_test.dart' show branded;

void main() {
  testWidgets('시간 휠은 입력 키보드를 닫고, 적용할 때만 저장하며 취소·재진입을 보존한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var value = '';
    final commits = <String>[];
    late StateSetter rebuild;
    await tester.pumpWidget(
      branded(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return PageFrame(
              title: '활동 구역',
              children: [
                Field('도매 픽업 구역', controller: controller),
                ProfileInputTheme(
                  child: ProfileTimeField(
                    label: '요청 마감시간',
                    value: value,
                    initialHour: 23,
                    onChanged: (next) => setState(() {
                      value = next;
                      commits.add(next);
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '동대문');
    expect(tester.testTextInput.isVisible, isTrue);
    await openTimePicker(tester, '요청 마감시간');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(commits, isEmpty);
    expect(find.text('선택 해제'), findsNothing);
    final hourWheel = find.byType(TdsWheel).first;
    final wheelView = tester.widget<ListWheelScrollView>(
      find.descendant(
        of: hourWheel,
        matching: find.byType(ListWheelScrollView),
      ),
    );
    await tester.drag(hourWheel, Offset(0, wheelView.itemExtent));
    await tester.pumpAndSettle();
    final scroll = wheelView.controller! as FixedExtentScrollController;
    expect(scroll.selectedItem, 22);
    expect(
      find.byType(TdsWheel),
      findsNWidgets(2),
      reason: '휠 드래그로 시트가 닫히지 않는다',
    );
    expect(commits, isEmpty);
    rebuild(() {});
    await tester.pumpAndSettle();
    expect(scroll.selectedItem, 22, reason: '자동 저장 등의 재빌드가 휠 위치를 되감지 않는다');
    await tester.tap(find.widgetWithText(TdsButton, '취소'));
    await tester.pumpAndSettle();
    expect(value, isEmpty);
    expect(controller.text, '동대문');
    expect(tester.testTextInput.isVisible, isFalse);

    await selectTime(tester, '요청 마감시간', '23:59');
    expect(value, '23:59');
    expect(commits, ['23:59']);
    await openTimePicker(tester, '요청 마감시간');
    final wheels = tester.widgetList<TdsWheel>(find.byType(TdsWheel)).toList();
    expect(wheels[0].initialIndex, 23);
    expect(wheels[1].initialIndex, 59);
    await scrollTimeWheel(tester, 0, 0);
    await scrollTimeWheel(tester, 1, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TdsWheel), findsNothing);
    expect(value, '23:59');
    await selectTime(tester, '요청 마감시간', '00:00');
    expect(value, '00:00');
    expect(commits, ['23:59', '00:00']);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('시간 선택은 $width 너비·큰 글자에서 적용·닫기·선택 해제가 가능하다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.reset);
      var value = '29:99';
      var saves = 0;
      await tester.pumpWidget(
        branded(
          StatefulBuilder(
            builder: (context, setState) => PageFrame(
              title: '활동 시간',
              children: [
                ProfileTimeField(
                  label: '활동 시작',
                  value: value,
                  initialHour: 22,
                  optional: true,
                  onChanged: (next) => setState(() {
                    value = next;
                    saves++;
                  }),
                ),
              ],
            ),
          ),
          scale: 180,
        ),
      );
      await openTimePicker(tester, '활동 시작 (선택)');
      expect(
        tester.widget<TdsWheel>(find.byType(TdsWheel).first).initialIndex,
        22,
      );
      await tester.tapAt(const Offset(8, 100));
      await tester.pumpAndSettle();
      expect(find.byType(TdsWheel), findsNothing);
      expect(saves, 0);
      await selectTime(tester, '활동 시작 (선택)', '22:05');
      expect(value, '22:05');
      await openTimePicker(tester, '활동 시작 (선택)');
      await tester.tap(find.widgetWithText(TdsTextButton, '선택 해제'));
      await tester.pumpAndSettle();
      expect(value, isEmpty);
      expect(saves, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
