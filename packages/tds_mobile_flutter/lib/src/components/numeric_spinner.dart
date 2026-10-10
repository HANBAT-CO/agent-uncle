import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';

enum TdsNumericSpinnerSize {
  tiny(TdsTypography.t7, 3, 8, 12, 8, 6, 3, 5, 6),
  small(TdsTypography.t6, 3, 12, 12, 10, 8, 5, 6, 8),
  medium(TdsTypography.t5, 4, 12, 16, 14, 10, 8, 8, 10),
  large(TdsTypography.t5, 4, 16, 16, 16, 14, 12, 14, 14);

  const TdsNumericSpinnerSize(
    this.typography,
    this.vertical,
    this.buttonPadding,
    this.iconSize,
    this.radius,
    this.numberRadius,
    this.numberVertical,
    this.numberHorizontal,
    this.gap,
  );
  final TdsTypography typography;
  final double vertical,
      buttonPadding,
      iconSize,
      radius,
      numberRadius,
      numberVertical,
      numberHorizontal,
      gap;
}

class TdsNumericSpinner extends StatefulWidget {
  const TdsNumericSpinner({
    required this.size,
    this.number,
    this.defaultNumber,
    this.minNumber = 0,
    this.maxNumber = 999,
    this.disabled = false,
    this.onNumberChange,
    this.minusButtonLabel = '빼기',
    this.plusButtonLabel = '더하기',
    this.semanticLabel,
    super.key,
  }) : assert(minNumber <= maxNumber),
       assert(number == null || defaultNumber == null);
  final TdsNumericSpinnerSize size;
  final int? number, defaultNumber;
  final int minNumber, maxNumber;
  final bool disabled;
  final ValueChanged<int>? onNumberChange;
  final String minusButtonLabel, plusButtonLabel;
  final String? semanticLabel;
  @override
  State<TdsNumericSpinner> createState() => _TdsNumericSpinnerState();
}

