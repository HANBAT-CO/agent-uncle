import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

class TdsSwitch extends StatefulWidget {
  const TdsSwitch({
    this.checked = false,
    this.onChanged,
    this.onPressed,
    this.disabled = false,
    this.inert = false,
    this.hasTouchEffect = true,
    this.semanticLabel,
    this.focusNode,
    super.key,
  });
  final bool checked, disabled, inert, hasTouchEffect;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final FocusNode? focusNode;
  @override
  State<TdsSwitch> createState() => _TdsSwitchState();
}

class _TdsSwitchState extends State<TdsSwitch> {
  // W.registerGesture runs once. TB's initial h callback captures Ee's null
  // rally, so k_.pressed/wiggle never run in the pinned 2.5.1 browser package.
  // It also captures initial haptic/touch options. Do not invent release motion.
  late final bool _touchEffect;
  late final bool _initialDisabled;
  TdsHaptic? _haptic;
  @override
  void initState() {
    super.initState();
    _touchEffect = widget.hasTouchEffect;
    _initialDisabled = widget.disabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _haptic ??= tdsHapticOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return ExcludeSemantics(
      excluding: widget.inert,
      child: MergeSemantics(
        child: Semantics(
          container: true,
          toggled: widget.checked,
          enabled: !widget.disabled,
          label: widget.semanticLabel,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.inert
                ? null
                : (_) {
                    if (_touchEffect && !_initialDisabled) {
                      _haptic!.generate(TdsHapticType.softWeak);
                    }
                  },
            child: TdsPressable(
              enabled: !widget.disabled && !widget.inert,
              button: false,
              focusNode: widget.focusNode,
              keyboardActivation: false,
              focusableWhenDisabled: !widget.inert,
              onPressed: () {
                widget.onPressed?.call();
                widget.onChanged?.call(!widget.checked);
              },
              builder: (context, pressed, hovered, focused) {
                final motion = TdsMotion.quick;
                return Opacity(
                  opacity: widget.disabled ? .3 : 1,
                  child: AnimatedContainer(
                    width: 50,
                    height: 30,
                    duration: motion.duration,
                    curve: motion,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: theme.color(
                        widget.checked ? 'blue500' : 'grey200',
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedPositioned(
                          left: widget.checked ? 23 : 7,
                          top: 3,
                          bottom: 3,
                          duration: TdsMotion.medium.duration,
                          curve: TdsMotion.medium,
                          child: Center(
                            child: AnimatedContainer(
                              width: widget.checked ? 24 : 16,
                              height: widget.checked ? 24 : 16,
                              duration: TdsMotion.quick.duration,
                              curve: TdsMotion.quick,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: TdsPalette.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
