import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

const _icon = 'assets/icons/icon-star-mono.svg';
const _package = 'tds_mobile_flutter';
Finder below(Type parent, Type child) =>
    find.descendant(of: find.byType(parent), matching: find.byType(child));

void main() {
  testWidgets(
    'AssetIcon preserves all shape/variant frames, scale and card padding',
    (tester) async {
      for (final shape in TdsListRowAssetIconShape.values) {
        for (final size in TdsListRowAssetSize.values.take(3)) {
          for (final variant in TdsListRowAssetIconVariant.values) {
            await tester.pumpWidget(
              testApp(
                Center(
                  child: TdsListRowAssetIcon(
                    name: 'icon-star-mono',
                    shape: shape,
                    size: size,
                    variant: variant,
                    paddingX: true,
                  ),
                ),
              ),
            );
            final icon = tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon));
            expect(
              tester
                  .widget<TdsAssetFrame>(find.byType(TdsAssetFrame))
                  .backgroundColor,
              const Color(0x00000000),
            );
            final shapeSize = [24.0, 30.0, 36.0][size.index];
            final fill = variant == TdsListRowAssetIconVariant.fill;
            final expected = switch (shape) {
              TdsListRowAssetIconShape.card => (
                20.0 + size.index * 4,
                30.0 + size.index * 6,
                fill ? 1.5 : .7,
              ),
              TdsListRowAssetIconShape.circleBackground => (40.0, 40.0, .66),
              TdsListRowAssetIconShape.circleMasking => (40.0, 40.0, 1.0),
              TdsListRowAssetIconShape.original => (shapeSize, shapeSize, 1.0),
              TdsListRowAssetIconShape.squircle => (
                shapeSize,
                shapeSize,
                fill ? 1.0 : .66,
              ),
            };
            expect(icon.frameShape!.width, expected.$1);
            expect(
              icon.frameShape!.height ?? icon.frameShape!.width,
              expected.$2,
            );
            expect(icon.scale, expected.$3);
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(TdsListRowAssetIcon)),
              Size(
                expected.$1 +
                    (shape == TdsListRowAssetIconShape.card
                        ? [4.0, 6.0, 8.0][size.index]
                        : 0),
                expected.$2,
              ),
            );
            expect(
              find.byType(TdsSquircleMasking),
              shape == TdsListRowAssetIconShape.squircle
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'AssetImage keeps source fixed circle/square and original custom frame',
    (tester) async {
      for (final size in TdsListRowAssetSize.values) {
        await tester.pumpWidget(
          testApp(
            Column(
              children: [
                TdsListRowAssetImage(
                  src: _icon,
                  package: _package,
                  shape: TdsListRowAssetShape.circle,
                  size: size,
                ),
                TdsListRowAssetImage(
                  src: _icon,
                  package: _package,
                  shape: TdsListRowAssetShape.square,
                  size: size,
                ),
                TdsListRowAssetImage(
                  src: _icon,
                  package: _package,
                  shape: TdsListRowAssetShape.card,
                  size: size,
                  paddingX: true,
                ),
              ],
            ),
          ),
        );
        final images = tester
            .widgetList<TdsAssetImage>(find.byType(TdsAssetImage))
            .toList();
        expect(images[0].frameShape, same(TdsAssetFrames.circleLarge));
        expect(images[1].frameShape, same(TdsAssetFrames.squareXLarge));
        expect(images[2].scaleType, TdsAssetScaleType.fill);
        expect(find.byType(SvgPicture), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      }
      const custom = TdsAssetFrameShape(width: 80, height: 45, radius: 8);
      await tester.pumpWidget(
        testApp(
          const Center(
            child: TdsListRowAssetImage(
              src: _icon,
              package: _package,
              shape: TdsListRowAssetShape.original,
              frameShape: custom,
              scale: 1.2,
              scaleType: TdsAssetScaleType.fill,
            ),
          ),
        ),
      );
      final image = tester.widget<TdsAssetImage>(find.byType(TdsAssetImage));
      expect(image.frameShape, same(custom));
      expect(image.scale, 1.2);
      expect(
        tester.getSize(find.byType(TdsListRowAssetImage)),
        const Size(80, 45),
      );
    },
  );

  testWidgets(
    'AssetText has six fixed bold sizes, decorative semantics and theme colors',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          testApp(
            TdsTheme(
              data: TdsThemeData(
                colorScheme: dark
                    ? TdsColorPreference.dark
                    : TdsColorPreference.light,
                platform: const TdsPlatform(os: TdsOS.android, fontScale: 200),
              ),
              child: Column(
                children: [
                  for (final size in TdsListRowAssetSize.values)
                    TdsListRowAssetText('T', size: size),
                ],
              ),
            ),
          ),
        );
        final texts = tester.widgetList<Text>(find.text('T')).toList();
        expect(texts.map((text) => text.style!.fontSize), [
          10,
          11,
          13,
          15,
          16,
          17,
        ]);
        expect(
          texts.every((text) => text.style!.fontWeight == FontWeight.bold),
          isTrue,
        );
        expect(
          texts.first.style!.color,
          TdsThemeData(
            colorScheme: dark
                ? TdsColorPreference.dark
                : TdsColorPreference.light,
          ).color('blue500'),
        );
        expect(find.bySemanticsLabel('T'), findsNothing);
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'Asset accessories retain position and are outside the squircle mask',
    (tester) async {
      const badgeKey = ValueKey('badge');
      for (final position in TdsAssetAccessoryPosition.values) {
        await tester.pumpWidget(
          testApp(
            Center(
              child: TdsListRowAssetText(
                'T',
                accessory: const ColoredBox(
                  key: badgeKey,
                  color: Color(0xff112233),
                ),
                accessoryPosition: position,
                accessoryMasking: true,
              ),
            ),
          ),
        );
        final frame = tester.getRect(find.byType(TdsSquircleMasking));
        final badge = tester.getRect(find.byKey(badgeKey));
        expect(badge.size, const Size(11, 11));
        final top =
            position == TdsAssetAccessoryPosition.topLeft ||
            position == TdsAssetAccessoryPosition.topRight;
        final right =
            position == TdsAssetAccessoryPosition.topRight ||
            position == TdsAssetAccessoryPosition.bottomRight;
        expect(top ? badge.top - frame.top : frame.bottom - badge.bottom, -2);
        expect(right ? frame.right - badge.right : badge.left - frame.left, -2);
        expect(
          find.ancestor(
            of: find.byKey(badgeKey),
            matching: find.byType(TdsSquircleMasking),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'LeftContainer and asset compounds align to unrounded first-line metrics at 135 percent',
    (tester) async {
      const leftKey = ValueKey('left');
      for (final type in TdsListRowTextType.values) {
        final presets = tdsListRowTextPresets[type]!;
        await tester.pumpWidget(
          testApp(
            TdsListRow(
              left: const TdsListRowLeftContainer(
                height: 12,
                width: 12,
                child: SizedBox(key: leftKey, width: 12, height: 12),
              ),
              contents: TdsListRowTexts(
                type: type,
                top: const Text('top'),
                middle: const Text('middle'),
                bottom: const Text('bottom'),
              ),
            ),
            scale: 135,
          ),
        );
        final expected = (presets.first.$1.baseSize * 1.35 * 1.35 - 12) / 2;
        expect(
          tester.getTopLeft(find.byKey(leftKey)).dy -
              tester.getTopLeft(find.byType(TdsListRow)).dy,
          closeTo(12 + expected, .0001),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        testApp(
          const TdsListRow(
            a11yLeftAlignment: TdsListRowAlignment.center,
            left: TdsListRowLeftContainer(
              height: 12,
              width: 12,
              marginTop: 7,
              child: SizedBox(key: leftKey, width: 12, height: 12),
            ),
            contents: Text('label'),
          ),
          scale: 200,
        ),
      );
      final padding = tester.widget<Padding>(
        below(TdsListRowLeftContainer, Padding),
      );
      expect(padding.padding, const EdgeInsets.only(top: 7));
      await tester.pumpWidget(
        testApp(
          const TdsListRow(
            contentsType: TdsListRowTextType.row1TypeA,
            left: TdsListRowAssetText('T', size: TdsListRowAssetSize.xsmall),
            contents: Text('wrapped'),
          ),
          scale: 200,
        ),
      );
      final frame = tester.getRect(find.byType(TdsAssetFrame));
      expect(
        frame.top - tester.getTopLeft(find.byType(TdsListRow)).dy,
        closeTo(12 + (17 * 2 * 1.35 - 24) / 2, .0001),
      );
    },
  );

  testWidgets(
    'FillIcon keeps source wrapper and inner circle-background dimensions',
    (tester) async {
      for (final shape in TdsListRowFillIconShape.values) {
        await tester.pumpWidget(
          testApp(
            Center(
              child: TdsListRowFillIcon(name: 'icon-star-mono', shape: shape),
            ),
          ),
        );
        final size = switch (shape) {
          TdsListRowFillIconShape.plain => 24.0,
          TdsListRowFillIconShape.squircle => 30.0,
          _ => 40.0,
        };
        expect(
          tester.getSize(find.byType(TdsListRowFillIcon)),
          Size.square(size),
        );
        expect(
          tester.widget<TdsAssetIcon>(find.byType(TdsAssetIcon)).size,
          shape == TdsListRowFillIconShape.circleBackground ? 20 : size,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('AssetLottie uses source original height and shape scales', (
    tester,
  ) async {
    for (final shape in TdsListRowAssetShape.values) {
      await tester.pumpWidget(
        testApp(
          Center(
            child: TdsListRowAssetLottie(
              src: 'assets/point/point-spot.json',
              package: _package,
              shape: shape,
              animate: false,
            ),
          ),
        ),
      );
      await tester.pump();
      final lottie = tester.widget<TdsAssetLottie>(find.byType(TdsAssetLottie));
      expect(
        lottie.scale,
        shape == TdsListRowAssetShape.original
            ? 1
            : shape == TdsListRowAssetShape.card
            ? .7
            : .66,
      );
      if (shape == TdsListRowAssetShape.original) {
        expect(lottie.frameShape.height, 40);
        expect(lottie.backgroundColor, const Color(0x00000000));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Header icon button inherits size and keeps source trailing edge',
    (tester) async {
      var calls = 0;
      for (final size in TdsListHeaderSize.values) {
        await tester.pumpWidget(
          testApp(
            TdsListHeader(
              size: size,
              title: const TdsListHeaderTitleParagraph('목록'),
              right: TdsListHeaderRightIconButton(
                semanticLabel: '더 보기',
                name: 'icon-star-mono',
                onPressed: () => calls++,
              ),
            ),
          ),
        );
        final iconSize = size.index < 2 ? 20.0 : 16.0;
        await tester.pumpAndSettle();
        final line = const TdsPlatform(os: TdsOS.android).lineHeight(
          [
            TdsTypography.t4,
            TdsTypography.t5,
            TdsTypography.t6,
            TdsTypography.t7,
          ][size.index],
        );
        expect(
          tester.getSize(find.byType(TdsListHeader)).height,
          closeTo(36 + line, .001),
        );
        expect(
          tester.widget<TdsIconButton>(find.byType(TdsIconButton)).iconSize,
          iconSize,
        );
        expect(
          tester.getSize(find.byType(TdsListHeaderRightIconButton)).width,
          iconSize + (size.index < 2 ? 9 : 8),
        );
        await tester.tap(find.byType(TdsIconButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(calls, 4);
    },
  );
}
