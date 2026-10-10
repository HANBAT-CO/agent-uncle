import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';

import 'collections_feedback_test.dart' show testApp;

// Expanding flow can safely recover CSS height. Rounded-up painted advances
// still use the pre-existing flow: shrinking these without moving glyphs would
// newly overlap following content. This branch is NOT a CSS parity expectation.
double expectedFlow(double cssHeight, int count) =>
    cssHeight.round() > cssHeight
    ? (count * cssHeight.round() / cssHeight).round() * cssHeight
    : count * cssHeight;

void main() {
  final source =
      jsonDecode(File('reference/visual-geometry.json').readAsStringSync())
          as Map<String, dynamic>;

  setUpAll(() async {
    final loader = FontLoader('packages/tds_mobile_flutter/Toss Product Sans');
    for (final weight in [400, 500, 600, 700]) {
      loader.addFont(
        rootBundle.load(
          'packages/tds_mobile_flutter/assets/fonts/TossProductSans-$weight.ttf',
        ),
      );
    }
    await loader.load();
  });

  testWidgets('long Footer labels recover lost flow without new shrinkage', (
    tester,
  ) async {
    for (final scale in [100.0, 160.0, 200.0]) {
      for (final count in [1, 2, 40, 100]) {
        await tester.pumpWidget(
          testApp(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 342,
                child: TdsListFooterText(
                  child: Text(List.filled(count, '토스 Ag').join('\n')),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        final height = tester
            .widget<TdsLineBox>(find.byType(TdsLineBox))
            .lineHeight;
        final expected = expectedFlow(height, count);
        final reason = '$count lines at $scale%';
        // The engine rounds each native line. Divide by that native advance,
        // not the fractional CSS advance, before restoring CSS flow height.
        expect(paragraph.size.height, height.round() * count, reason: reason);
        expect(box.size.height, expected, reason: reason);
        expect(
          box.getDryLayout(box.constraints).height,
          expected,
          reason: reason,
        );
        expect(box.getMinIntrinsicHeight(342), expected, reason: reason);
        expect(box.getMaxIntrinsicHeight(342), expected, reason: reason);
      }
    }
  });

  for (final weight in TdsFontWeight.values) {
    testWidgets('long block text preserves safe flow (${weight.name})', (
      tester,
    ) async {
      final rows = (source['typography'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (row) => row['weight'] == weight.name && row['multiline'] == false,
          );
      expect(rows, hasLength(60));
      for (final row in rows) {
        for (final count in [40, 100]) {
          await tester.pumpWidget(
            testApp(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 342,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TdsText(
                        List.filled(count, '토스 Ag').join('\n'),
                        typography: TdsTypography.values.byName(
                          row['type'] as String,
                        ),
                        fontWeight: weight,
                      ),
                      const SizedBox(key: ValueKey('following'), height: 8),
                    ],
                  ),
                ),
              ),
              scale: (row['scale'] as num).toDouble(),
            ),
          );
          final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
          final expected = expectedFlow(
            (row['height'] as num).toDouble(),
            count,
          );
          final reason = '${row['type']}/${row['scale']}/$count';
          expect(box.size.height, expected, reason: reason);
          expect(
            box.getDryLayout(box.constraints).height,
            expected,
            reason: reason,
          );
          expect(box.getMinIntrinsicHeight(342), expected, reason: reason);
          expect(box.getMaxIntrinsicHeight(342), expected, reason: reason);
          expect(
            box.getDryBaseline(box.constraints, TextBaseline.alphabetic),
            closeTo((row['baselines'] as List).first as num, .001),
            reason: reason,
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('following'))).dy -
                tester.getTopLeft(find.byType(TdsLineBox)).dy,
            expected,
            reason: reason,
          );
        }
      }
    });
  }

  testWidgets('soft wrapping and ellipsis follow native visible line count', (
    tester,
  ) async {
    final label = List.filled(200, '토스 글자 Ag 012').join(' ');
    for (final scale in [100.0, 160.0]) {
      for (final width in [138.0, 290.0, 210.0]) {
        for (final maxLines in [null, 1, 3, 40]) {
          await tester.pumpWidget(
            testApp(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: TdsText(
                    label,
                    typography: TdsTypography.t7,
                    ellipsisAfterLines: maxLines,
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(RichText),
          );
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
            maxLines: maxLines,
            ellipsis: maxLines == null ? null : '\u2026',
          )..layout(maxWidth: width);
          final count = painter.computeLineMetrics().length;
          expect(count, maxLines ?? greaterThan(40));
          final line = tester.widget<TdsLineBox>(find.byType(TdsLineBox));
          final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
          final expected = expectedFlow(line.lineHeight, count);
          expect(box.size.height, expected);
          expect(box.getDryLayout(box.constraints).height, expected);
          expect(box.getMinIntrinsicHeight(width), expected);
          expect(box.getMaxIntrinsicHeight(width), expected);
          // The wrapper changes flow only. Native shaping/paint is untouched.
          expect(paragraph.size, painter.size);
          painter.dispose();
        }
      }
    }
  });

  testWidgets('rounded-up lines do not introduce a new last-line overlap', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        TdsListFooterText(child: Text(List.filled(100, '토스 Ag').join('\n'))),
        scale: 160,
      ),
    );
    // Native advance: 100 * 34 = 3400. Exact CSS flow is 3379.6875, which
    // overlaps the unchanged last glyphs. Retain the pre-change 3413.484375.
    expect(tester.getSize(find.byType(TdsLineBox)).height, 3413.484375);
  });

  testWidgets('empty and trailing lines retain their native line count', (
    tester,
  ) async {
    for (final entry in {'': 1, '\n': 2, '토스\n\n': 3}.entries) {
      await tester.pumpWidget(
        testApp(TdsText(entry.key, typography: TdsTypography.t7)),
      );
      final line = tester.widget<TdsLineBox>(find.byType(TdsLineBox));
      expect(
        tester.getSize(find.byType(TdsLineBox)).height,
        entry.value * line.lineHeight,
      );
    }
  });

  testWidgets('tight constraints and dry baselines keep native placement', (
    tester,
  ) async {
    for (final baseline in [null, 16.0]) {
      for (final height in [12.0, 80.0]) {
        await tester.pumpWidget(
          testApp(
            SizedBox(
              height: height,
              child: TdsLineBox(
                lineHeight: 19.5,
                baseline: baseline,
                child: const Text(
                  '토스\nAg',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
        );
        final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(box.size.height, height);
        expect(box.getDryLayout(box.constraints), box.size);
        final nativeBaseline = paragraph.getDryBaseline(
          paragraph.constraints,
          TextBaseline.alphabetic,
        )!;
        final actualOffset =
            tester.getTopLeft(find.byType(RichText)).dy -
            tester.getTopLeft(find.byType(TdsLineBox)).dy;
        expect(
          box.getDryBaseline(box.constraints, TextBaseline.alphabetic),
          closeTo(nativeBaseline + actualOffset, .001),
        );
        expect(
          actualOffset,
          closeTo(
            baseline == null
                ? (height - paragraph.size.height) / 2
                : baseline - nativeBaseline,
            .001,
          ),
        );
      }
    }
  });

  testWidgets('subpixel-only line advances do not divide by zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(const TdsLineBox(lineHeight: .25, child: SizedBox(height: 0))),
    );
    final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
    expect(box.size.height, 0);
    expect(box.getDryLayout(box.constraints).height, 0);
    expect(tester.takeException(), isNull);
  });
}
