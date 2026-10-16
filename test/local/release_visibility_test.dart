import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/release_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workspace_test.dart' show Fixture;

void main() {
  final retailer = Account('retailer', {'role': 'retailer', 'complete': true});
  final now = DateTime.utc(2026, 10, 15);
  final release = <String, Object?>{
    'public': true,
    'published': true,
    'build': 20,
  };

  test('공개 버전은 개별 readers 없이 양쪽 역할이 조회한다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    await f.store.write(f.retailer, '', (s) {
      s.put('appReleases', 'release', release);
      return '';
    });
    expect(f.workspace.records('appReleases').single.n('build'), 20);
    await f.session.signIn(f.uncle);
    expect(f.workspace.records('appReleases').single.n('build'), 20);
  });

  test('비공개·미발행·미래·잘못된 날짜·대상 외 버전은 노출하지 않는다', () {
    for (final restriction in <Data>[
      {'public': false},
      {'visibility': 'private'},
      {'published': false},
      {'enabled': false},
      {'startsAt': '2027-01-01'},
      {'publicAt': '잘못된 날짜'},
      {
        'roles': ['uncle'],
      },
      {
        'targetUserIds': ['other'],
      },
      {'roles': 'retailer'},
      {
        'roles': [3],
      },
      {
        'targetUserIds': [null],
      },
    ]) {
      expect(
        projectAppRelease({...release, ...restriction}, retailer, now: now),
        isNull,
      );
    }
    expect(projectAppRelease(release, null), isNull);
    expect(
      projectAppRelease(release, Account('new', {'complete': false})),
      isNull,
    );
    expect(
      projectAppRelease(
        release,
        Account('deleted', {'complete': true, 'deletionPending': true}),
      ),
      isNull,
    );
  });

  test('플랫폼 제한을 평가한 후 허용한 표시 필드만 내보낸다', () {
    final data = projectAppRelease({
      ...release,
      'roles': ['retailer'],
      'readers': ['secret-user'],
      'internalNote': '내부',
      'platforms': {
        'ios': {
          'roles': ['uncle'],
          'body': '삼촌 전용',
        },
        'android': {'body': '공개 변경', 'secret': '비밀'},
      },
    }, retailer)!;
    expect(data.containsKey('roles'), false);
    expect(data.containsKey('readers'), false);
    expect(data.containsKey('internalNote'), false);
    expect(mapOf(data, 'platforms').keys, ['android']);
    final android = mapOf(mapOf(data, 'platforms'), 'android');
    expect(android['body'], '공개 변경');
    expect(android.containsKey('secret'), false);
    expect(android.containsKey('roles'), false);
  });

  test('공개 시각은 명시적 시간대를 요구하고 동일 시점으로 비교한다', () {
    for (final timestamp in [
      '2026-10-14',
      '2026-10-14T23:00:00',
      '2026-02-30T00:00:00Z',
      '2026-13-01T00:00:00Z',
      '0000-01-01T00:00:00Z',
      '2026-01-01T24:00:00Z',
      '2026-01-01T00:00:60Z',
      '2026-01-01T00:00:00+99:99',
    ]) {
      expect(
        projectAppRelease(
          {...release, 'publishedAt': timestamp},
          retailer,
          now: now,
        ),
        isNull,
      );
    }
    for (final timestamp in [
      '2026-10-15T00:00:00Z',
      '2026-10-15T09:00:00+09:00',
    ]) {
      expect(
        projectAppRelease(
          {...release, 'publishedAt': timestamp},
          retailer,
          now: now,
        ),
        isNotNull,
      );
    }
    expect(
      projectAppRelease(
        {...release, 'publishedAt': '2026-10-15T09:00:01+09:00'},
        retailer,
        now: now,
      ),
      isNull,
    );
  });

  test('제한된 플랫폼·부모를 하위 설정이나 공통 빌드로 우회하지 않는다', () {
    for (final variants in <Data>[
      {'platforms': {}},
      {'platforms': 'invalid'},
      {
        'ios': {'public': false},
      },
      {
        'platforms': {
          'ios': {
            'userIds': ['other'],
          },
        },
      },
    ]) {
      expect(projectAppRelease({...release, ...variants}, retailer), isNull);
    }
    expect(
      projectAppRelease({
        ...release,
        'roles': ['uncle'],
        'platforms': {
          'ios': {
            'roles': ['retailer'],
          },
        },
      }, retailer),
      isNull,
    );
  });
}
