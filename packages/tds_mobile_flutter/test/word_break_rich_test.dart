import 'dart:convert';
import 'dart:io';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';

import 'interaction_test.dart' show app;

const label = '자세한 내용을 확인하기';
const nestedLabel = TextSpan(
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
);

List<String> renderedLines(RenderParagraph paragraph) {
  final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final lines = <double, StringBuffer>{};
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
      (lines[box.top] ??= StringBuffer()).write(character);
      break;
    }
  }
  return lines.values.map((line) => line.toString().trimRight()).toList();
}

Iterable<TextSpan> textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* textSpans(child);
  }
}

class _OpaqueSpan extends TextSpan {
  const _OpaqueSpan() : super(text: '하');
}

Widget emergencyHost(
  Widget child, {
  double width = 90,
  SelectionContainerDelegate? selection,
}) {
  final button = TdsTheme(
    data: const TdsThemeData(
      platform: TdsPlatform(os: TdsOS.android, fontScale: 200),
    ),
    child: SizedBox(
      width: width,
      child: TdsTextButton(size: TdsTextButtonSize.large, child: child),
    ),
  );
  return app(
    selection == null
        ? button
        : SelectionContainer(delegate: selection, child: button),
  );
}

Widget clusterLabel(String source, {required bool rich}) {
  if (!rich) return Text(source);
  final unit = source.codeUnitAt(3);
  final end = 3 + (unit >= 0xd800 && unit <= 0xdbff ? 2 : 1);
  return Text.rich(
    TextSpan(
      text: source.substring(0, 3),
      children: [
        TextSpan(
          text: source.substring(3, end),
          style: const TextStyle(color: Color(0xff3182f6)),
        ),
        TextSpan(text: source.substring(end)),
      ],
    ),
  );
}

