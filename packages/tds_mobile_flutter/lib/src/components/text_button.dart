import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../foundation/color.dart';
import '../foundation/host.dart';
import '../foundation/line_box.dart';
import '../foundation/motion.dart';
import '../foundation/paragraph_scope.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/touch_inset.dart';
import '../foundation/text_underline.dart';
import '../foundation/word_break.dart';
import 'asset.dart';

enum TdsTextButtonSize {
  xsmall(TdsTypography.t7, TdsFontWeight.medium, 16.27, 3, 7),
  small(TdsTypography.t6, TdsFontWeight.medium, 18.77, 3, 7),
  medium(TdsTypography.t5, TdsFontWeight.medium, 21.28, 4, 9),
  large(TdsTypography.t4, TdsFontWeight.semibold, 25.04, 5, 11),
  xlarge(TdsTypography.t3, TdsFontWeight.bold, 27.54, 5, 11),
  xxlarge(TdsTypography.st2, TdsFontWeight.bold, 35.05, 7, 13);

  const TdsTextButtonSize(
    this.typography,
    this.weight,
    this.arrowSize,
    this.dimmerVertical,
    this.dimmerHorizontal,
  );
  final TdsTypography typography;
  final TdsFontWeight weight;
  final double arrowSize, dimmerVertical, dimmerHorizontal;
}

enum TdsTextButtonVariant { clear, arrow, underline }

enum TdsArrowPlacement { inline, block }

/// TextButton's DOM-specific as/href becomes an explicit onPressed callback.
/// Adaptive CSS tokens use [colorToken]; literal [color] stays theme-independent.
class TdsTextButton extends StatelessWidget {
  const TdsTextButton({
    required this.child,
    required this.size,
    this.onPressed,
    this.color,
    this.colorToken,
    this.fontWeight,
    this.variant = TdsTextButtonVariant.clear,
    this.arrowPlacement = TdsArrowPlacement.block,
    this.disabled = false,
    this.semanticLabel,
    this.focusNode,
    super.key,
  }) : assert(color == null || colorToken == null);
  final Widget child;
  final TdsTextButtonSize size;
  final VoidCallback? onPressed;
  final Color? color;
  final String? colorToken;
  final TdsFontWeight? fontWeight;
  final TdsTextButtonVariant variant;
  final TdsArrowPlacement arrowPlacement;
  final bool disabled;
  final String? semanticLabel;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => _TdsTextButtonBody(button: this);
}

class _TdsTextButtonBody extends StatefulWidget {
  const _TdsTextButtonBody({required this.button});
  final TdsTextButton button;
  @override
  State<_TdsTextButtonBody> createState() => _TdsTextButtonState();
}

class _TdsTextButtonState extends State<_TdsTextButtonBody> {
  TdsTextButton get button => widget.button;
  bool _pressed = false;
  Color? _startColor;
  void _down(PointerDownEvent event) {
    if (button.disabled) return;
    tdsHapticOf(context).generate(TdsHapticType.tickWeak);
    if (!_pressed) setState(() => _pressed = true);
  }

  void _up(PointerUpEvent event) {
    if (_pressed) setState(() => _pressed = false);
  }

