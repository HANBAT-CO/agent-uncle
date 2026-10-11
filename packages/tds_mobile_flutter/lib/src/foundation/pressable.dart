import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'activation_scope.dart';
import 'input_dispatch.dart';

/// Shared pointer/keyboard contract; visual feedback belongs to each component.
class TdsPressable extends StatefulWidget {
  const TdsPressable({
    required this.builder,
    this.onPressed,
    this.enabled = true,
    this.semanticLabel,
    this.button = true,
    this.focusNode,
    this.autofocus = false,
    this.skipTraversal = false,
    this.onPressStart,
    this.onPressEnd,
    this.activateOnPressStart = false,
    this.activateOnEnterDown = false,
    this.activateOnKeyDown = false,
    this.deferPointerActivation = false,
    this.allowPointerEffect,
    this.keyboardActivation = true,
    this.keyboardPressEffect = true,
    this.focusableWhenDisabled = false,
    this.onDisabledTap,
    super.key,
  });
  final Widget Function(
    BuildContext context,
    bool pressed,
    bool hovered,
    bool focused,
  )
  builder;
  final VoidCallback? onPressed, onPressStart, onPressEnd;
  final VoidCallback? onDisabledTap;
  final bool enabled, button, autofocus, skipTraversal;
  // Some source controls use focusable labels with a hidden native input.
  // Those labels receive focus but do not synthesize Enter/Space clicks.
  final bool keyboardActivation, focusableWhenDisabled;

  /// Some original controls only animate in response to pointer events, even
  /// though their HTML element still supports native keyboard activation.
  final bool keyboardPressEffect;

  /// Keypads commit on pointer down, while ordinary controls commit on tap.
  /// Semantics and keyboard activation remain available in either mode.
  final bool activateOnPressStart;
  final bool activateOnEnterDown;

  /// ListRow synthesizes clicks for every Enter/Space keydown (including
  /// repeat), without starting a pointer-style press animation.
  final bool activateOnKeyDown;

  /// DOM click follows the release event and its state commit. Keep the whole
  /// child/compound activation chain together when native pointer routes need
  /// to finish first, rather than deferring only the child's callback.
  final bool deferPointerActivation;

  /// Allows a component to suppress visual feedback (e.g. iOS edge navigation)
  /// without suppressing the accepted tap or keyboard activation.
  final bool Function(PointerDownEvent event)? allowPointerEffect;
  final String? semanticLabel;
  final FocusNode? focusNode;
  @override
  State<TdsPressable> createState() => _TdsPressableState();
}

class _TdsPressableState extends State<TdsPressable> {
  bool _pressed = false, _hovered = false, _focused = false;
  int? _pointer;
  bool _allowPointerEffect = true;
  final _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
  TdsActivationController? _activation;
  VoidCallback? get _onActivate =>
      widget.onPressed != null || _activation != null ? _activate : null;
  void _activate() {
    TdsInputDispatch.run(() {
      widget.onPressed?.call();
      if (mounted) _activation?.activate(_focus);
    });
  }

  void _pointerActivate() {
    if (!widget.deferPointerActivation) {
      _activate();
      return;
    }
    scheduleMicrotask(() {
      scheduleMicrotask(() {
        if (mounted && widget.enabled) _activate();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TdsActivationScope.maybeOf(context);
    if (_activation != next) {
      _activation?.unregister(this);
      _activation = next;
      _activation?.register(this);
    }
  }

  @override
  void dispose() {
    _activation?.unregister(this);
    _ownFocus.dispose();
    super.dispose();
  }

  void _press(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
    final callback = value ? widget.onPressStart : widget.onPressEnd;
    if (callback != null) TdsInputDispatch.run(callback);
  }

  @override
  void didUpdateWidget(TdsPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pressed = false;
      _pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.button,
    enabled: widget.enabled,
    label: widget.semanticLabel,
    onTap: widget.enabled ? _onActivate : null,
    child: Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      skipTraversal: widget.skipTraversal,
      canRequestFocus: widget.enabled || widget.focusableWhenDisabled,
      onFocusChange: (value) => setState(() {
        _focused = value;
        if (!value) _pressed = false;
      }),
      onKeyEvent: (_, event) {
        if (!widget.enabled ||
            !widget.keyboardActivation ||
            (event.logicalKey != LogicalKeyboardKey.enter &&
                event.logicalKey != LogicalKeyboardKey.space)) {
          return KeyEventResult.ignored;
        }
        if (widget.activateOnKeyDown) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            _onActivate?.call();
          }
          return KeyEventResult.handled;
        }
        final commitOnDown =
            widget.activateOnPressStart ||
            event.logicalKey == LogicalKeyboardKey.enter &&
                (widget.activateOnEnterDown || _activation != null);
        // Native HTML buttons repeat Enter clicks on repeated keydown, while
        // Space still produces a single activation when released.
        if (event is KeyRepeatEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            widget.activateOnEnterDown) {
          _onActivate?.call();
        }
        if (event is KeyDownEvent && !_pressed) {
          _allowPointerEffect = widget.keyboardPressEffect;
          _press(true);
          if (commitOnDown) _onActivate?.call();
        }
        if (event is KeyUpEvent && _pressed) {
          _press(false);
          if (!commitOnDown) _onActivate?.call();
        }
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: widget.enabled
              ? (event) {
                  _allowPointerEffect =
                      widget.allowPointerEffect?.call(event) ?? true;
                  if (!widget.activateOnPressStart) return;
                  if (_pointer != null || event.buttons != 1) return;
                  _pointer = event.pointer;
                  _press(true);
                  _onActivate?.call();
                }
              : null,
          onPointerUp: (event) {
            if (_pointer != event.pointer) return;
            _pointer = null;
            _press(false);
          },
          onPointerCancel: (event) {
            if (_pointer != event.pointer) return;
            _pointer = null;
            _press(false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: widget.enabled && !widget.activateOnPressStart
                ? (_) => _press(true)
                : null,
            onTapUp: widget.enabled && !widget.activateOnPressStart
                ? (_) => _press(false)
                : null,
            onTapCancel: widget.enabled && !widget.activateOnPressStart
                ? () => _press(false)
                : null,
            onTap: widget.enabled && !widget.activateOnPressStart
                ? (_onActivate == null ? null : _pointerActivate)
                // Disabled DOM controls suppress click bubbling. Claim the
                // gesture here so a compound trigger's fallback cannot win it.
                : !widget.enabled && widget.onDisabledTap != null
                ? widget.onDisabledTap
                : !widget.enabled && _activation != null
                ? () {}
                : null,
            child: widget.builder(
              context,
              _pressed && _allowPointerEffect,
              _hovered,
              _focused,
            ),
          ),
        ),
      ),
    ),
  );
}
