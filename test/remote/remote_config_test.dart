import 'dart:async';
import 'dart:convert';

import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/remote/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _reply(Object body, int status) => http.Response(
  body is String ? body : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
  request: http.Request(
    'POST',
    Uri.parse('https://example.supabase.co/rest/v1/rpc/app_bootstrap_config'),
  ),
);

Map<String, Object?> _payload({
  bool requiredUpdate = false,
  bool recommendedUpdate = false,
  bool maintenance = false,
  String accountStatus = 'active',
  int noticeVersion = 1,
}) => {
  'serverTime': '2026-10-13T00:00:00Z',
  'config': {
    'feature_flags': {'newHome': true},
    'support': {
      'kakaoChannel': '사입삼춘',
      'email': 'help@example.com',
      'phone': '',
      'hours': '평일 10:00-18:00',
    },
  },
  'maintenance': {
    'active': maintenance,
    'blockWrites': maintenance,
    'title': '점검 안내',
    'message': '잠시 점검하고 있어요.',
    'endsAt': '2026-10-13T01:00:00Z',
  },
  'update': {
    'platform': 'ios',
    'current': '0.1.0+1',
    'required': requiredUpdate,
    'recommended': recommendedUpdate,
    'minimum': '0.1.0',
    'latest': '0.2.0',
    'storeUrl': 'https://example.com/store',
    'message': '새 버전으로 업데이트해 주세요.',
  },
  'account': {
    'status': accountStatus,
    'message': accountStatus == 'suspended' ? '제한 사유를 확인해 주세요.' : '',
  },
  'notices': [
    {
      'id': 'notice-info',
      'title': '일반 공지',
      'body': '소매 공지예요.',
      'audience': 'retailer',
      'severity': 'info',
      'linkUrl': '',
      'startsAt': '2026-10-12T00:00:00Z',
      'endsAt': '2026-10-14T00:00:00Z',
      'dismissible': true,
      'version': noticeVersion,
      'updatedAt': '2026-10-12T00:00:00Z',
    },
    {
      'id': 'notice-critical',
      'title': '긴급 공지',
      'body': '모두에게 보이는 공지예요.',
      'audience': 'all',
      'severity': 'critical',
      'linkUrl': '',
      'startsAt': '2026-10-12T01:00:00Z',
      'endsAt': '2026-10-14T00:00:00Z',
      'dismissible': false,
      'version': 1,
      'updatedAt': '2026-10-12T01:00:00Z',
    },
  ],
};

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: MockClient(handler),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses config, support, account, update and role-filtered notices', () {
    final config = RemoteConfig.fromJson(
      _payload(requiredUpdate: true, accountStatus: 'suspended'),
    );
    expect(config.serverTime, DateTime.parse('2026-10-13T00:00:00Z'));
    expect(config.update.required, isTrue);
    expect(config.update.storeUrl, 'https://example.com/store');
    expect(config.account?.status, 'suspended');
    expect(config.featureFlag('newHome', defaultValue: false), isTrue);
    expect(config.featureFlag('missingFlag', defaultValue: true), isTrue);
    expect(config.support.hasAny, isTrue);
    expect(config.support.summary, contains('help@example.com'));

    final notices = config.visibleNoticesFor(
      AppRole.retailer,
      now: DateTime.parse('2026-10-13T00:00:00Z'),
    );
    expect(notices.map((notice) => notice.id), [
      'notice-critical',
      'notice-info',
    ]);
    expect(
      config
          .topNoticeFor(
            AppRole.uncle,
            now: DateTime.parse('2026-10-13T00:00:00Z'),
          )
          ?.id,
      'notice-critical',
    );
  });

  test(
    'load calls RPC with platform and app version, then caches the result',
    () async {
      final requests = <Map<String, Object?>>[];
      final client = _client((request) async {
        requests.add(jsonDecode(request.body) as Map<String, Object?>);
        return _reply(_payload(recommendedUpdate: true), 200);
      });
      final database = await databaseFactoryMemory.openDatabase(newId());
      addTearDown(database.close);
      addTearDown(client.dispose);

      final store = RemoteConfigStore(
        client,
        database,
        platform: 'ios',
        version: '0.1.0+1',
        timeout: const Duration(milliseconds: 100),
      );
      await store.initialize();
      await store.load();

      expect(requests.single, {
        'p_platform': 'ios',
        'p_app_version': '0.1.0+1',
      });
      expect(store.current.showRecommendedUpdate, isTrue);

      final reopened = RemoteConfigStore(client, database, platform: 'ios');
      await reopened.initialize();
      expect(reopened.current.showRecommendedUpdate, isTrue);
    },
  );

  test('timeout falls back to cached config without throwing', () async {
    final pending = Completer<http.Response>();
    final client = _client((_) => pending.future);
    final database = await databaseFactoryMemory.openDatabase(newId());
    addTearDown(database.close);
    addTearDown(client.dispose);

    final seed = RemoteConfigStore(client, database, platform: 'ios');
    await seed.initialize();
    seed.current;
    await seed.preferences
        .record('config')
        .put(
          database,
          RemoteConfig.fromJson(_payload(maintenance: true)).toCacheJson(),
        );

    final store = RemoteConfigStore(
      client,
      database,
      platform: 'ios',
      timeout: const Duration(milliseconds: 1),
    );
    await store.initialize();
    await store.load();

    expect(store.current.maintenance.active, isTrue);
    expect(store.current.maintenance.title, '점검 안내');
  });

  test('LOCAL_MODE no-op store returns defaults', () async {
    final store = NoopRemoteConfigStore();
    await store.load();
    expect(store.current, RemoteConfig.defaults);
    expect(store.current.update.required, isFalse);
    expect(store.current.visibleNoticesFor(AppRole.retailer), isEmpty);
  });

  test('notice dismissal is id to version and a version bump shows again', () {
    final first = RemoteConfig.fromJson(_payload());
    final dismissed = first.copyWith(dismissedNotices: {'notice-info': 1});
    expect(
      dismissed
          .visibleNoticesFor(
            AppRole.retailer,
            now: DateTime.parse('2026-10-13T00:00:00Z'),
          )
          .map((notice) => notice.id),
      ['notice-critical'],
    );

    final bumped = RemoteConfig.fromJson(
      _payload(noticeVersion: 2),
    ).copyWith(dismissedNotices: dismissed.dismissedNotices);
    expect(
      bumped
          .visibleNoticesFor(
            AppRole.retailer,
            now: DateTime.parse('2026-10-13T00:00:00Z'),
          )
          .map((notice) => notice.id),
      ['notice-critical', 'notice-info'],
    );
  });
}
