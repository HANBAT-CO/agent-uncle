import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/sheet_motion.dart';
import '../foundation/theme.dart';

/// Controlled native portal. The source's DOM portal container becomes a
/// Navigator target (root by default). Closing never pops a different route.
class TdsModal extends StatefulWidget {
  const TdsModal({
    required this.open,
    required this.child,
    this.onClose,
    this.onEntered,
    this.onExited,
    this.closeOnDimmerClick = true,
    this.closeOnBackEvent = true,
    this.scaleOnEnter = false,
    this.useRootNavigator = true,
    this.semanticLabel,
    this.sheet = false,
    this.disableDimmer = false,
    this.onDimmerClick,
    super.key,
  });
  final bool open,
      closeOnDimmerClick,
      closeOnBackEvent,
      scaleOnEnter,
      useRootNavigator;
  final Widget child;
  final VoidCallback? onClose, onEntered, onExited;
  final String? semanticLabel;

  /// Native presentation adapter used by BottomSheet; default dialog is unchanged.
  final bool sheet, disableDimmer;
  final VoidCallback? onDimmerClick;
  @override
  State<TdsModal> createState() => _TdsModalState();
}

class _TdsModalState extends State<TdsModal> {
  _TdsModalRoute? _route;
  bool _scheduled = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(TdsModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final presentation = _ModalPresentation(
        widget,
        TdsTheme.of(context),
        TdsHostProvider.maybeOf(context),
        TdsGlobalConfigProvider.maybeOf(context),
      );
      final existing = _route;
      if (existing != null) {
        existing.presentation.value = presentation;
        if (!widget.open) existing.close();
        return;
      }
      if (!widget.open) return;
      final route = _TdsModalRoute(presentation);
      _route = route;
      unawaited(
        Navigator.of(
          context,
          rootNavigator: widget.useRootNavigator,
        ).push(route),
      );
      route.completed.then((_) {
        if (_route == route) _route = null;
        if (!mounted) return;
        widget.onExited?.call();
        if (widget.open) _schedule();
      });
    });
  }

  @override
  void dispose() {
    _route?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ModalPresentation {
  const _ModalPresentation(this.model, this.theme, this.host, this.config);
  final TdsModal model;
  final TdsThemeData theme;
  final TdsHostProvider? host;
  final TdsGlobalConfigContext? config;
}

class _TdsModalRoute extends PopupRoute<void> {
  _TdsModalRoute(_ModalPresentation value)
    : presentation = ValueNotifier(value),
      super(
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        requestFocus: true,
      );
  final ValueNotifier<_ModalPresentation> presentation;
  bool _closing = false;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => TdsMotion.quick.duration;
  @override
  Duration get reverseTransitionDuration => presentation.value.model.sheet
      ? TdsSheetMotion.exitDuration
      : TdsMotion.rapid.duration;
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      await controller?.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (isActive) navigator?.removeRoute(this);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ValueListenableBuilder<_ModalPresentation>(
      valueListenable: presentation,
      builder: (context, value, _) {
        final host = value.host, config = value.config;
        Widget content = _ModalPage(
          model: value.model,
          animation: animation,
          backEvents: config?.backEvent,
        );
        if (config != null) {
          content = TdsGlobalConfigProvider(
            backEvent: config.backEvent,
            onLoadingStarted: config.onLoadingStarted,
            onLoadingFinish: config.onLoadingFinish,
            child: content,
          );
        }
        if (host != null) {
          content = TdsHostProvider(
            haptic: host.haptic,
            navigation: host.navigation,
            secureScreen: host.secureScreen,
            skeleton: host.skeleton,
            toast: host.toast,
            child: content,
          );
        }
        return TdsMobileProvider(theme: value.theme, child: content);
      },
    );
  }

  @override
  void dispose() {
    presentation.dispose();
    super.dispose();
  }
}

class _ModalPage extends StatefulWidget {
  const _ModalPage({
    required this.model,
    required this.animation,
    this.backEvents,
  });
  final TdsModal model;
  final Animation<double> animation;
  final Stream<void>? backEvents;
  @override
  State<_ModalPage> createState() => _ModalPageState();
}

