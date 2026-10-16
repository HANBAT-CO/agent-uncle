import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/team_commands.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/team_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, Data>> _tables() => {
  for (final name in [...collections, ...teamCollections])
    name: <String, Data>{},
};

class _Fixture {
  _Fixture() : state = MutableWorkspace(_tables()) {
    _putAccount('owner', '팀장 삼촌');
    _putAccount('picker', '동료 삼촌');
    _putAccount('outside', '외부 삼촌');
    state.put('accounts', 'retailer', {
      'name': '소매 상점',
      'nickname': '가게',
      'role': 'retailer',
      'complete': true,
    });
    _putRequest(
      'req-1',
      uncleId: 'owner',
      wholesaler: '남평화 1층',
      location: '남평화 1층 A열',
    );
    _putRequest(
      'req-2',
      uncleId: 'owner',
      wholesaler: '청평화',
      location: '청평화 2층',
    );
  }

  final MutableWorkspace state;

  void _putAccount(String id, String name) {
    state.put('accounts', id, {
      'name': name,
      'nickname': name,
      'role': 'uncle',
      'complete': true,
    });
  }

  void _putRequest(
    String id, {
    required String uncleId,
    required String wholesaler,
    required String location,
  }) {
    state.put('requests', id, {
      'retailerId': 'retailer',
      'uncleId': uncleId,
      'status': 'accepted',
      'businessName': '가게',
      'name': '가게',
      'wholesaler': wholesaler,
      'location': location,
      'wholesalers': [
        {
          'wholesaler': wholesaler,
          'location': location,
          'paymentMode': 'review',
        },
      ],
      'createdAt': '2026-10-15T00:00:00Z',
      'updatedAt': '2026-10-15T00:00:00Z',
      'version': 0,
    });
  }

  String run(String actor, String command, Data args) =>
      applyTeam(state, actor, command, args);

  Data row(String table, String id) => state.tables[table]![id]!;
}

Data _card(_Fixture f, String cardType, String sourceId) {
  return f.state.tables['teamChats']!.values.firstWhere(
    (row) =>
        textOf(row, 'cardType') == cardType &&
        textOf(row, 'sourceId') == sourceId,
  );
}

