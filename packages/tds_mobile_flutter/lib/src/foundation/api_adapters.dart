import 'package:flutter/widgets.dart';
import 'theme.dart';
import 'tokens.g.dart';
import 'host.dart';
import 'portal.dart';
import 'layout_adapters.dart';
import '../components/button.dart';
import '../components/text_button.dart';
import '../components/icon_button.dart';
import '../components/asset.dart';
import '../components/feedback.dart';

/// Legacy selector metadata for migration tooling; native widgets do not emit DOM.
const legacyTdsWebButtonClassName = 'button';
const borderBottomWidthVar = '--tds-paragraph-border-bottom-width';
const colorVar = '--tds-paragraph-color';
const fontWeightVar = '--tds-paragraph-font-weight';
const paragraphVariables = <String, Map<String, String>>{
  'common': {
    'fontWeight': '--tds-paragraph-common-font-weight',
    'color': '--tds-paragraph-common-color',
  },
  'text': {
    'fontSize': '--tds-paragraph-text-font-size',
    'lineHeight': '--tds-paragraph-text-line-height',
  },
  'icon': {'height': '--tds-paragraph-icon-height'},
  'badge': {
    'fontSize': '--tds-paragraph-badge-font-size',
    'borderRadius': '--tds-paragraph-badge-border-radius',
    'padding': '--tds-paragraph-badge-padding',
  },
  'link': {
    'verticalPadding': '--tds-paragraph-link-vertical-padding',
    'horizontalPadding': '--tds-paragraph-link-horizontal-padding',
    'borderRadius': '--tds-paragraph-link-border-radius',
    'lightThickness': '--tds-paragraph-link-light-thickness',
    'boldThickness': '--tds-paragraph-link-bold-thickness',
  },
};
Map<String, String> _assign(String type, TdsTypography typography) => {
  for (final entry in paragraphVariables[type]!.entries)
    entry.value: 'var(--tds-t-${typography.name}-$type-${entry.key})',
};
Map<String, String> assignTextVariables(TdsTypography typography) =>
    _assign('text', typography);
Map<String, String> assignIconVariables(TdsTypography typography) =>
    _assign('icon', typography);
Map<String, String> assignBadgeVariables(TdsTypography typography) =>
    _assign('badge', typography);
Map<String, String> assignLinkVariables(TdsTypography typography) =>
    _assign('link', typography);

/// Resolved values accompany CSS metadata so adapters can use them natively.
class TdsTypographyVariables {
  const TdsTypographyVariables(this.platform, {this.web = false});
  final TdsPlatform platform;
  final bool web;
  Map<String, String> get css => web ? webCSS : mobileCSS;
  TextStyle textStyle(TdsTypography typography) {
    final style = TdsThemeData(
      platform: platform,
    ).textStyle(typography: typography);
    return web
        ? style.copyWith(
            fontSize: platform.webSize(typography),
            height:
                platform.webLineHeight(typography) /
                platform.webSize(typography),
          )
        : style;
  }

  Map<String, String> get mobileCSS => {
    for (final typography in TdsTypography.values) ...{
      '--tds-t-${typography.name}-text-fontSize':
          '${platform.size(typography)}px',
      '--tds-t-${typography.name}-text-lineHeight':
          '${platform.lineHeight(typography)}px',
      '--tds-t-${typography.name}-badge-fontSize':
          '${tdsBadgeMetrics[platform.size(typography).toInt()]!.$1}px',
    },
  };
  Map<String, String> get webCSS {
    return {
      for (final type in TdsTypography.values) ...{
        '--toss-font-size-${type.baseSize.toInt()}':
            '${platform.webSize(type)}px',
        '--toss-line-height-${type.baseSize.toInt()}':
            '${platform.webLineHeight(type)}px',
      },
    };
  }
}

TdsTypographyVariables? useLimitedTdsMobileCSSVariables(
  BuildContext context, {
  double limit = 310,
  double minLimit = 100,
}) {
  final platform = usePlatform(context),
      limited = usePlatform(context).limited(limit: limit, minLimit: minLimit);
  return identical(platform, limited) ? null : TdsTypographyVariables(limited);
}

TdsTypographyVariables? useLimitedTdsWebCSSVariables(
  BuildContext context, {
  double limit = 310,
  double minLimit = 100,
}) {
  final platform = usePlatform(context),
      limited = platform.limited(limit: limit, minLimit: minLimit);
  return identical(platform, limited)
      ? null
      : TdsTypographyVariables(limited, web: true);
}

class TdsTouchInsets {
  const TdsTouchInsets(this.insets, this.radius);
  final EdgeInsets insets;
  final double radius;
}

final mapByTypeAndTypography =
    <String, Map<TdsTextButtonVariant, TdsTouchInsets>>{
      for (var level = 1; level <= 5; level++)
        'level$level': {
          for (final type in TdsTextButtonVariant.values)
            type: TdsTouchInsets(
              EdgeInsets.fromLTRB(
                [7, 9, 11, 13, 15][level - 1].toDouble(),
                [3, 4, 5, 7, 9][level - 1].toDouble(),
                (type == TdsTextButtonVariant.arrow
                        ? [2, 3, 3, 4, 6]
                        : [7, 9, 11, 13, 15])[level - 1]
                    .toDouble(),
                [3, 4, 5, 7, 9][level - 1].toDouble(),
              ),
              [7, 9, 11, 13, 15][level - 1].toDouble(),
            ),
        },
    };

