import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';

import 'interaction_test.dart' show app;
import 'word_break_rich_test.dart' show label, nestedLabel, renderedLines;

const _label = '한글 LatinTextCombined 다음';
const _style = TextStyle(
  fontFamily: 'Toss Product Sans',
  package: 'tds_mobile_flutter',
  fontSize: 40,
  fontWeight: FontWeight.w600,
  height: 1.4,
);

Widget _text(String source, {bool rich = false}) => TdsKeepAllText.from(
  rich
      ? Text.rich(
          TextSpan(
            text: source.substring(0, 2),
            children: [
              TextSpan(
                text: source.substring(2),
                style: const TextStyle(color: Color(0xff3182f6)),
              ),
            ],
          ),
          style: _style,
        )
      : Text(source, style: _style),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final depth = find.byType(SelectionContainer).evaluate().length;
  for (var frame = 0; frame <= depth; frame++) {
    tester.binding.scheduleFrame();
    await tester.pump();
  }
}

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText));

Offset _caret(RenderParagraph paragraph, int offset) {
  final position = TextPosition(offset: offset);
  return paragraph.localToGlobal(
    paragraph.getOffsetForCaret(position, Rect.zero) +
        Offset(0, paragraph.getFullHeightForCaret(position) / 2),
  );
}

Offset _character(RenderParagraph paragraph, String character) {
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final offset = raw.indexOf(character);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(
          baseOffset: offset,
          extentOffset: offset + character.length,
        ),
      )
      .first;
  return paragraph.localToGlobal(box.toRect().center);
}

