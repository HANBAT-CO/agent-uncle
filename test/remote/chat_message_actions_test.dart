import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';

import 'repositories_test.dart' show Harness, actor, peer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.open();
    await h.session.initialize();
  });
  tearDown(() => h.close());

  test('수정·삭제는 버전과 작업 번호를 RPC로 보내고 실패 시 원본을 유지한다', () async {
    h.tables['messages'] = {
      'm': {
        'senderId': actor,
        'recipientId': peer,
        'body': '원본',
        'status': 'sent',
        'version': 3,
      },
    };
    await h.store.refresh();
    await h.workspace.editMessage('m', ' 수정 ', 3, 'edit');
    expect(h.commands.last, {
      'command': 'editMessage',
      'args': {'id': 'm', 'body': '수정', 'version': 3},
      'operation_id': 'edit',
    });
    h.failWrite = true;
    await expectLater(
      h.workspace.deleteMessage('m', 3, 'delete'),
      throwsA(isA<AppFailure>()),
    );
    expect(h.commands.last, {
      'command': 'deleteMessage',
      'args': {'id': 'm', 'version': 3},
      'operation_id': 'delete',
    });
    expect(h.workspace.records('messages').single.s('body'), '원본');
    expect(await h.store.outbox.find(h.store.device), isEmpty);
  });

  test('삭제 표시된 서버 메시지는 재전송 및 로컬 outbox 생성이 불가능하다', () async {
    h.tables['messages'] = {
      'm': {
        'senderId': actor,
        'recipientId': peer,
        'body': '',
        'status': 'sent',
        'deleted': true,
        'version': 1,
      },
    };
    await h.store.refresh();
    final count = h.commands.length;
    expect(h.store.snapshot.get('messages', 'm')?.b('deleted'), isTrue);
    await expectLater(
      h.workspace.sendMessage(peer, 'm', '복원 시도', []),
      throwsA(isA<AppFailure>()),
    );
    expect(h.commands.length, count);
    expect(h.workspace.records('messages').single.b('deleted'), isTrue);
    expect(await h.store.outbox.find(h.store.device), isEmpty);
  });

  test('이미 수신한 서버 메시지를 재전송 실패 초안으로 덮지 않는다', () async {
    h.tables['messages'] = {
      'm': {
        'senderId': actor,
        'recipientId': peer,
        'body': '서버 최신 내용',
        'status': 'sent',
        'version': 2,
      },
    };
    await h.store.refresh();
    h.failWrite = true;
    await expectLater(
      h.workspace.sendMessage(peer, 'm', '예전 초안', []),
      throwsA(isA<AppFailure>()),
    );
    expect(h.workspace.records('messages').single.s('body'), '서버 최신 내용');
    expect(h.workspace.records('messages').single.s('status'), 'sent');
    expect(await h.store.outbox.find(h.store.device), isEmpty);
  });
}
