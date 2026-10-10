import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'interaction_test.dart' show app;

class RecordingHaptic implements TdsHaptic {
  final calls = <TdsHapticType>[];
  @override
  Future<void> generate(TdsHapticType type) async => calls.add(type);
}

void main() {
  String svg(WidgetTester tester) =>
      (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
              as SvgStringLoader)
          .provideSvg(null);
  AnimatedScale scale(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale));

  testWidgets(
    'checkbox selection overshoots only on changes and returns at 150ms',
    (tester) async {
      Widget view(bool checked) => app(TdsCheckbox(checked: checked));
      await tester.pumpWidget(view(true));
      expect(scale(tester).scale, 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(view(true));
      expect(scale(tester).scale, 1.1);
      expect(scale(tester).duration, TdsMotion.quick.duration);
      await tester.pump(const Duration(milliseconds: 149));
      expect(scale(tester).scale, 1.1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(scale(tester).scale, 1);
      expect(scale(tester).duration, TdsMotion.bounce.duration);
      await tester.pumpAndSettle();
      await tester.pumpWidget(view(false));
      await tester.pumpWidget(view(true));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(view(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scale(tester).scale, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'checkbox has immediate pointer feedback, tick haptic and no radio shrink',
    (tester) async {
      final haptic = RecordingHaptic();
      Widget view({bool radio = false}) => app(
        TdsHostProvider(
          haptic: haptic,
          child: TdsCheckbox(
            checked: radio,
            inputType: radio
                ? TdsCheckboxInputType.radio
                : TdsCheckboxInputType.checkbox,
          ),
        ),
      );
      await tester.pumpWidget(view());
      var gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsCheckbox)),
      );
      expect(haptic.calls, [TdsHapticType.tickWeak]);
      await tester.pump(); // before GestureDetector's delayed tap-down
      expect(scale(tester).scale, .8);
      expect(scale(tester).curve, TdsMotion.rapid);
      await gesture.cancel();
      await tester.pump();
      expect(scale(tester).scale, 1);
      await tester.pumpWidget(view(radio: true));
      await tester.pumpAndSettle();
      gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsCheckbox)),
      );
      await tester.pump();
      expect(haptic.calls.length, 2);
      expect(scale(tester).scale, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'disabled checkbox wiggles icon only using quadratic keyframes, never toggles',
    (tester) async {
      final haptic = RecordingHaptic();
      var calls = 0;
      for (final variant in TdsCheckboxVariant.values) {
        await tester.pumpWidget(
          app(
            TdsHostProvider(
              haptic: haptic,
              child: TdsCheckbox(
                key: ValueKey(variant),
                variant: variant,
                disabled: true,
                onChanged: (_) => calls++,
                child: const Text('동의'),
              ),
            ),
          ),
        );
        final left = tester.getTopLeft(find.byType(SvgPicture)).dx;
        final label = tester.getRect(find.text('동의'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TdsCheckbox)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getTopLeft(find.byType(SvgPicture)).dx, left);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(microseconds: 21875));
        // Quarter of the first segment: 2 * (.25 * .25 * 2), not linear .5.
        expect(
          tester.getTopLeft(find.byType(SvgPicture)).dx,
          closeTo(left + .25, .00001),
        );
        await tester.pump(const Duration(microseconds: 65625));
        expect(
          tester.getTopLeft(find.byType(SvgPicture)).dx,
          closeTo(left + 2, .00001),
        );
        for (final value in [-2.0, 1.0, -1.0, 0.0]) {
          await tester.pump(const Duration(microseconds: 87500));
          expect(
            tester.getTopLeft(find.byType(SvgPicture)).dx,
            closeTo(left + value, .00001),
          );
        }
        expect(tester.getRect(find.text('동의')), label);
        expect(calls, 0);
        expect(haptic.calls, isEmpty);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'checkbox uses source disabled check color and gamma-mixed line fill',
    (tester) async {
      await tester.pumpWidget(app(const TdsCheckbox(disabled: true)));
      expect(svg(tester), contains('fill="#e5e8eb" d="M17.2'));
      await tester.pumpWidget(
        app(const TdsCheckbox.line(key: ValueKey('line'), checked: false)),
      );
      await tester.pumpWidget(
        app(const TdsCheckbox.line(key: ValueKey('line'), checked: true)),
      );
      const sample = Duration(milliseconds: 100);
      await tester.pump(sample);
      final t = TdsMotion.quick.transform(
        sample.inMicroseconds / TdsMotion.quick.duration.inMicroseconds,
      );
      final theme = TdsTheme.of(tester.element(find.byType(TdsCheckbox)));
      final a = theme.color('grey300'), b = theme.color('blue500');
      int channel(double x, double y) =>
          (math.sqrt(x * x + (y * y - x * x) * t) * 255).round();
      final expected = Color.fromARGB(
        255,
        channel(a.r, b.r),
        channel(a.g, b.g),
        channel(a.b, b.b),
      );
      expect(
        svg(tester),
        contains(expected.toARGB32().toRadixString(16).substring(2)),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'controlled checked callback uses optimistic setter ref; uncontrolled notifies after render',
    (tester) async {
      final events = <String>[];
      Widget view(bool controlled) => app(
        TdsCheckbox(
          key: ValueKey(controlled),
          checked: controlled ? false : null,
          onChanged: (v) => events.add('change:$v'),
          onCheckedChange: (v) => events.add('checked:$v'),
        ),
      );
      await tester.pumpWidget(view(true));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(TdsCheckbox));
      }
      expect(events, [
        'change:true',
        'checked:true',
        'change:true',
        'change:true',
        'checked:true',
      ]);
      await tester.pumpWidget(view(false));
      events.clear();
      await tester.tap(find.byType(TdsCheckbox));
      expect(events, ['change:true']);
      await tester.pump();
      expect(events, ['change:true', 'checked:true']);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'checkbox and switch labels focus without synthesized keyboard clicks',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var changes = 0;
      for (final control in [
        TdsCheckbox(focusNode: focus, onChanged: (_) => changes++),
        TdsSwitch(focusNode: focus, onChanged: (_) => changes++),
      ]) {
        await tester.pumpWidget(app(control));
        focus.requestFocus();
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(changes, 0);
      }
    },
  );

  testWidgets(
    'switch matches dormant root tap motion, knob geometry and callback order',
    (tester) async {
      final haptic = RecordingHaptic();
      final events = <String>[];
      Widget view(bool checked) => app(
        TdsHostProvider(
          haptic: haptic,
          child: TdsSwitch(
            checked: checked,
            onPressed: () => events.add('click'),
            onChanged: (v) => events.add('change:$v'),
          ),
        ),
      );
      await tester.pumpWidget(view(false));
      final initial = tester.getRect(find.byType(TdsSwitch));
      final gesture = await tester.startGesture(initial.center);
      expect(haptic.calls, [TdsHapticType.softWeak]);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TdsSwitch)), initial);
      expect(find.byType(AnimatedScale), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(events, ['click', 'change:true']);
      expect(
        tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left,
        7,
      );
      await tester.pumpWidget(view(true));
      final position = tester.widget<AnimatedPositioned>(
        find.byType(AnimatedPositioned),
      );
      expect(position.left, 23);
      expect(position.duration, TdsMotion.medium.duration);
      await tester.pumpAndSettle();
      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(containers.last.constraints!.maxWidth, 24);
      expect(tester.getSize(find.byType(TdsSwitch)), const Size(50, 30));
    },
  );

  testWidgets(
    'switch captures initial touch options but inert always suppresses events',
    (tester) async {
      final haptic = RecordingHaptic();
      var changes = 0;
      Widget view({
        bool disabled = false,
        bool effect = true,
        bool inert = false,
        Key? key,
      }) => app(
        TdsHostProvider(
          haptic: haptic,
          child: TdsSwitch(
            key: key,
            disabled: disabled,
            hasTouchEffect: effect,
            inert: inert,
            onChanged: (_) => changes++,
          ),
        ),
      );
      await tester.pumpWidget(view(disabled: true));
      await tester.tap(find.byType(TdsSwitch));
      expect(haptic.calls, isEmpty);
      expect(changes, 0);
      await tester.pumpWidget(view());
      await tester.tap(find.byType(TdsSwitch));
      expect(haptic.calls, isEmpty); // bundled W retains the initial callback
      expect(changes, 1);
      await tester.pumpWidget(
        view(effect: false, key: const ValueKey('no-effect')),
      );
      await tester.tap(find.byType(TdsSwitch));
      expect(haptic.calls, isEmpty);
      await tester.pumpWidget(view(inert: true, key: const ValueKey('inert')));
      await tester.tap(find.byType(TdsSwitch));
      expect(haptic.calls, isEmpty);
      expect(changes, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
