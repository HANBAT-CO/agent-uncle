import 'dart:math';

/// Source pS/BXe insert blank *key groups*, not individual grid columns.
/// The original key count is the random bound on every insertion, including
/// the second blank. The trailing key group can therefore never be blank.
List<int?> secureKeypadRow(int keyCount, int emptyCount, Random random) {
  final result = <int?>[for (var i = 0; i < keyCount; i++) i];
  for (var i = 0; i < emptyCount; i++) {
    result.insert(random.nextInt(keyCount), null);
  }
  return List.unmodifiable(result);
}