  Color _ink(TdsThemeData theme, bool pressed) {
    final literal = button.color;
    if (literal != null) {
      return pressed ? tdsStaticPressColors[literal] ?? literal : literal;
    }
    final token = button.colorToken ?? 'grey600';
    if (!pressed) return theme.color(token);
    final match = RegExp(r'^([^\d]+)(50|[1-9]00)$').firstMatch(token);
    if (match == null) return theme.color(token);
    const levels = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
    final index = levels.indexOf(int.parse(match[2]!));
    final next = '${match[1]}${levels[(index + 1).clamp(0, 9)]}';
    return theme.color(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final startColor = _ink(theme, false);
    // Poe rebuilds its release timeline when the resolved start color changes.
    if (_startColor != null && _startColor != startColor) _pressed = false;
    _startColor = startColor;
    final size = button.size, weight = button.fontWeight ?? button.size.weight;
    final paragraph = TdsParagraphScope.maybeOf(context);
    // 2.5.1 inherits link CSS variables only from an ancestor Paragraph.
    // Missing variables invalidate standalone padding and negative margins.
    final metrics = paragraph == null
        ? null
        : tdsLinkMetrics[theme.platform.size(paragraph.typography).toInt()]!;
    final arrow = button.variant == TdsTextButtonVariant.arrow;
    final inset = EdgeInsets.fromLTRB(
      metrics?.$2 ?? 0,
      metrics?.$1 ?? 0,
      arrow ? 0 : metrics?.$2 ?? 0,
      metrics?.$1 ?? 0,
    );
    final motion = _pressed ? TdsMotion.rapid : TdsMotion.quick;
    return TdsTouchInset(
      insets: inset,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _up,
        // ht invokes only onPressCancel for touchcancel; Poe supplies none.
        // Keep the source's visual until a subsequent accepted press end.
        child: TdsPressable(
          enabled: !button.disabled,
          activateOnEnterDown: true,
          onPressed: button.onPressed,
          focusNode: button.focusNode,
          semanticLabel: button.semanticLabel,
          builder: (context, _, hovered, focused) =>
              TweenAnimationBuilder<Color>(
                tween: TdsGammaColorTween(
                  begin: _ink(theme, false),
                  end: _ink(theme, _pressed),
                ),
                duration: TdsMotion.quick.duration,
                curve: TdsMotion.quick,
                builder: (context, ink, _) {
                  final style = theme
                      .textStyle(
                        typography: size.typography,
                        fontWeight: weight,
                        color: ink,
                      )
                      .copyWith(
                        height: 1.252,
                        decoration:
                            button.variant == TdsTextButtonVariant.underline
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: ink,
                      );
                  final underlineThickness =
                      button.fontWeight == null || metrics == null
                      ? null
                      : weight.index >= TdsFontWeight.semibold.index
                      ? metrics.$5
                      : metrics.$4;
                  final content = DefaultTextStyle(
                    style: style,
                    child: _content(style, ink, arrow, underlineThickness),
                  );
                  return Opacity(
                    opacity: button.disabled ? .38 : 1,
                    child: AnimatedScale(
                      scale: _pressed ? .94 : 1,
                      duration: motion.duration,
                      curve: motion,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -size.dimmerVertical,
                            bottom: -size.dimmerVertical,
                            left: -size.dimmerHorizontal,
                            right: arrow ? 0 : -size.dimmerHorizontal,
                            child: TweenAnimationBuilder<Color>(
                              tween: TdsGammaColorTween(
                                begin: const Color(0x00ffffff),
                                // Initial release writes an inline style, which
                                // shadows the source's CSS-only hover rule.
                                end: _pressed
                                    ? theme.color('greyOpacity100')
                                    : const Color(0x00000000),
                              ),
                              duration: motion.duration,
                              curve: motion,
                              builder: (context, fill, _) => DecoratedBox(
                                key: const ValueKey('tds-text-button-dimmer'),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    size.dimmerHorizontal,
                                  ),
                                  color: fill,
                                ),
                              ),
                            ),
                          ),
                          Padding(padding: inset, child: content),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }

  Widget _content(
    TextStyle style,
    Color ink,
    bool arrow,
    double? underlineThickness,
  ) {
    final label = button.child;
    final text = label is Text ? label : null;
    final uniform = text != null && text.data != null && text.style == null;
    final fontSize = style.fontSize!;
    final lineHeight = (fontSize * 1.252 * 64).floor() / 64;
    final ascent = (fontSize * 2030 / 2048).round();
    final descent = (fontSize * 534 / 2048).round();
    Widget line(Widget child) => uniform
        ? TdsLineBox(
            lineHeight: lineHeight,
            baseline: (ascent + (lineHeight - ascent - descent) / 2)
                .floorToDouble(),
            child: child,
          )
        : child;
    if (!arrow) {
      Widget content = text == null ? label : TdsKeepAllText.from(text);
      if (uniform && button.variant == TdsTextButtonVariant.underline) {
        content = TdsTextUnderline(
          fontSize: style.fontSize!,
          color: ink,
          thickness: underlineThickness,
          child: DefaultTextStyle(
            style: style.copyWith(decoration: TextDecoration.none),
            child: content,
          ),
        );
      }
      return line(content);
    }
    final inline = button.arrowPlacement == TdsArrowPlacement.inline;
    final icon = SizedBox(
      width: button.size.arrowSize,
      height: 5,
      child: OverflowBox(
        minWidth: button.size.arrowSize,
        maxWidth: button.size.arrowSize,
        minHeight: button.size.arrowSize,
        maxHeight: button.size.arrowSize,
        child: Transform.translate(
          offset: Offset(0, inline ? -1.5 : 0),
          child: TdsAssetIcon(
            name: 'arrow-rightwards',
            color: ink,
            size: button.size.arrowSize,
          ),
        ),
      ),
    );
    if (inline && text != null) {
      return line(
        TdsKeepAllText.from(
          text,
          after: [
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _ArrowBaseline(
                baseline:
                    2.5 +
                    (text.style?.fontSize ?? style.fontSize!) * 1075 / 2048 / 2,
                child: icon,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: line(text == null ? label : TdsKeepAllText.from(text))),
        icon,
      ],
    );
  }
}

class _ArrowBaseline extends SingleChildRenderObjectWidget {
  const _ArrowBaseline({required this.baseline, required super.child});
  final double baseline;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderArrowBaseline(baseline);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderArrowBaseline renderObject,
  ) {
    renderObject.baseline = baseline;
  }
}

class _RenderArrowBaseline extends RenderProxyBox {
  _RenderArrowBaseline(this._baseline);
  double _baseline;
  set baseline(double value) {
    if (_baseline == value) return;
    _baseline = value;
    markNeedsLayout();
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;
  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _baseline;
}
