import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'workspace_test.dart' show Fixture;

void main() {
  test(
    'file database restores session, drafts, attachments and delivery receipts after close',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'saip-persistence-',
      );
      final path = '${directory.path}/workspace.db';
      final f = Fixture();
      await f.start(factory: databaseFactoryIo, path: path);
      try {
        await f.session.finishOnboarding();
        await f.session.saveProfile({
          'salesChannel': '온라인',
          'markets': ['동대문', '남대문'],
        });
        final request = await f.request();
        await f.accept(request);
        await f.session.saveProfile({
          'transport': '오토바이',
          'activityHours': '야간 22–06',
          'activityStart': '22:00',
          'activityEnd': '06:00',
          'activityDays': ['월', '수', '금'],
        });
        await f.result(request, 2, 1);
        final delivery = await f.deliver(request, 1);
        await f.receive(delivery, 1);
        await f.workspace.saveDraft('ongoing-draft', {'product': '이어 쓰는 요청'});
        final documentId = f.session.current!.s('documentId');
        await f.close();
        f.store = LocalStore(await databaseFactoryIo.openDatabase(path));
        await f.store.initialize();
        f.session = LocalSessionRepository(f.store);
        f.workspace = LocalWorkspaceRepository(f.store, f.session);
        f.attachments = LocalAttachmentRepository(
          f.store,
          f.session,
          f.workspace,
        );
        expect(f.session.onboardingSeen, isTrue);
        expect(f.session.current!.id, f.retailer);
        expect(f.session.current!.s('salesChannel'), '온라인');
        expect(f.session.current!.list('markets'), ['동대문', '남대문']);
        expect(f.workspace.records('drafts').single.s('product'), '이어 쓰는 요청');
        expect(await f.attachments.bytes(documentId), isNotEmpty);
        expect(f.workspace.records('receipts').single.n('confirmed'), 1);
        expect(f.workspace.request(request)!.backorder, 1);
        await f.session.signIn(f.uncle);
        expect(f.workspace.records('drafts'), isEmpty);
        expect(f.session.current!.s('transport'), '오토바이');
        expect(f.session.current!.s('activityStart'), '22:00');
        expect(f.session.current!.s('activityEnd'), '06:00');
        expect(f.session.current!.list('activityDays'), ['월', '수', '금']);
        expect(f.workspace.request(request)!.received, 1);
      } finally {
        await f.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
