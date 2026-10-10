import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() {
  testWidgets(
    'footer grows evenly and wraps confirm above cancel by intrinsic content',
    (tester) async {
      Widget footer(double confirmWidth) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 280,
            child: TdsDialogFooter(
              cancelButton: const SizedBox(
                key: ValueKey('cancel'),
                width: 60,
                height: 48,
              ),
              confirmButton: SizedBox(
                key: const ValueKey('confirm'),
                width: confirmWidth,
                height: 48,
              ),
            ),
          ),
        ),
      );
      final cancel = find.byKey(const ValueKey('cancel'));
      final confirm = find.byKey(const ValueKey('confirm'));
      await tester.pumpWidget(footer(70));
      // Auto flex bases 60/70, then the cancel item freezes at min-width 132.
      expect(tester.getSize(cancel), const Size(132, 48));
      expect(tester.getSize(confirm), const Size(140, 48));
      expect(tester.getTopLeft(confirm).dx - tester.getTopRight(cancel).dx, 8);
      await tester.pumpWidget(footer(190));
      expect(tester.getSize(cancel), const Size(280, 48));
      expect(
        tester.getTopLeft(cancel).dy - tester.getBottomLeft(confirm).dy,
        8,
      );
      expect(tester.getSize(find.byType(TdsDialogFooter)).height, 104);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('footer follows flex bases, min-width boundaries and RTL', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      for (final widths in [
        (60.0, 60.0),
        (64.0, 70.0),
        (70.0, 64.0),
        (40.0, 140.0),
        (40.0, 141.0),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: 280,
                child: TdsDialogFooter(
                  cancelButton: SizedBox(
                    key: const Key('cancel'),
                    width: widths.$1,
                    height: 40,
                  ),
                  confirmButton: SizedBox(
                    key: const Key('confirm'),
                    width: widths.$2,
                    height: 48,
                  ),
                ),
              ),
            ),
          ),
        );
        final c = tester.getRect(find.byKey(const Key('cancel')));
        final f = tester.getRect(find.byKey(const Key('confirm')));
        if (widths.$2 == 141) {
          expect(c.width, 280);
          expect(f.width, 280);
          expect(c.top - f.bottom, 8);
        } else {
          final expected = widths.$1 == 40
              ? 132.0
              : (272 + widths.$1 - widths.$2) / 2;
          expect(c.width, expected);
          expect(c.width + f.width, 272);
          expect(c.height, 48);
          expect(f.height, 48);
          expect(
            direction == TextDirection.ltr
                ? f.left - c.right
                : c.left - f.right,
            8,
          );
        }
      }
    }
  });
  testWidgets(
    'controlled modal handles dimmer, enter/exit callbacks and keeps background inert',
    (tester) async {
      var open = false,
          entered = 0,
          exited = 0,
          background = 0,
          closeRequests = 0;
      late StateSetter update;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          builder: (context, child) => TdsMobileProvider(child: child!),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Stack(
                children: [
                  Center(
                    child: TdsButton(
                      onPressed: () => background++,
                      child: const Text('배경'),
                    ),
                  ),
                  TdsAlertDialog(
                    open: open,
                    title: const Text('제목'),
                    description: const Text('설명'),
                    onEntered: () => entered++,
                    onExited: () => exited++,
                    onClose: () {
                      closeRequests++;
                      update(() => open = false);
                    },
                    alertButton: TdsAlertDialogButton(
                      onPressed: () => update(() => open = false),
                      child: const Text('확인'),
                    ),
                  ),
                ],
              );
            },
          ),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (c, a, s) => builder(c),
          ),
        ),
      );
      update(() => open = true);
      await tester.pumpAndSettle();
      expect(find.text('제목'), findsOneWidget);
      expect(entered, 1);
      expect(tester.getSize(find.byType(TdsModalContent)).width, 320);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(closeRequests, 1);
      expect(exited, 1);
      expect(background, 0);
      expect(find.text('제목'), findsNothing);
      update(() => open = true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closeRequests, 2);
      expect(exited, 2);
      await tester.tap(find.text('배경'));
      expect(background, 1);
    },
  );
}
