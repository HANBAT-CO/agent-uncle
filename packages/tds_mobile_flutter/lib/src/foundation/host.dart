import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'theme.dart';

enum TdsHapticType {
  tickWeak,
  tickMedium,
  softWeak,
  softMedium,
  basicWeak,
  basicMedium,
  tap,
  success,
  wiggle,
  error,
  confetti,
}

/// The Toss host has more haptic patterns than Flutter's platform API. Inject
/// an implementation when the exact host patterns are available.
abstract interface class TdsHaptic {
  Future<void> generate(TdsHapticType type);
}

class TdsNoopHaptic implements TdsHaptic {
  const TdsNoopHaptic();
  @override
  Future<void> generate(TdsHapticType type) async {}
}

/// Opt-in native approximation, never silently substituted for the Toss host.
class TdsPlatformHaptic implements TdsHaptic {
  const TdsPlatformHaptic();
  @override
  Future<void> generate(TdsHapticType type) => switch (type) {
    TdsHapticType.tickWeak ||
    TdsHapticType.tickMedium => HapticFeedback.selectionClick(),
    TdsHapticType.softWeak ||
    TdsHapticType.basicWeak ||
    TdsHapticType.tap => HapticFeedback.lightImpact(),
    TdsHapticType.softMedium ||
    TdsHapticType.basicMedium ||
    TdsHapticType.success => HapticFeedback.mediumImpact(),
    TdsHapticType.wiggle ||
    TdsHapticType.error ||
    TdsHapticType.confetti => HapticFeedback.heavyImpact(),
  };
}

sealed class TdsAccessoryButton {
  const TdsAccessoryButton();
}

class TdsAccessoryTextButton extends TdsAccessoryButton {
  const TdsAccessoryTextButton({required this.title, required this.callback});
  final String title;
  final VoidCallback callback;
}

class TdsAccessoryIconButton extends TdsAccessoryButton {
  const TdsAccessoryIconButton({
    required this.name,
    required this.alt,
    required this.callback,
    this.color,
  });
  final String name, alt;
  final Color? color;
  final VoidCallback callback;
}

class TdsAccessoryIconDoubleButton extends TdsAccessoryButton {
  const TdsAccessoryIconDoubleButton({
    required this.leftIconName,
    required this.leftIconAlt,
    required this.rightIconName,
    required this.rightIconAlt,
    required this.callback,
    this.color,
  });
  final String leftIconName, leftIconAlt, rightIconName, rightIconAlt;
  final Color? color;
  final void Function(bool isLeft) callback;
}

abstract interface class TdsNavigation {
  void addAccessoryButton(TdsAccessoryButton button);
  void removeAccessoryButton();
}

abstract interface class TdsSecureScreen {
  Future<void> enable();
  Future<void> disable();
}

abstract interface class TdsHostSkeleton {
  void remove();
}

enum TdsToastIconType { circle, square }

enum TdsToastActionColor { primary, danger, light, dark }

enum TdsToastActionStyle { fill, outline, weak, flat }

@immutable
class TdsToastAction {
  const TdsToastAction({
    required this.text,
    required this.onPressed,
    this.color,
    this.style,
  });
  final String text;
  final VoidCallback onPressed;
  final TdsToastActionColor? color;
  final TdsToastActionStyle? style;
}

@immutable
class TdsHostToastOptions {
  const TdsHostToastOptions({
    this.top,
    this.bottom,
    this.duration,
    this.persistent = false,
    this.icon,
    this.iconType,
    this.lottie,
    this.button,
  }) : assert(top == null || bottom == null);
  final double? top, bottom;
  final Duration? duration;
  final bool persistent;
  final String? icon, lottie;
  final TdsToastIconType? iconType;
  final TdsToastAction? button;
}

/// The source ToastContext exposes show only. No dismissal/lifecycle event is
/// invented: the host owns rendering, timeouts and the action callback.
abstract interface class TdsHostToast {
  void show(String message, TdsHostToastOptions options);
}

/// Native replacement for host-injected hooks. Missing capabilities remain
/// absent; screenshot protection requires a real platform implementation.
class TdsHostProvider extends InheritedWidget {
  const TdsHostProvider({
    required super.child,
    this.haptic = const TdsNoopHaptic(),
    this.navigation,
    this.secureScreen,
    this.skeleton,
    this.toast,
    super.key,
  });
  final TdsHaptic haptic;
  final TdsNavigation? navigation;
  final TdsSecureScreen? secureScreen;
  final TdsHostSkeleton? skeleton;
  final TdsHostToast? toast;
  static TdsHostProvider? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TdsHostProvider>();
  @override
  bool updateShouldNotify(TdsHostProvider oldWidget) =>
      haptic != oldWidget.haptic ||
      navigation != oldWidget.navigation ||
      secureScreen != oldWidget.secureScreen ||
      skeleton != oldWidget.skeleton ||
      toast != oldWidget.toast;
}

TdsHaptic tdsHapticOf(BuildContext context) =>
    TdsHostProvider.maybeOf(context)?.haptic ?? const TdsNoopHaptic();
TdsNavigation? tdsAppNavigationOf(BuildContext context) =>
    TdsHostProvider.maybeOf(context)?.navigation;
TdsSecureScreen? tdsSecureScreenOf(BuildContext context) =>
    TdsHostProvider.maybeOf(context)?.secureScreen;
