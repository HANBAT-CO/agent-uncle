// Public constructor names must stay stable; nullable private storage retains
// source optional-field presence separately from non-null public getters.
// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import '../foundation/theme.dart';
import 'text.dart';

enum TdsAssetScaleType { fit, fill }

enum TdsAssetAccessoryPosition {
  topLeft('top-left'),
  topRight('top-right'),
  bottomLeft('bottom-left'),
  bottomRight('bottom-right');

  const TdsAssetAccessoryPosition(this.value);
  final String value;
}

@immutable
class TdsAssetFrameShape {
  const TdsAssetFrameShape({
    this.width,
    this.height,
    double? radius,
    bool? transparent,
    this.accessorySize,
    Offset? accessoryOffset,
    Offset? overlapOffset,
    double? overlapBlur,
    double? overlapSpread,
  }) : _radius = radius,
       _transparent = transparent,
       _accessoryOffset = accessoryOffset,
       _overlapOffset = overlapOffset,
       _overlapBlur = overlapBlur,
       _overlapSpread = overlapSpread;
  final double? width, height;
  final bool? _transparent;
  final double? _radius, _overlapBlur, _overlapSpread;
  final Offset? _accessoryOffset, _overlapOffset;
  final Size? accessorySize;
  double get radius => _radius ?? 0;
  double get overlapBlur => _overlapBlur ?? 0;
  double get overlapSpread => _overlapSpread ?? 0;
  Offset get accessoryOffset => _accessoryOffset ?? Offset.zero;
  Offset get overlapOffset => _overlapOffset ?? Offset.zero;

  TdsAssetFrameShape withDefaultSize(
    double defaultWidth,
    double defaultHeight,
  ) => TdsAssetFrameShape(
    width: width ?? defaultWidth,
    height: height ?? defaultHeight,
    radius: _radius,
    transparent: _transparent,
    accessorySize: accessorySize,
    accessoryOffset: _accessoryOffset,
    overlapOffset: _overlapOffset,
    overlapBlur: _overlapBlur,
    overlapSpread: _overlapSpread,
  );

  // Original Frame compares the whole shape to G4e's clean literals. A
  // structurally identical custom shape is clean too, but {width:24,radius:0}
  // is not equal to {width:24}. Preserve optional-field presence for that case.
  bool get transparent =>
      _transparent ??
      (_radius == null &&
          accessorySize == null &&
          _accessoryOffset == null &&
          _overlapOffset == null &&
          _overlapBlur == null &&
          _overlapSpread == null &&
          ((height == null &&
                  const [
                    16.0,
                    20.0,
                    24.0,
                    30.0,
                    32.0,
                    36.0,
                    40.0,
                    60.0,
                    double.infinity,
                  ].contains(width)) ||
              (width == null &&
                  const [24.0, 32.0, 60.0, 100.0].contains(height))));
}

class TdsAssetFrame extends StatelessWidget {
  const TdsAssetFrame({
    required this.content,
    this.shape = const TdsAssetFrameShape(),
    this.backgroundColor,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.overlapColor,
    this.contentMasker,
    super.key,
  });
  final Widget content;
  final TdsAssetFrameShape shape;
  final Color? backgroundColor, overlapColor;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final bool accessoryMasking;
  final Widget Function(Widget child)? contentMasker;
  @override
  Widget build(BuildContext context) {
    final right =
        accessoryPosition == TdsAssetAccessoryPosition.topRight ||
        accessoryPosition == TdsAssetAccessoryPosition.bottomRight;
    final top =
        accessoryPosition == TdsAssetAccessoryPosition.topRight ||
        accessoryPosition == TdsAssetAccessoryPosition.topLeft;
    Widget child = Container(
      width: shape.width,
      height: shape.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: shape.transparent
            ? const Color(0x00000000)
            : backgroundColor ?? TdsTheme.of(context).color('grey100'),
        borderRadius: BorderRadius.circular(shape.radius),
        boxShadow: overlapColor == null
            ? null
            : [
                BoxShadow(
                  color: overlapColor!,
                  offset: shape.overlapOffset,
                  blurRadius: shape.overlapBlur,
                  spreadRadius: shape.overlapSpread,
                ),
              ],
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: content),
    );
    if (accessoryMasking) {
      child = ClipPath(
        clipper: _AccessoryMask(shape, top: top, right: right),
        child: child,
      );
    }
    child = contentMasker?.call(child) ?? child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (accessory != null)
          Positioned(
            top: top ? shape.accessoryOffset.dy : null,
            bottom: top ? null : shape.accessoryOffset.dy,
            right: right ? shape.accessoryOffset.dx : null,
            left: right ? null : shape.accessoryOffset.dx,
            width: shape.accessorySize?.width ?? 0,
            height: shape.accessorySize?.height ?? 0,
            child: accessory!,
          ),
      ],
    );
  }
}

