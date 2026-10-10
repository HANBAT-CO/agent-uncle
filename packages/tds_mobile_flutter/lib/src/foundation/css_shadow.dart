import 'package:flutter/painting.dart';

/// CSS box-shadow blur radius is twice the Gaussian standard deviation.
/// Flutter's ordinary Shadow instead uses radius * 0.57735 + 0.5. Retaining
/// the CSS radius with that conversion makes a 60px shadow too diffuse.
/// Use for static CSS-derived decorations; BoxShadow.lerp does not preserve
/// subclasses and must not be used for interpolating this value.
class TdsCssBoxShadow extends BoxShadow {
  const TdsCssBoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    super.spreadRadius,
    super.blurStyle,
  });
  @override
  double get blurSigma => blurRadius / 2;
  @override
  TdsCssBoxShadow scale(double factor) => TdsCssBoxShadow(
    color: color,
    offset: offset * factor,
    blurRadius: blurRadius * factor,
    spreadRadius: spreadRadius * factor,
    blurStyle: blurStyle,
  );
  @override
  TdsCssBoxShadow copyWith({
    Color? color,
    Offset? offset,
    double? blurRadius,
    double? spreadRadius,
    BlurStyle? blurStyle,
  }) => TdsCssBoxShadow(
    color: color ?? this.color,
    offset: offset ?? this.offset,
    blurRadius: blurRadius ?? this.blurRadius,
    spreadRadius: spreadRadius ?? this.spreadRadius,
    blurStyle: blurStyle ?? this.blurStyle,
  );
}
