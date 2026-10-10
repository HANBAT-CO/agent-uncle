import 'dart:async';
import 'package:flutter/widgets.dart';
import 'theme.dart';

/// Values, not an owner's BuildContext: a retained toast can outlive its route.
/// Arbitrary application InheritedWidgets must be placed above the target
/// Overlay; Flutter cannot clone an unknown inherited widget into another tree.
class TdsOverlaySnapshot {
  TdsOverlaySnapshot.capture(BuildContext context)
    : themes = InheritedTheme.capture(from: context, to: null),
      theme = TdsTheme.of(context),
      direction = Directionality.of(context),
      media = MediaQuery.maybeOf(context) ?? const MediaQueryData() {
    // capture() freezes inherited themes. Subscribe so a mounted owner takes
    // a new snapshot when any of those themes changes.
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is InheritedTheme) {
        context.dependOnInheritedElement(element);
      }
      return true;
    });
  }

  final CapturedThemes themes;
  final TdsThemeData theme;
  final TextDirection direction;
  final MediaQueryData media;

  Widget wrap(BuildContext context, Widget child, {bool liveViewport = false}) {
    final currentMedia = liveViewport ? MediaQuery.maybeOf(context) : null;
    return themes.wrap(
      TdsTheme(
        data: theme,
        child: Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: currentMedia == null
                ? media
                : currentMedia.copyWith(textScaler: media.textScaler),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A single owner for insertion, invalidation and teardown of an OverlayEntry.
/// Never mutates an Overlay during its ancestor's build/dispose traversal.
class TdsOverlayHost {
  TdsOverlayHost({
    required this.overlay,
    required WidgetBuilder builder,
    required this.onHostLost,
  }) {
    _entry = OverlayEntry(maintainState: true, builder: builder)
      ..addListener(_mountChanged);
  }

  final OverlayState overlay;
  final VoidCallback onHostLost;
  late final OverlayEntry _entry;
  bool _inserted = false, _mountedOnce = false;
  bool _disposed = false, _scheduled = false;

  void update() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      if (!overlay.mounted) {
        _lost();
      } else if (!_inserted) {
        _inserted = true;
        overlay.insert(_entry);
      } else {
        _entry.markNeedsBuild();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _mountChanged() {
    if (_entry.mounted) {
      _mountedOnce = true;
    } else if (_mountedOnce && !_disposed) {
      // OverlayEntry's mounted notifier is still dispatching this callback.
      // Disposing it synchronously would dispose a notifying ChangeNotifier.
      scheduleMicrotask(() {
        if (!_disposed) _lost();
      });
    }
  }

  void _lost() {
    dispose();
    onHostLost();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _entry.removeListener(_mountChanged);
    if (_inserted) _entry.remove();
    _entry.dispose();
  }
}