class _AccessoryMask extends CustomClipper<Path> {
  const _AccessoryMask(this.shape, {required this.top, required this.right});
  final TdsAssetFrameShape shape;
  final bool top, right;
  @override
  Path getClip(Size size) {
    final radius = (shape.accessorySize?.width ?? 0) / 2;
    final center = Offset(
      right
          ? size.width - shape.accessoryOffset.dx - radius
          : shape.accessoryOffset.dx + radius,
      top
          ? shape.accessoryOffset.dy + radius
          : size.height - shape.accessoryOffset.dy - radius,
    );
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius + 1)),
    );
  }

  @override
  bool shouldReclip(_AccessoryMask oldClipper) =>
      shape != oldClipper.shape ||
      top != oldClipper.top ||
      right != oldClipper.right;
}

class TdsAssetIcon extends StatelessWidget {
  static const bundled = {
    'icn-arrow-rightwards',
    'icon-arrow-down-mono',
    'icon-arrow-right-small-mono',
    'icon-arrow-right-mono',
    'icon-arrow-up-mono',
    'icon-arrow-up-sidebar-mono',
    'icon-x-circle-mono',
    'icon-eye-on-mono',
    'icon-eye-off-mono',
    'icn-searchfield',
    'icn-delete',
    'icon-star-mono',
    'icon-chip-arrow-down-mono',
    'icon-chip-x-mono',
    'icon-system-arrow-back-ios-outlined',
    'icon-system-arrow-back-android-outlined',
  };
  const TdsAssetIcon({
    required this.name,
    this.color,
    this.alt,
    this.size = 24,
    this.frameShape,
    this.scaleType = TdsAssetScaleType.fit,
    this.scale = 1,
    this.backgroundColor = const Color(0x00000000),
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.contentMasker,
    super.key,
  });
  final String name;
  final String? alt;
  final Color? color;
  final double size, scale;
  final TdsAssetFrameShape? frameShape;
  final TdsAssetScaleType scaleType;
  final Color? backgroundColor;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final bool accessoryMasking;
  final Widget Function(Widget)? contentMasker;
  static Uri uriFor(String name) => Uri.parse(
    'https://static.toss.im/icons/svg/${name.startsWith('icn-') || name.startsWith('icon-') ? name : 'icn-$name'}.svg',
  );
  @override
  Widget build(BuildContext context) => TdsAssetFrame(
    shape: frameShape ?? TdsAssetFrameShape(width: size, height: size),
    backgroundColor: backgroundColor ?? const Color(0x00000000),
    accessory: accessory,
    accessoryPosition: accessoryPosition,
    accessoryMasking: accessoryMasking,
    contentMasker: contentMasker,
    content: Transform.scale(
      scale: scale,
      child:
          (RegExp(r'^icon-step[1-9]-rounded-(light|dark)$').hasMatch(name) ||
              bundled.contains(
                uriFor(name).pathSegments.last.replaceAll('.svg', ''),
              ))
          ? SvgPicture.asset(
              'assets/icons/${uriFor(name).pathSegments.last}',
              package: 'tds_mobile_flutter',
              width: frameShape?.width ?? size,
              height: frameShape?.height,
              fit: scaleType == TdsAssetScaleType.fit
                  ? BoxFit.contain
                  : BoxFit.cover,
              colorFilter: color == null
                  ? null
                  : ColorFilter.mode(color!, BlendMode.srcIn),
              semanticsLabel: alt,
              excludeFromSemantics: alt == null,
            )
          : SvgPicture.network(
              uriFor(name).toString(),
              width: frameShape?.width ?? size,
              height: frameShape?.height,
              fit: scaleType == TdsAssetScaleType.fit
                  ? BoxFit.contain
                  : BoxFit.cover,
              colorFilter: color == null
                  ? null
                  : ColorFilter.mode(color!, BlendMode.srcIn),
              semanticsLabel: alt,
              excludeFromSemantics: alt == null,
            ),
    ),
  );
}

