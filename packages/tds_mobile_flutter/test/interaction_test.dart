import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Widget app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: TdsMobileProvider(child: Center(child: child)),
  ),
);

void main() {
  testWidgets('CTA disabled wiggle follows all four 87.5ms linear keyframes', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const TdsCTAButton(disabled: true, child: Text('확인'))),
    );
    final target = find.byType(TdsButton);
    final x = tester.getTopLeft(target).dx;
    await tester.tap(target);
    await tester.pump();
    for (final dx in [2.0, -2.0, 1.0, 0.0]) {
      await tester.pump(const Duration(microseconds: 87500));
      expect(tester.getTopLeft(target).dx, closeTo(x + dx, .0001));
    }
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'plain button text keeps fractional CSS line height when scaled',
    (tester) async {
      await tester.pumpWidget(
        app(
          const TdsTheme(
            data: TdsThemeData(
              platform: TdsPlatform(os: TdsOS.android, fontScale: 160),
            ),
            child: TdsButton(child: Text('확인')),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(TdsButton)).height,
        closeTo(30 + 27 * 1.252, .0001),
      );
    },
  );

  testWidgets(
    'button handles pointer and keyboard but blocks loading, disabled and inert activation',
    (tester) async {
      var calls = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        app(
          TdsButton(
            focusNode: focus,
            onPressed: () => calls++,
            child: const Text('확인'),
          ),
        ),
      );
      await tester.tap(find.text('확인'));
      expect(calls, 1);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, 3);
      for (final state in ['disabled', 'loading', 'inert']) {
        await tester.pumpWidget(
          app(
            TdsButton(
              disabled: state == 'disabled',
              loading: state == 'loading',
              inert: state == 'inert',
              onPressed: () => calls++,
              child: const Text('확인'),
            ),
          ),
        );
        await tester.tap(find.byType(TdsButton));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(calls, 3, reason: state);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'checkbox supports controlled and uncontrolled values and selected radio cannot toggle off',
    (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        app(TdsCheckbox(onChanged: changes.add, semanticLabel: '동의')),
      );
      await tester.tap(find.byType(TdsCheckbox));
      await tester.pumpAndSettle();
      expect(changes, [true]);
      await tester.tap(find.byType(TdsCheckbox));
      await tester.pumpAndSettle();
      expect(changes, [true, false]);
      await tester.pumpWidget(
        app(TdsCheckbox(checked: false, onChanged: changes.add)),
      );
      await tester.tap(find.byType(TdsCheckbox));
      await tester.tap(find.byType(TdsCheckbox));
      expect(changes, [true, false, true, true]);
      await tester.pumpWidget(
        app(
          TdsCheckbox(
            checked: true,
            inputType: TdsCheckboxInputType.radio,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.byType(TdsCheckbox));
      expect(changes.length, 4);
      await tester.pumpWidget(
        app(
          TdsCheckbox(checked: false, disabled: true, onChanged: changes.add),
        ),
      );
      await tester.tap(find.byType(TdsCheckbox));
      expect(changes.length, 4);
    },
  );

  testWidgets('switch reports state and requires controlled value updates', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final values = <bool>[];
    await tester.pumpWidget(
      app(
        TdsSwitch(checked: false, semanticLabel: '알림', onChanged: values.add),
      ),
    );
    expect(tester.getSize(find.byType(TdsSwitch)), const Size(50, 30));
    await tester.tap(find.byType(TdsSwitch));
    await tester.pumpAndSettle();
    expect(values, [true]);
    expect(
      tester.getSemantics(find.bySemanticsLabel('알림')),
      matchesSemantics(
        label: '알림',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });
}
