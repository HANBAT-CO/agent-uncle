import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

Widget view(double value, {Widget tooltip = const TdsSliderTooltip()}) =>
    testApp(
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24, top: 124),
          child: SizedBox(
            width: 342,
            child: TdsSlider(
              value: value,
              tooltip: tooltip,
              label: const TdsSliderLabel(min: '0', mid: '50', max: '100'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'default tooltip uses original progress anchor, 30px gap and value formatting',
    (tester) async {
      await tester.pumpWidget(view(25));
      await tester.pumpAndSettle();
      final anchor = tester.getRect(find.byType(TdsSliderTooltip));
      expect(
        anchor,
        rectMoreOrLessEquals(const Rect.fromLTWH(115.5, 141.5, 0, 0)),
      );
      final content = tester.getRect(find.byType(TdsTooltipContent));
      expect(anchor.top - content.bottom, 30);
      expect(content.center.dx, anchor.left);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('25.0'), findsNothing);
      expect(tester.getSize(find.byType(TdsSlider)).height, 60);
      await tester.pumpWidget(view(75));
      await tester.pumpAndSettle();
      expect(find.text('75'), findsOneWidget);
      expect(find.text('25'), findsNothing);
      expect(tester.getCenter(find.byType(TdsTooltipContent)).dx, 274.5);
    },
  );
  testWidgets(
    'tooltip forwards native options, message overrides, close and reopen',
    (tester) async {
      const tooltip = TdsSliderTooltip(
        message: '값',
        size: TdsTooltipSize.small,
        placement: TdsOverlayPlacement.bottom,
        offset: 12,
        anchorPositionByRatio: 0,
        clipToEnd: TdsTooltipClip.left,
        messageAlign: TextAlign.right,
        motionVariant: TdsTooltipMotion.strong,
        autoFlip: true,
      );
      await tester.pumpWidget(view(25, tooltip: tooltip));
      await tester.pumpAndSettle();
      final native = tester.widget<TdsTooltip>(find.byType(TdsTooltip));
      expect(native.offset, 12);
      expect(native.motionVariant, TdsTooltipMotion.strong);
      expect(native.autoFlip, true);
      final content = tester.widget<TdsTooltipContent>(
        find.byType(TdsTooltipContent),
      );
      expect(content.size, TdsTooltipSize.small);
      expect(content.clipToEnd, TdsTooltipClip.left);
      expect(content.anchorPositionByRatio, 0);
      expect(content.messageAlign, TextAlign.right);
      expect(find.text('값'), findsOneWidget);
      await tester.pumpWidget(
        view(25, tooltip: const TdsSliderTooltip(open: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TdsTooltipContent), findsNothing);
      await tester.pumpWidget(
        view(
          25,
          tooltip: const TdsSliderTooltip(messageWidget: Text('사용자 메시지')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('사용자 메시지'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(find.byType(TdsTooltipContent), findsNothing);
    },
  );
  testWidgets(
    'slider tooltip requires its scope instead of inventing value zero',
    (tester) async {
      await tester.pumpWidget(testApp(const TdsSliderTooltip()));
      expect(tester.takeException(), isA<StateError>());
    },
  );
}