class TdsAssetImage extends StatelessWidget {
  const TdsAssetImage({
    required this.src,
    this.alt,
    this.frameShape = const TdsAssetFrameShape(),
    this.backgroundColor,
    this.scaleType = TdsAssetScaleType.fit,
    this.scale = 1,
    this.package,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.contentMasker,
    this.placeholder,
    this.errorBuilder,
    super.key,
  }) : bytes = null;

  /// 저장소에서 읽은 사진을 URL로 공개하지 않고 같은 TDS 프레임에 표시한다.
  const TdsAssetImage.memory(
    Uint8List this.bytes, {
    this.alt,
    this.frameShape = const TdsAssetFrameShape(),
    this.backgroundColor,
    this.scaleType = TdsAssetScaleType.fit,
    this.scale = 1,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.contentMasker,
    this.placeholder,
    this.errorBuilder,
    super.key,
  }) : src = '',
       package = null;
  final String src;
  final Uint8List? bytes;
  final String? alt, package;
  final TdsAssetFrameShape frameShape;
  final Color? backgroundColor;
  final TdsAssetScaleType scaleType;
  final double scale;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final bool accessoryMasking;
  final Widget Function(Widget)? contentMasker;
  final Widget? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  Widget build(BuildContext context) {
    final network = src.startsWith('https:') || src.startsWith('http:');
    final svg = Uri.parse(src).path.toLowerCase().endsWith('.svg');
    final fit = scaleType == TdsAssetScaleType.fit
        ? BoxFit.contain
        : BoxFit.cover;
    Widget frameBuilder(
      BuildContext context,
      Widget child,
      int? frame,
      bool synchronouslyLoaded,
    ) => frame == null ? placeholder! : child;

    final Widget image = bytes != null
        ? Image.memory(
            bytes!,
            width: frameShape.width,
            height: frameShape.height,
            fit: fit,
            semanticLabel: alt,
            excludeFromSemantics: alt == null,
            frameBuilder: placeholder == null ? null : frameBuilder,
            errorBuilder: errorBuilder,
          )
        : svg
        ? (network
              ? SvgPicture.network(
                  src,
                  width: frameShape.width,
                  height: frameShape.height,
                  fit: fit,
                  semanticsLabel: alt,
                  excludeFromSemantics: alt == null,
                  placeholderBuilder: placeholder == null
                      ? null
                      : (_) => placeholder!,
                  errorBuilder: errorBuilder,
                )
              : SvgPicture.asset(
                  src,
                  package: package,
                  width: frameShape.width,
                  height: frameShape.height,
                  fit: fit,
                  semanticsLabel: alt,
                  excludeFromSemantics: alt == null,
                  placeholderBuilder: placeholder == null
                      ? null
                      : (_) => placeholder!,
                  errorBuilder: errorBuilder,
                ))
        : (network
              ? Image.network(
                  src,
                  width: frameShape.width,
                  height: frameShape.height,
                  fit: fit,
                  semanticLabel: alt,
                  excludeFromSemantics: alt == null,
                  frameBuilder: placeholder == null ? null : frameBuilder,
                  errorBuilder: errorBuilder,
                )
              : Image.asset(
                  src,
                  package: package,
                  width: frameShape.width,
                  height: frameShape.height,
                  fit: fit,
                  semanticLabel: alt,
                  excludeFromSemantics: alt == null,
                  frameBuilder: placeholder == null ? null : frameBuilder,
                  errorBuilder: errorBuilder,
                ));
    return TdsAssetFrame(
      shape: frameShape,
      backgroundColor: backgroundColor ?? const Color(0x00000000),
      accessory: accessory,
      accessoryPosition: accessoryPosition,
      accessoryMasking: accessoryMasking,
      contentMasker: contentMasker,
      content: Transform.scale(scale: scale, child: image),
    );
  }
}

