import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

void main() {
  testWidgets(
    'dialog future resolves on confirmation and replacement settles earlier request',
    (tester) async {
      final controller = TdsDialogController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fieldApp(
          TdsDialogProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final first = controller.openConfirm(title: const Text('첫 질문'));
      await tester.pumpAndSettle();
      final second = controller.openConfirm(title: const Text('다음 질문'));
      expect(await first, isFalse);
      await tester.pumpAndSettle();
      expect(find.text('첫 질문'), findsNothing);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(await second, isTrue);
      expect(find.text('다음 질문'), findsNothing);
      final third = controller.openConfirm(title: const Text('제거 시 취소'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(await third, isFalse);
    },
  );
  testWidgets(
    'async dialog blocks duplicate confirms, supports failure/retry and ignores stale completion',
    (tester) async {
      final controller = TdsDialogController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fieldApp(
          TdsDialogProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      var calls = 0;
      final errors = <Object>[];
      var work = Completer<void>();
      final result = controller.openAsyncConfirm(
        title: const Text('저장'),
        onConfirmClick: () {
          calls++;
          return work.future;
        },
        onError: (error, stack) => errors.add(error),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pump();
      await tester.tap(find.text('확인'));
      expect(calls, 1);
      work.completeError(StateError('저장 실패'));
      await tester.pumpAndSettle();
      expect(errors, hasLength(1));
      expect(find.text('저장'), findsOneWidget);
      work = Completer<void>();
      await tester.tap(find.text('확인'));
      await tester.pump();
      expect(calls, 2);
      controller.close();
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      final next = controller.openConfirm(title: const Text('새 작업'));
      await tester.pumpAndSettle();
      work.complete();
      await tester.pumpAndSettle();
      expect(find.text('새 작업'), findsOneWidget);
      controller.close();
      await tester.pumpAndSettle();
      expect(await next, isFalse);
    },
  );
}
