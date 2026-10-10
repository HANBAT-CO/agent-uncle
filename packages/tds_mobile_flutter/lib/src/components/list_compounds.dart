import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import '../foundation/list_row_scope.dart';
import '../foundation/touch_inset.dart';
import 'asset.dart';
import 'icon_button.dart';
import 'text.dart';

/// Original ListRow.Typography keys retain their source spelling.
const tdsListRowTypography = <String, TdsTypography>{
  'Large': TdsTypography.t4,
  'Medium': TdsTypography.t5,
  'Adjust': TdsTypography.t6,
  'Small': TdsTypography.t7,
};

enum TdsListRowImageType {
  plain,
  square,
  rectangle,
  rectangleSmall,
  circle,
  circleSmall,
  emoji3d,
}

class TdsListRowImageContainer extends StatelessWidget {
  const TdsListRowImageContainer({
    required this.child,
    this.type = TdsListRowImageType.plain,
    this.border = false,
    super.key,
  });
  final Widget child;
  final TdsListRowImageType type;
  final bool border;
  static ({double? width, double? height, double radius}) dimensions(
    TdsListRowImageType type,
  ) => switch (type) {
    TdsListRowImageType.plain => (width: null, height: null, radius: 0),
    TdsListRowImageType.square => (width: 54, height: 54, radius: 10),
    TdsListRowImageType.rectangle => (width: 34, height: 54, radius: 4),
    TdsListRowImageType.rectangleSmall => (width: 30, height: 47, radius: 4),
    TdsListRowImageType.circle => (width: 40, height: 40, radius: 20),
    TdsListRowImageType.circleSmall => (width: 34, height: 34, radius: 17),
    TdsListRowImageType.emoji3d => (width: 40, height: 40, radius: 0),
  };
  @override
  Widget build(BuildContext context) {
    final metrics = dimensions(type);
    return Container(
      width: metrics.width,
      height: metrics.height,
      constraints: const BoxConstraints(maxWidth: 108, maxHeight: 54),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: border
          ? BoxDecoration(
              border: Border.all(
                color: TdsTheme.of(context).color('greyOpacity100'),
              ),
              borderRadius: BorderRadius.circular(metrics.radius),
            )
          : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: child,
    );
  }
}

class TdsListRowImage extends StatelessWidget {
  const TdsListRowImage({
    required this.src,
    this.alt,
    this.type = TdsListRowImageType.plain,
    this.border,
    this.package,
    super.key,
  });
  final String src;
  final String? alt, package;
  final TdsListRowImageType type;
  final bool? border;
  @override
  Widget build(BuildContext context) {
    final fit = type == TdsListRowImageType.plain
        ? BoxFit.contain
        : BoxFit.cover;
    return TdsListRowImageContainer(
      type: type,
      border:
          border ??
          (type == TdsListRowImageType.rectangle ||
              type == TdsListRowImageType.rectangleSmall),
      child: Uri.tryParse(src)?.hasScheme == true
          ? Image.network(
              src,
              fit: fit,
              semanticLabel: alt,
              excludeFromSemantics: alt == null,
            )
          : Image.asset(
              src,
              package: package,
              fit: fit,
              semanticLabel: alt,
              excludeFromSemantics: alt == null,
            ),
    );
  }
}

enum TdsListRowIconShape {
  noBackground,
  squircleBackground,
  circleBackground,
  circleMasking,
}

enum TdsListRowIconSize { medium, large }

class TdsListRowIcon extends StatelessWidget {
  const TdsListRowIcon({
    this.name,
    this.url,
    this.alt,
    this.color,
    this.shape = TdsListRowIconShape.noBackground,
    this.size = TdsListRowIconSize.large,
    super.key,
  }) : assert((name == null) != (url == null));
  final String? name, url, alt;
  final Color? color;
  final TdsListRowIconShape shape;
  final TdsListRowIconSize size;
  @override
  Widget build(BuildContext context) {
    final squircle = shape == TdsListRowIconShape.squircleBackground;
    final plain = shape == TdsListRowIconShape.noBackground;
    final mask = shape == TdsListRowIconShape.circleMasking;
    final dimension = plain
        ? 24.0
        : squircle
        ? (size == TdsListRowIconSize.large ? 36.0 : 30.0)
        : 40.0;
    final iconSize = mask
        ? dimension
        : squircle && size == TdsListRowIconSize.medium
        ? 20.0
        : 24.0;
    final icon = SizedBox.square(
      dimension: iconSize,
      child: url != null
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              semanticLabel: alt,
              excludeFromSemantics: alt == null,
            )
          : TdsAssetIcon(name: name!, color: color, alt: alt, size: iconSize),
    );
    final content = ColoredBox(
      color: plain || mask
          ? const Color(0x00000000)
          : TdsTheme.of(context).color('grey100'),
      child: Center(child: icon),
    );
    return SizedBox.square(
      dimension: dimension,
      child: squircle
          ? TdsSquircleMasking(
              size: size == TdsListRowIconSize.large
                  ? TdsSquircleSize.medium
                  : TdsSquircleSize.small,
              child: content,
            )
          : plain
          ? content
          : ClipOval(child: content),
    );
  }
}

