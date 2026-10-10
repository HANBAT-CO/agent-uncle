import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Scalar CSS transition with the reversing-adjusted start value and shortening
/// factor from CSS Transitions §3. A reversal does not restart a full duration.
class TdsCssTransition extends ChangeNotifier {
  TdsCssTransition({
    required TickerProvider vsync,
    required double value,
    required this.baseDuration,
    this.curve = Curves.easeInOut,
  }) : _from = value,
       _to = value,
       _reversingStart = value {
    _controller = AnimationController(
      vsync: vsync,
      value: 1,
      duration: baseDuration,
    )..addListener(notifyListeners);
  }
  final Duration baseDuration;
  final Curve curve;
  late final AnimationController _controller;
  double _from, _to, _reversingStart, _shortening = 1;
  double get value =>
      _from + (_to - _from) * curve.transform(_controller.value);
  double get target => _to;
  Duration get duration => _controller.duration!;
  bool get isAnimating => _controller.isAnimating;

  void animateTo(double target) {
    if (target == _to) return;
    final current = value;
    if (_controller.isAnimating && target == _reversingStart) {
      _shortening =
          (curve.transform(_controller.value) * _shortening + (1 - _shortening))
              .abs()
              .clamp(0, 1);
      _reversingStart = _to;
    } else {
      _shortening = 1;
      _reversingStart = current;
    }
    _from = current;
    _to = target;
    _controller.duration = Duration(
      microseconds: (baseDuration.inMicroseconds * _shortening).round(),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
