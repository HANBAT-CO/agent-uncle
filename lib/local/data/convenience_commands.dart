import '../domain/convenience_models.dart';
import '../domain/models.dart';
import 'local_store.dart';

String applyConvenience(
  MutableWorkspace state,
  String actor,
  String command,
  Data args,
) {
  switch (command) {
    case 'convenience.upsertFavoriteWholesaler':
    case 'upsertFavoriteWholesaler':
      return _upsertFavoriteWholesaler(state, actor, args);
    case 'convenience.deleteFavoriteWholesaler':
    case 'deleteFavoriteWholesaler':
      return _deleteFavoriteWholesaler(state, actor, args);
  }
  throw AppFailure('지원하지 않는 편의 기능 명령이에요: $command');
}

Map<String, Data> _table(MutableWorkspace state, String name) =>
    state.tables.putIfAbsent(name, () => <String, Data>{});

Data _requireFrom(MutableWorkspace state, String table, String id) =>
    _table(state, table)[id] ??
    (throw const AppFailure('기록을 찾을 수 없어요. 목록을 다시 확인해 주세요.'));

Data _requireAccount(MutableWorkspace state, String userId) =>
    _requireFrom(state, 'accounts', userId);

void _requireRetailer(MutableWorkspace state, String userId) {
  final account = _requireAccount(state, userId);
  if (textOf(account, 'role') != 'retailer' || !flagOf(account, 'complete')) {
    throw const AppFailure('소매업자만 즐겨찾기 도매처를 관리할 수 있어요.');
  }
}

String _now() => DateTime.now().toIso8601String();

String _textArg(Data args, String key, {bool required = true}) {
  final value = textOf(args, key).trim();
  if (required && value.isEmpty) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

String _favoriteId(
  MutableWorkspace state,
  String actor,
  Data row,
  String requested,
) {
  if (requested.isNotEmpty) return requested;
  for (final entry in _table(state, 'favoriteWholesalers').entries) {
    if (textOf(entry.value, 'ownerId') != actor) continue;
    if (sameConvenienceWholesaler(entry.value, row)) return entry.key;
  }
  return newId();
}

String _upsertFavoriteWholesaler(
  MutableWorkspace state,
  String actor,
  Data args,
) {
  _requireRetailer(state, actor);
  final row = convenienceWholesalerRowOf(args);
  if (textOf(row, 'wholesaler').trim().isEmpty ||
      textOf(row, 'location').trim().isEmpty) {
    throw const AppFailure('도매처 이름과 위치를 확인해 주세요.');
  }
  final favoriteId = _favoriteId(
    state,
    actor,
    row,
    _textArg(args, 'favoriteId', required: false),
  );
  final previous = _table(state, 'favoriteWholesalers')[favoriteId];
  if (previous != null && textOf(previous, 'ownerId') != actor) {
    throw const AppFailure('본인 즐겨찾기만 수정할 수 있어요.');
  }
  _table(state, 'favoriteWholesalers')[favoriteId] = {
    ...?previous,
    ...row,
    'ownerId': actor,
    'label': convenienceWholesalerLabel(row),
    'createdAt': previous?['createdAt'] ?? _now(),
    'updatedAt': _now(),
    'version': numberOf(previous ?? const {}, 'version') + 1,
    'readers': [actor],
  };
  return favoriteId;
}

String _deleteFavoriteWholesaler(
  MutableWorkspace state,
  String actor,
  Data args,
) {
  _requireRetailer(state, actor);
  final favoriteId = _textArg(args, 'favoriteId');
  final favorite = _requireFrom(state, 'favoriteWholesalers', favoriteId);
  if (textOf(favorite, 'ownerId') != actor) {
    throw const AppFailure('본인 즐겨찾기만 삭제할 수 있어요.');
  }
  _table(state, 'favoriteWholesalers').remove(favoriteId);
  return favoriteId;
}
