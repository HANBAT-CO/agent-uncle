import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'pressable.dart';

enum TdsOverlayPlacement {
  top,
  bottom,
  topStart,
  topEnd,
  bottomStart,
  bottomEnd,
}

/// Native anchor geometry and overlay lifecycle. No DOM/global selector state.
class TdsAnchoredOverlay extends StatefulWidget {
  const TdsAnchoredOverlay({
    required this.open,
    required this.child,
    required this.overlayBuilder,
    this.placement = TdsOverlayPlacement.bottom,
    this.offset = 0,
    this.autoFlip = false,
    this.margin = 12,
    this.maxWidth,
    this.onDismiss,
    this.closeDelay = Duration.zero,
    this.dismissLabel,
    this.dismissFocusNode,
    this.focusScopeNode,
    this.flipAlignment = false,
    this.shiftIntoView = true,
    super.key,
  });
  final bool open, autoFlip;
  final Widget child;
  final Widget Function(BuildContext, TdsOverlayPlacement) overlayBuilder;
  final TdsOverlayPlacement placement;
  final double offset, margin;
  final double? maxWidth;
  final VoidCallback? onDismiss;
  final Duration closeDelay;
  final bool flipAlignment, shiftIntoView;
  final String? dismissLabel;
  final FocusNode? dismissFocusNode;
  final FocusScopeNode? focusScopeNode;
  @override
  State<TdsAnchoredOverlay> createState() => _TdsAnchoredOverlayState();
}

class _TdsAnchoredOverlayState extends State<TdsAnchoredOverlay>
    with WidgetsBindingObserver {
  final portal = OverlayPortalController();
  final anchor = GlobalKey();
  ScrollPosition? scroll;
  late TdsOverlayPlacement resolved = widget.placement;
  bool scheduled = false;
  Timer? closeTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != scroll) {
      scroll?.removeListener(refresh);
      scroll = position;
      scroll?.addListener(refresh);
    }
  }

  void refresh() {
    if (mounted && widget.open) setState(() {});
  }

  @override
  void didChangeMetrics() => schedule();
  void schedule() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted) return;
      if (widget.open) {
        closeTimer?.cancel();
        closeTimer = null;
        portal.show();
      } else if (widget.closeDelay == Duration.zero) {
        portal.hide();
      } else {
        closeTimer ??= Timer(widget.closeDelay, () {
          closeTimer = null;
          if (mounted && !widget.open) portal.hide();
        });
      }
      if (widget.open) setState(() {});
    });
  }

  @override
  void dispose() {
    closeTimer?.cancel();
    scroll?.removeListener(refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.open && closeTimer != null) {
      closeTimer?.cancel();
      closeTimer = null;
    }
    if (widget.open != portal.isShowing && closeTimer == null) schedule();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.open) widget.onDismiss?.call();
        },
      },
      child: OverlayPortal(
        controller: portal,
        child: _AnchorGeometryObserver(
          key: anchor,
          onChange: refresh,
          child: widget.child,
        ),
        overlayChildBuilder: (context) {
          final box = anchor.currentContext?.findRenderObject();
          final overlay = Overlay.of(context).context.findRenderObject();
          if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) {
            return const SizedBox();
          }
          final rect = MatrixUtils.transformRect(
            box.getTransformTo(overlay),
            Offset.zero & box.size,
          );
          return Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.open,
              child: ExcludeSemantics(
                excluding: !widget.open,
                child: FocusScope(
                  node: widget.focusScopeNode,
                  canRequestFocus: widget.open,
                  child: Stack(
                    children: [
                      if (widget.onDismiss != null)
                        Positioned.fill(
                          child: widget.dismissLabel != null
                              ? TdsPressable(
                                  focusNode: widget.dismissFocusNode,
                                  autofocus: true,
                                  semanticLabel: widget.dismissLabel,
                                  onPressed: widget.onDismiss,
                                  builder: (_, _, _, _) =>
                                      const SizedBox.expand(),
                                )
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onDismiss,
                                  child: const SizedBox.expand(),
                                ),
                        ),
                      CustomSingleChildLayout(
                        delegate: _AnchorLayout(
                          rect,
                          widget.placement,
                          widget.offset,
                          widget.autoFlip,
                          widget.margin,
                          widget.maxWidth,
                          widget.flipAlignment,
                          widget.shiftIntoView,
                          Directionality.of(context),
                          onPlacement: (placement) {
                            if (resolved == placement) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && resolved != placement) {
                                setState(() => resolved = placement);
                              }
                            });
                          },
                        ),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.escape,
                            ): () =>
                                widget.onDismiss?.call(),
                          },
                          child: widget.overlayBuilder(context, resolved),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Observe paint-time geometry, including ancestor translations that do not
/// relayout the anchor itself. Never drive an idle frame loop: only an actual
/// geometry change requests one post-frame overlay refresh.
class _AnchorGeometryObserver extends SingleChildRenderObjectWidget {
  const _AnchorGeometryObserver({
    required this.onChange,
    required super.child,
    super.key,
  });
  final VoidCallback onChange;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAnchorGeometryObserver(onChange);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnchorGeometryObserver renderObject,
  ) => renderObject.onChange = onChange;
}

class _RenderAnchorGeometryObserver extends RenderProxyBox {
  _RenderAnchorGeometryObserver(this.onChange);
  VoidCallback onChange;
  Rect? _last;
  bool _scheduled = false;
  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    if (_last != rect) {
      _last = rect;
      if (!_scheduled) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduled = false;
          if (attached) onChange();
        });
      }
    }
    super.paint(context, offset);
  }
}

