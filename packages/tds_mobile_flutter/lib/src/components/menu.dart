import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/pressable.dart';
import '../foundation/activation_scope.dart';
import '../foundation/motion.dart';
import '../foundation/line_box.dart';
import '../foundation/css_shadow.dart';
import '../foundation/anchored_overlay.dart';
import 'asset.dart';
import 'checkbox.dart';
import 'text.dart';

abstract final class TdsMenu {
  static Widget dropdown({required List<Widget> children, Widget? header}) =>
      TdsMenuDropdown(header: header, children: children);
}

class TdsMenuTrigger extends StatefulWidget {
  const TdsMenuTrigger({
    required this.child,
    required this.dropdown,
    this.open,
    this.defaultOpen = false,
    this.openOnLongPress = false,
    this.placement = TdsOverlayPlacement.bottomStart,
    this.onOpen,
    this.onClose,
    this.closeLabel = '메뉴 닫기',
    super.key,
  });
  final Widget child, dropdown;
  final bool? open;
  final bool defaultOpen;

  /// 채팅 등의 문맥 메뉴를 길게 눌러 연다. 기본 탭 메뉴 동작은 유지한다.
  final bool openOnLongPress;
  final TdsOverlayPlacement placement;
  final VoidCallback? onOpen, onClose;
  final String closeLabel;
  @override
  State<TdsMenuTrigger> createState() => _TdsMenuTriggerState();
}

class _TdsMenuTriggerState extends State<TdsMenuTrigger> {
  late bool internal = widget.defaultOpen;
  final focus = FocusNode();
  FocusNode? activationFocus;
  late final activation = TdsActivationController((source) {
    activationFocus = source;
    change(!open);
  });
  final dismissFocus = FocusNode();
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  Timer? restoreFocus;
  bool get open => widget.open ?? internal;
  void change(bool value) {
    if (open == value) return;
    (value ? widget.onOpen : widget.onClose)?.call();
    if (widget.open == null) {
      setState(() => internal = value);
      syncFocus(value);
    }
  }

  void syncFocus(bool value) {
    restoreFocus?.cancel();
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && open && dismissFocus.context != null) {
          dismissFocus.requestFocus();
        }
      });
    } else {
      restoreFocus = Timer(TdsMotion.quick.duration, () {
        if (mounted && !open) {
          final target = activationFocus;
          if (target?.context != null && target!.canRequestFocus) {
            target.requestFocus();
          } else {
            (focus.traversalDescendants.firstOrNull ?? focus).requestFocus();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(TdsMenuTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.open ?? internal) != open) syncFocus(open);
  }

  @override
  void dispose() {
    focus.dispose();
    dismissFocus.dispose();
    scope.dispose();
    activation.dispose();
    restoreFocus?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TdsAnchoredOverlay(
    open: open,
    placement: widget.placement,
    offset: 0,
    margin: 0,
    autoFlip: true,
    flipAlignment: true,
    shiftIntoView: false,
    closeDelay: TdsMotion.quick.duration,
    dismissLabel: widget.closeLabel,
    dismissFocusNode: dismissFocus,
    focusScopeNode: scope,
    onDismiss: () => change(false),
    overlayBuilder: (context, placement) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => change(false),
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: '메뉴',
        liveRegion: true,
        onDismiss: () => change(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: open ? 1 : 0),
          duration: TdsMotion.quick.duration,
          curve: TdsMotion.quick,
          child: widget.dropdown,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            // Original Bse: centered placements also originate at the end.
            alignment: Alignment(
              placement.name.endsWith('Start') ? -1 : 1,
              placement.name.startsWith('top') ? 1 : -1,
            ),
            // Original F.div animates scale only; it never fades opacity.
            child: child,
          ),
        ),
      ),
    ),
    child: Semantics(
      expanded: open,
      child: ListenableBuilder(
        listenable: activation,
        builder: (context, child) => TdsPressable(
          focusNode: focus,
          activateOnEnterDown: true,
          activateOnLongPress: widget.openOnLongPress,
          skipTraversal: activation.hasMembers,
          button: !activation.hasMembers,
          onPressed: () {
            activationFocus = focus;
            change(!open);
          },
          builder: (_, _, _, _) => child!,
        ),
        child: widget.openOnLongPress
            ? widget.child
            : TdsActivationScope(controller: activation, child: widget.child),
      ),
    ),
  );
}

class TdsMenuDropdown extends StatefulWidget {
  const TdsMenuDropdown({
    required this.children,
    this.header,
    this.scrollOverlay,
    super.key,
  });
  final List<Widget> children;
  final Widget? header;
  final Widget Function(double progress)? scrollOverlay;
  @override
  State<TdsMenuDropdown> createState() => _TdsMenuDropdownState();
}

