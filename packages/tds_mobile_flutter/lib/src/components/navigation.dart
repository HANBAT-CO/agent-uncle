import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';
import '../foundation/layout_adapters.dart';
import '../foundation/portal.dart';
import '../foundation/theme.dart';
import 'icon_button.dart';
import 'text.dart';
import 'text_button.dart';

class TdsTopNavigation extends StatelessWidget {
  const TdsTopNavigation({
    this.leading = const TdsTopNavigationBackButton(),
    this.content,
    this.trailing,
    this.fixed = false,
    this.withSafeAreaTop = true,
    this.background,
    this.blur = false,
    this.theme,
    this.scrollController,
    this.scrollBackground,
    this.scrollOffset = 0,
    super.key,
  });
  final Widget? leading, content, trailing;

  /// As in the source, fixed=true omits the flow spacer. Both modes are fixed.
  final bool fixed, withSafeAreaTop, blur;
  final Color? background, scrollBackground;
  final TdsColorPreference? theme;
  final ScrollController? scrollController;
  final double scrollOffset;
  @override
  Widget build(BuildContext context) {
    Widget nav(BuildContext context) {
      final t = TdsTheme.of(context),
          ios = usePlatform(context).os == TdsOS.ios;
      final trailingPadding =
          trailing is TdsTopNavigationIconButton ||
              trailing is TdsTopNavigationTextButton
          ? 12.0
          : 24.0;
      final title = TdsFontScaleLimit(
        limit: 135,
        child: Builder(
          builder: (context) => DefaultTextStyle(
            style: TdsTheme.of(context)
                .textStyle(
                  typography: TdsTypography.t5,
                  fontWeight: TdsFontWeight.semibold,
                )
                .copyWith(height: 1.35),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: content ?? const SizedBox(),
          ),
        ),
      );
      final start = Padding(
        padding: EdgeInsets.only(
          left: leading == null
              ? 24
              : ios
              ? 2
              : 4,
        ),
        child: leading,
      );
      final end = Padding(
        padding: EdgeInsets.only(right: trailingPadding),
        child: trailing,
      );
      Widget line = ios
          ? Row(
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: start),
                ),
                Flexible(child: title),
                Expanded(
                  child: Align(alignment: Alignment.centerRight, child: end),
                ),
              ],
            )
          : Row(
              children: [
                start,
                if (leading != null && content is Text)
                  const SizedBox(width: 20),
                Expanded(child: title),
                end,
              ],
            );
      final bg =
          scrollController?.hasClients == true &&
              scrollController!.offset > scrollOffset
          ? scrollBackground ?? background ?? t.color('background')
          : background ?? t.color('background');
      line = Container(
        height: useTopNavigationHeight(
          context,
          withSafeAreaTop: withSafeAreaTop,
        ),
        padding: EdgeInsets.only(
          top: withSafeAreaTop ? MediaQuery.viewPaddingOf(context).top : 0,
        ),
        color: bg,
        child: Semantics(container: true, child: line),
      );
      if (blur) {
        line = ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: line,
          ),
        );
      }
      return line;
    }

    Widget contentBuilder = scrollController == null
        ? Builder(builder: nav)
        : AnimatedBuilder(
            animation: scrollController!,
            builder: (context, _) => nav(context),
          );
    if (theme != null) {
      contentBuilder = TdsColorSchemeArea(theme: theme!, child: contentBuilder);
    }
    return TdsFixedPanel(top: true, takeSpace: !fixed, child: contentBuilder);
  }
}

class TdsRootTopNavigation extends StatelessWidget {
  const TdsRootTopNavigation({
    this.content,
    this.trailing,
    this.fixed = false,
    this.withSafeAreaTop = true,
    this.background,
    super.key,
  });
  final Widget? content, trailing;
  final bool fixed, withSafeAreaTop;
  final Color? background;
  @override
  Widget build(BuildContext context) => TdsFixedPanel(
    top: true,
    takeSpace: !fixed,
    child: Container(
      height: useTopNavigationHeight(context, withSafeAreaTop: withSafeAreaTop),
      padding: EdgeInsets.only(
        top: withSafeAreaTop ? MediaQuery.viewPaddingOf(context).top : 0,
      ),
      color: background ?? TdsTheme.of(context).color('background'),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: content is Text ? 24 : 0,
                right: trailing != null ? 10 : 24,
              ),
              child: TdsFontScaleLimit(
                limit: 120,
                child: Builder(
                  builder: (context) => DefaultTextStyle(
                    style: TdsTheme.of(context).textStyle(
                      typography: TdsTypography.t4,
                      fontWeight: TdsFontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: content ?? const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: EdgeInsets.only(
                right:
                    trailing is TdsTopNavigationIconButton ||
                        trailing is TdsTopNavigationTextButton
                    ? 12
                    : 24,
              ),
              child: trailing!,
            ),
        ],
      ),
    ),
  );
}

class TdsTopNavigationBackButton extends StatelessWidget {
  const TdsTopNavigationBackButton({
    this.onPressed,
    this.disabled = false,
    this.semanticLabel = '뒤로',
    super.key,
  });
  final VoidCallback? onPressed;
  final bool disabled;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => TdsTopNavigationIconButton(
    name: usePlatform(context).os == TdsOS.android
        ? 'icon-system-arrow-back-android-outlined'
        : 'icon-system-arrow-back-ios-outlined',
    semanticLabel: semanticLabel,
    color: TdsTheme.of(context).color('grey900'),
    disabled: disabled,
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

class TdsTopNavigationIconButton extends StatelessWidget {
  const TdsTopNavigationIconButton({
    required this.name,
    required this.semanticLabel,
    this.onPressed,
    this.color,
    this.disabled = false,
    this.redDot,
    this.count,
    this.countLabel,
    super.key,
  });
  final String name, semanticLabel;
  final String? redDot, countLabel;
  final num? count;
  final VoidCallback? onPressed;
  final Color? color;
  final bool disabled;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      TdsIconButton(
        name: name,
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        disabled: disabled,
        color: color ?? TdsTheme.of(context).color('greyOpacity700'),
      ),
      if (redDot != null)
        Positioned(top: 9, right: 7, child: _Dot(label: redDot!)),
      if (count != null && count!.isFinite)
        Positioned(
          top: 7.5,
          right: 5,
          child: Semantics(
            label: countLabel,
            container: true,
            excludeSemantics: countLabel != null,
            child: Container(
              height: 16,
              constraints: const BoxConstraints(minWidth: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TdsTheme.of(context).color('red500'),
                borderRadius: BorderRadius.circular(99),
              ),
              child: TdsFontScaleLimit(
                limit: 100,
                child: TdsText(
                  count! >= 10 ? '9+' : '$count',
                  typography: TdsTypography.st13,
                  color: const Color(0xffffffff),
                  fontWeight: TdsFontWeight.semibold,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class TdsTopNavigationTextButton extends StatelessWidget {
  const TdsTopNavigationTextButton({
    required this.child,
    this.onPressed,
    this.disabled = false,
    this.redDot,
    this.size = TdsTextButtonSize.small,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled;
  final String? redDot;
  final TdsTextButtonSize size;
  @override
  Widget build(BuildContext context) => TdsFontScaleLimit(
    limit: 160,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TdsTextButton(
            size: size,
            onPressed: onPressed,
            disabled: disabled,
            color: TdsTheme.of(context).color('grey700'),
            fontWeight: TdsFontWeight.semibold,
            child: child,
          ),
          if (redDot != null)
            Positioned(top: -3, right: -7, child: _Dot(label: redDot!)),
        ],
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TdsTheme.of(context).color('red500'),
      ),
    ),
  );
}
