import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import '../foundation/overlay_presence.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'text.dart';

enum TdsPointPosition { center, bottom }

class TdsPointOverlay extends StatefulWidget {
  const TdsPointOverlay({
    required this.open,
    required this.title,
    required this.onClose,
    this.subtitle,
    this.position = TdsPointPosition.bottom,
    this.bottomOffset = 88,
    this.duration = const Duration(seconds: 3),
    this.closeLockDuration = const Duration(seconds: 1),
    this.onExited,
    super.key,
  });
  final bool open;
  final String title;
  final String? subtitle;
  final TdsPointPosition position;
  final double bottomOffset;
  final Duration duration, closeLockDuration;
  final VoidCallback onClose;
  final VoidCallback? onExited;
  @override
  State<TdsPointOverlay> createState() => _TdsPointOverlayState();
}

class _TdsPointOverlayState extends State<TdsPointOverlay> {
  Timer? closeTimer, unlockTimer;
  bool locked = true, notified = false;
  void close() {
    if (notified) return;
    notified = true;
    widget.onClose();
  }

  void schedule() {
    closeTimer?.cancel();
    unlockTimer?.cancel();
    notified = false;
    locked = widget.closeLockDuration > Duration.zero;
    if (widget.open) {
      closeTimer = Timer(widget.duration, close);
      unlockTimer = Timer(widget.closeLockDuration, () {
        if (mounted) setState(() => locked = false);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(TdsPointOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open ||
        widget.duration != oldWidget.duration ||
        widget.closeLockDuration != oldWidget.closeLockDuration) {
      schedule();
    }
  }

  @override
  void dispose() {
    closeTimer?.cancel();
    unlockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TdsOverlayPresence(
    open: widget.open,
    onExited: widget.onExited,
    builder: (context, animation) {
      final content = FadeTransition(
        opacity: animation,
        child: TdsPressable(
          enabled: !locked,
          onPressed: close,
          semanticLabel: '포인트 안내 닫기',
          builder: (_, _, _, _) =>
              _PointContent(title: widget.title, subtitle: widget.subtitle),
        ),
      );
      return widget.position == TdsPointPosition.center
          ? Positioned.fill(child: Center(child: content))
          : Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomOffset,
              child: content,
            );
    },
  );
}

class TdsPointCTAOverlay extends StatelessWidget {
  const TdsPointCTAOverlay({
    required this.open,
    required this.title,
    this.subtitle,
    this.cta,
    this.onExited,
    super.key,
  });
  final bool open;
  final String title;
  final String? subtitle;
  final Widget? cta;
  final VoidCallback? onExited;
  @override
  Widget build(BuildContext context) => TdsOverlayPresence(
    open: open,
    onExited: onExited,
    builder: (context, animation) => Positioned.fill(
      child: FadeTransition(
        opacity: animation,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        TdsTheme.of(context).color('background'),
                        TdsTheme.of(
                          context,
                        ).color('background').withValues(alpha: 0),
                      ],
                      stops: const [.2, 1],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FocusScope(
                autofocus: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PointContent(title: title, subtitle: subtitle),
                    ?cta,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PointContent extends StatelessWidget {
  const _PointContent({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return Semantics(
      liveRegion: true,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                maxWidth: 400,
                maxHeight: 400,
                child: Image.asset(
                  'assets/point/point-blue2.png',
                  package: 'tds_mobile_flutter',
                  width: 400,
                  height: 400,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 100,
                  child: Lottie.asset(
                    'assets/point/point-spot.json',
                    package: 'tds_mobile_flutter',
                    repeat: false,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: TdsText(
                  title,
                  typography: TdsTypography.t2,
                  fontWeight: TdsFontWeight.bold,
                  textAlign: TextAlign.center,
                  color: theme.color('greyOpacity800'),
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TdsText(
                    subtitle!,
                    typography: TdsTypography.t5,
                    fontWeight: TdsFontWeight.semibold,
                    textAlign: TextAlign.center,
                    color: theme.color('greyOpacity600'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TdsPointToast extends StatefulWidget {
  const TdsPointToast({
    required this.open,
    required this.text,
    required this.onClose,
    this.topOffset = 0,
    this.duration = const Duration(seconds: 3),
    this.onClick,
    this.onExited,
    super.key,
  });
  final bool open;
  final String text;
  final double topOffset;
  final Duration duration;
  final VoidCallback onClose;
  final VoidCallback? onClick, onExited;
  @override
  State<TdsPointToast> createState() => _TdsPointToastState();
}

class _TdsPointToastState extends State<TdsPointToast> {
  Timer? timer;
  void schedule() {
    timer?.cancel();
    if (widget.open) timer = Timer(widget.duration, () => widget.onClose());
  }

  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(TdsPointToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open ||
        widget.duration != oldWidget.duration) {
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TdsOverlayPresence(
    open: widget.open,
    onExited: widget.onExited,
    builder: (context, animation) {
      final theme = TdsTheme.of(context);
      return Positioned(
        left: 12,
        right: 12,
        top: widget.topOffset,
        child: FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(animation),
            child: Center(
              child: TdsPressable(
                enabled: widget.onClick != null,
                onPressed: widget.onClick,
                button: widget.onClick != null,
                builder: (context, pressed, hovered, focused) => Semantics(
                  liveRegion: true,
                  child: AnimatedScale(
                    scale: pressed ? .96 : 1,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? theme.color('grey200')
                            : const Color(0xffffffff),
                        borderRadius: BorderRadius.circular(
                          widget.text.contains('\n') ? 20 : 100,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.color(
                              theme.isDark ? 'grey50' : 'grey200',
                            ),
                            blurRadius: 30,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/point/icon-point-circle-mono.svg',
                            package: 'tds_mobile_flutter',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              theme.color('blue500'),
                              BlendMode.srcIn,
                            ),
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: TdsText(
                              widget.text,
                              typography: TdsTypography.t6,
                              fontWeight: TdsFontWeight.semibold,
                              color: theme.color('greyOpacity800'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
