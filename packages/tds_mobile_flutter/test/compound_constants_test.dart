import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

void main() {
  test('all five touch-inset levels and three variants match original CSS', () {
    final source =
        (jsonDecode(
                  File('reference/compound-constants.json').readAsStringSync(),
                )
                as Map)['textButtonTouchInsets']
            as Map;
    expect(mapByTypeAndTypography.keys, unorderedEquals(source.keys));
    for (final entry in mapByTypeAndTypography.entries) {
      final level = source[entry.key] as Map;
      expect(
        entry.value.keys.map((type) => type.name),
        unorderedEquals(level.keys),
      );
      for (final type in entry.value.entries) {
        final css = level[type.key.name] as Map;
        double px(String name) =>
            double.parse((css[name] as String).replaceAll('px', ''));
        expect(type.value.insets.left, -px('left'));
        expect(type.value.insets.top, -px('top'));
        expect(type.value.insets.right, -px('right'));
        expect(type.value.insets.bottom, -px('bottom'));
        expect(type.value.radius, px('borderRadius'));
      }
    }
  });
  test(
    'all paragraph variable leaves and ListRow typography aliases match source',
    () {
      final original =
          jsonDecode(
                File('reference/compound-constants.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(paragraphVariables, original['paragraphVariables']);
      expect(
        tdsListRowTypography.map((name, type) => MapEntry(name, type.name)),
        original['listRowTypography'],
      );
      for (final type in TdsTypography.values) {
        for (final entry in <String, Map<String, String>>{
          'text': assignTextVariables(type),
          'icon': assignIconVariables(type),
          'badge': assignBadgeVariables(type),
          'link': assignLinkVariables(type),
        }.entries) {
          expect(entry.value, {
            for (final token in paragraphVariables[entry.key]!.entries)
              token.value:
                  'var(--tds-t-${type.name}-${entry.key}-${token.key})',
          });
        }
      }
    },
  );
}
