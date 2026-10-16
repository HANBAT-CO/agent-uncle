import 'models.dart';

const teamCollections = [
  'colleagueConnections',
  'teams',
  'teamInvites',
  'teamChats',
  'teamRounds',
  'teamAreas',
  'teamJobs',
  'teamPackages',
  'teamHandoffs',
  'teamReceipts',
];

const teamCommands = [
  'connectColleague',
  'respondColleagueConnection',
  'createTeam',
  'inviteTeamMember',
  'requestTeamMembership',
  'respondTeamInvite',
  'leaveTeam',
  'sendColleagueMessage',
  'markColleagueChatRead',
  'sendTeamMessage',
  'markTeamChatRead',
  'createTeamRound',
  'assignTeamArea',
  'createPickupJob',
  'assignPickupJob',
  'autoAssignTeamRound',
  'updatePickupScope',
  'recordPackageCustody',
  'requestPackageHandoff',
  'confirmPackageHandoff',
  'recordPackageDelivery',
  'recordPackageReceipt',
  'recoverPackageCustody',
];

const teamTerminalStatuses = {'archived', 'received'};
const teamActivePackageStatuses = {
  'queued',
  'assigned',
  'picked',
  'held',
  'delivery_ready',
  'handoff_requested',
  'handoff_partial',
  'delivered',
  'issue',
};

List<String> teamReadersOf(Data data) => stringsOf(data, 'readers');
List<String> teamMemberIdsOf(Data data) => stringsOf(data, 'memberIds');
List<String> teamAdminIdsOf(Data data) => stringsOf(data, 'adminIds');
List<String> teamReadByOf(Data data) => stringsOf(data, 'readBy');
List<String> teamPackageIdsOf(Data data) => stringsOf(data, 'packageIds');
List<String> teamAcceptedPackageIdsOf(Data data) =>
    stringsOf(data, 'acceptedPackageIds');
List<String> teamPendingPackageIdsOf(Data data) =>
    stringsOf(data, 'pendingPackageIds');
List<String> teamIssueIdsOf(Data data) => stringsOf(data, 'issueIds');
List<String> teamMatchKeywordsOf(Data data) => stringsOf(data, 'matchKeywords');

bool isTeamMember(Data data, String userId) => teamMemberIdsOf(data).contains(userId);
bool isTeamAdmin(Data data, String userId) => teamAdminIdsOf(data).contains(userId);
bool isUncleAccount(Data data) =>
    textOf(data, 'role') == 'uncle' && flagOf(data, 'complete');

String colleaguePeerId(Data data, String userId) =>
    textOf(data, 'fromId') == userId ? textOf(data, 'toId') : textOf(data, 'fromId');

String colleagueConnectionLabel(Data data) => switch (textOf(data, 'status')) {
  'accepted' => '연결됨',
  'declined' => '거절됨',
  _ => '수락 대기',
};

String teamInviteKindLabel(Data data) =>
    textOf(data, 'kind', 'invite') == 'membership_request' ? '참여 요청' : '팀 초대';

String teamInviteLabel(Data data) => switch (textOf(data, 'status')) {
  'accepted' => '참여 완료',
  'declined' => '거절됨',
  'cancelled' => '취소됨',
  _ => '응답 대기',
};

String teamJobStatusLabel(Data data) => switch (textOf(data, 'status')) {
  'queued' => '정리 전',
  'assigned' => '배정 완료',
  'picked' => '픽업 완료',
  'handoff_requested' => '인계 요청',
  'handoff_partial' => '부분 인계',
  'delivery_ready' => '전달 준비',
  'delivered' => '전달 완료',
  'issue' => '확인 필요',
  'received' => '수령 확인',
  _ => '진행 중',
};

String teamPackageStatusLabel(Data data) => switch (textOf(data, 'status')) {
  'queued' => '대기',
  'assigned' => '배정됨',
  'picked' => '픽업됨',
  'held' => '보관 중',
  'handoff_requested' => '인계 요청',
  'handoff_partial' => '부분 인계',
  'delivery_ready' => '전달 준비',
  'delivered' => '전달 완료',
  'received' => '수령 확인',
  _ => '확인 필요',
};

String teamChatPreview(Data data) {
  final body = textOf(data, 'body').trim();
  if (body.isNotEmpty) return body;
  return textOf(data, 'kind') == 'system' ? '업무 카드' : '새 메시지';
}

String teamRoleLabel(Data team, String userId) {
  if (textOf(team, 'ownerId') == userId) return '팀장';
  if (isTeamAdmin(team, userId)) return '운영자';
  return '팀원';
}

Map<String, int> packageVersionsOf(Data data, String key) {
  final raw = mapOf(data, key);
  return {
    for (final entry in raw.entries)
      if (entry.value is num) entry.key: (entry.value as num).toInt(),
  };
}

class TeamRecord extends Record {
  const TeamRecord(super.id, super.data);

  String get name => s('name');
  String get description => s('description');
  String get ownerId => s('ownerId');
  String get status => s('status', 'active');
  List<String> get memberIds => teamMemberIdsOf(data);
  List<String> get adminIds => teamAdminIdsOf(data);
}

class TeamInviteRecord extends Record {
  const TeamInviteRecord(super.id, super.data);

  String get teamId => s('teamId');
  String get inviterId => s('inviterId');
  String get inviteeId => s('inviteeId');
  String get kind => s('kind', 'invite');
  String get status => s('status', 'pending');
}

class TeamAreaRecord extends Record {
  const TeamAreaRecord(super.id, super.data);

