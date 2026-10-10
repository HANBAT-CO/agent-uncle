import 'package:flutter/widgets.dart';
import '../foundation/list_row_scope.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'asset_frames.g.dart';
import 'list_compounds.dart';

enum TdsListRowAssetSize { xsmall, small, medium, large, xlarge, xxlarge }

enum TdsListRowAssetShape { squircle, card, original, square, circle }

enum TdsListRowAssetIconShape {
  squircle,
  card,
  original,
  circleBackground,
  circleMasking,
}

enum TdsListRowAssetIconVariant { none, fill }

const _suffixes = ['XSmall', 'Small', 'Medium', 'Large', 'XLarge', '2XLarge'];
const _cardPadding = [2.0, 3.0, 4.0, 4.0, 5.0, 6.0];

TdsAssetFrameShape _frame(
  TdsListRowAssetShape shape,
  TdsListRowAssetSize size, {
  bool image = false,
  bool lottie = false,
}) {
  if (shape == TdsListRowAssetShape.original) {
    return TdsAssetFrameShape(height: lottie ? 40 : 56, transparent: true);
  }
  if (image || lottie) {
    if (shape == TdsListRowAssetShape.circle) return TdsAssetFrames.circleLarge;
    if (shape == TdsListRowAssetShape.square) {
      return TdsAssetFrames.squareXLarge;
    }
  }
  final prefix = switch (shape) {
    TdsListRowAssetShape.squircle => 'Squircle',
    TdsListRowAssetShape.card => 'Card',
    TdsListRowAssetShape.square => 'Square',
    TdsListRowAssetShape.circle => 'Circle',
    TdsListRowAssetShape.original => throw StateError('Handled above'),
  };
  return TdsAssetFrames.values['$prefix${_suffixes[size.index]}']!;
}

Widget Function(Widget)? _mask(bool squircle, TdsListRowAssetSize size) =>
    squircle
    ? (child) => TdsSquircleMasking(
        size: TdsSquircleSize.values[size.index],
        child: child,
      )
    : null;

Widget _layout(
  BuildContext context,
  Widget child,
  TdsAssetFrameShape frame,
  TdsListRowAssetSize size, {
  required bool cardPadding,
  String? alt,
}) => Semantics(
  label: alt,
  image: alt != null,
  excludeSemantics: true,
  child: Padding(
    padding: EdgeInsets.only(
      top: TdsListRowSlotScope.marginFor(
        context,
        frame.height ?? frame.width ?? 0,
      ),
      left: cardPadding ? _cardPadding[size.index] : 0,
      right: cardPadding ? _cardPadding[size.index] : 0,
    ),
    child: child,
  ),
);

/// ListRow.AssetIcon: source shape-specific scaling and fixed circle frames.
class TdsListRowAssetIcon extends StatelessWidget {
  const TdsListRowAssetIcon({
    this.name,
    this.src,
    this.url,
    this.alt,
    this.package,
    this.color,
    this.backgroundColor,
    this.shape = TdsListRowAssetIconShape.squircle,
    this.size = TdsListRowAssetSize.small,
    this.variant = TdsListRowAssetIconVariant.none,
    this.paddingX = false,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    super.key,
  }) : assert(
         size == TdsListRowAssetSize.xsmall ||
             size == TdsListRowAssetSize.small ||
             size == TdsListRowAssetSize.medium,
       );
  final String? name, src, url, alt, package;
  final Color? color, backgroundColor;
  final TdsListRowAssetIconShape shape;
  final TdsListRowAssetSize size;
  final TdsListRowAssetIconVariant variant;
  final bool paddingX, accessoryMasking;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;

