import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/domain/models.dart';

const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0+1',
);

String currentAppPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'web',
  };
}

abstract class RemoteConfigRepository extends ChangeNotifier {
  RemoteConfig get current;
  Future<void> load();
  Future<void> dismissNotice(String id);
  Future<void> dismissRecommendedUpdate();
  bool featureFlag(String name, {required bool defaultValue}) =>
      current.featureFlag(name, defaultValue: defaultValue);
}

class NoopRemoteConfigStore extends RemoteConfigRepository {
  NoopRemoteConfigStore({RemoteConfig? initial})
    : _current = initial ?? RemoteConfig.defaults;

  RemoteConfig _current;

  @override
  RemoteConfig get current => _current;

  @override
  Future<void> load() async {}

  @override
  Future<void> dismissNotice(String id) async {
    final notice = _current.notice(id);
    if (notice == null || !notice.dismissible) return;
    _current = _current.copyWith(
      dismissedNotices: {..._current.dismissedNotices, id: notice.version},
    );
    notifyListeners();
  }

  @override
  Future<void> dismissRecommendedUpdate() async {
    final key = _current.update.recommendationKey;
    if (key.isEmpty) return;
    _current = _current.copyWith(dismissedRecommendedUpdate: key);
    notifyListeners();
  }
}

class RemoteConfigStore extends RemoteConfigRepository {
  RemoteConfigStore(
    this.client,
    this.device, {
    String? platform,
    this.version = appVersion,
    this.timeout = const Duration(seconds: 3),
  }) : platform = platform ?? currentAppPlatform();

  final SupabaseClient client;
  final Database device;
  final String platform;
  final String version;
  final Duration timeout;
  final StoreRef<String, Data> preferences = stringMapStoreFactory.store(
    'remotePreferences',
  );
  RemoteConfig _current = RemoteConfig.defaults;
  Future<void>? _loading;
  bool _closed = false;

  @override
  RemoteConfig get current => _current;

  Future<void> initialize() async {
    _current = await _readCache() ?? RemoteConfig.defaults;
  }

  @override
  Future<void> load() {
    if (_closed) return Future<void>.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      final payload = await client
          .rpc(
            'app_bootstrap_config',
            params: {'p_platform': platform, 'p_app_version': version},
          )
          .timeout(timeout);
      if (_closed || payload is! Map) return;
      final next = RemoteConfig.fromJson(payload).copyWith(
        dismissedNotices: _current.dismissedNotices,
        dismissedRecommendedUpdate: _current.dismissedRecommendedUpdate,
      );
      _current = next;
      await _writeCache();
      if (!_closed) notifyListeners();
    } catch (_) {
      final cached = await _readCache();
      if (_closed || cached == null) return;
      _current = cached;
      notifyListeners();
    }
  }

  @override
  Future<void> dismissNotice(String id) async {
    final notice = _current.notice(id);
    if (notice == null || !notice.dismissible) return;
    _current = _current.copyWith(
      dismissedNotices: {..._current.dismissedNotices, id: notice.version},
    );
    await _writeCache();
    notifyListeners();
  }

  @override
  Future<void> dismissRecommendedUpdate() async {
    final key = _current.update.recommendationKey;
    if (key.isEmpty) return;
    _current = _current.copyWith(dismissedRecommendedUpdate: key);
    await _writeCache();
    notifyListeners();
  }

  Future<RemoteConfig?> _readCache() async {
    final value = await preferences.record('config').get(device);
    if (value == null) return null;
    return RemoteConfig.fromCache(value);
  }

  Future<void> _writeCache() =>
      preferences.record('config').put(device, _current.toCacheJson());

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

@immutable
class RemoteConfig {
  const RemoteConfig({
    required this.serverTime,
    required this.rawConfig,
    required this.maintenance,
    required this.update,
    required this.account,
    required this.notices,
    required this.dismissedNotices,
    required this.dismissedRecommendedUpdate,
  });

  static const defaults = RemoteConfig(
    serverTime: null,
    rawConfig: {},
    maintenance: MaintenanceConfig.defaults,
    update: UpdateConfig.defaults,
    account: null,
    notices: [],
    dismissedNotices: {},
    dismissedRecommendedUpdate: '',
  );

  final DateTime? serverTime;
  final Data rawConfig;
  final MaintenanceConfig maintenance;
  final UpdateConfig update;
  final AccountGateConfig? account;
  final List<AppNotice> notices;
  final Map<String, int> dismissedNotices;
  final String dismissedRecommendedUpdate;

