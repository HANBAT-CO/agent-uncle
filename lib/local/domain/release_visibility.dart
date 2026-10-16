import 'models.dart';

const _releasePublicFields = {
  'public',
  'published',
  'available',
  'enabled',
  'released',
  'platform',
  'publishedAt',
  'releasedAt',
  'availableAt',
  'publicAt',
  'startsAt',
  'createdAt',
  'buildNumber',
  'build',
  'versionCode',
  'versionName',
  'version',
  'buildName',
  'title',
  'headline',
  'body',
  'notes',
  'whatsNew',
  'description',
  'summary',
  'storeUrl',
  'updateUrl',
  'appStoreUrl',
  'playStoreUrl',
  'url',
};

/// 공개 여부와 대상자를 먼저 확인한 뒤 표시 필드만 돌려준다.
/// 플랫폼별 제한은 부모 제한을 넓힐 수 없으며, 누락된 플랫폼은 공개하지 않는다.
Data? projectAppRelease(Data source, Account? account, {DateTime? now}) {
  if (account == null ||
      !account.b('complete') ||
      account.b('deletionPending')) {
    return null;
  }
  final instant = now ?? DateTime.now();
  if (!_visible(source, account, instant)) return null;
  final platform = textOf(source, 'platform').trim().toLowerCase();
  if (platform.isNotEmpty && !const ['ios', 'android'].contains(platform)) {
    return null;
  }
  final publicData = _publicData(source);
  final hasVariants =
      source.containsKey('platforms') ||
      source.containsKey('ios') ||
      source.containsKey('android');
  if (!hasVariants) return publicData;
  final variants = <String, Object?>{};
  final raw = source['platforms'];
  for (final key in const ['ios', 'android']) {
    if (platform.isNotEmpty && platform != key) continue;
    final variant = source.containsKey('platforms')
        ? (raw is Map ? raw[key] : null)
        : source[key];
    if (variant is! Map) continue;
    final merged = <String, Object?>{
      ...source,
      ...Map<String, Object?>.from(variant),
    };
    if (!_visible(merged, account, instant)) continue;
    final target = textOf(merged, 'platform').trim().toLowerCase();
    if (target.isNotEmpty && target != key) continue;
    variants[key] = {..._publicData(merged), 'platform': key};
  }
  if (variants.isEmpty) return null;
  return {...publicData, 'platforms': variants};
}

Data _publicData(Data source) => {
  for (final key in _releasePublicFields)
    if (source[key] is String || source[key] is num || source[key] is bool)
      key: source[key],
};

bool _visible(Data source, Account account, DateTime now) {
  if (!_true(source['public']) ||
      ['visibility', 'audience'].any((key) => source[key] == 'private')) {
    return false;
  }
  for (final key in const ['published', 'available', 'enabled', 'released']) {
    if (source.containsKey(key) && !_true(source[key])) return false;
  }
  for (final key in const [
    'publishedAt',
    'releasedAt',
    'availableAt',
    'publicAt',
    'startsAt',
  ]) {
    final value = source[key];
    if (value == null || value == '') continue;
    // 단말과 서버의 시간대가 달라도 동일한 공개 시점으로 판단한다.
    if (value is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d{1,6})?(Z|[+-](0\d|1[0-5]):[0-5]\d)$',
        ).hasMatch(value)) {
      return false;
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final calendarDate = DateTime.utc(year, month, day);
    if (year == 0 ||
        calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day) {
      return false;
    }
    final date = DateTime.tryParse(value);
    if (date == null || date.isAfter(now)) return false;
  }
  for (final key in const [
    'roles',
    'eligibleRoles',
    'targetRoles',
    'audienceRoles',
  ]) {
    if (!_matches(source, key, account.role?.name ?? '')) return false;
  }
  for (final key in const [
    'userIds',
    'eligibleUserIds',
    'targetUserIds',
    'audienceUserIds',
  ]) {
    if (!_matches(source, key, account.id)) return false;
  }
  return true;
}

bool _true(Object? value) =>
    value == true || (value is String && value.trim().toLowerCase() == 'true');

bool _matches(Data source, String key, String value) {
  if (!source.containsKey(key)) return true;
  final values = source[key];
  if (values is! List || values.any((item) => item is! String)) return false;
  return values.isEmpty || values.contains(value);
}
