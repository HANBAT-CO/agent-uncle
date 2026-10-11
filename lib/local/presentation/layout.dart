import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

/// Layout-only surface from Figma 03 / 04 (radius 24). TDS has no card
/// container; its rows, fields, buttons and typography provide the contents.
class FigmaSurface extends StatelessWidget {
  const FigmaSurface({
    required this.children,
    this.margin = 24,
    this.tinted = false,
    super.key,
  });
  final List<Widget> children;
  final double margin;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: margin, vertical: 6),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: TdsTheme.of(context).color(tinted ? 'blue50' : 'cardBgWhite'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
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