  factory RemoteConfig.fromJson(Map<Object?, Object?> json) {
    return RemoteConfig(
      serverTime: _date(json['serverTime']),
      rawConfig: _data(json['config']),
      maintenance: MaintenanceConfig.fromJson(_data(json['maintenance'])),
      update: UpdateConfig.fromJson(_data(json['update'])),
      account: json['account'] is Map
          ? AccountGateConfig.fromJson(_data(json['account']))
          : null,
      notices: [
        for (final entry in _list(json['notices']))
          if (entry is Map) AppNotice.fromJson(_data(entry)),
      ],
      dismissedNotices: const {},
      dismissedRecommendedUpdate: '',
    );
  }

  factory RemoteConfig.fromCache(Data json) {
    final parsed = RemoteConfig.fromJson(json);
    return parsed.copyWith(
      dismissedNotices: _intMap(json['_dismissedNotices']),
      dismissedRecommendedUpdate: _string(json['_dismissedRecommendedUpdate']),
    );
  }

  Data toCacheJson() => {
    'serverTime': serverTime?.toIso8601String(),
    'config': rawConfig,
    'maintenance': maintenance.toJson(),
    'update': update.toJson(),
    'account': account?.toJson(),
    'notices': [for (final notice in notices) notice.toJson()],
    '_dismissedNotices': dismissedNotices,
    '_dismissedRecommendedUpdate': dismissedRecommendedUpdate,
  };

  RemoteConfig copyWith({
    DateTime? serverTime,
    Data? rawConfig,
    MaintenanceConfig? maintenance,
    UpdateConfig? update,
    Object? account = _sentinel,
    List<AppNotice>? notices,
    Map<String, int>? dismissedNotices,
    String? dismissedRecommendedUpdate,
  }) {
    return RemoteConfig(
      serverTime: serverTime ?? this.serverTime,
      rawConfig: rawConfig ?? this.rawConfig,
      maintenance: maintenance ?? this.maintenance,
      update: update ?? this.update,
      account: identical(account, _sentinel)
          ? this.account
          : account as AccountGateConfig?,
      notices: notices ?? this.notices,
      dismissedNotices: dismissedNotices ?? this.dismissedNotices,
      dismissedRecommendedUpdate:
          dismissedRecommendedUpdate ?? this.dismissedRecommendedUpdate,
    );
  }

  AppNotice? notice(String id) {
    for (final notice in notices) {
      if (notice.id == id) return notice;
    }
    return null;
  }

  bool featureFlag(String name, {required bool defaultValue}) {
    final flags = _data(rawConfig['feature_flags']);
    final value = flags[name];
    return value is bool ? value : defaultValue;
  }

  SupportConfig get support =>
      SupportConfig.fromJson(_data(rawConfig['support']));

  bool get showRecommendedUpdate =>
      update.recommended &&
      !update.required &&
      update.recommendationKey.isNotEmpty &&
      dismissedRecommendedUpdate != update.recommendationKey;

  List<AppNotice> visibleNoticesFor(AppRole? role, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final filtered = [
      for (final notice in notices)
        if (notice.visibleFor(role, at) && !_dismissed(notice)) notice,
    ];
    filtered.sort(AppNotice.compare);
    return filtered;
  }

  AppNotice? topNoticeFor(AppRole? role, {DateTime? now}) {
    final visible = visibleNoticesFor(role, now: now);
    return visible.isEmpty ? null : visible.first;
  }

  bool _dismissed(AppNotice notice) =>
      notice.dismissible &&
      (dismissedNotices[notice.id] ?? -1) >= notice.version;
}

@immutable
class MaintenanceConfig {
  const MaintenanceConfig({
    required this.active,
    required this.blockWrites,
    required this.title,
    required this.message,
    required this.endsAt,
  });

  static const defaults = MaintenanceConfig(
    active: false,
    blockWrites: false,
    title: '',
    message: '',
    endsAt: null,
  );

  final bool active;
  final bool blockWrites;
  final String title;
  final String message;
  final DateTime? endsAt;

  factory MaintenanceConfig.fromJson(Data json) => MaintenanceConfig(
    active: json['active'] == true,
    blockWrites: json['blockWrites'] == true,
    title: _string(json['title']),
    message: _string(json['message']),
    endsAt: _date(json['endsAt']),
  );

  Data toJson() => {
    'active': active,
    'blockWrites': blockWrites,
    'title': title,
    'message': message,
    'endsAt': endsAt?.toIso8601String(),
  };
}

@immutable
class UpdateConfig {
  const UpdateConfig({
    required this.platform,
    required this.current,
    required this.required,
    required this.recommended,
    required this.minimum,
    required this.latest,
    required this.storeUrl,
    required this.message,
  });

  static const defaults = UpdateConfig(
    platform: '',
    current: '',
    required: false,
    recommended: false,
    minimum: '',
    latest: '',
    storeUrl: '',
    message: '',
  );

