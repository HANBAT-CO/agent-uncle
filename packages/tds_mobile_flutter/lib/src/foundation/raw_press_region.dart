import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Native event phases of the source ht hook, separate from tap recognition.
/// Touch end bubbles with the target; mouse end belongs to the window and runs
/// after ancestor pointer listeners. Neither waits for the tap arena to resolve.
class TdsRawPressRegion extends StatefulWidget {
  const TdsRawPressRegion({
    required this.child,
    this.onPressStart,
    this.onPressEnd,
    this.onPressCancel,
    super.key,
  });
  final Widget child;
  final void Function(PointerDownEvent event, Offset? firstTouch)? onPressStart;
  final VoidCallback? onPressEnd, onPressCancel;
  @override
  State<TdsRawPressRegion> createState() => _TdsRawPressRegionState();
}

class _TdsRawPressRegionState extends State<TdsRawPressRegion> {
  final _touches = <int, Offset>{};
  final _compatibilityTimers = <Timer>{};
  Timer? _lastCompatibilityTimer;
  bool _suppressMouse = false, _listeningForMouseEnd = false;

  void _down(PointerDownEvent event) {
    if (!mounted) return;
    if (event.kind == PointerDeviceKind.touch) {
      _touches[event.pointer] = event.position;
      widget.onPressStart?.call(event, _touches.values.first);
      _suppressMouse = true;
    } else if (!_suppressMouse) {
      if (!_listeningForMouseEnd) {
        GestureBinding.instance.pointerRouter.addGlobalRoute(_windowPointer);
        _listeningForMouseEnd = true;
      }
      widget.onPressStart?.call(event, null);
    }
  }

  void _touchEnd(PointerEvent event, {bool cancelled = false}) {
    // Flutter retains a pointer's hit-test path until up/cancel. Unlike a
    // detached DOM node, that path can still call this listener after unmount.
    if (!mounted) return;
    _touches.remove(event.pointer);
    (cancelled ? widget.onPressCancel : widget.onPressEnd)?.call();
    // ht suppresses the browser's compatibility mouse event for 300ms after
    // touch end/cancel, including when the component disables visual feedback.
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 300), () {
      _compatibilityTimers.remove(timer);
      _suppressMouse = false;
    });
    _lastCompatibilityTimer = timer;
    _compatibilityTimers.add(timer);
  }

  void _removeMouseListener() {
    if (!_listeningForMouseEnd) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_windowPointer);
    _listeningForMouseEnd = false;
  }

  void _windowPointer(PointerEvent event) {
    if (!mounted ||
        event is! PointerUpEvent ||
        event.kind == PointerDeviceKind.touch) {
      return;
    }
    _removeMouseListener();
    widget.onPressEnd?.call();
    _suppressMouse = false;
    _lastCompatibilityTimer?.cancel();
    _compatibilityTimers.remove(_lastCompatibilityTimer);
  }

  @override
  void dispose() {
    _removeMouseListener();
    for (final timer in _compatibilityTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: (event) {
      if (mounted && _touches.containsKey(event.pointer)) {
        _touches[event.pointer] = event.position;
      }
    },
    onPointerUp: (event) {
      if (event.kind == PointerDeviceKind.touch) _touchEnd(event);
    },
    onPointerCancel: (event) {
      if (!mounted) return;
      if (event.kind == PointerDeviceKind.touch) {
        _touchEnd(event, cancelled: true);
      } else {
        // Native pointer cancellation also releases the global observer; the
        // DOM has no equivalent mousecancel event.
        _removeMouseListener();
        widget.onPressCancel?.call();
      }
    },
    child: widget.child,
  );
}