TdsHostSkeleton? tdsSkeletonOf(BuildContext context) =>
    TdsHostProvider.maybeOf(context)?.skeleton;
bool tdsScreenReaderOf(BuildContext context) =>
    MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

@immutable
class TdsGlobalConfig {
  const TdsGlobalConfig({
    this.backEvent,
    this.onLoadingStart,
    this.onLoadingFinish,
  });
  final Stream<void>? backEvent;
  final VoidCallback? onLoadingStart, onLoadingFinish;
}

@immutable
class TdsGlobalConfigContext {
  const TdsGlobalConfigContext({
    this.backEvent,
    this.onLoadingStarted,
    this.onLoadingFinish,
  });
  final Stream<void>? backEvent;
  final ValueChanged<String>? onLoadingStarted, onLoadingFinish;
}

class TdsGlobalConfigProvider extends StatefulWidget {
  const TdsGlobalConfigProvider({
    required this.child,
    this.config = const TdsGlobalConfig(),
    this.backEvent,
    this.onLoadingStarted,
    this.onLoadingFinish,
    super.key,
  });
  final Widget child;
  final TdsGlobalConfig config;
  final Stream<void>? backEvent;

  /// Optional per-loader callbacks, also used to forward an existing context
  /// across a native route. Config callbacks aggregate the active ID set.
  final ValueChanged<String>? onLoadingStarted, onLoadingFinish;
  static TdsGlobalConfigContext? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlobalConfigScope>()?.value;
  @override
  State<TdsGlobalConfigProvider> createState() =>
      _TdsGlobalConfigProviderState();
}

class _TdsGlobalConfigProviderState extends State<TdsGlobalConfigProvider> {
  final _loading = <String>{};
  void _started(String id) {
    if (_loading.isEmpty) widget.config.onLoadingStart?.call();
    _loading.add(id);
    widget.onLoadingStarted?.call(id);
  }

  void _finished(String id) {
    _loading.remove(id);
    // P7 also emits for an unknown finish when the map is already empty.
    if (_loading.isEmpty) widget.config.onLoadingFinish?.call();
    widget.onLoadingFinish?.call(id);
  }

  @override
  Widget build(BuildContext context) => _GlobalConfigScope(
    value: TdsGlobalConfigContext(
      backEvent: widget.backEvent ?? widget.config.backEvent,
      onLoadingStarted: _started,
      onLoadingFinish: _finished,
    ),
    child: widget.child,
  );
}

class _GlobalConfigScope extends InheritedWidget {
  const _GlobalConfigScope({required this.value, required super.child});
  final TdsGlobalConfigContext value;
  @override
  bool updateShouldNotify(_GlobalConfigScope oldWidget) =>
      value.backEvent != oldWidget.value.backEvent ||
      value.onLoadingStarted != oldWidget.value.onLoadingStarted ||
      value.onLoadingFinish != oldWidget.value.onLoadingFinish;
}

TdsGlobalConfigContext useGlobalConfigContext(BuildContext context) =>
    TdsGlobalConfigProvider.maybeOf(context) ?? const TdsGlobalConfigContext();

@immutable
class TdsViewport {
  const TdsViewport({
    required this.width,
    required this.height,
    this.offsetX = 0,
    this.offsetY = 0,
  });
  final double width, height, offsetX, offsetY;
  factory TdsViewport.of(BuildContext context) {
    final media = MediaQuery.of(context);
    return TdsViewport(
      width: media.size.width - media.viewInsets.horizontal,
      height: media.size.height - media.viewInsets.vertical,
      offsetX: media.viewInsets.left,
      offsetY: media.viewInsets.top,
    );
  }
}

@immutable
class TdsUserAgent {
  const TdsUserAgent({
    required this.isAndroid,
    required this.isIOS,
    required this.fontScale,
    required this.fontA11y,
    required this.colorPreference,
  });
  final bool isAndroid, isIOS;
  final double fontScale;
  final String fontA11y;
  final TdsColorPreference colorPreference;
  factory TdsUserAgent.of(BuildContext context) {
    final theme = TdsTheme.of(context);
    return TdsUserAgent(
      isAndroid: theme.platform.os == TdsOS.android,
      isIOS: theme.platform.os == TdsOS.ios,
      fontScale: theme.platform.fontScale,
      fontA11y: theme.platform.fontA11y,
      colorPreference: theme.colorScheme,
    );
  }
}

/// ScrollController counterpart of useScrollingDirection. Leading/trailing
/// throttle is 50ms, and the original threshold comparison is strictly >.
enum TdsScrollingDirection { up, down }

class TdsScrollingDirectionController
    extends ValueNotifier<TdsScrollingDirection?> {
  TdsScrollingDirectionController(this.scrollController, {this.threshold = 1})
    : super(null) {
    scrollController.addListener(_schedule);
  }
  final ScrollController scrollController;
  final double threshold;
  Timer? _timer;
  double _previous = 0;
  void _sample() {
    if (!scrollController.hasClients) return;
    final offset = scrollController.offset;
    if ((offset - _previous).abs() > threshold) {
      value = offset > _previous
          ? TdsScrollingDirection.down
          : TdsScrollingDirection.up;
      _previous = offset;
    }
  }

  void _schedule() {
    if (_timer != null) return;
    _sample();
    _timer = Timer(const Duration(milliseconds: 50), () {
      _timer = null;
      _sample();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    scrollController.removeListener(_schedule);
    super.dispose();
  }
}