void main() {
  test('기존 팀과 회차 식별자로 다른 팀의 기록을 덮어쓸 수 없다', () {
    final f = _Fixture();
    final teamId = f.run('owner', 'createTeam', {
      'teamId': 'existing-team',
      'name': '기존 팀',
    });
    final team = Map<String, Object?>.from(f.row('teams', teamId));
    expect(
      () => f.run('outside', 'createTeam', {'teamId': teamId, 'name': '덮어쓴 팀'}),
      throwsA(isA<AppFailure>()),
    );
    expect(f.row('teams', teamId), team);

    final otherTeamId = f.run('outside', 'createTeam', {'name': '다른 팀'});
    final roundId = f.run('owner', 'createTeamRound', {
      'id': 'existing-round',
      'teamId': teamId,
      'label': '기존 회차',
    });
    final round = Map<String, Object?>.from(f.row('teamRounds', roundId));
    expect(
      () => f.run('outside', 'createTeamRound', {
        'id': roundId,
        'teamId': otherTeamId,
        'label': '덮어쓴 회차',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(f.row('teamRounds', roundId), round);
  });

  test('다른 팀의 회차와 구역을 사용하거나 구역 기록을 변경할 수 없다', () {
    final f = _Fixture();
    final teamId = f.run('owner', 'createTeam', {'name': '우리 팀'});
    final otherTeamId = f.run('outside', 'createTeam', {'name': '다른 팀'});
    final otherRoundId = f.run('outside', 'createTeamRound', {
      'teamId': otherTeamId,
      'label': '외부 회차',
    });
    final otherAreaId = f.run('outside', 'assignTeamArea', {
      'teamId': otherTeamId,
      'name': '남평화',
      'primaryMemberId': 'outside',
    });
    final otherArea = Map<String, Object?>.from(
      f.row('teamAreas', otherAreaId),
    );
    expect(
      () => f.run('owner', 'assignTeamArea', {
        'id': otherAreaId,
        'version': numberOf(otherArea, 'version'),
        'teamId': teamId,
        'name': '우리 팀 구역',
        'primaryMemberId': 'owner',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(f.row('teamAreas', otherAreaId), otherArea);

    final jobId = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-1',
    });
    final job = Map<String, Object?>.from(f.row('teamJobs', jobId));
    for (final invalidScope in [
      {'roundId': otherRoundId},
      {'areaId': otherAreaId},
    ]) {
      expect(
        () => f.run('owner', 'createPickupJob', {
          'teamId': teamId,
          'requestId': 'req-2',
          ...invalidScope,
        }),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => f.run('owner', 'assignPickupJob', {
          'id': jobId,
          'version': numberOf(job, 'version'),
          'pickupAssigneeId': 'owner',
          'finalAssigneeId': 'owner',
          ...invalidScope,
        }),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(f.state.tables['teamJobs'], hasLength(1));
    expect(f.row('teamJobs', jobId), job);
  });

  test('업무 생성 시 외부 담당자와 기존 업무 식별자 사용을 거절한다', () {
    final f = _Fixture();
    final teamId = f.run('owner', 'createTeam', {'name': '업무 보호 팀'});
    for (final key in ['pickupAssigneeId', 'finalAssigneeId']) {
      expect(
        () => f.run('owner', 'createPickupJob', {
          'teamId': teamId,
          'requestId': 'req-1',
          key: 'outside',
        }),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(f.state.tables['teamJobs'], isEmpty);
    final jobId = f.run('owner', 'createPickupJob', {
      'id': 'existing-job',
      'teamId': teamId,
      'requestId': 'req-1',
    });
    final job = Map<String, Object?>.from(f.row('teamJobs', jobId));
    expect(
      () => f.run('owner', 'createPickupJob', {
        'id': jobId,
        'teamId': teamId,
        'requestId': 'req-2',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(f.row('teamJobs', jobId), job);
    expect(f.state.tables['teamJobs'], hasLength(1));
  });

  test('인계 확인 중이거나 전달한 포장은 현장 기록 수정으로 초기화할 수 없다', () {
    final f = _Fixture();
    final teamId = f.run('owner', 'createTeam', {'name': '포장 보호 팀'});
    final connectionId = f.run('owner', 'connectColleague', {
      'peerId': 'picker',
    });
    f.run('picker', 'respondColleagueConnection', {
      'id': connectionId,
      'status': 'accepted',
      'version': 1,
    });
    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'picker',
    });
    f.run('picker', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });
    final jobId = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-1',
      'pickupAssigneeId': 'owner',
      'finalAssigneeId': 'owner',
    });
    String record(String label) => f.run('owner', 'recordPackageCustody', {
      'jobId': jobId,
      'packageLabel': label,
      'quantity': 1,
    });
    void expectBlocked(String id, String message) {
      final previous = Map<String, Object?>.from(f.row('teamPackages', id));
      expect(
        () => f.run('owner', 'recordPackageCustody', {
          'id': id,
          'jobId': jobId,
          'version': numberOf(previous, 'version'),
          'packageLabel': '잘못 수정한 포장',
          'quantity': 99,
        }),
        throwsA(isA<AppFailure>().having((e) => e.message, 'message', message)),
      );
      expect(f.row('teamPackages', id), previous);
    }

    final first = record('첫 번째');
    final second = record('두 번째');
    final handoffId = f.run('owner', 'requestPackageHandoff', {
      'teamId': teamId,
      'toId': 'picker',
      'packageIds': [first, second],
    });
    const pendingMessage = '인계 확인 중인 포장은 수정할 수 없어요. 인계 확인을 먼저 끝내 주세요.';
    expectBlocked(second, pendingMessage);
    f.run('picker', 'confirmPackageHandoff', {
      'id': handoffId,
      'version': 0,
      'packageIds': [first],
      'versions': {first: numberOf(f.row('teamPackages', first), 'version')},
    });
    expect(f.row('teamHandoffs', handoffId)['status'], 'partial');
    expectBlocked(second, pendingMessage);

    final delivered = record('직접 전달');
    final handoff = Map<String, Object?>.from(f.row('teamHandoffs', handoffId));
    final package = Map<String, Object?>.from(f.row('teamPackages', delivered));
    expect(
      () => f.run('owner', 'requestPackageHandoff', {
        'id': handoffId,
        'teamId': teamId,
        'toId': 'picker',
        'packageIds': [delivered],
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(f.row('teamHandoffs', handoffId), handoff);
    expect(f.row('teamPackages', delivered), package);
    f.run('owner', 'recordPackageDelivery', {
      'packageIds': [delivered],
      'versions': {
        delivered: numberOf(f.row('teamPackages', delivered), 'version'),
      },
    });
    expectBlocked(delivered, '이미 전달이 끝난 포장 상태는 초기화하거나 다른 업무로 옮길 수 없어요.');
  });

  test('팀 업무는 닉네임 대신 요청의 수령 상호를 보존하고 매장명으로 대체한다', () {
    final f = _Fixture();
    final teamId = f.run('owner', 'createTeam', {'name': '상호 확인 팀'});
    final request = f.row('requests', 'req-1');
    request['receivingShop'] = '  주문 수령 매장  ';
    final requestedJob = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-1',
      'pickupAssigneeId': 'owner',
      'finalAssigneeId': 'owner',
    });
    expect(f.row('teamJobs', requestedJob)['retailerName'], '주문 수령 매장');
    final package = f.run('owner', 'recordPackageCustody', {
      'jobId': requestedJob,
      'packageLabel': '상호 확인 봉투',
      'quantity': 1,
    });
    expect(f.row('teamPackages', package)['retailerName'], '주문 수령 매장');

    f.row('accounts', 'retailer')['businessName'] = '등록 매장';
    final fallbackRequest = f.row('requests', 'req-2');
    fallbackRequest['receivingShop'] = ' ';
    fallbackRequest.remove('businessName');
    fallbackRequest.remove('name');
    final fallbackJob = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-2',
    });
    expect(f.row('teamJobs', fallbackJob)['retailerName'], '등록 매장');
  });

  test('사입 동료 연결, 팀 초대, readers 동기화가 분리된다', () {
    final f = _Fixture();
    final colleagueId = f.run('owner', 'connectColleague', {
      'peerId': 'picker',
    });
    expect(f.row('colleagueConnections', colleagueId)['readers'], [
      'owner',
      'picker',
    ]);

    f.run('picker', 'respondColleagueConnection', {
      'id': colleagueId,
      'status': 'accepted',
      'version': 1,
    });

    final teamId = f.run('owner', 'createTeam', {'name': '동대문 A팀'});
    final roundId = f.run('owner', 'createTeamRound', {
      'teamId': teamId,
      'label': '야간 1회차',
      'operatingDate': '2026-10-15',
    });
    expect(f.row('teamRounds', roundId)['readers'], ['owner']);

    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'picker',
      'note': '동대문 구역 같이 맡아요',
    });
    expect(
      f.row('teamInvites', inviteId)['readers'],
      containsAll(<String>['owner', 'picker']),
    );

    f.run('picker', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });

    expect(
      teamMemberIdsOf(f.row('teams', teamId)),
      containsAll(<String>['owner', 'picker']),
    );
    expect(
      teamReadersOf(f.row('teamRounds', roundId)),
      containsAll(<String>['owner', 'picker']),
    );
    expect(
      () => f.run('picker', 'createTeamRound', {
        'teamId': teamId,
        'label': '일반 팀원의 회차',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(f.state.tables['teamRounds'], hasLength(1));

    final colleagueMessage = f.run('owner', 'sendColleagueMessage', {
      'peerId': 'picker',
      'body': '외부 동료 대화는 팀과 별개예요',
    });
    expect(teamReadersOf(f.row('teamChats', colleagueMessage)), [
      'owner',
      'picker',
    ]);
    expect(
      () => f.run('retailer', 'connectColleague', {'peerId': 'owner'}),
      throwsA(isA<AppFailure>()),
    );
  });

  test('구역 배정과 포장 인계, 전달, 수령 확인이 단계적으로 진행된다', () {
    final f = _Fixture();
    Map<String, int> packageVersions(Iterable<String> ids) => {
      for (final id in ids) id: numberOf(f.row('teamPackages', id), 'version'),
    };
    final colleagueId = f.run('owner', 'connectColleague', {
      'peerId': 'picker',
    });
    f.run('picker', 'respondColleagueConnection', {
      'id': colleagueId,
      'status': 'accepted',
      'version': 1,
    });
    final teamId = f.run('owner', 'createTeam', {'name': '남평화 팀'});
    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'picker',
    });
    f.run('picker', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });

    final areaId = f.run('owner', 'assignTeamArea', {
      'teamId': teamId,
      'name': '남평화',
      'primaryMemberId': 'picker',
      'backupMemberId': 'owner',
    });
    final roundId = f.run('owner', 'createTeamRound', {
      'teamId': teamId,
      'label': '새벽 회차',
    });
    final jobId = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-1',
      'roundId': roundId,
      'areaId': areaId,
    });

    f.run('owner', 'assignPickupJob', {
      'id': jobId,
      'version': 0,
      'pickupAssigneeId': 'picker',
      'finalAssigneeId': 'owner',
      'assignmentReason': '구역 주담당 자동 배정',
    });
    void expectAssignmentPreservesStatus(String status) {
      final packages = Map<String, Data>.from(f.state.tables['teamPackages']!);
      f.run('owner', 'assignPickupJob', {
        'id': jobId,
        'version': numberOf(f.row('teamJobs', jobId), 'version'),
        'pickupAssigneeId': 'picker',
        'finalAssigneeId': 'owner',
      });
      expect(f.row('teamJobs', jobId)['status'], status);
      expect(f.state.tables['teamPackages'], packages);
    }

    final assignmentCard = _card(f, 'pickupAssignment', jobId);
    expect(textOf(assignmentCard, 'sourceType'), 'pickupJob');
    expect(textOf(assignmentCard, 'requestId'), 'req-1');
    expect(assignmentCard.containsKey('readerIds'), isFalse);
    expect(
      teamReadersOf(assignmentCard),
      containsAll(<String>['owner', 'picker']),
    );
    expect(teamReadByOf(assignmentCard), ['owner']);
    expect(textOf(assignmentCard, 'body'), contains('구역: 남평화'));
    expect(textOf(assignmentCard, 'body'), contains('픽업 담당: 동료 삼촌'));
    expect(textOf(assignmentCard, 'body'), contains('사유: 구역 주담당 자동 배정'));
    f.run('owner', 'updatePickupScope', {
      'id': jobId,
      'version': numberOf(f.row('teamJobs', jobId), 'version'),
      'expectedPackageCount': 1,
      'scopeConfirmed': true,
      'hasBackorder': false,
    });

    final packageId = f.run('picker', 'recordPackageCustody', {
      'jobId': jobId,
      'packageLabel': '봉투 1',
      'quantity': 1,
      'unit': '봉투',
      'finalAssigneeId': 'owner',
    });
    expect(f.row('teamJobs', jobId)['status'], 'picked');
    expectAssignmentPreservesStatus('picked');

    final handoffId = f.run('picker', 'requestPackageHandoff', {
      'teamId': teamId,
      'toId': 'owner',
      'packageIds': [packageId],
      'note': '동대문역 앞에서 교환',
    });
    final handoffRequestCard = _card(f, 'handoffRequest', handoffId);
    expect(textOf(handoffRequestCard, 'sourceType'), 'handoff');
    expect(textOf(handoffRequestCard, 'requestId'), 'req-1');
    expect(textOf(handoffRequestCard, 'body'), contains('발신: 동료 삼촌'));
    expect(textOf(handoffRequestCard, 'body'), contains('수신: 팀장 삼촌'));
    expect(textOf(handoffRequestCard, 'body'), contains('포장: 봉투 1 1봉투'));
    expect(teamReadByOf(handoffRequestCard), ['picker']);
    expect(f.row('teamPackages', packageId)['status'], 'handoff_requested');
    expectAssignmentPreservesStatus('handoff_requested');

    f.run('owner', 'confirmPackageHandoff', {
      'id': handoffId,
      'version': 0,
      'packageIds': [packageId],
      'versions': packageVersions([packageId]),
    });
    final handoffConfirmedCard = _card(f, 'handoffConfirmed', handoffId);
    expect(textOf(handoffConfirmedCard, 'body'), contains('받은 포장: 봉투 1 1봉투'));
    expect(textOf(handoffConfirmedCard, 'body'), contains('남은 포장: 없음'));
    expect(
      teamReadByOf(handoffConfirmedCard),
      containsAll(<String>['owner', 'picker']),
    );
    expect(f.row('teamPackages', packageId)['currentHolderId'], 'owner');
    expect(f.row('teamJobs', jobId)['status'], 'delivery_ready');
    expectAssignmentPreservesStatus('delivery_ready');

    f.run('owner', 'recordPackageDelivery', {
      'packageIds': [packageId],
      'versions': packageVersions([packageId]),
      'recipientLabel': '가게',
    });
    final deliveredCard = _card(f, 'packageDelivered', packageId);
    expect(textOf(deliveredCard, 'sourceType'), 'package');
    expect(textOf(deliveredCard, 'requestId'), 'req-1');
    expect(textOf(deliveredCard, 'body'), contains('대상: 가게'));
    expect(textOf(deliveredCard, 'body'), contains('포장: 봉투 1 1봉투'));
    expect(
      teamReadByOf(deliveredCard),
      containsAll(<String>['owner', 'picker']),
    );
    expect(f.row('teamPackages', packageId)['status'], 'delivered');
    expectAssignmentPreservesStatus('delivered');

    expect(
      () => f.run('owner', 'recordPackageReceipt', {
        'packageIds': [packageId],
        'versions': packageVersions([packageId]),
        'note': '가게에서 수령 확인',
      }),
      throwsA(isA<AppFailure>()),
    );

    final receiptId = f.run('retailer', 'recordPackageReceipt', {
      'packageIds': [packageId],
      'versions': packageVersions([packageId]),
      'note': '가게에서 수령 확인',
    });
    expect(f.row('teamPackages', packageId)['status'], 'received');
    expect(f.row('teamJobs', jobId)['status'], 'received');
    expect(teamPackageIdsOf(f.row('teamReceipts', receiptId)), [packageId]);
    expectAssignmentPreservesStatus('received');
  });

  test('자동 배정 결과와 남은 업무 카드가 팀 대화에 남고 읽음이 원본 상태를 바꾸지 않는다', () {
    final f = _Fixture();
    final colleagueId = f.run('owner', 'connectColleague', {
      'peerId': 'picker',
    });
    f.run('picker', 'respondColleagueConnection', {
      'id': colleagueId,
      'status': 'accepted',
      'version': 1,
    });
    final teamId = f.run('owner', 'createTeam', {'name': '자동 배정 팀'});
    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'picker',
    });
    f.run('picker', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });
    final roundId = f.run('owner', 'createTeamRound', {
      'teamId': teamId,
      'label': '자동 회차',
    });
    f.run('owner', 'assignTeamArea', {
      'id': 'area-auto',
      'teamId': teamId,
      'name': '남평화',
      'primaryMemberId': 'picker',
      'backupMemberId': 'owner',
      'primaryWorking': true,
    });
    final assignedJobId = f.run('owner', 'createPickupJob', {
      'id': 'job-auto-assigned',
      'teamId': teamId,
      'requestId': 'req-1',
      'roundId': roundId,
    });
    final pendingJobId = f.run('owner', 'createPickupJob', {
      'id': 'job-auto-pending',
      'teamId': teamId,
      'requestId': 'req-2',
      'roundId': roundId,
    });

    f.run('owner', 'autoAssignTeamRound', {
      'teamId': teamId,
      'roundId': roundId,
    });

    final autoAssignedCard = _card(f, 'pickupAssignment', assignedJobId);
    expect(textOf(autoAssignedCard, 'body'), contains('사유: 남평화 주담당 자동 배정'));
    expect(teamReadByOf(autoAssignedCard), ['owner']);
    final pendingCard = _card(f, 'pickupPending', pendingJobId);
    expect(textOf(pendingCard, 'body'), contains('남은 업무'));
    expect(
      textOf(pendingCard, 'body'),
      contains('사유: 도매처 위치와 정확히 맞는 구역이 없어 자동 배정하지 않았어요.'),
    );
    expect(teamReadByOf(pendingCard), containsAll(<String>['owner', 'picker']));

    final before = Map<String, Object?>.from(f.row('teamJobs', assignedJobId));
    f.run('picker', 'markTeamChatRead', {'teamId': teamId});
    expect(
      textOf(f.row('teamJobs', assignedJobId), 'status'),
      textOf(before, 'status'),
    );
    expect(
      textOf(f.row('teamJobs', assignedJobId), 'pickupAssigneeId'),
      textOf(before, 'pickupAssigneeId'),
    );
  });

  test('부분 인계 카드는 받은 포장과 남은 포장을 함께 남긴다', () {
    final f = _Fixture();
    Map<String, int> packageVersions(Iterable<String> ids) => {
      for (final id in ids) id: numberOf(f.row('teamPackages', id), 'version'),
    };
    final colleagueId = f.run('owner', 'connectColleague', {
      'peerId': 'picker',
    });
    f.run('picker', 'respondColleagueConnection', {
      'id': colleagueId,
      'status': 'accepted',
      'version': 1,
    });
    final teamId = f.run('owner', 'createTeam', {'name': '부분 인계 팀'});
    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'picker',
    });
    f.run('picker', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });
    final jobId = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-1',
    });
    f.run('owner', 'assignPickupJob', {
      'id': jobId,
      'version': 0,
      'pickupAssigneeId': 'picker',
      'finalAssigneeId': 'owner',
    });
    final firstPackageId = f.run('picker', 'recordPackageCustody', {
      'id': 'pkg-partial-1',
      'jobId': jobId,
      'packageLabel': '1번 봉투',
      'quantity': 1,
      'unit': '봉투',
      'finalAssigneeId': 'owner',
    });
    final secondPackageId = f.run('picker', 'recordPackageCustody', {
      'id': 'pkg-partial-2',
      'jobId': jobId,
      'packageLabel': '2번 봉투',
      'quantity': 2,
      'unit': '봉투',
      'finalAssigneeId': 'owner',
    });

    final handoffId = f.run('picker', 'requestPackageHandoff', {
      'id': 'handoff-partial',
      'teamId': teamId,
      'toId': 'owner',
      'packageIds': [firstPackageId, secondPackageId],
    });
    f.run('owner', 'confirmPackageHandoff', {
      'id': handoffId,
      'version': 0,
      'packageIds': [firstPackageId],
      'versions': packageVersions([firstPackageId]),
    });

    expect(textOf(f.row('teamHandoffs', handoffId), 'status'), 'partial');
    expect(
      textOf(f.row('teamPackages', firstPackageId), 'currentHolderId'),
      'owner',
    );
    expect(
      textOf(f.row('teamPackages', secondPackageId), 'currentHolderId'),
      'picker',
    );

    final partialCard = _card(f, 'handoffPartial', handoffId);
    expect(textOf(partialCard, 'requestId'), 'req-1');
    expect(textOf(partialCard, 'body'), contains('받은 포장: 1번 봉투 1봉투'));
    expect(textOf(partialCard, 'body'), contains('남은 포장: 2번 봉투 2봉투'));
    expect(teamReadByOf(partialCard), ['owner']);
  });

  test('진행 중인 물건이 있으면 탈퇴가 막히고, 정리 뒤에는 나갈 수 있다', () {
    final f = _Fixture();
    final colleagueId = f.run('owner', 'connectColleague', {
      'peerId': 'picker',
    });
    f.run('picker', 'respondColleagueConnection', {
      'id': colleagueId,
      'status': 'accepted',
      'version': 1,
    });
    final teamId = f.run('owner', 'createTeam', {'name': '청평화 팀'});
    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'picker',
    });
    f.run('picker', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });
    final jobId = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-2',
    });
    f.run('owner', 'assignPickupJob', {
      'id': jobId,
      'version': 0,
      'pickupAssigneeId': 'picker',
      'finalAssigneeId': 'owner',
    });
    f.run('picker', 'recordPackageCustody', {
      'jobId': jobId,
      'packageLabel': '봉투 9',
      'quantity': 1,
    });

    expect(
      () => f.run('picker', 'leaveTeam', {'teamId': teamId}),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => f.run('owner', 'leaveTeam', {'teamId': teamId}),
      throwsA(isA<AppFailure>()),
    );
  });

  test('예외 회수는 현재 보관자와 상태를 엄격하게 검증한다', () {
    final f = _Fixture();
    Map<String, int> packageVersions(Iterable<String> ids) => {
      for (final id in ids) id: numberOf(f.row('teamPackages', id), 'version'),
    };

    final colleagueId = f.run('owner', 'connectColleague', {
      'peerId': 'outside',
    });
    f.run('outside', 'respondColleagueConnection', {
      'id': colleagueId,
      'status': 'accepted',
      'version': 1,
    });
    final teamId = f.run('owner', 'createTeam', {'name': '회수 검증 팀'});
    final inviteId = f.run('owner', 'inviteTeamMember', {
      'teamId': teamId,
      'inviteeId': 'outside',
    });
    f.run('outside', 'respondTeamInvite', {
      'id': inviteId,
      'status': 'accepted',
      'version': 1,
    });
    final jobId = f.run('owner', 'createPickupJob', {
      'teamId': teamId,
      'requestId': 'req-1',
    });
    f.run('owner', 'assignPickupJob', {
      'id': jobId,
      'version': 0,
      'pickupAssigneeId': 'outside',
      'finalAssigneeId': 'owner',
    });

    final packageId = f.run('outside', 'recordPackageCustody', {
      'jobId': jobId,
      'packageLabel': '회수 봉투',
      'quantity': 1,
      'finalAssigneeId': 'owner',
    });
    f.state.put('accounts', 'picker', {
      ...f.row('accounts', 'picker'),
      'complete': false,
      'deletionPending': true,
    });
    f.state.put('teamPackages', packageId, {
      ...f.row('teamPackages', packageId),
      'requiresReconciliation': true,
      'reconciliationReason': 'account_deleted',
    });

    expect(
      () => f.run('owner', 'recoverPackageCustody', {
        'packageId': packageId,
        'version': numberOf(f.row('teamPackages', packageId), 'version'),
        'previousHolderId': 'picker',
        'nextHolderId': 'owner',
        'note': '스푸핑 회수 시도',
      }),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          '최신 보관자 정보가 달라졌어요. 최신 화면에서 다시 시도해 주세요.',
        ),
      ),
    );

    f.state.tables['accounts']!.remove('outside');

    expect(
      () => f.run('owner', 'recoverPackageCustody', {
        'packageId': packageId,
        'version': 99,
        'previousHolderId': 'outside',
        'nextHolderId': 'owner',
        'note': '오래된 버전 회수 시도',
      }),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          '다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.',
        ),
      ),
    );

    f.run('owner', 'recoverPackageCustody', {
      'packageId': packageId,
      'version': numberOf(f.row('teamPackages', packageId), 'version'),
      'previousHolderId': 'outside',
      'nextHolderId': 'owner',
      'note': '탈퇴 삼촌 회수 완료',
    });
    expect(f.row('teamPackages', packageId)['currentHolderId'], 'owner');
    expect(f.row('teamPackages', packageId)['recoveredFromId'], 'outside');
    expect(f.row('teamPackages', packageId)['finalAssigneeId'], 'owner');
    expect(f.row('teamPackages', packageId)['status'], 'delivery_ready');

    f.run('owner', 'recordPackageDelivery', {
      'packageIds': [packageId],
      'versions': packageVersions([packageId]),
      'recipientLabel': '가게',
    });
    f.state.put('teamPackages', packageId, {
      ...f.row('teamPackages', packageId),
      'requiresReconciliation': true,
      'reconciliationReason': 'account_deleted',
    });

    expect(
      () => f.run('owner', 'recoverPackageCustody', {
        'packageId': packageId,
        'version': numberOf(f.row('teamPackages', packageId), 'version'),
        'previousHolderId': 'owner',
        'nextHolderId': 'owner',
        'note': '전달 완료 후 회수 시도',
      }),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          '고객 전달이나 수령 확인이 끝난 포장은 예외 인계로 회수할 수 없어요.',
        ),
      ),
    );
  });
}
