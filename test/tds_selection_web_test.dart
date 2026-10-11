import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';

// Narrow foundation imports avoid Flutter's browser test-server host.dart.js
// collision. Ahem is sufficient for copy/offset contracts, not glyph geometry.
Future<void> settleSelection(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final depth = find.byType(SelectionContainer).evaluate().length;
  for (var frame = 0; frame < depth; frame++) {
    tester.binding.scheduleFrame();
    await tester.pump();
  }
}

List<String> _lines(RenderParagraph paragraph) {
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final lines = <double, StringBuffer>{};
  for (var offset = 0; offset < raw.length; offset++) {
    if (raw.codeUnitAt(offset) == 0x2060) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    for (final box in boxes) {
      if (box.right <= box.left) continue;
      (lines[box.top] ??= StringBuffer()).write(raw[offset]);
      break;
    }
  }
  return lines.values.map((line) => line.toString().trimRight()).toList();
}

void main() {
  testWidgets('Chrome rebuilt labels preserve selection and respect clear', (
    tester,
  ) async {
    const source = 'ab CDEFGHIJK zz';
    for (final rich in [false, true]) {
      final layout = ValueNotifier((60.0, 20.0));
      final delegate = StaticSelectionContainerDelegate();
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (content) => selected = content?.plainText,
              child: SelectionContainer(
                delegate: delegate,
                child: ValueListenableBuilder<(double, double)>(
                  valueListenable: layout,
                  builder: (context, value, child) => DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: value.$2,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
                    child: SizedBox(
                      width: value.$1,
                      child: TdsKeepAllText.from(
                        rich
                            ? const Text.rich(
                                TextSpan(
                                  text: 'ab ',
                                  children: [
                                    TextSpan(
                                      text: 'CDEFGHIJK zz',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                ),
                              )
                            : const Text(source),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settleSelection(tester);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      for (final next in [(40.0, 20.0), (120.0, 28.0), (60.0, 20.0)]) {
        layout.value = next;
        await settleSelection(tester);
        expect(selected, source, reason: 'layout=$next rich=$rich');
        expect(
          delegate.getSelection(),
          const SelectedContentRange(startOffset: 0, endOffset: source.length),
        );
      }
      tester.binding.addPostFrameCallback((_) => region.clearSelection());
      layout.value = (40, 28);
      await settleSelection(tester);
      expect(selected, isNull);
      expect(delegate.getSelection(), isNull);
      expect(delegate.contentLength, source.length);
      region.selectAll();
      await tester.pump();
      expect(selected, source);
      tester.binding.addPostFrameCallback((_) {
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
      layout.value = (60, 20);
      await tester.pumpAndSettle();
      // SelectionArea synchronously reports its public selectAll operation.
      // Direct child-delegate events update content/ranges, not that callback.
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
      delegate.dispose();
      layout.dispose();
    }
  }, skip: !kIsWeb);

  testWidgets('Chrome emergency selection survives reflow and Copy', (
    tester,
  ) async {
    const source = 'ab CDEFGHIJK zz';
    final width = ValueNotifier(60.0);
    addTearDown(width.dispose);
    String? selected;
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value?.plainText,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              child: TdsKeepAllText.from(
                const Text(
                  source,
                  style: TextStyle(
                    fontFamily: 'Ahem',
                    fontSize: 20,
                    height: 1.4,
                  ),
                ),
              ),
              builder: (context, value, child) =>
                  SizedBox(width: value, child: child),
            ),
          ),
        ),
      ),
    );
    await settleSelection(tester);
    final lines = _lines(
      tester.renderObject<RenderParagraph>(find.byType(RichText)),
    );
    // The browser test runner's resolved font need not have fixed-width glyphs.
    // Verify natural-space precedence and emergency splitting here; the pinned
    // original-font matrices verify exact character membership separately.
    expect(lines.first, 'ab');
    expect(lines.last, 'zz');
    expect(lines.length, greaterThan(3));
    expect(lines.sublist(1, lines.length - 1).join(), 'CDEFGHIJK');
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll();
    await tester.pump();
    expect(selected, source);
    for (final value in [120.0, 40.0, 60.0]) {
      width.value = value;
      await settleSelection(tester);
      expect(selected, source, reason: 'width=$value');
    }
    region.contextMenuButtonItems
        .singleWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(copied, source);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);

  testWidgets('Chrome character selection retains source control positions', (
    tester,
  ) async {
    const source = 'ab CDEFGHIJK x\u2060y';
    final delegate = StaticSelectionContainerDelegate();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SelectionContainer(
            delegate: delegate,
            child: SizedBox(
              width: 60,
              child: TdsKeepAllText.from(
                const Text(
                  source,
                  style: TextStyle(
                    fontFamily: 'Ahem',
                    fontSize: 20,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleSelection(tester);
    delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
    for (var offset = source.length - 1; offset >= 0; offset--) {
      delegate.dispatchSelectionEvent(
        const GranularlyExtendSelectionEvent(
          forward: false,
          isEnd: true,
          granularity: TextGranularity.character,
        ),
      );
      expect(
        delegate.getSelection(),
        SelectedContentRange(startOffset: 0, endOffset: offset),
      );
      expect(
        delegate.getSelectedContent()!.plainText,
        source.substring(0, offset),
      );
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  }, skip: !kIsWeb);

  testWidgets('Chrome Copy keeps source text and genuine Unicode controls', (
    tester,
  ) async {
    const source = '자세한 한\u2060글 Cafe\u0301 한글 👩‍👩‍👦\n  원문';
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
    for (final rich in [false, true]) {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (content) => selected = content?.plainText,
              child: TdsKeepAllText.from(
                rich
                    ? const Text.rich(
                        TextSpan(
                          text: '자세한 ',
                          children: [
                            TextSpan(
                              text: '한\u2060글 Cafe\u0301 한글 👩‍👩‍👦\n  원문',
                            ),
                          ],
                        ),
                        style: TextStyle(fontFamily: 'Ahem'),
                      )
                    : const Text(source, style: TextStyle(fontFamily: 'Ahem')),
              ),
            ),
          ),
        ),
      );
      await settleSelection(tester);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      expect(selected, source);
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, source);
      expect(tester.takeException(), isNull);
    }
  }, skip: !kIsWeb);

  testWidgets(
    'Chrome source replacement and disabled selection release old ranges',
    (tester) async {
      String? selected;
      for (final source in ['자세한 내용을 확인하기', '새로운 본문', '']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionArea(
                onSelectionChanged: (content) => selected = content?.plainText,
                child: TdsKeepAllText.from(
                  Text(
                    source,
                    semanticsLabel: '별도의 접근성 설명',
                    style: const TextStyle(fontFamily: 'Ahem'),
                  ),
                ),
              ),
            ),
          ),
        );
        await settleSelection(tester);
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectAll();
        await tester.pump();
        expect(selected ?? '', source);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (content) => selected = content?.plainText,
              child: SelectionContainer.disabled(
                child: TdsKeepAllText.from(const Text('선택하지 않음')),
              ),
            ),
          ),
        ),
      );
      await settleSelection(tester);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll();
      await tester.pump();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );
}
