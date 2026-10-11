import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'tokens.g.dart';

enum TdsTypography {
  t1,
  st1,
  st2,
  st3,
  t2,
  st4,
  st5,
  st6,
  t3,
  st7,
  t4,
  st8,
  st9,
  t5,
  st10,
  t6,
  st11,
  t7,
  st12,
  st13;

  double get baseSize => 30.0 - index;
}

enum TdsFontWeight {
  regular(FontWeight.w400),
  medium(FontWeight.w500),
  semibold(FontWeight.w600),
  bold(FontWeight.w700);

  const TdsFontWeight(this.value);
  final FontWeight value;
}

enum TdsColorPreference { light, dark }

enum TdsOS { ios, android, web }

@immutable
class TdsPlatform {
  const TdsPlatform({
    this.os = TdsOS.web,
    this.fontScale = 100,
    this.fontA11y = 'Large',
  }) : _mobileTypography = null,
       _webTypography = null;
  const TdsPlatform._scoped(
    this.os,
    this.fontScale,
    this.fontA11y,
    this._mobileTypography,
    this._webTypography,
  );
  final TdsOS os;
  final double fontScale;
  final String fontA11y;
  final TdsPlatform? _mobileTypography, _webTypography;

  /// CSS limits change typography variables, never the host's accessibility
  /// category or usePlatform/useFontScaleCondition/useFontSizeCondition result.
  TdsPlatform get unlimited =>
      _mobileTypography == null && _webTypography == null
      ? this
      : TdsPlatform(os: os, fontScale: fontScale, fontA11y: fontA11y);
  TdsPlatform _withTypography({TdsPlatform? mobile, TdsPlatform? web}) =>
      TdsPlatform._scoped(
        os,
        fontScale,
        fontA11y,
        mobile ?? _mobileTypography,
        web ?? _webTypography,
      );

  List<double> get typographyRule =>
      _mobileTypography?.typographyRule ??
      switch (os) {
        TdsOS.ios => tdsIosFontSizes[fontA11y] ?? tdsIosFontSizes['Large']!,
        TdsOS.android => List.generate(
          20,
          (i) => math
              .min(
                (30 - i) * math.max(fontScale, 100) / 100,
                tdsIosFontSizes['A11y_xxxLarge']![i],
              )
              .roundToDouble(),
        ),
        TdsOS.web => tdsIosFontSizes['Large']!,
      };

  double size(TdsTypography typography) => typographyRule[typography.index];
  double lineHeight(TdsTypography typography) =>
      tdsTextMetrics[size(typography).toInt()]!.$2;

  double webSize(TdsTypography typography) {
    final platform = _webTypography ?? this;
    return platform.os == TdsOS.ios
        ? (tdsWebIosFontSizes[platform.fontA11y] ??
              tdsWebIosFontSizes['Large']!)[typography.index]
        : math.min(
            typography.baseSize * platform.fontScale / 100,
            tdsWebFontSizeCaps[typography.index],
          );
  }

  double webLineHeight(TdsTypography typography) {
    final size = webSize(typography);
    return tdsWebLineHeights[size.round()] ?? (size * 1.5).roundToDouble();
  }

  TdsPlatform limited({double limit = 310, double minLimit = 100}) {
    assert(minLimit <= limit);
    if (fontScale >= minLimit && fontScale <= limit) return this;
    final scale = fontScale.clamp(minLimit, limit);
    final category =
        tdsIosFontScales.entries
            .where((e) => e.value == scale)
            .firstOrNull
            ?.key ??
        'Large';
    return TdsPlatform(os: os, fontScale: scale, fontA11y: category);
  }
}

@immutable
class TdsA11yCondition {
  const TdsA11yCondition({
    this.biggerThan,
    this.biggerThanOrEqualTo,
    this.smallerThan,
    this.smallerThanOrEqualTo,
  });
  final double? biggerThan,
      biggerThanOrEqualTo,
      smallerThan,
      smallerThanOrEqualTo;
  bool matches(double value) =>
      value > (biggerThan ?? double.negativeInfinity) &&
      value >= (biggerThanOrEqualTo ?? double.negativeInfinity) &&
      value < (smallerThan ?? double.infinity) &&
      value <= (smallerThanOrEqualTo ?? double.infinity);
}

