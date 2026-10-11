import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

/// Keeps the package's layout, colors and AIT accessibility settings intact.
/// Fonts live in the application bundle, not in the reusable TDS package.
class PaperlogyTheme extends TdsThemeData {
  const PaperlogyTheme({super.colorScheme, super.primary, super.platform});

  @override
  TextStyle textStyle({
    TdsTypography typography = TdsTypography.st10,
    TdsFontWeight fontWeight = TdsFontWeight.regular,
    Color? color,
  }) {
    final metrics = super.textStyle(
      typography: typography,
      fontWeight: fontWeight,
      color: color,
    );
    // TextStyle.copyWith retains the source package, which would resolve to
    // packages/tds_mobile_flutter/Paperlogy instead of the app's font asset.
    return TextStyle(
      fontFamily: 'Paperlogy',
      fontSize: metrics.fontSize,
      height: metrics.height,
      fontWeight: metrics.fontWeight,
      color: metrics.color,
      leadingDistribution: metrics.leadingDistribution,
    );
  }

  @override
  PaperlogyTheme copyWith({
    TdsColorPreference? colorScheme,
    Color? primary,
    TdsPlatform? platform,
  }) => PaperlogyTheme(
    colorScheme: colorScheme ?? this.colorScheme,
    primary: primary ?? this.primary,
    platform: platform ?? this.platform,
  );
}

abstract final class AppColors {
  static const primary = Color(0xFF0C483E);
  // Restore the original warm whites and charcoal; green is an accent only.
  static const background = Color(0xFFEDECE3);
  static const surface = Color(0xFFF5F4EE);
  static const charcoal = Color(0xFF101010);
  static const lime = Color(0xFFC6FF3A);
  // Official social provider colors; artwork is preserved in bundled assets.
  static const googleBorder = Color(0xFF747775);
  static const kakaoYellow = Color(0xFFFEE500);
}

/// App branding is resolved here so the TDS reference palette stays reusable.
class AppThemeData extends PaperlogyTheme {
  const AppThemeData({
    super.colorScheme,
    super.primary = AppColors.primary,
    super.platform,
  });

  @override
  Color get primaryButtonBackground => primary;

  @override
  Color get primaryButtonWeakBackground => primary.withValues(alpha: .12);

  @override
  Color get primaryButtonWeakForeground => primary;

  @override
  Color color(String name) {
    if (isDark) return super.color(name);
    return switch (name) {
      'primary' || 'blue500' => primary,
      'blue50' => const Color(0xFFF2FFE8),
      'blue100' => const Color(0xFFD9E9DC),
      'blue200' => const Color(0xFFB6D7C2),
      'blue300' => const Color(0xFF3E9A57),
      'blue400' => const Color(0xFF2E8C6B),
      'blue600' || 'blue700' || 'tBlueBadgeColor' => primary,
      'blue800' || 'blue900' => const Color(0xFF07231C),
      'tBlueBadgeBackground' => primary.withValues(alpha: .12),
      'background' => AppColors.background,
      'floatBackground' ||
      'layeredBackground' ||
      'backgroundLevel01' ||
      'backgroundLevel02' ||
      'cardBgWhite' => AppColors.surface,
      'greyBackground' ||
      'backgroundLevelB01' ||
      'pcScreenBg' => const Color(0xFFE4E3DA),
      'grey50' => const Color(0xFFF3F2EB),
      'grey100' => const Color(0xFFE4E3DA),
      'grey200' || 'hairlineBorder' => const Color(0xFFD7D7D7),
      'grey300' => const Color(0xFFBFBFBF),
      'grey400' => const Color(0xFFA3A3A3),
      'grey500' => const Color(0xFF808080),
      'grey600' => const Color(0xFF636363),
      'grey700' || 'tElephantBadgeColor' => const Color(0xFF484848),
      'grey800' => const Color(0xFF2D2D2D),
      'grey900' || 'black' => AppColors.charcoal,
      'greyOpacity50' ||
      'cardBgGrey' => AppColors.charcoal.withValues(alpha: .02),
      'opacity100' ||
      'greyOpacity100' => AppColors.charcoal.withValues(alpha: .05),
      'greyOpacity200' ||
      'tElephantBadgeBackground' => AppColors.charcoal.withValues(alpha: .10),
      'greyOpacity300' => AppColors.charcoal.withValues(alpha: .18),
      'greyOpacity400' => AppColors.charcoal.withValues(alpha: .31),
      'greyOpacity500' => AppColors.charcoal.withValues(alpha: .46),
      'greyOpacity600' => AppColors.charcoal.withValues(alpha: .58),
      'greyOpacity700' => AppColors.charcoal.withValues(alpha: .70),
      'greyOpacity800' => AppColors.charcoal.withValues(alpha: .80),
      'greyOpacity900' => AppColors.charcoal.withValues(alpha: .91),
      'backgroundDimmed' => AppColors.charcoal.withValues(alpha: .20),
      _ => super.color(name),
    };
  }

  @override
  AppThemeData copyWith({
    TdsColorPreference? colorScheme,
    Color? primary,
    TdsPlatform? platform,
  }) => AppThemeData(
    colorScheme: colorScheme ?? this.colorScheme,
    primary: primary ?? this.primary,
    platform: platform ?? this.platform,
  );
}

/// The supplied symbol is kept in its original black and original aspect ratio.
class AppLogo extends StatelessWidget {
  const AppLogo({this.width = 112, super.key});
  static const asset = 'assets/logos/saip_samchun_sc_symbol.svg';
  final double width;

  @override
  Widget build(BuildContext context) => TdsAssetImage(
    src: asset,
    alt: '사입삼춘 로고',
    frameShape: TdsAssetFrameShape(
      width: width,
      height: width * 254 / 415,
      transparent: true,
    ),
  );
}

class AppTheme extends StatelessWidget {
  const AppTheme({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final inherited = TdsTheme.of(context);
    final theme = AppThemeData(
      colorScheme: inherited.colorScheme,
      platform: inherited.platform,
    );
    return TdsTheme(
      data: theme,
      child: DefaultTextStyle(style: theme.textStyle(), child: child),
    );
  }
}
