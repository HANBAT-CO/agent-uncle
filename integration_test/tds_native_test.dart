import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_inline.dart';
import 'package:tds_mobile_flutter/src/foundation/wiki_description.dart';
import 'list_row_live_test.dart' show registerListRowLiveTests;
import 'list_row_blink_test.dart' show registerListRowBlinkTests;
import 'list_input_color_test.dart' show registerListInputColorTests;
import 'list_replay_async_test.dart' show registerListReplayAsyncTests;
import 'list_footer_context_test.dart' show registerListFooterContextTests;
import 'list_footer_edges_test.dart' show registerListFooterEdgesTests;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native WikiText viewport entry, definition and reentry', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    for (final dark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final scroll = ScrollController();
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: scale,
            fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        var clicks = 0;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('wiki', dark, scale)),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, a, s) => builder(context),
            ),
            builder: (_, navigator) =>
                TdsMobileProvider(theme: theme, child: navigator!),
            home: ColoredBox(
              color: theme.color('background'),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  return SingleChildScrollView(
                    controller: scroll,
                    child: SizedBox(
                      height: height * 3,
                      child: Stack(
                        children: [
                          Positioned(
                            top: height * .75,
                            left: 24,
                            width: constraints.maxWidth - 48,
                            child: DefaultTextStyle(
                              style: theme.textStyle(
                                typography: TdsTypography.t5,
                              ),
                              child: TdsWikiText(
                                '여러 줄로 이어지는 아주 긴 금융 용어의 뜻을 확인해요',
                                description:
                                    '첫 번째 줄의 설명이에요.\n두 번째 줄의 설명도 확인해요.',
                                onClick: () => clicks++,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        TdsWikiInline inline() => tester.widget(find.byType(TdsWikiInline));
        expect(inline().iconSlotWidth, 0);
        await tester.tap(find.byType(TdsWikiText));
        expect(clicks, 0);
        scroll.jumpTo(scroll.position.viewportDimension * .4);
        await tester.pumpAndSettle();
        expect(inline().iconOpacity, 1);
        final suffix =
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}';
        await binding.takeScreenshot('tds-native-wiki-$suffix');
        await tester.tap(find.byType(TdsWikiText));
        await tester.pumpAndSettle();
        expect(clicks, 1);
        expect(find.byType(TdsWikiDescription), findsOneWidget);
        await binding.takeScreenshot('tds-native-wiki-definition-$suffix');
        await tester.tapAt(Offset(10, scroll.position.viewportDimension * .8));
        await tester.pumpAndSettle();
        expect(find.byType(TdsWikiDescription), findsNothing);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(inline().iconOpacity, 0);
        scroll.jumpTo(scroll.position.viewportDimension * .4);
        await tester.pumpAndSettle();
        expect(inline().iconOpacity, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        scroll.dispose();
        expect(tester.takeException(), isNull);
      }
    }
  });
  if (const bool.fromEnvironment('TDS_WIKI_ONLY')) return;
  testWidgets('native checkables, text entry, progress and overlay lifecycle', (
    tester,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    final sheet = TdsBottomSheetController();
    var checkbox = false, switched = false;
    var input = '';
    final platformName = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    const fontScales = [100.0, 160.0];
    for (final dark in [false, true]) {
      for (final scale in fontScales) {
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: defaultTargetPlatform == TargetPlatform.iOS
                ? TdsOS.ios
                : TdsOS.android,
            fontScale: scale,
            fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey((dark, scale)),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, a, s) => builder(context),
            ),
            builder: (context, navigator) => TdsMobileProvider(
              theme: theme,
              child: TdsHostProvider(
                haptic: const TdsPlatformHaptic(),
                child: ColoredBox(
                  color: theme.color('background'),
                  child: navigator!,
                ),
              ),
            ),
            home: TdsBottomSheetProvider(
              controller: sheet,
              child: StatefulBuilder(
                builder: (context, update) => ColoredBox(
                  color: theme.color('background'),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TdsText(
                              'TDS 네이티브 검증',
                              typography: TdsTypography.t3,
                            ),
                            const SizedBox(height: 24),
                            TdsCheckbox(
                              checked: checkbox,
                              semanticLabel: '동의',
                              onChanged: (value) =>
                                  update(() => checkbox = value),
                              child: const Text('필수 약관에 동의합니다'),
                            ),
                            const SizedBox(height: 24),
                            TdsSwitch(
                              checked: switched,
                              semanticLabel: '알림',
                              onChanged: (value) =>
                                  update(() => switched = value),
                            ),
                            const SizedBox(height: 24),
                            TdsProgressBar(progress: checkbox ? .75 : .25),
                            const SizedBox(height: 24),
                            TdsTextField(
                              variant: TdsTextFieldVariant.box,
                              label: '이름',
                              onChanged: (value) => input = value,
                            ),
                            const SizedBox(height: 24),
                            TdsButton(
                              onPressed: () => sheet.open(
                                const TdsBottomSheetOptions(
                                  header: '원본 기준 바텀시트',
                                  headerDescription:
                                      TdsBottomSheetHeaderDescription(
                                        '네이티브 경로에서 확인합니다',
                                      ),
                                  child: SizedBox(
                                    height: 120,
                                    child: TdsText('시트 내용'),
                                  ),
                                ),
                              ),
                              child: const Text('바텀시트 열기'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('TDS 네이티브 검증')).style!.fontSize,
          theme.platform.size(TdsTypography.t3),
        );
        final previousCheckbox = checkbox, previousSwitch = switched;
        await tester.tap(find.byType(TdsCheckbox));
        await tester.tap(find.byType(TdsSwitch));
        await tester.pumpAndSettle();
        expect(checkbox, !previousCheckbox);
        expect(switched, !previousSwitch);
        await tester.enterText(find.byType(EditableText), '토스 Native');
        await tester.pump();
        expect(input, '토스 Native');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final suffix =
            '$platformName-${dark ? 'dark' : 'light'}-${scale.toInt()}';
        await binding.takeScreenshot('tds-native-controls-$suffix');
        await tester.ensureVisible(find.text('바텀시트 열기'));
        await tester.tap(find.text('바텀시트 열기'));
        await tester.pumpAndSettle();
        expect(find.text('원본 기준 바텀시트'), findsOneWidget);
        expect(find.text('시트 내용'), findsOneWidget);
        await binding.takeScreenshot('tds-native-sheet-$suffix');
        sheet.close();
        await tester.pumpAndSettle();
        expect(find.text('시트 내용'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    sheet.dispose();
  });

  testWidgets('native text-button keep-all, underline and activation', (
    tester,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    var calls = 0;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    for (final dark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: scale,
            fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery.fromView(
              view: tester.view,
              child: TdsMobileProvider(
                theme: theme,
                child: TdsHostProvider(
                  haptic: const TdsPlatformHaptic(),
                  child: ColoredBox(
                    color: theme.color('background'),
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TdsText(
                                '텍스트 버튼 검증',
                                typography: TdsTypography.t3,
                              ),
                              const SizedBox(height: 32),
                              TdsTextButton(
                                key: const ValueKey('native-text-action'),
                                size: TdsTextButtonSize.medium,
                                colorToken: 'blue500',
                                onPressed: () => calls++,
                                child: const Text('누르기'),
                              ),
                              const SizedBox(height: 32),
                              const SizedBox(
                                width: 130,
                                child: TdsTextButton(
                                  size: TdsTextButtonSize.medium,
                                  variant: TdsTextButtonVariant.arrow,
                                  arrowPlacement: TdsArrowPlacement.inline,
                                  child: Text('자세한 내용을 확인하기'),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const TdsTextButton(
                                size: TdsTextButtonSize.xlarge,
                                variant: TdsTextButtonVariant.underline,
                                child: Text('확인하기'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = calls;
        await tester.tap(find.byKey(const ValueKey('native-text-action')));
        await tester.pumpAndSettle();
        expect(calls, before + 1);
        expect(find.text('자세한 내용을 확인하기'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot(
          'tds-native-text-buttons-${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}',
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native Highlight mask, inert target and dismissal lifecycle', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    for (final dark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        var target = 0, closed = 0, exited = 0;
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: scale,
            fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('highlight', dark, scale)),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            builder: (context, navigator) => TdsMobileProvider(
              theme: theme,
              child: ColoredBox(
                color: theme.color('background'),
                child: navigator!,
              ),
            ),
            home: Stack(
              children: [
                Positioned(
                  left: 40,
                  top: 180,
                  width: 200,
                  child: TdsHighlight(
                    open: true,
                    padding: 8,
                    message: const Text('여기에서 새로운 기능을\n확인할 수 있어요'),
                    onClose: () => closed++,
                    onExited: () => exited++,
                    child: TdsButton(
                      key: const ValueKey('highlight-target'),
                      onPressed: () => target++,
                      child: const Text('강조 대상'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TdsHighlightUI), findsOneWidget);
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('highlight-target'))),
        );
        expect(target, 0);
        expect(closed, 0);
        await binding.takeScreenshot(
          'tds-native-highlight-${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}',
        );
        await tester.tapAt(const Offset(20, 120));
        await tester.pumpAndSettle();
        expect(closed, 1);
        expect(exited, 1);
        expect(find.byType(TdsHighlightUI), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native FullTooltip inline reflow and floating blur', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    for (final dark in [false, true]) {
      for (final scale in [100.0, 160.0]) {
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: scale,
            fontA11y: scale == 160 ? 'A11y_Medium' : 'Large',
          ),
        );
        var outside = 0;
        var message = '새로운 기능을 확인하고\n안내를 계속 읽어 보세요';
        var open = true, overlapped = false, floatingOpen = true;
        late StateSetter updateTooltip;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(('full-tooltip', dark, scale)),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            builder: (context, navigator) => TdsMobileProvider(
              theme: theme,
              child: ColoredBox(
                color: theme.color('background'),
                child: navigator!,
              ),
            ),
            home: StatefulBuilder(
              builder: (context, update) {
                updateTooltip = update;
                return Column(
                  children: [
                    const SizedBox(height: 100),
                    TdsFullTooltip(
                      key: const ValueKey('resizing-tooltip'),
                      open: open,
                      anchorOverlapped: overlapped,
                      placement: TdsOverlayPlacement.bottom,
                      message: Text(message),
                      child: const SizedBox(
                        height: 48,
                        child: ColoredBox(
                          color: TdsPalette.grey100,
                          child: Center(child: Text('기준 영역')),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                    TdsFullTooltip(
                      open: floatingOpen,
                      floating: true,
                      placement: TdsOverlayPlacement.top,
                      onClickOutside: () => outside++,
                      message: const Text('플로팅 안내'),
                      child: const SizedBox(
                        height: 48,
                        child: ColoredBox(
                          color: TdsPalette.grey100,
                          child: Center(child: Text('다음 기준')),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TdsFullTooltipSurface), findsNWidgets(2));
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tapAt(const Offset(20, 80));
        expect(outside, 1);
        await binding.takeScreenshot(
          'tds-native-full-tooltip-${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}',
        );
        final resizing = find.byKey(const ValueKey('resizing-tooltip'));
        final initialHeight = tester.getSize(resizing).height;
        updateTooltip(() => message = '첫 번째 안내\n두 번째 안내\n세 번째 안내');
        await tester.pump();
        expect(tester.getSize(resizing).height, initialHeight);
        // Two independent 100ms trailing observers: message -> surface -> flow.
        // pumpAndSettle alone does not wait for a timer with no scheduled frame.
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        final resizedHeight = tester.getSize(resizing).height;
        expect(resizedHeight, greaterThan(initialHeight));
        updateTooltip(() => overlapped = true);
        await tester.pumpAndSettle();
        expect(tester.getSize(resizing).height, resizedHeight - 12);
        updateTooltip(() => open = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byType(TdsFullTooltipSurface), findsNWidgets(2));
        updateTooltip(() => open = true);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.getSize(resizing).height, resizedHeight - 12);
        await binding.takeScreenshot(
          'tds-native-full-tooltip-resized-${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}',
        );
        // eo unwraps an interrupted reopened child. Only its NEXT close skips
        // the retained exit; a subsequent fresh mount restores normal exit.
        updateTooltip(() => open = false);
        await tester.pump();
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        expect(tester.getSize(resizing).height, 48);
        updateTooltip(() => open = true);
        await tester.pumpAndSettle();
        updateTooltip(() => open = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byType(TdsFullTooltipSurface), findsNWidgets(2));
        await tester.pumpAndSettle();
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        updateTooltip(() => floatingOpen = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        updateTooltip(() => floatingOpen = true);
        // Apply reopen now: pumpAndSettle's first pump waits another 100ms.
        // On the live clock, that can finish this 200ms exit before rebuilding,
        // testing a fresh mount instead of the intended interrupted reopen.
        await tester.pump();
        await tester.pumpAndSettle();
        updateTooltip(() => floatingOpen = false);
        await tester.pump();
        await tester.pump();
        expect(find.byType(TdsFullTooltipSurface), findsNothing);
        updateTooltip(() => floatingOpen = true);
        await tester.pump();
        await tester.pumpAndSettle();
        updateTooltip(() => floatingOpen = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byType(TdsFullTooltipSurface), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byType(TdsFullTooltipSurface), findsNothing);
        expect(find.text('다음 기준'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  registerListRowLiveTests(binding);
  registerListRowBlinkTests(binding);
  registerListInputColorTests(binding);
  registerListReplayAsyncTests(binding);
  registerListFooterContextTests(binding);
  registerListFooterEdgesTests(binding);
}
