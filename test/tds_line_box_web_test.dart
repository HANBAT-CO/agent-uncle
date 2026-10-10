import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
import 'package:tds_mobile_flutter/src/foundation/text_underline.dart';

// Run with: flutter test --platform chrome test/tds_line_box_web_test.dart
// The package's VM matrix reads the original metrics JSON from disk. Keep this
// browser check separate so it actually exercises CanvasKit, not flutter_tester.
// Import only the rendering foundations here: Flutter's test server intercepts any
// URL ending in /host.dart.js, including the package's unrelated host adapter.
// The browser runner does not serve bundled assets. Use its built-in Ahem face
// to isolate native line rounding; VM and native integration load the Toss faces.
void main() {
  testWidgets('Chrome restores long uniform text flow', (tester) async {
    // Representative original xs CSS heights for these resolved font sizes.
    for (final specimen in [
      (17.0, 21.28125),
      (27.0, 33.796875),
      (35.0, 43.8125),
    ]) {
      for (final count in [40, 100]) {
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xffffffff),
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 342,
                  child: TdsLineBox(
                    lineHeight: specimen.$2,
                    child: Text(
                      List.filled(count, '토스 Ag').join('\n'),
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: specimen.$1,
                        height: specimen.$2 / specimen.$1,
                        fontWeight: FontWeight.w500,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
        final cssHeight = specimen.$2;
        // Preserve pre-existing flow when native baselines advance farther than
        // CSS. Exact CSS shrinkage would introduce overlap; this is not parity.
        final expected = cssHeight.round() > cssHeight
            ? (count * cssHeight.round() / cssHeight).round() * cssHeight
            : cssHeight * count;
        expect(box.size.height, expected);
        expect(box.getDryLayout(box.constraints).height, expected);
        expect(box.getMinIntrinsicHeight(342), expected);
        expect(box.getMaxIntrinsicHeight(342), expected);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        // A flow-height check is not a claim that each painted line matches CSS.
        expect(paragraph.size.height, specimen.$2.round() * count);
      }
    }
  }, skip: !kIsWeb);

  testWidgets('Chrome preserves blank lines in underline placement', (
    tester,
  ) async {
    for (final fontSize in [17.0, 27.0, 35.0]) {
      final height = tdsCssLineHeight(fontSize * 1.252);
      final baseline = tdsCssTextBaseline(fontSize, height);
      for (final leading in [0, 1, 2]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: TdsLineBox(
                lineHeight: height,
                baseline: baseline,
                child: TdsTextUnderline(
                  fontSize: fontSize,
                  color: const Color(0xff000000),
                  child: Text(
                    '${'\n' * leading}Ag\n\nxyz',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: fontSize,
                      height: 1.252,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
        final underline = tester.renderObject<RenderTdsTextUnderline>(
          find.byType(TdsTextUnderline),
        );
        final origin = underline.localToGlobal(Offset.zero, ancestor: box);
        final rects = underline.underlineRects;
        expect(rects, hasLength(2));
        for (var i = 0; i < rects.length; i++) {
          expect(
            rects[i].top + origin.dy,
            closeTo(
              baseline + (leading + i * 2) * height + fontSize * 534 / 2564 + 1,
              .001,
            ),
          );
        }
      }
    }
  }, skip: !kIsWeb);
}
