import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';

import 'interaction_test.dart' show app;
import 'word_break_rich_test.dart' show renderedLines;

const _label = '자세한 내용을 확인하기';

Future<void> _settleRegistrars(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Each nested registrar can enqueue another post-frame callback from an
  // idle microtask, without requesting a new frame itself.
  final depth = find.byType(SelectionContainer).evaluate().length;
  for (var frame = 0; frame < depth; frame++) {
    tester.binding.scheduleFrame();
    await tester.pump();
  }
}

Offset _caretPoint(RenderParagraph paragraph, int offset) {
  final position = TextPosition(offset: offset);
  return paragraph.localToGlobal(
    paragraph.getOffsetForCaret(position, Rect.zero) +
        Offset(0, paragraph.getFullHeightForCaret(position) / 2),
  );
}

class _CustomSpan extends TextSpan {
  const _CustomSpan() : super(text: '한글');
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/tds_mobile_flutter/Toss Product Sans');
    for (final weight in [400, 500, 600, 700]) {
      loader.addFont(
        rootBundle.load(
          'packages/tds_mobile_flutter/assets/fonts/TossProductSans-$weight.ttf',
        ),
      );
    }
    await loader.load();
  });
  testWidgets('plain keep-all selection copies the original source', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: TdsKeepAllText.from(const Text(_label)),
        ),
      ),
    );
    await _settleRegistrars(tester);
    delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
    await tester.pump();
    expect(delegate.getSelectedContent()!.plainText, _label);
    expect(delegate.contentLength, _label.length);
    expect(
      delegate.getSelection(),
      const SelectedContentRange(startOffset: 0, endOffset: _label.length),
    );
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  });

  testWidgets('rich keep-all remains active while selection copies source', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: TdsKeepAllText.from(
            const Text.rich(
              TextSpan(
                text: '자세한 ',
                children: [
                  TextSpan(
                    text: '내용을 확인하기',
                    style: TextStyle(color: Color(0xff3182f6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _settleRegistrars(tester);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(
      paragraph.text.toPlainText(includeSemanticsLabels: false),
      tdsKeepAllText(_label),
    );
    delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
    await tester.pump();
    expect(delegate.getSelectedContent()!.plainText, _label);
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  });

  testWidgets('native Copy action does not put layout joiners on clipboard', (
    tester,
  ) async {
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
      material.MaterialApp(
        home: material.Scaffold(
          body: material.SelectionArea(
            child: TdsKeepAllText.from(const Text(_label)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll();
    await tester.pump();
    region.contextMenuButtonItems
        .singleWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(copied, _label);
  });

  testWidgets(
    'partial and reversed selections expose original UTF-16 offsets',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: SizedBox(
              width: 130,
              child: TdsKeepAllText.from(
                const Text(
                  _label,
                  style: TextStyle(
                    fontFamily: 'packages/tds_mobile_flutter/Toss Product Sans',
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    height: 1.252,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settleRegistrars(tester);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      expect(renderedLines(paragraph), ['자세한', '내용을', '확인하기']);
      final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final start = _caretPoint(paragraph, raw.indexOf('내'));
      final end = _caretPoint(paragraph, raw.indexOf('을') + 1);
      for (final reverse in [false, true]) {
        delegate.dispatchSelectionEvent(const ClearSelectionEvent());
        delegate.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forStart(
            globalPosition: reverse ? end : start,
          ),
        );
        delegate.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(
            globalPosition: reverse ? start : end,
          ),
        );
        await tester.pump();
        expect(delegate.getSelectedContent()!.plainText, '내용을');
        expect(
          delegate.getSelection(),
          SelectedContentRange(
            startOffset: reverse ? 7 : 4,
            endOffset: reverse ? 4 : 7,
          ),
        );
        expect(delegate.value.selectionRects, isNotEmpty);
      }
      delegate.dispatchSelectionEvent(const ClearSelectionEvent());
      expect(delegate.getSelectedContent(), isNull);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets(
    'copy retains genuine joiners, graphemes, whitespace and source text',
    (tester) async {
      const source = '漢\u{e0100}字 Cafe\u0301 한글 👩‍👩‍👦 한\u2060글\n  원문\n';
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: TdsKeepAllText.from(
              const Text(source, semanticsLabel: '다른 접근성 설명'),
            ),
          ),
        ),
      );
      await _settleRegistrars(tester);
      delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
      await tester.pump();
      expect(delegate.getSelectedContent()!.plainText, source);
      expect(delegate.contentLength, source.length);
      expect(delegate.getSelection()!.endOffset, source.length);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets('multiple selected labels compose original lengths and ranges', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TdsKeepAllText.from(const Text('첫번째 ')),
              TdsKeepAllText.from(
                const Text.rich(
                  TextSpan(
                    text: '두',
                    children: [TextSpan(text: '번째')],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _settleRegistrars(tester);
    delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
    await tester.pump();
    expect(delegate.getSelectedContent()!.plainText, '첫번째 두번째');
    expect(delegate.contentLength, 7);
    expect(
      delegate.getSelection(),
      const SelectedContentRange(startOffset: 0, endOffset: 7),
    );
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  });

  testWidgets(
    'replacement, empty text and selection scope changes dispose cleanly',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      for (final source in [_label, '새로운 내용', '', '한글']) {
        await tester.pumpWidget(
          app(
            SelectionContainer(
              delegate: delegate,
              child: TdsKeepAllText.from(Text(source)),
            ),
          ),
        );
        await _settleRegistrars(tester);
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
        await tester.pump();
        expect(delegate.getSelectedContent()?.plainText ?? '', source);
        expect(delegate.contentLength, source.length);
      }
      await tester.pumpWidget(
        app(
          SelectionContainer.disabled(
            child: TdsKeepAllText.from(const Text(_label)),
          ),
        ),
      );
      await _settleRegistrars(tester);
      expect(delegate.selectables, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets(
    'selectable opaque spans bypass text rewriting and copy unchanged',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      for (final (source, expected) in <(Text, String)>[
        (
          const Text.rich(
            TextSpan(
              children: [
                _CustomSpan(),
                TextSpan(text: ' 원문'),
              ],
            ),
          ),
          '한글 원문',
        ),
        (
          const Text.rich(
            TextSpan(
              text: '한글 ',
              children: [
                WidgetSpan(child: Text('가운데')),
                TextSpan(text: ' 원문'),
              ],
            ),
          ),
          '한글 가운데 원문',
        ),
      ]) {
        await tester.pumpWidget(
          app(
            SelectionContainer(
              delegate: delegate,
              child: TdsKeepAllText.from(source),
            ),
          ),
        );
        await _settleRegistrars(tester);
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
        await tester.pump();
        expect(delegate.getSelectedContent()!.plainText, expected);
      }
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets('selectable rich links retain activation and word selection', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    var clicks = 0;
    final recognizer = TapGestureRecognizer()..onTap = () => clicks++;
    addTearDown(recognizer.dispose);
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: TdsKeepAllText.from(
            Text.rich(
              TextSpan(
                text: '자세한 ',
                children: [
                  TextSpan(text: '내용을', recognizer: recognizer),
                  const TextSpan(text: ' 확인하기'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _settleRegistrars(tester);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(
            baseOffset: raw.indexOf('용'),
            extentOffset: raw.indexOf('용') + 1,
          ),
        )
        .first;
    final point = paragraph.localToGlobal(box.toRect().center);
    await tester.tapAt(point);
    expect(clicks, 1);
    delegate.dispatchSelectionEvent(
      SelectWordSelectionEvent(globalPosition: point),
    );
    await tester.pump();
    expect(delegate.getSelectedContent()!.plainText, '내용을');
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  });
}
