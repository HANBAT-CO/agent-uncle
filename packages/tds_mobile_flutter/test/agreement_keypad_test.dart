import 'dart:ui' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('Keypad uses fixed 30px text and 66px rows even at 200 percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        TdsNumberKeypad(onKeyClick: (_) {}, onBackspaceClick: () {}),
        scale: 200,
      ),
    );
    expect(tester.widget<Text>(find.text('1')).style!.fontSize, 30);
    expect(tester.getSize(find.byType(TdsNumberKeypad)).height, 264);
    expect(
      tester.getCenter(find.text('4')).dy - tester.getCenter(find.text('1')).dy,
      66,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Keypad commits on down without duplicate release, cancel, keyboard or semantics',
    (tester) async {
      final values = <String>[];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          TdsNumberKeypad(onKeyClick: values.add, onBackspaceClick: () {}),
        ),
      );
      final one = find.bySemanticsLabel('1');
      final press = await tester.startGesture(tester.getCenter(one));
      expect(values, ['1']);
      await press.up();
      expect(values, ['1']);
      final cancel = await tester.startGesture(tester.getCenter(one));
      expect(values, ['1', '1']);
      await cancel.cancel();
      await tester.pumpAndSettle();
      expect(values.length, 2);
      Focus.of(tester.element(find.text('1'))).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(values.length, 3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(values.length, 3);
      final node = tester.getSemantics(one);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(values.length, 4);
      semantics.dispose();
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Agreement checkbox updates both native state and pushable indent',
    (tester) async {
      bool? checked;
      await tester.pumpWidget(
        testApp(
          TdsAgreementIndentPushable(
            child: Column(
              children: [
                TdsAgreementIndentPushableTrigger(
                  child: TdsAgreementCheckbox(
                    semanticLabel: '동의',
                    onCheckedChange: (v) => checked = v,
                  ),
                ),
                const TdsAgreementIndentPushableContent(
                  child: TdsAgreementV4(
                    variant: TdsAgreementVariant.medium,
                    middle: TdsAgreementText('약관'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final before = tester.getTopLeft(find.text('약관')).dx;
      await tester.tap(find.bySemanticsLabel('동의'));
      await tester.pumpAndSettle();
      expect(checked, true);
      expect(tester.getTopLeft(find.text('약관')).dx, before + 24);
    },
  );
  testWidgets(
    'Agreement collapsed content is inaccessible and arrow toggles it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          const TdsAgreementCollapsible(
            defaultCollapsed: true,
            child: Column(
              children: [
                TdsAgreementCollapsibleTrigger(child: TdsAgreementRightArrow()),
                TdsAgreementCollapsibleContent(child: Text('숨은 약관')),
              ],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('숨은 약관'), findsNothing);
      await tester.tap(find.bySemanticsLabel('펼치기'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('숨은 약관'), findsOneWidget);
      semantics.dispose();
    },
  );
  testWidgets(
    'V3 controlled checkbox notifies but never changes supplied value',
    (tester) async {
      bool? changed;
      await tester.pumpWidget(
        testApp(
          TdsAgreementV3SingleCheckboxField(
            '항목',
            type: TdsAgreementV3Size.medium,
            checked: false,
            onCheckedChange: (v) => changed = v,
          ),
        ),
      );
      await tester.tap(find.text('항목'));
      await tester.pump();
      expect(changed, true);
      expect(
        tester.widget<TdsCheckbox>(find.byType(TdsCheckbox)).checked,
        false,
      );
    },
  );
  testWidgets(
    'Agreement module delays step transition and disables approval while pending',
    (tester) async {
      var approved = 0;
      Widget app(TdsAgreementStep step) => testApp(
        TdsAgreementModuleProvider(
          options: TdsAgreementModuleOptions(step: step),
          child: Column(
            children: [
              const TdsAgreementModuleContent(
                requiredContent: Text('필수'),
                optionalContent: Text('선택'),
              ),
              TdsAgreementModuleCTA(onApproveButtonClick: (_) => approved++),
            ],
          ),
        ),
      );
      await tester.pumpWidget(app(TdsAgreementStep.required));
      await tester.pumpWidget(app(TdsAgreementStep.optional));
      expect(
        tester.widget<TdsButton>(find.byType(TdsButton).first).disabled,
        true,
      );
      expect(find.text('필수'), findsOneWidget);
      await tester.tap(find.text('필수 동의하기'));
      expect(approved, 0);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('선택'), findsOneWidget);
      expect(find.text('필수'), findsNothing);
      await tester.tap(find.text('모두 동의'));
      expect(approved, 1);
      await tester.pumpWidget(app(TdsAgreementStep.required));
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Optional agreement completed title requires prior approval and more than one term',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsAgreementModuleProvider(
            options: TdsAgreementModuleOptions(
              step: TdsAgreementStep.optional,
              totalOptionalTermCount: 2,
              agreedOptionalTermCount: 2,
              hasAgreedOptionalOnce: true,
            ),
            child: TdsAgreementModuleTop(optionalTitle: '선택 안내'),
          ),
        ),
      );
      expect(find.text('선택 동의에\n모두 동의했어요'), findsOneWidget);
    },
  );
  testWidgets(
    'Number keypad routes special, digit and backspace callbacks once',
    (tester) async {
      final values = <String>[];
      var backs = 0;
      await tester.pumpWidget(
        testApp(
          TdsNumberKeypad(
            onKeyClick: values.add,
            onBackspaceClick: () => backs++,
            specialKey: '.',
            onSpecialKeyClick: values.add,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('1'));
      await tester.tap(find.bySemanticsLabel('마침표'));
      await tester.tap(find.bySemanticsLabel('지우기'));
      expect(values, ['1', '.']);
      expect(backs, 1);
    },
  );
  testWidgets(
    'Full keypad supports shift, symbols, spaces, blank reorder and disabled submit',
    (tester) async {
      final controller = TdsSecureKeypadController();
      final values = <String>[];
      var submits = 0;
      await tester.pumpWidget(
        testApp(
          TdsFullSecureKeypad(
            controller: controller,
            onKeyClick: values.add,
            onBackspaceClick: () {},
            onSpaceClick: () => values.add(' '),
            onSubmit: () => submits++,
            submitDisabled: true,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('q'));
      await tester.tap(find.bySemanticsLabel('shift'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Q'));
      await tester.tap(find.bySemanticsLabel('특수로 전환'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('!'));
      await tester.tap(find.bySemanticsLabel('space'));
      await tester.tap(find.bySemanticsLabel('입력 완료'));
      expect(values, ['q', 'Q', '!', ' ']);
      expect(submits, 0);
      controller.reorderEmptyCells();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.reorderEmptyCells();
      controller.dispose();
    },
  );
}
