import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'string header convenience and all slot contexts retain the invoking controller',
    (tester) async {
      final controller = TdsBottomSheetController();
      final seen = <TdsBottomSheetController>[];
      Widget slot(String label) => Builder(
        builder: (context) {
          seen.add(useBottomSheet(context));
          return Text(label);
        },
      );
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetProvider(
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      );
      controller.open(
        TdsBottomSheetOptions(
          header: slot('header'),
          headerDescription: slot('description'),
          cta: slot('cta'),
          child: slot('body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen.length, greaterThanOrEqualTo(4));
      expect(seen.every((c) => c == controller), true);
      controller.open(
        const TdsBottomSheetOptions(
          header: 'string header',
          child: Text('body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TdsBottomSheetHeader>(find.byType(TdsBottomSheetHeader))
            .text,
        'string header',
      );
      useBottomSheet(tester.element(find.text('body'))).close();
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom async button receives scoped loading state and recovers from error before success',
    (tester) async {
      final controller = TdsBottomSheetController();
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetProvider(
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      );
      TdsSheetButtonState? buttonState;
      var operation = Completer<void>();
      var calls = 0, errors = 0;
      final result = controller.openAsyncOneButtonSheet(
        options: const TdsBottomSheetOptions(child: Text('body')),
        onClick: () {
          calls++;
          return operation.future;
        },
        onError: (_, _) => errors++,
        buttonBuilder: (context, state) {
          expect(useBottomSheet(context), controller);
          buttonState = state;
          return TdsBottomSheetCTA(
            onPressed: state.onPressed,
            child: Text(state.loading ? 'working' : 'custom'),
          );
        },
      );
      await tester.pumpAndSettle();
      expect(buttonState!.loading, false);
      await tester.tap(find.text('custom'));
      await tester.pumpAndSettle();
      await buttonState!
          .onPressed(); // rejected duplicate while original is pending
      expect(calls, 1);
      expect(buttonState!.loading, true);
      operation.completeError(StateError('try again'));
      await tester.pumpAndSettle();
      expect(errors, 1);
      expect(buttonState!.loading, false);
      expect(find.text('custom'), findsOneWidget);
      operation = Completer<void>();
      await tester.tap(find.text('custom'));
      await tester.pump();
      operation.complete();
      await tester.pumpAndSettle();
      expect(await result, true);
      expect(calls, 2);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.dispose();
    },
  );

  testWidgets(
    'two custom buttons preserve side results and prevent stale async completion from closing replacement',
    (tester) async {
      final controller = TdsBottomSheetController();
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetProvider(
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      );
      final operation = Completer<void>();
      TdsSheetButtonState? left, right;
      final old = controller.openAsyncTwoButtonSheet(
        options: const TdsBottomSheetOptions(child: Text('old')),
        onLeftButtonClick: () => operation.future,
        leftButtonBuilder: (context, state) {
          left = state;
          return Text(state.loading ? 'busy left' : 'left');
        },
        rightButtonBuilder: (context, state) {
          right = state;
          return const Text('right');
        },
      );
      await tester.pumpAndSettle();
      final action = left!.onPressed();
      await tester.pumpAndSettle();
      expect(left!.loading, true);
      expect(right!.disabled, true);
      final next = controller.openTwoButtonSheet(
        options: const TdsBottomSheetOptions(child: Text('new')),
        closeOnLeftButtonClick: false,
        leftButtonBuilder: (_, state) =>
            TdsButton(onPressed: state.onPressed, child: const Text('stay')),
      );
      await tester.pumpAndSettle();
      expect(await old, TdsTwoButtonSheetAction.cancel);
      operation.complete();
      await action;
      await tester.pumpAndSettle();
      expect(find.text('new'), findsOneWidget);
      await tester.tap(find.text('stay'));
      await tester.pumpAndSettle();
      expect(await next, TdsTwoButtonSheetAction.leftButtonClick);
      expect(find.text('new'), findsOneWidget);
      controller.close();
      await tester.pumpAndSettle();
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.dispose();
    },
  );

  testWidgets(
    'plain open forwards close callback; promise helpers replace it; options reach the sheet',
    (tester) async {
      final controller = TdsBottomSheetController();
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetProvider(
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      );
      var closes = 0;
      final options = TdsBottomSheetOptions(
        onClose: () => closes++,
        expandBottomSheet: true,
        disableChildrenDragging: true,
        a11yIncludeHeaderInScroll: false,
        ctaContentGap: 12,
        expandedMaxHeight: const TdsBottomSheetHeight.viewport(.9),
        semanticLabel: 'custom sheet',
        child: const Text('body'),
      );
      controller.open(options);
      await tester.pumpAndSettle();
      final sheet = tester.widget<TdsBottomSheet>(find.byType(TdsBottomSheet));
      expect(sheet.expandBottomSheet, true);
      expect(sheet.disableChildrenDragging, true);
      expect(sheet.a11yIncludeHeaderInScroll, false);
      expect(sheet.ctaContentGap, 12);
      expect(sheet.expandedMaxHeight.fraction, .9);
      expect(sheet.semanticLabel, 'custom sheet');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(find.text('body'), findsOneWidget); // raw callback declined close
      final result = controller.openOneButtonSheet(options: options);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(await result, false);
      expect(find.text('body'), findsNothing);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.dispose();
    },
  );
}
