import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

enum TdsCheckboxVariant { circle, line, lineTransparent }

enum TdsCheckboxInputType { checkbox, radio }

class TdsCheckbox extends StatefulWidget {
  const TdsCheckbox({
    this.variant = TdsCheckboxVariant.circle,
    this.checked,
    this.defaultChecked = false,
    this.disabled = false,
    this.inert = false,
    this.size = 24,
    this.onChanged,
    this.onCheckedChange,
    this.child,
    this.semanticLabel,
    this.focusNode,
    this.inputType = TdsCheckboxInputType.checkbox,
    super.key,
  });
  const TdsCheckbox.circle({
    this.checked,
    this.defaultChecked = false,
    this.disabled = false,
    this.inert = false,
    this.size = 24,
    this.onChanged,
    this.onCheckedChange,
    this.child,
    this.semanticLabel,
    this.focusNode,
    this.inputType = TdsCheckboxInputType.checkbox,
    super.key,
  }) : variant = TdsCheckboxVariant.circle;
  const TdsCheckbox.line({
    this.checked,
    this.defaultChecked = false,
    this.disabled = false,
    this.inert = false,
    this.size = 24,
    this.onChanged,
    this.onCheckedChange,
    this.child,
    this.semanticLabel,
    this.focusNode,
    this.inputType = TdsCheckboxInputType.checkbox,
    super.key,
  }) : variant = TdsCheckboxVariant.line;
  const TdsCheckbox.lineTransparent({
    this.checked,
    this.defaultChecked = false,
    this.disabled = false,
    this.inert = false,
    this.size = 24,
    this.onChanged,
    this.onCheckedChange,
    this.child,
    this.semanticLabel,
    this.focusNode,
    this.inputType = TdsCheckboxInputType.checkbox,
    super.key,
  }) : variant = TdsCheckboxVariant.lineTransparent;
  final TdsCheckboxVariant variant;
  final bool? checked;
  final bool defaultChecked, disabled, inert;
  final double size;
  final ValueChanged<bool>? onChanged, onCheckedChange;
  final Widget? child;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final TdsCheckboxInputType inputType;
  @override
  State<TdsCheckbox> createState() => _TdsCheckboxState();
}

