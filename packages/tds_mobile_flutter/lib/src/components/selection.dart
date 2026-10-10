import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'text.dart';

enum TdsTabSize { small, large }

@immutable
class TdsTabItem {
  const TdsTabItem({
    required this.text,
    this.selected = false,
    this.redBean = false,
    this.onPressed,
  });
  final String text;
  final bool selected, redBean;
  final VoidCallback? onPressed;
}

class TdsTab extends StatefulWidget {
  const TdsTab({
    required this.items,
    required this.onChanged,
    this.size = TdsTabSize.large,
    this.fluid = false,
    this.itemGap,
    this.semanticLabel,
    super.key,
  }) : assert(items.length > 0);
  final List<TdsTabItem> items;
  final ValueChanged<int> onChanged;
  final TdsTabSize size;
  final bool fluid;
  final double? itemGap;
  final String? semanticLabel;
  @override
  State<TdsTab> createState() => _TdsTabState();
}

class _TdsTabState extends State<TdsTab> {
  final _focus = <FocusNode>[];
  final _scroll = ScrollController();
  int get _selected => widget.items.indexWhere((e) => e.selected);
  late int _focused = math.max(0, _selected);
  @override
  void initState() {
    super.initState();
    _syncFocus();
  }

  void _syncFocus() {
    while (_focus.length < widget.items.length) {
      _focus.add(FocusNode());
    }
    while (_focus.length > widget.items.length) {
      _focus.removeLast().dispose();
    }
    _focused = _focused.clamp(0, widget.items.length - 1);
  }

  @override
  void didUpdateWidget(TdsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
  }

