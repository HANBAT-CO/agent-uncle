import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'motion.dart';

/// Literal fre/_R geometry. Closing/expansion use displacement, not velocity.
abstract final class TdsSheetMotion {
  static Offset dragTranslation(Offset displacement) {
    final x = math.max(0.0, math.log((displacement.dx.abs() + 10) / 15) * 5);
    final up = math.max(0.0, math.log((displacement.dy.abs() + 10) / 15) * 15);
    return Offset(
      displacement.dx.sign * x,
      displacement.dy < 0 ? -up : displacement.dy,
    );
  }

  static double normalDimmer(bool dark) => dark ? .56 : .2;
  static double dimmer(Offset displacement, double height, bool dark) {
    final normal = normalDimmer(dark);
    if (displacement.dy <= -50) return dark ? .8 : .4;
    if (displacement.dy >= 10 && height > 0) {
      return (normal * (1 - displacement.dy / height)).clamp(0, 1);
    }
    return normal;
  }

  static Duration get exitDuration =>
      TdsMotion.quick.duration > TdsMotion.rapid.duration
      ? TdsMotion.quick.duration
      : TdsMotion.rapid.duration;

  static double exitProgress(double reverseValue, TdsSpringCurve spring) =>
      spring.transform(
        ((1 - reverseValue) *
                exitDuration.inMicroseconds /
                spring.duration.inMicroseconds)
            .clamp(0.0, 1.0),
      );
}

/// Route-owned channel for the inner sheet's drag-driven dimmer animation.
class TdsSheetDimmerScope extends InheritedWidget {
  const TdsSheetDimmerScope({
    required this.opacity,
    required super.child,
    super.key,
  });
  final ValueNotifier<double?> opacity;
  static ValueNotifier<double?>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TdsSheetDimmerScope>()
      ?.opacity;
  @override
  bool updateShouldNotify(TdsSheetDimmerScope oldWidget) =>
      oldWidget.opacity != opacity;
}
