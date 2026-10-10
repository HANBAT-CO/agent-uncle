import 'package:flutter/widgets.dart';
import '../components/toast.dart';
import '../components/asset.dart';
import 'host.dart';
import 'overlay_host.dart';
import 'theme.dart';

@immutable
class TdsToastOptions {
  const TdsToastOptions({
    this.position = TdsToastPosition.bottom,
    this.duration,
    this.persistent = false,
    this.higherThanCTA,
    this.leftAddon,
    this.button,
    this.action,
    this.icon,
    this.iconType,
    this.lottie,
    this.gap,
    this.liveRegion = true,
  }) : assert(button == null || action == null),
       assert(icon == null || lottie == null),
       assert(iconType == null || lottie == null),
       assert(leftAddon == null || (icon == null && lottie == null));
  final TdsToastPosition position;
  final Duration? duration;
  final bool persistent, liveRegion;
  final bool? higherThanCTA;
  final Widget? leftAddon, button;
  final TdsToastAction? action;
  final String? icon, lottie;
  final TdsToastIconType? iconType;
  final double? gap;

  Widget? get resolvedAddon =>
      leftAddon ??
      (lottie != null && lottie!.isNotEmpty
          ? TdsToastLottie(src: lottie!)
          : icon != null && icon!.isNotEmpty
          ? TdsToastIcon(
              name: icon!,
              frameShape: TdsAssetFrameShape(
                width: 24,
                height: 24,
                radius: iconType == TdsToastIconType.circle ? 9999 : 0,
              ),
            )
          : null);
  Widget? get resolvedButton =>
      button ??
      (action == null
          ? null
          : TdsToastButton(
              onPressed: action!.onPressed,
              child: Text(action!.text),
            ));
}

/// Native useWebToast. Replacements wait for the old toast's exit animation;
/// rapid replacements coalesce to the latest request, never overlapping.
/// Its root-overlay host can survive the caller, as useToast does in React.
class TdsToastController extends ChangeNotifier {
  _ToastRequest? _current, _pending;
  bool _open = false;
  bool _disposed = false;
  Object? _owner;
  TdsOverlayHost? _host;
  TdsOverlaySnapshot? _snapshot;
  bool _disposeWhenIdle = false;
  TdsHostToast? _nativeToast;
  TdsOS _os = TdsOS.web;
  double _safeAreaBottom = 0;

  /// Only the fallback overlay is observable. Host ToastContext has no status API.
  bool get isOpen => _open;

  void _changed() {
    _host?.update();
    notifyListeners();
  }

  void openToast(
    String message, {
    TdsToastOptions options = const TdsToastOptions(),
  }) {
    if (_disposed) return;
    final native = _nativeToast;
    if (native != null && options.leftAddon == null && options.button == null) {
      closeToast();
      final top = options.position == TdsToastPosition.top;
      native.show(
        message,
        TdsHostToastOptions(
          top: top
              ? (options.gap == null || options.gap == 0
                    ? (_os == TdsOS.android ? 26 : 46)
                    : options.gap)
              : null,
          bottom: top
              ? null
              : options.gap ??
                    (options.higherThanCTA == null
                        ? null
                        : _safeAreaBottom + (options.higherThanCTA! ? 81 : 17)),
          duration: options.duration,
          persistent: options.persistent,
          icon: options.icon,
          iconType: options.iconType,
          lottie: options.lottie,
          button: options.action,
        ),
      );
      return;
    }
    final request = _ToastRequest(message, options);
    if (_current == null || !_current!.presented) {
      _current = request;
      _pending = null;
      _open = true;
    } else {
      _pending = request;
      _open = false;
    }
    _changed();
  }

  void closeToast() {
    if (_disposed) return;
    _pending = null;
    if (!_open) return;
    _open = false;
    if (_current?.presented == false) _current = null;
    _changed();
  }

  void _exited(_ToastRequest request) {
    if (_disposed || !identical(request, _current) || _open) return;
    _current = _pending;
    _pending = null;
    _open = _current != null;
    _changed();
    if (_current == null && _owner == null) {
      _removeHost();
      if (_disposeWhenIdle) dispose();
    }
  }

  void _clear() {
    _current = _pending = null;
    _open = false;
  }

  void _removeHost() {
    final host = _host;
    _host = null;
    _snapshot = null;
    host?.dispose();
  }

