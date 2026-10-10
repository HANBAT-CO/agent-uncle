import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

void main() {
  testWidgets(
    'menu retains inner 180px minimum plus border and source effects',
    (tester) async {
      for (final scheme in TdsColorPreference.values) {
        await tester.pumpWidget(
          fieldApp(
            TdsColorSchemeArea(
              theme: scheme,
              child: const TdsMenuDropdown(
                children: [TdsMenuDropdownItem(child: Text('항목'))],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(TdsMenuDropdown)).width, 182);
        final containers = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(TdsMenuDropdown),
            matching: find.byType(Container),
          ),
        );
        final box = containers
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.border != null);
        expect(
          (box.border! as Border).top.color,
          Color.fromRGBO(
            255,
            255,
            255,
            scheme == TdsColorPreference.dark ? .01 : .7,
          ),
        );
        final blur = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
        expect(blur.filter, ImageFilter.blur(sigmaX: 30, sigmaY: 30));
        final shadow = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((b) => b.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.boxShadow != null)
            .boxShadow!
            .single;
        expect(shadow.blurRadius, 60);
        expect(shadow.offset, const Offset(0, 16));
      }
    },
  );

  testWidgets(
    'item addon gaps are 6/16 and source text line stays fractional',
    (tester) async {
      await tester.pumpWidget(
        fieldApp(
          const SizedBox(
            width: 240,
            child: TdsMenuDropdownItem(
              left: SizedBox(key: Key('left'), width: 20, height: 20),
              right: SizedBox(key: Key('right'), width: 20, height: 20),
              child: Text('항목'),
            ),
          ),
        ),
      );
      final text = tester.getRect(find.text('항목'));
      final left = tester.getRect(find.byKey(const Key('left')));
      final right = tester.getRect(find.byKey(const Key('right')));
      expect(text.left - left.right, 6);
      expect(right.left - text.right, 16);
      expect(tester.getSize(find.byType(TdsMenuDropdownItem)).height, 41.5);
    },
  );

  testWidgets(
    'check menus align headers to 16px and fades use 5/95 thresholds',
    (tester) async {
      await tester.pumpWidget(
        fieldApp(
          TdsMenuDropdown(
            header: const TdsMenuHeader('메뉴 제목'),
            children: [
              for (var i = 0; i < 30; i++)
                TdsMenuDropdownCheckItem(child: Text('항목 $i')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TdsMenuDropdown)).height, 362);
      expect(
        tester.getTopLeft(find.byType(TdsMenuHeader)).dx -
            tester.getTopLeft(find.byType(TdsMenuDropdown)).dx,
        17,
      ); // includes border
      final scrollable = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      List<double> fades() => tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();
      expect(fades(), [0, 1]);
      final scroll = scrollable.controller!;
      for (final step in [
        (0.04, [0.0, 1.0]),
        (0.06, [1.0, 1.0]),
        (0.94, [1.0, 1.0]),
        (0.96, [1.0, 0.0]),
      ]) {
        scroll.jumpTo(scroll.position.maxScrollExtent * step.$1);
        await tester.pumpAndSettle();
        expect(fades(), step.$2);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
