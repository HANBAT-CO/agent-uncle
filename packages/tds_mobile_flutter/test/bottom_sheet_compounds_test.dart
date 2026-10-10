import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:tds_mobile_flutter/src/foundation/bottom_sheet_scope.dart';
import 'collections_feedback_test.dart' show testApp;

const options = [
  TdsBottomSheetSelectOption(name: 'first', value: 'a'),
  TdsBottomSheetSelectOption(name: 'second', value: 'b'),
  TdsBottomSheetSelectOption(name: 'disabled', value: 'c', disabled: true),
  TdsBottomSheetSelectOption(
    name: 'hidden',
    value: 'd',
    hideUncheckedCheckbox: true,
  ),
];

void main() {
  Future<void> viewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('sheet CTA fades once with the original 600ms ease curve', (
    tester,
  ) async {
    Widget view() => testApp(const TdsBottomSheetCTA(child: Text('submit')));
    await tester.pumpWidget(view());
    Opacity opacity() => tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(TdsSheetCTAOverlap),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity().opacity, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      opacity().opacity,
      closeTo(const Cubic(.6, 0, 0, .6).transform(.5), .001),
    );
    await tester.pumpAndSettle();
    expect(opacity().opacity, 1);
    await tester.pumpWidget(view());
    expect(opacity().opacity, 1);
    await tester.pumpWidget(testApp(const SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large-text sheet descriptions and rows use source metric table, not fixed 1.5em',
    (tester) async {
      await viewport(tester);
      for (final scale in [100.0, 160.0, 200.0]) {
        await tester.pumpWidget(
          testApp(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TdsBottomSheetHeaderDescription('desc'),
                TdsBottomSheetSelect(
                  animation: false,
                  options: const [
                    TdsBottomSheetSelectOption(name: 'row', value: 'a'),
                  ],
                  onChange: (_) {},
                ),
              ],
            ),
            scale: scale,
          ),
        );
        final platform = TdsPlatform(os: TdsOS.android, fontScale: scale);
        expect(
          tester.getSize(find.byType(TdsBottomSheetHeaderDescription)).height,
          8 + platform.lineHeight(TdsTypography.t6),
        );
        expect(
          tester.getSize(find.byType(TdsBottomSheetSelect)).height,
          8 + 32 + platform.lineHeight(TdsTypography.t5),
        );
      }
      await tester.pumpWidget(testApp(const SizedBox()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'headers preserve string metrics, rich children and inherited colors',
    (tester) async {
      await viewport(tester);
      const custom = ValueKey('custom');
      const rich = ValueKey('rich');
      await tester.pumpWidget(
        testApp(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TdsBottomSheetHeader('title'),
              TdsBottomSheetHeaderDescription('description'),
              TdsBottomSheetHeader.child(SizedBox(key: custom, height: 40)),
              TdsBottomSheetHeaderDescription.child(
                Text.rich(
                  key: rich,
                  TextSpan(
                    children: [
                      TextSpan(text: 'rich '),
                      TextSpan(
                        text: 'text',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(TdsBottomSheetHeader).first).height,
        33,
      );
      expect(
        tester
            .getSize(find.byType(TdsBottomSheetHeaderDescription).first)
            .height,
        30.5,
      );
      expect(tester.getRect(find.byKey(custom)).left, 24);
      expect(tester.getRect(find.byKey(custom)).width, 342);
      expect(tester.getSize(find.byType(TdsBottomSheetHeader).last).height, 44);
      final style = DefaultTextStyle.of(tester.element(find.byKey(rich))).style;
      expect(style.fontSize, 15);
      expect(style.height, 1.5);
      expect(style.color, const TdsThemeData().color('grey600'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Select source spacing, disabled text, line marks and hidden reserved slot',
    (tester) async {
      await viewport(tester);
      for (final hasCTA in [true, false]) {
        await tester.pumpWidget(
          testApp(
            TdsBottomSheetScope(
              hasCTA: hasCTA,
              scrollable: false,
              child: TdsBottomSheetSelect(
                animation: false,
                value: 'a',
                options: options,
                onChange: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(TdsBottomSheetSelect)).height,
          8 + 4 * 57.5 + (hasCTA ? 0 : 16),
        );
        final texts = tester.widgetList<TdsText>(find.byType(TdsText));
        expect(
          texts.every(
            (e) =>
                e.fontWeight == TdsFontWeight.medium &&
                e.color == const TdsThemeData().color('grey700'),
          ),
          true,
        );
        final graphics = find.byType(TdsCheckboxLineGraphic);
        expect(graphics, findsNWidgets(4));
        for (var i = 0; i < 4; i++) {
          expect(tester.getSize(graphics.at(i)), const Size(24, 24));
          expect(tester.getRect(graphics.at(i)).right, 366);
        }
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(of: graphics.last, matching: find.byType(Opacity))
              .first,
        );
        expect(opacity.opacity, 0);
      }
    },
  );

  testWidgets(
    'Select stagger is translate-only: 80px, 800ms expo, delay plus 30ms',
    (tester) async {
      await viewport(tester);
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetSelect(
            options: options,
            onChange: (_) {},
            animationDelay: const Duration(milliseconds: 100),
          ),
        ),
      );
      final row = find.byType(TdsText).first;
      double translatedY(int index) => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byType(TdsText).at(index),
                  matching: find.byType(Transform),
                )
                .last,
          )
          .transform
          .storage[13];
      expect(translatedY(0), 80);
      expect(translatedY(1), 80);
      expect(
        find.ancestor(of: row, matching: find.byType(Opacity)),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(translatedY(0), 80);
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        translatedY(0),
        closeTo(80 * (1 - TdsMotion.expo.transform(30 / 800)), .001),
      );
      expect(translatedY(1), 80);
      await tester.pumpAndSettle();
      expect(translatedY(0), 0);
      await tester.pumpWidget(testApp(const SizedBox()));
      expect(tester.hasRunningAnimations, false);
    },
  );

  testWidgets(
    'Select click emits repeated checked changes; disabled still presses but never selects',
    (tester) async {
      await viewport(tester);
      final values = <String>[];
      final checks = <bool>[];
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetSelect(
            animation: false,
            options: options,
            value: 'a',
            onChange: values.add,
            onCheckedChange: (value, checked) => checks.add(checked),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('first'));
      await tester.tap(find.text('second'));
      expect(values, ['a', 'b']);
      expect(checks, [false, true]);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('disabled')),
      );
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.text('disabled'),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, .96);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(values, ['a', 'b']);
      final focus = find
          .ancestor(of: find.text('second'), matching: find.byType(Focus))
          .first;
      Focus.of(tester.element(find.text('second'))).requestFocus();
      await tester.pump();
      expect(tester.widget<Focus>(focus).canRequestFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(values, ['a', 'b']);
    },
  );

  testWidgets(
    'sheet CTA resolves measured overflow and removes gradient when content shrinks',
    (tester) async {
      await viewport(tester);
      Widget view(double height, {bool? background}) => testApp(
        TdsBottomSheet(
          open: true,
          maxHeight: const TdsBottomSheetHeight.pixels(400),
          header: const TdsBottomSheetHeader('title'),
          cta: TdsBottomSheetCTA(
            background: background,
            child: const Text('submit'),
          ),
          child: SizedBox(height: height),
        ),
      );
      for (final height in [50.0, 1000.0, 50.0]) {
        await tester.pumpWidget(view(height));
        await tester.pumpAndSettle();
        final cta = tester.widget<TdsBottomCTA>(find.byType(TdsBottomCTA));
        expect(cta.background, height > 400);
        expect(cta.hasSafeAreaPadding, false);
        expect(
          tester.getSize(find.byType(TdsSheetCTAOverlap)).height,
          height > 400 ? 78 : 76,
        );
        expect(
          cta.backgroundColor,
          TdsTheme.of(
            tester.element(find.byType(TdsBottomCTA)),
          ).color('layeredBackground'),
        );
        expect(tester.takeException(), isNull);
      }
      for (final override in [false, true]) {
        await tester.pumpWidget(view(1000, background: override));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TdsBottomCTA>(find.byType(TdsBottomCTA)).background,
          override,
        );
      }
    },
  );

  testWidgets(
    'CTA and DoubleCTA forward native button, accessory and layout options',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        testApp(
          TdsBottomSheetCTA(
            disabled: true,
            disabledChild: const Text('wait'),
            inert: true,
            focusNode: focus,
            autofocus: true,
            semanticLabel: 'action',
            color: TdsButtonColor.danger,
            variant: TdsButtonVariant.weak,
            hasPaddingBottom: false,
            background: true,
            topAccessory: const Text('top'),
            bottomAccessory: const Text('bottom'),
            child: const Text('submit'),
          ),
        ),
      );
      final single = tester.widget<TdsBottomCTA>(find.byType(TdsBottomCTA));
      expect(single.focusNode, focus);
      expect(single.inert, true);
      expect(single.autofocus, true);
      expect(single.semanticLabel, 'action');
      expect(single.color, TdsButtonColor.danger);
      expect(single.variant, TdsButtonVariant.weak);
      expect(single.hasPaddingBottom, false);
      expect(find.text('wait'), findsOneWidget);
      await tester.pumpWidget(
        testApp(
          const TdsBottomSheetDoubleCTA(
            leftButton: SizedBox(height: 30),
            rightButton: SizedBox(height: 40),
            background: true,
            hasPaddingBottom: false,
            topAccessory: Text('top'),
            bottomAccessory: Text('bottom'),
          ),
        ),
      );
      final doubleCTA = tester.widget<TdsBottomCTA>(find.byType(TdsBottomCTA));
      expect(doubleCTA.hasPaddingBottom, false);
      expect(doubleCTA.hasSafeAreaPadding, false);
      expect(doubleCTA.fixedAboveKeyboard, false);
      expect(doubleCTA.background, true);
      expect(find.text('top'), findsOneWidget);
      expect(find.text('bottom'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
    },
  );
}
