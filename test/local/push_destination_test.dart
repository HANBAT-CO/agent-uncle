import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'app_flow_test.dart' show drainClose, settle;
import 'workspace_test.dart' show Fixture;

// 화면 이동의 비동기 경합만 재현한다. 저장소 영속성은 저장소 테스트에서 확인한다.
class _PushSession extends LocalSessionRepository {
  _PushSession(super.store, this.account);
  Account? account;
  Record? destination;

  @override
  Account? get current => account;
  @override
  Record? get pendingDestination => destination;
  @override
  Future<void> setDestination(Data? value) async {
    destination = value == null ? null : Record('destination', value);
    notifyListeners();
  }

  void switchTo(Account value) {
    account = value;
    notifyListeners();
  }
}

class _DelayedReadWorkspace extends LocalWorkspaceRepository {
  _DelayedReadWorkspace(super.store, super.session);

  final reading = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> refreshReminders() async {}

  @override
  Future<void> readNotice(String id) async {
    // 서버에서는 읽음 응답을 기다리는 동안 다음 알림 탭이 도착할 수 있다.
    if (!reading.isCompleted) {
      reading.complete();
      await release.future;
    }
  }
}

void main() {
  testWidgets('읽음 처리 중 도착한 새 푸시의 목적지를 잃지 않는다', (tester) async {
    final f = Fixture();
    late String first, second, noticeId;
    await tester.runAsync(() async {
      await f.start();
      await f.session.finishOnboarding();
      first = await f.request();
      second = await f.request();
      await f.session.signIn(f.uncle);
      noticeId = f.workspace
          .records('notices')
          .firstWhere((notice) => notice.s('requestId') == first)
          .id;
    });
    final session = _PushSession(f.store, f.session.current);
    final workspace = _DelayedReadWorkspace(f.store, session);
    final app = AppServices(
      session: session,
      workspace: workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    await session.setDestination({
      'ownerId': f.uncle,
      'kind': 'request',
      'targetId': first,
      'noticeId': noticeId,
      'fromPush': true,
    });
    await settle(tester);
    expect(workspace.reading.isCompleted, isTrue);
    await session.setDestination({
      'ownerId': f.uncle,
      'kind': 'request',
      'targetId': second,
      'fromPush': true,
    });
    await settle(tester);
    workspace.release.complete();
    await settle(tester);

    expect(
      tester.widget<RequestDetailPage>(find.byType(RequestDetailPage)).id,
      second,
    );
    expect(session.pendingDestination, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await drainClose(tester, f.close());
  });

  testWidgets('읽음 처리 중 계정이 바뀌면 이전 계정의 화면을 열지 않는다', (tester) async {
    final f = Fixture();
    late String request, noticeId;
    await tester.runAsync(() async {
      await f.start();
      await f.session.finishOnboarding();
      request = await f.request();
      await f.session.signIn(f.uncle);
      noticeId = f.workspace
          .records('notices')
          .firstWhere((notice) => notice.s('requestId') == request)
          .id;
    });
    final session = _PushSession(f.store, f.session.current);
    final workspace = _DelayedReadWorkspace(f.store, session);
    final app = AppServices(
      session: session,
      workspace: workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    await session.setDestination({
      'ownerId': f.uncle,
      'kind': 'request',
      'targetId': request,
      'noticeId': noticeId,
      'fromPush': true,
    });
    await settle(tester);
    expect(workspace.reading.isCompleted, isTrue);
    session.switchTo(f.session.accounts.firstWhere((a) => a.id == f.retailer));
    await settle(tester);
    workspace.release.complete();
    await settle(tester);

    expect(find.byType(RequestDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await drainClose(tester, f.close());
  });
}
