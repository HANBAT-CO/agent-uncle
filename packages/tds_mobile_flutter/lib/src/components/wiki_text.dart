import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../foundation/host.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/wiki_inline.dart';
import '../foundation/wiki_motion.dart';
import '../foundation/wiki_viewport.dart';
import '../foundation/wiki_description.dart';
import '../foundation/css_shadow.dart';

class TdsWikiText extends StatefulWidget {
  const TdsWikiText(
    this.text, {
    required this.description,
    this.hasPaddingAnimation = true,
    this.onClick,
    super.key,
  }) : assert(description is String || description is Widget);
  final String text;

  /// Strings use the original staggered line entrance. Custom widget content
  /// bypasses that text animation, matching the React-node overload.
  final Object description;
  final bool hasPaddingAnimation;
  final VoidCallback? onClick;
  @override
  State<TdsWikiText> createState() => _TdsWikiTextState();
}

class _TdsWikiTextState extends State<TdsWikiText> {
  final _word = GlobalKey();
  final _focus = FocusNode();
  RawDialogRoute<void>? _route;
  StreamSubscription<void>? _back;
  bool _inView = false;

  Rect? _wordBounds() {
    final box = _word.currentContext?.findRenderObject();
    if (box is! RenderTdsWikiHighlight || !box.hasSize) return null;
    final rects = box.wordRects;
    if (rects.isEmpty) return null;
    return rects
        .reduce((a, b) => a.expandToInclude(b))
        .shift(box.localToGlobal(Offset.zero));
  }

  void _close() {
    final route = _route;
    if (route?.isCurrent == true) route!.navigator?.pop();
  }

