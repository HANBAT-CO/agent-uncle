import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'overlay_host.dart';

/// Native counterpart of the original portal target context. Flutter's Overlay
/// replaces an HTMLElement; providers must live inside a Navigator route.
class TdsPortalContext {
  const TdsPortalContext(this.overlay);
  final OverlayState overlay;
  static TdsPortalContext? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TdsPortalContextProvider>()
      ?.value;
}

class TdsPortalProvider extends StatelessWidget {
  const TdsPortalProvider({required this.child, super.key});
  final Widget child;
  static TdsPortalContext? maybeOf(BuildContext context) =>
      TdsPortalContext.maybeOf(context);
  @override
  Widget build(BuildContext context) => TdsPortalContextProvider(
    value: TdsPortalContext(Overlay.of(context)),
    child: child,
  );
}

/// The context Provider is distinct from the provider that creates a target.
/// A null value intentionally hides an enclosing portal target.
class TdsPortalContextProvider extends InheritedWidget {
  const TdsPortalContextProvider({
    required this.value,
    required super.child,
    super.key,
  });
  final TdsPortalContext? value;
  @override
  bool updateShouldNotify(TdsPortalContextProvider oldWidget) =>
      oldWidget.value?.overlay != value?.overlay;
}

/// React context Consumer's render callback; this does not create a portal.
class TdsPortalContextConsumer extends StatelessWidget {
  const TdsPortalContextConsumer({required this.builder, super.key});
  final Widget Function(BuildContext context, TdsPortalContext? value) builder;
  @override
  Widget build(BuildContext context) =>
      builder(context, TdsPortalContext.maybeOf(context));
}

class TdsPortalConsumer extends StatefulWidget {
  const TdsPortalConsumer({
    required this.child,
    this.visible = true,
    super.key,
  });
  final Widget child;
  final bool visible;
  @override
  State<TdsPortalConsumer> createState() => _TdsPortalConsumerState();
}

class _TdsPortalConsumerState extends State<TdsPortalConsumer> {
  TdsOverlayHost? _host;
  late TdsOverlaySnapshot _snapshot;

  @override
  void dispose() {
    _host?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = TdsPortalContext.maybeOf(context)?.overlay;
    _snapshot = TdsOverlaySnapshot.capture(context);
    if (!widget.visible || target == null || !target.mounted) {
      _host?.dispose();
      _host = null;
    } else {
      if (_host?.overlay != target) {
        _host?.dispose();
        _host = TdsOverlayHost(
          overlay: target,
          builder: (context) => _snapshot.wrap(context, widget.child),
          onHostLost: () => _host = null,
        );
      }
      _host!.update();
    }
    return const SizedBox.shrink();
  }
}

/// A layout-aware native replacement for fixed CSS positioning. The overlay
/// inherits the caller's theme and optionally reserves its measured flow height.
class TdsFixedPanel extends StatefulWidget {
  const TdsFixedPanel({
    required this.child,
    this.top = false,
    this.takeSpace = true,
    this.aboveKeyboard = false,
    super.key,
  });
  final Widget child;
  final bool top, takeSpace, aboveKeyboard;
  @override
  State<TdsFixedPanel> createState() => _TdsFixedPanelState();
}

class _TdsFixedPanelState extends State<TdsFixedPanel> {
  final _portal = OverlayPortalController();
  double _height = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (context) => Positioned(
      left: 0,
      right: 0,
      top: widget.top ? 0 : null,
      bottom: widget.top
          ? null
          : widget.aboveKeyboard
          ? MediaQuery.viewInsetsOf(context).bottom
          : 0,
      child: _Measure(
        onSize: (size) {
          if (mounted && _height != size.height) {
            setState(() => _height = size.height);
          }
        },
        child: widget.child,
      ),
    ),
    child: SizedBox(height: widget.takeSpace ? _height : 0),
  );
}

/// Explicit non-fixed `takeSpace` duplicates the source's measured flow spacer.
class TdsMeasuredFlowSpacer extends StatefulWidget {
  const TdsMeasuredFlowSpacer({required this.child, super.key});
  final Widget child;
  @override
  State<TdsMeasuredFlowSpacer> createState() => _TdsMeasuredFlowSpacerState();
}

class _TdsMeasuredFlowSpacerState extends State<TdsMeasuredFlowSpacer> {
  double _height = 0;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: _height),
      _Measure(
        onSize: (size) {
          if (mounted && _height != size.height) {
            setState(() => _height = size.height);
          }
        },
        child: widget.child,
      ),
    ],
  );
}

class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureRender(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureRender renderObject,
  ) => renderObject.onSize = onSize;
}

class _MeasureRender extends RenderProxyBox {
  _MeasureRender(this.onSize);
  ValueChanged<Size> onSize;
  Size? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous == size) return;
    _previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
