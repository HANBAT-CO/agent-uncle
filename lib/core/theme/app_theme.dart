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
      typography: typography, fontWeight: fontWeight, color: color,
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
  static const primary = Color(0xFFD9704F);
  static const background = Color(0xFFEDECE3);
  static const charcoal = Color(0xFF101010);
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
  Color color(String name) {
    if (isDark) return super.color(name);
    return switch (name) {
      'primary' || 'blue500' => primary,
      'blue50' => const Color(0xFFF3E5DC),
      'blue100' => const Color(0xFFEED6C8),
      'blue200' => const Color(0xFFE9BBA7),
      'blue300' => const Color(0xFFE4A38A),
      'blue400' => const Color(0xFFDF896C),
      'blue600' => const Color(0xFFB85538),
      'blue700' || 'tBlueBadgeColor' => const Color(0xFF99452F),
      'blue800' => const Color(0xFF7A3729),
      'blue900' => const Color(0xFF5C2C25),
      'tBlueBadgeBackground' => primary.withValues(alpha: .12),
      'background' => AppColors.background,
      'floatBackground' ||
      'layeredBackground' ||
      'backgroundLevel01' ||
      'backgroundLevel02' ||
      'cardBgWhite' => const Color(0xFFF5F4EE),
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