class _ModalPageState extends State<_ModalPage>
    with SingleTickerProviderStateMixin {
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  StreamSubscription<void>? _back;
  final _sheetDimmer = ValueNotifier<double?>(null);
  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.model.onEntered?.call();
  }

  void _requestBack() {
    if (widget.model.closeOnBackEvent && widget.model.open) {
      widget.model.onClose?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_status);
    _back = widget.backEvents?.listen((_) => _requestBack());
  }

  @override
  void didUpdateWidget(_ModalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backEvents != widget.backEvents) {
      _back?.cancel();
      _back = widget.backEvents?.listen((_) => _requestBack());
    }
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_status);
      widget.animation.addStatusListener(_status);
    }
  }

  @override
  void dispose() {
    _back?.cancel();
    widget.animation.removeStatusListener(_status);
    _wiggle.dispose();
    _sheetDimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), model = widget.model;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestBack();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _requestBack();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              widget.animation,
              _wiggle,
              _sheetDimmer,
            ]),
            builder: (context, _) {
              final closing =
                  widget.animation.status == AnimationStatus.reverse;
              final curve = closing ? TdsMotion.rapid : TdsMotion.quick;
              final t = model.sheet && closing
                  ? 1 -
                        TdsSheetMotion.exitProgress(
                          widget.animation.value,
                          TdsMotion.rapid,
                        )
                  : curve.transform(widget.animation.value);
              final dimmerT = model.sheet && closing
                  ? 1 -
                        TdsSheetMotion.exitProgress(
                          widget.animation.value,
                          TdsMotion.quick,
                        )
                  : t;
              final bottomGap = math.max(
                10.0,
                MediaQuery.viewPaddingOf(context).bottom,
              );
              const points = [0.0, 2.0, -2.0, 1.0, 0.0];
              final phase = _wiggle.value * 4, i = math.min(3, phase.floor());
              final dx = points[i] + (points[i + 1] - points[i]) * (phase - i);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!model.disableDimmer)
                    Semantics(
                      label: model.closeOnDimmerClick ? '닫기' : null,
                      button: model.closeOnDimmerClick,
                      excludeSemantics: !model.closeOnDimmerClick,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (model.closeOnDimmerClick) {
                            model.onDimmerClick?.call();
                            model.onClose?.call();
                          } else if (!model.sheet) {
                            _wiggle.forward(from: 0);
                          }
                        },
                        child: ColoredBox(
                          color: const Color(0xff000000).withValues(
                            alpha:
                                (dimmerT *
                                        (model.sheet &&
                                                _sheetDimmer.value != null
                                            ? _sheetDimmer.value!
                                            : TdsSheetMotion.normalDimmer(
                                                theme.isDark,
                                              )))
                                    .clamp(0, 1),
                          ),
                        ),
                      ),
                    ),
                  if (model.sheet)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: FractionalTranslation(
                          translation: Offset(0, closing ? 1 - t : 0),
                          child: Transform.translate(
                            // hre enters at y=150 and settles at -safeBottom.
                            // Exit uses the measured surface height, excluding
                            // the native bottom-padding equivalent of that shift.
                            offset: Offset(
                              0,
                              (closing ? -bottomGap : 150 + bottomGap) *
                                  (1 - t),
                            ),
                            child: Opacity(
                              opacity: t.clamp(0, 1),
                              child: Semantics(
                                namesRoute: true,
                                label: model.semanticLabel,
                                child: TdsSheetDimmerScope(
                                  opacity: _sheetDimmer,
                                  child: model.child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 80,
                        ),
                        child: Opacity(
                          opacity: t.clamp(0, 1),
                          child: Transform.translate(
                            offset: Offset(dx, 0),
                            child: Transform.scale(
                              scale: model.scaleOnEnter && !closing
                                  ? .8 + .2 * t
                                  : 1,
                              child: Semantics(
                                namesRoute: true,
                                label: model.semanticLabel,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: TdsModalContent(child: model.child),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class TdsModalContent extends StatelessWidget {
  const TdsModalContent({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: ColoredBox(
      color: TdsTheme.of(context).color('floatBackground'),
      child: child,
    ),
  );
}

/// A dimmer for custom native overlay compositions. TdsModal supplies its own
/// route-level barrier; do not layer this on top of that barrier by default.
class TdsModalOverlay extends StatelessWidget {
  const TdsModalOverlay({
    this.onPressed,
    this.color = const Color(0x80000000),
    this.semanticLabel,
    super.key,
  });
  final VoidCallback? onPressed;
  final Color color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: onPressed != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ColoredBox(color: color, child: const SizedBox.expand()),
    ),
  );
}