  String get teamId => s('teamId');
  String get name => s('name');
  String get primaryMemberId => s('primaryMemberId');
  String get backupMemberId => s('backupMemberId');
  bool get primaryWorking => b('primaryWorking');
  bool get backupWorking => b('backupWorking');
  int get primaryCapacity => n('primaryCapacity');
  int get backupCapacity => n('backupCapacity');
  String get primaryCutoffAt => s('primaryCutoffAt');
  String get backupCutoffAt => s('backupCutoffAt');
  List<String> get matchKeywords => teamMatchKeywordsOf(data);
}

class TeamJobRecord extends Record {
  const TeamJobRecord(super.id, super.data);

  String get teamId => s('teamId');
  String get requestId => s('requestId');
  String get roundId => s('roundId');
  String get areaId => s('areaId');
  String get pickupAssigneeId => s('pickupAssigneeId');
  String get finalAssigneeId => s('finalAssigneeId');
  String get status => s('status', 'queued');
  int get wholesalerIndex => n('wholesalerIndex');
  bool get scopeConfirmed => b('scopeConfirmed');
  int get expectedPackageCount => n('expectedPackageCount');
  bool get hasBackorder => b('hasBackorder');
  List<String> get issueIds => teamIssueIdsOf(data);
}

class TeamPackageRecord extends Record {
  const TeamPackageRecord(super.id, super.data);

  String get teamId => s('teamId');
  String get jobId => s('jobId');
  String get currentHolderId => s('currentHolderId');
  String get pickupAssigneeId => s('pickupAssigneeId');
  String get finalAssigneeId => s('finalAssigneeId');
  String get status => s('status', 'queued');
}

extension TeamWorkspaceView on WorkspaceRepository {
  List<TeamRecord> get teamsView =>
      records('teams').map((row) => TeamRecord(row.id, row.data)).toList(growable: false);
  List<TeamInviteRecord> get teamInvitesView => records(
    'teamInvites',
  ).map((row) => TeamInviteRecord(row.id, row.data)).toList(growable: false);
  List<TeamAreaRecord> get teamAreasView => records(
    'teamAreas',
  ).map((row) => TeamAreaRecord(row.id, row.data)).toList(growable: false);
  List<TeamJobRecord> get teamJobsView =>
      records('teamJobs').map((row) => TeamJobRecord(row.id, row.data)).toList(growable: false);
  List<TeamPackageRecord> get teamPackagesView => records(
    'teamPackages',
  ).map((row) => TeamPackageRecord(row.id, row.data)).toList(growable: false);

  Future<String> connectColleague(Data args, {String? operationId}) =>
      workflow('wf.connectColleague', args, operationId ?? newId());
  Future<String> respondColleagueConnection(Data args, {String? operationId}) =>
      workflow('wf.respondColleagueConnection', args, operationId ?? newId());
  Future<String> createTeam(Data args, {String? operationId}) =>
      workflow('wf.createTeam', args, operationId ?? newId());
  Future<String> inviteTeamMember(Data args, {String? operationId}) =>
      workflow('wf.inviteTeamMember', args, operationId ?? newId());
  Future<String> requestTeamMembership(Data args, {String? operationId}) =>
      workflow('wf.requestTeamMembership', args, operationId ?? newId());
  Future<String> respondTeamInvite(Data args, {String? operationId}) =>
      workflow('wf.respondTeamInvite', args, operationId ?? newId());
  Future<String> leaveTeam(Data args, {String? operationId}) =>
      workflow('wf.leaveTeam', args, operationId ?? newId());
  Future<String> sendColleagueMessage(Data args, {String? operationId}) =>
      workflow('wf.sendColleagueMessage', args, operationId ?? newId());
  Future<String> markColleagueChatRead(Data args, {String? operationId}) =>
      workflow('wf.markColleagueChatRead', args, operationId ?? newId());
  Future<String> sendTeamMessage(Data args, {String? operationId}) =>
      workflow('wf.sendTeamMessage', args, operationId ?? newId());
  Future<String> markTeamChatRead(Data args, {String? operationId}) =>
      workflow('wf.markTeamChatRead', args, operationId ?? newId());
  Future<String> createTeamRound(Data args, {String? operationId}) =>
      workflow('wf.createTeamRound', args, operationId ?? newId());
  Future<String> assignTeamArea(Data args, {String? operationId}) =>
      workflow('wf.assignTeamArea', args, operationId ?? newId());
  Future<String> createPickupJob(Data args, {String? operationId}) =>
      workflow('wf.createPickupJob', args, operationId ?? newId());
  Future<String> assignPickupJob(Data args, {String? operationId}) =>
      workflow('wf.assignPickupJob', args, operationId ?? newId());
  Future<String> autoAssignTeamRound(Data args, {String? operationId}) =>
      workflow('wf.autoAssignTeamRound', args, operationId ?? newId());
  Future<String> updatePickupScope(Data args, {String? operationId}) =>
      workflow('wf.updatePickupScope', args, operationId ?? newId());
  Future<String> recordPackageCustody(Data args, {String? operationId}) =>
      workflow('wf.recordPackageCustody', args, operationId ?? newId());
  Future<String> requestPackageHandoff(Data args, {String? operationId}) =>
      workflow('wf.requestPackageHandoff', args, operationId ?? newId());
  Future<String> confirmPackageHandoff(Data args, {String? operationId}) =>
      workflow('wf.confirmPackageHandoff', args, operationId ?? newId());
  Future<String> recordPackageDelivery(Data args, {String? operationId}) =>
      workflow('wf.recordPackageDelivery', args, operationId ?? newId());
  Future<String> recordPackageReceipt(Data args, {String? operationId}) =>
      workflow('wf.recordPackageReceipt', args, operationId ?? newId());
  Future<String> recoverPackageCustody(Data args, {String? operationId}) =>
      workflow('wf.recoverPackageCustody', args, operationId ?? newId());
}