class _TdsCheckboxState extends State<TdsCheckbox>
    with SingleTickerProviderStateMixin {
  late bool _internalChecked = widget.defaultChecked;
  late bool _optimisticChecked = checked;
  late bool _lastNotified = _internalChecked;
  late final AnimationController _wiggle;
  Timer? _activeEnd;
  bool _active = false, _pressed = false, _notificationQueued = false;
  int? _pointer;
  bool get checked => widget.checked ?? _internalChecked;

  @override
  void initState() {
    super.initState();
    _internalChecked = widget.defaultChecked;
    _optimisticChecked = checked;
    _lastNotified = _internalChecked;
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(microseconds: 437500),
    );
  }

  void _animateSelection() {
    _activeEnd?.cancel();
    _active = checked && !widget.disabled;
    if (_active) {
      _activeEnd = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _active = false);
      });
    }
  }

  @override
  void didUpdateWidget(TdsCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.checked ?? _internalChecked;
    _optimisticChecked = checked;
    if (widget.disabled != oldWidget.disabled ||
        widget.variant != oldWidget.variant) {
      // React swaps enabled/disabled graphic component types: no selection
      // animation on that new graphic's first mount.
      _activeEnd?.cancel();
      _active = false;
      _wiggle.reset();
    } else if (before != checked) {
      _animateSelection();
    }
    if (widget.disabled || widget.inert) {
      _pressed = false;
      _pointer = null;
    }
  }

  @override
  void dispose() {
    _activeEnd?.cancel();
    _wiggle.dispose();
    super.dispose();
  }

  void _change() {
    if (widget.disabled ||
        widget.inert ||
        (widget.inputType == TdsCheckboxInputType.radio && checked)) {
      return;
    }
    final value = !checked;
    widget.onChanged?.call(value);
    if (widget.checked != null) {
      // cr keeps an optimistic setter ref even if the controlled prop is
      // rejected. onChange still reports the hidden input's actual new value.
      _optimisticChecked = !_optimisticChecked;
      if (_optimisticChecked != checked) {
        widget.onCheckedChange?.call(_optimisticChecked);
      }
    } else {
      setState(() {
        _internalChecked = value;
        _animateSelection();
      });
      if (!_notificationQueued) {
        _notificationQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notificationQueued = false;
          if (!mounted || _lastNotified == _internalChecked) return;
          _lastNotified = _internalChecked;
          widget.onCheckedChange?.call(_internalChecked);
        });
      }
    }
  }

  void _pointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_pressed) setState(() => _pressed = false);
  }

  double get _wiggleX {
    const points = [0.0, 2.0, -2.0, 1.0, -1.0, 0.0];
    final frame = _wiggle.value * 5;
    final index = frame.floor().clamp(0, 4);
    final t = frame - index;
    // nC's `linear: true` is not a Framer `ease` option. The pinned runtime
    // actually applies its default quadratic ease-in-out to each keyframe.
    final ease = t <= .5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
    return points[index] + (points[index + 1] - points[index]) * ease;
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return ExcludeSemantics(
      excluding: widget.inert,
      child: MergeSemantics(
        child: Semantics(
          container: true,
          checked: checked,
          enabled: !widget.disabled,
          inMutuallyExclusiveGroup:
              widget.inputType == TdsCheckboxInputType.radio,
          label: widget.semanticLabel,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (widget.disabled ||
                  widget.inert ||
                  _pointer != null ||
                  event.buttons != 1) {
                return;
              }
              _pointer = event.pointer;
              tdsHapticOf(context).generate(TdsHapticType.tickWeak);
              if (!(checked &&
                  widget.inputType == TdsCheckboxInputType.radio)) {
                setState(() => _pressed = true);
              }
            },
            onPointerUp: _pointerEnd,
            onPointerCancel: _pointerEnd,
            child: TdsPressable(
              enabled: !widget.disabled && !widget.inert,
              button: false,
              focusNode: widget.focusNode,
              keyboardActivation: false,
              onDisabledTap: widget.disabled && !widget.inert
                  ? () => _wiggle.forward(from: 0)
                  : null,
              onPressed: _change,
              builder: (context, pressed, hovered, focused) {
                final highlighted = (_pressed || hovered) && !widget.disabled;
                final selected = theme.color(
                  highlighted
                      ? theme.colorScheme == TdsColorPreference.dark
                            ? 'blue300'
                            : 'blue700'
                      : 'blue500',
                );
                final unselected =
                    widget.variant == TdsCheckboxVariant.lineTransparent
                    ? const Color(0x00000000)
                    : theme.color(highlighted ? 'grey400' : 'grey300');
                final colors = (
                  outline: unselected,
                  fill: selected,
                  check: checked
                      ? (highlighted
                            ? TdsPalette.lightThemeGrey400
                            : TdsPalette.background)
                      : widget.disabled
                      ? theme.color('grey200')
                      : unselected,
                  selection: checked ? 1.0 : 0.0,
                );
                final scale = _pressed
                    ? .8
                    : _active
                    ? 1.1
                    : 1.0;
                final spring = _pressed
                    ? TdsMotion.rapid
                    : _active
                    ? TdsMotion.quick
                    : TdsMotion.bounce;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      key: ValueKey((widget.variant, widget.disabled)),
                      animation: _wiggle,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_wiggleX, 0),
                        child: child,
                      ),
                      child: AnimatedScale(
                        scale: scale,
                        duration: spring.duration,
                        curve: spring,
                        child: Opacity(
                          opacity: widget.disabled ? .4 : 1,
                          child: TweenAnimationBuilder<_CheckboxColors>(
                            tween: _CheckboxColorsTween(
                              begin: colors,
                              end: colors,
                            ),
                            duration: widget.disabled
                                ? Duration.zero
                                : (highlighted
                                          ? TdsMotion.rapid
                                          : TdsMotion.quick)
                                      .duration,
                            curve: highlighted
                                ? TdsMotion.rapid
                                : TdsMotion.quick,
                            builder: (context, paint, _) {
                              final svg =
                                  widget.variant == TdsCheckboxVariant.circle
                                  ? '<path fill="${_hex(theme.color('background'))}" d="$_circleFill"/>'
                                        '<path fill="${_hex(paint.outline)}" opacity="${1 - paint.selection}" d="$_circleOutline"/>'
                                        '<path fill="${_hex(paint.fill)}" opacity="${paint.selection}" d="$_circleFill"/>'
                                        '<path fill="${_hex(paint.check)}" d="$_circleCheck"/>'
                                  : '<path fill="${_hex(_mixColor(paint.outline, paint.fill, paint.selection))}" fill-opacity="${_mixColor(paint.outline, paint.fill, paint.selection).a}" d="$_lineCheck"/>';
                              return SvgPicture.string(
                                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">$svg</svg>',
                                width: widget.size,
                                height: widget.size,
                                excludeFromSemantics: true,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (widget.child != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: widget.child!),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

typedef _CheckboxColors = ({
  Color outline,
  Color fill,
  Color check,
  double selection,
});

class _CheckboxColorsTween extends Tween<_CheckboxColors> {
  _CheckboxColorsTween({super.begin, super.end});
  @override
  _CheckboxColors lerp(double t) => (
    outline: _mixColor(begin!.outline, end!.outline, t),
    fill: _mixColor(begin!.fill, end!.fill, t),
    check: _mixColor(begin!.check, end!.check, t),
    selection: begin!.selection + (end!.selection - begin!.selection) * t,
  );
}

// Framer interpolates squared sRGB channels (not Flutter's linear Color.lerp).
Color _mixColor(Color a, Color b, double t) {
  int channel(double x, double y) =>
      (math.sqrt((x * x + (y * y - x * x) * t).clamp(0, 1)) * 255).round();
  return Color.from(
    alpha: (a.a + (b.a - a.a) * t).clamp(0, 1),
    red: channel(a.r, b.r) / 255,
    green: channel(a.g, b.g) / 255,
    blue: channel(a.b, b.b) / 255,
  );
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// The original line path reused by agreement marks without nesting inputs.
class TdsCheckboxLineGraphic extends StatelessWidget {
  const TdsCheckboxLineGraphic({
    required this.size,
    required this.color,
    super.key,
  });
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="${_hex(color)}" d="$_lineCheck"/></svg>',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

const _circleOutline =
    'M12 3C17 3 21 7 21 12C21 17 17 21 12 21C7 21 3 17 3 12C3 7 7 3 12 3ZM12 1C5.9 1 1 5.9 1 12C1 18.1 5.9 23 12 23C18.1 23 23 18.1 23 12C23 5.9 18.1 1 12 1Z';
const _circleFill =
    'M12 1C5.9 1 1 5.9 1 12C1 18.1 5.9 23 12 23C18.1 23 23 18.1 23 12C23 5.9 18.1 1 12 1Z';
const _circleCheck =
    'M17.2 10.2L11.6 15.8C11.4 16 11.2 16.1 10.9 16.1C10.6 16.1 10.4 16 10.2 15.8L6.8 12.4C6.4 12 6.4 11.4 6.8 11C7.2 10.6 7.8 10.6 8.2 11L10.9 13.7L15.8 8.8C16.2 8.4 16.8 8.4 17.2 8.8C17.6 9.2 17.6 9.8 17.2 10.2Z';
const _lineCheck =
    'm10.4099 17.8538c-.3393 0-.67866-.1131-.90488-.4524l-5.20306-5.2031c-.56556-.5655-.56556-1.3573 0-1.9228.56555-.56559 1.35732-.56559 1.92287 0l4.18507 4.185 7.4653-7.46523c.5655-.56555 1.3573-.56555 1.9228 0 .5656.56555.5656 1.35732 0 1.92287l-8.3701 8.37016c-.3393.4524-.6787.5655-1.018.5655z';
