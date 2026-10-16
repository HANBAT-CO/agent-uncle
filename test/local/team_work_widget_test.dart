import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/team_commands.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/workflow_payload.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/team_work.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, drainWork, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

Future<String> _createUncle(
  Fixture fixture,
  String label,
  String nickname,
) async {
  final id = await fixture.account(label, AppRole.uncle);
  await fixture.session.saveProfile({'nickname': nickname});
  return id;
}

Future<String> _runTeam(
  Fixture fixture,
  String actor,
  String command,
  Data args,
) {
  return fixture.store.write(
    actor,
    newId(),
    (state) => applyTeam(state, actor, command, args),
  );
}

Future<void> _connectAccepted(
  Fixture fixture,
  String owner,
  String peer,
) async {
  final id = await _runTeam(fixture, owner, 'connectColleague', {
    'peerId': peer,
  });
  await _runTeam(fixture, peer, 'respondColleagueConnection', {
    'id': id,
    'status': 'accepted',
    'version': 1,
  });
}

Future<void> _seedAcceptedRequest(
  Fixture fixture, {
  required String id,
  required String uncleId,
  required String retailerName,
  required String wholesalerName,
  required String location,
}) {
  return fixture.store.write(uncleId, newId(), (state) {
    state.put('requests', id, {
      'retailerId': fixture.retailer,
      'uncleId': uncleId,
      'status': 'accepted',
      'businessName': retailerName,
      'name': retailerName,
      'wholesaler': wholesalerName,
      'location': location,
      'wholesalers': [
        {
          'wholesaler': wholesalerName,
          'location': location,
          'paymentMode': 'review',
        },
      ],
      'createdAt': '2026-10-15T00:00:00Z',
      'updatedAt': '2026-10-15T00:00:00Z',
      'version': 0,
    });
    return id;
  });
}

Widget _framed(String title, Widget child) =>
    PageFrame(title: title, children: [child]);

Map<String, int> _packageVersions(Fixture fixture, Iterable<String> ids) => {
  for (final id in ids)
    id: fixture.store.snapshot.get('teamPackages', id)!.n('version'),
};

Future<Map<String, Data>> _operations(Fixture fixture) async {
  final rows = await fixture.store
      .table('operations')
      .find(fixture.store.database);
  return {for (final row in rows) row.key: row.value};
}

Future<void> _pumpTeamPage(
  WidgetTester tester,
  Fixture fixture,
  Widget page, {
  bool registerCleanup = true,
}) async {
  final services = AppServices(
    session: fixture.session,
    workspace: fixture.workspace,
    attachments: fixture.attachments,
  );
  if (registerCleanup) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, fixture.close());
    });
  }
  await tester.pumpWidget(AppScope(services: services, child: branded(page)));
  await settle(tester);
}

