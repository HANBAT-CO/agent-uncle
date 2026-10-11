import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';

List<String> _lines(RenderParagraph paragraph) {
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final result = <double, StringBuffer>{};
  var offset = 0;
  for (final character in raw.characters) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: offset,
        extentOffset: offset + character.length,
      ),
      boxHeightStyle: BoxHeightStyle.max,
    );
    offset += character.length;
    if (character == '\u2060') continue;
    for (final box in boxes) {
      if (box.right <= box.left) continue;
      (result[box.top] ??= StringBuffer()).write(character);
      break;
    }
  }
  return result.values.map((line) => line.toString().trimRight()).toList();
}

// Original 2.5.1 rows in reference/word-break.json, all with full visible text.
const _clusterCases = <(String, String, Map<int, List<String>>)>[
  (
    "bmp",
    "앞 한\ufe0fABC 뒤",
    {
      90: ["앞", "한\ufe0fAB", "C 뒤"],
      130: ["앞", "한\ufe0fABC", "뒤"],
      210: ["앞 한\ufe0fABC 뒤"],
    },
  ),
  (
    "supplementary",
    "앞 한\u{e0100}ABCDEFGHIJ 뒤",
    {
      90: ["앞 한\u{e0100}", "ABC", "DEF", "GHI", "J 뒤"],
      130: ["앞 한\u{e0100}", "ABCD", "EFGHI", "J 뒤"],
      210: ["앞 한\u{e0100}", "ABCDEFG", "HIJ 뒤"],
    },
  ),
  (
    "word-joiner",
    "앞 한\u{e0100}\u2060ABCDEFGHIJ 뒤",
    {
      90: ["앞", "한\u{e0100}AB", "CDE", "FGH", "IJ 뒤"],
      130: ["앞", "한\u{e0100}ABC", "DEFG", "HIJ 뒤"],
      210: ["앞", "한\u{e0100}ABCDEF", "GHIJ 뒤"],
    },
  ),
  (
    "zwj",
    "앞 한\u200dABCDEFGHIJ 뒤",
    {
      90: ["앞", "한\u200dAB", "CDE", "FGH", "IJ 뒤"],
      130: ["앞", "한\u200dABC", "DEFG", "HIJ 뒤"],
      210: ["앞", "한\u200dABCDEF", "GHIJ 뒤"],
    },
  ),
  (
    "zwnj",
    "앞 한\u200c123 뒤",
    {
      90: ["앞 한\u200c", "123", "뒤"],
      130: ["앞 한\u200c", "123 뒤"],
      210: ["앞 한\u200c123 뒤"],
    },
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native rich labels inherit keep-all without losing activation', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    const stage = String.fromEnvironment(
      'TDS_WORD_BREAK_STAGE',
      defaultValue: 'after',
    );
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
        final suffix =
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${scale.toInt()}';
        var clicks = 0;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(suffix),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: TdsMobileProvider(
              theme: theme,
              child: ColoredBox(
                color: theme.color('background'),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in <(String, Widget)>[
                          ('plain', const Text('자세한 내용을 확인하기')),
                          (
                            'styled',
                            const Text.rich(
                              TextSpan(
                                text: '자',
                                children: [
                                  TextSpan(
                                    text: '세한 ',
                                    style: TextStyle(color: Color(0xff3182f6)),
                                  ),
                                  TextSpan(
                                    text: '내',
                                    children: [TextSpan(text: '용')],
                                  ),
                                  TextSpan(text: '을 '),
                                  TextSpan(
                                    text: '확인',
                                    style: TextStyle(color: Color(0xfff04452)),
                                    children: [TextSpan(text: '하')],
                                  ),
                                  TextSpan(text: '기'),
                                ],
                              ),
                            ),
                          ),
                          (
                            'decomposed',
                            const Text(
                              '\u1112\u1161\u11ab\u1100\u1173\u11af 계속',
                            ),
                          ),
                        ]) ...[
                          TdsText(entry.$1, typography: TdsTypography.t7),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 130,
                            child: TdsTextButton(
                              key: ValueKey(entry.$1),
                              size: TdsTextButtonSize.medium,
                              onPressed: () => clicks++,
                              child: entry.$2,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('tds-native-word-break-$stage-$suffix');
        for (final key in ['plain', 'styled']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(RichText),
            ),
          );
          expect(
            _lines(paragraph),
            scale == 100 ? ['자세한 내용을', '확인하기'] : ['자세한', '내용을', '확인하기'],
            reason: '$suffix/$key',
          );
        }
        await tester.tap(find.byKey(const ValueKey('styled')));
        await tester.pumpAndSettle();
        expect(clicks, 1);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native oversized words reshape at emergency line endings', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    final cases = <(String, String, double, List<String>)>[
      ('korean', '자세한 내용을 확인하기', 90, ['자세', '한', '내용', '을', '확인', '하기']),
      (
        'latin',
        '한글 LatinTextCombined 다음',
        90,
        ['한글', 'Lati', 'nTex', 'tCo', 'mbi', 'ned', '다음'],
      ),
      (
        'latin',
        '한글 LatinTextCombined 다음',
        60,
        ['한', '글', 'La', 'tin', 'Te', 'xt', 'Co', 'mb', 'ine', 'd', '다', '음'],
      ),
    ];
    for (final dark in [false, true]) {
      final theme = TdsThemeData(
        colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
        // These different host settings both resolve t4 to the measured 40px.
        platform: TdsPlatform(
          os: ios ? TdsOS.ios : TdsOS.android,
          fontScale: ios ? 310 : 200,
          fontA11y: ios ? 'A11y_xxxLarge' : 'Large',
        ),
      );
      expect(theme.platform.size(TdsTypography.t4), 40);
      for (final item in cases) {
        final suffix =
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${item.$1}-${item.$3.toInt()}';
        var clicks = 0;
        final split = item.$2.indexOf(' ') + 1;
        await tester.pumpWidget(
          WidgetsApp(
            key: ValueKey(suffix),
            color: theme.color('background'),
            debugShowCheckedModeBanner: false,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: TdsMobileProvider(
              theme: theme,
              child: ColoredBox(
                color: theme.color('background'),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final rich in [false, true]) ...[
                          SizedBox(
                            width: item.$3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TdsText(
                                  rich ? 'rich' : 'plain',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TdsTextButton(
                                  key: ValueKey(rich),
                                  size: TdsTextButtonSize.large,
                                  onPressed: () => clicks++,
                                  child: rich
                                      ? Text.rich(
                                          TextSpan(
                                            text: item.$2.substring(0, split),
                                            children: [
                                              TextSpan(
                                                text: item.$2.substring(split),
                                                style: const TextStyle(
                                                  color: Color(0xff3182f6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Text(item.$2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final rich in [false, true]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(ValueKey(rich)),
              matching: find.byType(RichText),
            ),
          );
          expect(_lines(paragraph), item.$4, reason: '$suffix/rich=$rich');
          if (rich) expect(paragraph.text.toPlainText(), item.$2);
        }
        await binding.takeScreenshot('tds-native-emergency-$suffix');
        await tester.tap(find.byKey(const ValueKey(true)));
        await tester.pumpAndSettle();
        expect(clicks, 1);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native selectable keep-all preserves original clipboard text', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    const label = '자세한 내용을 확인하기';
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Test the actual Copy action without changing the simulator/host clipboard.
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    for (final dark in [false, true]) {
      for (final rich in [false, true]) {
        String? selected;
        copied = null;
        final selectionFocus = FocusNode();
        addTearDown(selectionFocus.dispose);
        final theme = TdsThemeData(
          colorScheme: dark
              ? TdsColorPreference.dark
              : TdsColorPreference.light,
          platform: TdsPlatform(
            os: ios ? TdsOS.ios : TdsOS.android,
            fontScale: 160,
            fontA11y: 'A11y_Medium',
          ),
        );
        final style = theme.textStyle(
          typography: TdsTypography.t5,
          fontWeight: TdsFontWeight.semibold,
        );
        final suffix =
            '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${rich ? 'rich' : 'plain'}';
        await tester.pumpWidget(
          material.MaterialApp(
            key: ValueKey(suffix),
            debugShowCheckedModeBanner: false,
            home: TdsMobileProvider(
              theme: theme,
              child: material.Scaffold(
                backgroundColor: theme.color('background'),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
                  child: material.SelectionArea(
                    focusNode: selectionFocus,
                    onSelectionChanged: (content) =>
                        selected = content?.plainText,
                    child: SizedBox(
                      width: 130,
                      child: TdsKeepAllText.from(
                        rich
                            ? Text.rich(
                                TextSpan(
                                  text: '자세한 ',
                                  children: [
                                    TextSpan(
                                      text: '내용을 확인하기',
                                      style: TextStyle(
                                        color: theme.color('blue500'),
                                      ),
                                    ),
                                  ],
                                ),
                                style: style,
                              )
                            : Text(label, style: style),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Flush nested registrar post-frame updates even without animations.
        for (var frame = 0; frame < 4; frame++) {
          binding.scheduleFrame();
          await tester.pump();
        }
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(_lines(paragraph), ['자세한', '내용을', '확인하기']);
        final region = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        selectionFocus.requestFocus();
        await tester.pumpAndSettle();
        region.selectAll();
        await tester.pumpAndSettle();
        expect(selected, label);
        // Native screenshot capture may otherwise observe the previous raster
        // frame even after the selection notifier has updated synchronously.
        binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 100));
        await binding.takeScreenshot('tds-native-selection-$suffix');
        region.contextMenuButtonItems
            .singleWhere((item) => item.type == ContextMenuButtonType.copy)
            .onPressed!();
        await tester.pumpAndSettle();
        expect(copied, label);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'native emergency selection preserves words across reflow and Copy',
    (tester) async {
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      if (!ios) await binding.convertFlutterSurfaceToImage();
      const source = '한글 LatinTextCombined 다음';
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      Future<void> settle() async {
        await tester.pumpAndSettle();
        final depth = find.byType(SelectionContainer).evaluate().length;
        for (var frame = 0; frame <= depth; frame++) {
          binding.scheduleFrame();
          await tester.pump();
        }
      }

      for (final dark in [false, true]) {
        for (final rich in [false, true]) {
          final theme = TdsThemeData(
            colorScheme: dark
                ? TdsColorPreference.dark
                : TdsColorPreference.light,
            platform: TdsPlatform(
              os: ios ? TdsOS.ios : TdsOS.android,
              fontScale: ios ? 310 : 200,
              fontA11y: ios ? 'A11y_xxxLarge' : 'Large',
            ),
          );
          final style = theme.textStyle(
            typography: TdsTypography.t4,
            fontWeight: TdsFontWeight.semibold,
          );
          final suffix =
              '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${rich ? 'rich' : 'plain'}';
          final delegate = StaticSelectionContainerDelegate();
          final focus = FocusNode();
          final width = ValueNotifier(90.0);
          String? selected;
          await tester.pumpWidget(
            material.MaterialApp(
              key: ValueKey(suffix),
              debugShowCheckedModeBanner: false,
              home: material.Scaffold(
                backgroundColor: theme.color('background'),
                // Keep Material's body letter spacing outside the original
                // typography specimen. The reference uses normal spacing.
                body: TdsMobileProvider(
                  theme: theme,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
                      child: material.SelectionArea(
                        focusNode: focus,
                        onSelectionChanged: (content) =>
                            selected = content?.plainText,
                        child: SelectionContainer(
                          delegate: delegate,
                          child: ValueListenableBuilder<double>(
                            valueListenable: width,
                            builder: (context, value, child) => Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: value,
                                // Rebuild as a responsive application does,
                                // rather than retaining an unchanged child.
                                child: TdsKeepAllText.from(
                                  rich
                                      ? Text.rich(
                                          TextSpan(
                                            text: '한글 ',
                                            children: [
                                              TextSpan(
                                                text: 'LatinTextCombined 다음',
                                                style: TextStyle(
                                                  color: theme.color('blue500'),
                                                ),
                                              ),
                                            ],
                                          ),
                                          style: style,
                                        )
                                      : Text(source, style: style),
                                ),
                              ),
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
          await settle();
          focus.requestFocus();
          await tester.pumpAndSettle();
          final labelParagraph = find.descendant(
            of: find.byType(TdsKeepAllText),
            matching: find.byType(RichText),
          );
          var paragraph = tester.renderObject<RenderParagraph>(labelParagraph);
          expect(_lines(paragraph), [
            '한글',
            'Lati',
            'nTex',
            'tCo',
            'mbi',
            'ned',
            '다음',
          ]);
          final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
          final offset = raw.indexOf('C');
          final box = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: offset, extentOffset: offset + 1),
              )
              .first;
          // Start through the owning SelectionArea so its outer registrar
          // knows which child owns the selection and can expose the Copy menu.
          await tester.longPressAt(
            paragraph.localToGlobal(box.toRect().center),
          );
          await settle();
          expect(selected, 'LatinTextCombined');
          for (final value in [60.0, 240.0, 90.0]) {
            width.value = value;
            await settle();
            if (value == 60) {
              expect(
                _lines(tester.renderObject<RenderParagraph>(labelParagraph)),
                [
                  '한',
                  '글',
                  'La',
                  'tin',
                  'Te',
                  'xt',
                  'Co',
                  'mb',
                  'ine',
                  'd',
                  '다',
                  '음',
                ],
              );
            }
            expect(
              selected,
              'LatinTextCombined',
              reason: 'width=$value $suffix',
            );
            expect(
              delegate.getSelection(),
              const SelectedContentRange(startOffset: 3, endOffset: 20),
            );
          }
          paragraph = tester.renderObject<RenderParagraph>(labelParagraph);
          expect(_lines(paragraph), [
            '한글',
            'Lati',
            'nTex',
            'tCo',
            'mbi',
            'ned',
            '다음',
          ]);
          binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 100));
          await binding.takeScreenshot(
            'tds-native-selection-emergency-$suffix',
          );
          final region = tester.state<SelectableRegionState>(
            find.byType(SelectableRegion),
          );
          region.contextMenuButtonItems
              .singleWhere((item) => item.type == ContextMenuButtonType.copy)
              .onPressed!();
          await tester.pumpAndSettle();
          expect(copied, 'LatinTextCombined');
          region.selectAll();
          await settle();
          binding.addPostFrameCallback((_) => region.clearSelection());
          width.value = 60;
          await settle();
          expect(selected, isNull);
          expect(delegate.getSelection(), isNull);
          expect(delegate.value.status, SelectionStatus.none);
          expect(delegate.contentLength, source.length);
          region.selectAll();
          await settle();
          expect(selected, source);
          binding.addPostFrameCallback((_) {
            region.selectAll();
            for (final forward in [false, false, true]) {
              delegate.dispatchSelectionEvent(
                GranularlyExtendSelectionEvent(
                  forward: forward,
                  isEnd: true,
                  granularity: TextGranularity.character,
                ),
              );
            }
          });
          width.value = 90;
          await tester.pumpAndSettle();
          // The public selectAll callback is synchronous. Direct delegate
          // commands are checked through their own content/range contract.
          expect(selected, source);
          expect(
            delegate.getSelectedContent()?.plainText,
            source.substring(0, source.length - 1),
          );
          expect(
            delegate.getSelection(),
            const SelectedContentRange(
              startOffset: 0,
              endOffset: source.length - 1,
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          delegate.dispose();
          focus.dispose();
          width.dispose();
        }
      }
    },
  );
  _registerClusterBoundaryTests(binding);
}

void _registerClusterBoundaryTests(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  testWidgets('native cluster boundaries keep source lines and Copy on reflow', (
    tester,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!ios) await binding.convertFlutterSurfaceToImage();
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    Future<void> settle() async {
      await tester.pumpAndSettle();
      final depth = find.byType(SelectionContainer).evaluate().length;
      for (var frame = 0; frame <= depth; frame++) {
        binding.scheduleFrame();
        await tester.pump();
      }
    }

    for (final dark in [false, true]) {
      final theme = TdsThemeData(
        colorScheme: dark ? TdsColorPreference.dark : TdsColorPreference.light,
        platform: TdsPlatform(
          os: ios ? TdsOS.ios : TdsOS.android,
          fontScale: ios ? 310 : 200,
          fontA11y: ios ? 'A11y_xxxLarge' : 'Large',
        ),
      );
      expect(theme.platform.size(TdsTypography.t4), 40);
      for (final specimen in _clusterCases) {
        for (final rich in [false, true]) {
          final source = specimen.$2;
          final unit = source.codeUnitAt(3);
          final end = 3 + (unit >= 0xd800 && unit <= 0xdbff ? 2 : 1);
          final width = ValueNotifier(90.0);
          final delegate = StaticSelectionContainerDelegate();
          final suffix =
              '${ios ? 'ios' : 'android'}-${dark ? 'dark' : 'light'}-${specimen.$1}-${rich ? 'rich' : 'plain'}';
          String? selected;
          await tester.pumpWidget(
            material.MaterialApp(
              key: ValueKey(suffix),
              debugShowCheckedModeBanner: false,
              home: material.Scaffold(
                backgroundColor: theme.color('background'),
                body: TdsMobileProvider(
                  theme: theme,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: material.SelectionArea(
                          onSelectionChanged: (content) =>
                              selected = content?.plainText,
                          child: SelectionContainer(
                            delegate: delegate,
                            child: ValueListenableBuilder<double>(
                              valueListenable: width,
                              builder: (context, value, _) => SizedBox(
                                width: value,
                                child: TdsTextButton(
                                  key: const ValueKey('cluster-label'),
                                  size: TdsTextButtonSize.large,
                                  child: rich
                                      ? Text.rich(
                                          TextSpan(
                                            text: source.substring(0, 3),
                                            children: [
                                              TextSpan(
                                                text: source.substring(3, end),
                                                style: const TextStyle(
                                                  color: Color(0xff3182f6),
                                                ),
                                              ),
                                              TextSpan(
                                                text: source.substring(end),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Text(source),
                                ),
                              ),
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
          await settle();
          final region = tester.state<SelectableRegionState>(
            find.byType(SelectableRegion),
          );
          region.selectAll();
          await tester.pump();
          for (final value in [90, 130, 210, 90]) {
            width.value = value.toDouble();
            await settle();
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(const ValueKey('cluster-label')),
                matching: find.byType(RichText),
              ),
            );
            expect(
              _lines(paragraph),
              specimen.$3[value],
              reason: '$suffix/$value',
            );
            expect(selected, source, reason: '$suffix/$value');
            expect(delegate.getSelectedContent()!.plainText, source);
            expect(delegate.contentLength, source.length);
            expect(
              delegate.getSelection(),
              SelectedContentRange(startOffset: 0, endOffset: source.length),
            );
          }
          if (!rich && ['bmp', 'supplementary'].contains(specimen.$1)) {
            region.clearSelection();
            await settle();
            await tester.pump(const Duration(milliseconds: 100));
            await binding.takeScreenshot('tds-native-cluster-boundary-$suffix');
            region.selectAll();
            await tester.pump();
          }
          copied = null;
          region.contextMenuButtonItems
              .singleWhere(
                (item) => item.type == material.ContextMenuButtonType.copy,
              )
              .onPressed!();
          await tester.pump();
          expect(copied, source);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          delegate.dispose();
          width.dispose();
        }
      }
    }
  });
}
