import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('Tooltip flips near the viewport edge and dismisses outside', (
    tester,
  ) async {
    bool? changed;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        Align(
          alignment: Alignment.topLeft,
          child: TdsTooltip(
            defaultOpen: true,
            placement: TdsOverlayPlacement.top,
            autoFlip: true,
            dismissible: true,
            onOpenChange: (v) => changed = v,
            message: const Text('설명'),
            child: const SizedBox(width: 100, height: 40, child: Text('대상')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('설명'), findsOneWidget);
    expect(tester.getTopLeft(find.text('설명')).dy, greaterThan(40));
    await tester.tapAt(const Offset(500, 450));
    await tester.pumpAndSettle();
    expect(changed, false);
    expect(find.text('설명'), findsNothing);
    semantics.dispose();
  });
  testWidgets(
    'Menu opens, check item toggles and Escape restores trigger focus',
    (tester) async {
      bool? checked;
      await tester.pumpWidget(
        testApp(
          TdsMenuTrigger(
            dropdown: TdsMenuDropdown(
              children: [
                TdsMenuDropdownCheckItem(
                  onCheckedChange: (v) => checked = v,
                  child: const Text('항목'),
                ),
              ],
            ),
            child: const Text('메뉴 열기'),
          ),
        ),
      );
      await tester.tap(find.text('메뉴 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('항목'));
      await tester.pump();
      expect(checked, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('항목'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('FullTooltip auto close cancels on unmount', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      testApp(
        TdsFullTooltip(
          duration: const Duration(milliseconds: 100),
          onClose: () => closed++,
          message: const Text('안내'),
          child: const Text('기준'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    // Original Sat overrides the user's callback in uncontrolled mode.
    expect(closed, 0);
    expect(find.text('안내'), findsNothing);
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pump(const Duration(seconds: 3));
    expect(closed, 0);
  });
  testWidgets(
    'Highlight keeps the visual target inert and backdrop dismissible',
    (tester) async {
      var target = 0, closed = 0;
      await tester.pumpWidget(
        testApp(
          Center(
            child: TdsHighlight(
              open: true,
              onClose: () => closed++,
              message: const Text('안내'),
              child: GestureDetector(
                onTap: () => target++,
                child: const SizedBox(
                  width: 100,
                  height: 40,
                  child: Text('대상'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('대상')));
      expect(target, 0);
      await tester.tapAt(const Offset(10, 10));
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('PointToast times out and removes overlay after exit', (
    tester,
  ) async {
    var closed = 0, exited = 0;
    Widget app(bool open) => testApp(
      TdsPointToast(
        open: open,
        text: '10 포인트',
        duration: const Duration(seconds: 1),
        onClose: () => closed++,
        onExited: () => exited++,
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(closed, 1);
    expect(find.text('10 포인트'), findsOneWidget);
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(exited, 1);
    expect(find.text('10 포인트'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Overlay replacement invalidates previous close callback', (
    tester,
  ) async {
    final controller = TdsOverlayController();
    VoidCallback? stale;
    await tester.pumpWidget(
      testApp(
        TdsOverlayProvider(controller: controller, child: const Text('페이지')),
      ),
    );
    controller.open((_, _, close, _) {
      stale = close;
      return const Text('first');
    });
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    controller.open((_, _, _, _) => const Text('second'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    stale!();
    await tester.pump();
    expect(controller.isOpen, true);
    controller.close();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
    await tester.pumpWidget(testApp(const SizedBox()));
    controller.dispose();
  });
  testWidgets('WikiText description opens and closes via native dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(const TdsWikiText('정의', description: Text('추가 설명'))),
    );
    await tester.pumpAndSettle(); // Wait for the initial viewport observation.
    await tester.tap(find.byType(TdsWikiText));
    await tester.pumpAndSettle();
    expect(find.text('추가 설명'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('추가 설명'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'Source paragraph variable names and touch inset maps are preserved',
    () {
      expect(
        assignTextVariables(TdsTypography.t5)['--tds-paragraph-text-font-size'],
        'var(--tds-t-t5-text-fontSize)',
      );
      expect(assignBadgeVariables(TdsTypography.t7).length, 3);
      expect(
        mapByTypeAndTypography['level5']![TdsTextButtonVariant.arrow]!.insets,
        const EdgeInsets.fromLTRB(15, 9, 6, 9),
      );
    },
  );
}
