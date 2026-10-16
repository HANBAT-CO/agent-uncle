import '../domain/models.dart';
import '../domain/team_models.dart';
import 'local_store.dart';

String applyTeam(MutableWorkspace s, String actor, String command, Data args) {
  final normalized = command.startsWith('wf.') ? command.substring(3) : command;
  if (normalized != 'recordPackageReceipt') {
    _requireUncleAccount(s, actor);
  }
  switch (normalized) {
    case 'connectColleague':
      return _connectColleague(s, actor, args);
    case 'respondColleagueConnection':
      return _respondColleagueConnection(s, actor, args);
    case 'createTeam':
      return _createTeam(s, actor, args);
    case 'inviteTeamMember':
      return _inviteTeamMember(s, actor, args);
    case 'requestTeamMembership':
      return _requestTeamMembership(s, actor, args);
    case 'respondTeamInvite':
      return _respondTeamInvite(s, actor, args);
    case 'leaveTeam':
      return _leaveTeam(s, actor, args);
    case 'sendColleagueMessage':
      return _sendColleagueMessage(s, actor, args);
    case 'markColleagueChatRead':
      return _markColleagueChatRead(s, actor, args);
    case 'sendTeamMessage':
      return _sendTeamMessage(s, actor, args);
    case 'markTeamChatRead':
      return _markTeamChatRead(s, actor, args);
    case 'createTeamRound':
      return _createTeamRound(s, actor, args);
    case 'assignTeamArea':
      return _assignTeamArea(s, actor, args);
    case 'createPickupJob':
      return _createPickupJob(s, actor, args);
    case 'assignPickupJob':
      return _assignPickupJob(s, actor, args);
    case 'autoAssignTeamRound':
      return _autoAssignTeamRound(s, actor, args);
    case 'updatePickupScope':
      return _updatePickupScope(s, actor, args);
    case 'recordPackageCustody':
      return _recordPackageCustody(s, actor, args);
    case 'requestPackageHandoff':
      return _requestPackageHandoff(s, actor, args);
    case 'confirmPackageHandoff':
      return _confirmPackageHandoff(s, actor, args);
    case 'recordPackageDelivery':
      return _recordPackageDelivery(s, actor, args);
    case 'recordPackageReceipt':
      return _recordPackageReceipt(s, actor, args);
    case 'recoverPackageCustody':
      return _recoverPackageCustody(s, actor, args);
  }
  throw AppFailure('지원하지 않는 팀 명령이에요: $normalized');
}

Map<String, Data> _table(MutableWorkspace s, String name) =>
    s.tables.putIfAbsent(name, () => <String, Data>{});

Data _requireFrom(MutableWorkspace s, String table, String id) =>
    _table(s, table)[id] ??
    (throw const AppFailure('기록을 찾을 수 없어요. 목록을 다시 확인해 주세요.'));

String _now() => DateTime.now().toIso8601String();

String _slug(String value) {
  final buffer = StringBuffer();
  var lastHyphen = false;
  for (final rune in value.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final ok = RegExp(r'[a-z0-9가-힣]').hasMatch(char);
    if (ok) {
      buffer.write(char);
      lastHyphen = false;
      continue;
    }
    if (!lastHyphen && buffer.isNotEmpty) {
      buffer.write('-');
      lastHyphen = true;
    }
  }
  final text = buffer.toString().replaceAll(RegExp(r'-+$'), '');
  return text.isEmpty ? 'item' : text;
}

List<String> _uniqueStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    result.add(trimmed);
  }
  return result;
}

