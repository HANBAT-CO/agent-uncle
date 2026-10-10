import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum TdsIconButtonVariant { clear, fill, border }

class TdsIconButtonImage extends StatelessWidget {
  const TdsIconButtonImage({
    required this.src,
    this.size = 24,
    this.alt,
    this.color,
    this.package,
    super.key,
  });
  final String src;
  final double size;
  final String? alt, package;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final network = src.startsWith('https:') || src.startsWith('http:');
    final svg = Uri.parse(src).path.endsWith('.svg');
    Widget child = svg
        ? (network
              ? SvgPicture.network(
                  src,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                )
              : SvgPicture.asset(
                  src,
                  package: package,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ))
        : network
        ? Image.network(src, fit: BoxFit.contain, excludeFromSemantics: true)
        : Image.asset(
            src,
            package: package,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          );
    if (color != null) {
      child = ColorFiltered(
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
        child: child,
      );
    }
    return Semantics(
      label: alt,
      image: alt != null,
      excludeSemantics: true,
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

class TdsIconButton extends StatelessWidget {
  const TdsIconButton({
    required this.semanticLabel,
    this.name,
    this.child,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.variant = TdsIconButtonVariant.clear,
    this.iconSize = 24,
    this.disabled = false,
    this.focusNode,
    super.key,
  }) : assert(name != null || child != null);
  final String semanticLabel;
  final String? name;
  final Widget? child;
  final VoidCallback? onPressed;
  final Color? color, backgroundColor;
  final TdsIconButtonVariant variant;
  final double iconSize;
  final bool disabled;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final padding = iconSize >= 18 && iconSize <= 20 ? 9.0 : iconSize / 2;
    final radius = iconSize <= 16
        ? 6.0
        : iconSize <= 20
        ? 8.0
        : 12.0;
    return TdsPressable(
      enabled: !disabled,
      onPressed: onPressed,
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      onPressStart: () => tdsHapticOf(context).generate(TdsHapticType.tickWeak),
      builder: (context, pressed, hovered, focused) {
        final motion = pressed ? TdsMotion.rapid : TdsMotion.quick;
        final background = backgroundColor ?? theme.color('greyOpacity100');
        return AnimatedScale(
          scale: pressed ? .9 : 1,
          duration: motion.duration,
          curve: motion,
          child: AnimatedContainer(
            duration: motion.duration,
            curve: motion,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: variant == TdsIconButtonVariant.fill
                  ? (pressed && backgroundColor == null
                        ? theme.color('greyOpacity200')
                        : background)
                  : pressed
                  ? background
                  : const Color(0x00000000),
              border: variant == TdsIconButtonVariant.border
                  ? Border.all(color: theme.color('greyOpacity100'))
                  : null,
            ),
            child: ExcludeSemantics(
              child:
                  child ??
                  TdsAssetIcon(name: name!, color: color, size: iconSize),
            ),
          ),
        );
      },
    );
  }
}
