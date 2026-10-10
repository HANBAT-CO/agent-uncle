import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() {
  final source =
      jsonDecode(File('reference/tokens.json').readAsStringSync())
          as Map<String, dynamic>;
  test(
    'every source typography size and iOS accessibility category is preserved',
    () {
      for (final entry in (source['text'] as Map<String, dynamic>).entries) {
        expect(tdsTextMetrics[int.parse(entry.key)], (
          entry.value['fontSize'].toDouble(),
          entry.value['lineHeight'].toDouble(),
        ));
      }
      for (final entry
          in (source['iosFontSizes'] as Map<String, dynamic>).entries) {
        expect(
          getTypographyRule(TdsPlatform(os: TdsOS.ios, fontA11y: entry.key)),
          entry.value,
        );
      }
      expect(
        const TdsPlatform(os: TdsOS.android, fontScale: 310).typographyRule,
        tdsIosFontSizes['A11y_xxxLarge'],
      );
      expect(
        const TdsPlatform(
          os: TdsOS.android,
          fontScale: 80,
        ).size(TdsTypography.t5),
        17,
      );
      expect(
        const TdsPlatform(os: TdsOS.web, fontScale: 310).size(TdsTypography.t5),
        17,
      );
    },
  );
  testWidgets(
    'AIT defaults remain light and 100 percent without double scaling',
    (tester) async {
      late TdsThemeData theme;
      late double scale;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            platformBrightness: Brightness.dark,
          ),
          child: TdsMobileAITProvider(
            child: Builder(
              builder: (context) {
                theme = TdsTheme.of(context);
                scale = MediaQuery.textScalerOf(context).scale(10);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(theme.colorScheme, TdsColorPreference.light);
      expect(theme.platform.fontScale, 100);
      expect(scale, 10);
    },
  );

  testWidgets(
    'FontScaleLimit limits CSS families without changing host hooks',
    (tester) async {
      for (final mode in ['both', 'mobile', 'web']) {
        for (final os in [TdsOS.android, TdsOS.ios]) {
          final host = TdsPlatform(
            os: os,
            fontScale: 310,
            fontA11y: 'A11y_xxxLarge',
          );
          late TdsPlatform rendered, actual;
          late bool largeHost, largeFont;
          final probe = Builder(
            builder: (context) {
              rendered = TdsTheme.of(context).platform;
              actual = usePlatform(context);
              largeHost = useFontScaleCondition(
                context,
                const TdsA11yCondition(biggerThan: 200),
              );
              largeFont = useFontSizeCondition(
                context,
                TdsTypography.t5,
                const TdsA11yCondition(biggerThan: 35),
              );
              return const SizedBox();
            },
          );
          final child = switch (mode) {
            'mobile' => TdsFontScaleLimit.tdsMobile(limit: 160, child: probe),
            'web' => TdsFontScaleLimit.tdsWeb(limit: 160, child: probe),
            _ => TdsFontScaleLimit(limit: 160, child: probe),
          };
          await tester.pumpWidget(
            TdsTheme(
              data: TdsThemeData(platform: host),
              child: child,
            ),
          );
          final limited = host.limited(limit: 160);
          for (final type in TdsTypography.values) {
            expect(
              rendered.size(type),
              (mode == 'web' ? host : limited).size(type),
            );
            expect(
              rendered.webSize(type),
              (mode == 'mobile' ? host : limited).webSize(type),
            );
          }
          expect(actual.fontScale, 310);
          expect(rendered.fontScale, 310);
          expect(largeHost, isTrue);
          expect(largeFont, isTrue);
          expect(actual.size(TdsTypography.t5), host.size(TdsTypography.t5));
        }
      }
    },
  );

  testWidgets(
    'nested independent limits preserve CSS inheritance and override order',
    (tester) async {
      const host = TdsPlatform(os: TdsOS.android, fontScale: 310);
      late TdsPlatform result;
      final probe = Builder(
        builder: (context) {
          result = TdsTheme.of(context).platform;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        TdsTheme(
          data: const TdsThemeData(platform: host),
          child: TdsFontScaleLimit(
            limit: 100,
            child: TdsFontScaleLimit.tdsWeb(
              limit: 160,
              child: TdsFontScaleLimit(limit: 310, child: probe),
            ),
          ),
        ),
      );
      for (final type in TdsTypography.values) {
        expect(result.size(type), host.limited(limit: 100).size(type));
        expect(result.webSize(type), host.limited(limit: 160).webSize(type));
      }
    },
  );

  test(
    'all iOS categories and Android limit boundaries follow original tables',
    () {
      for (final category in tdsIosFontScales.entries) {
        final platform = TdsPlatform(
          os: TdsOS.ios,
          fontA11y: category.key,
          fontScale: category.value,
        );
        for (final limit in tdsIosFontScales.entries.where(
          (e) => e.value >= 100,
        )) {
          final actual = platform.limited(limit: limit.value);
          final expected = category.value > limit.value
              ? limit.key
              : category.value < 100
              ? 'Large'
              : category.key;
          expect(actual.typographyRule, tdsIosFontSizes[expected]);
        }
      }
      for (final scale in [80.0, 100.0, 160.0, 160.01, 310.0, 400.0]) {
        final platform = TdsPlatform(os: TdsOS.android, fontScale: scale);
        final limited = platform.limited(limit: 160);
        expect(limited.fontScale, scale.clamp(100, 160));
        expect(identical(platform, limited), scale >= 100 && scale <= 160);
      }
    },
  );
}
