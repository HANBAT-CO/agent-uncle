import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'CodeAuth submits once, enforces minimum loading and returns data after success',
    (tester) async {
      final controller = TdsCodeAuthController(length: 4);
      var submissions = 0;
      String? result;
      final response = Completer<String>();
      await tester.pumpWidget(
        testApp(
          TdsCodeAuthModule(
            child: TdsCodeAuthFieldController(
              length: 4,
              controller: controller,
              builder: (_, _) => TdsCodeAuthField<String>(
                onSubmit: (_) {
                  submissions++;
                  return response.future;
                },
                onSuccess: (value) => result = value,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '12a34');
      await tester.pump();
      expect(controller.value, '1234');
      expect(controller.step, TdsCodeAuthStep.loading);
      expect(submissions, 1);
      response.complete('token');
      await tester.pump(const Duration(milliseconds: 999));
      expect(controller.step, TdsCodeAuthStep.loading);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.step, TdsCodeAuthStep.success);
      await tester.pump(const Duration(milliseconds: 600));
      expect(result, 'token');
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.dispose();
    },
  );
  testWidgets(
    'CodeAuth ignores stale completion after clear and handles retry/errors',
    (tester) async {
      final controller = TdsCodeAuthController(length: 2);
      var failures = 0, errors = 0, successes = 0;
      final response = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        testApp(
          TdsCodeAuthModule(
            child: TdsCodeAuthFieldController(
              length: 2,
              controller: controller,
              builder: (_, _) => TdsCodeAuthField<bool>(
                error: const TdsCodeAuthError('실패'),
                onSubmit: (_) {
                  if (calls++ == 0) return response.future;
                  throw StateError('network');
                },
                onSuccess: (_) => successes++,
                onFailure: () => failures++,
                onError: (_, _) => errors++,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '12');
      controller.clear();
      response.complete(true);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.step, TdsCodeAuthStep.typing);
      expect(successes, 0);
      await tester.enterText(find.byType(EditableText), '34');
      await tester.pump(const Duration(seconds: 1));
      expect(controller.step, TdsCodeAuthStep.error);
      expect(failures, 1);
      expect(errors, 1);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(controller.step, TdsCodeAuthStep.retry);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Split RRN formats, advances focus, masks only second part and retains owned controllers',
    (tester) async {
      final first = TextEditingController(), second = TextEditingController();
      final secondFocus = FocusNode();
      await tester.pumpWidget(
        testApp(
          TdsSplitTextField.rrn13(
            variant: TdsTextFieldVariant.box,
            first: TdsSplitInput(controller: first),
            second: TdsSplitInput(controller: second, focusNode: secondFocus),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText).at(0), '123456a789');
      await tester.pump();
      expect(first.text, '123456');
      expect(secondFocus.hasFocus, true);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .obscureText,
        true,
      );
      await tester.enterText(find.byType(EditableText).at(1), '123456789');
      expect(second.text, '1234567');
      await tester.pumpWidget(testApp(const SizedBox()));
      first.text = 'alive';
      second.text = 'alive';
      first.dispose();
      second.dispose();
      secondFocus.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
