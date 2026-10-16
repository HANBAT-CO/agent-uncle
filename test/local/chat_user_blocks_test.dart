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

  test('차단은 양방향 전송·사진·수정을 막고 기존 대화와 알림을 보존한다', () async {
    await f.workspace.sendMessage(f.uncle, 'before', '기존 대화', []);
    final message = f.workspace.records('messages').single;
    final notices = f.store.snapshot.all('notices').length;
    await f.workspace.setChatBlocked(f.uncle, true, 'block');
    expect(f.workspace.hasBlockedUser(f.uncle), isTrue);
    for (final photos in [
      <String>[],
      ['photo'],
    ]) {
      await expectLater(
        f.workspace.sendMessage(f.uncle, 'blocked', '확인', photos),
        throwsA(isA<AppFailure>()),
      );
    }
    await expectLater(
      f.workspace.editMessage('before', '수정', message.version, 'edit'),
      throwsA(isA<AppFailure>()),
    );
    expect(f.workspace.records('messages').single.data, message.data);
    expect(f.store.snapshot.all('notices').length, notices);
    await f.session.signIn(f.uncle);
    expect(f.workspace.hasBlockedUser(f.retailer), isFalse);
    expect(f.workspace.isChatBlocked(f.retailer), isTrue);
    await expectLater(
      f.workspace.sendMessage(f.retailer, 'reverse', '확인', []),
      throwsA(isA<AppFailure>()),
    );
    await f.workspace.markChatRead(f.retailer);
    expect(f.workspace.records('messages').single.b('read'), isTrue);
    await f.session.signIn(f.retailer);
    await f.workspace.deleteMessage('before', message.version, 'delete');
    expect(f.workspace.records('messages').single.b('deleted'), isTrue);
  });

  test('서로 차단하면 양쪽 모두 해제해야 대화가 재개된다', () async {
    await f.workspace.setChatBlocked(f.uncle, true, 'retailer-block');
    await f.session.signIn(f.uncle);
    await f.workspace.setChatBlocked(f.retailer, true, 'uncle-block');
    await f.workspace.setChatBlocked(f.retailer, false, 'uncle-unblock');
    expect(f.workspace.isChatBlocked(f.retailer), isTrue);
    await f.session.signIn(f.retailer);
    await f.workspace.setChatBlocked(f.uncle, false, 'retailer-unblock');
    expect(f.workspace.isChatBlocked(f.uncle), isFalse);
    await f.workspace.sendMessage(f.uncle, 'resumed', '다시 대화', []);
    expect(f.workspace.records('messages').single.s('body'), '다시 대화');
  });

  test('차단 상태는 다시 읽어도 유지되고 제삼자에게 노출되지 않는다', () async {
    await f.workspace.setChatBlocked(f.uncle, true, 'block');
    await f.store.reload();
    expect(f.workspace.isChatBlocked(f.uncle), isTrue);
    await f.account('다른 매장', AppRole.retailer);
    expect(f.workspace.records('chatBlocks'), isEmpty);
    expect(f.workspace.isChatBlocked(f.uncle), isFalse);
    await expectLater(
      f.workspace.setChatBlocked(f.uncle, true, 'stranger'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('저장 실패 시 차단 상태를 바꾸지 않고 재시도할 수 있다', () async {
    f.store.failNextWrite = true;
    await expectLater(
      f.workspace.setChatBlocked(f.uncle, true, 'block'),
      throwsA(isA<AppFailure>()),
    );
    expect(f.workspace.isChatBlocked(f.uncle), isFalse);
    await f.workspace.setChatBlocked(f.uncle, true, 'block');
    expect(f.workspace.isChatBlocked(f.uncle), isTrue);
    await expectLater(
      f.workspace.setChatBlocked(f.retailer, true, 'self'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('차단 전에 실패한 메시지도 차단 중에는 재전송할 수 없다', () async {
    f.store.failNextWrite = true;
    await expectLater(
      f.workspace.sendMessage(f.uncle, 'retry', '확인 부탁드려요', []),
      throwsA(isA<AppFailure>()),
    );
    expect(f.workspace.records('messages').single.s('status'), 'failed');
    await f.workspace.setChatBlocked(f.uncle, true, 'block');
    await expectLater(
      f.workspace.sendMessage(f.uncle, 'retry', '확인 부탁드려요', []),
      throwsA(isA<AppFailure>()),
    );
    expect(f.workspace.records('messages').single.s('status'), 'failed');
    await f.workspace.setChatBlocked(f.uncle, false, 'unblock');
    await f.workspace.sendMessage(f.uncle, 'retry', '확인 부탁드려요', []);
    expect(f.workspace.records('messages').single.s('status'), 'sent');
  });

  test('차단 후에도 사입 업무와 시스템 기록은 정상 처리한다', () async {
    final request = await f.request();
    await f.workspace.setChatBlocked(f.uncle, true, 'block');
    await f.accept(request);
    expect(f.workspace.request(request)!.s('status'), 'accepted');
    expect(
      f.workspace.records('messages').where((m) => m.b('system')),
      isNotEmpty,
    );
    await f.session.deleteAccount();
    expect(f.store.snapshot.all('chatBlocks'), isEmpty);
  });
}