class TdsAssetLottie extends StatelessWidget {
  const TdsAssetLottie({
    required this.src,
    this.frameShape = const TdsAssetFrameShape(),
    this.repeat = true,
    this.animate = true,
    this.controller,
    this.alt,
    this.package,
    this.backgroundColor = const Color(0x00000000),
    this.scale = 1,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.contentMasker,
    super.key,
  });
  final String src;
  final TdsAssetFrameShape frameShape;
  final bool repeat, animate;
  final AnimationController? controller;
  final String? alt, package;
  final Color? backgroundColor;
  final double scale;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final bool accessoryMasking;
  final Widget Function(Widget)? contentMasker;
  @override
  Widget build(BuildContext context) => Semantics(
    label: alt,
    image: alt != null,
    excludeSemantics: true,
    child: TdsAssetFrame(
      shape: frameShape,
      backgroundColor: backgroundColor,
      accessory: accessory,
      accessoryPosition: accessoryPosition,
      accessoryMasking: accessoryMasking,
      contentMasker: contentMasker,
      content: Transform.scale(
        scale: scale,
        child: src.startsWith('https:') || src.startsWith('http:')
            ? Lottie.network(
                src,
                width: frameShape.width,
                height: frameShape.height,
                repeat: repeat,
                animate: animate,
                controller: controller,
              )
            : Lottie.asset(
                src,
                package: package,
                width: frameShape.width,
                height: frameShape.height,
                repeat: repeat,
                animate: animate,
                controller: controller,
              ),
      ),
    ),
  );
}

class TdsAssetText extends StatelessWidget {
  const TdsAssetText(
    this.text, {
    this.frameShape = const TdsAssetFrameShape(),
    this.color,
    this.backgroundColor,
    this.style,
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.contentMasker,
    super.key,
  });
  final String text;
  final TdsAssetFrameShape frameShape;
  final Color? color, backgroundColor;
  final TextStyle? style;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final bool accessoryMasking;
  final Widget Function(Widget)? contentMasker;
  @override
  Widget build(BuildContext context) => TdsAssetFrame(
    shape: frameShape,
    backgroundColor: backgroundColor,
    accessory: accessory,
    accessoryPosition: accessoryPosition,
    accessoryMasking: accessoryMasking,
    contentMasker: contentMasker,
    content: Center(
      child: TdsText(
        text,
        color: color,
        fontWeight: TdsFontWeight.semibold,
        style: style,
      ),
    ),
  );
}

enum TdsSquircleSize { xsmall, small, medium, large, xlarge, xxlarge }

class TdsSquircleMasking extends StatelessWidget {
  const TdsSquircleMasking({
    required this.child,
    this.size = TdsSquircleSize.medium,
    super.key,
  });
  final Widget child;
  final TdsSquircleSize size;
  @override
  Widget build(BuildContext context) {
    final width = [24.0, 30.0, 36.0, 40.0, 52.0, 60.0][size.index];
    return SizedBox.square(
      dimension: width,
      child: ClipPath(clipper: _SquircleClipper(size), child: child),
    );
  }
}

class _SquircleClipper extends CustomClipper<Path> {
  const _SquircleClipper(this.type);
  final TdsSquircleSize type;
  @override
  Path getClip(Size size) {
    // These ratios are the original six SVG paths, not an approximation using a
    // rounded rectangle. The two largest sizes use a different corner profile.
    final big = type.index >= 4;
    final w = size.width,
        h = size.height,
        a = big ? .4 : .482,
        b = big ? .099 : .099;
    return Path()
      ..moveTo(0, h * a)
      ..cubicTo(0, h * b, w * b, 0, w * a, 0)
      ..lineTo(w * (1 - a), 0)
      ..cubicTo(w * (1 - b), 0, w, h * b, w, h * a)
      ..lineTo(w, h * (1 - a))
      ..cubicTo(w, h * (1 - b), w * (1 - b), h, w * (1 - a), h)
      ..lineTo(w * a, h)
      ..cubicTo(w * b, h, 0, h * (1 - b), 0, h * (1 - a))
      ..close();
  }

  @override
  bool shouldReclip(_SquircleClipper oldClipper) => type != oldClipper.type;
}