  void _attach(
    Object owner,
    OverlayState overlay,
    TdsOverlaySnapshot snapshot,
    TdsHostToast? nativeToast,
  ) {
    if (_disposed) {
      throw StateError('Cannot attach a disposed toast controller.');
    }
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError('A toast controller may only have one active provider.');
    }
    _owner = owner;
    _disposeWhenIdle = false;
    _nativeToast = nativeToast;
    _os = snapshot.theme.platform.os;
    _safeAreaBottom = snapshot.media.padding.bottom;
    if (_host?.overlay != overlay) {
      _removeHost();
      _host = TdsOverlayHost(
        overlay: overlay,
        builder: _buildToast,
        onHostLost: () {
          _host = null;
          _snapshot = null;
          _clear();
          // Overlay teardown runs during tree disposal, not a notification
          // phase. An external controller remains reusable by a later owner.
          if (_owner == null && _disposeWhenIdle) dispose();
        },
      );
    }
    _snapshot = snapshot;
    _host!.update();
  }

  void _detach(Object owner, {required bool exit, required bool owned}) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _disposeWhenIdle = owned;
    if (exit || _current == null || _host == null) {
      _clear();
      _removeHost();
      if (owned) dispose();
    } else {
      // Also checks a root Overlay removed before the first entry frame.
      _host!.update();
    }
  }

  Widget _buildToast(BuildContext context) {
    final request = _current;
    if (request == null || _snapshot == null) return const SizedBox.shrink();
    if (_open) request.presented = true;
    final options = request.options;
    return _snapshot!.wrap(
      context,
      TdsToast(
        key: ObjectKey(request),
        open: _open,
        text: request.message,
        position: options.position,
        // JavaScript uses duration || default, so zero means the default.
        duration: options.duration == null || options.duration == Duration.zero
            ? Duration(
                seconds: options.button == null && options.action == null
                    ? 3
                    : 5,
              )
            : options.duration,
        persistent: options.persistent,
        leftAddon: options.resolvedAddon,
        button: options.position == TdsToastPosition.top
            ? null
            : options.resolvedButton,
        higherThanCTA: options.higherThanCTA ?? false,
        gap: options.gap ?? 0,
        liveRegion: options.liveRegion,
        onClose: closeToast,
        onExited: () => _exited(request),
      ),
      liveViewport: true,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _owner = null;
    _nativeToast = null;
    _clear();
    _removeHost();
    super.dispose();
  }
}

class _ToastRequest {
  _ToastRequest(this.message, this.options);
  final String message;
  final TdsToastOptions options;
  bool presented = false;
}

/// Place inside a Navigator's route so an Overlay is available. This provider
/// does not create a second Navigator or steal keyboard focus.
class TdsToastProvider extends StatefulWidget {
  const TdsToastProvider({
    required this.child,
    this.controller,
    this.exitOnUnmount = false,
    super.key,
  }) : preferHost = true;

  /// Matches useWebToast's default; the unnamed constructor matches useToast.
  const TdsToastProvider.web({
    required this.child,
    this.controller,
    this.exitOnUnmount = true,
    super.key,
  }) : preferHost = false;
  final Widget child;
  final TdsToastController? controller;
  final bool exitOnUnmount;
  final bool preferHost;
  static TdsToastController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToastScope>()?.controller;
  static TdsToastController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ToastScope>();
    assert(scope != null, 'TdsToastProvider is required above this context.');
    return scope!.controller;
  }

  @override
  State<TdsToastProvider> createState() => _TdsToastProviderState();
}

/// Host context is separate from the web-overlay controller context.
class TdsToastContextProvider extends InheritedWidget {
  const TdsToastContextProvider({
    required this.value,
    required super.child,
    super.key,
  });
  final TdsHostToast? value;
  @override
  bool updateShouldNotify(TdsToastContextProvider oldWidget) =>
      value != oldWidget.value;
}

TdsHostToast? useToastContext(BuildContext context) {
  final explicit = context
      .dependOnInheritedWidgetOfExactType<TdsToastContextProvider>();
  return explicit != null
      ? explicit.value
      : TdsHostProvider.maybeOf(context)?.toast;
}

class _TdsToastProviderState extends State<TdsToastProvider> {
  late TdsToastController _controller;
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TdsToastController();
  }

  @override
  void didUpdateWidget(TdsToastProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller._detach(
        this,
        exit: true,
        owned: oldWidget.controller == null,
      );
      _controller = widget.controller ?? TdsToastController();
    }
  }

  @override
  void dispose() {
    _controller._detach(
      this,
      exit: widget.exitOnUnmount,
      owned: widget.controller == null,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller._attach(
      this,
      Overlay.of(context, rootOverlay: true),
      TdsOverlaySnapshot.capture(context),
      widget.preferHost ? useToastContext(context) : null,
    );
    return _ToastScope(controller: _controller, child: widget.child);
  }
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.controller, required super.child});
  final TdsToastController controller;
  @override
  bool updateShouldNotify(_ToastScope oldWidget) =>
      controller != oldWidget.controller;
}
