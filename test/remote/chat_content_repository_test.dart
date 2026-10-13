import 'package:agent_uncle/local/domain/chat_content_policy.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';

import 'repositories_test.dart' show Harness, peer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('비속어 수정은 원격 RPC를 호출하지 않는다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    final count = h.commands.length;
    await expectLater(
      h.workspace.editMessage('editable', 'sh1t', 0, 'edit-filtered'),
      throwsA(isA<AppFailure>()),
    );
    expect(h.commands.length, count);
    await h.workspace.editMessage('editable', '확인 감사합니다', 0, 'edit-filtered');
    expect(h.commands.last['command'], 'editMessage');
    expect(h.commands.last['args']['body'], '확인 감사합니다');
  });

  test('원격 전송은 비속어 검사 후에만 outbox와 RPC를 사용한다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    final count = h.commands.length;
    for (final body in ['시1발', 'sh1t', 'ㅅㅣㅂㅏㄹ']) {
      await expectLater(
        h.workspace.sendMessage(peer, 'filtered', body, ['photo']),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            ChatContentPolicy.rejectionMessage,
          ),
        ),
      );
    }
    expect(h.commands.length, count);
    expect(await h.store.outbox.find(h.store.device), isEmpty);
    expect(h.workspace.records('messages'), isEmpty);

    const original = 'shirt 18개\n확인 부탁드려요.';
    await h.workspace.sendMessage(peer, 'filtered', original, []);
    expect(h.commands.last['args']['body'], original);
    expect(h.commands.last['operation_id'], 'filtered');
    expect(await h.store.outbox.find(h.store.device), isEmpty);
  });

  test('사진만 보내는 원격 메시지는 허용한다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    await h.workspace.sendMessage(peer, 'photo-only', '', ['photo']);
    expect(h.commands.last['args']['body'], '');
    expect(h.commands.last['args']['attachments'], ['photo']);
  });
}
