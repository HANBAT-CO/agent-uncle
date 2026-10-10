import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/portal.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/css_shadow.dart';
import 'asset.dart';
import 'text.dart';
import 'tooltip.dart';

class TdsSearchField extends StatefulWidget {
  const TdsSearchField({
    this.controller,
    this.focusNode,
    this.value,
    this.placeholder,
    this.onChanged,
    this.onDeleteClick,
    this.onSubmitted,
    this.onTap,
    this.disabled = false,
    this.readOnly = false,
    this.autofocus = false,
    this.fixed = false,
    this.takeSpace = true,
    super.key,
  }) : assert(controller == null || value == null);
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? value, placeholder;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onDeleteClick, onTap;
  final bool disabled, readOnly, autofocus, fixed, takeSpace;
  @override
  State<TdsSearchField> createState() => _TdsSearchFieldState();
}

class _TdsSearchFieldState extends State<TdsSearchField> {
  late TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.value);
  late FocusNode _focus = widget.focusNode ?? FocusNode();
  @override
  void didUpdateWidget(TdsSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final text = _controller.text;
      if (oldWidget.controller == null) _controller.dispose();
      _controller =
          widget.controller ??
          TextEditingController(text: widget.value ?? text);
    } else if (widget.value != oldWidget.value &&
        widget.value != null &&
        widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value!,
        selection: TextSelection.collapsed(offset: widget.value!.length),
      );
    }
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: theme.color('background'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: GestureDetector(
              onTap: widget.disabled
                  ? null
                  : () {
                      _focus.requestFocus();
                      widget.onTap?.call();
                    },
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.color('opacity100'),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    TdsAssetIcon(
                      name: 'icn-searchfield',
                      size: 24,
                      color: theme.color('grey600'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => Semantics(
                          label: widget.placeholder,
                          textField: true,
                          enabled: !widget.disabled,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              if (value.text.isEmpty &&
                                  widget.placeholder != null)
                                ExcludeSemantics(
                                  child: TdsText(
                                    widget.placeholder!,
                                    color: theme.color('grey500'),
                                  ),
                                ),
                              ExcludeFocus(
                                excluding: widget.disabled,
                                child: IgnorePointer(
                                  ignoring: widget.disabled,
                                  child: EditableText(
                                    controller: _controller,
                                    focusNode: _focus,
                                    style: theme.textStyle().copyWith(
                                      height: 1.35,
                                    ),
                                    cursorColor: theme.color('blue500'),
                                    backgroundCursorColor: theme.color(
                                      'grey400',
                                    ),
                                    selectionColor: theme
                                        .color('blue400')
                                        .withValues(alpha: .3),
                                    readOnly:
                                        widget.readOnly || widget.disabled,
                                    autofocus: widget.autofocus,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.search,
                                    onChanged: widget.onChanged,
                                    onSubmitted: widget.onSubmitted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox()
                          : TdsPressable(
                              enabled: !widget.disabled && !widget.readOnly,
                              semanticLabel: '검색어 삭제',
                              onPressed: () {
                                widget.onDeleteClick?.call();
                                _controller.clear();
                                widget.onChanged?.call('');
                                _focus.requestFocus();
                              },
                              builder: (context, p, h, f) => TdsAssetIcon(
                                name: 'icn-delete',
                                size: 24,
                                color: theme.color('grey400'),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.color('background'),
                  theme.color('background').withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (widget.fixed) {
      content = TdsFixedPanel(
        top: true,
        takeSpace: widget.takeSpace,
        child: content,
      );
    }
    return content;
  }
}

class TdsSliderLabel {
  const TdsSliderLabel({required this.min, required this.max, this.mid});
  final String min, max;
  final String? mid;
}

class TdsSlider extends StatefulWidget {
  const TdsSlider({
    this.value,
    this.defaultValue,
    this.minValue = 0,
    this.maxValue = 100,
    this.step = 1,
    this.onValueChange,
    this.color,
    this.label,
    this.tooltip,
    this.disabled = false,
    this.semanticLabel,
    super.key,
  }) : assert(minValue < maxValue),
       assert(step > 0);
  final double? value, defaultValue;
  final double minValue, maxValue, step;
  final ValueChanged<double>? onValueChange;
  final Color? color;
  final TdsSliderLabel? label;
  final Widget? tooltip;
  final bool disabled;
  final String? semanticLabel;
  @override
  State<TdsSlider> createState() => _TdsSliderState();
}

class _TdsSliderState extends State<TdsSlider> {
  late double _value =
      widget.defaultValue ?? (widget.minValue + widget.maxValue) / 2;
  double get value =>
      (widget.value ?? _value).clamp(widget.minValue, widget.maxValue);
  void change(double input) {
    if (widget.disabled) return;
    final next =
        (widget.minValue +
                ((input - widget.minValue) / widget.step).round() * widget.step)
            .clamp(widget.minValue, widget.maxValue);
    if (next == value) return;
    if (widget.value == null) setState(() => _value = next);
    widget.onValueChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context),
        fraction =
            (value - widget.minValue) / (widget.maxValue - widget.minValue);
    return _SliderScope(
      value: value,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            slider: true,
            label: widget.semanticLabel,
            value: '$value',
            enabled: !widget.disabled,
            increasedValue:
                '${(value + widget.step).clamp(widget.minValue, widget.maxValue)}',
            decreasedValue:
                '${(value - widget.step).clamp(widget.minValue, widget.maxValue)}',
            onIncrease: !widget.disabled && value < widget.maxValue
                ? () => change(value + widget.step)
                : null,
            onDecrease: !widget.disabled && value > widget.minValue
                ? () => change(value - widget.step)
                : null,
            child: Focus(
              canRequestFocus: !widget.disabled,
              onKeyEvent: (_, e) {
                if (e is! KeyDownEvent || widget.disabled) {
                  return KeyEventResult.ignored;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowRight ||
                    e.logicalKey == LogicalKeyboardKey.arrowUp) {
                  change(value + widget.step);
                } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    e.logicalKey == LogicalKeyboardKey.arrowDown) {
                  change(value - widget.step);
                } else if (e.logicalKey == LogicalKeyboardKey.home) {
                  change(widget.minValue);
                } else if (e.logicalKey == LogicalKeyboardKey.end) {
                  change(widget.maxValue);
                } else {
                  return KeyEventResult.ignored;
                }
                return KeyEventResult.handled;
              },
              child: SizedBox(
                height: 40,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final extent = math.max(1.0, width - 24),
                        x = 12 + extent * fraction;
                    void position(Offset offset) => change(
                      widget.minValue +
                          ((offset.dx - 12) / extent).clamp(0.0, 1.0) *
                              (widget.maxValue - widget.minValue),
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: widget.disabled
                          ? null
                          : (e) => position(e.localPosition),
                      onHorizontalDragStart: widget.disabled
                          ? null
                          : (e) => position(e.localPosition),
                      onHorizontalDragUpdate: widget.disabled
                          ? null
                          : (e) => position(e.localPosition),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 17.5,
                            left: 0,
                            right: 0,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.color('grey200'),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 17.5,
                            left: 0,
                            width: x,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.color ?? theme.color('blue400'),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                          Positioned(
                            left: x - 12,
                            top: 8,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xffffffff),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  TdsCssBoxShadow(
                                    color: theme.color('greyOpacity200'),
                                    spreadRadius: 1,
                                  ),
                                  TdsCssBoxShadow(
                                    color: theme.color('greyOpacity200'),
                                    offset: const Offset(0, 8),
                                    blurRadius: 8,
                                  ),
                                  TdsCssBoxShadow(
                                    color: theme.color('greyOpacity300'),
                                    offset: const Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.tooltip != null)
                            Positioned(
                              left: x,
                              top: 17.5,
                              child: widget.tooltip!,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (widget.label != null)
            SizedBox(
              height: 20,
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TdsText(
                        widget.label!.min,
                        typography: TdsTypography.t7,
                        fontWeight: TdsFontWeight.medium,
                        color: theme.color('grey600'),
                      ),
                      TdsText(
                        widget.label!.max,
                        typography: TdsTypography.t7,
                        fontWeight: TdsFontWeight.medium,
                        color: theme.color('grey600'),
                      ),
                    ],
                  ),
                  if (widget.label!.mid != null)
                    Center(
                      child: TdsText(
                        widget.label!.mid!,
                        typography: TdsTypography.t7,
                        fontWeight: TdsFontWeight.medium,
                        color: theme.color('grey600'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SliderScope extends InheritedWidget {
  const _SliderScope({required this.value, required super.child});
  final double value;
  @override
  bool updateShouldNotify(_SliderScope oldWidget) => value != oldWidget.value;
}

class TdsSliderTooltip extends StatelessWidget {
  const TdsSliderTooltip({
    this.message,
    this.messageWidget,
    this.formatValue,
    this.open = true,
    this.defaultOpen = false,
    this.onOpenChange,
    this.size = TdsTooltipSize.medium,
    this.placement = TdsOverlayPlacement.top,
    this.messageAlign = TextAlign.center,
    this.motionVariant = TdsTooltipMotion.weak,
    this.offset = 30,
    this.anchorPositionByRatio = .5,
    this.openOnHover = false,
    this.openOnFocus = false,
    this.dismissible = false,
    this.autoFlip = false,
    this.clipToEnd = TdsTooltipClip.none,
    super.key,
  }) : assert(message == null || messageWidget == null);
  final String? message;
  final Widget? messageWidget;
  final String Function(double)? formatValue;
  final bool? open;
  final bool defaultOpen, openOnHover, openOnFocus, dismissible, autoFlip;
  final ValueChanged<bool>? onOpenChange;
  final TdsTooltipSize size;
  final TdsOverlayPlacement placement;
  final TextAlign messageAlign;
  final TdsTooltipMotion motionVariant;
  final double offset, anchorPositionByRatio;
  final TdsTooltipClip clipToEnd;
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SliderScope>();
    if (scope == null) {
      throw StateError('TdsSliderTooltip requires a TdsSlider ancestor.');
    }
    final value = scope.value;
    return TdsTooltip(
      message:
          messageWidget ??
          Text(
            message ??
                formatValue?.call(value) ??
                value.toString().replaceFirst(RegExp(r'\.0(?=e|$)'), ''),
          ),
      open: open,
      defaultOpen: defaultOpen,
      onOpenChange: onOpenChange,
      size: size,
      placement: placement,
      messageAlign: messageAlign,
      motionVariant: motionVariant,
      offset: offset,
      anchorPositionByRatio: anchorPositionByRatio,
      openOnHover: openOnHover,
      openOnFocus: openOnFocus,
      dismissible: dismissible,
      autoFlip: autoFlip,
      clipToEnd: clipToEnd,
      child: const SizedBox.shrink(),
    );
  }
}