class TdsThemeProvider extends StatelessWidget {
  const TdsThemeProvider({required this.child, this.primary, super.key});
  final Widget child;
  final Color? primary;
  @override
  Widget build(BuildContext context) => TdsTheme(
    data: TdsTheme.of(context).copyWith(primary: primary),
    child: child,
  );
}

/// React HOCs become typed builder decorators. Flutter's Key replaces a ref;
/// a component's props remain its own statically typed constructor/options.
typedef TdsComponentBuilder<P> =
    Widget Function(BuildContext context, P props, Key? key);

/// A strongly typed native alternative to React's polymorphic `as` component.
/// `P` is an explicit Dart options class/record, not inferred HTML attributes.
typedef TdsAs<P> = TdsComponentBuilder<P>;
typedef TdsElementRef = GlobalKey;

class TdsComponentWithAs<P> {
  const TdsComponentWithAs({required this.builder, this.displayName, this.id});
  final TdsComponentBuilder<P> builder;
  final String? displayName, id;
  Widget call(BuildContext context, P props, {TdsAs<P>? as, Key? key}) =>
      (as ?? builder)(context, props, key);
}

/// Migration helpers for JS structural props. Immutable runtime maps replace
/// TypeScript conditional/keyof types; these do NOT give Dart HTML attributes.
class TdsProps {
  TdsProps([Map<String, Object?> values = const {}])
    : values = Map.unmodifiable(values);
  final Map<String, Object?> values;
  Object? operator [](String key) => values[key];
  TdsProps omitCommon([Iterable<String> additional = const []]) {
    final excluded = {'transition', 'as', 'color', ...additional};
    return TdsProps({
      for (final entry in values.entries)
        if (!excluded.contains(entry.key)) entry.key: entry.value,
    });
  }

  TdsProps rightJoin(TdsProps overrides) => TdsProps({
    ...omitCommon(overrides.values.keys).values,
    ...overrides.values,
  });
  TdsProps mergeWithAs(TdsProps asProps, TdsProps additional, {Object? as}) =>
      TdsProps({
        ...rightJoin(additional).values,
        ...asProps.rightJoin(additional).values,
        'as': ?as,
      });
}

/// Explicit typed props association in place of TS ComponentProps inference.
class TdsPropsOf<P> {
  const TdsPropsOf(this.component, this.props);
  final TdsComponentWithAs<P> component;
  final P props;
  Widget build(BuildContext context, {Key? key}) =>
      component(context, props, key: key);
}

TdsComponentBuilder<P> forwardRefWithAs<P>(TdsComponentBuilder<P> builder) =>
    (context, props, key) => builder(context, props, key);
typedef TdsStyledWidget = Widget Function(Widget child);
TdsStyledWidget styledText({
  TdsTypography typography = TdsTypography.st10,
  TdsFontWeight fontWeight = TdsFontWeight.regular,
  Color? color,
}) =>
    (child) => Builder(
      builder: (context) => DefaultTextStyle(
        style: TdsTheme.of(context).textStyle(
          typography: typography,
          fontWeight: fontWeight,
          color: color,
        ),
        child: child,
      ),
    );
TdsStyledWidget styledButton({
  VoidCallback? onPressed,
  TdsButtonColor color = TdsButtonColor.primary,
  TdsButtonVariant variant = TdsButtonVariant.fill,
  TdsButtonSize size = TdsButtonSize.xlarge,
  TdsButtonDisplay display = TdsButtonDisplay.inline,
  bool disabled = false,
  bool loading = false,
}) =>
    (child) => TdsButton(
      onPressed: onPressed,
      color: color,
      variant: variant,
      size: size,
      display: display,
      disabled: disabled,
      loading: loading,
      child: child,
    );
WidgetBuilder withLoadingSkeleton(
  WidgetBuilder builder, {
  bool fadeIn = false,
}) =>
    (context) =>
        TdsLoadingCompleteView(fadeIn: fadeIn, child: builder(context));

/// Source AccessoryButton is a side-effect-only component. Keep the existing
/// typed host option object separate from this lifecycle widget.
class TdsAccessoryButtonView extends StatelessWidget {
  const TdsAccessoryButtonView({required this.button, super.key});
  final TdsAccessoryButton button;
  @override
  Widget build(BuildContext context) {
    final host = tdsAppNavigationOf(context);
    if (host != null) {
      return TdsAccessoryButtonScope(button: button, child: const SizedBox());
    }
    Widget icon(
      String name,
      String label,
      Color? color,
      VoidCallback onPressed,
    ) => TdsIconButton(
      onPressed: onPressed,
      semanticLabel: label,
      child: TdsAssetIcon(name: name, size: 24, color: color),
    );
    final content = switch (button) {
      TdsAccessoryTextButton(:final title, :final callback) => TdsTextButton(
        size: TdsTextButtonSize.medium,
        onPressed: callback,
        child: Text(title),
      ),
      TdsAccessoryIconButton(
        :final name,
        :final alt,
        :final color,
        :final callback,
      ) =>
        icon(name, alt, color, callback),
      TdsAccessoryIconDoubleButton(
        :final leftIconName,
        :final leftIconAlt,
        :final rightIconName,
        :final rightIconAlt,
        :final color,
        :final callback,
      ) =>
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon(leftIconName, leftIconAlt, color, () => callback(true)),
            icon(rightIconName, rightIconAlt, color, () => callback(false)),
          ],
        ),
    };
    return TdsFixedPanel(
      top: true,
      takeSpace: false,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }
}