class _TdsNumericSpinnerState extends State<TdsNumericSpinner>
    with SingleTickerProviderStateMixin {
  late int _uncontrolled = widget.defaultNumber ?? 0;
  int get _number =>
      widget.number ?? (widget.defaultNumber != null ? _uncontrolled : 0);
  Timer? _timer;
  bool _repeated = false, _dragging = false;
  double _dragX = 0;
  int _activeDirection = 0;
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(microseconds: 437500),
  );

  void _step(int direction) {
    if (widget.disabled) return;
    final next = _number + direction;
    if (next < widget.minNumber || next > widget.maxNumber) {
      tdsHapticOf(context).generate(TdsHapticType.wiggle);
      _wiggle.forward(from: 0);
      return;
    }
    tdsHapticOf(context).generate(TdsHapticType.tickWeak);
    if (widget.defaultNumber != null) setState(() => _uncontrolled = next);
    widget.onNumberChange?.call(next);
  }

  void _repeat(int direction, [double milliseconds = 400]) {
    _timer?.cancel();
    _timer = Timer(
      Duration(microseconds: (math.max(50, milliseconds) * 1000).round()),
      () {
        if (!mounted || widget.disabled) return;
        _repeated = true;
        _step(direction);
        _repeat(direction, milliseconds * .8);
      },
    );
  }

  void _begin(int direction) {
    _repeated = false;
    setState(() => _activeDirection = direction);
    _repeat(direction);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _activeDirection = 0);
  }

  @override
  void didUpdateWidget(TdsNumericSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disabled && !oldWidget.disabled) {
      _timer?.cancel();
      _activeDirection = 0;
      _dragging = false;
      _dragX = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), s = widget.size;
    final style = theme.textStyle(
      typography: s.typography,
      fontWeight: TdsFontWeight.semibold,
      color: theme.color('grey800'),
    );
    final measure = TextPainter(
      text: TextSpan(text: '000', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = measure.width + s.numberHorizontal * 2;
    final height =
        theme.platform.lineHeight(s.typography) + s.numberVertical * 2;
    measure.dispose();
    final limit = s.buttonPadding + s.iconSize + s.gap - s.vertical;
    Widget button(int direction) => TdsPressable(
      enabled: !widget.disabled,
      semanticLabel: direction < 0
          ? widget.minusButtonLabel
          : widget.plusButtonLabel,
      onPressStart: () => _begin(direction),
      onPressEnd: _stop,
      onPressed: () {
        if (!_repeated) _step(direction);
      },
      builder: (context, pressed, hovered, focused) => SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(
            left: direction < 0 ? s.buttonPadding : 0,
            right: direction > 0 ? s.buttonPadding : 0,
          ),
          child: AnimatedScale(
            scale: pressed ? .9 : 1,
            duration: TdsMotion.rapid.duration,
            curve: TdsMotion.rapid,
            child: Center(
              child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="${direction > 0 ? _plusPath : _minusPath}"/></svg>',
                width: s.iconSize,
                height: s.iconSize,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(
                  theme.color(
                    (direction < 0
                            ? _number <= widget.minNumber
                            : _number >= widget.maxNumber)
                        ? 'grey300'
                        : pressed
                        ? 'grey900'
                        : 'grey700',
                  ),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      value: '$_number',
      liveRegion: true,
      enabled: !widget.disabled,
      increasedValue: _number < widget.maxNumber ? '${_number + 1}' : null,
      decreasedValue: _number > widget.minNumber ? '${_number - 1}' : null,
      onIncrease: !widget.disabled && _number < widget.maxNumber
          ? () => _step(1)
          : null,
      onDecrease: !widget.disabled && _number > widget.minNumber
          ? () => _step(-1)
          : null,
      child: Opacity(
        opacity: widget.disabled ? .3 : 1,
        child: AnimatedBuilder(
          animation: _wiggle,
          builder: (context, child) {
            const points = [0.0, 2.0, -2.0, 1.0, -1.0, 0.0];
            final t = _wiggle.value * 5, i = math.min(4, t.floor());
            return Transform.translate(
              offset: Offset(
                points[i] + (points[i + 1] - points[i]) * (t - i),
                0,
              ),
              child: child,
            );
          },
          child: AnimatedScale(
            scale: _dragging ? .96 : 1,
            duration: TdsMotion.quick.duration,
            curve: TdsMotion.quick,
            child: AnimatedContainer(
              duration: TdsMotion.quick.duration,
              curve: TdsMotion.quick,
              padding: EdgeInsets.symmetric(vertical: s.vertical),
              decoration: BoxDecoration(
                color: theme.color(_dragging ? 'grey200' : 'grey100'),
                borderRadius: BorderRadius.circular(_dragging ? 50 : s.radius),
              ),
              child: Stack(
                children: [
                  if (_activeDirection != 0 && !_dragging)
                    Positioned.fill(
                      child: Align(
                        alignment: _activeDirection < 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: .72,
                          heightFactor: .92,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.color('greyOpacity100'),
                              borderRadius: BorderRadius.circular(s.radius),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      button(-1),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: widget.disabled
                            ? null
                            : (_) {
                                _timer?.cancel();
                                setState(() {
                                  _dragging = true;
                                  _dragX = 0;
                                });
                              },
                        onHorizontalDragUpdate: widget.disabled
                            ? null
                            : (details) {
                                final previous = _dragX;
                                setState(
                                  () => _dragX = (_dragX + details.delta.dx)
                                      .clamp(-limit, limit),
                                );
                                if (_dragX.abs() == limit &&
                                    previous != _dragX) {
                                  _repeat(_dragX.sign.toInt());
                                }
                                if (_dragX.abs() < limit) {
                                  _timer?.cancel();
                                  _timer = null;
                                }
                              },
                        onHorizontalDragEnd: widget.disabled
                            ? null
                            : (_) {
                                if (_dragX.abs() >= limit) {
                                  _step(_dragX.sign.toInt());
                                }
                                _stop();
                                setState(() {
                                  _dragging = false;
                                  _dragX = 0;
                                });
                              },
                        onHorizontalDragCancel: () {
                          _stop();
                          setState(() {
                            _dragging = false;
                            _dragX = 0;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: s.gap),
                          child: Transform.translate(
                            offset: Offset(_dragX, 0),
                            child: AnimatedScale(
                              scale: _activeDirection != 0 ? .9 : 1,
                              duration: TdsMotion.rapid.duration,
                              curve: TdsMotion.rapid,
                              child: AnimatedContainer(
                                duration: TdsMotion.quick.duration,
                                curve: TdsMotion.quick,
                                width: width,
                                height: height,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.color(
                                    'tRadioIndicatorBackgroundColor',
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    _dragging ? 50 : s.numberRadius,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, .09),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: ExcludeSemantics(
                                  child: Text('$_number', style: style),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      button(1),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _plusPath =
    'M11.876 3.257a1.136 1.136 0 00-1.011 1.128l-.001 6.48H4.385c-.626 0-1.135.508-1.135 1.135l.007.124a1.136 1.136 0 001.128 1.011h6.479v6.48c0 .626.51 1.135 1.136 1.135l.124-.007a1.136 1.136 0 001.011-1.128v-6.48h6.48c.626 0 1.135-.508 1.135-1.135l-.007-.124a1.136 1.136 0 00-1.128-1.011h-6.48v-6.48c0-.626-.508-1.135-1.135-1.135l-.124.007z';
const _minusPath =
    'M19.835 10.9H4.165C3.52 10.9 3 11.392 3 12c0 .608.521 1.1 1.165 1.1h15.67C20.48 13.1 21 12.608 21 12c0-.608-.521-1.1-1.165-1.1z';
