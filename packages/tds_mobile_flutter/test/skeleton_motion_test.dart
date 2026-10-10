import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'wrapper starts at zero, enters for 1s and hides for 400ms with source curves',
    (tester) async {
      Widget view(bool show) =>
          testApp(TdsSkeletonWrapper(show: show, child: const Text('내용')));
      double opacity() =>
          tester.widget<Opacity>(find.byType(Opacity).last).opacity;
      await tester.pumpWidget(view(true));
      expect(opacity(), 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), closeTo(TdsMotion.out.transform(.5), .0001));
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), 1);
      await tester.pumpWidget(view(false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(), closeTo(1 - TdsMotion.expo.transform(.5), .0001));
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(), 0);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpWidget(view(false));
      expect(opacity(), 1); // Source initially hidden wrapper animates from 1.
      await tester.pump(const Duration(milliseconds: 400));
      expect(opacity(), 0);
    },
  );

  testWidgets(
    'wrapper reversal preserves current opacity and does not swallow child clicks',
    (tester) async {
      var clicks = 0;
      Widget view(bool show) => testApp(
        TdsSkeletonWrapper(
          show: show,
          child: TdsButton(onPressed: () => clicks++, child: const Text('확인')),
        ),
      );
      double opacity() =>
          tester.widget<Opacity>(find.byType(Opacity).first).opacity;
      await tester.pumpWidget(view(true));
      await tester.pump(const Duration(milliseconds: 300));
      final partial = opacity();
      await tester.tap(find.text('확인'));
      expect(clicks, 1);
      await tester.pumpWidget(view(false));
      expect(opacity(), partial);
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), lessThan(partial));
      final exiting = opacity();
      await tester.pumpWidget(view(true));
      expect(opacity(), exiting);
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 1);
    },
  );

  testWidgets(
    'item delay starts invisible, then alternates the original 600ms pulse curve',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsSkeletonItem(
            index: 3,
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      double opacity() =>
          tester.widget<Opacity>(find.byType(Opacity).last).opacity;
      double scale() => tester
          .widget<Transform>(find.byType(Transform).last)
          .transform
          .storage[0];
      expect(opacity(), 0);
      expect(scale(), 1);
      await tester.pump(const Duration(milliseconds: 299));
      expect(opacity(), 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(opacity(), .2);
      expect(scale(), .96);
      await tester.pump(const Duration(milliseconds: 300));
      final t = const Cubic(.6, 0, 0, .6).transform(.5);
      expect(opacity(), closeTo(.2 + .8 * t, .0001));
      expect(scale(), closeTo(.96 + .04 * t, .0001));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), closeTo(1, .0001));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), closeTo(.2 + .8 * t, .0001));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), closeTo(.2, .0001));
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('removal during delayed pulse cancels timer', (tester) async {
    await tester.pumpWidget(
      testApp(const TdsSkeletonItem(index: 50, child: Text('대기'))),
    );
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
