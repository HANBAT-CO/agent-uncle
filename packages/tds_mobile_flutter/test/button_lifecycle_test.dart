import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'interaction_test.dart' show app;

// Source: @toss/tds-mobile@2.5.1 Button variants and AnimatePresence.
// The original-browser button-lifecycle fixture verifies these contracts.
double labelOpacity(WidgetTester tester) {
  RenderObject? node = tester.renderObject(find.text('확인'));
  while (node != null) {
    if (node is RenderAnimatedOpacity) return node.opacity.value;
    if (node is RenderOpacity) return node.opacity;
    node = node.parent;
  }
  throw StateError('No label opacity');
}

Finder get glow => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).gradient is RadialGradient,
);

double glowOpacity(WidgetTester tester) {
  RenderObject? node = tester.renderObject(glow);
  while (node != null) {
    if (node is RenderOpacity) return node.opacity;
    node = node.parent;
  }
  throw StateError('No glow opacity');
}

void main() {
  testWidgets('keyboard activation does not start pointer press visuals', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      app(
        TdsButton(focusNode: focus, onPressed: () {}, child: const Text('확인')),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      await tester.sendKeyDownEvent(key);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      final dimmer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).last,
      );
      expect((dimmer.decoration! as BoxDecoration).color!.a, 0);
      await tester.sendKeyUpEvent(key);
    }
    final touch = await tester.startGesture(tester.getCenter(find.text('확인')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .96);
    await touch.up();
    await tester.pumpAndSettle();
  });

  testWidgets('idle loading layers preserve custom child hit testing', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(
        TdsButton(
          child: GestureDetector(onTap: () => taps++, child: const Text('확인')),
        ),
      ),
    );
    await tester.tap(find.text('확인'));
    expect(taps, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Button Enter commits on keydown and Space on keyup', (
    tester,
  ) async {
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
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(calls, 2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(calls, 2);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    expect(calls, 2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(calls, 3);
  });

  for (final variant in TdsButtonVariant.values) {
    testWidgets('disabled loading $variant has no dimmer', (tester) async {
      for (final color in TdsButtonColor.values) {
        await tester.pumpWidget(
          app(
            TdsButton(
              loading: true,
              disabled: true,
              variant: variant,
              color: color,
              child: const Text('확인'),
            ),
          ),
        );
        await tester.pump(TdsMotion.quick.duration);
        final dimmer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).last,
        );
        expect(
          (dimmer.decoration! as BoxDecoration).color!.a,
          0,
          reason: color.name,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('loading dots retain their exit animation then dispose', (
    tester,
  ) async {
    Widget view(bool loading) =>
        app(TdsButton(loading: loading, child: const Text('확인')));
    await tester.pumpWidget(view(true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(view(false));
    expect(find.byType(TdsButtonLoader), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TdsButtonLoader), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(TdsButtonLoader), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('loading glow fades from its current value when stopped', (
    tester,
  ) async {
    Widget view(bool loading) =>
        app(TdsButton(loading: loading, child: const Text('확인')));
    await tester.pumpWidget(view(true));
    await tester.pump(const Duration(milliseconds: 300));
    final before = glowOpacity(tester);
    expect(before, greaterThan(0));
    await tester.pumpWidget(view(false));
    expect(glow, findsOneWidget);
    expect(glowOpacity(tester), closeTo(before, .0001));
    await tester.pump(const Duration(milliseconds: 50));
    expect(glowOpacity(tester), allOf(greaterThan(0), lessThan(before)));
    await tester.pumpAndSettle();
    expect(glowOpacity(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('label waits 100ms before returning after loading', (
    tester,
  ) async {
    Widget view(bool loading) =>
        app(TdsButton(loading: loading, child: const Text('확인')));
    await tester.pumpWidget(view(true));
    expect(labelOpacity(tester), 0);
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(milliseconds: 99));
    expect(labelOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(labelOpacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(labelOpacity(tester), 1);
  });

  testWidgets(
    'reentering loading cancels label delay and retained-dot removal',
    (tester) async {
      Widget view(bool loading) =>
          app(TdsButton(loading: loading, child: const Text('확인')));
      await tester.pumpWidget(view(true));
      final original = tester.state(find.byType(TdsButtonLoader));
      await tester.pumpWidget(view(false));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(view(true));
      expect(tester.state(find.byType(TdsButtonLoader)), same(original));
      await tester.pump(const Duration(seconds: 1));
      expect(labelOpacity(tester), 0);
      expect(find.byType(TdsButtonLoader), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('disposing during the label delay cancels pending work', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const TdsButton(loading: true, child: Text('확인'))),
    );
    await tester.pumpWidget(app(const TdsButton(child: Text('확인'))));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'disabling during the label delay uses the disabled target immediately',
    (tester) async {
      Widget view({bool loading = false, bool disabled = false}) => app(
        TdsButton(
          loading: loading,
          disabled: disabled,
          variant: TdsButtonVariant.weak,
          child: const Text('확인'),
        ),
      );
      await tester.pumpWidget(view(loading: true));
      await tester.pumpWidget(view());
      await tester.pump(const Duration(milliseconds: 50));
      expect(labelOpacity(tester), 0);
      await tester.pumpWidget(view(disabled: true));
      await tester.pump(const Duration(milliseconds: 20));
      expect(labelOpacity(tester), greaterThan(0));
      await tester.pumpAndSettle();
      expect(labelOpacity(tester), closeTo(.3, .0001));
    },
  );
}