@immutable
class TdsThemeData {
  const TdsThemeData({
    this.colorScheme = TdsColorPreference.light,
    this.primary = TdsPalette.blue500,
    this.platform = const TdsPlatform(),
  });
  final TdsColorPreference colorScheme;
  final Color primary;
  final TdsPlatform platform;

  /// Optional exact brand fill. Null keeps the original TDS contrast adjustment.
  Color? get primaryButtonBackground => null;

  /// Optional brand colors for weak buttons. Null retains TDS's contrast rules.
  Color? get primaryButtonWeakBackground => null;
  Color? get primaryButtonWeakForeground => null;

  /// Resolves a fixed light token while allowing application palette overrides.
  Color fixedColor(String name) =>
      copyWith(colorScheme: TdsColorPreference.light).color(name);

  bool get isDark => colorScheme == TdsColorPreference.dark;

  Color color(String name) {
    if (name == 'primary') return primary;
    final adaptive = tdsAdaptiveColors[name];
    if (adaptive != null) {
      return colorScheme == TdsColorPreference.light
          ? adaptive.$1
          : adaptive.$2;
    }
    if (colorScheme == TdsColorPreference.dark) {
      final suffix = '${name[0].toUpperCase()}${name.substring(1)}';
      final dark =
          TdsPalette.values['darkTheme$suffix'] ??
          TdsPalette.values['dark$suffix'];
      if (dark != null) return dark;
    }
    return TdsPalette.values[name] ??
        (throw ArgumentError.value(name, 'name', 'Unknown TDS color'));
  }

  TdsThemeData copyWith({
    TdsColorPreference? colorScheme,
    Color? primary,
    TdsPlatform? platform,
  }) => TdsThemeData(
    colorScheme: colorScheme ?? this.colorScheme,
    primary: primary ?? this.primary,
    platform: platform ?? this.platform,
  );

  TextStyle textStyle({
    TdsTypography typography = TdsTypography.st10,
    TdsFontWeight fontWeight = TdsFontWeight.regular,
    Color? color,
  }) {
    final size = platform.size(typography);
    return TextStyle(
      fontFamily: 'Toss Product Sans',
      package: 'tds_mobile_flutter',
      fontSize: size,
      height: platform.lineHeight(typography) / size,
      fontWeight: fontWeight.value,
      color: color ?? this.color('grey900'),
      leadingDistribution: TextLeadingDistribution.even,
    );
  }
}

class TdsTheme extends InheritedWidget {
  const TdsTheme({required this.data, required super.child, super.key});
  final TdsThemeData data;
  static TdsThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TdsTheme>()?.data ??
      const TdsThemeData();
  @override
  bool updateShouldNotify(TdsTheme oldWidget) => data != oldWidget.data;
}

/// Native counterpart of TDSMobileProvider. System font scaling is resolved once
/// into TDS's non-linear typography tables; descendants must not scale it twice.
class TdsMobileProvider extends StatelessWidget {
  const TdsMobileProvider({required this.child, this.theme, super.key});
  final Widget child;
  final TdsThemeData? theme;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final scale = media.textScaler.scale(100);
    final os = kIsWeb
        ? TdsOS.web
        : defaultTargetPlatform == TargetPlatform.iOS
        ? TdsOS.ios
        : TdsOS.android;
    final category = tdsIosFontScales.entries
        .reduce(
          (a, b) => (a.value - scale).abs() <= (b.value - scale).abs() ? a : b,
        )
        .key;
    final data =
        theme ??
        TdsThemeData(
          colorScheme: media.platformBrightness == Brightness.dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: os,
            fontScale: os == TdsOS.ios ? tdsIosFontScales[category]! : scale,
            fontA11y: category,
          ),
        );
    return TdsTheme(
      data: data,
      child: MediaQuery(
        data: media.copyWith(textScaler: TextScaler.noScaling),
        child: ScrollNotificationObserver(
          child: DefaultTextStyle(style: data.textStyle(), child: child),
        ),
      ),
    );
  }
}

