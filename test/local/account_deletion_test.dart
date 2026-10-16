import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'workspace_test.dart' show Fixture;

void main() {
  test('탈퇴는 개인 자료·첨부 원본을 지우고 상대방 거래 기록을 보존한다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    final request = await f.request();
    await f.store.write(f.retailer, '', (s) {
      s.put('drafts', 'private-draft', {'ownerId': f.retailer});
      s.put('notices', 'private-notice', {'ownerId': f.retailer});
      s.put('messages', 'sent', {
        'senderId': f.retailer,
        'recipientId': f.uncle,
        'body': '개인 채팅',
        'attachments': ['photo'],
        'version': 1,
        'status': 'sent',
      });
      s.put('messages', 'reply', {'senderId': f.uncle, 'body': '상대방 기록'});
      s.put('settings', 'destination', {'address': '배송지'});
      return '';
    });
    final mine = f.store.snapshot
        .all('attachments')
        .where((r) => r.s('ownerId') == f.retailer)
        .map((r) => r.id)
        .toList();
    await f.session.deleteAccount();
    expect(f.session.current, isNull);
    expect(f.store.snapshot.get('accounts', f.retailer), isNull);
    expect(f.store.snapshot.get('signupProgress', f.retailer), isNull);
    expect(f.store.snapshot.get('drafts', 'private-draft'), isNull);
    expect(f.store.snapshot.get('notices', 'private-notice'), isNull);
    expect(f.session.pendingDestination, isNull);
    expect(f.store.snapshot.all('connections'), isEmpty);
    for (final id in mine) {
      expect(f.store.snapshot.get('attachments', id), isNull);
      expect(
        await f.store
            .table('attachmentPayloads')
            .record(id)
            .get(f.store.database),
        isNull,
      );
    }
    expect(f.store.snapshot.get('messages', 'sent')!.b('deleted'), isTrue);
    expect(f.store.snapshot.get('messages', 'sent')!.s('body'), '');
    expect(f.store.snapshot.get('messages', 'reply')!.s('body'), '상대방 기록');
    expect(f.store.snapshot.get('requests', request), isNotNull);
    expect(f.store.snapshot.get('accounts', f.uncle), isNotNull);
    expect(
      await f.store.table('operations').count(f.store.database),
      greaterThan(0),
    );
    await expectLater(f.session.signIn(f.retailer), throwsA(isA<AppFailure>()));
    await f.session.signIn(f.uncle);
    expect(f.workspace.request(request), isNotNull);
  });

  test('저장 실패 시 계정과 자료를 유지하고 재시도할 수 있다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    f.store.failNextWrite = true;
    await expectLater(f.session.deleteAccount(), throwsA(isA<AppFailure>()));
    expect(f.session.current!.id, f.retailer);
    expect(f.store.snapshot.all('connections'), isNotEmpty);
    await f.session.deleteAccount();
    expect(f.session.current, isNull);
  });

  test('마지막 거래 참여자도 탈퇴하면 공유 거래 기록을 제거한다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    final request = await f.request();
    await f.session.deleteAccount();
    await f.session.signIn(f.uncle);
    await f.session.deleteAccount();
    expect(f.store.snapshot.get('requests', request), isNull);
    expect(f.store.snapshot.all('messages'), isEmpty);
    expect(f.store.snapshot.all('events'), isEmpty);
    expect(
      await f.store.table('attachmentPayloads').count(f.store.database),
      0,
    );
  });
}
