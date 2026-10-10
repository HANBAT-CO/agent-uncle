import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'host.dart';
import 'theme.dart';
import 'tokens.g.dart';

enum TdsBackground { greyOpacity100, white, grey100 }

enum TdsNavigationTextType { darkText, lightText }

/// CSS backgroundColor becomes a native decoration rather than a DOM style.
BoxDecoration useBackgroundStyle(
  BuildContext context, {
  required TdsBackground background,
}) {
  final theme = TdsTheme.of(context);
  return BoxDecoration(
    color: switch (background) {
      TdsBackground.greyOpacity100 => theme.color('greyOpacity100'),
      TdsBackground.white => theme.color('background'),
      TdsBackground.grey100 =>
        theme.colorScheme == TdsColorPreference.light
            ? TdsPalette.grey100
            : theme.color('grey50'),
    },
  );
}

double useTopNavigationHeight(
  BuildContext context, {
  bool withSafeAreaTop = false,
  double? height,
}) =>
    (height ?? (usePlatform(context).os == TdsOS.android ? 54 : 44)) +
    (withSafeAreaTop ? MediaQuery.viewPaddingOf(context).top : 0);

double getTopOffsetInMobile({
  required TdsOS os,
  required bool hasWebNav,
  double pureSafeAreaTop = 0,
}) => os != TdsOS.android && hasWebNav ? pureSafeAreaTop : 0;

/// Source intentionally uses weighted 8-bit RGB, not WCAG gamma-corrected
/// luminance. Alpha does not participate in its threshold calculation.
TdsNavigationTextType getNavTypeByBackgroundColor(Color backgroundColor) =>
    (.2126 * backgroundColor.r +
                .7152 * backgroundColor.g +
                .0722 * backgroundColor.b) *
            255 >
        127.5
    ? TdsNavigationTextType.darkText
    : TdsNavigationTextType.lightText;

/// Exact 110-degree CSS alpha-gradient geometry at any aspect ratio. The
/// browser's maskImage/WebkitMaskImage become ShaderMask + dstIn.
class TdsGradientMask extends StatelessWidget {
  const TdsGradientMask({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) {
      const angle = 110 * math.pi / 180;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      final length =
          bounds.width * direction.dx.abs() +
          bounds.height * direction.dy.abs();
      return ui.Gradient.linear(
        bounds.center - direction * length / 2,
        bounds.center + direction * length / 2,
        const [Color(0xffffffff), Color(0x00ffffff)],
      );
    },
    child: child,
  );
}

@immutable
class TdsFixedBottomMetrics {
  const TdsFixedBottomMetrics({
    required this.isKeyboardOpen,
    required this.bottom,
  });
  final bool isKeyboardOpen;
  final double bottom;
  factory TdsFixedBottomMetrics.of(
    BuildContext context, {
    bool enabled = true,
  }) {
    final inset = enabled ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    // Native adaptation: actual keyboard insets instead of guessing from a
    // 30% browser viewport shrink. Position this in an unresized root overlay;
    // applying it to an already-resized scaffold would count the inset twice.
    return TdsFixedBottomMetrics(isKeyboardOpen: inset > 0, bottom: inset);
  }
}

/// Lifecycle counterpart of useSecureScreen(enabled). This delegates only;
/// without an injected TdsSecureScreen there is NO screenshot protection.
class TdsSecureScreenScope extends StatefulWidget {
  const TdsSecureScreenScope({
    required this.child,
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final bool enabled;
  @override
  State<TdsSecureScreenScope> createState() => _TdsSecureScreenScopeState();
}

class _TdsSecureScreenScopeState extends State<TdsSecureScreenScope> {
  TdsSecureScreen? _active;
  Future<void> _operations = Future.value();
  void _enqueue(Future<void> Function() operation) {
    _operations = _operations.then((_) => operation()).catchError((
      Object error,
      StackTrace stack,
    ) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'tds_mobile_flutter',
          context: ErrorDescription(
            'while updating the secure-screen host adapter',
          ),
        ),
      );
    });
  }

  void _sync() {
    final adapter = widget.enabled ? tdsSecureScreenOf(context) : null;
    if (identical(adapter, _active)) return;
    final old = _active;
    _active = adapter;
    if (old != null) _enqueue(old.disable);
    if (adapter != null) _enqueue(adapter.enable);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TdsSecureScreenScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    final old = _active;
    if (old != null) _enqueue(old.disable);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Host-backed useAccessoryButton lifecycle. The original no-host web
/// navigation overlay is not reproduced by this adapter.
class TdsAccessoryButtonScope extends StatefulWidget {
  const TdsAccessoryButtonScope({
    required this.button,
    required this.child,
    super.key,
  });
  final TdsAccessoryButton button;
  final Widget child;
  @override
  State<TdsAccessoryButtonScope> createState() =>
      _TdsAccessoryButtonScopeState();
}

class _TdsAccessoryButtonScopeState extends State<TdsAccessoryButtonScope> {
  TdsNavigation? _navigation;
  TdsAccessoryButton? _button;
  void _sync() {
    final navigation = tdsAppNavigationOf(context);
    if (identical(navigation, _navigation) &&
        identical(_button, widget.button)) {
      return;
    }
    _navigation?.removeAccessoryButton();
    _navigation = navigation;
    _button = widget.button;
    navigation?.addAccessoryButton(widget.button);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TdsAccessoryButtonScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _navigation?.removeAccessoryButton();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