void main() {
  testWidgets('연결 화면이 같은 팀 동료와 팀 초대 응답 대기를 구분한다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final picker = await _createUncle(fixture, '팀 동료 계정', '팀 동료');
      final outside = await _createUncle(fixture, '외부 동료 계정', '외부 동료');
      final invited = await _createUncle(fixture, '초대 대기 계정', '초대 대기');
      await _connectAccepted(fixture, owner, picker);
      await _connectAccepted(fixture, owner, outside);
      await _connectAccepted(fixture, owner, invited);
      final teamId = await _runTeam(fixture, owner, 'createTeam', {
        'name': '동대문 A팀',
      });
      final invitePicker = await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': picker,
      });
      await _runTeam(fixture, picker, 'respondTeamInvite', {
        'id': invitePicker,
        'status': 'accepted',
        'version': 1,
      });
      await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': invited,
        'note': '야간 회차 같이 맡아요',
      });
      await fixture.session.signIn(owner);
    });

    await _pumpTeamPage(
      tester,
      fixture,
      _framed('팀 연결', const UncleTeamConnections()),
    );

    expect(find.text('팀 동료'), findsOneWidget);
    expect(find.text('같은 팀 · 동대문 A팀'), findsOneWidget);
    expect(find.text('외부 동료'), findsAtLeastNWidgets(1));

    await tester.tap(find.textContaining('초대').first);
    await settle(tester);
    expect(find.text('팀 초대 · 응답 대기'), findsOneWidget);
    expect(find.text('응답 대기 초대 대기'), findsOneWidget);
    expect(find.text('야간 회차 같이 맡아요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('대화 화면이 최근 대화와 1:1 기록을 함께 보여 준다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final picker = await _createUncle(fixture, '팀 동료 계정', '팀 동료');
      final outside = await _createUncle(fixture, '외부 동료 계정', '외부 동료');
      await _connectAccepted(fixture, owner, picker);
      await _connectAccepted(fixture, owner, outside);
      final teamId = await _runTeam(fixture, owner, 'createTeam', {
        'name': '남평화 단체방',
      });
      final inviteId = await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': picker,
      });
      await _runTeam(fixture, picker, 'respondTeamInvite', {
        'id': inviteId,
        'status': 'accepted',
        'version': 1,
      });
      await _runTeam(fixture, picker, 'sendTeamMessage', {
        'teamId': teamId,
        'body': '남평화 단체방 메모',
      });
      await _runTeam(fixture, outside, 'sendColleagueMessage', {
        'peerId': owner,
        'body': '외부 동료 메모',
      });
      await fixture.session.signIn(owner);
    });

    await _pumpTeamPage(
      tester,
      fixture,
      _framed('팀 대화', const UncleTeamChats()),
    );

    expect(find.text('남평화 단체방'), findsAtLeastNWidgets(1));
    expect(find.text('남평화 단체방 메모'), findsAtLeastNWidgets(1));
    expect(find.text('안 읽음'), findsAtLeastNWidgets(1));

    await tester.tap(find.textContaining('동료 1:1').first);
    await settle(tester);
    expect(find.text('외부 동료'), findsAtLeastNWidgets(1));
    expect(find.text('외부 동료 메모'), findsAtLeastNWidgets(1));
    expect(find.text('동료 1:1 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('팀 업무 화면이 방향별 목록과 포장 상세를 함께 보여 준다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final picker = await _createUncle(fixture, '팀 동료 계정', '팀 동료');
      await _connectAccepted(fixture, owner, picker);
      final teamId = await _runTeam(fixture, owner, 'createTeam', {
        'name': '청평화 팀',
      });
      final inviteId = await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': picker,
      });
      await _runTeam(fixture, picker, 'respondTeamInvite', {
        'id': inviteId,
        'status': 'accepted',
        'version': 1,
      });
      final areaId = await _runTeam(fixture, owner, 'assignTeamArea', {
        'teamId': teamId,
        'name': '청평화',
        'primaryMemberId': picker,
        'backupMemberId': owner,
      });
      final roundId = await _runTeam(fixture, owner, 'createTeamRound', {
        'teamId': teamId,
        'label': '새벽 1회차',
      });
      await _seedAcceptedRequest(
        fixture,
        id: 'req-give',
        uncleId: owner,
        retailerName: '가게 A',
        wholesalerName: '청평화 1층',
        location: '청평화 1층 A열',
      );
      await _seedAcceptedRequest(
        fixture,
        id: 'req-receive',
        uncleId: owner,
        retailerName: '가게 B',
        wholesalerName: '청평화 2층',
        location: '청평화 2층 B열',
      );
      await _seedAcceptedRequest(
        fixture,
        id: 'req-deliver',
        uncleId: owner,
        retailerName: '가게 C',
        wholesalerName: '청평화 3층',
        location: '청평화 3층 C열',
      );

      final giveJob = await _runTeam(fixture, owner, 'createPickupJob', {
        'teamId': teamId,
        'requestId': 'req-give',
        'areaId': areaId,
        'roundId': roundId,
        'wholesalerIndex': 0,
      });
      await _runTeam(fixture, owner, 'assignPickupJob', {
        'id': giveJob,
        'version': 0,
        'pickupAssigneeId': owner,
        'finalAssigneeId': picker,
        'assignmentReason': '팀장이 먼저 확보해 전달해요',
      });
      await _runTeam(fixture, owner, 'recordPackageCustody', {
        'id': 'pkg-give',
        'jobId': giveJob,
        'packageLabel': '봉투 A',
        'quantity': 1,
        'finalAssigneeId': picker,
      });

      final receiveJob = await _runTeam(fixture, owner, 'createPickupJob', {
        'teamId': teamId,
        'requestId': 'req-receive',
        'wholesalerIndex': 0,
      });
      await _runTeam(fixture, owner, 'assignPickupJob', {
        'id': receiveJob,
        'version': 0,
        'pickupAssigneeId': picker,
        'finalAssigneeId': owner,
        'assignmentReason': '구역 담당이 픽업 후 전달해요',
      });
      final receivePackage =
          await _runTeam(fixture, picker, 'recordPackageCustody', {
            'id': 'pkg-receive',
            'jobId': receiveJob,
            'packageLabel': '봉투 B',
            'quantity': 1,
            'finalAssigneeId': owner,
          });
      await _runTeam(fixture, picker, 'requestPackageHandoff', {
        'teamId': teamId,
        'toId': owner,
        'packageIds': [receivePackage],
        'note': '팀장에게 넘길 예정',
      });

      final deliverJob = await _runTeam(fixture, owner, 'createPickupJob', {
        'teamId': teamId,
        'requestId': 'req-deliver',
        'wholesalerIndex': 0,
      });
      await _runTeam(fixture, owner, 'assignPickupJob', {
        'id': deliverJob,
        'version': 0,
        'pickupAssigneeId': picker,
        'finalAssigneeId': owner,
      });
      final deliverPackage =
          await _runTeam(fixture, picker, 'recordPackageCustody', {
            'id': 'pkg-deliver',
            'jobId': deliverJob,
            'packageLabel': '봉투 C',
            'quantity': 1,
            'finalAssigneeId': owner,
          });
      final handoffId = await _runTeam(
        fixture,
        picker,
        'requestPackageHandoff',
        {
          'teamId': teamId,
          'toId': owner,
          'packageIds': [deliverPackage],
        },
      );
      await _runTeam(fixture, owner, 'confirmPackageHandoff', {
        'id': handoffId,
        'version': 0,
        'packageIds': [deliverPackage],
        'versions': _packageVersions(fixture, [deliverPackage]),
      });
      await fixture.session.signIn(owner);
    });

    await _pumpTeamPage(tester, fixture, const TeamWorkPage());

    expect(find.text('팀 업무'), findsOneWidget);
    expect(find.text('내가 팀원에게 줄 물건'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Item &&
            widget.title == '봉투 A' &&
            widget.subtitle ==
                '가게 A · 청평화 1층\n포장 pkg-give · 1 묶음\n받을 팀원 · 팀 동료',
      ),
      findsOneWidget,
    );
    expect(find.text('내가 받아야 할 인계'), findsOneWidget);
    expect(find.text('팀장에게 넘길 예정'), findsOneWidget);
    expect(find.text('고객 전달'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Item &&
            widget.title == '봉투 C' &&
            (widget.subtitle?.contains('포장 pkg-deliver · 1 묶음') ?? false) &&
            widget.trailing is StatusBadge,
      ),
      findsOneWidget,
    );
    expect(find.text('인계받기 전'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Item &&
            widget.title == '봉투 B' &&
            widget.subtitle ==
                '가게 B · 청평화 2층\n포장 pkg-receive · 1 묶음\n현재 보관 · 팀 동료',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('handoff sourceType/sourceId가 있으면 수령 확인 대상을 바로 연다', (
    tester,
  ) async {
    final fixture = Fixture();
    late String handoffId;
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final picker = await _createUncle(fixture, '팀 동료 계정', '팀 동료');
      await _connectAccepted(fixture, owner, picker);
      final teamId = await _runTeam(fixture, owner, 'createTeam', {
        'name': '광희 팀',
      });
      final inviteId = await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': picker,
      });
      await _runTeam(fixture, picker, 'respondTeamInvite', {
        'id': inviteId,
        'status': 'accepted',
        'version': 1,
      });
      await _seedAcceptedRequest(
        fixture,
        id: 'req-source',
        uncleId: owner,
        retailerName: '가게 원본',
        wholesalerName: '광희 5층',
        location: '광희 5층 E열',
      );
      final jobId = await _runTeam(fixture, owner, 'createPickupJob', {
        'teamId': teamId,
        'requestId': 'req-source',
        'wholesalerIndex': 0,
      });
      await _runTeam(fixture, owner, 'assignPickupJob', {
        'id': jobId,
        'version': 0,
        'pickupAssigneeId': picker,
        'finalAssigneeId': owner,
      });
      final packageId =
          await _runTeam(fixture, picker, 'recordPackageCustody', {
            'id': 'pkg-source',
            'jobId': jobId,
            'packageLabel': '원본 봉투',
            'quantity': 2,
            'finalAssigneeId': owner,
          });
      handoffId = await _runTeam(fixture, picker, 'requestPackageHandoff', {
        'teamId': teamId,
        'toId': owner,
        'packageIds': [packageId],
        'note': '원본 화면에서 바로 확인',
      });
      await fixture.session.signIn(owner);
    });

    await _pumpTeamPage(
      tester,
      fixture,
      TeamWorkPage(sourceType: 'handoff', sourceId: handoffId),
    );

    expect(find.text('실제 일부 수령 / 인계 확인'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TdsCheckbox && widget.semanticLabel == '원본 봉투 수령',
      ),
      findsOneWidget,
    );
    expect(find.text('원본 화면에서 바로 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('재시도 초안은 저장된 payload와 operation ID로만 다시 전송한다', (tester) async {
    final fixture = Fixture();
    late String handoffId;
    const operationId = 'handoff-confirm-op';
    late Data submitted;
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final picker = await _createUncle(fixture, '팀 동료 계정', '팀 동료');
      await _connectAccepted(fixture, owner, picker);
      final teamId = await _runTeam(fixture, owner, 'createTeam', {
        'name': '재시도 팀',
      });
      final inviteId = await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': picker,
      });
      await _runTeam(fixture, picker, 'respondTeamInvite', {
        'id': inviteId,
        'status': 'accepted',
        'version': 1,
      });
      await _seedAcceptedRequest(
        fixture,
        id: 'req-retry',
        uncleId: owner,
        retailerName: '가게 재시도',
        wholesalerName: '재시도상가',
        location: '재시도 B열',
      );
      final jobId = await _runTeam(fixture, owner, 'createPickupJob', {
        'teamId': teamId,
        'requestId': 'req-retry',
        'wholesalerIndex': 0,
      });
      await _runTeam(fixture, owner, 'assignPickupJob', {
        'id': jobId,
        'version': 0,
        'pickupAssigneeId': picker,
        'finalAssigneeId': owner,
      });
      final packageId =
          await _runTeam(fixture, picker, 'recordPackageCustody', {
            'id': 'pkg-retry',
            'jobId': jobId,
            'packageLabel': '재시도 봉투',
            'quantity': 1,
            'finalAssigneeId': owner,
          });
      handoffId = await _runTeam(fixture, picker, 'requestPackageHandoff', {
        'teamId': teamId,
        'toId': owner,
        'packageIds': [packageId],
        'note': '초기 메모',
      });
      submitted = {
        'id': handoffId,
        'version': 0,
        'packageIds': [packageId],
        'versions': _packageVersions(fixture, [packageId]),
        'note': '원래 메모',
      };
      await fixture.session.signIn(owner);
      await fixture.workspace.saveWorkflowInput('team:handoff-confirm:all', {
        'operationId': operationId,
        'command': 'wf.confirmPackageHandoff',
        'values': {
          'id': handoffId,
          'packageIds': [packageId],
          'note': '원래 메모',
        },
        'submitted': submitted,
      });
    });

    await _pumpTeamPage(tester, fixture, const TeamWorkPage());

    expect(find.text('서버 확인을 기다리고 있어요. 같은 내용으로 다시 시도할 수 있어요.'), findsOneWidget);
    expect(find.text('같은 수령 확인 다시 저장'), findsOneWidget);

    await tapButton(tester, '같은 수령 확인 다시 저장');

    final handoff = fixture.store.snapshot.get('teamHandoffs', handoffId)!;
    expect(handoff.s('status'), 'confirmed');
    expect(handoff.s('note'), '원래 메모');
    expect(
      fixture.workspace.workflowInput('team:handoff-confirm:all'),
      isEmpty,
    );

    final operations = await tester.runAsync(() => _operations(fixture));
    expect(
      operations![operationId]?['payload'],
      workflowPayload('wf.confirmPackageHandoff', submitted),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('계정이 바뀐 뒤에는 이전 draft operation을 재사용하지 못한다', (tester) async {
    final fixture = Fixture();
    late String handoffId;
    const operationId = 'handoff-actor-guard';
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final picker = await _createUncle(fixture, '팀 동료 계정', '팀 동료');
      await _connectAccepted(fixture, owner, picker);
      final teamId = await _runTeam(fixture, owner, 'createTeam', {
        'name': '가드 팀',
      });
      final inviteId = await _runTeam(fixture, owner, 'inviteTeamMember', {
        'teamId': teamId,
        'inviteeId': picker,
      });
      await _runTeam(fixture, picker, 'respondTeamInvite', {
        'id': inviteId,
        'status': 'accepted',
        'version': 1,
      });
      await _seedAcceptedRequest(
        fixture,
        id: 'req-guard',
        uncleId: owner,
        retailerName: '가게 가드',
        wholesalerName: '가드상가',
        location: '가드 C열',
      );
      final jobId = await _runTeam(fixture, owner, 'createPickupJob', {
        'teamId': teamId,
        'requestId': 'req-guard',
        'wholesalerIndex': 0,
      });
      await _runTeam(fixture, owner, 'assignPickupJob', {
        'id': jobId,
        'version': 0,
        'pickupAssigneeId': picker,
        'finalAssigneeId': owner,
      });
      final packageId =
          await _runTeam(fixture, picker, 'recordPackageCustody', {
            'id': 'pkg-guard',
            'jobId': jobId,
            'packageLabel': '가드 봉투',
            'quantity': 1,
            'finalAssigneeId': owner,
          });
      handoffId = await _runTeam(fixture, picker, 'requestPackageHandoff', {
        'teamId': teamId,
        'toId': owner,
        'packageIds': [packageId],
      });
      await fixture.session.signIn(owner);
      await fixture.workspace.saveWorkflowInput('team:handoff-confirm:all', {
        'operationId': operationId,
        'command': 'wf.confirmPackageHandoff',
        'values': {
          'id': handoffId,
          'packageIds': [packageId],
        },
        'submitted': {
          'id': handoffId,
          'version': 0,
          'packageIds': [packageId],
          'versions': _packageVersions(fixture, [packageId]),
        },
      });
    });

    await _pumpTeamPage(tester, fixture, const TeamWorkPage());

    await tester.runAsync(() async {
      final picker = fixture.store.snapshot
          .all('accounts')
          .firstWhere((row) => row.s('nickname') == '팀 동료')
          .id;
      await fixture.session.signIn(picker);
    });

    await tapButton(tester, '같은 수령 확인 다시 저장');

    expect(find.text('인계 수령을 확인하지 못했어요'), findsOneWidget);
    expect(find.textContaining('계정이 변경되었어요'), findsOneWidget);
    expect(
      fixture.store.snapshot.get('teamHandoffs', handoffId)!.s('status'),
      'pending',
    );

    final operations = await tester.runAsync(() => _operations(fixture));
    expect(operations!, isNot(contains(operationId)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('동료 읽음 처리를 여러 번 하면 매번 새 operation ID를 쓴다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      final owner = fixture.uncle;
      final outside = await _createUncle(fixture, '외부 동료 계정', '외부 동료');
      await _connectAccepted(fixture, owner, outside);
      await _runTeam(fixture, outside, 'sendColleagueMessage', {
        'peerId': owner,
        'body': '첫 번째 안 읽음',
      });
      await fixture.session.signIn(owner);
    });

    await _pumpTeamPage(
      tester,
      fixture,
      _framed('팀 대화', const UncleTeamChats()),
    );

    await tester.tap(find.textContaining('동료 1:1').first);
    await settle(tester);
    await tapButton(tester, '읽음 처리');

    await tester.pumpWidget(const SizedBox());
    await drainWork(tester, () async {
      final outside = fixture.store.snapshot
          .all('accounts')
          .firstWhere((row) => row.s('nickname') == '외부 동료')
          .id;
      final owner = fixture.uncle;
      await fixture.session.signIn(outside);
      await _runTeam(fixture, outside, 'sendColleagueMessage', {
        'peerId': owner,
        'body': '두 번째 안 읽음',
      });
      await fixture.session.signIn(owner);
    }());
    await _pumpTeamPage(
      tester,
      fixture,
      _framed('팀 대화', const UncleTeamChats()),
      registerCleanup: false,
    );

    await tester.tap(find.textContaining('동료 1:1').first);
    await settle(tester);
    await tapButton(tester, '읽음 처리');

    late Map<String, Data> operations;
    await drainWork(tester, () async {
      operations = await _operations(fixture);
    }());
    final readOps = operations.entries
        .where(
          (entry) =>
              '${entry.value['payload']}'.contains('wf.markColleagueChatRead'),
        )
        .map((entry) => entry.key)
        .toList();

    expect(readOps, hasLength(2));
    expect(readOps[0], isNot(readOps[1]));
    expect(tester.takeException(), isNull);
  });
}