  @override
  void dispose() {
    for (final node in _focus) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _choose(int index) {
    widget.items[index].onPressed?.call();
    widget.onChanged(index);
  }

  KeyEventResult _keyboard(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final next = key == LogicalKeyboardKey.home
        ? 0
        : key == LogicalKeyboardKey.end
        ? _focus.length - 1
        : key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowUp
        ? (_focused - 1 + _focus.length) % _focus.length
        : key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowDown
        ? (_focused + 1) % _focus.length
        : null;
    if (next == null) return KeyEventResult.ignored;
    setState(() => _focused = next);
    _focus[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final initialFont = widget.size == TdsTabSize.small
            ? TdsTypography.t6
            : TdsTypography.t5;
        final preliminary = widget.items
            .map(
              (e) => _textWidth(
                e.text,
                theme.textStyle(
                  typography: initialFont,
                  fontWeight: e.selected
                      ? TdsFontWeight.bold
                      : TdsFontWeight.semibold,
                ),
              ),
            )
            .toList();
        final available = constraints.maxWidth;
        final fluid =
            widget.fluid ||
            !available.isFinite ||
            preliminary.any(
              (w) => w.floor() > (available - 40) / widget.items.length - 16,
            );
        final typography = fluid ? TdsTypography.t5 : initialFont;
        final gap =
            widget.itemGap ??
            (fluid && widget.size == TdsTabSize.large ? 12 : 8);
        final left = fluid ? 14.0 : 20.0, right = fluid ? 0.0 : 20.0;
        final widths = widget.items
            .map(
              (e) => fluid
                  ? math.max(
                      64.0,
                      _textWidth(
                            e.text,
                            theme.textStyle(
                              typography: typography,
                              fontWeight: e.selected
                                  ? TdsFontWeight.bold
                                  : TdsFontWeight.semibold,
                            ),
                          ) +
                          gap * 2,
                    )
                  : math.max(
                      64.0,
                      (available - left - right) / widget.items.length,
                    ),
            )
            .toList();
        final selected = math.max(0, _selected);
        final x = widths.take(selected).fold(0.0, (a, b) => a + b);
        final height =
            theme.platform.size(typography) * 1.252 +
            (widget.size == TdsTabSize.large ? 26 : 16);
        _centerAfterLayout(
          _scroll,
          fluid,
          left + x + widths[selected] / 2,
          available,
        );
        return Semantics(
          label: widget.semanticLabel,
          explicitChildNodes: true,
          child: ColoredBox(
            color: theme.color('background'),
            child: Stack(
              children: [
                Focus(
                  skipTraversal: true,
                  onKeyEvent: _keyboard,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: left + widths.fold(0.0, (a, b) => a + b) + right,
                      height: height + 2,
                      child: Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: left, right: right),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < widget.items.length; i++)
                                  SizedBox(
                                    width: widths[i],
                                    height: height,
                                    child: MergeSemantics(
                                      child: Semantics(
                                        selected: widget.items[i].selected,
                                        child: TdsPressable(
                                          focusNode: _focus[i],
                                          skipTraversal: i != _focused,
                                          onPressed: () {
                                            setState(() => _focused = i);
                                            _choose(i);
                                          },
                                          builder: (context, pressed, hovered, focused) => Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: gap,
                                            ),
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: AnimatedScale(
                                                    scale: pressed ? .96 : 1,
                                                    duration: TdsMotion
                                                        .quick
                                                        .duration,
                                                    curve: TdsMotion.quick,
                                                    child: Text(
                                                      widget.items[i].text,
                                                      semanticsLabel:
                                                          widget
                                                              .items[i]
                                                              .redBean
                                                          ? '${widget.items[i].text} (업데이트 있음)'
                                                          : null,
                                                      maxLines: 1,
                                                      style: theme
                                                          .textStyle(
                                                            typography:
                                                                typography,
                                                            fontWeight:
                                                                widget
                                                                    .items[i]
                                                                    .selected
                                                                ? TdsFontWeight
                                                                      .bold
                                                                : TdsFontWeight
                                                                      .semibold,
                                                            color: theme.color(
                                                              widget
                                                                      .items[i]
                                                                      .selected
                                                                  ? 'grey800'
                                                                  : 'grey600',
                                                            ),
                                                          )
                                                          .copyWith(
                                                            height: 1.252,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                if (widget.items[i].redBean)
                                                  Positioned(
                                                    right: fluid ? -10 : 0,
                                                    top: 4,
                                                    child: Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Color(
                                                              0xfff44336,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          AnimatedPositioned(
                            duration: TdsMotion.quick.duration,
                            curve: TdsMotion.quick,
                            left: left + x + 10,
                            bottom: 0,
                            width: math.max(0, widths[selected] - 20),
                            height: 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.color('grey800'),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: TdsBorder()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum TdsSegmentedControlSize { small, large }

enum TdsSegmentedControlAlignment { fixed, fluid }

@immutable
class TdsSegmentedControlItem {
  const TdsSegmentedControlItem({
    required this.value,
    required this.text,
    this.disabled = false,
  });
  final String value, text;
  final bool disabled;
}

class TdsSegmentedControl extends StatefulWidget {
  const TdsSegmentedControl({
    required this.items,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.size = TdsSegmentedControlSize.large,
    this.alignment = TdsSegmentedControlAlignment.fixed,
    this.disabled = false,
    this.semanticLabel,
    super.key,
  }) : assert(items.length > 0);
  final List<TdsSegmentedControlItem> items;
  final String? value, defaultValue, semanticLabel;
  final ValueChanged<String>? onChanged;
  final TdsSegmentedControlSize size;
  final TdsSegmentedControlAlignment alignment;
  final bool disabled;
  @override
  State<TdsSegmentedControl> createState() => _TdsSegmentedControlState();
}

class _TdsSegmentedControlState extends State<TdsSegmentedControl> {
  static final _motion = TdsSpringCurve(stiffness: 1000, damping: 52);
  final _focus = <FocusNode>[];
  final _scroll = ScrollController();
  late String _internal = widget.defaultValue ?? '';
  String get _value => widget.value ?? _internal;
  @override
  void initState() {
    super.initState();
    _syncFocus();
  }

  void _syncFocus() {
    while (_focus.length < widget.items.length) {
      _focus.add(FocusNode());
    }
    while (_focus.length > widget.items.length) {
      _focus.removeLast().dispose();
    }
  }

  @override
  void didUpdateWidget(TdsSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
  }

  @override
  void dispose() {
    for (final node in _focus) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _choose(int index) {
    if (widget.disabled ||
        widget.items[index].disabled ||
        widget.items[index].value == _value) {
      return;
    }
    final value = widget.items[index].value;
    if (widget.value == null) setState(() => _internal = value);
    widget.onChanged?.call(value);
  }

  KeyEventResult _keyboard(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.disabled) {
      return KeyEventResult.ignored;
    }
    final enabled = [
      for (var i = 0; i < widget.items.length; i++)
        if (!widget.items[i].disabled) i,
    ];
    if (enabled.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final current = enabled.indexWhere((i) => _focus[i].hasFocus);
    final direction =
        key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp
        ? -1
        : key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowDown
        ? 1
        : 0;
    if (direction == 0 &&
        key != LogicalKeyboardKey.home &&
        key != LogicalKeyboardKey.end) {
      return KeyEventResult.ignored;
    }
    final index = key == LogicalKeyboardKey.home
        ? enabled.first
        : key == LogicalKeyboardKey.end
        ? enabled.last
        : enabled[(current + direction + enabled.length) % enabled.length];
    _focus[index].requestFocus();
    _choose(index);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => TdsFontScaleLimit(
    limit: 160,
    child: Builder(
      builder: (context) {
        final theme = TdsTheme.of(context),
            small = widget.size == TdsSegmentedControlSize.small;
        final typography = small ? TdsTypography.t6 : TdsTypography.t5;
        final padX = small ? 3.0 : 5.0, padY = small ? 3.0 : 4.0;
        final itemPadX = small ? 14.0 : 12.0, itemPadY = small ? 5.0 : 7.0;
        final style = theme
            .textStyle(typography: typography, fontWeight: TdsFontWeight.medium)
            .copyWith(height: 1.5);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final natural = widget.items
                  .map(
                    (e) =>
                        _textWidth(
                          e.text,
                          style.copyWith(
                            fontWeight: e.value == _value
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ) +
                        itemPadX * 2,
                  )
                  .toList();
              final fluid =
                  widget.alignment == TdsSegmentedControlAlignment.fluid &&
                  natural.fold(0.0, (a, b) => a + b) + padX * 2 >
                      constraints.maxWidth;
              final widths = fluid || !constraints.maxWidth.isFinite
                  ? natural
                  : List.filled(
                      widget.items.length,
                      (constraints.maxWidth - padX * 2) / widget.items.length,
                    );
              final selected = widget.items.indexWhere(
                (e) => e.value == _value,
              );
              final x = selected < 0
                  ? 0.0
                  : widths.take(selected).fold(0.0, (a, b) => a + b);
              final height = style.fontSize! * 1.5 + itemPadY * 2 + padY * 2;
              if (selected >= 0) {
                _centerAfterLayout(
                  _scroll,
                  fluid,
                  padX + x + widths[selected] / 2,
                  constraints.maxWidth,
                );
              }
              return Semantics(
                label: widget.semanticLabel,
                explicitChildNodes: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(small ? 10 : 14),
                  child: ColoredBox(
                    color: theme.color('greyOpacity100'),
                    child: Focus(
                      skipTraversal: true,
                      onKeyEvent: _keyboard,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: widths.fold(0.0, (a, b) => a + b) + padX * 2,
                          height: height,
                          child: Stack(
                            children: [
                              if (selected >= 0)
                                AnimatedPositioned(
                                  duration: _motion.duration,
                                  curve: _motion,
                                  left: padX + x,
                                  width: widths[selected],
                                  top: padY,
                                  bottom: padY,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.color(
                                        'tRadioIndicatorBackgroundColor',
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        small ? 8 : 10,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                          color: Color.fromRGBO(0, 0, 0, .09),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: padX,
                                  vertical: padY,
                                ),
                                child: Row(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < widget.items.length;
                                      i++
                                    )
                                      SizedBox(
                                        width: widths[i],
                                        child: MergeSemantics(
                                          child: Semantics(
                                            checked: i == selected,
                                            inMutuallyExclusiveGroup: true,
                                            child: TdsPressable(
                                              focusNode: _focus[i],
                                              skipTraversal:
                                                  i !=
                                                  (selected >= 0
                                                      ? selected
                                                      : widget.items.indexWhere(
                                                          (e) => !e.disabled,
                                                        )),
                                              button: false,
                                              enabled:
                                                  !widget.disabled &&
                                                  !widget.items[i].disabled,
                                              onPressed: () => _choose(i),
                                              builder:
                                                  (
                                                    context,
                                                    pressed,
                                                    hovered,
                                                    focused,
                                                  ) => Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: itemPadX,
                                                          vertical: itemPadY,
                                                        ),
                                                    child: AnimatedScale(
                                                      scale:
                                                          pressed &&
                                                              i != selected
                                                          ? .96
                                                          : 1,
                                                      duration: TdsMotion
                                                          .quick
                                                          .duration,
                                                      curve: TdsMotion.quick,
                                                      child: Text(
                                                        widget.items[i].text,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: style.copyWith(
                                                          fontWeight:
                                                              i == selected
                                                              ? FontWeight.w600
                                                              : FontWeight.w500,
                                                          color: theme.color(
                                                            widget.disabled ||
                                                                    widget
                                                                        .items[i]
                                                                        .disabled
                                                                ? 'grey400'
                                                                : i == selected
                                                                ? 'grey800'
                                                                : 'grey600',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void _centerAfterLayout(
  ScrollController scroll,
  bool enabled,
  double center,
  double viewportWidth,
) {
  if (!enabled || !viewportWidth.isFinite) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!scroll.hasClients) return;
    final target = (center - viewportWidth / 2).clamp(
      0.0,
      scroll.position.maxScrollExtent,
    );
    if ((scroll.offset - target).abs() > 1) {
      scroll.animateTo(
        target,
        duration: TdsMotion.quick.duration,
        curve: TdsMotion.quick,
      );
    }
  });
}