  final String platform;
  final String current;
  final bool required;
  final bool recommended;
  final String minimum;
  final String latest;
  final String storeUrl;
  final String message;

  String get recommendationKey => latest.isNotEmpty
      ? '$platform:$latest'
      : minimum.isNotEmpty
      ? '$platform:$minimum'
      : '';

  factory UpdateConfig.fromJson(Data json) => UpdateConfig(
    platform: _string(json['platform']),
    current: _string(json['current']),
    required: json['required'] == true,
    recommended: json['recommended'] == true,
    minimum: _string(json['minimum']),
    latest: _string(json['latest']),
    storeUrl: _string(json['storeUrl']),
    message: _string(json['message']),
  );

  Data toJson() => {
    'platform': platform,
    'current': current,
    'required': required,
    'recommended': recommended,
    'minimum': minimum,
    'latest': latest,
    'storeUrl': storeUrl,
    'message': message,
  };
}

@immutable
class AccountGateConfig {
  const AccountGateConfig({required this.status, required this.message});

  final String status;
  final String message;

  factory AccountGateConfig.fromJson(Data json) => AccountGateConfig(
    status: _string(json['status'], 'active'),
    message: _string(json['message']),
  );

  Data toJson() => {'status': status, 'message': message};
}

enum AppNoticeSeverity {
  info(0),
  important(1),
  critical(2);

  const AppNoticeSeverity(this.rank);
  final int rank;

  static AppNoticeSeverity parse(String value) => switch (value) {
    'critical' => AppNoticeSeverity.critical,
    'important' => AppNoticeSeverity.important,
    _ => AppNoticeSeverity.info,
  };

  String get label => switch (this) {
    AppNoticeSeverity.critical => '긴급',
    AppNoticeSeverity.important => '중요',
    AppNoticeSeverity.info => '안내',
  };
}

@immutable
class AppNotice {
  const AppNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.severity,
    required this.linkUrl,
    required this.startsAt,
    required this.endsAt,
    required this.dismissible,
    required this.version,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final AppNoticeSeverity severity;
  final String linkUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool dismissible;
  final int version;
  final DateTime? updatedAt;

  factory AppNotice.fromJson(Data json) => AppNotice(
    id: _string(json['id']),
    title: _string(json['title']),
    body: _string(json['body']),
    audience: _string(json['audience'], 'all'),
    severity: AppNoticeSeverity.parse(_string(json['severity'])),
    linkUrl: _string(json['linkUrl']),
    startsAt: _date(json['startsAt']),
    endsAt: _date(json['endsAt']),
    dismissible: json['dismissible'] != false,
    version: _int(json['version']),
    updatedAt: _date(json['updatedAt']),
  );

  Data toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'audience': audience,
    'severity': severity.name,
    'linkUrl': linkUrl,
    'startsAt': startsAt?.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'dismissible': dismissible,
    'version': version,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  bool visibleFor(AppRole? role, DateTime now) {
    if (id.isEmpty) return false;
    final roleName = role?.name;
    if (audience != 'all' && audience != roleName) return false;
    if (startsAt != null && startsAt!.isAfter(now)) return false;
    if (endsAt != null && !endsAt!.isAfter(now)) return false;
    return true;
  }

  static int compare(AppNotice left, AppNotice right) {
    final severity = right.severity.rank.compareTo(left.severity.rank);
    if (severity != 0) return severity;
    final leftTime = left.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }
}

@immutable
class SupportConfig {
  const SupportConfig({
    required this.kakaoChannel,
    required this.email,
    required this.phone,
    required this.hours,
  });

  final String kakaoChannel;
  final String email;
  final String phone;
  final String hours;

  bool get hasAny =>
      kakaoChannel.isNotEmpty ||
      email.isNotEmpty ||
      phone.isNotEmpty ||
      hours.isNotEmpty;

  String get summary {
    final entries = [
      if (kakaoChannel.isNotEmpty) '카카오톡 채널',
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (hours.isNotEmpty) hours,
    ];
    return entries.join(' · ');
  }

  factory SupportConfig.fromJson(Data json) => SupportConfig(
    kakaoChannel: _string(json['kakaoChannel']).trim(),
    email: _string(json['email']).trim(),
    phone: _string(json['phone']).trim(),
    hours: _string(json['hours']).trim(),
  );
}

const _sentinel = Object();

Data _data(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};

List<Object?> _list(Object? value) => value is List ? value : const [];

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

int _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, int> _intMap(Object? value) {
  final data = _data(value);
  return {
    for (final entry in data.entries)
      if (entry.value is num || entry.value is String)
        entry.key: _int(entry.value),
  };
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
