import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'motion.dart';

/// Timelines extracted from tv/sae/lae in TDS Mobile 2.5.1.
abstract final class TdsListRowMotion {
  static final blinkContentDuration =
      const Duration(milliseconds: 200) + TdsMotion.slow.duration;
  static final blinkEntryDuration = Duration(
    microseconds: math.max(
      (const Duration(milliseconds: 80) + TdsMotion.slow.duration)
          .inMicroseconds,
      (const Duration(milliseconds: 480) + TdsMotion.basic.duration)
          .inMicroseconds,
    ),
  );
  static double _spring(
    Duration elapsed,
    Duration delay,
    TdsSpringCurve spring,
  ) => spring.transform(
    ((elapsed - delay).inMicroseconds / spring.duration.inMicroseconds).clamp(
      0,
      1,
    ),
  );
  static double blinkRadius(Duration elapsed) =>
      _spring(elapsed, const Duration(milliseconds: 80), TdsMotion.slow);
  static double blinkDimmer(Duration elapsed) =>
      _spring(elapsed, const Duration(milliseconds: 480), TdsMotion.basic);
  static double blinkScale(Duration elapsed) {
    const rise = Duration(milliseconds: 200);
    if (elapsed <= rise) {
      return 1 +
          .02 *
              TdsMotion.out.transform(
                (elapsed.inMicroseconds / rise.inMicroseconds).clamp(0, 1),
              );
    }
    return 1.02 - .02 * _spring(elapsed, rise, TdsMotion.slow);
  }

  static Duration shineDuration(bool dark, int playCount) => Duration(
    milliseconds: dark
        ? 2500 * playCount
        : 2200 * playCount + 100 * (playCount - 1),
  );
  static double shineProgress(Duration elapsed, {required bool dark}) =>
      (elapsed.inMicroseconds %
              (dark ? 2500000 : 2300000) /
              (dark ? 2500000 : 2200000))
          .clamp(0, 1);

  // sae/lae pass `easings`/`easing`, but this bundled Framer runtime consumes
  // `ease`. $h -> FEe -> Nh therefore supplies its quadratic ease-in-out.
  static double shineEase(double t) =>
      t <= .5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
  static Rect shineRect(
    Size size,
    Duration elapsed, {
    required bool dark,
    double? translateFromX,
    double? translateToX,
  }) {
    final t = shineEase(shineProgress(elapsed, dark: dark));
    if (dark) {
      return Rect.fromLTWH(
        -3 * size.width * (1 - t),
        0,
        4 * size.width,
        size.height,
      );
    }
    final edge = size.height * 3;
    final from = translateFromX ?? -edge;
    final to = translateToX ?? size.width;
    return Rect.fromLTWH(from + (to - from) * t, -size.height, edge, edge);
  }

  static double shineOpacity(Duration elapsed, {required bool dark}) {
    if (!dark) return 1;
    final t = shineProgress(elapsed, dark: true);
    return t <= .36 ? shineEase(t / .36) : 1 - shineEase((t - .36) / .64);
  }
}
