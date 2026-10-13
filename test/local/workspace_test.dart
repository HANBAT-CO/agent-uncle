import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/domain/models.dart';

class Fixture {
  late LocalStore store;
  late LocalSessionRepository session;
  late LocalWorkspaceRepository workspace;
  late LocalAttachmentRepository attachments;
  late String retailer, uncle;
  Future<void> start({DatabaseFactory? factory, String? path}) async {
    store = LocalStore(
      await (factory ?? databaseFactoryMemory).openDatabase(path ?? newId()),
    );
    await store.initialize();
    session = LocalSessionRepository(store);
    workspace = LocalWorkspaceRepository(store, session);
    attachments = LocalAttachmentRepository(store, session, workspace);
    retailer = await account('소매 매장', AppRole.retailer);
    uncle = await account('사입 업체', AppRole.uncle);
    await session.signIn(retailer);
    final connection = await workspace.connect(uncle, newId());
    await session.signIn(uncle);
    await workspace.respondConnection(connection, 'accepted', 0, newId());
    await session.signIn(retailer);
  }

  Future<String> account(String label, AppRole role) async {
    final id = await session.createAccount(label);
    await session.chooseRole(role);
    final file = await attachments.save(
      '사업자.pdf',
      Uint8List.fromList([37, 80, 68, 70]),
      'application/pdf',
    );
    await session.saveProfile({
      'name': label,
      'contact': role == AppRole.uncle ? label : '담당자',
      'phone': '01012345678',
      'businessName': label,
      'businessNumber': '1234567890',
      'documentId': file,
      'address': '서울시 중구',
      'addressDetail': '101호',
      'pickupArea': '동대문 1층',
      'deliveryArea': '서울',
      'deadline': '22:00',
      'salesChannel': '온라인',
      'terms': true,
      'privacy': true,
    }, complete: true);
    return id;
  }

  Future<String> request({int quantity = 3}) async {
    await session.signIn(retailer);
    final id = newId();
    await workspace.saveDraft(id, {
      'uncleId': uncle,
      'wholesaler': '도매상',
      'location': '상가 2층',
      'product': '셔츠',
      'option': '흰색 M',
      'quantity': quantity,
      'address': '서울시 중구',
      'addressDetail': '101호',
    });
    await workspace.sendDraft(id, 'send-$id');
    return id;
  }

  Future<void> accept(String id) async {
    await session.signIn(uncle);
    await workspace.act(
      id,
      'accept',
      {},
      workspace.request(id)!.version,
      newId(),
    );
  }

  Future<void> result(String id, int acquired, int backorder) async {
    await session.signIn(uncle);
    await workspace.act(
      id,
      'result',
      {
        'acquired': acquired,
        'backorder': backorder,
        'recheck': '2026-10-12',
        'reason': '미송 확인',
        'needsReply': true,
      },
      workspace.request(id)!.version,
      newId(),
    );
  }

  Future<String> deliver(String id, int n) async {
    await session.signIn(uncle);
    await workspace.deliver(
      {id: n},
      {id: workspace.request(id)!.version},
      newId(),
    );
    return workspace.records('deliveries').first.id;
  }

  Future<void> receive(String id, int n, {String reason = ''}) async {
    await session.signIn(retailer);
    final d = workspace.records('deliveries').firstWhere((d) => d.id == id);
    await workspace.receive(id, n, reason, d.version, newId());
  }

  Future<void> close() async {
    workspace.dispose();
    session.dispose();
    await store.close();
  }
}

