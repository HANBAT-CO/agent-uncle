import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'repositories_test.dart' show Harness, actor, peer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('차단 명령은 본인 ID를 입력받지 않고 상대·상태·작업번호만 전송한다', () async {
    final h = Harness();
    await h.open();
    await h.session.initialize();
    addTearDown(h.close);
    await h.workspace.setChatBlocked(peer, true, 'block');
    expect(h.commands.last, {
      'command': 'setChatBlocked',
      'args': {'peerId': peer, 'blocked': true},
      'operation_id': 'block',
    });
    h.failWrite = true;
    await expectLater(
      h.workspace.setChatBlocked(peer, false, 'unblock'),
      throwsA(isA<AppFailure>()),
    );
  });

  for (final owner in [actor, peer]) {
    test('$owner 차단이면 outbox·RPC 호출 전 전송과 수정을 막는다', () async {
      final h = Harness();
      await h.open();
      await h.session.initialize();
      addTearDown(h.close);
      h.tables['chatBlocks'] = {
        'block': {
          'ownerId': owner,
          'peerId': owner == actor ? peer : actor,
          'blocked': true,
        },
      };
      h.tables['messages'] = {
        'existing': {
          'senderId': actor,
          'recipientId': peer,
          'body': '기존 대화',
          'status': 'sent',
        },
      };
      await h.store.refresh();
      expect(h.workspace.hasBlockedUser(peer), owner == actor);
      final count = h.commands.length;
      await expectLater(
        h.workspace.sendMessage(peer, 'retry', '', ['photo']),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        h.workspace.editMessage('existing', '수정', 0, 'edit'),
        throwsA(isA<AppFailure>()),
      );
      expect(h.commands.length, count);
      expect(await h.store.outbox.find(h.store.device), isEmpty);
    });
  }
}
