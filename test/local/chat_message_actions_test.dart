import 'dart:typed_data';

import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workspace_test.dart' show Fixture;

void main() {
  late Fixture f;
  setUp(() async {
    f = Fixture();
    await f.start();
  });
  tearDown(() => f.close());
  Record message() =>
      f.workspace.records('messages').firstWhere((m) => m.id == 'm');

  test('수정은 같은 메시지의 시간·수신자·읽음을 보존하고 중복 실행하지 않는다', () async {
    await f.workspace.sendMessage(f.uncle, 'm', '원본', []);
    final original = message();
    await f.session.signIn(f.uncle);
    await f.workspace.markChatRead(f.retailer);
    await f.session.signIn(f.retailer);
    await f.workspace.editMessage('m', '  수정한 내용\n두 번째 줄  ', 0, 'edit');
    await f.workspace.editMessage('m', '  수정한 내용\n두 번째 줄  ', 0, 'edit');
    expect(message().s('body'), '수정한 내용\n두 번째 줄');
    expect(message().version, 1);
    expect(message().s('createdAt'), original.s('createdAt'));
    expect(message().s('recipientId'), f.uncle);
    expect(message().b('read'), isTrue);
    expect(message().s('editedAt'), isNotEmpty);
    await f.session.signIn(f.uncle);
    expect(message().s('body'), '수정한 내용\n두 번째 줄');
  });

  test('삭제는 양쪽에 남고 첨부 접근을 회수하며 재수정·재삭제·재전송으로 복원되지 않는다', () async {
    final photo = await f.attachments.save(
      '사진.png',
      Uint8List.fromList([1, 2, 3]),
      'image/png',
    );
    await f.workspace.sendMessage(f.uncle, 'm', '첨부 메시지', [photo]);
    final original = message();
    await f.session.signIn(f.uncle);
    expect(await f.attachments.bytes(photo), [1, 2, 3]);
    await f.session.signIn(f.retailer);
    await f.workspace.deleteMessage('m', 0, 'delete');
    final deleted = message().data;
    expect(message().b('deleted'), isTrue);
    expect(message().s('body'), isEmpty);
    expect(message().list('attachments'), isEmpty);
    expect(message().s('requestId'), isEmpty);
    expect(message().s('createdAt'), original.s('createdAt'));
    expect(message().s('status'), 'sent');
    expect(message().version, 1);
    await f.workspace.deleteMessage('m', 0, 'delete');
    await expectLater(
      f.workspace.editMessage('m', '복원', 1, 'edit-deleted'),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.deleteMessage('m', 1, 'delete-again'),
      throwsA(isA<AppFailure>()),
    );
    // 전송 작업 번호의 재실행은 무해한 중복이며 레코드를 다시 생성하지 않는다.
    await f.workspace.sendMessage(f.uncle, 'm', '복원', [photo]);
    expect(message().data, deleted);
    await f.session.signIn(f.uncle);
    expect(message().data, deleted);
    await expectLater(f.attachments.bytes(photo), throwsA(isA<AppFailure>()));
    await f.workspace.markChatRead(f.retailer);
    expect(message().b('read'), isTrue);
    expect(message().b('deleted'), isTrue);
  });

  test('타인과 시스템 메시지 및 실패 메시지는 변경할 수 없다', () async {
    await f.workspace.sendMessage(f.uncle, 'm', '원본', []);
    await f.session.signIn(f.uncle);
    await expectLater(
      f.workspace.editMessage('m', '도용', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.deleteMessage('m', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    await f.request();
    final system = f.workspace
        .records('messages')
        .firstWhere((m) => m.b('system'));
    await expectLater(
      f.workspace.editMessage(system.id, '변경', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.deleteMessage(system.id, 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    f.store.failNextWrite = true;
    await expectLater(
      f.workspace.sendMessage(f.uncle, 'failed', '실패', []),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.editMessage('failed', '변경', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.deleteMessage('failed', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
  });

  test('오래된 수정·삭제와 저장 실패는 기존 메시지를 보존한다', () async {
    await f.workspace.sendMessage(f.uncle, 'm', '원본', []);
    await f.workspace.editMessage('m', '최신', 0, 'edit');
    await expectLater(
      f.workspace.editMessage('m', '덮어쓰기', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.deleteMessage('m', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    f.store.failNextWrite = true;
    await expectLater(
      f.workspace.deleteMessage('m', 1, 'delete'),
      throwsA(isA<AppFailure>()),
    );
    expect(message().s('body'), '최신');
    expect(message().b('deleted'), isFalse);
    await f.workspace.deleteMessage('m', 1, 'delete');
    expect(message().b('deleted'), isTrue);
  });

  test('빈 본문은 텍스트 메시지에서 거절하고 사진 캡션에서는 허용한다', () async {
    await f.workspace.sendMessage(f.uncle, 'm', '원본', []);
    await expectLater(
      f.workspace.editMessage('m', '  ', 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      f.workspace.editMessage('m', '가' * 10001, 0, newId()),
      throwsA(isA<AppFailure>()),
    );
    final photo = await f.attachments.save(
      '사진.png',
      Uint8List.fromList([1]),
      'image/png',
    );
    await f.workspace.sendMessage(f.uncle, 'photo', '캡션', [photo]);
    await f.workspace.editMessage('photo', '', 0, newId());
    final record = f.workspace
        .records('messages')
        .firstWhere((m) => m.id == 'photo');
    expect(record.s('body'), isEmpty);
    expect(record.list('attachments'), [photo]);
    expect(message().s('body'), '원본');
  });
}