class TdsListRowIconButton extends TdsIconButton {
  const TdsListRowIconButton({
    required super.semanticLabel,
    super.name,
    super.child,
    super.onPressed,
    super.color,
    super.backgroundColor,
    super.variant,
    super.iconSize,
    super.disabled,
    super.focusNode,
    this.inRightSlot,
    super.key,
  });
  final bool? inRightSlot;
  @override
  Widget build(BuildContext context) => TdsTouchInset(
    insets: EdgeInsets.only(
      right:
          (inRightSlot ??
              TdsListRowSlotScope.maybeOf(context)?.inRight ??
              false)
          ? (iconSize >= 18 && iconSize <= 20 ? 9 : iconSize / 2)
          : 0,
    ),
    child: super.build(context),
  );
}

class TdsListRowText extends TdsText {
  const TdsListRowText(
    super.data, {
    super.typography = TdsTypography.t5,
    super.fontWeight,
    super.color,
    super.textAlign,
    super.ellipsisAfterLines,
    super.style,
    super.semanticsLabel,
    super.key,
  });
}

class TdsListRowLeftText extends StatelessWidget {
  const TdsListRowLeftText(
    this.text, {
    this.border = false,
    this.marginTop = 0,
    this.typography,
    this.fontWeight,
    this.color,
    super.key,
  });
  final String text;
  final bool border;
  final double marginTop;
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: marginTop),
    child: Container(
      width: border ? 40 : null,
      height: border ? 40 : null,
      alignment: border ? Alignment.center : null,
      decoration: border
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TdsTheme.of(context).color('greyOpacity100'),
              ),
            )
          : null,
      child: TdsText(
        text,
        typography:
            typography ?? (border ? TdsTypography.st9 : TdsTypography.t6),
        fontWeight:
            fontWeight ?? (border ? TdsFontWeight.regular : TdsFontWeight.bold),
        color: color,
      ),
    ),
  );
}

enum TdsListRowLoaderType { square, circle, bar }

enum TdsListRowLoaderPadding { extraSmall, small, medium, large }

class TdsListRowLoader extends StatefulWidget {
  const TdsListRowLoader({
    this.type = TdsListRowLoaderType.square,
    this.verticalPadding = TdsListRowLoaderPadding.medium,
    super.key,
  });
  final TdsListRowLoaderType type;
  final TdsListRowLoaderPadding verticalPadding;
  @override
  State<TdsListRowLoader> createState() => _TdsListRowLoaderState();
}

class _TdsListRowLoaderState extends State<TdsListRowLoader>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: [8.0, 16.0, 24.0, 32.0][widget.verticalPadding.index],
      ),
      child: AspectRatio(
        aspectRatio: 327 / 60,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => CustomPaint(
            painter: _RowLoaderPainter(
              widget.type,
              _animation.value,
              TdsTheme.of(context).color('grey100'),
              TdsTheme.of(context).color('grey300'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RowLoaderPainter extends CustomPainter {
  _RowLoaderPainter(this.type, this.progress, this.background, this.foreground);
  final TdsListRowLoaderType type;
  final double progress;
  final Color background, foreground;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 327, size.height / 60);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [background, foreground, background],
        stops: const [0, .5, 1],
      ).createShader(Rect.fromLTWH(-327 + progress * 654, 0, 327, 60));
    if (type == TdsListRowLoaderType.circle) {
      canvas.drawCircle(const Offset(23, 30), 23, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          type == TdsListRowLoaderType.bar
              ? const Rect.fromLTWH(0, 10, 46, 16)
              : const Rect.fromLTWH(0, 7, 46, 46),
          Radius.circular(type == TdsListRowLoaderType.bar ? 2 : 7),
        ),
        paint,
      );
    }
    for (final rect in [
      const Rect.fromLTWH(62, 10, 90, 16),
      const Rect.fromLTWH(62, 34, 120, 16),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RowLoaderPainter old) =>
      progress != old.progress ||
      type != old.type ||
      background != old.background ||
      foreground != old.foreground;
}
