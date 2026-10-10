import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('BottomSheet selection, dimmer closing and exit lifecycle', (
    tester,
  ) async {
    var open = true, exits = 0, dimmers = 0;
    String? selected;
    await tester.pumpWidget(
      testApp(
        StatefulBuilder(
          builder: (context, setState) => TdsBottomSheet(
            open: open,
            onClose: () => setState(() => open = false),
            onExited: () => exits++,
            onDimmerClick: () => dimmers++,
            header: const TdsBottomSheetHeader('선택하세요'),
            child: TdsBottomSheetSelect(
              options: const [
                TdsBottomSheetSelectOption(name: '가능', value: 'yes'),
                TdsBottomSheetSelectOption(
                  name: '불가',
                  value: 'no',
                  disabled: true,
                ),
              ],
              value: selected,
              onChange: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('선택하세요'), findsOneWidget);
    await tester.tap(find.text('가능'));
    await tester.pumpAndSettle();
    expect(selected, 'yes');
    await tester.tap(find.text('불가'));
    expect(selected, 'yes');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(dimmers, 1);
    expect(exits, 1);
    expect(find.text('선택하세요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Sheet controller deduplicates async action and ignores stale completion',
    (tester) async {
      final controller = TdsBottomSheetController();
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetProvider(
            controller: controller,
            child: const SizedBox(height: 100),
          ),
        ),
      );
      final pending = Completer<void>();
      var calls = 0;
      final oldResult = controller.openAsyncOneButtonSheet(
        options: const TdsBottomSheetOptions(child: Text('첫 번째')),
        onClick: () {
          calls++;
          return pending.future;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pump(const Duration(milliseconds: 100));
      // A second activation during the operation is ignored even if it was queued.
      final button = tester.widget<TdsBottomSheetCTA>(
        find.byType(TdsBottomSheetCTA),
      );
      button.onPressed!();
      expect(calls, 1);
      final newResult = controller.openOneButtonSheet(
        options: const TdsBottomSheetOptions(child: Text('두 번째')),
      );
      expect(await oldResult, false);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('두 번째'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(await newResult, true);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      controller.dispose();
    },
  );

  testWidgets(
    'Sheet failure stays open, provider unmount settles pending futures',
    (tester) async {
      final controller = TdsBottomSheetController();
      Object? error;
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetProvider(
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      );
      final result = controller.openAsyncOneButtonSheet(
        options: const TdsBottomSheetOptions(child: Text('재시도')),
        onClick: () async => throw StateError('retry'),
        onError: (e, _) => error = e,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(error, isA<StateError>());
      expect(find.text('재시도'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(await result, false);
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Fixed CTA reserves measured height and removes portal on unmount',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const Column(
            children: [
              Text('내용'),
              TdsFixedBottomCTA(child: Text('계속')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TdsFixedPanel)).height,
        greaterThan(70),
      );
      expect(tester.getBottomLeft(find.text('계속')).dy, greaterThan(500));
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(find.text('계속'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Navigation bounds count badge and reports label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        const TdsTopNavigation(
          content: Text('제목'),
          trailing: TdsTopNavigationIconButton(
            name: 'icn-delete',
            semanticLabel: '알림',
            count: 18,
            countLabel: '알림 18개',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
    expect(find.bySemanticsLabel('알림 18개'), findsOneWidget);
    expect(tester.getSize(find.byType(TdsFixedPanel)).height, 54);
    semantics.dispose();
  });

  testWidgets(
    'Native portal consumers require a provider and follow its lifetime',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsPortalConsumer(
            child: Positioned(top: 0, left: 0, child: Text('포털')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('포털'), findsNothing);
      await tester.pumpWidget(
        testApp(
          const TdsPortalProvider(
            child: TdsPortalConsumer(
              child: Positioned(top: 0, left: 0, child: Text('포털')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('포털'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(find.text('포털'), findsNothing);
    },
  );
}