String _textArg(Data args, String key, {bool required = true}) {
  final value = textOf(args, key).trim();
  if (required && value.isEmpty) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

int _intArg(Data args, String key, {int min = 0}) {
  final value = nullableNumberOf(args, key);
  if (value == null || value < min) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

int _versionArg(Data args, [String key = 'version']) {
  final value = nullableNumberOf(args, key);
  if (value == null || value < 0) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

void _checkVersion(Data data, int? version) {
  if (version == null) return;
  if (numberOf(data, 'version') != version) {
    throw const AppFailure('다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.');
  }
}

void _requireVersion(Data data, Data args, [String key = 'version']) =>
    _checkVersion(data, _versionArg(args, key));

Data _requireAccount(MutableWorkspace s, String userId) =>
    _requireFrom(s, 'accounts', userId);

void _requireUncleAccount(MutableWorkspace s, String userId) {
  if (!isUncleAccount(_requireAccount(s, userId))) {
    throw const AppFailure('사입삼촌만 팀 기능을 사용할 수 있어요.');
  }
}

Data? _activeTeamForMember(MutableWorkspace s, String userId) {
  for (final entry in _table(s, 'teams').entries) {
    final data = entry.value;
    if (textOf(data, 'status', 'active') != 'active') continue;
    if (teamMemberIdsOf(data).contains(userId)) return data;
  }
  return null;
}

String? _activeTeamIdForMember(MutableWorkspace s, String userId) =>
    _activeTeamForMember(s, userId)?['id'] as String?;

Data _requireTeam(MutableWorkspace s, String teamId, String userId) {
  final team = _requireFrom(s, 'teams', teamId);
  if (!isTeamMember(team, userId) ||
      textOf(team, 'status', 'active') != 'active') {
    throw const AppFailure('이 팀의 공동 업무를 볼 수 없어요.');
  }
  return team;
}

void _requireTeamAdmin(Data team, String userId) {
  if (!isTeamAdmin(team, userId)) {
    throw const AppFailure('팀장이나 운영자만 처리할 수 있어요.');
  }
}

Data? _acceptedColleague(MutableWorkspace s, String a, String b) {
  final id = _colleagueId(a, b);
  final record = _table(s, 'colleagueConnections')[id];
  if (record == null || textOf(record, 'status') != 'accepted') return null;
  return record;
}

String _colleagueId(String a, String b) {
  final pair = [a.trim(), b.trim()]..sort();
  return 'colleague:${pair.first}:${pair.last}';
}

String _teamInviteId(String teamId, String userId, String kind) =>
    kind == 'membership_request'
    ? 'team-membership:$teamId:$userId'
    : 'team-invite:$teamId:$userId';

void _putTeamRecord(MutableWorkspace s, String table, String id, Data data) {
  _table(s, table)[id] = {
    ...data,
    'id': id,
    'readers': _uniqueStrings(teamReadersOf(data)),
  };
}

void _syncTeamReaders(MutableWorkspace s, String teamId) {
  final team = _requireFrom(s, 'teams', teamId);
  final readers = teamMemberIdsOf(team);
  _putTeamRecord(s, 'teams', teamId, {...team, 'readers': readers});
  for (final tableName in [
    'teamInvites',
    'teamChats',
    'teamRounds',
    'teamAreas',
    'teamJobs',
    'teamPackages',
    'teamHandoffs',
    'teamReceipts',
  ]) {
    final table = _table(s, tableName);
    for (final entry in table.entries.toList()) {
      final row = entry.value;
      if (textOf(row, 'teamId') != teamId) continue;
      final extraReaders = switch (tableName) {
        'teamInvites' => [textOf(row, 'inviteeId')],
        'teamReceipts' => [textOf(row, 'confirmedBy')],
        _ => const <String>[],
      };
      final nextReaders = _uniqueStrings([...readers, ...extraReaders]);
      _putTeamRecord(s, tableName, entry.key, {
        ...row,
        'readers': nextReaders,
        if (row.containsKey('readerIds')) 'readerIds': nextReaders,
      });
    }
  }
}

void _ensureAcceptedColleague(MutableWorkspace s, String actor, String peerId) {
  if (_acceptedColleague(s, actor, peerId) == null) {
    throw const AppFailure('연결된 사입 동료에게만 요청하거나 대화할 수 있어요.');
  }
}

void _ensureTeamMemberAccount(Data team, String memberId) {
  if (!teamMemberIdsOf(team).contains(memberId)) {
    throw const AppFailure('같은 팀의 삼촌만 선택해 주세요.');
  }
}

bool _accountInactiveOrDeleted(MutableWorkspace s, String accountId) {
  final account = _table(s, 'accounts')[accountId];
  if (account == null) return true;
  return !flagOf(account, 'complete') || flagOf(account, 'deletionPending');
}

Data _requireAcceptedRequest(MutableWorkspace s, String requestId) {
  final request = _requireFrom(s, 'requests', requestId);
  if (textOf(request, 'status') != 'accepted') {
    throw const AppFailure('실제로 수락되어 진행 중인 요청만 팀 업무로 정리할 수 있어요.');
  }
  return request;
}

String _joinNonEmpty(Iterable<String> values, {String separator = ' · '}) {
  final filtered = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return filtered.join(separator);
}

String _accountLabel(MutableWorkspace s, String userId) {
  final normalized = userId.trim();
  if (normalized.isEmpty) return '미지정';
  final account = _table(s, 'accounts')[normalized];
  if (account == null) return normalized;
  return Account(normalized, account).displayName;
}

String _jobAreaLabel(MutableWorkspace s, Data job) {
  final areaId = textOf(job, 'areaId').trim();
  if (areaId.isEmpty) return '미지정';
  final area = _table(s, 'teamAreas')[areaId];
  return textOf(area ?? const <String, Object?>{}, 'name', areaId);
}

String _jobTargetLabel(Data job) {
  final label = _joinNonEmpty([
    textOf(job, 'retailerName'),
    textOf(job, 'wholesalerName'),
    textOf(job, 'wholesalerLocation'),
  ]);
  return label.isEmpty ? '대상 미확인' : label;
}

String _packageSummary(Data package) {
  final label = textOf(
    package,
    'packageLabel',
  ).ifEmpty(() => textOf(package, 'id'));
  final quantity = numberOf(package, 'quantity');
  final unit = textOf(package, 'unit', '묶음');
  return '$label $quantity$unit';
}

String _packageSummaryList(MutableWorkspace s, Iterable<String> packageIds) {
  final items = [
    for (final packageId in packageIds)
      if (_table(s, 'teamPackages')[packageId] case final package?)
        _packageSummary(package),
  ];
  return items.isEmpty ? '없음' : items.join(', ');
}

String _singleRequestIdForPackages(
  MutableWorkspace s,
  Iterable<String> packageIds,
) {
  final ids = _uniqueStrings([
    for (final packageId in packageIds)
      textOf(
        _table(s, 'teamPackages')[packageId] ?? const <String, Object?>{},
        'requestId',
      ),
  ]);
  return ids.length == 1 ? ids.first : '';
}

String _sourceCardId(
  String sourceType,
  String sourceId,
  String cardType,
  Object revision,
) => 'team-card:$sourceType:$sourceId:$cardType:$revision';

String _cardBody(String title, Iterable<String> lines) =>
    '$title\n- ${lines.join('\n- ')}';

List<String> _initialReadBy({
  required Iterable<String> readers,
  required String actor,
  Iterable<String> unreadFor = const <String>[],
}) {
  final normalizedReaders = _uniqueStrings(readers);
  final unreadTargets = _uniqueStrings(unreadFor);
  if (unreadTargets.isEmpty) return normalizedReaders;
  return [
    for (final reader in normalizedReaders)
      if (reader == actor || !unreadTargets.contains(reader)) reader,
  ];
}

void _putTeamSourceCard(
  MutableWorkspace s, {
  required String id,
  required String teamId,
  required String actor,
  required String sourceType,
  required String sourceId,
  required String requestId,
  required String cardType,
  required String body,
  required List<String> readers,
  List<String> unreadFor = const <String>[],
}) {
  if (_table(s, 'teamChats').containsKey(id)) return;
  final createdAt = _now();
  final normalizedReaders = _uniqueStrings(readers);
  _putTeamRecord(s, 'teamChats', id, {
    'teamId': teamId,
    'chatType': 'team',
    'kind': 'system',
    'senderId': actor,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'requestId': requestId,
    'cardType': cardType,
    'body': body,
    'createdAt': createdAt,
    'updatedAt': createdAt,
    'version': 0,
    'readBy': _initialReadBy(
      readers: normalizedReaders,
      actor: actor,
      unreadFor: unreadFor,
    ),
    'readers': normalizedReaders,
  });
}

void _logPickupAssignmentCard(
  MutableWorkspace s, {
  required String actor,
  required Data team,
  required Data job,
}) {
  final reason = textOf(job, 'assignmentReason').ifEmpty(() => '수동 배정');
  _putTeamSourceCard(
    s,
    id: _sourceCardId(
      'pickupJob',
      textOf(job, 'id'),
      'pickupAssignment',
      numberOf(job, 'version'),
    ),
    teamId: textOf(team, 'id'),
    actor: actor,
    sourceType: 'pickupJob',
    sourceId: textOf(job, 'id'),
    requestId: textOf(job, 'requestId'),
    cardType: 'pickupAssignment',
    body: _cardBody('배정 결과', [
      '구역: ${_jobAreaLabel(s, job)}',
      '픽업 담당: ${_accountLabel(s, textOf(job, 'pickupAssigneeId'))}',
      '전달 담당: ${_accountLabel(s, textOf(job, 'finalAssigneeId'))}',
      '대상: ${_jobTargetLabel(job)}',
      '사유: $reason',
    ]),
    readers: teamMemberIdsOf(team),
    unreadFor: [textOf(job, 'pickupAssigneeId')],
  );
}

void _logPickupPendingCard(
  MutableWorkspace s, {
  required String actor,
  required Data team,
  required Data job,
  required String reason,
}) {
  _putTeamSourceCard(
    s,
    id: _sourceCardId(
      'pickupJob',
      textOf(job, 'id'),
      'pickupPending',
      numberOf(job, 'version'),
    ),
    teamId: textOf(team, 'id'),
    actor: actor,
    sourceType: 'pickupJob',
    sourceId: textOf(job, 'id'),
    requestId: textOf(job, 'requestId'),
    cardType: 'pickupPending',
    body: _cardBody('남은 업무', [
      '구역: ${_jobAreaLabel(s, job)}',
      '대상: ${_jobTargetLabel(job)}',
      '사유: $reason',
    ]),
    readers: teamMemberIdsOf(team),
    unreadFor: teamAdminIdsOf(team),
  );
}

void _logHandoffRequestCard(
  MutableWorkspace s, {
  required String actor,
  required Data team,
  required Data handoff,
}) {
  final packageIds = teamPackageIdsOf(handoff);
  _putTeamSourceCard(
    s,
    id: _sourceCardId(
      'handoff',
      textOf(handoff, 'id'),
      'handoffRequest',
      numberOf(handoff, 'version'),
    ),
    teamId: textOf(team, 'id'),
    actor: actor,
    sourceType: 'handoff',
    sourceId: textOf(handoff, 'id'),
    requestId: _singleRequestIdForPackages(s, packageIds),
    cardType: 'handoffRequest',
    body: _cardBody('인계 요청', [
      '도매처: ${textOf(handoff, 'wholesalerName').ifEmpty(() => '미확인')}',
      '발신: ${_accountLabel(s, textOf(handoff, 'fromId'))}',
      '수신: ${_accountLabel(s, textOf(handoff, 'toId'))}',
      '포장: ${_packageSummaryList(s, packageIds)}',
    ]),
    readers: teamMemberIdsOf(team),
    unreadFor: [textOf(handoff, 'toId')],
  );
}

void _logHandoffResultCard(
  MutableWorkspace s, {
  required String actor,
  required Data team,
  required Data handoff,
}) {
  final pendingIds = teamPendingPackageIdsOf(handoff);
  final acceptedIds = teamAcceptedPackageIdsOf(handoff);
  final partial = pendingIds.isNotEmpty;
  final cardType = partial ? 'handoffPartial' : 'handoffConfirmed';
  final title = partial ? '인계 일부 수령' : '인계 수령 완료';
  _putTeamSourceCard(
    s,
    id: _sourceCardId(
      'handoff',
      textOf(handoff, 'id'),
      cardType,
      numberOf(handoff, 'version'),
    ),
    teamId: textOf(team, 'id'),
    actor: actor,
    sourceType: 'handoff',
    sourceId: textOf(handoff, 'id'),
    requestId: _singleRequestIdForPackages(s, teamPackageIdsOf(handoff)),
    cardType: cardType,
    body: _cardBody(title, [
      '도매처: ${textOf(handoff, 'wholesalerName').ifEmpty(() => '미확인')}',
      '발신: ${_accountLabel(s, textOf(handoff, 'fromId'))}',
      '수신: ${_accountLabel(s, textOf(handoff, 'toId'))}',
      '받은 포장: ${_packageSummaryList(s, acceptedIds)}',
      '남은 포장: ${_packageSummaryList(s, pendingIds)}',
    ]),
    readers: teamMemberIdsOf(team),
    unreadFor: partial ? [textOf(handoff, 'fromId')] : const <String>[],
  );
}

void _logPackageDeliveredCard(
  MutableWorkspace s, {
  required String actor,
  required Data team,
  required Data package,
}) {
  final recipient = textOf(
    package,
    'recipientLabel',
  ).ifEmpty(() => textOf(package, 'retailerName').ifEmpty(() => '고객 미확인'));
  _putTeamSourceCard(
    s,
    id: _sourceCardId(
      'package',
      textOf(package, 'id'),
      'packageDelivered',
      numberOf(package, 'version'),
    ),
    teamId: textOf(team, 'id'),
    actor: actor,
    sourceType: 'package',
    sourceId: textOf(package, 'id'),
    requestId: textOf(package, 'requestId'),
    cardType: 'packageDelivered',
    body: _cardBody('고객 전달 처리', [
      '전달 담당: ${_accountLabel(s, actor)}',
      '대상: $recipient',
      '포장: ${_packageSummary(package)}',
      '도매처: ${textOf(package, 'wholesalerName').ifEmpty(() => '미확인')}',
    ]),
    readers: teamMemberIdsOf(team),
  );
}

Data _pickupJobSeed(MutableWorkspace s, Data request, Data team, Data args) {
  final uncleId = textOf(request, 'uncleId');
  _ensureTeamMemberAccount(team, uncleId);
  final retailerId = textOf(request, 'retailerId');
  final retailer = retailerId.isEmpty
      ? null
      : Account(retailerId, _requireAccount(s, retailerId));
  final wholesalerRows = requestWholesalers(request)
      .where((row) => textOf(row, 'wholesaler').trim().isNotEmpty)
      .toList(growable: false);
  final requestedIndex = nullableNumberOf(args, 'wholesalerIndex');
  Data? selectedWholesaler;
  var selectedIndex = requestedIndex;
  if (requestedIndex != null) {
    if (requestedIndex < 0 || requestedIndex >= wholesalerRows.length) {
      throw const AppFailure('요청에 없는 도매처라 팀 업무로 옮길 수 없어요.');
    }
    selectedWholesaler = wholesalerRows[requestedIndex];
  } else {
    final requestedName = _textArg(args, 'wholesalerName', required: false);
    if (requestedName.isNotEmpty) {
      for (var index = 0; index < wholesalerRows.length; index++) {
        if (textOf(wholesalerRows[index], 'wholesaler') == requestedName) {
          selectedWholesaler = wholesalerRows[index];
          selectedIndex = index;
          break;
        }
      }
    }
    selectedWholesaler ??= wholesalerRows.isEmpty ? null : wholesalerRows.first;
    selectedIndex ??= wholesalerRows.isEmpty ? 0 : 0;
  }
  if (selectedWholesaler == null) {
    throw const AppFailure('도매처 정보가 없는 요청은 팀 업무로 정리할 수 없어요.');
  }
  return {
    'retailerId': retailerId,
    'retailerName': textOf(request, 'receivingShop').trim().ifEmpty(
      () => textOf(request, 'businessName').trim().ifEmpty(
        () => textOf(request, 'name').trim().ifEmpty(
          () => (retailer?.s('businessName').trim() ?? '').ifEmpty(
            () => (retailer?.name.trim() ?? '').ifEmpty(() => '소매 상호'),
          ),
        ),
      ),
    ),
    'wholesalerName': textOf(selectedWholesaler, 'wholesaler'),
    'wholesalerLocation': textOf(selectedWholesaler, 'location'),
    'requestUncleId': uncleId,
    'wholesalerIndex': selectedIndex,
  };
}

Data? _requireRoundForTeam(MutableWorkspace s, String teamId, String roundId) {
  if (roundId.trim().isEmpty) return null;
  final round = _requireFrom(s, 'teamRounds', roundId);
  if (textOf(round, 'teamId') != teamId ||
      textOf(round, 'status', 'active') != 'active') {
    throw const AppFailure('같은 팀의 활성 회차만 선택해 주세요.');
  }
  return round;
}

Data? _requireAreaForTeam(MutableWorkspace s, String teamId, String areaId) {
  if (areaId.trim().isEmpty) return null;
  final area = _requireFrom(s, 'teamAreas', areaId);
  if (textOf(area, 'teamId') != teamId) {
    throw const AppFailure('같은 팀의 구역만 선택해 주세요.');
  }
  return area;
}

bool _jobStarted(MutableWorkspace s, Data job) {
  if (!{'queued', 'assigned'}.contains(textOf(job, 'status', 'queued'))) {
    return true;
  }
  for (final package in _table(s, 'teamPackages').values) {
    if (textOf(package, 'jobId') == textOf(job, 'id')) return true;
  }
  for (final payment in _table(s, 'fieldPayments').values) {
    if (textOf(payment, 'requestId') == textOf(job, 'requestId') &&
        textOf(payment, 'teamId') == textOf(job, 'teamId')) {
      return true;
    }
  }
  return false;
}

void _blockIfOutstandingReimbursements(
  MutableWorkspace s,
  String teamId,
  String userId,
) {
  for (final row in _table(s, 'reimbursements').values) {
    if (textOf(row, 'teamId') != teamId) continue;
    if (textOf(row, 'status') == 'settled') continue;
    if ({textOf(row, 'fromId'), textOf(row, 'toId')}.contains(userId)) {
      throw const AppFailure(
        '개인 대납이나 팀 정산이 아직 남아 있어 팀을 바로 나갈 수 없어요. 먼저 반환과 회수를 끝내 주세요.',
      );
    }
  }
}

void _blockIfTeamWorkPending(MutableWorkspace s, String teamId, String userId) {
  for (final row in _table(s, 'teamJobs').values) {
    if (textOf(row, 'teamId') != teamId) continue;
    if (textOf(row, 'status') == 'received') continue;
    if ({
      textOf(row, 'pickupAssigneeId'),
      textOf(row, 'finalAssigneeId'),
    }.contains(userId)) {
      throw const AppFailure(
        '진행 중인 배정이 남아 있어 팀을 바로 나갈 수 없어요. 인계와 정산을 먼저 끝내 주세요.',
      );
    }
  }
  for (final row in _table(s, 'teamPackages').values) {
    if (textOf(row, 'teamId') != teamId) continue;
    if (!teamActivePackageStatuses.contains(textOf(row, 'status'))) continue;
    if ({
      textOf(row, 'currentHolderId'),
      textOf(row, 'finalAssigneeId'),
    }.contains(userId)) {
      throw const AppFailure(
        '보관 중이거나 전달 전인 물건이 남아 있어 팀을 바로 나갈 수 없어요. 실제 인계를 먼저 확인해 주세요.',
      );
    }
  }
  for (final row in _table(s, 'teamHandoffs').values) {
    if (textOf(row, 'teamId') != teamId) continue;
    if (!{'pending', 'partial'}.contains(textOf(row, 'status'))) continue;
    if ({textOf(row, 'fromId'), textOf(row, 'toId')}.contains(userId)) {
      throw const AppFailure(
        '인계 확인이 끝나지 않아 팀을 바로 나갈 수 없어요. 실제 받은 물건을 먼저 확인해 주세요.',
      );
    }
  }
  _blockIfOutstandingReimbursements(s, teamId, userId);
}

List<Data> _jobPackages(MutableWorkspace s, String jobId) => [
  for (final row in _table(s, 'teamPackages').values)
    if (textOf(row, 'jobId') == jobId) row,
];

List<Data> _jobIssues(MutableWorkspace s, String jobId) => [
  for (final row in _table(s, 'issues').values)
    if (textOf(row, 'jobId') == jobId &&
        textOf(row, 'status', 'open') != 'resolved')
      row,
];

void _updateRequestIssueCount(MutableWorkspace s, String requestId, int delta) {
  final request = _requireFrom(s, 'requests', requestId);
  final next = numberOf(request, 'openIssues') + delta;
  s.put('requests', requestId, {
    ...request,
    'openIssues': next < 0 ? 0 : next,
    'updatedAt': _now(),
    'version': numberOf(request, 'version') + 1,
  });
}

String _upsertReceiptIssue(
  MutableWorkspace s,
  String actor,
  Data job,
  List<String> remainingPackageIds,
  String note,
) {
  final requestId = textOf(job, 'requestId');
  final jobId = textOf(job, 'id');
  for (final entry in _table(s, 'issues').entries.toList()) {
    final row = entry.value;
    if (textOf(row, 'jobId') != jobId ||
        textOf(row, 'kind') != 'team_receipt_gap') {
      continue;
    }
    final resolved = textOf(row, 'status', 'open') == 'resolved';
    if (remainingPackageIds.isEmpty) {
      if (!resolved) {
        s.put('issues', entry.key, {
          ...row,
          'status': 'resolved',
          'version': numberOf(row, 'version') + 1,
          'resolvedAt': _now(),
          'resolvedBy': actor,
        });
        _updateRequestIssueCount(s, requestId, -1);
      }
      return entry.key;
    }
    if (resolved) continue;
    s.put('issues', entry.key, {
      ...row,
      'packageIds': remainingPackageIds,
      'note': note,
      'updatedAt': _now(),
      'version': numberOf(row, 'version') + 1,
    });
    return entry.key;
  }
  if (remainingPackageIds.isEmpty) return '';
  final issueId = 'team-issue:${newId()}';
  s.put('issues', issueId, {
    'requestId': requestId,
    'teamId': textOf(job, 'teamId'),
    'jobId': jobId,
    'packageIds': remainingPackageIds,
    'reporterId': actor,
    'status': 'open',
    'kind': 'team_receipt_gap',
    'reason': '일부 포장만 수령 확인됐어요.',
    'note': note,
    'held': 0,
    'version': 0,
    'createdAt': _now(),
    'updatedAt': _now(),
  });
  _updateRequestIssueCount(s, requestId, 1);
  return issueId;
}

Map<String, int> _requiredPackageVersions(
  Data args,
  Iterable<String> packageIds,
) {
  final versions = packageVersionsOf(args, 'versions');
  final ids = packageIds.toList(growable: false);
  if (ids.isNotEmpty && versions.length < ids.length) {
    throw const AppFailure('선택한 포장의 버전 정보를 다시 확인해 주세요. 최신 화면에서 다시 시도해 주세요.');
  }
  for (final packageId in ids) {
    if (!versions.containsKey(packageId)) {
      throw const AppFailure('선택한 포장의 버전 정보를 다시 확인해 주세요. 최신 화면에서 다시 시도해 주세요.');
    }
  }
  return versions;
}

bool _jobCanComplete(MutableWorkspace s, Data job, List<Data> packages) {
  if (!flagOf(job, 'scopeConfirmed')) return false;
  if (flagOf(job, 'hasBackorder')) return false;
  final expected = numberOf(job, 'expectedPackageCount');
  if (expected <= 0 || expected != packages.length) return false;
  if (_jobIssues(s, textOf(job, 'id')).isNotEmpty) return false;
  return true;
}

int _memberLoad(MutableWorkspace s, String memberId) {
  var total = 0;
  for (final row in _table(s, 'teamJobs').values) {
    if (teamTerminalStatuses.contains(textOf(row, 'status'))) continue;
    if ({
      textOf(row, 'pickupAssigneeId'),
      textOf(row, 'finalAssigneeId'),
    }.contains(memberId)) {
      total += 1;
    }
  }
  return total;
}

bool _workingAllowed(Data area, bool primary) =>
    primary ? flagOf(area, 'primaryWorking') : flagOf(area, 'backupWorking');

int _capacityOf(Data area, bool primary) {
  final key = primary ? 'primaryCapacity' : 'backupCapacity';
  final value = nullableNumberOf(area, key) ?? 0;
  return value < 0 ? 0 : value;
}

String _cutoffOf(Data area, bool primary) =>
    textOf(area, primary ? 'primaryCutoffAt' : 'backupCutoffAt');

bool _beforeCutoff(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  final now = DateTime.now();
  if (trimmed.contains('T')) {
    final date = DateTime.tryParse(trimmed);
    return date == null || !now.isAfter(date);
  }
  final parts = trimmed.split(':');
  if (parts.length != 2) return true;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return true;
  final cutoff = DateTime(now.year, now.month, now.day, hour, minute);
  return !now.isAfter(cutoff);
}

bool _memberAvailableForArea(
  MutableWorkspace s,
  Data area,
  String memberId,
  bool primary,
) {
  if (memberId.trim().isEmpty) return false;
  if (!_workingAllowed(area, primary)) return false;
  if (!_beforeCutoff(_cutoffOf(area, primary))) return false;
  final capacity = _capacityOf(area, primary);
  if (capacity > 0 && _memberLoad(s, memberId) >= capacity) return false;
  return true;
}

List<String> _areaKeywords(Data area) {
  final direct = teamMatchKeywordsOf(area);
  if (direct.isNotEmpty) {
    return _uniqueStrings([textOf(area, 'name'), ...direct]);
  }
  return _uniqueStrings([textOf(area, 'name')]);
}

bool _areaMatchesJob(Data area, Data job) {
  final haystack =
      '${textOf(job, 'wholesalerName')} ${textOf(job, 'wholesalerLocation')}'
          .toLowerCase();
  final matches = _areaKeywords(area)
      .where((keyword) => keyword.trim().isNotEmpty)
      .where((keyword) => haystack.contains(keyword.trim().toLowerCase()))
      .length;
  return matches > 0;
}

void _recomputeJobStatus(MutableWorkspace s, String jobId) {
  final job = _table(s, 'teamJobs')[jobId];
  if (job == null) return;
  final packages = _jobPackages(s, jobId);
  if (packages.isEmpty) return;
  final statuses = packages.map((row) => textOf(row, 'status')).toSet();
  final allReceived = statuses.every((status) => status == 'received');
  final allDeliveredOrReceived = statuses.every(
    (status) => {'delivered', 'received'}.contains(status),
  );
  final nextStatus = allReceived
      ? (_jobCanComplete(s, job, packages) ? 'received' : 'issue')
      : allDeliveredOrReceived
      ? 'delivered'
      : statuses.contains('handoff_requested')
      ? 'handoff_requested'
      : statuses.contains('delivery_ready')
      ? 'delivery_ready'
      : statuses.contains('picked') || statuses.contains('held')
      ? 'picked'
      : textOf(job, 'status', 'assigned');
  _putTeamRecord(s, 'teamJobs', jobId, {
    ...job,
    'status': nextStatus,
    'updatedAt': _now(),
    'version': numberOf(job, 'version') + 1,
  });
}

String _connectColleague(MutableWorkspace s, String actor, Data args) {
  final peerId = _textArg(args, 'peerId');
  if (peerId == actor) throw const AppFailure('본인을 사입 동료로 추가할 수 없어요.');
  final me = _requireAccount(s, actor);
  final peer = _requireAccount(s, peerId);
  if (textOf(peer, 'role') != 'uncle' ||
      !flagOf(peer, 'complete') ||
      !flagOf(me, 'complete')) {
    throw const AppFailure('가입을 완료한 다른 사입삼촌에게만 연결을 보낼 수 있어요.');
  }
  final id = _colleagueId(actor, peerId);
  final previous = _table(s, 'colleagueConnections')[id];
  if (previous != null &&
      {'pending', 'accepted'}.contains(textOf(previous, 'status'))) {
    throw AppFailure(
      textOf(previous, 'status') == 'accepted'
          ? '이미 연결된 사입 동료예요.'
          : '이미 수락을 기다리고 있어요.',
    );
  }
  _putTeamRecord(s, 'colleagueConnections', id, {
    'fromId': actor,
    'toId': peerId,
    'status': 'pending',
    'createdAt': previous?['createdAt'] ?? _now(),
    'updatedAt': _now(),
    'version': 1,
    'readers': [actor, peerId],
  });
  return id;
}

String _respondColleagueConnection(
  MutableWorkspace s,
  String actor,
  Data args,
) {
  final id = _textArg(args, 'id');
  final status = _textArg(args, 'status');
  if (!{'accepted', 'declined'}.contains(status)) {
    throw const AppFailure('연결 응답 상태를 다시 확인해 주세요.');
  }
  final row = _requireFrom(s, 'colleagueConnections', id);
  _requireVersion(row, args);
  if (textOf(row, 'toId') != actor || textOf(row, 'status') != 'pending') {
    throw const AppFailure('받은 연결 요청만 처리할 수 있어요.');
  }
  _putTeamRecord(s, 'colleagueConnections', id, {
    ...row,
    'status': status,
    'updatedAt': _now(),
    'version': numberOf(row, 'version') + 1,
  });
  return id;
}

String _createTeam(MutableWorkspace s, String actor, Data args) {
  if (_activeTeamForMember(s, actor) != null) {
    throw const AppFailure('한 번에 하나의 활성 팀만 운영할 수 있어요. 먼저 기존 팀을 정리해 주세요.');
  }
  final name = _textArg(args, 'name');
  final teamId = _textArg(
    args,
    'teamId',
    required: false,
  ).ifEmpty(() => 'team:${_slug(name)}:${newId()}');
  if (_table(s, 'teams').containsKey(teamId)) {
    throw const AppFailure('이미 사용 중인 팀 식별자예요. 새 팀으로 다시 만들어 주세요.');
  }
  final now = _now();
  _putTeamRecord(s, 'teams', teamId, {
    'name': name,
    'description': _textArg(args, 'description', required: false),
    'ownerId': actor,
    'adminIds': [actor],
    'memberIds': [actor],
    'status': 'active',
    'createdAt': now,
    'updatedAt': now,
    'version': 0,
    'readers': [actor],
  });
  final defaultChatId = 'team-chat:$teamId';
  _putTeamRecord(s, 'teamChats', defaultChatId, {
    'teamId': teamId,
    'chatType': 'team',
    'kind': 'system',
    'senderId': actor,
    'body': '팀이 만들어졌어요. 초대 전까지 팀장만 볼 수 있어요.',
    'createdAt': now,
    'updatedAt': now,
    'version': 0,
    'readBy': [actor],
    'readers': [actor],
  });
  return teamId;
}

String _inviteTeamMember(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final inviteeId = _textArg(args, 'inviteeId');
  final team = _requireTeam(s, teamId, actor);
  _requireTeamAdmin(team, actor);
  _requireUncleAccount(s, inviteeId);
  if (inviteeId == actor) throw const AppFailure('본인에게 팀 초대를 보낼 수 없어요.');
  if (teamMemberIdsOf(team).contains(inviteeId)) {
    throw const AppFailure('이미 같은 팀에 참여 중인 동료예요.');
  }
  _ensureAcceptedColleague(s, actor, inviteeId);
  final activeOtherTeam = _activeTeamIdForMember(s, inviteeId);
  if (activeOtherTeam != null && activeOtherTeam != teamId) {
    throw const AppFailure('상대방이 이미 다른 팀에서 활동 중이에요.');
  }
  final id = _teamInviteId(teamId, inviteeId, 'invite');
  final previous = _table(s, 'teamInvites')[id];
  if (previous != null && textOf(previous, 'status') == 'pending') {
    throw const AppFailure('이미 응답을 기다리는 팀 초대예요.');
  }
  _putTeamRecord(s, 'teamInvites', id, {
    'teamId': teamId,
    'inviterId': actor,
    'inviteeId': inviteeId,
    'kind': 'invite',
    'status': 'pending',
    'note': _textArg(args, 'note', required: false),
    'createdAt': previous?['createdAt'] ?? _now(),
    'updatedAt': _now(),
    'version': numberOf(previous ?? const <String, Object?>{}, 'version') + 1,
    'readers': _uniqueStrings([...teamMemberIdsOf(team), inviteeId]),
  });
  return id;
}

String _requestTeamMembership(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireFrom(s, 'teams', teamId);
  if (textOf(team, 'status', 'active') != 'active') {
    throw const AppFailure('이미 정리된 팀에는 참여 요청을 보낼 수 없어요.');
  }
  if (teamMemberIdsOf(team).contains(actor)) {
    throw const AppFailure('이미 이 팀에 참여 중이에요.');
  }
  if (_activeTeamForMember(s, actor) != null) {
    throw const AppFailure('한 번에 하나의 활성 팀만 참여할 수 있어요.');
  }
  final approverId = _textArg(
    args,
    'approverId',
    required: false,
  ).ifEmpty(() => textOf(team, 'ownerId'));
  _ensureTeamMemberAccount(team, approverId);
  _ensureAcceptedColleague(s, actor, approverId);
  final id = _teamInviteId(teamId, actor, 'membership_request');
  final previous = _table(s, 'teamInvites')[id];
  if (previous != null && textOf(previous, 'status') == 'pending') {
    throw const AppFailure('이미 응답을 기다리는 팀 참여 요청이에요.');
  }
  _putTeamRecord(s, 'teamInvites', id, {
    'teamId': teamId,
    'inviterId': actor,
    'inviteeId': actor,
    'approverId': approverId,
    'kind': 'membership_request',
    'status': 'pending',
    'note': _textArg(args, 'note', required: false),
    'createdAt': previous?['createdAt'] ?? _now(),
    'updatedAt': _now(),
    'version': numberOf(previous ?? const <String, Object?>{}, 'version') + 1,
    'readers': _uniqueStrings([...teamMemberIdsOf(team), actor]),
  });
  return id;
}

String _respondTeamInvite(MutableWorkspace s, String actor, Data args) {
  final id = _textArg(args, 'id');
  final status = _textArg(args, 'status');
  if (!{'accepted', 'declined'}.contains(status)) {
    throw const AppFailure('팀 초대 응답 상태를 다시 확인해 주세요.');
  }
  final invite = _requireFrom(s, 'teamInvites', id);
  _requireVersion(invite, args);
  final teamId = textOf(invite, 'teamId');
  final team = _requireFrom(s, 'teams', teamId);
  if (textOf(team, 'status', 'active') != 'active') {
    throw const AppFailure('이미 정리된 팀이라 참여할 수 없어요.');
  }
  final kind = textOf(invite, 'kind', 'invite');
  if (textOf(invite, 'status') != 'pending') {
    throw const AppFailure('대기 중인 요청만 처리할 수 있어요.');
  }
  if (kind == 'membership_request') {
    _requireTeam(s, teamId, actor);
    _requireTeamAdmin(team, actor);
  } else if (textOf(invite, 'inviteeId') != actor) {
    throw const AppFailure('받은 팀 초대만 처리할 수 있어요.');
  }
  if (status == 'accepted') {
    final memberId = textOf(invite, 'inviteeId');
    final active = _activeTeamIdForMember(s, memberId);
    if (active != null && active != teamId) {
      throw const AppFailure('한 번에 하나의 활성 팀만 참여할 수 있어요.');
    }
    _putTeamRecord(s, 'teams', teamId, {
      ...team,
      'memberIds': _uniqueStrings([...teamMemberIdsOf(team), memberId]),
      'updatedAt': _now(),
      'version': numberOf(team, 'version') + 1,
      'readers': _uniqueStrings([...teamMemberIdsOf(team), memberId]),
    });
    _syncTeamReaders(s, teamId);
  }
  _putTeamRecord(s, 'teamInvites', id, {
    ...invite,
    'status': status,
    'respondedBy': actor,
    'updatedAt': _now(),
    'version': numberOf(invite, 'version') + 1,
  });
  if (status == 'accepted') _syncTeamReaders(s, teamId);
  return teamId;
}

String _leaveTeam(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireTeam(s, teamId, actor);
  if (nullableNumberOf(args, 'version') != null) {
    _checkVersion(team, nullableNumberOf(args, 'version'));
  }
  _blockIfTeamWorkPending(s, teamId, actor);
  final members = [...teamMemberIdsOf(team)]..remove(actor);
  final admins = [...teamAdminIdsOf(team)]..remove(actor);
  if (textOf(team, 'ownerId') == actor && members.isNotEmpty) {
    throw const AppFailure('팀장은 먼저 물건과 권한을 넘긴 뒤 팀 정리를 완료해 주세요.');
  }
  _putTeamRecord(s, 'teams', teamId, {
    ...team,
    'memberIds': members,
    'adminIds': admins,
    'status': members.isEmpty ? 'archived' : textOf(team, 'status', 'active'),
    'updatedAt': _now(),
    'version': numberOf(team, 'version') + 1,
    'readers': members,
  });
  _syncTeamReaders(s, teamId);
  return teamId;
}

String _sendColleagueMessage(MutableWorkspace s, String actor, Data args) {
  final peerId = _textArg(args, 'peerId');
  _ensureAcceptedColleague(s, actor, peerId);
  final body = _textArg(args, 'body');
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'colleague-chat:${newId()}');
  if (_table(s, 'teamChats').containsKey(id)) return id;
  _putTeamRecord(s, 'teamChats', id, {
    'chatType': 'colleague',
    'senderId': actor,
    'peerId': peerId,
    'body': body,
    'kind': 'text',
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
    'readBy': [actor],
    'readers': [actor, peerId],
  });
  return id;
}

String _markColleagueChatRead(MutableWorkspace s, String actor, Data args) {
  final peerId = _textArg(args, 'peerId');
  for (final entry in _table(s, 'teamChats').entries.toList()) {
    final row = entry.value;
    if (textOf(row, 'chatType') != 'colleague') continue;
    final participants = {textOf(row, 'senderId'), textOf(row, 'peerId')};
    if (!participants.containsAll({actor, peerId})) continue;
    final readBy = _uniqueStrings([...teamReadByOf(row), actor]);
    _putTeamRecord(s, 'teamChats', entry.key, {
      ...row,
      'readBy': readBy,
      'updatedAt': _now(),
      'version': numberOf(row, 'version') + 1,
    });
  }
  return peerId;
}

String _sendTeamMessage(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireTeam(s, teamId, actor);
  final body = _textArg(args, 'body');
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-chat:${newId()}');
  if (_table(s, 'teamChats').containsKey(id)) return id;
  _putTeamRecord(s, 'teamChats', id, {
    'teamId': teamId,
    'chatType': 'team',
    'senderId': actor,
    'body': body,
    'kind': 'text',
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
    'readBy': [actor],
    'readers': teamMemberIdsOf(team),
  });
  return id;
}

String _markTeamChatRead(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  _requireTeam(s, teamId, actor);
  for (final entry in _table(s, 'teamChats').entries.toList()) {
    final row = entry.value;
    if (textOf(row, 'chatType') != 'team' || textOf(row, 'teamId') != teamId) {
      continue;
    }
    final readBy = _uniqueStrings([...teamReadByOf(row), actor]);
    _putTeamRecord(s, 'teamChats', entry.key, {
      ...row,
      'readBy': readBy,
      'updatedAt': _now(),
      'version': numberOf(row, 'version') + 1,
    });
  }
  return teamId;
}

String _createTeamRound(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireTeam(s, teamId, actor);
  _requireTeamAdmin(team, actor);
  final label = _textArg(args, 'label');
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-round:$teamId:${_slug(label)}:${newId()}');
  if (_table(s, 'teamRounds').containsKey(id)) {
    throw const AppFailure('이미 사용 중인 회차 식별자예요. 새 회차로 다시 만들어 주세요.');
  }
  _putTeamRecord(s, 'teamRounds', id, {
    'teamId': teamId,
    'label': label,
    'operatingDate': _textArg(args, 'operatingDate', required: false),
    'receiverLabel': _textArg(args, 'receiverLabel', required: false),
    'status': 'active',
    'createdBy': actor,
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
    'readers': teamMemberIdsOf(team),
  });
  return id;
}

String _assignTeamArea(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireTeam(s, teamId, actor);
  _requireTeamAdmin(team, actor);
  final name = _textArg(args, 'name');
  final primaryMemberId = _textArg(args, 'primaryMemberId');
  final backupMemberId = _textArg(args, 'backupMemberId', required: false);
  _ensureTeamMemberAccount(team, primaryMemberId);
  if (backupMemberId.isNotEmpty) _ensureTeamMemberAccount(team, backupMemberId);
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-area:$teamId:${_slug(name)}');
  final previous = _table(s, 'teamAreas')[id];
  if (previous != null) {
    if (textOf(previous, 'teamId') != teamId) {
      throw const AppFailure('다른 팀의 구역을 변경할 수 없어요.');
    }
    _requireVersion(previous, args);
  }
  _putTeamRecord(s, 'teamAreas', id, {
    ...?previous,
    'teamId': teamId,
    'name': name,
    'primaryMemberId': primaryMemberId,
    'backupMemberId': backupMemberId,
    'primaryWorking': args['primaryWorking'] != false,
    'backupWorking': args['backupWorking'] == true,
    'primaryCapacity':
        nullableNumberOf(args, 'primaryCapacity') ??
        nullableNumberOf(previous ?? {}, 'primaryCapacity') ??
        0,
    'backupCapacity':
        nullableNumberOf(args, 'backupCapacity') ??
        nullableNumberOf(previous ?? {}, 'backupCapacity') ??
        0,
    'primaryCutoffAt': _textArg(
      args,
      'primaryCutoffAt',
      required: false,
    ).ifEmpty(() => textOf(previous ?? {}, 'primaryCutoffAt')),
    'backupCutoffAt': _textArg(
      args,
      'backupCutoffAt',
      required: false,
    ).ifEmpty(() => textOf(previous ?? {}, 'backupCutoffAt')),
    'matchKeywords': _uniqueStrings([
      ...teamMatchKeywordsOf(previous ?? {}),
      ...stringsOf(args, 'matchKeywords'),
      ..._textArg(args, 'matchKeywordsText', required: false)
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    ]),
    'updatedAt': _now(),
    'createdAt': previous?['createdAt'] ?? _now(),
    'version': numberOf(previous ?? const <String, Object?>{}, 'version') + 1,
    'readers': teamMemberIdsOf(team),
  });
  return id;
}

String _createPickupJob(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireTeam(s, teamId, actor);
  _requireTeamAdmin(team, actor);
  final requestId = _textArg(args, 'requestId');
  final request = _requireAcceptedRequest(s, requestId);
  final seed = _pickupJobSeed(s, request, team, args);
  final wholesalerIndex = nullableNumberOf(seed, 'wholesalerIndex') ?? 0;
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-job:$teamId:$requestId:$wholesalerIndex');
  if (_table(s, 'teamJobs').containsKey(id)) {
    throw const AppFailure('이미 사용 중인 업무 식별자예요. 기존 기록을 확인해 주세요.');
  }
  for (final row in _table(s, 'teamJobs').values) {
    if (textOf(row, 'requestId') != requestId ||
        numberOf(row, 'wholesalerIndex') != wholesalerIndex) {
      continue;
    }
    if (!teamTerminalStatuses.contains(textOf(row, 'status'))) {
      throw const AppFailure('같은 요청의 같은 도매처는 한 번만 팀 업무로 정리할 수 있어요.');
    }
  }
  final roundId = _textArg(args, 'roundId', required: false);
  final areaId = _textArg(args, 'areaId', required: false);
  _requireRoundForTeam(s, teamId, roundId);
  _requireAreaForTeam(s, teamId, areaId);
  final pickupAssigneeId = _textArg(args, 'pickupAssigneeId', required: false);
  final finalAssigneeId = _textArg(args, 'finalAssigneeId', required: false);
  if (pickupAssigneeId.isNotEmpty) {
    _ensureTeamMemberAccount(team, pickupAssigneeId);
  }
  if (finalAssigneeId.isNotEmpty) {
    _ensureTeamMemberAccount(team, finalAssigneeId);
  }
  _putTeamRecord(s, 'teamJobs', id, {
    'teamId': teamId,
    'requestId': requestId,
    'roundId': roundId,
    'areaId': areaId,
    'wholesalerName': seed['wholesalerName'],
    'wholesalerLocation': seed['wholesalerLocation'],
    'retailerId': seed['retailerId'],
    'retailerName': seed['retailerName'],
    'requestUncleId': seed['requestUncleId'],
    'wholesalerIndex': wholesalerIndex,
    'pickupAssigneeId': pickupAssigneeId,
    'finalAssigneeId': finalAssigneeId,
    'assignmentReason': _textArg(args, 'assignmentReason', required: false),
    'autoAssignReason': '',
    'scopeConfirmed': false,
    'expectedPackageCount': 0,
    'hasBackorder': false,
    'note': _textArg(args, 'note', required: false),
    'status': 'queued',
    'createdBy': actor,
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
    'readers': teamMemberIdsOf(team),
  });
  return id;
}

String _assignPickupJob(MutableWorkspace s, String actor, Data args) {
  final id = _textArg(args, 'id');
  final job = _requireFrom(s, 'teamJobs', id);
  _requireVersion(job, args);
  final team = _requireTeam(s, textOf(job, 'teamId'), actor);
  _requireTeamAdmin(team, actor);
  final pickupAssigneeId = _textArg(args, 'pickupAssigneeId');
  final finalAssigneeId = _textArg(args, 'finalAssigneeId');
  _ensureTeamMemberAccount(team, pickupAssigneeId);
  _ensureTeamMemberAccount(team, finalAssigneeId);
  final previousPickup = textOf(job, 'pickupAssigneeId');
  if (previousPickup.isNotEmpty &&
      previousPickup != pickupAssigneeId &&
      _jobStarted(s, job)) {
    throw const AppFailure(
      '이미 픽업을 시작했거나 현장 지급이 생긴 업무는 자동 재배정할 수 없어요. 남은 작업만 따로 처리해 주세요.',
    );
  }
  final roundId = _textArg(
    args,
    'roundId',
    required: false,
  ).ifEmpty(() => textOf(job, 'roundId'));
  final areaId = _textArg(
    args,
    'areaId',
    required: false,
  ).ifEmpty(() => textOf(job, 'areaId'));
  _requireRoundForTeam(s, textOf(job, 'teamId'), roundId);
  _requireAreaForTeam(s, textOf(job, 'teamId'), areaId);
  final updatedJob = {
    ...job,
    'roundId': roundId,
    'areaId': areaId,
    'pickupAssigneeId': pickupAssigneeId,
    'finalAssigneeId': finalAssigneeId,
    'assignmentReason': _textArg(
      args,
      'assignmentReason',
      required: false,
    ).ifEmpty(() => textOf(job, 'assignmentReason')),
    'autoAssignReason': '',
    'status': _jobStarted(s, job) ? textOf(job, 'status') : 'assigned',
    'updatedAt': _now(),
    'version': numberOf(job, 'version') + 1,
  };
  _putTeamRecord(s, 'teamJobs', id, updatedJob);
  _logPickupAssignmentCard(s, actor: actor, team: team, job: updatedJob);
  return id;
}

String _autoAssignTeamRound(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final roundId = _textArg(args, 'roundId');
  final team = _requireTeam(s, teamId, actor);
  _requireTeamAdmin(team, actor);
  _requireRoundForTeam(s, teamId, roundId);
  final areas = [
    for (final area in _table(s, 'teamAreas').values)
      if (textOf(area, 'teamId') == teamId) area,
  ];
  for (final entry in _table(s, 'teamJobs').entries.toList()) {
    final job = entry.value;
    if (textOf(job, 'teamId') != teamId || textOf(job, 'roundId') != roundId) {
      continue;
    }
    if (textOf(job, 'status', 'queued') != 'queued' ||
        textOf(job, 'pickupAssigneeId').isNotEmpty) {
      continue;
    }
    if (_jobStarted(s, job)) {
      final updatedJob = {
        ...job,
        'autoAssignReason': '이미 픽업을 시작했거나 현장 지급이 있어 자동 재배정할 수 없어요.',
        'updatedAt': _now(),
        'version': numberOf(job, 'version') + 1,
      };
      _putTeamRecord(s, 'teamJobs', entry.key, updatedJob);
      _logPickupPendingCard(
        s,
        actor: actor,
        team: team,
        job: updatedJob,
        reason: textOf(updatedJob, 'autoAssignReason'),
      );
      continue;
    }
    final matches = areas
        .where((area) => _areaMatchesJob(area, job))
        .toList(growable: false);
    if (matches.length != 1) {
      final reason = matches.isEmpty
          ? '도매처 위치와 정확히 맞는 구역이 없어 자동 배정하지 않았어요.'
          : '도매처 위치와 맞는 구역이 여러 개라 수동 확인이 필요해요.';
      final updatedJob = {
        ...job,
        'autoAssignReason': reason,
        'updatedAt': _now(),
        'version': numberOf(job, 'version') + 1,
      };
      _putTeamRecord(s, 'teamJobs', entry.key, updatedJob);
      _logPickupPendingCard(
        s,
        actor: actor,
        team: team,
        job: updatedJob,
        reason: reason,
      );
      continue;
    }
    final area = matches.single;
    final primaryMemberId = textOf(area, 'primaryMemberId');
    final backupMemberId = textOf(area, 'backupMemberId');
    String assigneeId = '';
    String assignmentReason = '';
    if (_memberAvailableForArea(s, area, primaryMemberId, true)) {
      assigneeId = primaryMemberId;
      assignmentReason = '${textOf(area, 'name')} 주담당 자동 배정';
    } else if (_memberAvailableForArea(s, area, backupMemberId, false)) {
      assigneeId = backupMemberId;
      assignmentReason = '${textOf(area, 'name')} 대체 담당 자동 배정';
    }
    if (assigneeId.isEmpty) {
      final updatedJob = {
        ...job,
        'areaId': textOf(area, 'id'),
        'autoAssignReason': '근무 중이면서 마감 전이고 작업량 여유가 있는 담당자가 없어 자동 배정하지 않았어요.',
        'updatedAt': _now(),
        'version': numberOf(job, 'version') + 1,
      };
      _putTeamRecord(s, 'teamJobs', entry.key, updatedJob);
      _logPickupPendingCard(
        s,
        actor: actor,
        team: team,
        job: updatedJob,
        reason: textOf(updatedJob, 'autoAssignReason'),
      );
      continue;
    }
    final finalAssigneeId = textOf(job, 'requestUncleId').isNotEmpty
        ? textOf(job, 'requestUncleId')
        : assigneeId;
    final updatedJob = {
      ...job,
      'areaId': textOf(area, 'id'),
      'pickupAssigneeId': assigneeId,
      'finalAssigneeId': finalAssigneeId,
      'assignmentReason': assignmentReason,
      'autoAssignReason': '',
      'status': 'assigned',
      'updatedAt': _now(),
      'version': numberOf(job, 'version') + 1,
    };
    _putTeamRecord(s, 'teamJobs', entry.key, updatedJob);
    _logPickupAssignmentCard(s, actor: actor, team: team, job: updatedJob);
  }
  return roundId;
}

String _updatePickupScope(MutableWorkspace s, String actor, Data args) {
  final id = _textArg(args, 'id');
  final job = _requireFrom(s, 'teamJobs', id);
  _requireVersion(job, args);
  final team = _requireTeam(s, textOf(job, 'teamId'), actor);
  _ensureTeamMemberAccount(team, actor);
  final expectedPackageCount = _intArg(args, 'expectedPackageCount', min: 0);
  final packages = _jobPackages(s, id);
  if (expectedPackageCount > 0 && packages.length > expectedPackageCount) {
    throw const AppFailure('이미 기록한 포장 수보다 적게 확정할 수 없어요. 기존 포장 기록을 먼저 확인해 주세요.');
  }
  final scopeConfirmed = args['scopeConfirmed'] == true;
  if (scopeConfirmed && expectedPackageCount <= 0) {
    throw const AppFailure('포장 식별 수를 입력한 뒤 범위를 확정해 주세요.');
  }
  final hasBackorder = args['hasBackorder'] == true;
  _putTeamRecord(s, 'teamJobs', id, {
    ...job,
    'scopeConfirmed': scopeConfirmed,
    'expectedPackageCount': expectedPackageCount,
    'hasBackorder': hasBackorder,
    'scopeNote': _textArg(args, 'note', required: false),
    'updatedAt': _now(),
    'version': numberOf(job, 'version') + 1,
  });
  _recomputeJobStatus(s, id);
  return id;
}

String _recordPackageCustody(MutableWorkspace s, String actor, Data args) {
  final jobId = _textArg(args, 'jobId');
  final job = _requireFrom(s, 'teamJobs', jobId);
  final team = _requireTeam(s, textOf(job, 'teamId'), actor);
  final actualPickupAssigneeId = textOf(job, 'pickupAssigneeId');
  if (actualPickupAssigneeId.isEmpty || actualPickupAssigneeId != actor) {
    throw const AppFailure('실제로 배정된 픽업 담당 삼촌만 현장 포장을 기록할 수 있어요.');
  }
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-package:${newId()}');
  final previous = _table(s, 'teamPackages')[id];
  if (previous != null) {
    _requireVersion(previous, args);
    if (textOf(previous, 'jobId') != jobId) {
      throw const AppFailure(
        '이미 다른 업무에 묶인 포장 기록은 옮길 수 없어요. 새 포장으로 따로 기록해 주세요.',
      );
    }
    if (textOf(previous, 'currentHolderId') != actor) {
      throw const AppFailure(
        '현재 보관 중인 삼촌만 포장 상태를 바로 바꿀 수 있어요. 인계는 별도 확인이 필요해요.',
      );
    }
    if (teamTerminalStatuses.contains(textOf(previous, 'status')) ||
        textOf(previous, 'status') == 'delivered') {
      throw const AppFailure('이미 전달이 끝난 포장 상태는 초기화하거나 다른 업무로 옮길 수 없어요.');
    }
    final handoff = _table(
      s,
      'teamHandoffs',
    )[textOf(previous, 'activeHandoffId')];
    if (handoff != null &&
        const {'pending', 'partial'}.contains(textOf(handoff, 'status'))) {
      throw const AppFailure('인계 확인 중인 포장은 수정할 수 없어요. 인계 확인을 먼저 끝내 주세요.');
    }
  }
  final label = _textArg(args, 'packageLabel');
  final finalAssigneeId = _textArg(
    args,
    'finalAssigneeId',
    required: false,
  ).ifEmpty(() => textOf(job, 'finalAssigneeId'));
  if (finalAssigneeId.isNotEmpty) {
    _ensureTeamMemberAccount(team, finalAssigneeId);
  }
  final status = finalAssigneeId == actor ? 'delivery_ready' : 'picked';
  _putTeamRecord(s, 'teamPackages', id, {
    ...?previous,
    'teamId': textOf(job, 'teamId'),
    'jobId': jobId,
    'requestId': textOf(job, 'requestId'),
    'packageLabel': label,
    'quantity': _intArg(args, 'quantity', min: 1),
    'unit': _textArg(args, 'unit', required: false).ifEmpty(() => '묶음'),
    'currentHolderId': actor,
    'pickupAssigneeId': actualPickupAssigneeId,
    'finalAssigneeId': finalAssigneeId,
    'retailerId': textOf(job, 'retailerId'),
    'retailerName': textOf(job, 'retailerName'),
    'wholesalerName': textOf(job, 'wholesalerName'),
    'activeHandoffId': '',
    'status': status,
    'note': _textArg(args, 'note', required: false),
    'createdAt': previous?['createdAt'] ?? _now(),
    'updatedAt': _now(),
    'version': numberOf(previous ?? const <String, Object?>{}, 'version') + 1,
    'readers': teamMemberIdsOf(team),
  });
  _recomputeJobStatus(s, jobId);
  return id;
}

String _requestPackageHandoff(MutableWorkspace s, String actor, Data args) {
  final teamId = _textArg(args, 'teamId');
  final team = _requireTeam(s, teamId, actor);
  final toId = _textArg(args, 'toId');
  _ensureTeamMemberAccount(team, toId);
  final packageIds = _uniqueStrings(stringsOf(args, 'packageIds'));
  if (packageIds.isEmpty) {
    throw const AppFailure('인계할 포장을 한 개 이상 선택해 주세요.');
  }
  String wholesalerName = '';
  for (final packageId in packageIds) {
    final package = _requireFrom(s, 'teamPackages', packageId);
    if (textOf(package, 'teamId') != teamId ||
        textOf(package, 'currentHolderId') != actor) {
      throw const AppFailure('현재 내가 보관 중인 포장만 인계 요청할 수 있어요.');
    }
    if ({'delivered', 'received'}.contains(textOf(package, 'status'))) {
      throw const AppFailure('이미 전달한 포장은 다시 인계 요청할 수 없어요.');
    }
    wholesalerName = wholesalerName.isEmpty
        ? textOf(package, 'wholesalerName')
        : wholesalerName;
    if (wholesalerName != textOf(package, 'wholesalerName')) {
      throw const AppFailure('같은 도매처에서 실제 받은 포장만 한 번에 인계 요청할 수 있어요.');
    }
    final activeHandoffId = textOf(package, 'activeHandoffId');
    if (activeHandoffId.isNotEmpty) {
      final activeHandoff = _table(s, 'teamHandoffs')[activeHandoffId];
      if (activeHandoff != null &&
          {'pending', 'partial'}.contains(textOf(activeHandoff, 'status'))) {
        throw const AppFailure('이미 확인 대기 중인 인계 요청이 있어요. 오래된 카드인지 먼저 확인해 주세요.');
      }
    }
  }
  final id = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-handoff:${newId()}');
  if (_table(s, 'teamHandoffs').containsKey(id)) {
    throw const AppFailure('이미 사용 중인 인계 식별자예요. 기존 인계 기록을 확인해 주세요.');
  }
  final handoff = {
    'id': id,
    'teamId': teamId,
    'fromId': actor,
    'toId': toId,
    'wholesalerName': wholesalerName,
    'packageIds': packageIds,
    'pendingPackageIds': packageIds,
    'acceptedPackageIds': const <String>[],
    'status': 'pending',
    'note': _textArg(args, 'note', required: false),
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
    'readers': teamMemberIdsOf(team),
  };
  _putTeamRecord(s, 'teamHandoffs', id, handoff);
  for (final packageId in packageIds) {
    final package = _requireFrom(s, 'teamPackages', packageId);
    _putTeamRecord(s, 'teamPackages', packageId, {
      ...package,
      'activeHandoffId': id,
      'status': 'handoff_requested',
      'updatedAt': _now(),
      'version': numberOf(package, 'version') + 1,
    });
    _recomputeJobStatus(s, textOf(package, 'jobId'));
  }
  _logHandoffRequestCard(s, actor: actor, team: team, handoff: handoff);
  return id;
}

String _confirmPackageHandoff(MutableWorkspace s, String actor, Data args) {
  final id = _textArg(args, 'id');
  final handoff = _requireFrom(s, 'teamHandoffs', id);
  _requireVersion(handoff, args);
  final team = _requireTeam(s, textOf(handoff, 'teamId'), actor);
  if (textOf(handoff, 'toId') != actor ||
      !{'pending', 'partial'}.contains(textOf(handoff, 'status'))) {
    throw const AppFailure('받는 팀원만 실제 인계 수령을 확인할 수 있어요.');
  }
  final receivedIds = _uniqueStrings(stringsOf(args, 'packageIds'));
  if (receivedIds.isEmpty) {
    throw const AppFailure('실제로 받은 포장을 한 개 이상 선택해 주세요.');
  }
  final versions = _requiredPackageVersions(args, receivedIds);
  final allowed = teamPackageIdsOf(handoff).toSet();
  if (!allowed.containsAll(receivedIds)) {
    throw const AppFailure('해당 인계 요청의 포장만 확인할 수 있어요.');
  }
  final accepted = <String>{...teamAcceptedPackageIdsOf(handoff)};
  final pending = <String>{...teamPendingPackageIdsOf(handoff)};
  for (final packageId in receivedIds) {
    final package = _requireFrom(s, 'teamPackages', packageId);
    _checkVersion(package, versions[packageId]);
    if (textOf(package, 'teamId') != textOf(team, 'id')) {
      throw const AppFailure('같은 팀의 포장만 확인할 수 있어요.');
    }
    if (textOf(package, 'activeHandoffId') != id ||
        textOf(package, 'currentHolderId') != textOf(handoff, 'fromId')) {
      throw const AppFailure('이미 다른 인계로 바뀌었어요. 최신 인계 상태를 다시 확인해 주세요.');
    }
    accepted.add(packageId);
    pending.remove(packageId);
    final nextStatus = textOf(package, 'finalAssigneeId') == actor
        ? 'delivery_ready'
        : 'held';
    _putTeamRecord(s, 'teamPackages', packageId, {
      ...package,
      'currentHolderId': actor,
      'activeHandoffId': '',
      'status': nextStatus,
      'updatedAt': _now(),
      'version': numberOf(package, 'version') + 1,
    });
    _recomputeJobStatus(s, textOf(package, 'jobId'));
  }
  final status = pending.isEmpty ? 'confirmed' : 'partial';
  final updatedHandoff = {
    ...handoff,
    'status': status,
    'acceptedPackageIds': accepted.toList()..sort(),
    'pendingPackageIds': pending.toList()..sort(),
    'confirmedBy': actor,
    'confirmedAt': _now(),
    'updatedAt': _now(),
    'version': numberOf(handoff, 'version') + 1,
    'note': _textArg(
      args,
      'note',
      required: false,
    ).ifEmpty(() => textOf(handoff, 'note')),
    'readers': teamMemberIdsOf(team),
  };
  _putTeamRecord(s, 'teamHandoffs', id, updatedHandoff);
  _logHandoffResultCard(s, actor: actor, team: team, handoff: updatedHandoff);
  return id;
}

String _recordPackageDelivery(MutableWorkspace s, String actor, Data args) {
  final packageIds = _uniqueStrings(stringsOf(args, 'packageIds'));
  if (packageIds.isEmpty) {
    throw const AppFailure('전달한 포장을 한 개 이상 선택해 주세요.');
  }
  final versions = _requiredPackageVersions(args, packageIds);
  for (final packageId in packageIds) {
    final package = _requireFrom(s, 'teamPackages', packageId);
    _checkVersion(package, versions[packageId]);
    final team = _requireTeam(s, textOf(package, 'teamId'), actor);
    _ensureTeamMemberAccount(team, actor);
    if (textOf(package, 'currentHolderId') != actor ||
        textOf(package, 'finalAssigneeId') != actor) {
      throw const AppFailure('실제로 보관하고 고객에게 전달할 권한이 있는 포장만 처리할 수 있어요.');
    }
    if (!{
      'delivery_ready',
      'held',
      'picked',
    }.contains(textOf(package, 'status'))) {
      throw const AppFailure('아직 전달 준비가 되지 않은 포장이 있어요.');
    }
    final updatedPackage = {
      ...package,
      'status': 'delivered',
      'deliveredAt': _now(),
      'deliveredBy': actor,
      'recipientLabel': _textArg(
        args,
        'recipientLabel',
        required: false,
      ).ifEmpty(() => textOf(package, 'retailerName')),
      'deliveryNote': _textArg(args, 'note', required: false),
      'updatedAt': _now(),
      'version': numberOf(package, 'version') + 1,
    };
    _putTeamRecord(s, 'teamPackages', packageId, updatedPackage);
    _recomputeJobStatus(s, textOf(package, 'jobId'));
    _logPackageDeliveredCard(
      s,
      actor: actor,
      team: team,
      package: updatedPackage,
    );
  }
  return packageIds.first;
}

String _recordPackageReceipt(MutableWorkspace s, String actor, Data args) {
  final packageIds = _uniqueStrings(stringsOf(args, 'packageIds'));
  if (packageIds.isEmpty) {
    throw const AppFailure('수령 확인한 포장을 한 개 이상 선택해 주세요.');
  }
  final versions = _requiredPackageVersions(args, packageIds);
  String? teamId;
  Data? retailer;
  final touchedJobs = <String>{};
  for (final packageId in packageIds) {
    final package = _requireFrom(s, 'teamPackages', packageId);
    _checkVersion(package, versions[packageId]);
    teamId ??= textOf(package, 'teamId');
    if (textOf(package, 'teamId') != teamId) {
      throw const AppFailure('같은 팀에서 전달한 포장만 한 번에 수령 확인할 수 있어요.');
    }
    retailer ??= _requireAccount(s, actor);
    if (textOf(retailer, 'role') != 'retailer' ||
        !flagOf(retailer, 'complete')) {
      throw const AppFailure('소매업자 본인만 실제 수령 확인을 남길 수 있어요.');
    }
    if (textOf(package, 'retailerId') != actor ||
        textOf(package, 'status') != 'delivered') {
      throw const AppFailure('내가 전달받은 포장만 실제 수령 확인할 수 있어요.');
    }
    _putTeamRecord(s, 'teamPackages', packageId, {
      ...package,
      'status': 'received',
      'receivedAt': _now(),
      'receivedBy': actor,
      'receiptNote': _textArg(args, 'note', required: false),
      'updatedAt': _now(),
      'version': numberOf(package, 'version') + 1,
    });
    touchedJobs.add(textOf(package, 'jobId'));
  }
  for (final jobId in touchedJobs) {
    final job = _requireFrom(s, 'teamJobs', jobId);
    final remaining = _jobPackages(s, jobId)
        .where((row) => textOf(row, 'status') == 'delivered')
        .map((row) => textOf(row, 'id'))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    _upsertReceiptIssue(
      s,
      actor,
      job,
      remaining,
      _textArg(args, 'note', required: false),
    );
    _recomputeJobStatus(s, jobId);
  }
  final team = _requireFrom(s, 'teams', teamId!);
  final receiptId = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'team-receipt:${newId()}');
  _putTeamRecord(s, 'teamReceipts', receiptId, {
    'teamId': teamId,
    'packageIds': packageIds,
    'confirmedBy': actor,
    'note': _textArg(args, 'note', required: false),
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
    'readers': _uniqueStrings([...teamMemberIdsOf(team), actor]),
  });
  return receiptId;
}

String _recoverPackageCustody(MutableWorkspace s, String actor, Data args) {
  final packageId = _textArg(args, 'packageId');
  final package = _requireFrom(s, 'teamPackages', packageId);
  final team = _requireTeam(s, textOf(package, 'teamId'), actor);
  _requireTeamAdmin(team, actor);
  _requireVersion(package, args);
  if (!flagOf(package, 'requiresReconciliation') ||
      textOf(package, 'reconciliationReason') != 'account_deleted') {
    throw const AppFailure('탈퇴 계정 인수 정리가 필요한 포장만 예외 인계로 회수할 수 있어요.');
  }
  if ({'delivered', 'received'}.contains(textOf(package, 'status'))) {
    throw const AppFailure('고객 전달이나 수령 확인이 끝난 포장은 예외 인계로 회수할 수 없어요.');
  }
  final storedHolderId = textOf(package, 'currentHolderId');
  final previousHolderId = _textArg(args, 'previousHolderId', required: false);
  if (storedHolderId.isEmpty) {
    throw const AppFailure('이전 보관자 정보를 다시 확인해 주세요.');
  }
  if (previousHolderId.isNotEmpty && previousHolderId != storedHolderId) {
    throw const AppFailure('최신 보관자 정보가 달라졌어요. 최신 화면에서 다시 시도해 주세요.');
  }
  if (!_accountInactiveOrDeleted(s, storedHolderId)) {
    throw const AppFailure('비활성화되었거나 탈퇴한 이전 보관자에게서만 예외 인계를 회수할 수 있어요.');
  }
  final nextHolderId = _textArg(args, 'nextHolderId');
  _ensureTeamMemberAccount(team, nextHolderId);
  if (_accountInactiveOrDeleted(s, nextHolderId)) {
    throw const AppFailure('활동 중인 팀원에게만 회수 포장을 다시 맡길 수 있어요.');
  }
  final note = _textArg(args, 'note');
  final nextStatus = textOf(package, 'finalAssigneeId') == nextHolderId
      ? 'delivery_ready'
      : 'held';
  _putTeamRecord(s, 'teamPackages', packageId, {
    ...package,
    'currentHolderId': nextHolderId,
    'activeHandoffId': '',
    'status': nextStatus,
    'requiresReconciliation': false,
    'reconciliationResolvedAt': _now(),
    'reconciliationResolvedBy': actor,
    'recoveredAt': _now(),
    'recoveredBy': actor,
    'recoveredFromId': storedHolderId,
    'recoveryNote': note,
    'updatedAt': _now(),
    'version': numberOf(package, 'version') + 1,
  });
  _recomputeJobStatus(s, textOf(package, 'jobId'));
  return packageId;
}

extension on String {
  String ifEmpty(String Function() orElse) => trim().isEmpty ? orElse() : this;
}