Future<void> settleSelection(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final depth = find.byType(SelectionContainer).evaluate().length;
  for (var frame = 0; frame <= depth; frame++) {
    tester.binding.scheduleFrame();
    await tester.pump();
  }
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

  test('keep-all never injects joiners inside a grapheme cluster', () {
    const decomposed = '\u1112\u1161\u11ab\u1100\u1173\u11af';
    expect(
      tdsKeepAllText(decomposed),
      '\u1112\u1161\u11ab\u2060\u1100\u1173\u11af',
    );
    expect(tdsKeepAllText('한\u0301글'), '한\u0301\u2060글');
    expect(tdsKeepAllText('漢\ufe00字'), '漢\ufe00\u2060字');
    expect(tdsKeepAllText('漢\u{e0100}字'), '漢\u{e0100}字');
    for (final cluster in ['한\u0301', '漢\ufe00', '👩‍👩‍👦', '🇰🇷', '1️⃣']) {
      expect(tdsKeepAllText(cluster), cluster);
    }
  });

  test('keep-all retains CJK context after a single BMP mark', () {
    for (final cluster in [
      '한\u0301',
      '한\u0308',
      '한\u0323',
      '한\u302e',
      '한\ufe0f',
      '漢\ufe00',
      '\u1112\u1161\u11ab\u0301',
    ]) {
      expect(tdsKeepAllText('${cluster}ABC'), '$cluster\u2060ABC');
      expect(tdsKeepAllText('${cluster}123'), '$cluster\u2060123');
    }
  });

  test('keep-all does not generalize the single-mark lookbehind', () {
    for (final cluster in [
      '한\u0301\u0308',
      '한\ufe0f\u0301',
      '한\u{e0100}',
      '漢\u{e0100}',
      '한\u{e0100}\u0301',
    ]) {
      for (final suffix in ['ABC', '123', '글']) {
        final text = '$cluster$suffix';
        expect(tdsKeepAllText(text), text);
      }
    }
  });

  test('keep-all preserves separators and is idempotent', () {
    for (final text in [
      '',
      '한\n글\r\n다음',
      '한\t글\u00a0다음',
      'abc-def 123🙂',
      '한\u0301글',
      '\u1112\u1161\u11ab\u1100\u1173\u11af',
    ]) {
      final joined = tdsKeepAllText(text);
      expect(joined.replaceAll('\u2060', ''), text);
      expect(tdsKeepAllText(joined), joined);
    }
  });

  test(
    'decomposed Hangul retains composed glyph advances in the original font',
    () {
      for (final size in [17.0, 27.0, 34.0]) {
        double width(String text) {
          final painter = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: tdsKeepAllText(text),
              style: TextStyle(
                fontFamily: 'packages/tds_mobile_flutter/Toss Product Sans',
                fontSize: size,
                fontWeight: FontWeight.w500,
              ),
            ),
          )..layout();
          final value = painter.width;
          painter.dispose();
          return value;
        }

        expect(width('한글'), closeTo(width('한글'), .001));
      }
    },
  );

  testWidgets('graphemes stay intact across separate and empty rich spans', (
    tester,
  ) async {
    for (final parts in [
      ['\u1112', '', '\u1161', '\u11ab', '\u1100\u1173\u11af'],
      ['한', '\u0301', '', '글'],
      ['漢', '\ufe00', '字'],
      ['漢', '\u{e0100}', '字'],
    ]) {
      final original = TextSpan(
        children: [for (final part in parts) TextSpan(text: part)],
      );
      await tester.pumpWidget(app(TdsKeepAllText.from(Text.rich(original))));
      final span = tester.widget<RichText>(find.byType(RichText)).text;
      expect(
        span.toPlainText(includeSemanticsLabels: false),
        tdsKeepAllText(parts.join()),
      );
      expect(span.toPlainText(), parts.join());
      expect(original.toPlainText(), parts.join());
    }
  });

  testWidgets(
    'rich spans keep their metadata, pointer handlers and semantics',
    (tester) async {
      var taps = 0, enters = 0, exits = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => taps++;
      addTearDown(recognizer.dispose);
      void enter(PointerEnterEvent _) => enters++;
      void exit(PointerExitEvent _) => exits++;
      const style = TextStyle(
        color: Color(0xff3182f6),
        fontWeight: FontWeight.w600,
      );
      final original = TextSpan(
        text: '확인',
        children: const [TextSpan(text: '하기')],
        style: style,
        recognizer: recognizer,
        mouseCursor: SystemMouseCursors.precise,
        onEnter: enter,
        onExit: exit,
        semanticsLabel: '눌러 확인',
        semanticsIdentifier: 'rich-link',
        locale: const Locale('ko', 'KR'),
        spellOut: true,
      );
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(app(TdsKeepAllText.from(Text.rich(original))));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        final root = paragraph.text as TextSpan;
        final rewritten = textSpans(
          root,
        ).singleWhere((span) => span.semanticsIdentifier == 'rich-link');
        expect(rewritten.text, '확\u2060인');
        expect(rewritten.style, same(style));
        expect(rewritten.recognizer, same(recognizer));
        expect(rewritten.mouseCursor, original.mouseCursor);
        expect(rewritten.onEnter, same(enter));
        expect(rewritten.onExit, same(exit));
        expect(rewritten.semanticsLabel, original.semanticsLabel);
        expect(rewritten.semanticsIdentifier, original.semanticsIdentifier);
        expect(rewritten.locale, original.locale);
        expect(rewritten.spellOut, original.spellOut);
        expect(root.toPlainText(), '눌러 확인하기');
        expect(original.text, '확인');
        expect(find.bySemanticsLabel(RegExp('\u2060')), findsNothing);
        final box = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .first
            .toRect();
        final point = paragraph.localToGlobal(box.center);
        await tester.tapAt(point);
        expect(taps, 1);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        await mouse.moveTo(point);
        await tester.pump();
        await mouse.moveTo(const Offset(1, 1));
        await tester.pump();
        expect(enters, 1);
        expect(exits, 1);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('widgets and custom spans remain opaque word boundaries', (
    tester,
  ) async {
    const widget = WidgetSpan(child: SizedBox(width: 8, height: 8));
    const custom = _OpaqueSpan();
    const original = TextSpan(
      children: [
        TextSpan(text: '한'),
        widget,
        TextSpan(text: '글'),
        custom,
        TextSpan(text: '다음'),
      ],
    );
    await tester.pumpWidget(
      app(TdsKeepAllText.from(const Text.rich(original))),
    );
    final root =
        tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
    final rewritten = textSpans(
      root,
    ).singleWhere((span) => span.children?.contains(widget) ?? false);
    expect(rewritten.children![1], same(widget));
    expect(rewritten.children![3], same(custom));
    expect(
      root.toPlainText(includeSemanticsLabels: false),
      '한\ufffc글하다\u2060음',
    );
    expect(root.toPlainText(), original.toPlainText());
  });

  testWidgets(
    'unchanged spans retain identity and rebuilds do not leak context',
    (tester) async {
      const latin = TextSpan(
        text: 'ABC',
        children: [TextSpan(text: '123')],
      );
      for (final original in [
        latin,
        const TextSpan(
          text: '한',
          children: [TextSpan(text: '글')],
        ),
        latin,
      ]) {
        await tester.pumpWidget(app(TdsKeepAllText.from(Text.rich(original))));
        final root =
            tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
        if (identical(original, latin)) {
          expect(textSpans(root).any((span) => identical(span, latin)), isTrue);
        }
        expect(root.toPlainText(), original.toPlainText());
      }
    },
  );

  testWidgets('selectable rich labels retain keep-all and original semantics', (
    tester,
  ) async {
    final wrapped = TdsKeepAllText.from(const Text.rich(nestedLabel));
    await tester.pumpWidget(
      material.MaterialApp(
        home: material.Scaffold(body: material.SelectionArea(child: wrapped)),
      ),
    );
    var paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    expect(
      paragraph.text.toPlainText(includeSemanticsLabels: false),
      tdsKeepAllText(label),
    );
    expect(paragraph.text.toPlainText(), label);
    expect(identical(wrapped.source.textSpan, nestedLabel), isTrue);
    await tester.pumpWidget(app(wrapped));
    paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    expect(
      paragraph.text.toPlainText(includeSemanticsLabels: false),
      tdsKeepAllText(label),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich keep-all inherits across nested style boundaries', (
    tester,
  ) async {
    const theme = TdsThemeData(
      platform: TdsPlatform(os: TdsOS.android, fontScale: 160),
    );
    await tester.pumpWidget(
      app(
        const TdsTheme(
          data: theme,
          child: SizedBox(
            width: 130,
            child: TdsTextButton(
              size: TdsTextButtonSize.medium,
              child: Text.rich(nestedLabel),
            ),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(renderedLines(paragraph), ['자세한', '내용을', '확인하기']);
    expect(paragraph.text.toPlainText(), label);
  });

  testWidgets('original wrapping matrix includes oversized words', (
    tester,
  ) async {
    final source =
        jsonDecode(File('reference/word-break.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      tdsKeepAllText(label),
      '자\u2060세\u2060한 내\u2060용\u2060을 확\u2060인\u2060하\u2060기',
      reason: 'Plain layout input is unchanged from the previous adapter',
    );
    var matched = 0;
    for (final row in source['specimens'] as List) {
      final specimen = row as Map<String, dynamic>;
      final theme = TdsThemeData(
        platform: TdsPlatform(
          os: TdsOS.android,
          fontScale: (specimen['scale'] as num).toDouble(),
        ),
      );
      await tester.pumpWidget(
        app(
          TdsTheme(
            data: theme,
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
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final actual = renderedLines(paragraph);
      final key =
          '${specimen['size']}/${specimen['scale']}/${specimen['width']}';
      expect(actual, specimen['lines'], reason: '$key/${specimen['form']}');
      matched++;
      expect(tester.takeException(), isNull);
    }
    expect(matched, 108);
  });

  testWidgets('comparable selector boundaries preserve wrapping and copy', (
    tester,
  ) async {
    final source = jsonDecode(
      File('reference/word-break.json').readAsStringSync(),
    );
    final specimens = source['clusterBoundaries']['specimens'] as List;
    expect(specimens, hasLength(176));
    // These are retained source discrepancies, not accepted equivalence. The
    // pinned browser actually omits the suffix, including on fresh React mounts.
    final pending = specimens.where((row) => row['knownDifference'] != null);
    expect(pending, hasLength(12));
    final comparable = specimens.where((row) => row['knownDifference'] == null);
    expect(comparable, hasLength(164));
    for (final selectable in [false, true]) {
      for (final specimen in comparable) {
        final text = specimen['text'] as String;
        final delegate = selectable ? StaticSelectionContainerDelegate() : null;
        await tester.pumpWidget(
          emergencyHost(
            clusterLabel(text, rich: specimen['form'] == 'nested'),
            width: (specimen['width'] as num).toDouble(),
            selection: delegate,
          ),
        );
        await settleSelection(tester);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(
          renderedLines(paragraph),
          specimen['lines'],
          reason:
              '${specimen['width']}/${specimen['form']}/$text/selectable=$selectable',
        );
        if (delegate != null) {
          delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
          expect(delegate.getSelectedContent()!.plainText, text);
          expect(delegate.contentLength, text.length);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        delegate?.dispose();
      }
    }
  });

  testWidgets('cluster-boundary selection survives reverse ranges and reflow', (
    tester,
  ) async {
    for (final source in [
      '앞 한\ufe0fABCDEFGHIJ 뒤',
      '앞 한\u{e0100}ABCDEFGHIJ 뒤',
      '앞 한\u{e0100}\u2060ABCDEFGHIJ 뒤',
      '앞 한\u200dABCDEFGHIJ 뒤',
      '앞 한\u200cABCDEFGHIJ 뒤',
    ]) {
      for (final rich in [false, true]) {
        final width = ValueNotifier(90.0);
        final delegate = StaticSelectionContainerDelegate();
        await tester.pumpWidget(
          ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, _) => emergencyHost(
              clusterLabel(source, rich: rich),
              width: value,
              selection: delegate,
            ),
          ),
        );
        await settleSelection(tester);
        final selected = source.substring(2, source.indexOf('뒤'));
        for (final reverse in [false, true]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(RichText),
          );
          final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
          Offset caret(int offset) {
            final position = TextPosition(offset: offset);
            return paragraph.localToGlobal(
              paragraph.getOffsetForCaret(position, Rect.zero) +
                  Offset(0, paragraph.getFullHeightForCaret(position) / 2),
            );
          }

          final start = caret(raw.indexOf('한'));
          final end = caret(raw.indexOf('뒤'));
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
          expect(delegate.getSelectedContent()!.plainText, selected);
          final range = delegate.getSelection();
          for (final next in [130.0, 210.0, 90.0]) {
            width.value = next;
            await settleSelection(tester);
            expect(delegate.getSelectedContent()!.plainText, selected);
            expect(
              delegate.getSelection(),
              range,
              reason: '$source/rich=$rich/reverse=$reverse/width=$next',
            );
          }
        }
        // Character extension uses the source graphemes, not inserted joiners
        // or the extra emergency break at a normal cluster boundary.
        delegate.dispatchSelectionEvent(const SelectAllSelectionEvent());
        final boundaries = [0];
        for (final cluster in source.characters) {
          boundaries.add(boundaries.last + cluster.length);
        }
        for (final end in boundaries.reversed.skip(1)) {
          delegate.dispatchSelectionEvent(
            const GranularlyExtendSelectionEvent(
              forward: false,
              isEnd: true,
              granularity: TextGranularity.character,
            ),
          );
          expect(
            delegate.getSelection(),
            SelectedContentRange(startOffset: 0, endOffset: end),
          );
          expect(
            delegate.getSelectedContent()!.plainText,
            source.substring(0, end),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        delegate.dispose();
        width.dispose();
      }
    }
  });

  testWidgets(
    'emergency wrapping follows original mixed Korean and Latin words',
    (tester) async {
      final source = jsonDecode(
        File('reference/word-break.json').readAsStringSync(),
      );
      final cases = source['emergency']['specimens'] as List;
      for (final row in cases) {
        final text = row['text'] as String;
        for (final rich in [false, true]) {
          final split = text.indexOf(' ') + 1;
          final child = rich
              ? Text.rich(
                  TextSpan(
                    text: text.substring(0, split),
                    children: [
                      TextSpan(
                        text: text.substring(split),
                        style: const TextStyle(color: Color(0xff3182f6)),
                      ),
                    ],
                  ),
                )
              : Text(text);
          await tester.pumpWidget(
            app(
              TdsTheme(
                data: const TdsThemeData(
                  platform: TdsPlatform(os: TdsOS.android, fontScale: 200),
                ),
                child: SizedBox(
                  width: (row['width'] as num).toDouble(),
                  child: TdsTextButton(
                    size: TdsTextButtonSize.large,
                    child: child,
                  ),
                ),
              ),
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(RichText),
          );
          expect(
            renderedLines(paragraph),
            row['lines'],
            reason: '${row['width']}/$text/rich=$rich',
          );
          if (rich) expect(paragraph.text.toPlainText(), text);
          expect(tester.takeException(), isNull);
        }
      }
      expect(cases, hasLength(24));
    },
  );

  testWidgets(
    'width-only relayout restores spaces and keeps intrinsic measurements pure',
    (tester) async {
      final width = ValueNotifier<double>(90);
      addTearDown(width.dispose);
      await tester.pumpWidget(
        app(
          TdsTheme(
            data: const TdsThemeData(
              platform: TdsPlatform(os: TdsOS.android, fontScale: 200),
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              child: const TdsTextButton(
                size: TdsTextButtonSize.large,
                child: Text.rich(nestedLabel),
              ),
              builder: (context, value, child) =>
                  SizedBox(width: value, child: child),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final adapter = paragraph.parent! as RenderBox;
      final maxIntrinsic = adapter.getMaxIntrinsicWidth(double.infinity);
      for (final value in [90.0, 210.0, 130.0, 90.0, 800.0, 90.0]) {
        width.value = value;
        await tester.pump();
        expect(
          tester.renderObject<RenderParagraph>(find.byType(RichText)),
          same(paragraph),
        );
        expect(
          adapter.getDryLayout(BoxConstraints(maxWidth: value)),
          paragraph.size,
        );
        expect(adapter.getMaxIntrinsicWidth(double.infinity), maxIntrinsic);
        expect(adapter.getMinIntrinsicHeight(value), paragraph.size.height);
        if (value == 90) {
          expect(renderedLines(paragraph), ['자세', '한', '내용', '을', '확인', '하기']);
        } else if (value == 800) {
          expect(renderedLines(paragraph), [label]);
          expect(
            paragraph.text.toPlainText(includeSemanticsLabels: false),
            isNot(contains('\n')),
          );
        }
        expect(paragraph.text.toPlainText(), label);
        expect(tester.takeException(), isNull);
      }
      // Dry measurements at other widths must not rewrite the live paragraph.
      final rendered = paragraph.text;
      adapter.getDryLayout(const BoxConstraints(maxWidth: 800));
      adapter.getDryBaseline(
        const BoxConstraints(maxWidth: 210),
        TextBaseline.alphabetic,
      );
      expect(paragraph.text, same(rendered));
    },
  );

  testWidgets(
    'emergency splits keep link targets and original accessibility text',
    (tester) async {
      var taps = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => taps++;
      addTearDown(recognizer.dispose);
      final link = TextSpan(
        text: '내용을',
        recognizer: recognizer,
        semanticsIdentifier: 'emergency-link',
        style: const TextStyle(color: Color(0xff3182f6)),
      );
      final original = TextSpan(
        text: '자세한 ',
        children: [
          link,
          const TextSpan(text: ' 확인하기'),
        ],
      );
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(emergencyHost(Text.rich(original)));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(renderedLines(paragraph), ['자세', '한', '내용', '을', '확인', '하기']);
        expect(paragraph.text.toPlainText(), label);
        expect(original.text, '자세한 ');
        expect(link.text, '내용을');
        final liveLink = textSpans(
          paragraph.text,
        ).singleWhere((span) => span.semanticsIdentifier == 'emergency-link');
        expect(liveLink.recognizer, same(recognizer));
        expect(liveLink.style, same(link.style));
        final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
        final offset = raw.indexOf('내');
        final target = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: offset + 1),
            )
            .single
            .toRect();
        await tester.tapAt(paragraph.localToGlobal(target.center));
        expect(taps, 1);
        expect(find.bySemanticsLabel(RegExp('\u2060')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'nowrap, justified text and non-dry inline widgets keep their native path',
    (tester) async {
      for (final text in [
        const Text(label, softWrap: false),
        const Text(label, textAlign: TextAlign.justify),
        Text.rich(
          TextSpan(
            text: '$label ',
            children: [
              WidgetSpan(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      const SizedBox(width: 8, height: 8),
                ),
              ),
            ],
          ),
        ),
      ]) {
        await tester.pumpWidget(emergencyHost(text));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(
          paragraph.text.toPlainText(includeSemanticsLabels: false),
          isNot(contains('\n')),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('emergency splits never separate combining graphemes', (
    tester,
  ) async {
    for (final value in [
      '\u1112\u1161\u11ab\u1100\u1173\u11af',
      'e\u0301e\u0301',
      '漢\u{e0100}字',
    ]) {
      await tester.pumpWidget(
        emergencyHost(Text.rich(TextSpan(text: value)), width: 1),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final layout = paragraph.text
          .toPlainText(includeSemanticsLabels: false)
          .replaceAll('\u2060', '');
      expect(layout.split('\n'), value.characters.toList());
      expect(paragraph.text.toPlainText(), value);
      expect(tester.takeException(), isNull);
    }
  });
}
