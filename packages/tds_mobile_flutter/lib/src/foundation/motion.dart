import 'package:flutter/animation.dart';

/// Original TDS uses RK4 spring integration at 60Hz, with a .01 rest threshold.
/// Sampling this curve preserves its timing (a generic ease curve would not).
class TdsSpringCurve extends Curve {
  TdsSpringCurve({
    required double stiffness,
    required double damping,
    double velocity = 0,
  }) {
    var x = -1.0;
    var v = velocity;
    const dt = 1 / 60;
    _values.add(0);
    for (var i = 0; i < 3600; i++) {
      double acceleration(double position, double speed) =>
          -stiffness * position - damping * speed;
      final ax = v, av = acceleration(x, v);
      final bx = v + av * dt / 2,
          bv = acceleration(x + ax * dt / 2, v + av * dt / 2);
      final cx = v + bv * dt / 2,
          cv = acceleration(x + bx * dt / 2, v + bv * dt / 2);
      final dx = v + cv * dt, dv = acceleration(x + cx * dt, v + cv * dt);
      x += dt / 6 * (ax + 2 * bx + 2 * cx + dx);
      v += dt / 6 * (av + 2 * bv + 2 * cv + dv);
      _values.add(1 + x);
      if (x.abs() < .01 && v.abs() < .01) break;
    }
  }
  final _values = <double>[];
  Duration get duration =>
      Duration(microseconds: ((_values.length - 1) / 60 * 1000000).round());
  @override
  double transformInternal(double t) =>
      _values[(t * (_values.length - 1)).floor().clamp(0, _values.length - 2) +
          1];
}

abstract final class TdsMotion {
  static final basic = TdsSpringCurve(stiffness: 200, damping: 30);
  static final small = TdsSpringCurve(stiffness: 480, damping: 50);
  static final quick = TdsSpringCurve(stiffness: 800, damping: 55);
  static final medium = TdsSpringCurve(stiffness: 270, damping: 25);
  static final large = TdsSpringCurve(stiffness: 100, damping: 15);
  static final slow = TdsSpringCurve(stiffness: 70, damping: 20);
  static final rapid = TdsSpringCurve(stiffness: 1000, damping: 55);
  static final bounce = TdsSpringCurve(stiffness: 300, damping: 15);
  static const out = Cubic(.25, .1, .25, 1);
  static const expo = Cubic(.16, 1, .3, 1);
  static const back = Cubic(.34, 1.56, .64, 1);
}
