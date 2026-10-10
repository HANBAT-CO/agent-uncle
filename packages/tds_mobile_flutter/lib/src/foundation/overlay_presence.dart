import 'dart:async';
import 'package:flutter/widgets.dart';
import 'motion.dart';

/// Portal-owned animation lifetime. Exit callbacks run after removal animation,
/// never after owner disposal or when a closing overlay is reopened.
class TdsOverlayPresence extends StatefulWidget {
  const TdsOverlayPresence({
    required this.open,
    required this.builder,
    this.onExited,
    this.delay = Duration.zero,
    super.key,
  });
  final bool open;
  final Duration delay;
  final Widget Function(BuildContext, Animation<double>) builder;
  final VoidCallback? onExited;
  @override
  State<TdsOverlayPresence> createState() => _TdsOverlayPresenceState();
}

class _TdsOverlayPresenceState extends State<TdsOverlayPresence>
    with SingleTickerProviderStateMixin {
  final portal = OverlayPortalController();
  late final animation = AnimationController(
    vsync: this,
    duration: TdsMotion.basic.duration,
  );
  Timer? timer;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    animation.addStatusListener(status);
    schedule();
  }

  void status(AnimationStatus value) {
    if (value == AnimationStatus.dismissed && closing) {
      closing = false;
      portal.hide();
      widget.onExited?.call();
    }
  }

  void schedule() {
    timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.open) {
        closing = false;
        timer = Timer(widget.delay, () {
          if (mounted && widget.open) {
            portal.show();
            animation.forward();
          }
        });
      } else if (portal.isShowing) {
        closing = true;
        if (animation.isDismissed) {
          status(AnimationStatus.dismissed);
        } else {
          animation.reverse();
        }
      }
    });
  }

  @override
  void didUpdateWidget(TdsOverlayPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open || widget.delay != oldWidget.delay) {
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    animation.removeStatusListener(status);
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: (context) => Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.open,
        child: ExcludeSemantics(
          excluding: !widget.open,
          child: Stack(children: [widget.builder(context, animation)]),
        ),
      ),
    ),
  );
}
