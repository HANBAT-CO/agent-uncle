import 'package:agent_uncle/local/domain/chat_content_policy.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workspace_test.dart' show Fixture;

void main() {
  test('보낸 메시지를 비속어로 수정하면 본문·버전을 유지한다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    await f.workspace.sendMessage(f.uncle, 'editable', '확인 부탁드려요', []);
    final before = f.workspace.records('messages').single;
    await expectLater(
      f.workspace.editMessage(
        'editable',
        '시1발',
        before.version,
        'edit-filtered',
      ),
      throwsA(isA<AppFailure>()),
    );
    final after = f.workspace.records('messages').single;
    expect(after.data, before.data);
    await f.workspace.editMessage(
      'editable',
      '확인 감사합니다',
      before.version,
      'edit-filtered',
    );
    expect(f.workspace.records('messages').single.s('body'), '확인 감사합니다');
  });

  test('차단한 메시지·실패 기록·알림을 저장하지 않고 수정 후 같은 ID로 전송한다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    final before = f.store.snapshot.all('notices').length;
    for (final text in ['시1발', 'f.u.c.k']) {
      await expectLater(
        f.workspace.sendMessage(f.uncle, 'filtered', text, []),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            ChatContentPolicy.rejectionMessage,
          ),
        ),
      );
      expect(f.workspace.records('messages'), isEmpty);
      expect(f.store.snapshot.all('notices').length, before);
    }
    const original = 'Ｆ 품목 18개\n확인 부탁드려요.';
    await f.workspace.sendMessage(f.uncle, 'filtered', original, []);
    expect(f.workspace.records('messages').single.s('body'), original);
    await f.session.signIn(f.uncle);
    expect(f.workspace.records('messages').single.s('body'), original);
    expect(
      f.workspace.records('notices').where((n) => n.s('title') == original),
      hasLength(1),
    );
  });
}