class _AnchorLayout extends SingleChildLayoutDelegate {
  _AnchorLayout(
    this.anchor,
    this.placement,
    this.offset,
    this.autoFlip,
    this.margin,
    this.maxWidth,
    this.flipAlignment,
    this.shiftIntoView,
    this.direction, {
    required this.onPlacement,
  });
  final Rect anchor;
  final TdsOverlayPlacement placement;
  final double offset, margin;
  final double? maxWidth;
  final bool autoFlip, flipAlignment, shiftIntoView;
  final TextDirection direction;
  final ValueChanged<TdsOverlayPlacement> onPlacement;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(
          0,
          math.min(
            maxWidth ?? double.infinity,
            constraints.maxWidth - margin * 2,
          ),
        ),
        maxHeight: math.max(0, constraints.maxHeight - margin * 2),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    if (autoFlip && flipAlignment) {
      final top = placement.name.startsWith('top');
      final start = placement.name.endsWith('Start');
      final aligned = start || placement.name.endsWith('End');
      TdsOverlayPlacement candidate(bool above, bool leading) => above
          ? (aligned
                ? (leading
                      ? TdsOverlayPlacement.topStart
                      : TdsOverlayPlacement.topEnd)
                : TdsOverlayPlacement.top)
          : (aligned
                ? (leading
                      ? TdsOverlayPlacement.bottomStart
                      : TdsOverlayPlacement.bottomEnd)
                : TdsOverlayPlacement.bottom);
      final placements = [
        placement,
        if (aligned) candidate(top, !start),
        candidate(!top, start),
        if (aligned) candidate(!top, !start),
      ];
      final results =
          <
            ({
              TdsOverlayPlacement placement,
              Offset position,
              double main,
              double cross,
              double total,
            })
          >[];
      for (final p in placements) {
        final above = p.name.startsWith('top');
        final leading = p.name.endsWith('Start');
        final leftAligned = direction == TextDirection.ltr ? leading : !leading;
        final x = !aligned
            ? anchor.center.dx - childSize.width / 2
            : leftAligned
            ? anchor.left
            : anchor.right - childSize.width;
        final y = above
            ? anchor.top - childSize.height - offset
            : anchor.bottom + offset;
        final main = above
            ? margin - y
            : y + childSize.height - size.height + margin;
        final left = margin - x,
            right = x + childSize.width - size.width + margin;
        final primaryRight = anchor.width > childSize.width
            ? !leftAligned
            : leftAligned;
        final cross = primaryRight ? right : left;
        final total =
            math.max(0.0, main) + math.max(0.0, left) + math.max(0.0, right);
        final result = (
          placement: p,
          position: Offset(x, y),
          main: main,
          cross: cross,
          total: total,
        );
        results.add(result);
        if (total == 0) {
          onPlacement(p);
          return result.position;
        }
      }
      final mainFits = results.where((r) => r.main <= 0).toList()
        ..sort((a, b) => a.cross.compareTo(b.cross));
      results.sort((a, b) => a.total.compareTo(b.total));
      final best = mainFits.isNotEmpty ? mainFits.first : results.first;
      onPlacement(best.placement);
      if (!shiftIntoView) return best.position;
      return Offset(
        best.position.dx.clamp(
          margin,
          math.max(margin, size.width - childSize.width - margin),
        ),
        best.position.dy.clamp(
          margin,
          math.max(margin, size.height - childSize.height - margin),
        ),
      );
    }
    var top = placement.name.startsWith('top');
    if (autoFlip) {
      final above = anchor.top - offset - margin,
          below = size.height - anchor.bottom - offset - margin;
      if (top && childSize.height > above && below > above) {
        top = false;
      } else if (!top && childSize.height > below && above > below) {
        top = true;
      }
    }
    final start = placement.name.endsWith('Start'),
        end = placement.name.endsWith('End');
    onPlacement(
      top
          ? (start
                ? TdsOverlayPlacement.topStart
                : end
                ? TdsOverlayPlacement.topEnd
                : TdsOverlayPlacement.top)
          : start
          ? TdsOverlayPlacement.bottomStart
          : end
          ? TdsOverlayPlacement.bottomEnd
          : TdsOverlayPlacement.bottom,
    );
    final leftAligned = direction == TextDirection.ltr ? start : end;
    final rightAligned = direction == TextDirection.ltr ? end : start;
    final x = leftAligned
        ? anchor.left
        : rightAligned
        ? anchor.right - childSize.width
        : anchor.center.dx - childSize.width / 2;
    final y = top
        ? anchor.top - childSize.height - offset
        : anchor.bottom + offset;
    if (!shiftIntoView) return Offset(x, y);
    return Offset(
      x.clamp(margin, math.max(margin, size.width - childSize.width - margin)),
      y.clamp(
        margin,
        math.max(margin, size.height - childSize.height - margin),
      ),
    );
  }

  @override
  bool shouldRelayout(_AnchorLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      placement != oldDelegate.placement ||
      offset != oldDelegate.offset ||
      margin != oldDelegate.margin ||
      maxWidth != oldDelegate.maxWidth ||
      direction != oldDelegate.direction ||
      flipAlignment != oldDelegate.flipAlignment ||
      shiftIntoView != oldDelegate.shiftIntoView ||
      autoFlip != oldDelegate.autoFlip;
}
