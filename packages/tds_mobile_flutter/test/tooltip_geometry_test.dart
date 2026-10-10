import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/css_shadow.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  test(
    'CSS shadow uses sigma half the radius, including copied/scaled shadows',
    () {
      const shadow = TdsCssBoxShadow(blurRadius: 60, offset: Offset(0, 16));
      expect(shadow.blurSigma, 30);
      expect(shadow.copyWith(blurRadius: 20).blurSigma, 10);
      expect(shadow.scale(2).blurSigma, 60);
      expect(shadow.scale(2).offset, const Offset(0, 32));
    },
  );
  testWidgets(
    'plain tooltip text retains fractional source line boxes at all sizes and scales',
    (tester) async {
      for (final size in TdsTooltipSize.values) {
        for (final scale in [100.0, 160.0, 200.0]) {
          await tester.pumpWidget(
            testApp(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  child: TdsTooltipContent(
                    size: size,
                    child: const Text('도움말'),
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          final typography = [
            TdsTypography.t7,
            TdsTypography.t6,
            TdsTypography.t5,
          ][size.index];
          final line = TdsPlatform(
            os: TdsOS.android,
            fontScale: scale,
          ).lineHeight(typography);
          expect(
            tester.getSize(find.byType(TdsTooltipContent)).height,
            line + (size == TdsTooltipSize.small ? 16 : 26),
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
  final original =
      (jsonDecode(File('reference/compound-constants.json').readAsStringSync())
              as Map)['tooltipArrows']
          as Map;
  testWidgets(
    'all 18 clipped size/side arrows preserve original SVG path, size and offset',
    (tester) async {
      for (final size in TdsTooltipSize.values) {
        for (final clip in TdsTooltipClip.values) {
          for (final placement in [
            TdsOverlayPlacement.top,
            TdsOverlayPlacement.bottom,
          ]) {
            final top = placement == TdsOverlayPlacement.top;
            final shape = clip == TdsTooltipClip.none
                ? 'none'
                : (clip == TdsTooltipClip.left) != top
                ? 'left'
                : 'right';
            final source = original['$shape-${size.name}'] as Map;
            final width = (source['width'] as num).toDouble();
            final translate = double.parse(
              RegExp(r'\d+')
                  .firstMatch((source['style'] as Map)['transform'] as String)!
                  .group(0)!,
            );
            await tester.pumpWidget(
              testApp(
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 200,
                    child: TdsTooltipContent(
                      size: size,
                      placement: placement,
                      clipToEnd: clip,
                      child: const Text('도움말'),
                    ),
                  ),
                ),
              ),
            );
            final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
            expect(svg.width, width);
            expect(svg.height, width);
            expect(
              (svg.bytesLoader as SvgStringLoader).provideSvg(null),
              contains('d="${source['d']}"'),
            );
            final positioned = tester.widget<Positioned>(
              find
                  .ancestor(
                    of: find.byType(SvgPicture),
                    matching: find.byType(Positioned),
                  )
                  .first,
            );
            expect(positioned.left, (200 - width) / 2);
            expect(top ? positioned.bottom : positioned.top, translate - width);
            final matrix = tester
                .widget<Transform>(
                  find
                      .ancestor(
                        of: find.byType(SvgPicture),
                        matching: find.byType(Transform),
                      )
                      .first,
                )
                .transform;
            expect(matrix.storage[0], closeTo(top ? -1 : 1, .000001));
            expect(matrix.storage[5], closeTo(top ? -1 : 1, .000001));
          }
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'arrow ratio uses CSS center calculation and 16px / zero clamps',
    (tester) async {
      for (final clip in TdsTooltipClip.values) {
        for (final ratio in [-1.0, 0.0, .25, .5, .75, 1.0, 2.0]) {
          await tester.pumpWidget(
            testApp(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  child: TdsTooltipContent(
                    clipToEnd: clip,
                    anchorPositionByRatio: ratio,
                    child: const Text('설명'),
                  ),
                ),
              ),
            ),
          );
          final arrow = tester.widget<SvgPicture>(find.byType(SvgPicture));
          final width = arrow.width!;
          final p = clip == TdsTooltipClip.none ? 16.0 : 0.0;
          final expected = ratio == .5
              ? (200 - width) / 2
              : math.max(p, math.min(200 * ratio - width / 2, 200 - width - p));
          final positioned = tester.widget<Positioned>(
            find
                .ancestor(
                  of: find.byType(SvgPicture),
                  matching: find.byType(Positioned),
                )
                .first,
          );
          expect(positioned.left, expected);
        }
      }
    },
  );
}
