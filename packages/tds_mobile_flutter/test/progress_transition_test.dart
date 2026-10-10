import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/css_transition.dart';
import 'interaction_test.dart' show app;

void main() {
  TdsCssTransition transition(WidgetTester tester) => TdsCssTransition(
    vsync: tester,
    value: 0,
    baseDuration: const Duration(milliseconds: 500),
  );

  testWidgets('CSS reversal shortens duration by eased progress', (
    tester,
  ) async {
    final motion = transition(tester);
    motion.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final progress = Curves.easeInOut.transform(.4);
    expect(motion.value, closeTo(progress, .000001));
    motion.animateTo(0);
    expect(motion.value, closeTo(progress, .000001));
    expect(motion.duration.inMicroseconds, (500000 * progress).round());
    await tester.pump();
    await tester.pump(motion.duration + const Duration(milliseconds: 1));
    expect(motion.value, 0);
    expect(motion.isAnimating, isFalse);
    motion.dispose();
  });

  testWidgets('second reversal carries the previous shortening factor', (
    tester,
  ) async {
    final motion = transition(tester);
    motion.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    motion.animateTo(0);
    expect(motion.duration.inMicroseconds, closeTo(250000, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final current = motion.value;
    motion.animateTo(1);
    expect(motion.value, current);
    // .5 + .5 * ease-in-out(.4), not a fresh 500ms or just distance * 500ms.
    final factor = .5 + .5 * Curves.easeInOut.transform(.4);
    expect(motion.duration.inMicroseconds, closeTo(500000 * factor, 150));
    await tester.pump();
    await tester.pump(motion.duration + const Duration(milliseconds: 1));
    expect(motion.value, 1);
    motion.dispose();
  });

  testWidgets(
    'new target restarts full duration, identical target keeps timeline',
    (tester) async {
      final motion = transition(tester);
      motion.animateTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final current = motion.value;
      motion.animateTo(.75);
      expect(motion.value, current);
      expect(motion.duration, const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final middle = motion.value;
      motion.animateTo(.75);
      expect(motion.value, middle);
      await tester.pump(const Duration(milliseconds: 251));
      expect(motion.value, .75);
      expect(motion.isAnimating, isFalse);
      motion.dispose();
    },
  );

  testWidgets(
    'immediate reversal completes and active disposal releases ticker',
    (tester) async {
      final motion = transition(tester);
      motion.animateTo(1);
      motion.animateTo(0);
      expect(motion.duration, Duration.zero);
      expect(motion.value, 0);
      expect(motion.isAnimating, isFalse);
      motion.animateTo(1);
      await tester.pump();
      motion.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  Positioned filler(WidgetTester tester) => tester.widget<Positioned>(
    find.descendant(
      of: find.byType(TdsProgressBar),
      matching: find.byType(Positioned),
    ),
  );

  Widget view(double progress, {bool animate = false, Key? key}) => app(
    SizedBox(
      width: 200,
      child: TdsProgressBar(
        key: key,
        progress: progress,
        animate: animate,
        semanticLabel: '진행',
      ),
    ),
  );

  testWidgets(
    'animate affects initial paint only; every later change transitions',
    (tester) async {
      await tester.pumpWidget(view(.8, animate: true));
      expect(filler(tester).left, -200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(filler(tester).left, closeTo(-120, .05));
      await tester.pumpAndSettle();
      expect(filler(tester).left, closeTo(-40, .00001));
      await tester.pumpWidget(view(.4));
      expect(filler(tester).left, closeTo(-40, .00001));
      await tester.pumpAndSettle();
      expect(filler(tester).left, closeTo(-120, .00001));
      await tester.pumpWidget(view(.4, animate: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(filler(tester).left, closeTo(-120, .00001));
      await tester.pumpWidget(view(.9, key: const ValueKey('new')));
      expect(filler(tester).left, closeTo(-20, .00001));
    },
  );

  testWidgets(
    'source preserves out-of-range translation and fractional semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final progress in [-.25, .125, 1.25]) {
        await tester.pumpWidget(view(progress, key: ValueKey(progress)));
        expect(filler(tester).left, (progress - 1) * 200);
        expect(filler(tester).width, 200);
        expect(
          tester.getSemantics(find.bySemanticsLabel('진행')).value,
          switch (progress) {
            -.25 => '-25%',
            .125 => '12.5%',
            _ => '125%',
          },
        );
      }
      await tester.pumpWidget(
        view(.5, animate: true, key: const ValueKey('remove')),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
