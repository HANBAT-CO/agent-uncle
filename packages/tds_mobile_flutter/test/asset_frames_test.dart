import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Map<String, dynamic> source(String name) =>
    jsonDecode(File('reference/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('every original frame name and optional geometry field is retained', () {
    final frames = source('asset-frames');
    final clean = source('compound-constants')['assetCleanFrames'] as List;
    expect(TdsAssetFrames.values.keys, unorderedEquals(frames.keys));
    for (final entry in frames.entries) {
      final original = entry.value as Map<String, dynamic>;
      final native = TdsAssetFrames.values[entry.key]!;
      expect(
        original.keys,
        everyElement(isIn(['width', 'height', 'radius', 'acc', 'overlap'])),
      );
      expect(
        native.width,
        original['width'] == '100%' ? double.infinity : original['width'],
        reason: entry.key,
      );
      expect(native.height, original['height'], reason: entry.key);
      expect(native.radius, original['radius'] ?? 0, reason: entry.key);
      expect(native.transparent, clean.contains(entry.key), reason: entry.key);
      final acc = original['acc'] as Map<String, dynamic>?;
      if (acc == null) {
        expect(native.accessorySize, isNull);
        expect(native.accessoryOffset, Offset.zero);
      } else {
        expect(acc.keys, unorderedEquals(['width', 'height', 'x', 'y']));
        expect(
          native.accessorySize,
          Size(
            (acc['width'] as num).toDouble(),
            (acc['height'] as num).toDouble(),
          ),
        );
        expect(
          native.accessoryOffset,
          Offset((acc['x'] as num).toDouble(), (acc['y'] as num).toDouble()),
        );
      }
      final overlap = original['overlap'] as Map<String, dynamic>?;
      if (overlap != null) {
        expect(overlap.keys, unorderedEquals(['x', 'y', 'blur', 'spread']));
      }
      expect(
        native.overlapOffset,
        Offset(
          (overlap?['x'] as num? ?? 0).toDouble(),
          (overlap?['y'] as num? ?? 0).toDouble(),
        ),
      );
      expect(native.overlapBlur, overlap?['blur'] ?? 0);
      expect(native.overlapSpread, overlap?['spread'] ?? 0);
    }
    final positions =
        source('compound-constants')['assetAccessoryPositions'] as Map;
    expect({
      for (final p in TdsAssetAccessoryPosition.values)
        '${p.name[0].toUpperCase()}${p.name.substring(1)}': p.value,
    }, positions);
  });

  test(
    'custom clean shapes follow structural equality, not a name heuristic',
    () {
      expect(const TdsAssetFrameShape(width: 24).transparent, isTrue);
      expect(const TdsAssetFrameShape(height: 100).transparent, isTrue);
      expect(
        const TdsAssetFrameShape(width: double.infinity).transparent,
        isTrue,
      );
      expect(const TdsAssetFrameShape(width: 100).transparent, isFalse);
      expect(const TdsAssetFrameShape(height: 20).transparent, isFalse);
      expect(const TdsAssetFrameShape(height: 28).transparent, isFalse);
      expect(
        const TdsAssetFrameShape(width: 24, height: 24).transparent,
        isFalse,
      );
      expect(
        const TdsAssetFrameShape(width: 24, radius: 0).transparent,
        isFalse,
      );
      expect(
        const TdsAssetFrameShape(width: 24, overlapBlur: 0).transparent,
        isFalse,
      );
      expect(
        const TdsAssetFrameShape(width: 24, transparent: false).transparent,
        isFalse,
      );
    },
  );

  testWidgets('all 44 frame geometries lay out content and four accessories', (
    tester,
  ) async {
    for (final shape in TdsAssetFrames.values.values) {
      for (final position in TdsAssetAccessoryPosition.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 300,
                child: Center(
                  child: TdsAssetFrame(
                    key: const Key('frame'),
                    shape: shape,
                    accessoryPosition: position,
                    content: const SizedBox(width: 10, height: 13),
                    accessory: const SizedBox(
                      key: Key('accessory'),
                      width: 50,
                      height: 50,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byKey(const Key('frame')));
        final acc = tester.getRect(find.byKey(const Key('accessory')));
        expect(
          rect.size,
          Size(
            shape.width == double.infinity ? 300 : shape.width ?? 10,
            shape.height ?? 13,
          ),
        );
        expect(acc.size, shape.accessorySize ?? Size.zero);
        final top =
            position == TdsAssetAccessoryPosition.topLeft ||
            position == TdsAssetAccessoryPosition.topRight;
        final left =
            position == TdsAssetAccessoryPosition.topLeft ||
            position == TdsAssetAccessoryPosition.bottomLeft;
        expect(
          top ? acc.top - rect.top : rect.bottom - acc.bottom,
          shape.accessoryOffset.dy,
        );
        expect(
          left ? acc.left - rect.left : rect.right - acc.right,
          shape.accessoryOffset.dx,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accessory mask applies without an accessory and retains 1px ring',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: TdsAssetFrame(
              shape: TdsAssetFrames.circleLarge,
              accessoryMasking: true,
              content: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      final clipper = tester
          .widget<ClipPath>(find.byType(ClipPath).first)
          .clipper!;
      final path = clipper.getClip(const Size(40, 40));
      expect(path.contains(const Offset(35, 35)), isFalse);
      expect(path.contains(const Offset(27.1, 35)), isFalse);
      expect(path.contains(const Offset(26.9, 35)), isTrue);
      expect(path.contains(const Offset(10, 10)), isTrue);
    },
  );
}
