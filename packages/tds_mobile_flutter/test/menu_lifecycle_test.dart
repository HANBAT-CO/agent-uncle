import 'dart:ui' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/pressable.dart';
import 'collections_feedback_test.dart' show testApp;

Finder dismissControl() => find.byWidgetPredicate(
  (w) => w is TdsPressable && w.semanticLabel == '메뉴 닫기',
);
Finder motion() => find
    .ancestor(
      of: find.byKey(const Key('menu-body')),
      matching: find.byType(Transform),
    )
    .first;

Widget trigger({
  bool? open,
  bool defaultOpen = false,
  VoidCallback? onClose,
  VoidCallback? onOpen,
  Widget? child,
}) => TdsMenuTrigger(
  open: open,
  defaultOpen: defaultOpen,
  onClose: onClose,
  onOpen: onOpen,
  dropdown: const SizedBox(
    key: Key('menu-body'),
    width: 182,
    height: 100,
    child: Text('항목'),
  ),
  child: child ?? const SizedBox(width: 80, height: 30, child: Text('열기')),
);

void main() {
  testWidgets(
    'ListRow pointer and keydown retain child-first compound activation',
    (tester) async {
      for (final keyboard in [false, true]) {
        final events = <String>[];
        await tester.pumpWidget(
          testApp(
            trigger(
              onOpen: () => events.add('open'),
              child: TdsListRow(
                onPressed: () => events.add('child'),
                contents: const Text('행 메뉴'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (keyboard) {
          Focus.of(tester.element(find.text('행 메뉴'))).requestFocus();
          await tester.pump();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        } else {
          await tester.tap(find.text('행 메뉴'));
        }
        await tester.pumpAndSettle();
        expect(events, ['child', 'open']);
        await tester.pumpWidget(testApp(const SizedBox()));
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'open menu tracks ancestor paint-only translation without an idle frame loop',
    (tester) async {
      final offset = ValueNotifier(Offset.zero);
      await tester.pumpWidget(
        testApp(
          ValueListenableBuilder<Offset>(
            valueListenable: offset,
            child: trigger(defaultOpen: true),
            builder: (context, value, child) => Align(
              alignment: Alignment.topLeft,
              child: Transform.translate(offset: value, child: child),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = tester.getTopLeft(find.byKey(const Key('menu-body')));
      offset.value = const Offset(70, 90);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('menu-body'))),
        start + const Offset(70, 90),
      );
      expect(tester.binding.hasScheduledFrame, false);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      offset.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Enter opens on key down, without fading the scaled dropdown', (
    tester,
  ) async {
    var opens = 0;
    final focus = FocusNode();
    await tester.pumpWidget(
      testApp(
        trigger(
          onOpen: () => opens++,
          child: TdsButton(focusNode: focus, child: const Text('열기')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(opens, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Transform>(motion()).child, isA<SizedBox>());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, 1);
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pumpAndSettle();
    focus.dispose();
  });
  testWidgets(
    'nested TDS buttons bubble once after their callback and restore their focus',
    (tester) async {
      for (final kind in ['button', 'text', 'icon']) {
        final events = <String>[];
        final focus = FocusNode();
        void pressed() => events.add('child');
        final child = switch (kind) {
          'button' => TdsButton(
            focusNode: focus,
            onPressed: pressed,
            child: const Text('열기'),
          ),
          'text' => TdsTextButton(
            focusNode: focus,
            size: TdsTextButtonSize.medium,
            onPressed: pressed,
            child: const Text('열기'),
          ),
          _ => TdsIconButton(
            focusNode: focus,
            semanticLabel: '열기',
            onPressed: pressed,
            child: const Text('열기'),
          ),
        };
        await tester.pumpWidget(
          testApp(trigger(child: child, onOpen: () => events.add('open'))),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(events, ['child', 'open'], reason: kind);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(focus.hasPrimaryFocus, true, reason: kind);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(events, ['child', 'open', 'child', 'open'], reason: kind);
        await tester.pumpWidget(testApp(const SizedBox()));
        await tester.pumpAndSettle();
        focus.dispose();
      }
    },
  );
  testWidgets(
    'disabled child blocks fallback, null callback still opens, and dragging never opens',
    (tester) async {
      var opens = 0;
      Widget view(bool disabled) => testApp(
        trigger(
          onOpen: () => opens++,
          child: TdsButton(disabled: disabled, child: const Text('열기')),
        ),
      );
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(opens, 0);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      await tester.drag(find.text('열기'), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(opens, 0);
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(find.text('항목'), findsOneWidget);
    },
  );
  testWidgets(
    'nested activation is available through semantics, without duplicate traversal stops',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var calls = 0, opens = 0;
      final focus = FocusNode();
      await tester.pumpWidget(
        testApp(
          trigger(
            onOpen: () => opens++,
            child: TdsButton(
              focusNode: focus,
              onPressed: () => calls++,
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final outer = tester
          .widgetList<TdsPressable>(find.byType(TdsPressable))
          .first;
      expect(outer.skipTraversal, true);
      final node = tester.getSemantics(find.text('열기'));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: node.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(opens, 1);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      focus.dispose();
      semantics.dispose();
    },
  );
  testWidgets(
    'trigger uses zero gap, alignment flip and zero viewport padding',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final record in [
        (0.0, 24.0, TextDirection.ltr, const Offset(0, 54)),
        (300.0, 24.0, TextDirection.ltr, const Offset(198, 54)),
        (24.0, 550.0, TextDirection.ltr, const Offset(24, 450)),
        (200.0, 24.0, TextDirection.rtl, const Offset(98, 54)),
      ]) {
        await tester.pumpWidget(
          testApp(
            Directionality(
              textDirection: record.$3,
              child: SizedBox(
                height: 600,
                child: Stack(
                  children: [
                    Positioned(
                      left: record.$1,
                      top: record.$2,
                      child: trigger(defaultOpen: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('menu-body'))),
          offsetMoreOrLessEquals(record.$4),
        );
        await tester.pumpWidget(testApp(const SizedBox()));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'menu enters from scale zero, retains exit and reverses without a new surface',
    (tester) async {
      Widget view(bool open) => testApp(trigger(open: open));
      await tester.pumpWidget(view(true));
      await tester.pump();
      double scale() => tester.widget<Transform>(motion()).transform.storage[0];
      expect(scale(), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(scale(), greaterThan(0));
      expect(scale(), lessThan(1));
      await tester.pumpAndSettle();
      expect(scale(), 1);
      await tester.pumpWidget(view(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('항목'), findsOneWidget);
      expect(scale(), lessThan(1));
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      expect(scale(), 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(find.text('항목'), findsNothing);
    },
  );

  testWidgets(
    'initial focus is labelled close control, with Tab cycling and Escape return',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          TdsMenuTrigger(
            dropdown: TdsMenuDropdown(
              children: [
                TdsMenuDropdownItem(
                  onPressed: () {},
                  child: const Text('첫 항목'),
                ),
                TdsMenuDropdownItem(
                  onPressed: () {},
                  child: const Text('둘째 항목'),
                ),
              ],
            ),
            child: const Text('열기'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final close = tester.widget<TdsPressable>(dismissControl()).focusNode!;
      expect(close.hasPrimaryFocus, true);
      expect(find.bySemanticsLabel('메뉴 닫기'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('첫 항목'))).hasPrimaryFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        Focus.of(tester.element(find.text('둘째 항목'))).hasPrimaryFocus,
        true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(close.hasPrimaryFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('첫 항목'), findsNothing);
      expect(Focus.of(tester.element(find.text('열기'))).hasPrimaryFocus, true);
      semantics.dispose();
    },
  );

  testWidgets(
    'backdrop closes on click, not pointer down, matching original fixed close control',
    (tester) async {
      var closes = 0;
      await tester.pumpWidget(
        testApp(trigger(defaultOpen: true, onClose: () => closes++)),
      );
      await tester.pumpAndSettle();
      final down = await tester.startGesture(const Offset(20, 400));
      expect(closes, 0);
      await down.up();
      expect(closes, 1);
      await tester.pumpAndSettle();
      expect(find.text('항목'), findsNothing);
    },
  );

  testWidgets(
    'controlled close request keeps focus and state until owner accepts',
    (tester) async {
      var closes = 0;
      Widget view(bool open) =>
          testApp(trigger(open: open, onClose: () => closes++));
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      final close = tester.widget<TdsPressable>(dismissControl()).focusNode!;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(find.text('항목'), findsOneWidget);
      expect(close.hasPrimaryFocus, true);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(find.text('항목'), findsNothing);
      expect(Focus.of(tester.element(find.text('열기'))).hasPrimaryFocus, true);
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(view(false));
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
