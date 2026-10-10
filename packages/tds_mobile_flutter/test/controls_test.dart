import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'interaction_test.dart' show app;

void main() {
  testWidgets(
    'standalone text button keeps flow size without invented hit padding',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => calls++,
            child: const Text('내용'),
          ),
        ),
      );
      final text = tester.getRect(find.text('내용'));
      final button = tester.getRect(find.byType(TdsTextButton));
      expect(button.width, text.width);
      expect(button.height, closeTo((17 * 1.252 * 64).floor() / 64, .0001));
      await tester.tapAt(text.centerLeft - const Offset(3, 0));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('내용'));
      expect(calls, 1);
      await tester.pumpWidget(
        app(
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            disabled: true,
            onPressed: () => calls++,
            child: const Text('내용'),
          ),
        ),
      );
      await tester.tap(find.text('내용'));
      expect(calls, 1);
    },
  );
  testWidgets('icon button size rules, keyboard and disabled state', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var calls = 0;
    for (final size in [16.0, 18.0, 20.0, 24.0, 32.0]) {
      await tester.pumpWidget(
        app(
          TdsIconButton(
            semanticLabel: '닫기',
            iconSize: size,
            focusNode: focus,
            onPressed: () => calls++,
            child: SizedBox.square(dimension: size),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final padding = size >= 18 && size <= 20 ? 9 : size / 2;
      expect(
        tester.getSize(find.byType(TdsIconButton)).width,
        size + 2 * padding,
      );
    }
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.pumpWidget(
      app(
        TdsIconButton(
          semanticLabel: '닫기',
          disabled: true,
          onPressed: () => calls++,
          child: const SizedBox.square(dimension: 24),
        ),
      ),
    );
    await tester.tap(find.byType(TdsIconButton));
    expect(calls, 1);
  });
  testWidgets('spinner tap, accelerating hold, bounds and disposal', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      app(
        TdsNumericSpinner(
          size: TdsNumericSpinnerSize.medium,
          defaultNumber: 0,
          maxNumber: 3,
          onNumberChange: changes.add,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('더하기'));
    await tester.pump();
    expect(changes, [1]);
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('더하기')),
    );
    await tester.pump(
      const Duration(milliseconds: 110),
    ); // GestureDetector's tap-down delay
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 320));
    await gesture.up();
    await tester.pump();
    expect(changes, [1, 2, 3]);
    await tester.tap(find.bySemanticsLabel('더하기'));
    await tester.pumpAndSettle();
    expect(changes.last, 3);
    final held = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('빼기')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await held.up();
    expect(tester.takeException(), isNull);
  });
  testWidgets('spinner controlled value and drag do not mutate caller state', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      app(
        TdsNumericSpinner(
          size: TdsNumericSpinnerSize.small,
          number: 5,
          onNumberChange: changes.add,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('더하기'));
    await tester.pumpAndSettle();
    expect(changes, [6]);
    expect(find.text('5'), findsOneWidget);
    await tester.drag(find.text('5'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(changes.last, 4);
    expect(find.text('5'), findsOneWidget);
  });
  testWidgets('progress tracks original heights and accessible value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final size in TdsProgressBarSize.values) {
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 200,
            child: TdsProgressBar(
              progress: .4,
              size: size,
              semanticLabel: '진행',
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TdsProgressBar)).height, size.height);
      expect(tester.getSemantics(find.bySemanticsLabel('진행')).value, '40%');
    }
    semantics.dispose();
  });
  test(
    'all original named asset shapes are represented without invented dimensions',
    () {
      expect(TdsAssetFrames.values.length, 44);
      expect(TdsAssetFrames.circleXSmall.accessoryOffset, const Offset(-2, -2));
      expect(
        TdsAssetFrames.squareLarge.width,
        40,
      ); // Do not normalize this source value.
      expect(TdsAssetFrames.cleanW24.height, isNull);
      expect(TdsAssetFrames.cleanWFull.width, double.infinity);
    },
  );
}