/// The original AIT provider forces light appearance and disables font scaling
/// unless explicitly enabled. The Flutter adapter follows those defaults.
class TdsMobileAITProvider extends StatelessWidget {
  const TdsMobileAITProvider({
    required this.child,
    this.fontScaleAvailable = false,
    this.brandPrimaryColor = TdsPalette.blue500,
    super.key,
  });
  final Widget child;
  final bool fontScaleAvailable;
  final Color brandPrimaryColor;
  @override
  Widget build(BuildContext context) => TdsMobileProvider(
    child: Builder(
      builder: (context) {
        final inherited = TdsTheme.of(context);
        return TdsTheme(
          data: inherited.copyWith(
            colorScheme: TdsColorPreference.light,
            primary: brandPrimaryColor,
            platform: fontScaleAvailable
                ? inherited.platform
                : TdsPlatform(os: inherited.platform.os),
          ),
          child: child,
        );
      },
    ),
  );
}

class TdsColorSchemeArea extends StatelessWidget {
  const TdsColorSchemeArea({
    required this.theme,
    required this.child,
    super.key,
  });
  final TdsColorPreference theme;
  final Widget child;
  @override
  Widget build(BuildContext context) => TdsTheme(
    data: TdsTheme.of(context).copyWith(colorScheme: theme),
    child: child,
  );
}

class TdsFontScaleLimit extends StatelessWidget {
  const TdsFontScaleLimit({
    required this.child,
    this.limit = 310,
    this.minLimit = 100,
    super.key,
  }) : _web = true,
       _mobile = true,
       assert(minLimit <= limit);
  const TdsFontScaleLimit.tdsWeb({
    required this.child,
    this.limit = 310,
    this.minLimit = 100,
    super.key,
  }) : _web = true,
       _mobile = false,
       assert(minLimit <= limit);
  const TdsFontScaleLimit.tdsMobile({
    required this.child,
    this.limit = 310,
    this.minLimit = 100,
    super.key,
  }) : _web = false,
       _mobile = true,
       assert(minLimit <= limit);
  final Widget child;
  final double limit, minLimit;
  final bool _web, _mobile;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final host = theme.platform.unlimited;
    final limited = host.limited(limit: limit, minLimit: minLimit);
    // In-range inner limits emit no variables; an outer override still applies.
    if (identical(host, limited)) return child;
    return TdsTheme(
      data: theme.copyWith(
        platform: theme.platform._withTypography(
          mobile: _mobile ? limited : null,
          web: _web ? limited : null,
        ),
      ),
      child: child,
    );
  }
}

List<double> getTypographyRule(TdsPlatform platform) => platform.typographyRule;
double calculateSizeAsFontScale({
  required double baseSize,
  required TdsTypography typography,
  required TdsPlatform platform,
}) => (baseSize * platform.size(typography) / typography.baseSize)
    .roundToDouble();
TdsPlatform usePlatform(BuildContext context) =>
    TdsTheme.of(context).platform.unlimited;
TdsColorPreference useAppearance(BuildContext context) =>
    TdsTheme.of(context).colorScheme;
bool useFontScaleCondition(BuildContext context, TdsA11yCondition condition) =>
    condition.matches(usePlatform(context).fontScale);
bool useFontSizeCondition(
  BuildContext context,
  TdsTypography typography,
  TdsA11yCondition condition,
) => condition.matches(usePlatform(context).size(typography));
double useSafeAreaBottomHeight(
  BuildContext context, {
  double defaultHeight = 0,
}) {
  final bottom = MediaQuery.viewPaddingOf(context).bottom;
  return bottom == 0 ? defaultHeight : bottom;
}

double safeAreaInset(
  BuildContext context, {
  required bool top,
  double fallback = 20,
}) => math.max(
  fallback,
  top
      ? MediaQuery.viewPaddingOf(context).top
      : MediaQuery.viewPaddingOf(context).bottom,
);
double safeAreaInsetTop(BuildContext context, [double fallback = 20]) =>
    safeAreaInset(context, top: true, fallback: fallback);
double safeAreaInsetBottom(BuildContext context, [double fallback = 20]) =>
    safeAreaInset(context, top: false, fallback: fallback);
EdgeInsets safeAreaInsetPaddingTop(
  BuildContext context, [
  double fallback = 20,
]) => EdgeInsets.only(top: safeAreaInsetTop(context, fallback));
EdgeInsets safeAreaInsetPaddingBottom(
  BuildContext context, [
  double fallback = 20,
]) => EdgeInsets.only(bottom: safeAreaInsetBottom(context, fallback));