  @override
  Widget build(BuildContext context) {
    final squircle = shape == TdsListRowAssetIconShape.squircle;
    final card = shape == TdsListRowAssetIconShape.card;
    final frame = switch (shape) {
      TdsListRowAssetIconShape.original => [
        TdsAssetFrames.cleanW24,
        TdsAssetFrames.cleanW30,
        TdsAssetFrames.cleanW36,
      ][size.index],
      TdsListRowAssetIconShape.circleBackground ||
      TdsListRowAssetIconShape.circleMasking => TdsAssetFrames.circleLarge,
      _ => _frame(
        card ? TdsListRowAssetShape.card : TdsListRowAssetShape.squircle,
        size,
      ),
    };
    final fill = variant == TdsListRowAssetIconVariant.fill;
    final scale = switch (shape) {
      TdsListRowAssetIconShape.squircle => fill ? 1.0 : .66,
      TdsListRowAssetIconShape.circleBackground => .66,
      TdsListRowAssetIconShape.card => fill ? 1.5 : .7,
      _ => 1.0,
    };
    final source = src ?? url;
    final Widget child = source != null
        ? TdsAssetImage(
            src: source,
            package: package,
            frameShape: frame,
            scale: scale,
            scaleType: scale == 1
                ? TdsAssetScaleType.fill
                : TdsAssetScaleType.fit,
            backgroundColor: backgroundColor,
            accessory: accessory,
            accessoryPosition: accessoryPosition,
            accessoryMasking: accessoryMasking,
            contentMasker: _mask(squircle, size),
          )
        : name != null
        ? TdsAssetIcon(
            name: name!,
            color: color,
            frameShape: frame,
            scale: scale,
            backgroundColor: backgroundColor,
            accessory: accessory,
            accessoryPosition: accessoryPosition,
            accessoryMasking: accessoryMasking,
            contentMasker: _mask(squircle, size),
          )
        : const SizedBox.shrink();
    return _layout(
      context,
      child,
      frame,
      size,
      cardPadding: card && paddingX,
      alt: alt,
    );
  }
}

class TdsListRowAssetImage extends StatelessWidget {
  const TdsListRowAssetImage({
    required this.src,
    this.alt,
    this.package,
    this.shape = TdsListRowAssetShape.squircle,
    this.size = TdsListRowAssetSize.small,
    this.paddingX = false,
    this.frameShape,
    this.scale = 1,
    this.scaleType,
    this.backgroundColor,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    super.key,
  }) : assert(frameShape == null || shape == TdsListRowAssetShape.original);
  final String src;
  final String? alt, package;
  final TdsListRowAssetShape shape;
  final TdsListRowAssetSize size;
  final bool paddingX, accessoryMasking;
  final TdsAssetFrameShape? frameShape;
  final double scale;
  final TdsAssetScaleType? scaleType;
  final Color? backgroundColor;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  @override
  Widget build(BuildContext context) {
    final frame = frameShape ?? _frame(shape, size, image: true);
    final card = shape == TdsListRowAssetShape.card;
    return _layout(
      context,
      TdsAssetImage(
        src: src,
        package: package,
        frameShape: frame,
        scale: scale,
        scaleType:
            scaleType ??
            (card ? TdsAssetScaleType.fill : TdsAssetScaleType.fit),
        backgroundColor: backgroundColor,
        accessory: accessory,
        accessoryPosition: accessoryPosition,
        accessoryMasking: accessoryMasking,
        contentMasker: _mask(shape == TdsListRowAssetShape.squircle, size),
      ),
      frame,
      size,
      cardPadding: card && paddingX,
      alt: alt,
    );
  }
}

class TdsListRowAssetText extends StatelessWidget {
  const TdsListRowAssetText(
    this.text, {
    this.shape = TdsListRowAssetShape.squircle,
    this.size = TdsListRowAssetSize.small,
    this.paddingX = false,
    this.backgroundColor,
    this.color,
    this.alt,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    super.key,
  }) : assert(
         shape == TdsListRowAssetShape.squircle ||
             shape == TdsListRowAssetShape.card,
       );
  final String text;
  final String? alt;
  final TdsListRowAssetShape shape;
  final TdsListRowAssetSize size;
  final bool paddingX, accessoryMasking;
  final Color? backgroundColor, color;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final frame = _frame(shape, size);
    return _layout(
      context,
      TdsAssetText(
        text,
        frameShape: frame,
        color: color ?? theme.color('blue500'),
        backgroundColor: backgroundColor ?? theme.color('greyOpacity100'),
        style: TextStyle(
          fontSize: [10.0, 11.0, 13.0, 15.0, 16.0, 17.0][size.index],
          fontWeight: FontWeight.bold,
        ),
        accessory: accessory,
        accessoryPosition: accessoryPosition,
        accessoryMasking: accessoryMasking,
        contentMasker: _mask(shape == TdsListRowAssetShape.squircle, size),
      ),
      frame,
      size,
      cardPadding: shape == TdsListRowAssetShape.card && paddingX,
      alt: alt,
    );
  }
}