void main() {
  late Fixture f;
  setUp(() async {
    f = Fixture();
    await f.start();
  });
  tearDown(() async {
    await f.close();
  });
  test(
    'A: full pickup, delivery and retailer receipt completes on both accounts',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 3, 0);
      final d = await f.deliver(id, 3);
      expect(f.workspace.request(id)!.s('status'), 'accepted');
      await f.receive(d, 3);
      expect(f.workspace.request(id)!.s('status'), 'completed');
      await f.session.signIn(f.uncle);
      expect(f.workspace.request(id)!.received, 3);
    },
  );
  test(
    'B: two receipts keep missing stock open and add only remaining delivery',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 2, 1);
      await f.session.signIn(f.retailer);
      await f.workspace.act(
        id,
        'wait',
        {},
        f.workspace.request(id)!.version,
        newId(),
      );
      await f.receive(await f.deliver(id, 2), 2);
      expect(f.workspace.request(id)!.s('status'), 'accepted');
      expect(f.workspace.request(id)!.backorder, 1);
      await f.result(id, 3, 0);
      expect(f.workspace.request(id)!.available, 1);
      await f.receive(await f.deliver(id, 1), 1);
      expect(f.workspace.request(id)!.s('status'), 'completed');
      expect(f.workspace.records('deliveries').length, 2);
    },
  );
  test(
    'C: repeating snapshots a new draft and current address without progress',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 2, 1);
      await f.session.signIn(f.retailer);
      await f.session.saveProfile({'address': '새 주소'});
      final copy = await f.workspace.repeatRequest(id);
      final d = f.workspace.records('drafts').single;
      expect(copy, isNot(id));
      expect(d.s('address'), '새 주소');
      expect(d.n('acquired'), 0);
      expect(f.workspace.request(id)!.s('address'), '서울시 중구');
    },
  );
  test(
    'draft retries create one request and one linked event; failure rolls back all',
    () async {
      final id = newId();
      await f.workspace.saveDraft(id, {
        'uncleId': f.uncle,
        'wholesaler': '도매',
        'location': '1층',
        'product': '셔츠',
        'option': 'S',
        'quantity': 3,
        'address': '주소',
        'addressDetail': '1층',
      });
      f.store.failNextWrite = true;
      await expectLater(
        f.workspace.sendDraft(id, 'same'),
        throwsA(isA<AppFailure>()),
      );
      expect(f.workspace.records('drafts'), hasLength(1));
      expect(f.workspace.records('requests'), isEmpty);
      expect(f.workspace.records('messages'), isEmpty);
      await f.workspace.sendDraft(id, 'same');
      await f.workspace.sendDraft(id, 'same');
      await f.workspace.sendDraft(id, 'different-retry');
      expect(f.workspace.records('requests'), hasLength(1));
      expect(f.workspace.records('events'), hasLength(1));
      expect(f.workspace.records('drafts'), isEmpty);
    },
  );
  test(
    'preaccept cancellation blocks accept and stale revisions are rejected',
    () async {
      final id = await f.request();
      final v = f.workspace.request(id)!.version;
      await f.workspace.act(id, 'cancel', {}, v, newId());
      await f.session.signIn(f.uncle);
      await expectLater(
        f.workspace.act(id, 'accept', {}, v, newId()),
        throwsA(isA<AppFailure>()),
      );
      expect(f.workspace.request(id)!.s('status'), 'cancelled');
    },
  );
  test(
    'cancel unpicked stock does not subtract available picked stock twice',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 2, 1);
      await f.session.signIn(f.retailer);
      await f.workspace.propose(
        id,
        'cancel',
        {'quantity': 1, 'acquiredCancelled': 0, 'reason': '미송 잔량 취소'},
        f.workspace.request(id)!.version,
        newId(),
      );
      expect(f.workspace.request(id)!.available, 2);
      final p = f.workspace.records('proposals').single;
      await f.session.signIn(f.uncle);
      await f.workspace.respondProposal(p.id, true, p.version, newId());
      expect(f.workspace.request(id)!.available, 2);
      expect(f.workspace.request(id)!.quantity, 3);
      expect(f.workspace.request(id)!.cancelled, 1);
      await f.receive(await f.deliver(id, 2), 2);
      expect(f.workspace.request(id)!.s('status'), 'completed');
    },
  );
  test(
    'picked cancellation holds only affected quantity and cannot self approve',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 3, 0);
      await f.session.signIn(f.retailer);
      await f.workspace.propose(
        id,
        'cancel',
        {'quantity': 1, 'acquiredCancelled': 1, 'reason': '한 장 반품 협의'},
        f.workspace.request(id)!.version,
        newId(),
      );
      final p = f.workspace.records('proposals').single;
      expect(f.workspace.request(id)!.available, 2);
      await expectLater(
        f.workspace.respondProposal(p.id, true, p.version, newId()),
        throwsA(isA<AppFailure>()),
      );
      await f.session.signIn(f.uncle);
      await f.workspace.respondProposal(p.id, true, p.version, newId());
      expect(f.workspace.request(id)!.available, 2);
      await expectLater(
        f.workspace.deliver(
          {id: 3},
          {id: f.workspace.request(id)!.version},
          newId(),
        ),
        throwsA(isA<AppFailure>()),
      );
      await f.receive(await f.deliver(id, 2), 2);
      expect(f.workspace.request(id)!.s('status'), 'completed');
    },
  );
  test(
    'over receipt stays capped until approved correction and issue resolution',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 3, 0);
      final d = await f.deliver(id, 2);
      await f.receive(d, 3, reason: '한 장 더 받았어요');
      expect(f.workspace.request(id)!.received, 2);
      expect(f.workspace.request(id)!.n('openIssues'), 1);
      await f.session.signIn(f.uncle);
      await f.workspace.propose(
        id,
        'correction',
        {
          'deliveryId': d,
          'quantity': 3,
          'received': 3,
          'acquired': 3,
          'reason': '전달 입력 정정',
        },
        f.workspace.request(id)!.version,
        newId(),
      );
      final p = f.workspace.records('proposals').single;
      expect(f.workspace.request(id)!.delivered, 2);
      await f.session.signIn(f.retailer);
      await f.workspace.respondProposal(p.id, true, p.version, newId());
      expect(f.workspace.request(id)!.received, 3);
      final receipts = f.workspace.records('receipts');
      expect(receipts, hasLength(2));
      final original = receipts.singleWhere(
        (r) => r.s('kind') == 'confirmation',
      );
      expect(original.n('actual'), 3);
      expect(original.n('confirmed'), 2);
      expect(f.workspace.request(id)!.s('status'), 'accepted');
      final issue = f.workspace.records('issues').single;
      await f.workspace.actOnIssue(
        issue.id,
        'resolve',
        '',
        issue.version,
        newId(),
      );
      expect(f.workspace.request(id)!.s('status'), 'completed');
    },
  );
  test(
    'issue holds exclude delivery and only retailer resolves after action',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 3, 0);
      await f.session.signIn(f.retailer);
      await f.workspace.reportIssue(
        id,
        {'reason': '옵션 확인', 'held': 1},
        f.workspace.request(id)!.version,
        newId(),
      );
      expect(f.workspace.request(id)!.available, 2);
      final issue = f.workspace.records('issues').single;
      await f.session.signIn(f.uncle);
      await expectLater(
        f.workspace.actOnIssue(issue.id, 'resolve', '', issue.version, newId()),
        throwsA(isA<AppFailure>()),
      );
      await f.workspace.actOnIssue(
        issue.id,
        'action',
        '옵션 확인 완료',
        issue.version,
        newId(),
      );
      await f.session.signIn(f.retailer);
      await f.workspace.actOnIssue(
        issue.id,
        'resolve',
        '',
        issue.version + 1,
        newId(),
      );
      expect(f.workspace.request(id)!.available, 3);
    },
  );
  test(
    'private drafts, documents, requests and notifications are account scoped',
    () async {
      final id = await f.request();
      await f.session.signIn(f.retailer);
      await f.workspace.saveDraft(newId(), {'product': '비공개'});
      final document = f.session.current!.s('documentId');
      final third = await f.account('다른 매장', AppRole.retailer);
      expect(third, isNot(f.retailer));
      expect(f.workspace.request(id), isNull);
      expect(f.workspace.records('drafts'), isEmpty);
      expect(f.workspace.records('notices'), isEmpty);
      await expectLater(
        f.attachments.bytes(document),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        f.workspace.act(id, 'cancel', {}, 0, newId()),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'reading messages never accepts request; failed message retries once',
    () async {
      final id = await f.request();
      await f.workspace.sendMessage(f.uncle, 'message-1', '확인했어요', []);
      await f.session.signIn(f.uncle);
      await f.workspace.markChatRead(f.retailer);
      expect(f.workspace.request(id)!.s('status'), 'pending');
      f.store.failNextWrite = true;
      await expectLater(
        f.workspace.sendMessage(f.retailer, 'message-2', '답변', []),
        throwsA(isA<AppFailure>()),
      );
      expect(
        f.workspace
            .records('messages')
            .firstWhere((m) => m.id == 'message-2')
            .s('status'),
        'failed',
      );
      await f.session.signIn(f.retailer);
      expect(
        f.workspace.records('messages').where((m) => m.id == 'message-2'),
        isEmpty,
      );
      await f.session.signIn(f.uncle);
      await f.workspace.sendMessage(f.retailer, 'message-2', '답변', []);
      await f.workspace.sendMessage(f.retailer, 'message-2', '답변', []);
      expect(
        f.workspace.records('messages').where((m) => m.id == 'message-2'),
        hasLength(1),
      );
    },
  );
  test(
    'draft, session, attachment and incomplete signup restore from database',
    () async {
      final draft = newId();
      await f.workspace.saveDraft(draft, {'product': '초안'});
      await f.store.reload();
      final another = LocalSessionRepository(f.store);
      expect(another.current!.id, f.retailer);
      expect(f.workspace.records('drafts').single.s('product'), '초안');
      expect(
        await f.attachments.bytes(f.session.current!.s('documentId')),
        Uint8List.fromList([37, 80, 68, 70]),
      );
      another.dispose();
      final id = await f.session.createAccount('가입 중');
      await f.session.chooseRole(AppRole.uncle);
      await f.session.saveProfile({'name': '이어 쓰기'});
      await f.session.signOut();
      await f.session.signIn(id);
      expect(f.session.current!.complete, false);
      expect(f.session.current!.name, '이어 쓰기');
      expect(f.session.current!.role, AppRole.uncle);
    },
  );
  test(
    'acquisition-only correction preserves receipt floor and requires agreement',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 3, 0);
      await f.workspace.propose(
        id,
        'correction',
        {'acquired': 2, 'reason': '픽업 수량 재확인', 'recheck': '2026-10-13'},
        f.workspace.request(id)!.version,
        newId(),
      );
      expect(f.workspace.request(id)!.acquired, 3);
      final proposal = f.workspace.records('proposals').single;
      await f.session.signIn(f.retailer);
      await f.workspace.respondProposal(
        proposal.id,
        true,
        proposal.version,
        newId(),
      );
      expect(f.workspace.request(id)!.acquired, 2);
      expect(f.workspace.request(id)!.backorder, 1);
      expect(f.workspace.request(id)!.needsReply, isTrue);
      expect(f.workspace.request(id)!.s('recheck'), '2026-10-13');
    },
  );
  test(
    'multi-request delivery is atomic and preserves each address snapshot',
    () async {
      final first = await f.request();
      final second = await f.request();
      await f.accept(first);
      await f.result(first, 3, 0);
      await f.accept(second);
      await f.result(second, 3, 0);
      final versions = {
        first: f.workspace.request(first)!.version,
        second: f.workspace.request(second)!.version,
      };
      await expectLater(
        f.workspace.deliver({first: 1, second: 4}, versions, newId()),
        throwsA(isA<AppFailure>()),
      );
      expect(f.workspace.records('deliveries'), isEmpty);
      await f.workspace.deliver({first: 1, second: 2}, versions, newId());
      expect(f.workspace.records('deliveries'), hasLength(2));
      await f.session.signIn(f.retailer);
      await f.session.saveProfile({'address': '다른 주소'});
      expect(
        f.workspace
            .records('deliveries')
            .every((d) => d.s('address') == '서울시 중구'),
        isTrue,
      );
    },
  );
  test(
    'expired code, connection withdrawal, and duplicate acceptance are explicit',
    () async {
      final third = await f.account('새 매장', AppRole.retailer);
      await f.store.write(f.uncle, '', (s) {
        final a = s.require('accounts', f.uncle);
        s.put('accounts', f.uncle, {...a, 'codeExpires': '2000-01-01'});
        return '';
      });
      final code = f.store.snapshot.get('accounts', f.uncle)!.s('code');
      await expectLater(
        f.workspace.lookupCode(code),
        throwsA(isA<AppFailure>()),
      );
      await f.session.signIn(f.uncle);
      await f.workspace.renewCode();
      await f.session.signIn(third);
      final id = await f.workspace.connect(f.uncle, newId());
      await f.workspace.respondConnection(id, 'withdrawn', 0, newId());
      await f.session.signIn(f.uncle);
      await expectLater(
        f.workspace.respondConnection(id, 'accepted', 0, newId()),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'closing and reopening storage restores session and full transaction history',
    () async {
      final id = await f.request();
      await f.accept(id);
      await f.result(id, 2, 1);
      final path = f.store.database.path;
      f.workspace.dispose();
      f.session.dispose();
      await f.store.close();
      f.store = LocalStore(await databaseFactoryMemory.openDatabase(path));
      await f.store.initialize();
      f.session = LocalSessionRepository(f.store);
      f.workspace = LocalWorkspaceRepository(f.store, f.session);
      f.attachments = LocalAttachmentRepository(
        f.store,
        f.session,
        f.workspace,
      );
      expect(f.session.current!.id, f.uncle);
      expect(f.workspace.request(id)!.acquired, 2);
      expect(f.workspace.records('events'), hasLength(3));
      expect(
        await f.attachments.bytes(f.session.current!.s('documentId')),
        isNotEmpty,
      );
    },
  );
}
