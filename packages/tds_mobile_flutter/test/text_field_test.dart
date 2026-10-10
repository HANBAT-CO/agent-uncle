import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Widget fieldApp(Widget child) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, navigator) => TdsMobileProvider(child: navigator!),
  home: Center(child: child),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (c, a, s) => builder(c),
  ),
);

void main() {
  test('format functions retain source edge cases and decimal digits', () {
    expect(
      TdsTextFieldFormat.phoneNumber.transform('01012345678'),
      '010-1234-5678',
    );
    expect(
      TdsTextFieldFormat.phoneNumber.transform('0212345678'),
      '02-1234-5678',
    );
    expect(
      TdsTextFieldFormat.phoneNumber.transform('021234567'),
      '02-123-4567',
    );
    expect(TdsTextFieldFormat.phoneNumber.reset!('010-12ab'), '01012');
    expect(
      TdsTextFieldFormat.price.transform('-1234567.1234'),
      '-1,234,567.1234',
    );
    expect(TdsTextFieldFormat.price.reset!('1,234.56'), '1234.56');
  });
  testWidgets(
    'raw controlled value, displayed format, disabled editing and controller ownership',
    (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        fieldApp(
          TdsTextField(
            variant: TdsTextFieldVariant.box,
            value: '1234',
            format: TdsTextFieldFormat.price,
            onChanged: changes.add,
          ),
        ),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '1,234',
      );
      await tester.enterText(find.byType(EditableText), '9999');
      await tester.pump();
      expect(changes, ['9999']);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '1,234',
      );
      final controller = TextEditingController(text: 'initial');
      await tester.pumpWidget(
        fieldApp(
          TdsTextField(
            variant: TdsTextFieldVariant.line,
            controller: controller,
            disabled: true,
          ),
        ),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      controller.text = 'still owned by caller';
      expect(controller.text, 'still owned by caller');
      controller.dispose();
    },
  );
  testWidgets(
    'clear button emits change before clear callback, password visibility retains value',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        fieldApp(
          TdsTextFieldClearable(
            variant: TdsTextFieldVariant.box,
            defaultValue: 'text',
            label: '이름',
            onChanged: (v) => events.add('change:$v'),
            onClear: () => events.add('clear'),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('이름 값 지우기'));
      await tester.pump();
      expect(events, ['change:', 'clear']);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
      await tester.pumpWidget(
        fieldApp(
          TdsTextFieldPassword(
            variant: TdsTextFieldVariant.box,
            key: const ValueKey('password'),
            defaultValue: 'secret',
            onVisibilityChange: (v) => events.add('visible:$v'),
          ),
        ),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('비밀번호 표시'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'secret',
      );
      expect(events.last, 'visible:true');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets('formatter does not destroy Korean composing regions', (
    tester,
  ) async {
    final changes = <String>[];
    await tester.pumpWidget(
      fieldApp(
        TdsTextField(
          variant: TdsTextFieldVariant.box,
          value: '',
          format: TdsTextFieldFormat.price,
          onChanged: changes.add,
        ),
      ),
    );
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    final editor = tester.widget<EditableText>(find.byType(EditableText));
    expect(editor.controller.text, '한');
    expect(
      editor.controller.value.composing,
      const TextRange(start: 0, end: 1),
    );
    expect(changes, isEmpty);
  });
}
