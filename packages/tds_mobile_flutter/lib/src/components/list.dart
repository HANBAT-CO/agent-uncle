import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../foundation/line_box.dart';
import '../foundation/theme.dart';
import '../foundation/list_row_controller.dart';
import '../foundation/list_row_scope.dart';
import 'asset.dart';
import 'badge.dart';
import 'button.dart';
import 'list_presets.g.dart';
import 'text.dart';
import 'text_button.dart';

enum TdsListRowVerticalPadding { small, medium, large, xlarge }

enum TdsListHorizontalPadding { small, medium }

enum TdsListRowAlignment { top, center }

enum TdsListRowBorder { none, indented }

enum TdsListRowDisabledStyle { type1, type2 }

enum TdsListRowArrow { right, up, down }

/// Original List is a zero-margin/padding group, not an independently scrolling
/// view. Use inside a native scroll view, or use its rows in a sliver.
class TdsList extends StatelessWidget {
  const TdsList({required this.children, this.semanticLabel, super.key});
  final List<Widget> children;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: semanticLabel,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class TdsListRow extends StatelessWidget {
  const TdsListRow({
    this.contents,
    this.left,
    this.right,
    this.onPressed,
    this.border = TdsListRowBorder.none,
    this.disabled = false,
    this.disabledStyle = TdsListRowDisabledStyle.type1,
    this.verticalPadding = TdsListRowVerticalPadding.medium,
    this.horizontalPadding = TdsListHorizontalPadding.medium,
    this.leftAlignment = TdsListRowAlignment.center,
    this.a11yLeftAlignment = TdsListRowAlignment.top,
    this.rightAlignment = TdsListRowAlignment.center,
    this.a11yRightReflow = true,
    this.withArrow = false,
    this.arrowType,
    this.withTouchEffect,
    this.semanticLabel,
    this.controller,
    this.contentsType,
    super.key,
  });
  final Widget? contents, left, right;
  final VoidCallback? onPressed;
  final TdsListRowBorder border;
  final bool disabled, a11yRightReflow, withArrow;
  final bool? withTouchEffect;
  final TdsListRowDisabledStyle disabledStyle;
  final TdsListRowVerticalPadding verticalPadding;
  final TdsListHorizontalPadding horizontalPadding;
  final TdsListRowAlignment leftAlignment, a11yLeftAlignment, rightAlignment;
  final TdsListRowArrow? arrowType;
  final String? semanticLabel;
  final TdsListRowController? controller;

  /// Optional when Texts is wrapped in a custom widget and cannot be inspected.
  final TdsListRowTextType? contentsType;

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final scale = theme.platform.fontScale;
    final textType =
        contentsType ??
        (contents is TdsListRowTexts
            ? (contents as TdsListRowTexts).type
            : null);
    final firstType = textType == null
        ? TdsTypography.t4
        : tdsListRowTextPresets[textType]!.first.$1;
    Widget slot(Widget child, {bool left = false, bool right = false}) =>
        TdsListRowSlotScope(
          inLeft: left,
          inRight: right,
          alignTop: a11yLeftAlignment == TdsListRowAlignment.top,
          firstTypography: firstType,
          child: child,
        );
    final viewport = MediaQuery.sizeOf(context).width;
    // The source :has selector reflows only these component families. Wrapping
    // an arbitrary Widget in native code cannot be queried like a DOM subtree.
    final reflowable =
        right is TdsListRowTexts ||
        right is TdsButton ||
        right is TdsTextButton ||
        right is TdsBadge;
    final reflow =
        a11yRightReflow && reflowable && scale >= (viewport < 560 ? 135 : 160);
    final gap = scale >= 135 && a11yRightReflow ? 4.0 : 16.0;
    final arrow = arrowType ?? (withArrow ? TdsListRowArrow.right : null);
    Widget body() => Stack(
      children: [
        if (disabled)
          Positioned.fill(
            child: ColoredBox(color: theme.color('tListRowDisabledBackground')),
          ),
        if (disabled && disabledStyle == TdsListRowDisabledStyle.type2)
          Positioned.fill(
            child: ColoredBox(color: theme.color('greyOpacity50')),
          ),
        if (border == TdsListRowBorder.indented)
          const Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: TdsBorder(variant: TdsBorderVariant.padding24),
          ),
        TdsListRowEffects(
          controller: controller,
          handleInput: true,
          touchEffectEnabled: withTouchEffect ?? onPressed != null,
          enabled: !disabled,
          onPressed: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding == TdsListHorizontalPadding.small
                  ? 20
                  : 24,
              vertical: const [8.0, 12.0, 16.0, 24.0][verticalPadding.index],
            ),
            child: _ListSlots(
              left: slot(left ?? const SizedBox.shrink(), left: true),
              leftGap: left == null ? 0 : 12,
              leftAlignment: scale >= 135 ? a11yLeftAlignment : leftAlignment,
              rightAlignment: rightAlignment,
              arrow: arrow == null
                  ? const SizedBox.shrink()
                  : SizedBox(
                      width: 20,
                      height: 24,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 28,
                        maxWidth: 28,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: TdsAssetIcon(
                            name: 'icon-arrow-${arrow.name}-mono',
                            color: theme.color('grey400'),
                            frameShape: const TdsAssetFrameShape(
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
              contents: LayoutBuilder(
                builder: (context, constraints) {
                  final main = _ListTextScope(
                    right: false,
                    reflow: false,
                    child: slot(contents ?? const SizedBox.shrink()),
                  );
                  if (right == null) return main;
                  final trailing = _ListTextScope(
                    right: true,
                    reflow: reflow,
                    child: slot(right!, right: true),
                  );
                  if (reflow) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        main,
                        SizedBox(height: gap),
                        trailing,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment:
                        rightAlignment == TdsListRowAlignment.top
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Expanded(child: main),
                      SizedBox(width: gap),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(
                            0,
                            constraints.maxWidth * .8 - gap,
                          ),
                        ),
                        child: trailing,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
    return Semantics(
      enabled: disabled ? false : null,
      label: semanticLabel,
      child: ExcludeFocus(
        excluding: disabled,
        child: IgnorePointer(
          ignoring: disabled,
          child: ClipRect(child: body()),
        ),
      ),
    );
  }
}

/// Native equivalent of EssentialTextProps. Explicit child Text styles retain
/// precedence over these defaults, as cloned React element props do.
@immutable
class TdsListRowTextStyle {
  const TdsListRowTextStyle({
    this.typography,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.style,
  });
  final TdsTypography? typography;
  final TdsFontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextStyle? style;
}

class TdsListRowTexts extends StatelessWidget {
  const TdsListRowTexts({
    required this.type,
    required this.top,
    this.middle,
    this.bottom,
    this.topProps = const TdsListRowTextStyle(),
    this.middleProps = const TdsListRowTextStyle(),
    this.bottomProps = const TdsListRowTextStyle(),
    this.marginTop = 0,
    super.key,
  });
  final TdsListRowTextType type;
  final Widget top;
  final Widget? middle, bottom;
  final TdsListRowTextStyle topProps, middleProps, bottomProps;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    final presets = tdsListRowTextPresets[type]!;
    assert(
      presets.length < 2 || bottom != null,
      '${type.sourceName} requires bottom',
    );
    assert(
      presets.length < 3 || middle != null,
      '${type.sourceName} requires middle',
    );
    final children = [
      top,
      if (presets.length == 3) middle!,
      if (presets.length >= 2) bottom!,
    ];
    final overrides = [
      topProps,
      if (presets.length == 3) middleProps,
      if (presets.length >= 2) bottomProps,
    ];
    final scope = _ListTextScope.maybeOf(context);
    final right = scope?.right == true && scope?.reflow != true;
    final theme = TdsTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top:
            marginTop + (scope?.right == true && scope?.reflow == true ? 2 : 0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < presets.length; i++)
            Builder(
              builder: (context) {
                final (typography, weight, color) = presets[i];
                final props = overrides[i];
                final actualType = props.typography ?? typography;
                final style = theme
                    .textStyle(
                      typography: actualType,
                      fontWeight: props.fontWeight ?? weight,
                      color: props.color ?? theme.color(color),
                    )
                    .copyWith(height: scope == null ? null : 1.35)
                    .merge(props.style);
                Widget child = DefaultTextStyle(
                  style: style,
                  textAlign:
                      props.textAlign ??
                      (right ? TextAlign.right : TextAlign.left),
                  maxLines: props.maxLines,
                  overflow: props.maxLines == null
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  child: children[i],
                );
                if (children[i] is Text) {
                  child = TdsLineBox(
                    lineHeight: style.fontSize! * style.height!,
                    child: child,
                  );
                }
                return child;
              },
            ),
        ],
      ),
    );
  }
}

class _ListTextScope extends InheritedWidget {
  const _ListTextScope({
    required this.right,
    required this.reflow,
    required super.child,
  });
  final bool right, reflow;
  static _ListTextScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ListTextScope>();
  @override
  bool updateShouldNotify(_ListTextScope oldWidget) =>
      right != oldWidget.right || reflow != oldWidget.reflow;
}

/// Layout the left, flexible contents and arrow independently. Unlike an
/// IntrinsicHeight Row this supports contents containing LayoutBuilder/editors.
class _ListSlots extends MultiChildRenderObjectWidget {
  _ListSlots({
    required Widget left,
    required Widget contents,
    required Widget arrow,
    required this.leftGap,
    required this.leftAlignment,
    required this.rightAlignment,
  }) : super(children: [left, contents, arrow]);
  final double leftGap;
  final TdsListRowAlignment leftAlignment, rightAlignment;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderListSlots(leftGap, leftAlignment, rightAlignment);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderListSlots renderObject,
  ) {
    renderObject
      ..gap = leftGap
      ..leftAlign = leftAlignment
      ..rightAlign = rightAlignment
      ..markNeedsLayout();
  }
}

class _SlotData extends ContainerBoxParentData<RenderBox> {}

class _RenderListSlots extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SlotData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SlotData> {
  _RenderListSlots(this.gap, this.leftAlign, this.rightAlign);
  double gap;
  TdsListRowAlignment leftAlign, rightAlign;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SlotData) child.parentData = _SlotData();
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'List rows need a bounded width.');
    final left = firstChild!, arrow = lastChild!;
    final main = childAfter(left)!;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    left.layout(loose, parentUsesSize: true);
    arrow.layout(loose, parentUsesSize: true);
    main.layout(
      BoxConstraints.tightFor(
        width: math.max(
          0,
          constraints.maxWidth - left.size.width - arrow.size.width - gap,
        ),
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(
        constraints.maxWidth,
        math.max(
          main.size.height,
          math.max(left.size.height, arrow.size.height),
        ),
      ),
    );
    (left.parentData! as _SlotData).offset = Offset(
      0,
      leftAlign == TdsListRowAlignment.top
          ? 0
          : (size.height - left.size.height) / 2,
    );
    (main.parentData! as _SlotData).offset = Offset(
      left.size.width + gap,
      (size.height - main.size.height) / 2,
    );
    (arrow.parentData! as _SlotData).offset = Offset(
      size.width - arrow.size.width,
      rightAlign == TdsListRowAlignment.top
          ? 0
          : (size.height - arrow.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
