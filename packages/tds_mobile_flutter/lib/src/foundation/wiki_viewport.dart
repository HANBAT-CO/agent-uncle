import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Native counterpart of Ppe. The reference runtime's IntersectionObserver
/// resolves its -40% bottom margin against height (390px at a 650px viewport).
/// A root scroll extent supplies the native equivalent of document.body height.
class TdsWikiViewport extends StatefulWidget {
  const TdsWikiViewport({required this.builder, this.measureTarget, super.key});
  final Widget Function(BuildContext context, bool inView) builder;
  final Rect? Function()? measureTarget;
  @override
  State<TdsWikiViewport> createState() => _TdsWikiViewportState();
}

class _TdsWikiViewportState extends State<TdsWikiViewport>
    with WidgetsBindingObserver {
  final _probe = GlobalKey();
  final _positions = <ScrollPosition>[];
  Size _viewport = Size.zero;
  double? _bodyHeight;
  bool _inView = false, _latched = false, _scheduled = false;
  bool? _intersection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewport = MediaQuery.sizeOf(context);
    // Register an inherited dependency as well as every nested scroll owner.
    Scrollable.maybeOf(context);
    for (final position in _positions) {
      position.removeListener(_schedule);
    }
    _positions.clear();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        _positions.add(position);
        position.addListener(_schedule);
      }
      return true;
    });
    _schedule();
  }

  @override
  void didChangeMetrics() => _schedule();

  void _schedule() {
    if (_scheduled || _latched || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && !_latched) _measure();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _measure() {
    final box = _probe.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final rect =
        widget.measureTarget?.call() ??
        MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
    if (!rect.isFinite) return;
    _bodyHeight ??=
        _positions.reversed
            .where(
              (p) =>
                  axisDirectionToAxis(p.axisDirection) == Axis.vertical &&
                  p.hasContentDimensions,
            )
            .map(
              (p) =>
                  p.maxScrollExtent - p.minScrollExtent + p.viewportDimension,
            )
            .firstOrNull ??
        _viewport.height;
    var visible = Rect.fromLTWH(
      0,
      0,
      _viewport.width,
      math.max(0, _viewport.height * .6),
    );
    RenderObject child = box;
    while (child.parent != null) {
      final parent = child.parent!;
      if (parent is RenderOffstage && parent.offstage) {
        visible = Rect.zero;
        break;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        visible = visible.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(null), clip),
        );
      }
      child = parent;
    }
    // An edge-adjacent rectangle is intersecting at the source's threshold:0.
    final intersects =
        visible.width > 0 &&
        visible.height > 0 &&
        rect.right >= visible.left &&
        rect.left <= visible.right &&
        rect.bottom >= visible.top &&
        rect.top <= visible.bottom;
    if (_intersection == intersects) return;
    final first = _intersection == null;
    _intersection = intersects;
    final guard = _viewport.height * .4;
    if (_bodyHeight! > 0 && rect.top > _bodyHeight! - guard) {
      _latched = true;
    }
    final next = _latched || intersects || (first && rect.top < guard);
    if (next != _inView) setState(() => _inView = next);
  }

  @override
  void dispose() {
    for (final position in _positions) {
      position.removeListener(_schedule);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _WikiViewportProbe(
    key: _probe,
    onGeometry: _schedule,
    child: widget.builder(context, _inView),
  );
}

class _WikiViewportProbe extends SingleChildRenderObjectWidget {
  const _WikiViewportProbe({
    required this.onGeometry,
    required super.child,
    super.key,
  });
  final VoidCallback onGeometry;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWikiViewportProbe(onGeometry);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWikiViewportProbe renderObject,
  ) => renderObject.onGeometry = onGeometry;
}

class _RenderWikiViewportProbe extends RenderProxyBox {
  _RenderWikiViewportProbe(this.onGeometry);
  VoidCallback onGeometry;
  Rect? _last;
  @override
  void performLayout() {
    super.performLayout();
    onGeometry();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    if (rect != _last) {
      _last = rect;
      onGeometry();
    }
    super.paint(context, offset);
  }
}
