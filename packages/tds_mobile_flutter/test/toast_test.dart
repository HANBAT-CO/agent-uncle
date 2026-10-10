import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

void main() {
  testWidgets(
    'toast auto closes, retains live-region semantics, does not block background',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TdsToastController();
      var background = 0;
      await tester.pumpWidget(
        fieldApp(
          TdsToastProvider(
            controller: controller,
            child: Center(
              child: TdsButton(
                onPressed: () => background++,
                child: const Text('배경'),
              ),
            ),
          ),
        ),
      );
      controller.openToast('저장했어요');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final surface = find.byType(TdsToastContent);
      expect(surface, findsOneWidget);
      final node = tester.getSemantics(surface).getSemanticsData();
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(tester.getBottomLeft(surface).dy, 580);
      await tester.tap(find.text('배경'));
      expect(background, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      semantics.dispose();
    },
  );

  testWidgets(
    'replacement is serialized, latest wins even before first frame',
    (tester) async {
      final controller = TdsToastController();
      await tester.pumpWidget(
        fieldApp(
          TdsToastProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.openToast('첫째');
      controller.openToast('둘째');
      await tester.pumpAndSettle();
      expect(find.text('첫째'), findsNothing);
      expect(find.text('둘째'), findsOneWidget);
      controller.openToast('셋째');
      await tester.pump();
      controller.openToast('넷째');
      expect(find.text('둘째'), findsOneWidget);
      expect(find.text('셋째'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('둘째'), findsNothing);
      expect(find.text('넷째'), findsOneWidget);
      controller.closeToast();
      await tester.pumpAndSettle();
      expect(find.byType(TdsToastContent), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'action keeps five-second lifetime and does not implicitly close',
    (tester) async {
      final controller = TdsToastController();
      var actions = 0;
      await tester.pumpWidget(
        fieldApp(
          TdsToastProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.openToast(
        '저장했어요',
        options: TdsToastOptions(
          button: TdsToastButton(
            onPressed: () => actions++,
            child: const Text('취소'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(controller.isOpen, isTrue);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(controller.isOpen, isTrue);
      // A pointer interaction restarts the original timer on release.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(TdsToastContent), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'Android bottom drag dismisses down, persistent survives, timers dispose',
    (tester) async {
      final controller = TdsToastController();
      await tester.pumpWidget(
        fieldApp(
          TdsToastProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.openToast('첫째');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TdsToastContent), const Offset(0, 25));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      controller.openToast(
        '계속 보여요',
        options: const TdsToastOptions(persistent: true),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TdsToastContent), const Offset(0, 25));
      await tester.pump(const Duration(seconds: 20));
      expect(controller.isOpen, isTrue);
      controller.openToast('타이머 취소');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );
}
