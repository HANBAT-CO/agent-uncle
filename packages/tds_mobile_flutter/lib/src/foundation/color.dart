import 'dart:math' as math;
import 'package:flutter/animation.dart';

/// Original Framer color interpolation: squared sRGB channels, linear alpha.
class TdsGammaColorTween extends Tween<Color> {
  TdsGammaColorTween({required Color begin, required Color end})
    : super(begin: begin, end: end);

  @override
  Color lerp(double t) {
    final a = begin!, b = end!;
    double channel(double x, double y) =>
        (math.sqrt((x * x + (y * y - x * x) * t).clamp(0, 1)) * 255).round() /
        255;
    return Color.from(
      alpha: (a.a + (b.a - a.a) * t).clamp(0, 1),
      red: channel(a.r, b.r),
      green: channel(a.g, b.g),
      blue: channel(a.b, b.b),
    );
  }
}

/// OKLCH transformations used by the original button theme generator.
class TdsOklch {
  const TdsOklch(this.l, this.c, this.h, [this.alpha = 1]);
  final double l, c, h, alpha;
  factory TdsOklch.fromColor(Color color) {
    double linear(double v) =>
        v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
    double cubeRoot(double v) => v.sign * math.pow(v.abs(), 1 / 3).toDouble();
    final r = linear(color.r), g = linear(color.g), b = linear(color.b);
    final ll = cubeRoot(.4122214708 * r + .5363325363 * g + .0514459929 * b);
    final mm = cubeRoot(.2119034982 * r + .6806995451 * g + .1073969566 * b);
    final ss = cubeRoot(.0883024619 * r + .2817188376 * g + .6299787005 * b);
    final a = 1.9779984951 * ll - 2.428592205 * mm + .4505937099 * ss;
    final bb = .0259040371 * ll + .7827717662 * mm - .808675766 * ss;
    return TdsOklch(
      .2104542553 * ll + .793617785 * mm - .0040720468 * ss,
      math.sqrt(a * a + bb * bb),
      math.atan2(bb, a),
      color.a,
    );
  }
  Color withLightness(double lightness) {
    final a = c * math.cos(h), b = c * math.sin(h);
    double cube(double v) => v * v * v;
    final ll = cube(lightness + .3963377774 * a + .2158037573 * b);
    final mm = cube(lightness - .1055613458 * a - .0638541728 * b);
    final ss = cube(lightness - .0894841775 * a - 1.291485548 * b);
    double gamma(double v) =>
        (v <= .0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - .055)
            .toDouble()
            .clamp(0, 1);
    return Color.from(
      alpha: alpha,
      red: gamma(4.0767416621 * ll - 3.3077115913 * mm + .2309699292 * ss),
      green: gamma(-1.2684380046 * ll + 2.6097574011 * mm - .3413193965 * ss),
      blue: gamma(-.0041960863 * ll - .7034186147 * mm + 1.707614701 * ss),
    );
  }
}
