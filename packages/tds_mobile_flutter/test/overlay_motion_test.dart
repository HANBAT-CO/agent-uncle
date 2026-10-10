import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'Tooltip strong motion overshoots then settles, exit can be reversed',
    (tester) async {
      Widget view(bool open) => testApp(
        TdsTooltip(
          open: open,
          motionVariant: TdsTooltipMotion.strong,
          message: const Text('툴팁'),
          child: const Text('대상'),
        ),
      );
      await tester.pumpWidget(view(true));
      await tester.pump();
      await tester.pump();
      await tester.pump(TdsMotion.quick.duration);
      double scale() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(TdsTooltipMotionSurface),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[0];
      expect(scale(), closeTo(1.25, .03));
      await tester.pumpAndSettle();
      expect(scale(), closeTo(1, .001));
      await tester.pumpWidget(view(false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('툴팁'), findsOneWidget);
      final exiting = scale();
      expect(exiting, lessThan(1));
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      expect(find.text('툴팁'), findsOneWidget);
      expect(scale(), closeTo(1, .001));
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(find.text('툴팁'), findsNothing);
    },
  );
  testWidgets('Tooltip reduced motion keeps the original scale while fading', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
          ),
          child: const TdsTooltip(
            open: true,
            motionVariant: TdsTooltipMotion.strong,
            message: Text('설명'),
            child: Text('대상'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(TdsTooltipMotionSurface),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.storage[0], 1);
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Agreement exposes state immediately but delays its visual color and cancels on removal',
    (tester) async {
      bool? changed;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          TdsAgreementV4(
            variant: TdsAgreementVariant.medium,
            left: TdsAgreementCheckbox(
              transitionDelay: const Duration(milliseconds: 400),
              onCheckedChange: (v) => changed = v,
            ),
            middle: const TdsAgreementText('개인정보 동의'),
          ),
        ),
      );
      final original = tester
          .widget<TdsCheckboxLineGraphic>(find.byType(TdsCheckboxLineGraphic))
          .color;
      await tester.tap(find.byType(TdsCheckboxLineGraphic));
      await tester.pump();
      expect(changed, true);
      expect(
        tester
            .widget<TdsCheckboxLineGraphic>(find.byType(TdsCheckboxLineGraphic))
            .color,
        original,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TdsCheckboxLineGraphic>(find.byType(TdsCheckboxLineGraphic))
            .color,
        isNot(original),
      );
      expect(find.bySemanticsLabel('개인정보 동의'), findsWidgets);
      await tester.tap(find.byType(TdsCheckboxLineGraphic));
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'Wiki definition flips above a low word and restores keyboard focus',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const SizedBox(
            height: 590,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: TdsWikiText('정의', description: Text('추가 설명')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final anchor = tester.getTopLeft(find.byType(TdsWikiText));
      await tester.tap(find.byType(TdsWikiText));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.text('추가 설명')).dy, lessThan(anchor.dy));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('추가 설명'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(find.text('추가 설명'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Short menu fits content instead of taking 66 percent of viewport',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsMenuTrigger(
            defaultOpen: true,
            dropdown: TdsMenuDropdown(
              children: [TdsMenuDropdownItem(child: Text('저장'))],
            ),
            child: Text('열기'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Original inner scroller is 180px; its two outer 1px borders add 2px.
      expect(tester.getSize(find.byType(TdsMenuDropdown)).width, 182);
      expect(tester.takeException(), isNull);
    },
  );
}