void _selectLatin(
  WidgetTester tester,
  SelectionContainerDelegate delegate, {
  bool reverse = false,
}) {
  final paragraph = _paragraph(tester);
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final start = _caret(paragraph, raw.indexOf('L'));
  final end = _caret(paragraph, raw.indexOf('다'));
  delegate.dispatchSelectionEvent(const ClearSelectionEvent());
  delegate.dispatchSelectionEvent(
    SelectionEdgeUpdateEvent.forStart(globalPosition: reverse ? end : start),
  );
  delegate.dispatchSelectionEvent(
    SelectionEdgeUpdateEvent.forEnd(globalPosition: reverse ? start : end),
  );
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/tds_mobile_flutter/Toss Product Sans');
    for (final weight in [400, 600]) {
      loader.addFont(
        rootBundle.load(
          'packages/tds_mobile_flutter/assets/fonts/TossProductSans-$weight.ttf',
        ),
      );
    }
    await loader.load();
  });

  testWidgets('selectable labels match the entire original wrapping matrix', (
    tester,
  ) async {
    final reference = jsonDecode(
      File('reference/word-break.json').readAsStringSync(),
    );
    final specimens = reference['specimens'] as List;
    for (final specimen in specimens) {
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          TdsTheme(
            data: TdsThemeData(
              platform: TdsPlatform(
                os: TdsOS.android,
                fontScale: (specimen['scale'] as num).toDouble(),
              ),
            ),
            child: SelectionContainer(
              delegate: delegate,
              child: SizedBox(
                width: (specimen['width'] as num).toDouble(),
                child: TdsTextButton(
                  size: TdsTextButtonSize.values.byName(
                    specimen['size'] as String,
                  ),
                  child: specimen['form'] == 'plain'
                      ? const Text(label)
                      : const Text.rich(nestedLabel),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        renderedLines(_paragraph(tester)),
        specimen['lines'],
        reason:
            '${specimen['size']}/${specimen['scale']}/${specimen['width']}/${specimen['form']}',
      );
      delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
      expect(delegate.getSelectedContent()!.plainText, label);
      expect(delegate.contentLength, label.length);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    }
    expect(specimens, hasLength(108));
  });

  testWidgets('selectable mixed-language specimens retain original copy text', (
    tester,
  ) async {
    final reference = jsonDecode(
      File('reference/word-break.json').readAsStringSync(),
    );
    final specimens = reference['emergency']['specimens'] as List;
    for (final specimen in specimens) {
      final source = specimen['text'] as String;
      for (final rich in [false, true]) {
        final delegate = StaticSelectionContainerDelegate();
        await tester.pumpWidget(
          app(
            SelectionContainer(
              delegate: delegate,
              child: SizedBox(
                width: (specimen['width'] as num).toDouble(),
                child: _text(source, rich: rich),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(
          renderedLines(_paragraph(tester)),
          specimen['lines'],
          reason: '${specimen['width']}/$source/rich=$rich',
        );
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
        expect(delegate.getSelectedContent()!.plainText, source);
        expect(delegate.contentLength, source.length);
        await tester.pumpWidget(const SizedBox());
        delegate.dispose();
      }
    }
    expect(specimens, hasLength(24));
  });

  testWidgets(
    'selectable emergency lines match the original without copying breaks',
    (tester) async {
      const specimens = [
        ('자세한 내용을 확인하기', 90.0, ['자세', '한', '내용', '을', '확인', '하기']),
        (_label, 90.0, ['한글', 'Lati', 'nTex', 'tCo', 'mbi', 'ned', '다음']),
        (
          _label,
          60.0,
          ['한', '글', 'La', 'tin', 'Te', 'xt', 'Co', 'mb', 'ine', 'd', '다', '음'],
        ),
      ];
      for (final rich in [false, true]) {
        for (final (source, width, lines) in specimens) {
          final delegate = StaticSelectionContainerDelegate();
          await tester.pumpWidget(
            app(
              SelectionContainer(
                delegate: delegate,
                child: SizedBox(
                  width: width,
                  child: _text(source, rich: rich),
                ),
              ),
            ),
          );
          await _settle(tester);
          expect(
            renderedLines(_paragraph(tester)),
            lines,
            reason: 'width=$width rich=$rich',
          );
          delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
          await tester.pump();
          expect(delegate.getSelectedContent()!.plainText, source);
          expect(
            delegate.getSelection(),
            SelectedContentRange(startOffset: 0, endOffset: source.length),
          );
          expect(delegate.contentLength, source.length);
          await tester.pumpWidget(const SizedBox());
          delegate.dispose();
        }
      }
    },
  );

  testWidgets('partial emergency selection maps forward and reverse ranges', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: SizedBox(width: 90, child: _text(_label, rich: true)),
        ),
      ),
    );
    await _settle(tester);
    for (final reverse in [false, true]) {
      _selectLatin(tester, delegate, reverse: reverse);
      await tester.pump();
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined ');
      expect(
        delegate.getSelection(),
        SelectedContentRange(
          startOffset: reverse ? _label.indexOf('다') : _label.indexOf('L'),
          endOffset: reverse ? _label.indexOf('L') : _label.indexOf('다'),
        ),
      );
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  });

  testWidgets('width-only reflow preserves source selection and reversals', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    final width = ValueNotifier(90.0);
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            child: _text(_label, rich: true),
            builder: (context, value, child) =>
                SizedBox(width: value, child: child),
          ),
        ),
      ),
    );
    await _settle(tester);
    for (final reverse in [false, true]) {
      _selectLatin(tester, delegate, reverse: reverse);
      await tester.pump();
      final selection = delegate.getSelection();
      for (final next in [210.0, 60.0, 90.0]) {
        width.value = next;
        await _settle(tester);
        expect(
          delegate.getSelectedContent()?.plainText,
          'LatinTextCombined ',
          reason: 'width=$next reverse=$reverse',
        );
        expect(delegate.getSelection(), selection);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    width.dispose();
  });

  testWidgets('equivalent rebuilt text preserves selection during reflow', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    final width = ValueNotifier(90.0);
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, child) =>
                SizedBox(width: value, child: _text(_label, rich: true)),
          ),
        ),
      ),
    );
    await _settle(tester);
    _selectLatin(tester, delegate);
    await tester.pumpAndSettle();
    final expected = delegate.getSelection();
    for (final value in [60.0, 240.0, 90.0]) {
      width.value = value;
      await _settle(tester);
      expect(delegate.getSelection(), expected, reason: 'width=$value');
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined ');
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    width.dispose();
  });

  testWidgets('inherited font updates retain the original selection range', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    final style = ValueNotifier(_style);
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: ValueListenableBuilder<TextStyle>(
            valueListenable: style,
            child: TdsKeepAllText.from(const Text(_label)),
            builder: (context, value, child) => DefaultTextStyle(
              style: value,
              child: SizedBox(width: 90, child: child),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    _selectLatin(tester, delegate, reverse: true);
    await tester.pumpAndSettle();
    final expected = delegate.getSelection();
    for (final size in [32.0, 48.0, 40.0]) {
      style.value = _style.copyWith(
        fontSize: size,
        color: const Color(0xff3182f6),
      );
      await _settle(tester);
      expect(delegate.getSelection(), expected, reason: 'fontSize=$size');
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined ');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    style.dispose();
  });

  testWidgets('clear cancels pending restoration after a rebuilt label', (
    tester,
  ) async {
    for (final rich in [false, true]) {
      final delegate = StaticSelectionContainerDelegate();
      final width = ValueNotifier(90.0);
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (context, value, child) => SizedBox(
                width: value,
                child: _text(_label, rich: rich),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      for (final reverse in [false, true]) {
        for (final next in [60.0, 240.0, 90.0]) {
          _selectLatin(tester, delegate, reverse: reverse);
          tester.binding.addPostFrameCallback((_) {
            delegate.dispatchSelectionEvent(const ClearSelectionEvent());
            expect(delegate.contentLength, _label.length);
          });
          width.value = next;
          await _settle(tester);
          expect(delegate.getSelection(), isNull);
          expect(delegate.getSelectedContent(), isNull);
          expect(delegate.value.status, SelectionStatus.none);
          expect(tester.takeException(), isNull);
          delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
          await tester.pump();
          expect(delegate.getSelectedContent()!.plainText, _label);
        }
      }
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
      width.dispose();
    }
  });

  testWidgets(
    'select all replaces pending restoration during a rebuilt label',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      final width = ValueNotifier(90.0);
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (context, value, child) =>
                  SizedBox(width: value, child: _text(_label, rich: true)),
            ),
          ),
        ),
      );
      await _settle(tester);
      _selectLatin(tester, delegate);
      tester.binding.addPostFrameCallback((_) {
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
      });
      width.value = 60;
      await _settle(tester);
      expect(delegate.getSelectedContent()?.plainText, _label);
      expect(
        delegate.getSelection(),
        const SelectedContentRange(startOffset: 0, endOffset: _label.length),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
      width.dispose();
    },
  );

  testWidgets(
    'queued character events keep input order and clear cancels them',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      final width = ValueNotifier(90.0);
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (context, value, child) =>
                  SizedBox(width: value, child: _text(_label)),
            ),
          ),
        ),
      );
      await _settle(tester);
      for (final reverse in [false, true]) {
        _selectLatin(tester, delegate, reverse: reverse);
        tester.binding.addPostFrameCallback((_) {
          for (final forward in [false, false, true]) {
            delegate.dispatchSelectionEvent(
              GranularlyExtendSelectionEvent(
                forward: forward,
                isEnd: !reverse,
                granularity: TextGranularity.character,
              ),
            );
          }
        });
        width.value = reverse ? 90 : 60;
        await tester.pumpAndSettle();
        expect(delegate.getSelectedContent()?.plainText, 'LatinTextCombined');
        expect(
          delegate.getSelection(),
          SelectedContentRange(
            startOffset: reverse ? 20 : 3,
            endOffset: reverse ? 3 : 20,
          ),
        );
      }
      tester.binding.addPostFrameCallback((_) {
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
        delegate.dispatchSelectionEvent(
          const GranularlyExtendSelectionEvent(
            forward: false,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
        delegate.dispatchSelectionEvent(const ClearSelectionEvent());
      });
      width.value = 60;
      await tester.pumpAndSettle();
      expect(delegate.getSelection(), isNull);
      expect(delegate.getSelectedContent(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
      width.dispose();
    },
  );

  testWidgets('deferred word and character input keeps order until cleared', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    final width = ValueNotifier(90.0);
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, child) =>
                SizedBox(width: value, child: _text(_label, rich: true)),
          ),
        ),
      ),
    );
    await _settle(tester);
    for (final clear in [false, true]) {
      _selectLatin(tester, delegate);
      tester.binding.addPostFrameCallback((_) {
        delegate.dispatchSelectionEvent(
          SelectWordSelectionEvent(
            globalPosition: _character(_paragraph(tester), 'C'),
          ),
        );
        delegate.dispatchSelectionEvent(
          const GranularlyExtendSelectionEvent(
            forward: false,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
        if (clear) {
          delegate.dispatchSelectionEvent(const ClearSelectionEvent());
        }
      });
      width.value = clear ? 90 : 60;
      await tester.pumpAndSettle();
      expect(
        delegate.getSelectedContent()?.plainText,
        clear ? isNull : 'LatinTextCombine',
      );
      expect(
        delegate.getSelection(),
        clear
            ? isNull
            : const SelectedContentRange(startOffset: 3, endOffset: 19),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    width.dispose();
  });

  testWidgets(
    'reflow restores a live selection without manually scheduled frames',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      final width = ValueNotifier(90.0);
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              child: _text(_label),
              builder: (context, value, child) =>
                  SizedBox(width: value, child: child),
            ),
          ),
        ),
      );
      await _settle(tester);
      _selectLatin(tester, delegate);
      await tester.pumpAndSettle();
      final expected = delegate.getSelection();
      for (final value in [60.0, 240.0, 90.0]) {
        width.value = value;
        await tester.pumpAndSettle();
        expect(delegate.getSelection(), expected, reason: 'width=$value');
        expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined ');
        expect(delegate.value.status, SelectionStatus.uncollapsed);
        expect(delegate.value.selectionRects, isNotEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
      width.dispose();
    },
  );

  testWidgets(
    'word and paragraph selection ignore emergency layout separators',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: SizedBox(width: 60, child: _text(_label)),
          ),
        ),
      );
      await _settle(tester);
      final point = _character(_paragraph(tester), 'T');
      delegate.dispatchSelectionEvent(
        SelectWordSelectionEvent(globalPosition: point),
      );
      await tester.pump();
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined');
      delegate.dispatchSelectionEvent(const ClearSelectionEvent());
      delegate.dispatchSelectionEvent(
        SelectParagraphSelectionEvent(globalPosition: point),
      );
      await tester.pump();
      expect(delegate.getSelectedContent()!.plainText, _label);
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets(
    'character extension crosses layout breaks without extra keystrokes',
    (tester) async {
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: SizedBox(width: 60, child: _text(_label)),
          ),
        ),
      );
      await _settle(tester);
      final paragraph = _paragraph(tester);
      final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final point = _caret(paragraph, raw.indexOf('L'));
      delegate.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forStart(globalPosition: point),
      );
      delegate.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(globalPosition: point),
      );
      const word = 'LatinTextCombined';
      for (var length = 1; length <= word.length; length++) {
        delegate.dispatchSelectionEvent(
          const GranularlyExtendSelectionEvent(
            forward: true,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
        await tester.pump();
        expect(
          delegate.getSelectedContent()?.plainText,
          word.substring(0, length),
        );
      }
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets('word dragging keeps the entire source word when reversing', (
    tester,
  ) async {
    final delegate = StaticSelectionContainerDelegate();
    await tester.pumpWidget(
      app(
        SelectionContainer(
          delegate: delegate,
          child: SizedBox(width: 90, child: _text(_label, rich: true)),
        ),
      ),
    );
    await _settle(tester);
    final paragraph = _paragraph(tester);
    delegate.dispatchSelectionEvent(
      SelectWordSelectionEvent(globalPosition: _character(paragraph, 'C')),
    );
    expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined');
    for (final character in ['b', 'T', 'i']) {
      delegate.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(
          globalPosition: _character(paragraph, character),
          granularity: TextGranularity.word,
        ),
      );
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined');
    }
    delegate.dispatchSelectionEvent(
      SelectionEdgeUpdateEvent.forEnd(
        globalPosition: _character(paragraph, '한'),
        granularity: TextGranularity.word,
      ),
    );
    expect(delegate.getSelectedContent()!.plainText, '한글 LatinTextCombined');
    expect(
      delegate.getSelection(),
      const SelectedContentRange(startOffset: 20, endOffset: 0),
    );
    delegate.dispatchSelectionEvent(
      SelectionEdgeUpdateEvent.forEnd(
        globalPosition: _character(paragraph, '음'),
        granularity: TextGranularity.word,
      ),
    );
    expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined 다음');
    expect(
      delegate.getSelection(),
      const SelectedContentRange(startOffset: 3, endOffset: _label.length),
    );
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
  });

  testWidgets(
    'character extension preserves zero-width source controls and graphemes',
    (tester) async {
      const source = 'Cafe\u0301 한\u2060글 한\n👩‍👩‍👦 끝';
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: SizedBox(width: 90, child: _text(source, rich: true)),
          ),
        ),
      );
      await _settle(tester);
      final boundaries = [0];
      for (final cluster in source.characters) {
        boundaries.add(boundaries.last + cluster.length);
      }
      for (final forward in [false, true]) {
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
        if (forward) {
          delegate.dispatchSelectionEvent(
            const GranularlyExtendSelectionEvent(
              forward: false,
              isEnd: true,
              granularity: TextGranularity.document,
            ),
          );
        }
        final targets = forward
            ? boundaries.skip(1)
            : boundaries.reversed.skip(1);
        for (final offset in targets) {
          delegate.dispatchSelectionEvent(
            GranularlyExtendSelectionEvent(
              forward: forward,
              isEnd: true,
              granularity: TextGranularity.character,
            ),
          );
          expect(
            delegate.getSelection(),
            SelectedContentRange(startOffset: 0, endOffset: offset),
            reason: 'forward=$forward offset=$offset',
          );
          expect(
            delegate.getSelectedContent()!.plainText,
            source.substring(0, offset),
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );

  testWidgets('SelectionArea long press keeps the source word through reflow', (
    tester,
  ) async {
    final width = ValueNotifier(90.0);
    final focus = FocusNode();
    String? selected;
    await tester.pumpWidget(
      material.MaterialApp(
        home: material.Scaffold(
          body: material.SelectionArea(
            focusNode: focus,
            onSelectionChanged: (value) => selected = value?.plainText,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              child: _text(_label, rich: true),
              builder: (context, value, child) =>
                  SizedBox(width: value, child: child),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.longPressAt(_character(_paragraph(tester), 'C'));
    await _settle(tester);
    expect(selected, 'LatinTextCombined');
    for (final value in [60.0, 240.0, 90.0]) {
      width.value = value;
      await _settle(tester);
      expect(selected, 'LatinTextCombined', reason: 'width=$value');
    }
    await tester.pumpWidget(const SizedBox());
    width.dispose();
    focus.dispose();
  });

  testWidgets(
    'paragraph dragging ignores inserted newlines but keeps real ones',
    (tester) async {
      const source = '첫줄\nLatinTextCombined 끝';
      final delegate = StaticSelectionContainerDelegate();
      await tester.pumpWidget(
        app(
          SelectionContainer(
            delegate: delegate,
            child: SizedBox(width: 90, child: _text(source)),
          ),
        ),
      );
      await _settle(tester);
      final paragraph = _paragraph(tester);
      delegate.dispatchSelectionEvent(
        SelectParagraphSelectionEvent(
          globalPosition: _character(paragraph, 'C'),
        ),
      );
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined 끝');
      delegate.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(
          globalPosition: _character(paragraph, 'T'),
          granularity: TextGranularity.paragraph,
        ),
      );
      expect(delegate.getSelectedContent()!.plainText, 'LatinTextCombined 끝');
      delegate.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(
          globalPosition: _character(paragraph, '첫'),
          granularity: TextGranularity.paragraph,
        ),
      );
      expect(delegate.getSelectedContent()!.plainText, source);
      expect(
        delegate.getSelection(),
        const SelectedContentRange(startOffset: source.length, endOffset: 0),
      );
      await tester.pumpWidget(const SizedBox());
      delegate.dispose();
    },
  );
}
