import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:http/http.dart' as http;
import 'package:agent_uncle/local/domain/models.dart';
import 'repositories_test.dart' show Harness, actor, peer, reply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('서버 탈퇴 성공 후 본인 대기열·배송지·세션을 지우고 중복 호출을 합친다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    await h.session.initialize();
    await h.store.outbox.record('mine').put(h.store.device, {
      'senderId': actor,
      'body': '미전송',
    });
    await h.store.outbox.record('other').put(h.store.device, {
      'senderId': peer,
      'body': '다른 계정',
    });
    await h.session.setDestination({'address': '서울'});
    h.pendingDeletion = Completer<http.Response>();
    final first = h.session.deleteAccount();
    final second = h.session.deleteAccount();
    h.pendingDeletion!.complete(reply('{"deleted":true}', 200));
    await Future.wait([first, second]);
    expect(h.deletionCalls, 1);
    expect(h.client.auth.currentSession, isNull);
    expect(h.session.current, isNull);
    expect(h.session.pendingDestination, isNull);
    expect(await h.store.outbox.record('mine').get(h.store.device), isNull);
    expect(await h.store.outbox.record('other').get(h.store.device), isNotNull);
  });

  for (final status in [404, 503]) {
    test('서버 오류 $status 후 로그인 상태를 유지하고 재시도한다', () async {
      final h = Harness();
      await h.open();
      addTearDown(h.close);
      await h.session.initialize();
      h.deletionResponse = reply('{"error":"실패"}', status);
      await expectLater(h.session.deleteAccount(), throwsA(isA<AppFailure>()));
      expect(h.session.authenticated, isTrue);
      h.deletionResponse = null;
      await h.session.deleteAccount();
      expect(h.session.authenticated, isFalse);
      expect(h.deletionCalls, 2);
    });
  }
}