class TdsListRowAssetLottie extends StatelessWidget {
  const TdsListRowAssetLottie({
    required this.src,
    this.alt,
    this.package,
    this.shape = TdsListRowAssetShape.squircle,
    this.size = TdsListRowAssetSize.small,
    this.paddingX = false,
    this.backgroundColor,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.repeat = true,
    this.animate = true,
    this.controller,
    super.key,
  });
  final String src;
  final String? alt, package;
  final TdsListRowAssetShape shape;
  final TdsListRowAssetSize size;
  final bool paddingX, accessoryMasking, repeat, animate;
  final Color? backgroundColor;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final AnimationController? controller;
  @override
  Widget build(BuildContext context) {
    final frame = _frame(shape, size, lottie: true);
    final original = shape == TdsListRowAssetShape.original;
    final card = shape == TdsListRowAssetShape.card;
    return _layout(
      context,
      TdsAssetLottie(
        src: src,
        package: package,
        frameShape: frame,
        scale: original
            ? 1
            : card
            ? .7
            : .66,
        backgroundColor: original
            ? const Color(0x00000000)
            : backgroundColor ?? TdsTheme.of(context).color('greyOpacity100'),
        repeat: repeat,
        animate: animate,
        controller: controller,
        accessory: accessory,
        accessoryPosition: accessoryPosition,
        accessoryMasking: accessoryMasking,
        contentMasker: _mask(shape == TdsListRowAssetShape.squircle, size),
      ),
      frame,
      size,
      cardPadding: card && paddingX,
      alt: alt,
    );
  }
}

class TdsListRowLeftContainer extends StatelessWidget {
  const TdsListRowLeftContainer({
    required this.height,
    required this.child,
    this.width,
    this.marginTop,
    super.key,
  }) : assert(height >= 0);
  final Widget child;
  final double height;
  final double? width, marginTop;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: marginTop ?? TdsListRowSlotScope.marginFor(context, height),
    ),
    child: SizedBox(
      width: width,
      height: height,
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    ),
  );
}

enum TdsListRowFillIconShape {
  plain,
  squircle,
  circleBackground,
  circleMasking,
}

class TdsListRowFillIcon extends StatelessWidget {
  const TdsListRowFillIcon({
    this.name,
    this.url,
    this.alt,
    this.color,
    this.package,
    this.shape = TdsListRowFillIconShape.plain,
    this.size = TdsListRowIconSize.medium,
    super.key,
  }) : assert((name == null) != (url == null));
  final String? name, url, alt, package;
  final Color? color;
  final TdsListRowFillIconShape shape;
  final TdsListRowIconSize size;
  @override
  Widget build(BuildContext context) {
    final dimension = switch (shape) {
      TdsListRowFillIconShape.plain => 24.0,
      TdsListRowFillIconShape.squircle =>
        size == TdsListRowIconSize.medium ? 30.0 : 36.0,
      _ => 40.0,
    };
    final iconSize = shape == TdsListRowFillIconShape.circleBackground
        ? 20.0
        : dimension;
    Widget child = SizedBox.square(
      dimension: iconSize,
      child: url != null
          ? TdsAssetImage(
              src: url!,
              package: package,
              backgroundColor: const Color(0x00000000),
              frameShape: TdsAssetFrameShape(width: iconSize, height: iconSize),
            )
          : TdsAssetIcon(name: name!, color: color, size: iconSize),
    );
    if (shape == TdsListRowFillIconShape.circleBackground) {
      child = ColoredBox(
        color: TdsTheme.of(context).color('grey100'),
        child: Center(child: child),
      );
    }
    if (shape == TdsListRowFillIconShape.squircle) {
      child = ClipPath(clipper: _FillSquircleClipper(size), child: child);
    } else if (shape != TdsListRowFillIconShape.plain) {
      child = ClipOval(child: child);
    }
    return TdsListRowLeftContainer(
      height: dimension,
      width: dimension,
      child: Semantics(
        label: alt,
        image: alt != null,
        excludeSemantics: true,
        child: child,
      ),
    );
  }
}

class _FillSquircleClipper extends CustomClipper<Path> {
  const _FillSquircleClipper(this.type);
  final TdsListRowIconSize type;
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final shift = type == TdsListRowIconSize.large ? .5 : 0.0;
    return (Path()
          ..moveTo(0, h * .482)
          ..cubicTo(0, h * .099, w * .099, 0, w * .482, 0)
          ..lineTo(w * .518, 0)
          ..cubicTo(w * .901, 0, w, h * .099, w, h * .482)
          ..lineTo(w, h * .518)
          ..cubicTo(w, h * .901, w * .901, h, w * .518, h)
          ..lineTo(w * .482, h)
          ..cubicTo(w * .099, h, 0, h * .901, 0, h * .518)
          ..close())
        .shift(Offset(0, shift));
  }

  @override
  bool shouldReclip(_FillSquircleClipper oldClipper) => type != oldClipper.type;
}
