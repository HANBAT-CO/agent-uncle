import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../core/theme/app_theme.dart';

enum FigmaSurfaceStyle { solid, glass }

/// Stationary color behind the home surfaces; never intercepts input.
class HomeBackdrop extends StatelessWidget {
  const HomeBackdrop({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.background,
      gradient: MediaQuery.highContrastOf(context)
          ? null
          : RadialGradient(
              center: const Alignment(.85, -.7),
              radius: 1.1,
              colors: [
                Color.alphaBlend(
                  AppColors.lime.withValues(alpha: .14),
                  AppColors.background,
                ),
                AppColors.background,
              ],
            ),
    ),
    child: child,
  );
}

/// Layout-only surface from Figma 03 / 04 (radius 24). TDS has no card
/// container; its rows, fields, buttons and typography provide the contents.
class FigmaSurface extends StatelessWidget {
  const FigmaSurface({
    required this.children,
    this.margin = 24,
    this.tinted = false,
    this.style = FigmaSurfaceStyle.solid,
    this.grouped = false,
    super.key,
  });
  final List<Widget> children;
  final double margin;
  final bool tinted;
  final FigmaSurfaceStyle style;

  /// Only non-overlapping surfaces in the same BackdropGroup may share input.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(24));
    final highContrast = MediaQuery.highContrastOf(context);
    final glass = style == FigmaSurfaceStyle.glass && !highContrast;
    final theme = TdsTheme.of(context);
    Widget surface = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    if (glass) {
      // These two simple borders paint highlights without another compositing
      // layer. Decorations never tint, blur or change the size of the contents.
      surface = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border(
            bottom: BorderSide(color: AppColors.primary.withValues(alpha: .15)),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: const Border(
              top: BorderSide(color: Color(0xF2FFFFFF)),
              left: BorderSide(color: Color(0xF2FFFFFF)),
              right: BorderSide(color: Color(0xF2FFFFFF)),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: .55),
                AppColors.glassTint.withValues(alpha: .32),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.2,
                colors: [
                  (tinted ? AppColors.lime : const Color(0xFFFFFFFF))
                      .withValues(alpha: tinted ? .14 : .24),
                  const Color(0x00FFFFFF),
                ],
              ),
            ),
            child: surface,
          ),
        ),
      );
      final blur = ImageFilter.blur(sigmaX: 16, sigmaY: 16);
      surface = grouped
          ? BackdropFilter.grouped(filter: blur, child: surface)
          : BackdropFilter(filter: blur, child: surface);
    } else {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          color: theme.color(tinted ? 'blue50' : 'cardBgWhite'),
          borderRadius: radius,
          border: highContrast ? Border.all(color: AppColors.primary) : null,
        ),
        child: surface,
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: glass
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .08),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(borderRadius: radius, child: surface),
      ),
    );
  }
}

/// Original Figma assets, including the two Material icons referenced by
/// Figma Code Connect. No replacement illustrations or custom icon drawing.
class FigmaIcon extends StatelessWidget {
  const FigmaIcon(
    this.name, {
    this.selected = false,
    this.size = 24,
    super.key,
  });
  final String name;
  final bool selected;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = TdsTheme.of(context).color(selected ? 'blue600' : 'grey600');
    if (name == 'chat' || name == 'person') {
      return TdsAssetFrame(
        shape: TdsAssetFrameShape(width: size, height: size, transparent: true),
        content: Icon(
          name == 'chat' ? Icons.chat_bubble_outline : Icons.person_outline,
          size: size,
          color: color,
        ),
      );
    }
    return TdsIconButtonImage(
      src: 'assets/icons/figma_$name.svg',
      color: color,
      size: size,
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {this.eyebrow, this.description, super.key});
  final String title;
  final String? eyebrow, description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (eyebrow != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: TdsText(
            eyebrow!,
            typography: TdsTypography.t7,
            color: TdsTheme.of(context).color('blue600'),
            fontWeight: TdsFontWeight.semibold,
          ),
        ),
      TdsTop(
        title: TdsTopTitleParagraph(title, size: 22),
        subtitleBottom: description == null
            ? null
            : TdsTopSubtitleParagraph(description!),
      ),
    ],
  );
}

class QuantityRow extends StatelessWidget {
  const QuantityRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => TdsTableRow(
    left: Text(label),
    right: Text(value),
    align: TdsTableRowAlign.spaceBetween,
    leftRatio: 58,
    rightFontWeight: TdsFontWeight.semibold,
  );
}
