import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/paragraph_scope.dart';
import 'package:tds_mobile_flutter/src/foundation/touch_inset.dart';
import 'package:tds_mobile_flutter/src/foundation/text_underline.dart';
import 'package:tds_mobile_flutter/src/foundation/word_break.dart';
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
import 'interaction_test.dart' show app;
import 'checkable_motion_test.dart' show RecordingHaptic;

Color ink(WidgetTester tester) =>
    tester.widget<RichText>(find.byType(RichText)).text.style!.color!;
AnimatedScale motion(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale));

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

  testWidgets(
    'Korean keep-all wraps whole words, oversized words and trailing arrows like original',
    (tester) async {
      const theme = TdsThemeData(
        platform: TdsPlatform(os: TdsOS.android, fontScale: 160),
      );
      const lines = [2, 2, 3, 4, 4, 4];
      for (final size in TdsTextButtonSize.values) {
        await tester.pumpWidget(
          app(
            TdsTheme(
              data: theme,
              child: SizedBox(
                width: 130,
                child: TdsTextButton(
                  size: size,
                  variant: TdsTextButtonVariant.arrow,
                  arrowPlacement: TdsArrowPlacement.inline,
                  child: const Text('자세한 내용을 확인하기'),
                ),
              ),
            ),
          ),
        );
        final lineHeight =
            (theme.platform.size(size.typography) * 1.252 * 64).floor() / 64;
        expect(
          tester.getSize(find.byType(TdsTextButton)).height,
          closeTo(lines[size.index] * lineHeight, .001),
          reason: size.name,
        );
        final text = tester.widget<RichText>(find.byType(RichText));
        expect(text.text.toPlainText(), contains('\u2060'));
        expect(find.text('자세한 내용을 확인하기'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('자세한 내용을 확인하기'), findsOneWidget);
        semantics.dispose();
      }
    },
  );

  test(
    'keep-all preserves punctuation, spaces, emoji and original string identity without CJK',
    () {
      expect(tdsKeepAllText('abc-def 123\n🙂'), 'abc-def 123\n🙂');
      expect(tdsKeepAllText('한글, 다음!'), '한\u2060글, 다\u2060음!');
      expect(tdsKeepAllText('한A2글'), '한\u2060A2\u2060글');
    },
  );

  testWidgets(
    'uniform underlines use source under-edge and CSS auto thickness without layout growth',
    (tester) async {
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final size in TdsTextButtonSize.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: TdsTextButton(
                        size: size,
                        variant: TdsTextButtonVariant.underline,
                        child: const Text('확인하기'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final elements = find.byType(TdsTextUnderline).evaluate().toList();
      const tops = [40, 82, 128, 177, 227, 287];
      const thicknesses = [1, 1, 1, 2, 2, 2];
      for (var i = 0; i < elements.length; i++) {
        final render = elements[i].renderObject! as RenderTdsTextUnderline;
        expect(render.underlineRects, hasLength(1));
        final rect = render.underlineRects.single.shift(
          render.localToGlobal(Offset.zero),
        );
        expect(rect.top.floor(), tops[i]);
        expect(rect.height, thicknesses[i]);
      }
    },
  );

  testWidgets('underlines keep empty lines in their original CSS line index', (
    tester,
  ) async {
    for (final scale in [100.0, 160.0, 200.0]) {
      final theme = TdsThemeData(
        platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
      );
      for (final size in TdsTextButtonSize.values) {
        for (final leading in [false, true]) {
          await tester.pumpWidget(
            app(
              TdsTheme(
                data: theme,
                child: TdsTextButton(
                  size: size,
                  variant: TdsTextButtonVariant.underline,
                  child: Text('${leading ? '\n' : ''}토스 Ag\n\n끝 gyp'),
                ),
              ),
            ),
          );
          final render = tester.renderObject<RenderTdsTextUnderline>(
            find.byType(TdsTextUnderline),
          );
          final box = tester.renderObject<RenderBox>(find.byType(TdsLineBox));
          final fontSize = theme.platform.size(size.typography);
          final lineHeight = tdsCssLineHeight(fontSize * 1.252);
          final offset = render.localToGlobal(Offset.zero, ancestor: box);
          final rects = render.underlineRects;
          expect(rects, hasLength(2));
          // Original TextButton with two BRs has baselines at CSS line 0/2,
          // or 1/3 with a leading BR. Literal source newlines collapse.
          for (var i = 0; i < rects.length; i++) {
            final line = i * 2 + (leading ? 1 : 0);
            expect(
              rects[i].top + offset.dy,
              closeTo(
                tdsCssTextBaseline(fontSize, lineHeight) +
                    line * lineHeight +
                    fontSize * 534 / 2564 +
                    1,
                .001,
              ),
              reason: '${size.name}/$scale/leading=$leading/line=$line',
            );
          }
        }
      }
    }
  });

  testWidgets(
    'ellipsized labels preserve their native visible underline boxes',
    (tester) async {
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 120,
            child: TdsTextButton(
              size: TdsTextButtonSize.medium,
              variant: TdsTextButtonVariant.underline,
              child: Text(
                '토스 글자를 여러 줄로 확인하고 마지막 생략 부호도 확인해요',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textAlign: paragraph.textAlign,
        textScaler: paragraph.textScaler,
        maxLines: paragraph.maxLines,
        ellipsis: '\u2026',
      )..layout(maxWidth: 120);
      addTearDown(painter.dispose);
      expect(painter.didExceedMaxLines, isTrue);
      final render = tester.renderObject<RenderTdsTextUnderline>(
        find.byType(TdsTextUnderline),
      );
      final rects = render.underlineRects;
      final boxes = painter.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text
              .toPlainText(includeSemanticsLabels: false)
              .length,
        ),
      );
      expect(rects, hasLength(2));
      // LineMetrics.width and range boxes differ for trailing blanks/ellipsis.
      // This change must preserve the existing range geometry, not replace it.
      expect(
        rects.last.width,
        closeTo(boxes.last.right - boxes.last.left, .001),
      );
    },
  );

  testWidgets('blank-only and trailing lines paint no extra underlines', (
    tester,
  ) async {
    for (final entry in {
      '': 0,
      '\n\n': 0,
      '토스 Ag\n\n': 1,
      '\n\n토스 Ag\n\n끝 gyp\n': 2,
    }.entries) {
      await tester.pumpWidget(
        app(
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            variant: TdsTextButtonVariant.underline,
            child: Text(entry.key),
          ),
        ),
      );
      final render = tester.renderObject<RenderTdsTextUnderline>(
        find.byType(TdsTextUnderline),
      );
      expect(render.underlineRects, hasLength(entry.value));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty newline boxes never extend centered or RTL underlines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      const label = '\n토스 Ag\n\n끝 gyp';
      for (final direction in TextDirection.values) {
        for (final align in [
          TextAlign.start,
          TextAlign.center,
          TextAlign.right,
        ]) {
          await tester.pumpWidget(
            app(
              SizedBox(
                width: 160,
                child: TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  variant: TdsTextButtonVariant.underline,
                  child: Text(
                    label,
                    textAlign: align,
                    textDirection: direction,
                  ),
                ),
              ),
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(RichText),
          );
          final render = tester.renderObject<RenderTdsTextUnderline>(
            find.byType(TdsTextUnderline),
          );
          final origin = paragraph.localToGlobal(Offset.zero, ancestor: render);
          final boxes = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: paragraph.text
                      .toPlainText(includeSemanticsLabels: false)
                      .length,
                ),
              )
              .where((box) => box.right > box.left)
              .map((box) => box.toRect())
              .toList();
          final tops = boxes.map((box) => box.top).toSet().toList()..sort();
          final rects = render.underlineRects;
          expect(rects, hasLength(tops.length));
          for (var i = 0; i < tops.length; i++) {
            final extent = boxes
                .where((box) => box.top == tops[i])
                .reduce((a, b) => a.expandToInclude(b));
            expect(rects[i].left, closeTo(extent.left + origin.dx, .001));
            expect(rects[i].right, closeTo(extent.right + origin.dx, .001));
          }
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('long underline advances use the original 1/64px CSS units', (
    tester,
  ) async {
    for (final scale in [100.0, 160.0, 200.0]) {
      final theme = TdsThemeData(
        platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
      );
      for (final count in [40, 100]) {
        await tester.pumpWidget(
          app(
            TdsTheme(
              data: theme,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 342,
                  child: TdsTextButton(
                    size: TdsTextButtonSize.medium,
                    variant: TdsTextButtonVariant.underline,
                    child: Text(List.filled(count, '토스 Ag').join('\n')),
                  ),
                ),
              ),
            ),
          ),
        );
        final render = tester.renderObject<RenderTdsTextUnderline>(
          find.byType(TdsTextUnderline),
        );
        final rects = render.underlineRects;
        final height = tdsCssLineHeight(
          theme.platform.size(TdsTypography.t5) * 1.252,
        );
        expect(rects, hasLength(count));
        expect(
          rects.last.top - rects.first.top,
          closeTo((count - 1) * height, .001),
        );
      }
    }
  });

  testWidgets(
    'all sizes retain fractional flow height and fixed arrow frames at 100/160/200%',
    (tester) async {
      for (final scale in [100.0, 160.0, 200.0]) {
        final theme = TdsThemeData(
          platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
        );
        for (final size in TdsTextButtonSize.values) {
          for (final placement in TdsArrowPlacement.values) {
            await tester.pumpWidget(
              app(
                TdsTheme(
                  data: theme,
                  child: TdsTextButton(
                    size: size,
                    variant: TdsTextButtonVariant.arrow,
                    arrowPlacement: placement,
                    child: const Text('확인'),
                  ),
                ),
              ),
            );
            expect(
              tester.getSize(find.byType(TdsTextButton)).height,
              closeTo(
                (theme.platform.size(size.typography) * 1.252 * 64).floor() /
                    64,
                .0001,
              ),
            );
            final lineBox = tester.renderObject<RenderBox>(
              find.byType(TdsLineBox),
            );
            final fontSize = theme.platform.size(size.typography);
            final ascent = (fontSize * 2030 / 2048).round();
            final descent = (fontSize * 534 / 2048).round();
            final height = (fontSize * 1.252 * 64).floor() / 64;
            expect(
              lineBox.getDryBaseline(
                lineBox.constraints,
                TextBaseline.alphabetic,
              ),
              (ascent + (height - ascent - descent) / 2).floorToDouble(),
            );
            expect(
              tester.getSize(find.byType(TdsAssetIcon)),
              Size.square(size.arrowSize),
            );
            final frame = tester
                .widgetList<SizedBox>(find.byType(SizedBox))
                .where((box) => box.width == size.arrowSize && box.height == 5);
            expect(frame, hasLength(1));
          }
        }
      }
    },
  );

  testWidgets(
    'block and inline reserve equal widths without invented 3px gap',
    (tester) async {
      double? width;
      for (final placement in TdsArrowPlacement.values) {
        await tester.pumpWidget(
          app(
            TdsTextButton(
              size: TdsTextButtonSize.medium,
              variant: TdsTextButtonVariant.arrow,
              arrowPlacement: placement,
              child: const Text('확인'),
            ),
          ),
        );
        final actual = tester.getSize(find.byType(TdsTextButton)).width;
        if (width != null) expect(actual, closeTo(width, .0001));
        width = actual;
      }
    },
  );

  testWidgets('paragraph ancestry alone provides expanded hit padding', (
    tester,
  ) async {
    var calls = 0;
    Widget view(bool inherited) {
      Widget button = TdsTextButton(
        size: TdsTextButtonSize.medium,
        onPressed: () => calls++,
        child: const Text('확인'),
      );
      if (inherited) {
        button = TdsParagraphScope(
          typography: TdsTypography.t3,
          fontWeight: TdsFontWeight.regular,
          color: TdsPalette.grey900,
          textStyle: const TextStyle(fontSize: 22),
          child: button,
        );
      }
      return app(button);
    }

    await tester.pumpWidget(view(false));
    expect(
      tester.widget<TdsTouchInset>(find.byType(TdsTouchInset)).insets,
      EdgeInsets.zero,
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(TdsTextButton)) + const Offset(-2, 8),
    );
    expect(calls, 0);
    await tester.pumpWidget(view(true));
    final metrics = tdsLinkMetrics[22]!;
    expect(
      tester.widget<TdsTouchInset>(find.byType(TdsTouchInset)).insets,
      EdgeInsets.symmetric(horizontal: metrics.$2, vertical: metrics.$1),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(TdsTextButton)) + const Offset(-2, 8),
    );
    expect(calls, 1);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'immediate tick, rapid scale, quick gamma ink; touchcancel retains press',
    (tester) async {
      final haptic = RecordingHaptic();
      var calls = 0;
      await tester.pumpWidget(
        app(
          TdsHostProvider(
            haptic: haptic,
            child: TdsTextButton(
              size: TdsTextButtonSize.medium,
              onPressed: () => calls++,
              child: const Text('확인'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsTextButton)),
      );
      expect(haptic.calls, [TdsHapticType.tickWeak]);
      expect(calls, 0);
      await tester.pump();
      expect(motion(tester).scale, .94);
      expect(motion(tester).curve, TdsMotion.rapid);
      await tester.pump(const Duration(milliseconds: 100));
      final t = TdsMotion.quick.transform(
        100000 / TdsMotion.quick.duration.inMicroseconds,
      );
      int channel(double a, double b) =>
          (math.sqrt(a * a + (b * b - a * a) * t) * 255).round();
      const a = TdsPalette.grey600, b = TdsPalette.grey700;
      expect(
        ink(tester).toARGB32(),
        Color.fromARGB(
          255,
          channel(a.r, b.r),
          channel(a.g, b.g),
          channel(a.b, b.b),
        ).toARGB32(),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(motion(tester).scale, .94);
      expect(ink(tester), TdsPalette.grey700);
      expect(calls, 0);
      gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsTextButton)),
      );
      await gesture.up();
      await tester.pump();
      expect(motion(tester).scale, 1);
      expect(motion(tester).curve, TdsMotion.quick);
      expect(calls, 1);
      await tester.pumpAndSettle();
      expect(ink(tester), TdsPalette.grey600);
    },
  );

  testWidgets(
    'static palette advances one level, unknown literal is unchanged; tokens adapt',
    (tester) async {
      final cases = <(Color?, String?, Color, Color)>[
        (TdsPalette.blue500, null, TdsPalette.blue500, TdsPalette.blue600),
        (TdsPalette.blue900, null, TdsPalette.blue900, TdsPalette.blue900),
        (
          const Color(0xff123456),
          null,
          const Color(0xff123456),
          const Color(0xff123456),
        ),
        (
          null,
          'blue500',
          TdsPalette.darkThemeBlue500,
          TdsPalette.darkThemeBlue600,
        ),
        (null, null, TdsPalette.darkThemeGrey600, TdsPalette.darkThemeGrey700),
      ];
      for (final (color, token, start, end) in cases) {
        await tester.pumpWidget(
          app(
            TdsTheme(
              data: const TdsThemeData(colorScheme: TdsColorPreference.dark),
              child: TdsTextButton(
                key: UniqueKey(),
                size: TdsTextButtonSize.medium,
                color: color,
                colorToken: token,
                child: const Text('확인'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(ink(tester), start);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TdsTextButton)),
        );
        await tester.pumpAndSettle();
        expect(ink(tester), end);
        await gesture.up();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'keyboard click has no pointer haptic/scale; hover has no invented fill',
    (tester) async {
      final focus = FocusNode(), haptic = RecordingHaptic();
      var calls = 0;
      await tester.pumpWidget(
        app(
          TdsHostProvider(
            haptic: haptic,
            child: TdsTextButton(
              size: TdsTextButtonSize.medium,
              focusNode: focus,
              onPressed: () => calls++,
              child: const Text('확인'),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(calls, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      expect(calls, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(calls, 2);
      expect(haptic.calls, isEmpty);
      expect(motion(tester).scale, 1);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(TdsTextButton)));
      await tester.pumpAndSettle();
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('tds-text-button-dimmer')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color!.a, 0);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    },
  );

  testWidgets('disabled blocks pointer/keyboard/haptic and keeps .38 opacity', (
    tester,
  ) async {
    final haptic = RecordingHaptic();
    var calls = 0;
    await tester.pumpWidget(
      app(
        TdsHostProvider(
          haptic: haptic,
          child: TdsTextButton(
            size: TdsTextButtonSize.medium,
            disabled: true,
            onPressed: () => calls++,
            child: const Text('확인'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TdsTextButton));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(haptic.calls, isEmpty);
    expect(motion(tester).scale, 1);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, .38);
  });

  testWidgets(
    'resolved color update releases a pressed timeline and unmount disposes it',
    (tester) async {
      Widget view(Color color) => app(
        TdsTextButton(
          size: TdsTextButtonSize.medium,
          color: color,
          child: const Text('확인'),
        ),
      );
      await tester.pumpWidget(view(TdsPalette.blue500));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TdsTextButton)),
      );
      await tester.pump();
      expect(motion(tester).scale, .94);
      await tester.pumpWidget(view(TdsPalette.red500));
      expect(motion(tester).scale, 1);
      await tester.pumpAndSettle();
      expect(ink(tester), TdsPalette.red500);
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