  void _open() {
    if (!_inView || _route != null) return;
    final box = _word.currentContext?.findRenderObject();
    if (box is! RenderTdsWikiHighlight || !box.hasSize) return;
    final rects = box.wordRects
        .map((rect) => rect.shift(box.localToGlobal(Offset.zero)))
        .toList();
    if (rects.isEmpty) return;
    final theme = TdsTheme.of(context);
    final style = DefaultTextStyle.of(context).style;
    widget.onClick?.call();
    final route = _WikiDialogRoute(
      barrierColor: null,
      barrierDismissible: true,
      barrierLabel: '추가 정보 상자 닫기',
      requestFocus: true,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      transitionDuration: TdsWikiPopupFrame.duration,
      transitionBuilder: (_, animation, secondary, child) => child,
      pageBuilder: (context, animation, _) => TdsTheme(
        data: theme,
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
          child: _WikiDefinition(
            rects: rects,
            word: widget.text,
            style: style,
            description: widget.description,
            onClose: _close,
            animation: animation,
          ),
        ),
      ),
    );
    _route = route;
    _back = TdsGlobalConfigProvider.maybeOf(
      context,
    )?.backEvent?.listen((_) => _close());
    Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
      if (_route != route) return;
      _route = null;
      _back?.cancel();
      _back = null;
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _back?.cancel();
    final route = _route;
    _route = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context),
        style = DefaultTextStyle.of(context).style;
    final size = style.fontSize ?? 16;
    final lineHeight = size * (style.height ?? 1.5);
    final padding = widget.hasPaddingAnimation ? lineHeight * .23 * .6 : 0.0;
    return TdsWikiViewport(
      measureTarget: _wordBounds,
      builder: (context, inView) {
        _inView = inView;
        return Focus(
          focusNode: _focus,
          onKeyEvent: (_, event) {
            if (event.logicalKey != LogicalKeyboardKey.enter &&
                event.logicalKey != LogicalKeyboardKey.space) {
              return KeyEventResult.ignored;
            }
            if (event is KeyDownEvent || event is KeyRepeatEvent) _open();
            return KeyEventResult.handled;
          },
          child: Semantics(
            button: true,
            label: '${widget.text} 추가 정보',
            onTap: _open,
            excludeSemantics: true,
            child: MouseRegion(
              cursor: inView
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.text,
              child: Listener(
                onPointerDown: (event) {
                  if (inView && event.kind == PointerDeviceKind.touch) {
                    tdsHapticOf(context).generate(TdsHapticType.tickWeak);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _open,
                  child: TdsWikiInlineMotion(
                    inView: inView,
                    padding: padding,
                    iconWidth: size * .7,
                    builder: (context, frame) => TdsWikiInline(
                      highlightKey: _word,
                      text: widget.text,
                      style: style,
                      dark: theme.isDark,
                      padding: frame.padding,
                      iconWidth: size * .7,
                      iconSlotWidth: frame.iconWidth,
                      iconOpacity: frame.iconOpacity,
                      iconTranslation: frame.iconX,
                      highlightOpacity: frame.highlightOpacity,
                      highlightScale: frame.highlightScale,
                      icon: SvgPicture.string(
                        _magnifier,
                        width: size * .7,
                        height: size * .7,
                        colorFilter: ColorFilter.mode(
                          theme.isDark
                              ? const Color(0xff4593fc)
                              : const Color(0xff3182f6),
                          BlendMode.srcIn,
                        ),
                        excludeFromSemantics: true,
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
}

class _WikiDialogRoute extends RawDialogRoute<void> {
  _WikiDialogRoute({
    required super.pageBuilder,
    required super.transitionBuilder,
    required super.transitionDuration,
    required super.barrierColor,
    required super.barrierDismissible,
    required super.barrierLabel,
    required super.requestFocus,
    required super.traversalEdgeBehavior,
  });
  @override
  bool didPop(Object? result) {
    final popped = super.didPop(null);
    if (popped) {
      // A pop during entry still needs the complete source exit timeline;
      // TransitionRoute's default reverse shortens it by the entry progress.
      controller?.animateBack(0, duration: TdsWikiPopupFrame.duration);
    }
    return popped;
  }
}

class _WikiDefinition extends StatelessWidget {
  const _WikiDefinition({
    required this.rects,
    required this.word,
    required this.style,
    required this.description,
    required this.onClose,
    required this.animation,
  });
  final List<Rect> rects;
  final String word;
  final TextStyle style;
  final Object description;
  final VoidCallback onClose;
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), screen = MediaQuery.sizeOf(context);
    final rect = rects.reduce((a, b) => a.expandToInclude(b));
    final first = rects.first, last = rects.last;
    final above =
        screen.height - rect.bottom <=
        last.height * 3 + 6 + screen.height * .05 + 32;
    final wide = screen.width > 480;
    final top = above ? null : rect.bottom + 6;
    final bottom = above ? screen.height - rect.top + 6 : null;
    final maxHeight = math.max(
      0.0,
      screen.height -
          (top ?? bottom!) -
          screen.height * .05 -
          32 -
          (above ? 46 : 0),
    );
    final initialLeft = math.max(0.0, rect.left);
    final left = wide
        ? initialLeft + 364 > screen.width
              ? screen.width - 364
              : initialLeft - 20
        : 22.0;
    final center = last.center.dx;
    final originX = wide || center < screen.width / 3
        ? -.5
        : center > screen.width * 2 / 3
        ? .5
        : 0.0;
    return TdsWikiPopupMotion(
      animation: animation,
      builder: (context, frame) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: onClose,
              child: ColoredBox(
                key: const ValueKey('tds-wiki-dimmer'),
                color: theme.color('grey100').withValues(alpha: frame.dimmer),
              ),
            ),
          ),
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width.ceilToDouble(),
            height: rect.height,
            child: Opacity(
              key: const ValueKey('tds-wiki-word-opacity'),
              opacity: frame.word,
              child: ExcludeSemantics(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: DefaultTextStyle(
                      style: style.copyWith(color: theme.color('grey800')),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (first.left > rect.left)
                              WidgetSpan(
                                child: SizedBox(width: first.left - rect.left),
                              ),
                            TextSpan(text: word),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: left.toDouble(),
            top: top,
            bottom: bottom,
            width: wide ? 364 : screen.width - 44,
            child: Opacity(
              key: const ValueKey('tds-wiki-box-opacity'),
              opacity: frame.box,
              child: Transform.scale(
                alignment: Alignment(originX, 0),
                scale: frame.scale,
                child: Semantics(
                  namesRoute: true,
                  label: '$word 추가 정보',
                  explicitChildNodes: true,
                  child: _WikiDescriptionBox(
                    maxHeight: maxHeight,
                    description: description,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Semantics(
              button: true,
              label: '추가 정보 상자 닫기',
              onTap: onClose,
              child: const SizedBox(width: 1, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _WikiDescriptionBox extends StatefulWidget {
  const _WikiDescriptionBox({
    required this.maxHeight,
    required this.description,
  });
  final double maxHeight;
  final Object description;
  @override
  State<_WikiDescriptionBox> createState() => _WikiDescriptionBoxState();
}

class _WikiDescriptionBoxState extends State<_WikiDescriptionBox> {
  final _scroll = ScrollController();
  bool _top = false, _bottom = false;
  bool _textReady = false;
  void _update() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final overflow = position.maxScrollExtent > 0;
    final top = overflow && position.pixels >= 5;
    final bottom = overflow && position.pixels + 5 < position.maxScrollExtent;
    if (top != _top || bottom != _bottom) {
      setState(() {
        _top = top;
        _bottom = bottom;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context), background = theme.color('background');
    Widget fade(bool top) => Positioned(
      top: top ? 15 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: top ? 40 : 80,
      child: IgnorePointer(
        child: DecoratedBox(
          key: ValueKey(top ? 'tds-wiki-fade-top' : 'tds-wiki-fade-bottom'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [background, background.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          TdsCssBoxShadow(
            color: TdsPalette.greyOpacity200,
            offset: Offset(0, 2),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: Focus(
                  autofocus: true,
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _update(),
                      );
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: widget.description is String && !_textReady
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: DefaultTextStyle(
                        style: theme.textStyle(typography: TdsTypography.t6),
                        child: widget.description is String
                            ? TdsWikiDescription(
                                widget.description as String,
                                onEnd: () {
                                  if (mounted) {
                                    setState(() => _textReady = true);
                                  }
                                },
                              )
                            : widget.description as Widget,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_top) fade(true),
            if (_bottom) fade(false),
          ],
        ),
      ),
    );
  }
}

const _magnifier =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 15 15" fill="none"><path d="M10.1228 9.1149C11.4219 7.23951 11.2363 4.6468 9.56598 2.97644C7.68685 1.09731 4.64018 1.09731 2.76105 2.97644C0.881915 4.85557 0.881914 7.90224 2.76104 9.78137C4.46016 11.4805 7.11366 11.6432 8.99573 10.2697L11.3713 12.6453C11.6864 12.9604 12.1972 12.9604 12.5123 12.6453C12.8273 12.3303 12.8273 11.8194 12.5123 11.5044L10.1228 9.1149ZM8.42503 8.64042C7.17603 9.88943 5.15099 9.88943 3.90199 8.64042C2.65299 7.39142 2.65299 5.36639 3.90199 4.11739C5.151 2.86838 7.17603 2.86838 8.42503 4.11738C9.67403 5.36639 9.67403 7.39142 8.42503 8.64042Z" fill="currentColor" stroke="currentColor" stroke-width=".2"/></svg>';
