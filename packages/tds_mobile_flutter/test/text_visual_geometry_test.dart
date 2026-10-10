import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  final sourceMetrics =
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

  testWidgets('replacement fonts do not get a Toss-specific baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const TdsText(
          '다른 폰트',
          style: TextStyle(fontFamily: 'Ahem', fontSize: 20, height: 1.5),
        ),
      ),
    );
    expect(tester.widget<TdsLineBox>(find.byType(TdsLineBox)).baseline, isNull);
  });

  testWidgets('Footer retains styled and mixed child text metrics', (
    tester,
  ) async {
    for (final child in [
      const Text('사용자 폰트', style: TextStyle(fontFamily: 'Ahem', fontSize: 20)),
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '작게'),
            TextSpan(text: '크게', style: TextStyle(fontSize: 32)),
          ],
        ),
      ),
    ]) {
      await tester.pumpWidget(testApp(TdsListFooterText(child: child)));
      expect(
        tester.widget<TdsLineBox>(find.byType(TdsLineBox)).baseline,
        isNull,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final weight in TdsFontWeight.values) {
    testWidgets(
      'block text uses the original first-line baseline (${weight.name})',
      (tester) async {
        // Original DOM specimens for every type, four weights, three scales and
        // one/two lines. Baselines are relative to Text display="block".
        final allRows = (sourceMetrics['typography'] as List)
            .cast<Map<String, dynamic>>();
        final rows = allRows.where((row) => row['weight'] == weight.name);
        expect(sourceMetrics['source'], '@toss/tds-mobile@2.5.1');
        expect(allRows, hasLength(480));
        expect(rows, hasLength(120));
        expect(
          rows
              .map((row) => (row['type'], row['scale'], row['multiline']))
              .toSet(),
          {
            for (final type in TdsTypography.values)
              for (final scale in [100, 160, 200])
                for (final multiline in [false, true])
                  (type.name, scale, multiline),
          },
          reason: 'Regenerate every original specimen with --all',
        );
        for (final row in rows) {
          final type = TdsTypography.values.byName(row['type'] as String);
          await tester.pumpWidget(
            testApp(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 342,
                  child: TdsText(
                    row['multiline'] as bool
                        ? '토스 Ag 012\n둘째 줄 xyz'
                        : '토스 Ag 012',
                    typography: type,
                    fontWeight: weight,
                  ),
                ),
              ),
              scale: (row['scale'] as num).toDouble(),
            ),
          );
          final render = tester.renderObject<RenderBox>(
            find.byType(TdsLineBox),
          );
          expect(
            render.getDryBaseline(render.constraints, TextBaseline.alphabetic),
            closeTo((row['baselines'] as List).first as num, .001),
            reason: '${type.name}/${row['scale']}/${row['multiline']}',
          );
          expect(render.size.width, row['width']);
          expect(render.size.height, row['height']);
        }
      },
    );

    testWidgets(
      'Footer text preserves the source xs baseline and fractional flow (${weight.name})',
      (tester) async {
        for (final row
            in (sourceMetrics['footer'] as List).cast<Map<String, dynamic>>()) {
          final scale = (row['scale'] as num).toDouble();
          await tester.pumpWidget(
            testApp(
              TdsListFooterText(fontWeight: weight, child: const Text('바깥')),
              scale: scale,
            ),
          );
          final render = tester.renderObject<RenderBox>(
            find.byType(TdsLineBox),
          );
          expect(render.size.height, row['lineHeight']);
          expect(
            render.getDryBaseline(render.constraints, TextBaseline.alphabetic),
            closeTo(row['baseline'] as num, .001),
          );
        }
      },
    );
  }

  testWidgets(
    'inline Footer label keeps the parent strut and top-aligned arrow',
    (tester) async {
      for (final scale in [100.0, 160.0]) {
        await tester.pumpWidget(
          testApp(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                TdsInlineMiddle(child: TdsListFooterText(child: Text('바깥'))),
                SizedBox(key: ValueKey('arrow'), width: 24, height: 24),
              ],
            ),
            scale: scale,
          ),
        );
        final row = tester.getRect(find.byType(Row));
        final line = tester.getRect(find.byType(TdsLineBox));
        expect(row.height, scale == 100 ? 24.4375 : 33.796875);
        expect(line.top - row.top, scale == 100 ? 3.15625 : 0);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('arrow'))).dy,
          row.top,
        );
      }
    },
  );

  testWidgets('Footer wraps whole Korean words like Paragraph.Text', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 210,
            child: TdsListFooter(
              iconName: 'icon-arrow-right-mono',
              child: const Text('글자와 화살표의 위치를 확인하고 다음 안내를 읽어요'),
            ),
          ),
        ),
      ),
    );
    final render = tester.renderObject<RenderParagraph>(find.byType(RichText));
    final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
    // Source: three lines, 138px text slot, each line 21.28125px tall.
    expect(box.size, const Size(138, 63.84375));
    final text = render.text.toPlainText();
    for (final word in ['글자와', '화살표의', '위치를', '확인하고', '다음', '안내를', '읽어요']) {
      final joined = word.split('').join('\u2060');
      expect(text, contains(joined));
    }
  });
}
