import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Widget testApp(Widget child, {double scale = 100}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, navigator) => TdsMobileProvider(
    theme: TdsThemeData(
      platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
    ),
    child: navigator!,
  ),
  home: SingleChildScrollView(child: child),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (c, a, s) => builder(c),
  ),
);

void main() {
  testWidgets('BoardRow preserves controlled state and hides folded content', (
    tester,
  ) async {
    var opened = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        TdsBoardRow(
          isOpened: false,
          onOpen: () => opened++,
          title: const Text('펼치기'),
          child: const TdsBoardRowText('비공개 내용'),
        ),
      ),
    );
    await tester.tap(find.text('펼치기'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.bySemanticsLabel('비공개 내용'), findsNothing);
    await tester.pumpWidget(
      testApp(
        const TdsBoardRow(
          isOpened: true,
          title: Text('펼치기'),
          child: TdsBoardRowText('비공개 내용'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('비공개 내용'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('BoardRow uncontrolled pointer and keyboard activation', (
    tester,
  ) async {
    var closes = 0;
    await tester.pumpWidget(
      testApp(
        TdsBoardRow(
          title: const Text('제목'),
          onClose: () => closes++,
          child: const SizedBox(height: 70),
        ),
      ),
    );
    final folded = tester.getSize(find.byType(TdsBoardRow)).height;
    await tester.tap(find.text('제목'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(TdsBoardRow)).height,
      greaterThan(folded + 70),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(tester.getSize(find.byType(TdsBoardRow)).height, folded);
  });

  testWidgets(
    'GridList reduces three columns at 160 percent without clipping',
    (tester) async {
      final children = List.generate(
        3,
        (i) => TdsGridListItem(
          image: const SizedBox(width: 24, height: 24),
          label: '항목 $i',
        ),
      );
      await tester.pumpWidget(testApp(TdsGridList(children: children)));
      expect(
        tester.getTopLeft(find.text('항목 0')).dy,
        tester.getTopLeft(find.text('항목 2')).dy,
      );
      await tester.pumpWidget(
        testApp(TdsGridList(children: children), scale: 160),
      );
      expect(
        tester.getTopLeft(find.text('항목 2')).dy,
        greaterThan(tester.getTopLeft(find.text('항목 0')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Chip selected, disabled and inert contracts', (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        TdsChip(
          children: [
            TdsChipItem(text: '활성', selected: true, onPressed: () => taps++),
            TdsChipItem(text: '비활성', disabled: true, onPressed: () => taps++),
            TdsChipItem(text: '제외', inert: true, onPressed: () => taps++),
          ],
        ),
      ),
    );
    await tester.tap(find.text('활성'));
    await tester.tap(find.text('비활성'));
    await tester.tap(find.text('제외'), warnIfMissed: false);
    expect(taps, 1);
    expect(find.bySemanticsLabel('제외'), findsNothing);
    expect(tester.getSize(find.byType(TdsChipItem).first).height, 44);
    semantics.dispose();
  });

  testWidgets(
    'Rating edits integers, readonly never changes, halves use source thresholds',
    (tester) async {
      double? next;
      await tester.pumpWidget(
        testApp(
          Align(
            alignment: Alignment.topLeft,
            child: TdsRating(
              value: 0,
              readOnly: false,
              onValueChange: (value) => next = value,
            ),
          ),
        ),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(TdsRating)) + const Offset(100, 10),
      );
      expect(next, 4);
      next = null;
      await tester.pumpWidget(
        testApp(TdsRating(value: 2.5, onValueChange: (v) => next = v)),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(TdsRating)) + const Offset(10, 10),
      );
      expect(next, isNull);
      final halves = tester
          .widgetList<Align>(
            find.descendant(
              of: find.byType(TdsRating),
              matching: find.byType(Align),
            ),
          )
          .where((w) => w.widthFactor == .5);
      expect(halves.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Skeleton patterns, repetition and disposal cancel delayed animation',
    (tester) async {
      for (final pattern in TdsSkeletonPattern.values) {
        await tester.pumpWidget(
          testApp(TdsSkeleton(pattern: pattern, height: 300)),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        testApp(
          const TdsSkeleton(
            custom: [TdsSkeletonPart(TdsSkeletonModule.list)],
            repeatLastItemCount: 2,
          ),
        ),
      );
      expect(find.byType(TdsSkeletonItem), findsNWidgets(2));
      await tester.pumpWidget(testApp(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FadeIn cancels delayed completion after unmount', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      testApp(
        TdsFadeIn(
          delay: const Duration(seconds: 2),
          onEnd: () => completed++,
          child: const Text('내용'),
        ),
      ),
    );
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pump(const Duration(seconds: 3));
    expect(completed, 0);
    expect(tester.takeException(), isNull);
  });
}
