import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'collections_feedback_test.dart' show testApp;

Widget menu({Widget? child, VoidCallback? onOpen}) => TdsMenuTrigger(
  openOnLongPress: true,
  onOpen: onOpen,
  dropdown: const TdsMenuDropdown(
    children: [TdsMenuDropdownItem(child: Text('메시지 수정'))],
  ),
  child: child ?? const SizedBox(width: 100, height: 60, child: Text('메시지')),
);

void main() {
  testWidgets('탭은 열지 않고 길게 누르면 한 번 열린다', (tester) async {
    var opens = 0;
    await tester.pumpWidget(testApp(menu(onOpen: () => opens++)));
    await tester.tap(find.text('메시지'));
    await tester.pumpAndSettle();
    expect(find.text('메시지 수정'), findsNothing);
    await tester.longPress(find.text('메시지'));
    await tester.pumpAndSettle();
    expect(find.text('메시지 수정'), findsOneWidget);
    expect(opens, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('메시지 수정'), findsNothing);
  });

  testWidgets('스크롤은 길게 누르기를 취소한다', (tester) async {
    await tester.pumpWidget(
      testApp(
        SizedBox(
          height: 180,
          child: ListView(children: [menu(), const SizedBox(height: 1000)]),
        ),
      ),
    );
    await tester.drag(find.text('메시지'), const Offset(0, -100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('메시지 수정'), findsNothing);
  });

  testWidgets('자식 버튼 탭과 문맥 메뉴 길게 누르기를 구분한다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        menu(
          child: TdsButton(onPressed: () => taps++, child: const Text('사진')),
        ),
      ),
    );
    await tester.tap(find.text('사진'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('메시지 수정'), findsNothing);
    await tester.longPress(find.text('사진'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('메시지 수정'), findsOneWidget);
  });

  testWidgets('키보드와 접근성에서도 메뉴를 열 수 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(testApp(menu()));
    final node = tester.getSemantics(find.text('메시지'));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    Focus.of(tester.element(find.text('메시지'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('메시지 수정'), findsOneWidget);
    semantics.dispose();
  });
}