class _TdsMenuDropdownState extends State<TdsMenuDropdown> {
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    scroll.addListener(update);
    WidgetsBinding.instance.addPostFrameCallback((_) => update());
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TdsMenuDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => update());
  }

  @override
  void dispose() {
    scroll.removeListener(update);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), screen = MediaQuery.sizeOf(context);
    final progress = scroll.hasClients && scroll.position.maxScrollExtent > 0
        ? (scroll.offset / scroll.position.maxScrollExtent).clamp(0.0, 1.0)
        : 1.0;
    final hasScroll = scroll.hasClients && scroll.position.maxScrollExtent > 0;
    final hasCheckItem = widget.children.any(
      (child) => child is TdsMenuDropdownCheckItem,
    );
    return TdsFontScaleLimit(
      limit: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            TdsCssBoxShadow(
              color: theme.isDark
                  ? const Color(0x40000000)
                  : theme.color('greyOpacity200'),
              blurRadius: 60,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: IntrinsicWidth(
              child: Container(
                constraints: BoxConstraints(
                  // Source limits the inner scroller; the outer 1px border is
                  // additional, not subtracted from those dimensions.
                  minWidth: math.min(182, screen.width * .66 + 2),
                  maxWidth: screen.width * .66 + 2,
                  maxHeight: screen.height * .6 + 2,
                ),
                decoration: BoxDecoration(
                  color: theme
                      .color(theme.isDark ? 'grey100' : 'background')
                      .withValues(alpha: .8),
                  border: Border.all(
                    color: Color.fromRGBO(
                      255,
                      255,
                      255,
                      theme.isDark ? .01 : .7,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: FocusTraversalGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.header != null)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  hasCheckItem ? 16 : 20,
                                  8,
                                  20,
                                  12,
                                ),
                                child: widget.header,
                              ),
                            ...widget.children,
                          ],
                        ),
                      ),
                    ),
                    if (hasScroll && widget.scrollOverlay != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: widget.scrollOverlay!(progress),
                        ),
                      ),
                    if (widget.scrollOverlay == null) ...[
                      _MenuScrollFade(
                        top: true,
                        visible: hasScroll && progress > .05,
                      ),
                      _MenuScrollFade(
                        top: false,
                        visible: hasScroll && progress < .95,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuScrollFade extends StatefulWidget {
  const _MenuScrollFade({required this.top, required this.visible});
  final bool top, visible;
  @override
  State<_MenuScrollFade> createState() => _MenuScrollFadeState();
}

class _MenuScrollFadeState extends State<_MenuScrollFade> {
  double opacity = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => opacity = widget.visible ? 1 : 0);
    });
  }

  @override
  void didUpdateWidget(_MenuScrollFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    opacity = widget.visible ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.top;
    final theme = TdsTheme.of(context);
    final color = theme.isDark ? TdsPalette.darkThemeGrey100 : TdsPalette.white;
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 400),
          curve: const Cubic(.6, 0, 0, .6),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TdsMenuDropdownItem extends StatelessWidget {
  const TdsMenuDropdownItem({
    required this.child,
    this.left,
    this.right,
    this.onPressed,
    this.disabled = false,
    this.autofocus = false,
    super.key,
  });
  final Widget child;
  final Widget? left, right;
  final VoidCallback? onPressed;
  final bool disabled, autofocus;
  @override
  Widget build(BuildContext context) => TdsPressable(
    onPressed: onPressed,
    enabled: !disabled,
    autofocus: autofocus,
    builder: (context, pressed, hovered, focused) => AnimatedScale(
      scale: pressed ? .96 : 1,
      duration: pressed ? TdsMotion.rapid.duration : TdsMotion.quick.duration,
      curve: pressed ? TdsMotion.rapid : TdsMotion.quick,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          left == null ? 20 : 12,
          8,
          left == null && right != null ? 16 : 20,
          8,
        ),
        decoration: BoxDecoration(
          color: pressed ? TdsTheme.of(context).color('greyOpacity100') : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (left != null)
              Padding(padding: const EdgeInsets.only(right: 6), child: left),
            Expanded(
              child: DefaultTextStyle(
                style: TdsTheme.of(context).textStyle(
                  typography: TdsTypography.t5,
                  fontWeight: TdsFontWeight.medium,
                  color: TdsTheme.of(context).color('grey700'),
                ),
                child: child is Text && (child as Text).style == null
                    ? TdsLineBox(
                        lineHeight: TdsTheme.of(
                          context,
                        ).platform.lineHeight(TdsTypography.t5),
                        child: child,
                      )
                    : child,
              ),
            ),
            if (right != null)
              Padding(padding: const EdgeInsets.only(left: 16), child: right),
          ],
        ),
      ),
    ),
  );
}

class TdsMenuDropdownCheckItem extends StatelessWidget {
  const TdsMenuDropdownCheckItem({
    required this.child,
    this.checked = false,
    this.onCheckedChange,
    this.onPressed,
    super.key,
  });
  final Widget child;
  final bool checked;
  final ValueChanged<bool>? onCheckedChange;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    inMutuallyExclusiveGroup: true,
    child: TdsMenuDropdownItem(
      onPressed: () {
        onPressed?.call();
        onCheckedChange?.call(!checked);
      },
      left: TdsCheckbox.lineTransparent(
        checked: checked,
        inert: true,
        size: TdsTheme.of(context).platform.fontScale >= 160 ? 30 : 24,
      ),
      child: DefaultTextStyle(
        style: TdsTheme.of(context).textStyle(
          typography: TdsTypography.t5,
          color: TdsTheme.of(context).color(checked ? 'blue500' : 'grey700'),
          fontWeight: checked ? TdsFontWeight.bold : TdsFontWeight.medium,
        ),
        child: child,
      ),
    ),
  );
}

class TdsMenuDropdownIcon extends StatelessWidget {
  const TdsMenuDropdownIcon({required this.name, this.color, super.key});
  final String name;
  final Color? color;
  @override
  Widget build(BuildContext context) => TdsAssetIcon(
    name: name,
    size: TdsTheme.of(context).platform.fontScale >= 160 ? 30 : 20,
    color: color ?? TdsTheme.of(context).color('grey400'),
  );
}

class TdsMenuHeader extends StatelessWidget {
  const TdsMenuHeader(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: TdsText(
      text,
      typography: TdsTypography.t7,
      fontWeight: TdsFontWeight.bold,
      color: TdsTheme.of(context).color('grey500'),
    ),
  );
}
