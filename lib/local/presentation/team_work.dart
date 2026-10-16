import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import '../domain/pickup_progress.dart';
import '../domain/team_models.dart';
import 'common.dart';

class UncleTeamConnections extends StatefulWidget {
  const UncleTeamConnections({super.key});

  @override
  State<UncleTeamConnections> createState() => _UncleTeamConnectionsState();
}

class _UncleTeamConnectionsState extends State<UncleTeamConnections>
    with _WorkflowDraftOwner<UncleTeamConnections> {
  final _search = TextEditingController();
  final _teamNameController = TextEditingController();
  final _teamDescription = TextEditingController();
  final _inviteNote = TextEditingController();
  final _membershipNote = TextEditingController();

  bool _restored = false;
  bool _searching = false;
  int _tabIndex = 0;
  String _selectedInviteeId = '';
  String _selectedMembershipTeamId = '';
  List<Account> _results = const [];

  late _WorkflowDraft _teamDraft;
  late _WorkflowDraft _inviteDraft;
  late _WorkflowDraft _membershipDraft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    final workspace = AppScope.of(context).workspace;
    _teamDraft = trackDraft(workspace, 'team:create');
    _inviteDraft = trackDraft(workspace, 'team:invite');
    _membershipDraft = trackDraft(workspace, 'team:membership');
    _teamDraft.restore((values) {
      _teamNameController.text = textOf(values, 'name');
      _teamDescription.text = textOf(values, 'description');
    });
    _inviteDraft.restore((values) {
      _selectedInviteeId = textOf(values, 'inviteeId');
      _inviteNote.text = textOf(values, 'note');
    });
    _membershipDraft.restore((values) {
      _selectedMembershipTeamId = textOf(values, 'teamId');
      _membershipNote.text = textOf(values, 'note');
    });
    _restored = true;
  }

  @override
  void dispose() {
    _search.dispose();
    _teamNameController.dispose();
    _teamDescription.dispose();
    _inviteNote.dispose();
    _membershipNote.dispose();
    super.dispose();
  }

  Future<void> _searchColleagues() async {
    final app = AppScope.of(context);
    setState(() => _searching = true);
    try {
      final found = await app.workspace.searchColleagues(
        query: _search.text.trim(),
        limit: 12,
      );
      if (!mounted) return;
      setState(() {
        _results = found.toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '동료를 찾지 못했어요', e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _connectColleague(String peerId) async {
    final workspace = AppScope.of(context).workspace;
    try {
      await trackDraft(
        workspace,
        'team:connect:$peerId',
      ).submit('wf.connectColleague', {'peerId': peerId});
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '동료 연결을 보내지 못했어요', e.toString());
    }
  }

  Future<void> _respondColleague(Record row, String status) async {
    final workspace = AppScope.of(context).workspace;
    try {
      await trackDraft(workspace, 'team:colleague:${row.id}').submit(
        'wf.respondColleagueConnection',
        {'id': row.id, 'status': status, 'version': row.version},
      );
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '동료 요청을 처리하지 못했어요', e.toString());
    }
  }

  Future<void> _createTeam() async {
    final values = {
      'name': _teamNameController.text.trim(),
      'description': _teamDescription.text.trim(),
    };
    if (values['name']!.isEmpty) {
      await confirm(context, '팀 이름이 필요해요', '팀 이름을 먼저 입력해 주세요.');
      return;
    }
    try {
      await _teamDraft.submit('wf.createTeam', values);
      if (!mounted) return;
      setState(() {
        _teamNameController.clear();
        _teamDescription.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '팀을 만들지 못했어요', e.toString());
    }
  }

  Future<void> _inviteTeammate(String teamId) async {
    final values = {
      'teamId': teamId,
      'inviteeId': _selectedInviteeId,
      'note': _inviteNote.text.trim(),
    };
    if (_selectedInviteeId.isEmpty) {
      await confirm(context, '초대할 동료를 골라 주세요', '팀 초대는 수락된 동료에게만 보낼 수 있어요.');
      return;
    }
    try {
      await _inviteDraft.submit('wf.inviteTeamMember', values);
      if (!mounted) return;
      setState(() {
        _selectedInviteeId = '';
        _inviteNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '팀 초대를 보내지 못했어요', e.toString());
    }
  }

  Future<void> _requestMembership() async {
    final values = {
      'teamId': _selectedMembershipTeamId,
      'note': _membershipNote.text.trim(),
    };
    if (_selectedMembershipTeamId.isEmpty) {
      await confirm(context, '참여 요청할 팀을 골라 주세요', '연결된 동료가 속한 팀만 요청할 수 있어요.');
      return;
    }
    try {
      await _membershipDraft.submit('wf.requestTeamMembership', values);
      if (!mounted) return;
      setState(() {
        _selectedMembershipTeamId = '';
        _membershipNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '참여 요청을 보내지 못했어요', e.toString());
    }
  }

  Future<void> _respondInvite(Record row, String status) async {
    final workspace = AppScope.of(context).workspace;
    try {
      await trackDraft(workspace, 'team:invite:${row.id}').submit(
        'wf.respondTeamInvite',
        {'id': row.id, 'status': status, 'version': row.version},
      );
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '팀 요청을 처리하지 못했어요', e.toString());
    }
  }

  Future<void> _leaveTeam(Record team) async {
    final approved = await confirm(
      context,
      '팀을 나갈까요?',
      '보관 중인 포장이나 미확인 인계, 남은 정산이 있으면 나갈 수 없어요.',
    );
    if (!approved) return;
    if (!mounted) return;
    final workspace = AppScope.of(context).workspace;
    try {
      await trackDraft(
        workspace,
        'team:leave:${team.id}',
      ).submit('wf.leaveTeam', {'teamId': team.id, 'version': team.version});
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '팀을 나가지 못했어요', e.toString());
    }
  }

  Future<void> _persistCreate() => _teamDraft.persist({
    'name': _teamNameController.text,
    'description': _teamDescription.text,
  });

  Future<void> _persistInvite() => _inviteDraft.persist({
    'inviteeId': _selectedInviteeId,
    'note': _inviteNote.text,
  });

  Future<void> _persistMembership() => _membershipDraft.persist({
    'teamId': _selectedMembershipTeamId,
    'note': _membershipNote.text,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    if (current?.role != AppRole.uncle) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyState(
            '사입 동료 연결은 삼촌 전용이에요',
            '소매업자는 담당 삼촌 연결과 요청 진행만 확인해요.',
            icon: 'person',
          ),
        ],
      );
    }

    final userId = current!.id;
    final colleagueRows = app.workspace.records('colleagueConnections');
    final inviteRows = app.workspace.records('teamInvites');
    final teamRows = app.workspace.records('teams');
    final activeTeam = _activeTeam(teamRows, userId);
    final accepted = <Record>[];
    final pending = <Record>[];
    for (final row in colleagueRows) {
      if (!teamReadersOf(row.data).contains(userId)) continue;
      if (row.s('status') == 'accepted') {
        accepted.add(row);
      } else if (row.s('status') == 'pending') {
        pending.add(row);
      }
    }
    final incomingInvites = <Record>[];
    final outgoingInvites = <Record>[];
    final incomingMembership = <Record>[];
    final outgoingMembership = <Record>[];
    for (final row in inviteRows) {
      final kind = row.s('kind', 'invite');
      final isIncoming = row.s('inviteeId') == userId;
      final isOutgoing = row.s('inviterId') == userId;
      if (kind == 'membership_request') {
        if (isIncoming && row.s('status') == 'pending') {
          incomingMembership.add(row);
        }
        if (isOutgoing) outgoingMembership.add(row);
      } else {
        if (isIncoming) incomingInvites.add(row);
        if (isOutgoing) outgoingInvites.add(row);
      }
    }
    final inviteCandidates = accepted
        .map((row) => app.workspace.profile(colleaguePeerId(row.data, userId)))
        .whereType<Account>()
        .where(
          (peer) =>
              activeTeam == null ||
              !teamMemberIdsOf(activeTeam.data).contains(peer.id),
        )
        .toList(growable: false);
    final visiblePeerTeams = _knownColleagueTeams(app, userId, accepted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdsTab(
          semanticLabel: '팀 연결 탭',
          items: [
            TdsTabItem(text: '동료 ${accepted.length}', selected: _tabIndex == 0),
            TdsTabItem(
              text:
                  '초대 ${incomingInvites.where((row) => row.s('status') == 'pending').length + incomingMembership.length}',
              selected: _tabIndex == 1,
            ),
            TdsTabItem(
              text: '내 팀 ${activeTeam == null ? 0 : 1}',
              selected: _tabIndex == 2,
            ),
          ],
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
        const TdsSpacing(12),
        ...switch (_tabIndex) {
          0 => _buildColleagueTab(
            context,
            accepted: accepted,
            pending: pending,
            activeTeam: activeTeam,
          ),
          1 => _buildInviteTab(
            context,
            incomingInvites: incomingInvites,
            outgoingInvites: outgoingInvites,
            incomingMembership: incomingMembership,
            outgoingMembership: outgoingMembership,
          ),
          _ => _buildTeamTab(
            context,
            activeTeam: activeTeam,
            inviteCandidates: inviteCandidates,
            colleagueTeams: visiblePeerTeams,
          ),
        },
      ],
    );
  }

  List<Widget> _buildColleagueTab(
    BuildContext context, {
    required List<Record> accepted,
    required List<Record> pending,
    required Record? activeTeam,
  }) {
    final app = AppScope.of(context);
    final userId = app.session.current!.id;
    return [
      FigmaSurface(
        children: [
          const Section('동료 검색'),
          AppSearchField(
            placeholder: '이름·닉네임·공개 코드로 찾기',
            onChanged: (value) => _search.text = value,
          ),
          ActionButton(
            _searching ? '찾는 중…' : '동료 찾기',
            weak: true,
            icon: 'search',
            onPressed: _searchColleagues,
            enabled: !_searching,
          ),
          if (_results.isEmpty)
            const Info('검색 결과에서 사입 동료를 바로 추가할 수 있어요. 팀 정보는 필요한 범위만 보여 줘요.')
          else
            for (final peer in _results)
              FigmaSurface(
                margin: 0,
                children: [
                  Item(
                    peer.displayName,
                    subtitle: _colleagueSearchSubtitle(app, peer),
                    leading: const FigmaIcon('person'),
                    trailing: StatusBadge(_colleagueActionLabel(app, peer.id)),
                  ),
                  if (_colleagueActionEnabled(app, peer.id))
                    ActionButton(
                      '동료 추가',
                      weak: true,
                      onPressed: () => _connectColleague(peer.id),
                    ),
                ],
              ),
        ],
      ),
      if (pending.isNotEmpty) ...[
        const Section('응답 대기'),
        for (final row in pending)
          _ConnectionPendingCard(
            row: row,
            incoming: row.s('toId') == userId,
            onAccept: () => _respondColleague(row, 'accepted'),
            onDecline: () => _respondColleague(row, 'declined'),
          ),
      ],
      if (accepted.isEmpty)
        const EmptyState.titleOnly('연결된 동료가 없어요', icon: 'person')
      else ...[
        const Section('연결된 동료'),
        for (final row in accepted)
          _AcceptedColleagueCard(
            row: row,
            teamLabel: _colleagueTeamLabel(
              app,
              colleaguePeerId(row.data, userId),
              activeTeam,
            ),
          ),
      ],
    ];
  }

  List<Widget> _buildInviteTab(
    BuildContext context, {
    required List<Record> incomingInvites,
    required List<Record> outgoingInvites,
    required List<Record> incomingMembership,
    required List<Record> outgoingMembership,
  }) {
    final app = AppScope.of(context);
    if (incomingInvites.isEmpty &&
        outgoingInvites.isEmpty &&
        incomingMembership.isEmpty &&
        outgoingMembership.isEmpty) {
      return const [
        EmptyState(
          '기다리는 팀 요청이 없어요',
          '동료 연결이 수락되면 팀 초대나 참여 요청을 여기서 바로 확인할 수 있어요.',
          icon: 'bell',
        ),
      ];
    }
    return [
      if (incomingInvites.isNotEmpty) ...[
        const Section('받은 팀 초대'),
        for (final row in incomingInvites)
          _InviteCard(
            row: row,
            title: _teamLabel(app.workspace.records('teams'), row.s('teamId')),
            subtitle:
                '초대한 동료 ${app.workspace.profile(row.s('inviterId'))?.displayName ?? '알 수 없음'}',
            onAccept: row.s('status') == 'pending'
                ? () => _respondInvite(row, 'accepted')
                : null,
            onDecline: row.s('status') == 'pending'
                ? () => _respondInvite(row, 'declined')
                : null,
          ),
      ],
      if (incomingMembership.isNotEmpty) ...[
        const Section('받은 팀 참여 요청'),
        for (final row in incomingMembership)
          _InviteCard(
            row: row,
            title: _teamLabel(app.workspace.records('teams'), row.s('teamId')),
            subtitle:
                '요청한 동료 ${app.workspace.profile(row.s('inviterId'))?.displayName ?? '알 수 없음'}',
            onAccept: row.s('status') == 'pending'
                ? () => _respondInvite(row, 'accepted')
                : null,
            onDecline: row.s('status') == 'pending'
                ? () => _respondInvite(row, 'declined')
                : null,
          ),
      ],
      if (outgoingInvites.isNotEmpty) ...[
        const Section('보낸 팀 초대'),
        for (final row in outgoingInvites)
          _InviteCard(
            row: row,
            title: _teamLabel(app.workspace.records('teams'), row.s('teamId')),
            subtitle:
                '응답 대기 ${app.workspace.profile(row.s('inviteeId'))?.displayName ?? '알 수 없음'}',
          ),
      ],
      if (outgoingMembership.isNotEmpty) ...[
        const Section('보낸 팀 참여 요청'),
        for (final row in outgoingMembership)
          _InviteCard(
            row: row,
            title: _teamLabel(app.workspace.records('teams'), row.s('teamId')),
            subtitle: '응답 대기 중인 참여 요청',
          ),
      ],
    ];
  }

  List<Widget> _buildTeamTab(
    BuildContext context, {
    required Record? activeTeam,
    required List<Account> inviteCandidates,
    required List<Record> colleagueTeams,
  }) {
    final app = AppScope.of(context);
    final userId = app.session.current!.id;
    if (activeTeam == null) {
      return [
        _WorkflowSurface(
          draft: _teamDraft,
          children: [
            const Section('팀 만들기'),
            Field(
              '팀 이름',
              controller: _teamNameController,
              onChanged: (_) => _persistCreate(),
            ),
            Field(
              '팀 소개',
              controller: _teamDescription,
              multiline: true,
              onChanged: (_) => _persistCreate(),
            ),
            ActionButton(
              _teamDraft.retrying ? '같은 팀 만들기 다시 시도' : '새 팀 만들기',
              onPressed: _createTeam,
            ),
          ],
        ),
        if (colleagueTeams.isEmpty)
          const Info(
            '지금은 보이는 팀이 없어요. 연결된 동료가 먼저 팀을 만들거나 초대하면 여기서 바로 참여 요청할 수 있어요.',
          )
        else
          _WorkflowSurface(
            draft: _membershipDraft,
            children: [
              const Section('동료 팀 참여 요청'),
              _OptionChoices(
                options: [
                  for (final team in colleagueTeams)
                    _Option(
                      team.id,
                      '${team.s('name')} · ${_displayName(app, team.s('ownerId'))}',
                    ),
                ],
                value: _selectedMembershipTeamId,
                onChanged: (next) {
                  setState(() => _selectedMembershipTeamId = next);
                  _persistMembership();
                },
              ),
              Field(
                '요청 메모',
                controller: _membershipNote,
                multiline: true,
                onChanged: (_) => _persistMembership(),
              ),
              ActionButton(
                _membershipDraft.retrying ? '같은 참여 요청 다시 보내기' : '팀 참여 요청 보내기',
                weak: true,
                onPressed: _requestMembership,
              ),
            ],
          ),
      ];
    }

    return [
      FigmaSurface(
        children: [
          const Section('내 팀'),
          Item(
            activeTeam.s('name'),
            subtitle: activeTeam.s('description').isEmpty
                ? '${teamMemberIdsOf(activeTeam.data).length}명 활동 중'
                : activeTeam.s('description'),
            leading: const FigmaIcon('person'),
            trailing: StatusBadge(teamRoleLabel(activeTeam.data, userId)),
          ),
          Inset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuantityRow('팀장', _displayName(app, activeTeam.s('ownerId'))),
                QuantityRow(
                  '팀원',
                  '${teamMemberIdsOf(activeTeam.data).length}명',
                ),
              ],
            ),
          ),
          for (final memberId in teamMemberIdsOf(activeTeam.data))
            Item(
              _displayName(app, memberId),
              subtitle: teamRoleLabel(activeTeam.data, memberId),
              leading: const FigmaIcon('person'),
            ),
          ActionButton(
            '팀 나가기',
            weak: true,
            danger: true,
            onPressed: () => _leaveTeam(activeTeam),
          ),
        ],
      ),
      if (isTeamAdmin(activeTeam.data, userId))
        _WorkflowSurface(
          draft: _inviteDraft,
          children: [
            const Section('동료 초대'),
            if (inviteCandidates.isEmpty)
              const Info('연결된 동료가 없거나 이미 모두 팀에 있어요.')
            else
              _OptionChoices(
                options: [
                  for (final peer in inviteCandidates)
                    _Option(
                      peer.id,
                      '${peer.displayName}${_activeTeamNameForPeer(app, peer.id).isEmpty ? '' : ' · ${_activeTeamNameForPeer(app, peer.id)}'}',
                    ),
                ],
                value: _selectedInviteeId,
                onChanged: (next) {
                  setState(() => _selectedInviteeId = next);
                  _persistInvite();
                },
              ),
            Field(
              '초대 메모',
              controller: _inviteNote,
              multiline: true,
              onChanged: (_) => _persistInvite(),
            ),
            ActionButton(
              _inviteDraft.retrying ? '같은 팀 초대 다시 보내기' : '팀 초대 보내기',
              onPressed: () => _inviteTeammate(activeTeam.id),
              enabled: inviteCandidates.isNotEmpty,
            ),
          ],
        ),
    ];
  }

  String _colleagueSearchSubtitle(AppServices app, Account peer) {
    final memberships = dataRowsOf(peer.data, 'teamMemberships');
    if (memberships.isEmpty) return '공개 팀 소속 없음';
    return memberships
        .map((row) => textOf(row, 'name'))
        .where((name) => name.isNotEmpty)
        .join(' · ');
  }

  String _colleagueActionLabel(AppServices app, String peerId) {
    final current = app.session.current!.id;
    for (final row in app.workspace.records('colleagueConnections')) {
      if ({row.s('fromId'), row.s('toId')}.contains(current) &&
          {row.s('fromId'), row.s('toId')}.contains(peerId)) {
        return colleagueConnectionLabel(row.data);
      }
    }
    return '연결 전';
  }

  bool _colleagueActionEnabled(AppServices app, String peerId) {
    final userId = app.session.current!.id;
    return !app.workspace
        .records('colleagueConnections')
        .any(
          (row) =>
              {row.s('fromId'), row.s('toId')}.contains(userId) &&
              {row.s('fromId'), row.s('toId')}.contains(peerId) &&
              {'pending', 'accepted'}.contains(row.s('status')),
        );
  }
}

class UncleTeamChats extends StatefulWidget {
  const UncleTeamChats({super.key});

  @override
  State<UncleTeamChats> createState() => _UncleTeamChatsState();
}

class _UncleTeamChatsState extends State<UncleTeamChats>
    with _WorkflowDraftOwner<UncleTeamChats> {
  final _teamBody = TextEditingController();
  final _peerBody = TextEditingController();

  bool _restored = false;
  int _tabIndex = 0;
  String _selectedTeamId = '';
  String _selectedPeerId = '';

  late _WorkflowDraft _teamDraft;
  late _WorkflowDraft _peerDraft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    final workspace = AppScope.of(context).workspace;
    _teamDraft = trackDraft(workspace, 'team:chat:group');
    _peerDraft = trackDraft(workspace, 'team:chat:peer');
    _teamDraft.restore((values) {
      _selectedTeamId = textOf(values, 'teamId');
      _teamBody.text = textOf(values, 'body');
    });
    _peerDraft.restore((values) {
      _selectedPeerId = textOf(values, 'peerId');
      _peerBody.text = textOf(values, 'body');
    });
    _restored = true;
  }

  @override
  void dispose() {
    _teamBody.dispose();
    _peerBody.dispose();
    super.dispose();
  }

  Future<void> _sendTeamMessage() async {
    final values = {'teamId': _selectedTeamId, 'body': _teamBody.text.trim()};
    if (_selectedTeamId.isEmpty || _teamBody.text.trim().isEmpty) {
      await confirm(context, '보낼 내용을 확인해 주세요', '팀 단체방과 메시지를 먼저 선택해 주세요.');
      return;
    }
    try {
      await _teamDraft.submit('wf.sendTeamMessage', values);
      if (!mounted) return;
      setState(() => _teamBody.clear());
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '팀 메시지를 보내지 못했어요', e.toString());
    }
  }

  Future<void> _sendPeerMessage() async {
    final values = {'peerId': _selectedPeerId, 'body': _peerBody.text.trim()};
    if (_selectedPeerId.isEmpty || _peerBody.text.trim().isEmpty) {
      await confirm(context, '보낼 내용을 확인해 주세요', '동료와 메시지를 먼저 선택해 주세요.');
      return;
    }
    try {
      await _peerDraft.submit('wf.sendColleagueMessage', values);
      if (!mounted) return;
      setState(() => _peerBody.clear());
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '동료 메시지를 보내지 못했어요', e.toString());
    }
  }

  Future<void> _markTeamRead(String teamId) async {
    try {
      await trackDraft(
        AppScope.of(context).workspace,
        'team:chat:read:$teamId',
      ).submit('wf.markTeamChatRead', {'teamId': teamId});
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '단체방 읽음 처리를 하지 못했어요', e.toString());
    }
  }

  Future<void> _markPeerRead(String peerId) async {
    try {
      await trackDraft(
        AppScope.of(context).workspace,
        'team:peer:read:$peerId',
      ).submit('wf.markColleagueChatRead', {'peerId': peerId});
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '동료 대화를 읽음 처리하지 못했어요', e.toString());
    }
  }

  Future<void> _persistTeam() =>
      _teamDraft.persist({'teamId': _selectedTeamId, 'body': _teamBody.text});

  Future<void> _persistPeer() =>
      _peerDraft.persist({'peerId': _selectedPeerId, 'body': _peerBody.text});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    if (current?.role != AppRole.uncle) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyState(
            '팀 대화는 삼촌 전용이에요',
            '소매업자 대화는 기존 요청 채팅에서 계속 이어져요.',
            icon: 'chat',
          ),
        ],
      );
    }
    final userId = current!.id;
    final teams = app.workspace
        .records('teams')
        .where(
          (row) =>
              row.s('status', 'active') == 'active' &&
              teamMemberIdsOf(row.data).contains(userId),
        )
        .toList(growable: false);
    final peers = app.workspace
        .records('colleagueConnections')
        .where(
          (row) =>
              row.s('status') == 'accepted' &&
              teamReadersOf(row.data).contains(userId),
        )
        .map((row) => app.workspace.profile(colleaguePeerId(row.data, userId)))
        .whereType<Account>()
        .toList(growable: false);
    final chats = app.workspace
        .records('teamChats')
        .where((row) => teamReadersOf(row.data).contains(userId))
        .toList(growable: false);

    if (!_teamDraft.locked && _selectedTeamId.isEmpty && teams.isNotEmpty) {
      _selectedTeamId = teams.first.id;
    }
    if (!_peerDraft.locked && _selectedPeerId.isEmpty && peers.isNotEmpty) {
      _selectedPeerId = peers.first.id;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdsTab(
          semanticLabel: '팀 대화 탭',
          items: [
            TdsTabItem(text: '팀 단체방', selected: _tabIndex == 0),
            TdsTabItem(text: '동료 1:1', selected: _tabIndex == 1),
          ],
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
        const TdsSpacing(12),
        if (_tabIndex == 0) ...[
          _WorkflowSurface(
            draft: _teamDraft,
            children: [
              const Section('팀 단체방 보내기'),
              if (teams.isEmpty)
                const Info('먼저 팀에 참여해야 단체방을 사용할 수 있어요.')
              else ...[
                _OptionChoices(
                  options: [
                    for (final row in teams) _Option(row.id, row.s('name')),
                  ],
                  value: _selectedTeamId,
                  onChanged: (next) {
                    setState(() => _selectedTeamId = next);
                    _persistTeam();
                  },
                ),
                Field(
                  '메시지',
                  controller: _teamBody,
                  multiline: true,
                  onChanged: (_) => _persistTeam(),
                ),
                ActionButton(
                  _teamDraft.retrying ? '같은 팀 메시지 다시 보내기' : '팀 단체방 보내기',
                  onPressed: _sendTeamMessage,
                ),
              ],
            ],
          ),
          ..._teamChatSections(app, chats, userId),
        ] else ...[
          _WorkflowSurface(
            draft: _peerDraft,
            children: [
              const Section('동료 1:1 보내기'),
              if (peers.isEmpty)
                const Info('수락된 동료가 있어야 1:1 대화를 시작할 수 있어요.')
              else ...[
                _OptionChoices(
                  options: [
                    for (final peer in peers)
                      _Option(
                        peer.id,
                        '${peer.displayName} · ${_colleagueTeamLabel(app, peer.id, _activeTeam(teams, userId))}',
                      ),
                  ],
                  value: _selectedPeerId,
                  onChanged: (next) {
                    setState(() => _selectedPeerId = next);
                    _persistPeer();
                  },
                ),
                Field(
                  '메시지',
                  controller: _peerBody,
                  multiline: true,
                  onChanged: (_) => _persistPeer(),
                ),
                ActionButton(
                  _peerDraft.retrying ? '같은 동료 메시지 다시 보내기' : '동료 1:1 보내기',
                  onPressed: _sendPeerMessage,
                ),
              ],
            ],
          ),
          ..._peerChatSections(app, chats, userId),
        ],
      ],
    );
  }

  List<Widget> _teamChatSections(
    AppServices app,
    List<Record> chats,
    String userId,
  ) {
    final latest = <String, Record>{};
    for (final row in chats.where((row) => row.s('chatType') == 'team')) {
      final key = row.s('teamId');
      final current = latest[key];
      if (current == null ||
          current.s('createdAt').compareTo(row.s('createdAt')) < 0) {
        latest[key] = row;
      }
    }
    final sections = <Widget>[];
    if (latest.isNotEmpty) {
      sections.add(const Section('최근 단체방'));
      for (final entry in latest.entries) {
        final row = entry.value;
        final unread =
            row.s('senderId') != userId &&
            !teamReadByOf(row.data).contains(userId);
        sections.add(
          FigmaSurface(
            children: [
              Item(
                _teamLabel(app.workspace.records('teams'), entry.key),
                subtitle: teamChatPreview(row.data),
                leading: const FigmaIcon('chat'),
                trailing: unread
                    ? const StatusBadge('안 읽음')
                    : const StatusBadge('읽음'),
              ),
              if (unread)
                ActionButton(
                  '읽음 처리',
                  weak: true,
                  onPressed: () => _markTeamRead(entry.key),
                ),
            ],
          ),
        );
      }
    }
    final currentTeam = _selectedTeamId;
    if (currentTeam.isEmpty) return sections;
    final thread =
        chats
            .where(
              (row) =>
                  row.s('chatType') == 'team' && row.s('teamId') == currentTeam,
            )
            .toList(growable: false)
          ..sort((a, b) => b.s('createdAt').compareTo(a.s('createdAt')));
    sections.add(const Section('단체방 기록'));
    if (thread.isEmpty) {
      sections.add(
        const EmptyState.titleOnly('아직 팀 단체방 메시지가 없어요', icon: 'chat'),
      );
      return sections;
    }
    for (final row in thread.take(12)) {
      sections.add(
        FigmaSurface(
          children: [
            Item(
              row.s('senderId').isEmpty
                  ? '팀 업무 안내'
                  : _displayName(app, row.s('senderId')),
              subtitle: row
                  .s('createdAt')
                  .replaceFirst('T', ' ')
                  .replaceFirst('.000Z', 'Z'),
              leading: const FigmaIcon('person'),
              trailing:
                  row.s('senderId') != userId &&
                      !teamReadByOf(row.data).contains(userId)
                  ? const StatusBadge('안 읽음')
                  : null,
            ),
            Inset(child: TdsText(row.s('body'), typography: TdsTypography.t5)),
            if (row.s('sourceId').isNotEmpty)
              ActionButton(
                '연결된 업무 열기',
                weak: true,
                onPressed: () => _openTeamSource(context, row),
              ),
          ],
        ),
      );
    }
    return sections;
  }

  List<Widget> _peerChatSections(
    AppServices app,
    List<Record> chats,
    String userId,
  ) {
    final latest = <String, Record>{};
    for (final row in chats.where((row) => row.s('chatType') == 'colleague')) {
      final peerId = row.s('senderId') == userId
          ? row.s('peerId')
          : row.s('senderId');
      final current = latest[peerId];
      if (current == null ||
          current.s('createdAt').compareTo(row.s('createdAt')) < 0) {
        latest[peerId] = row;
      }
    }
    final sections = <Widget>[];
    if (latest.isNotEmpty) {
      sections.add(const Section('최근 동료 대화'));
      for (final entry in latest.entries) {
        final row = entry.value;
        final unread =
            row.s('senderId') != userId &&
            !teamReadByOf(row.data).contains(userId);
        sections.add(
          FigmaSurface(
            children: [
              Item(
                _displayName(app, entry.key),
                subtitle: teamChatPreview(row.data),
                leading: const FigmaIcon('chat'),
                trailing: unread
                    ? const StatusBadge('안 읽음')
                    : const StatusBadge('읽음'),
              ),
              if (unread)
                ActionButton(
                  '읽음 처리',
                  weak: true,
                  onPressed: () => _markPeerRead(entry.key),
                ),
            ],
          ),
        );
      }
    }
    final currentPeer = _selectedPeerId;
    if (currentPeer.isEmpty) return sections;
    final thread =
        chats
            .where(
              (row) =>
                  row.s('chatType') == 'colleague' &&
                  teamReadersOf(row.data).contains(currentPeer),
            )
            .toList(growable: false)
          ..sort((a, b) => b.s('createdAt').compareTo(a.s('createdAt')));
    sections.add(const Section('동료 1:1 기록'));
    if (thread.isEmpty) {
      sections.add(
        const EmptyState.titleOnly('아직 동료 1:1 메시지가 없어요', icon: 'chat'),
      );
      return sections;
    }
    for (final row in thread.take(12)) {
      sections.add(
        FigmaSurface(
          children: [
            Item(
              _displayName(app, row.s('senderId')),
              subtitle: row
                  .s('createdAt')
                  .replaceFirst('T', ' ')
                  .replaceFirst('.000Z', 'Z'),
              leading: const FigmaIcon('person'),
              trailing:
                  row.s('senderId') != userId &&
                      !teamReadByOf(row.data).contains(userId)
                  ? const StatusBadge('안 읽음')
                  : null,
            ),
            Inset(child: TdsText(row.s('body'), typography: TdsTypography.t5)),
          ],
        ),
      );
    }
    return sections;
  }
}

class TeamWorkPage extends StatelessWidget {
  const TeamWorkPage({this.sourceType, this.sourceId, super.key});

  final String? sourceType;
  final String? sourceId;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: '팀 업무',
      children: [
        _TeamWorkDashboard(sourceType: sourceType, sourceId: sourceId),
      ],
    );
  }
}

class PickupRequestWorkPage extends StatelessWidget {
  const PickupRequestWorkPage({
    required this.requestId,
    this.sourceType,
    this.sourceId,
    super.key,
  });

  final String requestId;
  final String? sourceType;
  final String? sourceId;

  @override
  Widget build(BuildContext context) {
    final request = AppScope.of(context).workspace.request(requestId);
    return PageFrame(
      title: '요청별 팀 업무',
      navigationSubtitle: request == null
          ? '팀 처리 화면'
          : requestTitle(request.data),
      children: [
        _TeamWorkDashboard(
          requestIdFilter: requestId,
          sourceType: sourceType,
          sourceId: sourceId,
        ),
      ],
    );
  }
}

class _TeamWorkDashboard extends StatefulWidget {
  const _TeamWorkDashboard({
    this.requestIdFilter,
    this.sourceType,
    this.sourceId,
  });

  final String? requestIdFilter;
  final String? sourceType;
  final String? sourceId;

  @override
  State<_TeamWorkDashboard> createState() => _TeamWorkDashboardState();
}

class _TeamWorkDashboardState extends State<_TeamWorkDashboard>
    with _WorkflowDraftOwner<_TeamWorkDashboard> {
  final _roundLabel = TextEditingController();
  final _roundDate = TextEditingController();
  final _roundReceiver = TextEditingController();
  final _areaName = TextEditingController();
  final _areaKeywords = TextEditingController();
  final _primaryCapacity = TextEditingController();
  final _backupCapacity = TextEditingController();
  final _primaryCutoff = TextEditingController();
  final _backupCutoff = TextEditingController();
  final _jobNote = TextEditingController();
  final _assignReason = TextEditingController();
  final _scopeExpected = TextEditingController();
  final _scopeNote = TextEditingController();
  final _packageLabel = TextEditingController();
  final _packageQuantity = TextEditingController(text: '1');
  final _packageUnit = TextEditingController(text: '묶음');
  final _handoffNote = TextEditingController();
  final _confirmNote = TextEditingController();
  final _deliveryRecipient = TextEditingController();
  final _deliveryNote = TextEditingController();
  final _recoveryNote = TextEditingController();

  bool _restored = false;
  String _selectedAreaId = '';
  String _selectedPrimaryId = '';
  String _selectedBackupId = '';
  bool _primaryWorking = true;
  bool _backupWorking = false;
  String _selectedRequestId = '';
  int _selectedWholesalerIndex = 0;
  String _selectedJobRoundId = '';
  String _selectedJobAreaId = '';
  String _selectedAssignJobId = '';
  String _selectedAssignPickupId = '';
  String _selectedAssignFinalId = '';
  String _selectedAssignRoundId = '';
  String _selectedAssignAreaId = '';
  String _selectedAutoRoundId = '';
  String _selectedScopeJobId = '';
  bool _scopeConfirmed = false;
  bool _hasBackorder = false;
  String _selectedCustodyJobId = '';
  String _selectedCustodyFinalId = '';
  String _selectedHandoffToId = '';
  String _selectedHandoffWholesaler = '';
  final Set<String> _selectedHandoffPackages = <String>{};
  String _selectedConfirmHandoffId = '';
  final Set<String> _selectedConfirmedPackages = <String>{};
  final Set<String> _selectedDeliveryPackages = <String>{};
  String _selectedRecoveryPackageId = '';
  String _selectedRecoveryHolderId = '';

  late _WorkflowDraft _roundDraft;
  late _WorkflowDraft _areaDraft;
  late _WorkflowDraft _jobDraft;
  late _WorkflowDraft _assignDraft;
  late _WorkflowDraft _autoDraft;
  late _WorkflowDraft _scopeDraft;
  late _WorkflowDraft _custodyDraft;
  late _WorkflowDraft _handoffDraft;
  late _WorkflowDraft _confirmDraft;
  late _WorkflowDraft _deliveryDraft;
  late _WorkflowDraft _recoveryDraft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    final workspace = AppScope.of(context).workspace;
    final suffix = widget.requestIdFilter == null
        ? 'all'
        : widget.requestIdFilter!;
    _roundDraft = trackDraft(workspace, 'team:round:$suffix');
    _areaDraft = trackDraft(workspace, 'team:area:$suffix');
    _jobDraft = trackDraft(workspace, 'team:job:$suffix');
    _assignDraft = trackDraft(workspace, 'team:assign:$suffix');
    _autoDraft = trackDraft(workspace, 'team:auto:$suffix');
    _scopeDraft = trackDraft(workspace, 'team:scope:$suffix');
    _custodyDraft = trackDraft(workspace, 'team:custody:$suffix');
    _handoffDraft = trackDraft(workspace, 'team:handoff:$suffix');
    _confirmDraft = trackDraft(workspace, 'team:handoff-confirm:$suffix');
    _deliveryDraft = trackDraft(workspace, 'team:delivery:$suffix');
    _recoveryDraft = trackDraft(workspace, 'team:recovery:$suffix');
    _roundDraft.restore((values) {
      _roundLabel.text = textOf(values, 'label');
      _roundDate.text = textOf(values, 'operatingDate');
      _roundReceiver.text = textOf(values, 'receiverLabel');
    });
    _areaDraft.restore((values) {
      _selectedAreaId = textOf(values, 'id');
      _areaName.text = textOf(values, 'name');
      _selectedPrimaryId = textOf(values, 'primaryMemberId');
      _selectedBackupId = textOf(values, 'backupMemberId');
      _primaryWorking = values['primaryWorking'] != false;
      _backupWorking = values['backupWorking'] == true;
      _primaryCapacity.text = textOf(values, 'primaryCapacity');
      _backupCapacity.text = textOf(values, 'backupCapacity');
      _primaryCutoff.text = textOf(values, 'primaryCutoffAt');
      _backupCutoff.text = textOf(values, 'backupCutoffAt');
      _areaKeywords.text = textOf(values, 'matchKeywordsText');
    });
    _jobDraft.restore((values) {
      _selectedRequestId = textOf(values, 'requestId');
      _selectedWholesalerIndex =
          nullableNumberOf(values, 'wholesalerIndex') ?? 0;
      _selectedJobRoundId = textOf(values, 'roundId');
      _selectedJobAreaId = textOf(values, 'areaId');
      _jobNote.text = textOf(values, 'note');
    });
    _assignDraft.restore((values) {
      _selectedAssignJobId = textOf(values, 'id');
      _selectedAssignPickupId = textOf(values, 'pickupAssigneeId');
      _selectedAssignFinalId = textOf(values, 'finalAssigneeId');
      _selectedAssignRoundId = textOf(values, 'roundId');
      _selectedAssignAreaId = textOf(values, 'areaId');
      _assignReason.text = textOf(values, 'assignmentReason');
    });
    _autoDraft.restore(
      (values) => _selectedAutoRoundId = textOf(values, 'roundId'),
    );
    _scopeDraft.restore((values) {
      _selectedScopeJobId = textOf(values, 'id');
      _scopeExpected.text = textOf(values, 'expectedPackageCount');
      _scopeConfirmed = values['scopeConfirmed'] == true;
      _hasBackorder = values['hasBackorder'] == true;
      _scopeNote.text = textOf(values, 'note');
    });
    _custodyDraft.restore((values) {
      _selectedCustodyJobId = textOf(values, 'jobId');
      _selectedCustodyFinalId = textOf(values, 'finalAssigneeId');
      _packageLabel.text = textOf(values, 'packageLabel');
      _packageQuantity.text = textOf(values, 'quantity', '1');
      _packageUnit.text = textOf(values, 'unit', '묶음');
    });
    _handoffDraft.restore((values) {
      _selectedHandoffToId = textOf(values, 'toId');
      _selectedHandoffWholesaler = textOf(values, 'wholesalerName');
      _selectedHandoffPackages
        ..clear()
        ..addAll(stringsOf(values, 'packageIds'));
      _handoffNote.text = textOf(values, 'note');
    });
    _confirmDraft.restore((values) {
      _selectedConfirmHandoffId = textOf(values, 'id');
      _selectedConfirmedPackages
        ..clear()
        ..addAll(stringsOf(values, 'packageIds'));
      _confirmNote.text = textOf(values, 'note');
    });
    _deliveryDraft.restore((values) {
      _selectedDeliveryPackages
        ..clear()
        ..addAll(stringsOf(values, 'packageIds'));
      _deliveryRecipient.text = textOf(values, 'recipientLabel');
      _deliveryNote.text = textOf(values, 'note');
    });
    _recoveryDraft.restore((values) {
      _selectedRecoveryPackageId = textOf(values, 'packageId');
      _selectedRecoveryHolderId = textOf(values, 'nextHolderId');
      _recoveryNote.text = textOf(values, 'note');
    });
    final sourceId = widget.sourceId;
    if (sourceId != null) {
      if (widget.sourceType == 'pickupJob') {
        final job = _recordById(workspace.records('teamJobs'), sourceId);
        if (job != null) {
          if (!_assignDraft.hasInput) {
            _selectedAssignJobId = job.id;
            _selectedAssignPickupId = job.s('pickupAssigneeId');
            _selectedAssignFinalId = job.s('finalAssigneeId');
            _selectedAssignRoundId = job.s('roundId');
            _selectedAssignAreaId = job.s('areaId');
            _assignReason.text = job.s('assignmentReason');
          }
          if (!_scopeDraft.hasInput) {
            _selectedScopeJobId = job.id;
            _scopeExpected.text = '${job.n('expectedPackageCount')}';
            _scopeConfirmed = job.b('scopeConfirmed');
            _hasBackorder = job.b('hasBackorder');
          }
          if (!_custodyDraft.hasInput) {
            _selectedCustodyJobId = job.id;
            _selectedCustodyFinalId = job.s('finalAssigneeId');
          }
        }
      } else if (widget.sourceType == 'handoff' && !_confirmDraft.hasInput) {
        _selectedConfirmHandoffId = sourceId;
      }
    }
    _restored = true;
  }

  @override
  void dispose() {
    for (final controller in [
      _roundLabel,
      _roundDate,
      _roundReceiver,
      _areaName,
      _areaKeywords,
      _primaryCapacity,
      _backupCapacity,
      _primaryCutoff,
      _backupCutoff,
      _jobNote,
      _assignReason,
      _scopeExpected,
      _scopeNote,
      _packageLabel,
      _packageQuantity,
      _packageUnit,
      _handoffNote,
      _confirmNote,
      _deliveryRecipient,
      _deliveryNote,
      _recoveryNote,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitCreateRound(Record team) async {
    final values = {
      'teamId': team.id,
      'label': _roundLabel.text.trim(),
      'operatingDate': _roundDate.text.trim(),
      'receiverLabel': _roundReceiver.text.trim(),
    };
    if (!_roundDraft.retrying && values['label']!.isEmpty) {
      await confirm(context, '회차 이름이 필요해요', '예: 새벽 1회차처럼 회차 이름을 먼저 입력해 주세요.');
      return;
    }
    try {
      await _roundDraft.submit('wf.createTeamRound', values);
      if (!mounted) return;
      setState(() {
        _roundLabel.clear();
        _roundDate.clear();
        _roundReceiver.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '회차를 만들지 못했어요', e.toString());
    }
  }

  Future<void> _submitArea(Record team, List<Record> areas) async {
    final area = _recordById(areas, _selectedAreaId);
    final values = {
      'teamId': team.id,
      if (area != null) 'id': area.id,
      if (area != null) 'version': area.version,
      'name': _areaName.text.trim(),
      'primaryMemberId': _selectedPrimaryId,
      'backupMemberId': _selectedBackupId,
      'primaryWorking': _primaryWorking,
      'backupWorking': _backupWorking,
      'primaryCapacity': _primaryCapacity.text.trim(),
      'backupCapacity': _backupCapacity.text.trim(),
      'primaryCutoffAt': _primaryCutoff.text.trim(),
      'backupCutoffAt': _backupCutoff.text.trim(),
      'matchKeywordsText': _areaKeywords.text.trim(),
    };
    if (!_areaDraft.retrying &&
        (_areaName.text.trim().isEmpty || _selectedPrimaryId.isEmpty)) {
      await confirm(context, '구역 정보를 확인해 주세요', '구역 이름과 주담당은 꼭 필요해요.');
      return;
    }
    try {
      await _areaDraft.submit('wf.assignTeamArea', values);
      if (!mounted) return;
      setState(() {
        _selectedAreaId = '';
        _areaName.clear();
        _selectedPrimaryId = '';
        _selectedBackupId = '';
        _primaryWorking = true;
        _backupWorking = false;
        _primaryCapacity.clear();
        _backupCapacity.clear();
        _primaryCutoff.clear();
        _backupCutoff.clear();
        _areaKeywords.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '구역을 저장하지 못했어요', e.toString());
    }
  }

  Future<void> _submitCreateJob(Record team) async {
    final values = {
      'teamId': team.id,
      'requestId': _selectedRequestId,
      'wholesalerIndex': _selectedWholesalerIndex,
      'roundId': _selectedJobRoundId,
      'areaId': _selectedJobAreaId,
      'note': _jobNote.text.trim(),
    };
    if (!_jobDraft.retrying && _selectedRequestId.isEmpty) {
      await confirm(
        context,
        '요청을 골라 주세요',
        '받은 요청 중에서 팀 업무로 묶을 원본 요청을 먼저 선택해 주세요.',
      );
      return;
    }
    try {
      await _jobDraft.submit('wf.createPickupJob', values);
      if (!mounted) return;
      setState(() {
        _jobNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '팀 업무를 만들지 못했어요', e.toString());
    }
  }

  Future<void> _submitAssign(List<Record> jobs) async {
    final job = _recordById(jobs, _selectedAssignJobId);
    if (job == null && !_assignDraft.retrying) {
      await confirm(context, '업무를 골라 주세요', '배정할 팀 업무를 먼저 선택해 주세요.');
      return;
    }
    final values = {
      'id': job?.id,
      'version': job?.version,
      'pickupAssigneeId': _selectedAssignPickupId,
      'finalAssigneeId': _selectedAssignFinalId,
      'roundId': _selectedAssignRoundId,
      'areaId': _selectedAssignAreaId,
      'assignmentReason': _assignReason.text.trim(),
    };
    if (!_assignDraft.retrying &&
        (_selectedAssignPickupId.isEmpty || _selectedAssignFinalId.isEmpty)) {
      await confirm(context, '담당자를 골라 주세요', '주 픽업 담당과 최종 전달 담당을 모두 선택해 주세요.');
      return;
    }
    try {
      await _assignDraft.submit('wf.assignPickupJob', values);
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '배정을 저장하지 못했어요', e.toString());
    }
  }

  Future<void> _submitAutoAssign(Record team) async {
    final values = {'teamId': team.id, 'roundId': _selectedAutoRoundId};
    if (!_autoDraft.retrying && _selectedAutoRoundId.isEmpty) {
      await confirm(context, '회차를 골라 주세요', '자동 배정할 회차를 먼저 선택해 주세요.');
      return;
    }
    try {
      await _autoDraft.submit('wf.autoAssignTeamRound', values);
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '자동 배정을 실행하지 못했어요', e.toString());
    }
  }

  Future<void> _submitScope(List<Record> jobs) async {
    final job = _recordById(jobs, _selectedScopeJobId);
    if (job == null && !_scopeDraft.retrying) {
      await confirm(context, '업무를 골라 주세요', '포장 범위를 확정할 팀 업무를 먼저 선택해 주세요.');
      return;
    }
    final values = {
      'id': job?.id,
      'version': job?.version,
      'expectedPackageCount': _scopeExpected.text.trim(),
      'scopeConfirmed': _scopeConfirmed,
      'hasBackorder': _hasBackorder,
      'note': _scopeNote.text.trim(),
    };
    try {
      await _scopeDraft.submit('wf.updatePickupScope', values);
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '포장 범위를 저장하지 못했어요', e.toString());
    }
  }

  Future<void> _submitCustody(List<Record> jobs) async {
    final job = _recordById(jobs, _selectedCustodyJobId);
    if (job == null && !_custodyDraft.retrying) {
      await confirm(context, '업무를 골라 주세요', '현장 포장을 기록할 팀 업무를 먼저 골라 주세요.');
      return;
    }
    final values = {
      'jobId': job?.id,
      'packageLabel': _packageLabel.text.trim(),
      'quantity': _packageQuantity.text.trim(),
      'unit': _packageUnit.text.trim(),
      'finalAssigneeId': _selectedCustodyFinalId,
    };
    if (!_custodyDraft.retrying &&
        (_packageLabel.text.trim().isEmpty ||
            _selectedCustodyFinalId.isEmpty)) {
      await confirm(context, '포장 정보를 확인해 주세요', '포장 이름과 최종 전달 담당을 모두 적어 주세요.');
      return;
    }
    try {
      await _custodyDraft.submit('wf.recordPackageCustody', values);
      if (!mounted) return;
      setState(() {
        _packageLabel.clear();
        _packageQuantity.text = '1';
        _packageUnit.text = '묶음';
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '포장 기록을 남기지 못했어요', e.toString());
    }
  }

  Future<void> _submitHandoff(Record team) async {
    final values = {
      'teamId': team.id,
      'toId': _selectedHandoffToId,
      'packageIds': _selectedHandoffPackages.toList()..sort(),
      'note': _handoffNote.text.trim(),
    };
    if (!_handoffDraft.retrying &&
        (_selectedHandoffToId.isEmpty || _selectedHandoffPackages.isEmpty)) {
      await confirm(context, '인계 목록을 확인해 주세요', '받는 팀원과 실제 받은 포장을 모두 선택해 주세요.');
      return;
    }
    try {
      await _handoffDraft.submit('wf.requestPackageHandoff', values);
      if (!mounted) return;
      setState(() {
        _selectedHandoffPackages.clear();
        _handoffNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '인계 요청을 만들지 못했어요', e.toString());
    }
  }

  Future<void> _submitConfirm(
    List<Record> handoffs,
    List<Record> packages,
  ) async {
    final handoff = _recordById(handoffs, _selectedConfirmHandoffId);
    if (handoff == null && !_confirmDraft.retrying) {
      await confirm(
        context,
        '인계 카드를 골라 주세요',
        '부분 수령하거나 전체 수령할 인계 카드를 먼저 고르세요.',
      );
      return;
    }
    final values = {
      'id': handoff?.id,
      'version': handoff?.version,
      'packageIds': _selectedConfirmedPackages.toList()..sort(),
      'versions': {
        for (final row in packages)
          if (_selectedConfirmedPackages.contains(row.id)) row.id: row.version,
      },
      'note': _confirmNote.text.trim(),
    };
    if (!_confirmDraft.retrying && _selectedConfirmedPackages.isEmpty) {
      await confirm(
        context,
        '실제로 받은 포장을 골라 주세요',
        '부분 수령도 실제 받은 포장만 선택해 확인할 수 있어요.',
      );
      return;
    }
    try {
      await _confirmDraft.submit('wf.confirmPackageHandoff', values);
      if (!mounted) return;
      setState(() {
        _selectedConfirmedPackages.clear();
        _confirmNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '인계 수령을 확인하지 못했어요', e.toString());
    }
  }

  Future<void> _submitDelivery(List<Record> packages) async {
    final values = {
      'packageIds': _selectedDeliveryPackages.toList()..sort(),
      'versions': {
        for (final row in packages)
          if (_selectedDeliveryPackages.contains(row.id)) row.id: row.version,
      },
      'recipientLabel': _deliveryRecipient.text.trim(),
      'note': _deliveryNote.text.trim(),
    };
    if (!_deliveryDraft.retrying && _selectedDeliveryPackages.isEmpty) {
      await confirm(context, '전달할 포장을 골라 주세요', '실제로 전달한 포장을 한 개 이상 선택해 주세요.');
      return;
    }
    try {
      await _deliveryDraft.submit('wf.recordPackageDelivery', values);
      if (!mounted) return;
      setState(() {
        _selectedDeliveryPackages.clear();
        _deliveryNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '전달 완료를 기록하지 못했어요', e.toString());
    }
  }

  Future<void> _persistRound() => _roundDraft.persist({
    'label': _roundLabel.text,
    'operatingDate': _roundDate.text,
    'receiverLabel': _roundReceiver.text,
  });

  Future<void> _persistArea() => _areaDraft.persist({
    if (_selectedAreaId.isNotEmpty) 'id': _selectedAreaId,
    'name': _areaName.text,
    'primaryMemberId': _selectedPrimaryId,
    'backupMemberId': _selectedBackupId,
    'primaryWorking': _primaryWorking,
    'backupWorking': _backupWorking,
    'primaryCapacity': _primaryCapacity.text,
    'backupCapacity': _backupCapacity.text,
    'primaryCutoffAt': _primaryCutoff.text,
    'backupCutoffAt': _backupCutoff.text,
    'matchKeywordsText': _areaKeywords.text,
  });

  Future<void> _persistJob() => _jobDraft.persist({
    'requestId': _selectedRequestId,
    'wholesalerIndex': _selectedWholesalerIndex,
    'roundId': _selectedJobRoundId,
    'areaId': _selectedJobAreaId,
    'note': _jobNote.text,
  });

  Future<void> _persistAssign() => _assignDraft.persist({
    'id': _selectedAssignJobId,
    'pickupAssigneeId': _selectedAssignPickupId,
    'finalAssigneeId': _selectedAssignFinalId,
    'roundId': _selectedAssignRoundId,
    'areaId': _selectedAssignAreaId,
    'assignmentReason': _assignReason.text,
  });

  Future<void> _persistAuto() =>
      _autoDraft.persist({'roundId': _selectedAutoRoundId});

  Future<void> _persistScope() => _scopeDraft.persist({
    'id': _selectedScopeJobId,
    'expectedPackageCount': _scopeExpected.text,
    'scopeConfirmed': _scopeConfirmed,
    'hasBackorder': _hasBackorder,
    'note': _scopeNote.text,
  });

  Future<void> _persistCustody() => _custodyDraft.persist({
    'jobId': _selectedCustodyJobId,
    'packageLabel': _packageLabel.text,
    'quantity': _packageQuantity.text,
    'unit': _packageUnit.text,
    'finalAssigneeId': _selectedCustodyFinalId,
  });

  Future<void> _persistHandoff() => _handoffDraft.persist({
    'toId': _selectedHandoffToId,
    'wholesalerName': _selectedHandoffWholesaler,
    'packageIds': _selectedHandoffPackages.toList(),
    'note': _handoffNote.text,
  });

  Future<void> _persistConfirm() => _confirmDraft.persist({
    'id': _selectedConfirmHandoffId,
    'packageIds': _selectedConfirmedPackages.toList(),
    'note': _confirmNote.text,
  });

  Future<void> _persistDelivery() => _deliveryDraft.persist({
    'packageIds': _selectedDeliveryPackages.toList(),
    'recipientLabel': _deliveryRecipient.text,
    'note': _deliveryNote.text,
  });

  Future<void> _persistRecovery() => _recoveryDraft.persist({
    'packageId': _selectedRecoveryPackageId,
    'nextHolderId': _selectedRecoveryHolderId,
    'note': _recoveryNote.text,
  });

  Future<void> _submitRecovery(List<Record> packages) async {
    final package = _recordById(packages, _selectedRecoveryPackageId);
    if (!_recoveryDraft.retrying &&
        (package == null ||
            _selectedRecoveryHolderId.isEmpty ||
            _recoveryNote.text.trim().isEmpty)) {
      await confirm(
        context,
        '실제 인수 근거가 필요해요',
        '회수한 포장, 현재 보관자와 실제 인수한 경위를 입력해 주세요.',
      );
      return;
    }
    try {
      await _recoveryDraft.submit('wf.recoverPackageCustody', {
        'packageId': package?.id,
        'version': package?.version,
        'previousHolderId': package?.s('currentHolderId'),
        'nextHolderId': _selectedRecoveryHolderId,
        'note': _recoveryNote.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _selectedRecoveryPackageId = '';
        _selectedRecoveryHolderId = '';
        _recoveryNote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      await confirm(context, '회수 기록을 저장하지 못했어요', e.toString());
    }
  }

  void _applyAreaSelection(List<Record> areas, String next) {
    setState(() {
      _selectedAreaId = next;
      final area = _recordById(areas, next);
      if (area == null) {
        _areaName.clear();
        _selectedPrimaryId = '';
        _selectedBackupId = '';
        _primaryWorking = true;
        _backupWorking = false;
        _primaryCapacity.clear();
        _backupCapacity.clear();
        _primaryCutoff.clear();
        _backupCutoff.clear();
        _areaKeywords.clear();
      } else {
        _areaName.text = area.s('name');
        _selectedPrimaryId = area.s('primaryMemberId');
        _selectedBackupId = area.s('backupMemberId');
        _primaryWorking = area.b('primaryWorking');
        _backupWorking = area.b('backupWorking');
        _primaryCapacity.text = area.n('primaryCapacity') == 0
            ? ''
            : '${area.n('primaryCapacity')}';
        _backupCapacity.text = area.n('backupCapacity') == 0
            ? ''
            : '${area.n('backupCapacity')}';
        _primaryCutoff.text = area.s('primaryCutoffAt');
        _backupCutoff.text = area.s('backupCutoffAt');
        _areaKeywords.text = teamMatchKeywordsOf(area.data).join(', ');
      }
    });
    _persistArea();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    if (current?.role != AppRole.uncle) {
      return const EmptyState(
        '팀 업무는 삼촌 전용이에요',
        '소매업자 수령 확인은 픽업 현황 화면에서 이어서 확인해 주세요.',
        icon: 'truck',
      );
    }
    final userId = current!.id;
    final team = _activeTeam(app.workspace.records('teams'), userId);
    if (team == null) {
      return const EmptyState(
        '먼저 팀을 만들어 주세요',
        '연결 탭에서 동료를 추가하고 팀을 만든 뒤 회차·구역·업무를 이어서 설정할 수 있어요.',
        icon: 'person',
      );
    }

    final rounds = app.workspace
        .records('teamRounds')
        .where((row) => row.s('teamId') == team.id)
        .toList(growable: false);
    final areas = app.workspace
        .records('teamAreas')
        .where((row) => row.s('teamId') == team.id)
        .toList(growable: false);
    final jobs = app.workspace
        .records('teamJobs')
        .where((row) {
          if (row.s('teamId') != team.id) return false;
          if (widget.requestIdFilter == null) return true;
          return row.s('requestId') == widget.requestIdFilter;
        })
        .toList(growable: false);
    final jobIds = jobs.map((row) => row.id).toSet();
    final packages = app.workspace
        .records('teamPackages')
        .where((row) => jobIds.contains(row.s('jobId')))
        .toList(growable: false);
    final sourcePackage = widget.sourceType == 'package'
        ? _recordById(packages, widget.sourceId ?? '')
        : null;
    final handoffs = app.workspace
        .records('teamHandoffs')
        .where((row) {
          if (row.s('teamId') != team.id) return false;
          if (widget.requestIdFilter == null) return true;
          for (final packageId in teamPackageIdsOf(row.data)) {
            final pack = _recordById(packages, packageId);
            if (pack != null) return true;
          }
          return false;
        })
        .toList(growable: false);
    final requests = app.workspace
        .records('requests')
        .where((row) {
          if (row.s('status') != 'accepted') return false;
          if (row.s('uncleId') != userId) return false;
          if (widget.requestIdFilter == null) return true;
          return row.id == widget.requestIdFilter;
        })
        .toList(growable: false);
    final admin = isTeamAdmin(team.data, userId);
    final members = [
      for (final memberId in teamMemberIdsOf(team.data))
        if (_activeTeamAccount(app, memberId))
          _Option(memberId, _displayName(app, memberId)),
    ];
    final currentUserJobs = jobs
        .where((row) => row.s('pickupAssigneeId') == userId)
        .toList(growable: false);
    final scopeJob = _recordById(jobs, _selectedScopeJobId);
    if (!_jobDraft.locked &&
        _selectedRequestId.isEmpty &&
        requests.isNotEmpty) {
      _selectedRequestId = requests.first.id;
    }
    if (!_autoDraft.locked &&
        _selectedAutoRoundId.isEmpty &&
        rounds.isNotEmpty) {
      _selectedAutoRoundId = rounds.first.id;
    }
    if (!_jobDraft.locked &&
        _selectedTeamIdOrEmpty(_selectedJobRoundId, rounds).isEmpty &&
        rounds.isNotEmpty) {
      _selectedJobRoundId = rounds.first.id;
    }

    final handoffPackages = packages
        .where((row) {
          if (row.s('currentHolderId') != userId) return false;
          if (row.s('finalAssigneeId') == userId) return false;
          return {
            'picked',
            'held',
            'handoff_requested',
          }.contains(row.s('status'));
        })
        .toList(growable: false);
    final handoffGroups = <String, List<Record>>{};
    for (final row in handoffPackages) {
      handoffGroups
          .putIfAbsent(row.s('wholesalerName'), () => <Record>[])
          .add(row);
    }
    if (!_handoffDraft.locked &&
        _selectedHandoffWholesaler.isEmpty &&
        handoffGroups.isNotEmpty) {
      _selectedHandoffWholesaler = handoffGroups.keys.first;
    }
    final selectedHandoffPackages =
        handoffGroups[_selectedHandoffWholesaler] ?? const <Record>[];
    final incomingHandoffs = handoffs
        .where(
          (row) =>
              row.s('toId') == userId &&
              {'pending', 'partial'}.contains(row.s('status')),
        )
        .toList(growable: false);
    final confirmHandoff = _recordById(
      incomingHandoffs,
      _selectedConfirmHandoffId,
    );
    final deliverablePackages = packages
        .where((row) {
          if (row.s('currentHolderId') != userId ||
              row.s('finalAssigneeId') != userId) {
            return false;
          }
          return {'delivery_ready', 'held', 'picked'}.contains(row.s('status'));
        })
        .toList(growable: false);
    final awaitingPackages = packages
        .where(
          (row) =>
              row.s('finalAssigneeId') == userId &&
              row.s('currentHolderId') != userId &&
              !{'delivered', 'received'}.contains(row.s('status')),
        )
        .toList(growable: false);
    final recoveryPackages = packages
        .where(
          (row) =>
              row.b('requiresReconciliation') &&
              row.s('reconciliationReason') == 'account_deleted' &&
              !{'delivered', 'received'}.contains(row.s('status')) &&
              !_activeTeamAccount(app, row.s('currentHolderId')),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sourcePackage != null)
          FigmaSurface(
            children: [
              const Section('선택한 포장'),
              Item(
                sourcePackage.s('packageLabel'),
                subtitle: _packageDescription(sourcePackage),
              ),
              QuantityRow(
                '현재 보관',
                _displayName(app, sourcePackage.s('currentHolderId')),
              ),
              QuantityRow(
                '최종 전달',
                _displayName(app, sourcePackage.s('finalAssigneeId')),
              ),
            ],
          ),
        FigmaSurface(
          children: [
            const Section('팀 현황'),
            Item(
              team.s('name'),
              subtitle: widget.requestIdFilter == null
                  ? '${jobs.length}개 업무 · ${packages.length}개 포장'
                  : '이 요청에 연결된 ${jobs.length}개 업무',
              leading: const FigmaIcon('truck'),
              trailing: StatusBadge(teamRoleLabel(team.data, userId)),
            ),
            Inset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuantityRow('활성 회차', '${rounds.length}개'),
                  QuantityRow('설정 구역', '${areas.length}개'),
                  QuantityRow(
                    '진행 업무',
                    '${jobs.where((row) => row.s('status') != 'received').length}건',
                  ),
                  QuantityRow('대기 인계', '${incomingHandoffs.length}건'),
                ],
              ),
            ),
            if (widget.requestIdFilter == null)
              const Info(
                '업무 카드를 누르면 요청별 팀 처리 화면으로 이동해 실제 포장·인계·전달을 이어서 처리할 수 있어요.',
              ),
          ],
        ),
        if (jobs.isEmpty)
          EmptyState.titleOnly(
            widget.requestIdFilter == null
                ? '아직 팀 업무가 없어요'
                : '이 요청의 팀 업무가 아직 없어요',
            icon: 'store',
          )
        else ...[
          const Section('진행 업무'),
          for (final job in jobs)
            FigmaSurface(
              children: [
                Item(
                  job.s('retailerName', '거래처'),
                  subtitle:
                      '${job.s('wholesalerName')} · ${teamJobStatusLabel(job.data)}',
                  leading: const FigmaIcon('store'),
                  trailing: StatusBadge(teamJobStatusLabel(job.data)),
                  onTap: widget.requestIdFilter == null
                      ? () => openPage(
                          context,
                          PickupRequestWorkPage(
                            requestId: job.s('requestId'),
                            sourceType: 'pickupJob',
                            sourceId: job.id,
                          ),
                        )
                      : null,
                ),
                Inset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuantityRow(
                        '픽업 담당',
                        _displayName(app, job.s('pickupAssigneeId')),
                      ),
                      QuantityRow(
                        '최종 전달',
                        _displayName(app, job.s('finalAssigneeId')),
                      ),
                      QuantityRow(
                        '도매처',
                        '${job.n('wholesalerIndex') + 1}번 · ${job.s('wholesalerName')}',
                      ),
                    ],
                  ),
                ),
                if (job.s('assignmentReason').isNotEmpty)
                  Info(job.s('assignmentReason')),
                if (job.s('autoAssignReason').isNotEmpty)
                  Info(job.s('autoAssignReason'), error: true),
              ],
            ),
        ],
        const Section('내가 팀원에게 줄 물건'),
        if (handoffPackages.isEmpty)
          const EmptyState.titleOnly('줄 물건이 없어요', icon: 'truck')
        else
          for (final row in handoffPackages)
            Item(
              row.s('packageLabel'),
              subtitle:
                  '${_packageDescription(row)}\n받을 팀원 · ${_displayName(app, row.s('finalAssigneeId'))}',
            ),
        const Section('내가 받아야 할 인계'),
        if (incomingHandoffs.isEmpty)
          const EmptyState.titleOnly('받을 인계가 없어요', icon: 'truck')
        else
          for (final row in incomingHandoffs)
            FigmaSurface(
              children: [
                Item(
                  _displayName(app, row.s('fromId')),
                  subtitle: row.s('wholesalerName'),
                  trailing: StatusBadge(
                    row.s('status') == 'partial' ? '부분 수령' : '수령 대기',
                  ),
                ),
                for (final package in _packagesForHandoff(packages, row))
                  Item(
                    package.s('packageLabel'),
                    subtitle: _packageDescription(package),
                  ),
                if (row.s('note').trim().isNotEmpty) Info(row.s('note')),
              ],
            ),
        const Section('고객 전달'),
        if (deliverablePackages.isEmpty && awaitingPackages.isEmpty)
          const EmptyState.titleOnly('전달할 물건이 없어요', icon: 'truck'),
        for (final row in deliverablePackages)
          Item(
            row.s('packageLabel'),
            subtitle: _packageDescription(row),
            trailing: const StatusBadge('전달 가능'),
          ),
        for (final row in awaitingPackages)
          Item(
            row.s('packageLabel'),
            subtitle:
                '${_packageDescription(row)}\n현재 보관 · ${_displayName(app, row.s('currentHolderId'))}',
            trailing: const StatusBadge('인계받기 전'),
          ),
        if (admin && widget.requestIdFilter == null) ...[
          _WorkflowSurface(
            draft: _roundDraft,
            children: [
              const Section('회차 만들기'),
              Field(
                '회차 이름',
                controller: _roundLabel,
                onChanged: (_) => _persistRound(),
              ),
              Field(
                '운영일',
                controller: _roundDate,
                onChanged: (_) => _persistRound(),
                placeholder: '2026-10-15',
              ),
              Field(
                '수령 안내',
                controller: _roundReceiver,
                onChanged: (_) => _persistRound(),
                placeholder: '예: 시장 입구 합류',
              ),
              ActionButton(
                _roundDraft.retrying ? '같은 회차 다시 만들기' : '회차 만들기',
                onPressed: () => _submitCreateRound(team),
              ),
            ],
          ),
          _WorkflowSurface(
            draft: _areaDraft,
            children: [
              const Section('구역 설정'),
              _OptionChoices(
                options: [
                  const _Option('', '새 구역'),
                  ...[for (final row in areas) _Option(row.id, row.s('name'))],
                ],
                value: _selectedAreaId,
                onChanged: (next) => _applyAreaSelection(areas, next),
              ),
              Field(
                '구역 이름',
                controller: _areaName,
                onChanged: (_) => _persistArea(),
              ),
              _OptionChoices(
                options: members,
                value: _selectedPrimaryId,
                onChanged: (next) {
                  setState(() => _selectedPrimaryId = next);
                  _persistArea();
                },
                title: '주담당',
              ),
              _OptionChoices(
                options: [const _Option('', '없음'), ...members],
                value: _selectedBackupId,
                onChanged: (next) {
                  setState(() => _selectedBackupId = next);
                  _persistArea();
                },
                title: '대체 담당',
              ),
              Toggle(
                '주담당 근무 중',
                value: _primaryWorking,
                onChanged: (next) {
                  setState(() => _primaryWorking = next);
                  _persistArea();
                },
              ),
              Toggle(
                '대체 담당 근무 중',
                value: _backupWorking,
                onChanged: (next) {
                  setState(() => _backupWorking = next);
                  _persistArea();
                },
              ),
              Field(
                '주담당 처리 가능 업무 수',
                controller: _primaryCapacity,
                numeric: true,
                onChanged: (_) => _persistArea(),
                placeholder: '0이면 제한 없음',
              ),
              Field(
                '대체 담당 처리 가능 업무 수',
                controller: _backupCapacity,
                numeric: true,
                onChanged: (_) => _persistArea(),
                placeholder: '0이면 제한 없음',
              ),
              Field(
                '주담당 마감 시간',
                controller: _primaryCutoff,
                onChanged: (_) => _persistArea(),
                placeholder: 'HH:mm 또는 ISO',
              ),
              Field(
                '대체 마감 시간',
                controller: _backupCutoff,
                onChanged: (_) => _persistArea(),
                placeholder: 'HH:mm 또는 ISO',
              ),
              Field(
                '매칭 키워드',
                controller: _areaKeywords,
                multiline: true,
                onChanged: (_) => _persistArea(),
                placeholder: '예: 남평화, A열, 2층',
              ),
              ActionButton(
                _areaDraft.retrying
                    ? '같은 구역 다시 저장'
                    : (_selectedAreaId.isEmpty ? '구역 만들기' : '구역 업데이트'),
                onPressed: () => _submitArea(team, areas),
              ),
            ],
          ),
        ],
        if (admin)
          _WorkflowSurface(
            draft: _jobDraft,
            children: [
              const Section('팀 업무 만들기'),
              _OptionChoices(
                options: [
                  for (final row in requests)
                    _Option(
                      row.id,
                      row.s('businessName', requestTitle(row.data)),
                    ),
                ],
                value: _selectedRequestId,
                onChanged: (next) {
                  setState(() {
                    _selectedRequestId = next;
                    _selectedWholesalerIndex = 0;
                  });
                  _persistJob();
                },
                title: '원본 요청',
              ),
              _OptionChoices(
                options: _wholesalerOptions(
                  _recordById(requests, _selectedRequestId),
                ),
                value: '$_selectedWholesalerIndex',
                onChanged: (next) {
                  setState(
                    () => _selectedWholesalerIndex = int.tryParse(next) ?? 0,
                  );
                  _persistJob();
                },
                title: '도매처 선택',
              ),
              _OptionChoices(
                options: [
                  const _Option('', '회차 미지정'),
                  ...[
                    for (final row in rounds) _Option(row.id, row.s('label')),
                  ],
                ],
                value: _selectedJobRoundId,
                onChanged: (next) {
                  setState(() => _selectedJobRoundId = next);
                  _persistJob();
                },
                title: '회차',
              ),
              _OptionChoices(
                options: [
                  const _Option('', '구역 미지정'),
                  ...[for (final row in areas) _Option(row.id, row.s('name'))],
                ],
                value: _selectedJobAreaId,
                onChanged: (next) {
                  setState(() => _selectedJobAreaId = next);
                  _persistJob();
                },
                title: '구역',
              ),
              Field(
                '업무 메모',
                controller: _jobNote,
                multiline: true,
                onChanged: (_) => _persistJob(),
              ),
              ActionButton(
                _jobDraft.retrying ? '같은 팀 업무 다시 만들기' : '팀 업무 만들기',
                onPressed: () => _submitCreateJob(team),
                enabled: requests.isNotEmpty || _jobDraft.retrying,
              ),
            ],
          ),
        if (jobs.isNotEmpty ||
            [
              _assignDraft,
              _autoDraft,
              _scopeDraft,
              _custodyDraft,
              _handoffDraft,
              _confirmDraft,
              _deliveryDraft,
            ].any((draft) => draft.retrying)) ...[
          if (admin)
            _WorkflowSurface(
              draft: _assignDraft,
              children: [
                const Section('업무 배정'),
                _OptionChoices(
                  options: [
                    for (final row in jobs)
                      _Option(
                        row.id,
                        '${row.s('retailerName')} · ${row.s('wholesalerName')}',
                      ),
                  ],
                  value: _selectedAssignJobId,
                  onChanged: (next) {
                    final job = _recordById(jobs, next);
                    setState(() {
                      _selectedAssignJobId = next;
                      _selectedAssignPickupId =
                          job?.s('pickupAssigneeId') ?? '';
                      _selectedAssignFinalId = job?.s('finalAssigneeId') ?? '';
                      _selectedAssignRoundId = job?.s('roundId') ?? '';
                      _selectedAssignAreaId = job?.s('areaId') ?? '';
                      _assignReason.text = job?.s('assignmentReason') ?? '';
                    });
                    _persistAssign();
                  },
                ),
                _OptionChoices(
                  options: members,
                  value: _selectedAssignPickupId,
                  onChanged: (next) {
                    setState(() => _selectedAssignPickupId = next);
                    _persistAssign();
                  },
                  title: '픽업 담당',
                ),
                _OptionChoices(
                  options: members,
                  value: _selectedAssignFinalId,
                  onChanged: (next) {
                    setState(() => _selectedAssignFinalId = next);
                    _persistAssign();
                  },
                  title: '최종 전달',
                ),
                _OptionChoices(
                  options: [
                    const _Option('', '회차 유지'),
                    ...[
                      for (final row in rounds) _Option(row.id, row.s('label')),
                    ],
                  ],
                  value: _selectedAssignRoundId,
                  onChanged: (next) {
                    setState(() => _selectedAssignRoundId = next);
                    _persistAssign();
                  },
                  title: '회차',
                ),
                _OptionChoices(
                  options: [
                    const _Option('', '구역 유지'),
                    ...[
                      for (final row in areas) _Option(row.id, row.s('name')),
                    ],
                  ],
                  value: _selectedAssignAreaId,
                  onChanged: (next) {
                    setState(() => _selectedAssignAreaId = next);
                    _persistAssign();
                  },
                  title: '구역',
                ),
                Field(
                  '배정 사유',
                  controller: _assignReason,
                  multiline: true,
                  onChanged: (_) => _persistAssign(),
                ),
                ActionButton(
                  _assignDraft.retrying ? '같은 배정 다시 저장' : '배정 저장',
                  onPressed: () => _submitAssign(jobs),
                ),
              ],
            ),
          if (admin && widget.requestIdFilter == null)
            _WorkflowSurface(
              draft: _autoDraft,
              children: [
                const Section('회차 자동 배정'),
                _OptionChoices(
                  options: [
                    for (final row in rounds) _Option(row.id, row.s('label')),
                  ],
                  value: _selectedAutoRoundId,
                  onChanged: (next) {
                    setState(() => _selectedAutoRoundId = next);
                    _persistAuto();
                  },
                ),
                const Info(
                  '수락한 요청 중 위치와 구역이 명확하고, 담당자의 근무 시간·마감·처리 가능 업무 수 조건을 만족하는 미착수 업무를 배정해요.',
                ),
                ActionButton(
                  _autoDraft.retrying ? '같은 자동 배정 다시 실행' : '자동 배정 실행',
                  weak: true,
                  onPressed: () => _submitAutoAssign(team),
                  enabled: rounds.isNotEmpty || _autoDraft.retrying,
                ),
              ],
            ),
          _WorkflowSurface(
            draft: _scopeDraft,
            children: [
              const Section('포장 범위 확정'),
              _OptionChoices(
                options: [
                  for (final row in jobs)
                    _Option(
                      row.id,
                      '${row.s('retailerName')} · ${row.s('wholesalerName')}',
                    ),
                ],
                value: _selectedScopeJobId,
                onChanged: (next) {
                  final job = _recordById(jobs, next);
                  setState(() {
                    _selectedScopeJobId = next;
                    _scopeExpected.text =
                        job == null || job.n('expectedPackageCount') == 0
                        ? ''
                        : '${job.n('expectedPackageCount')}';
                    _scopeConfirmed = job?.b('scopeConfirmed') ?? false;
                    _hasBackorder = job?.b('hasBackorder') ?? false;
                    _scopeNote.text = job?.s('scopeNote') ?? '';
                  });
                  _persistScope();
                },
              ),
              Field(
                '확정 포장 식별 수',
                controller: _scopeExpected,
                numeric: true,
                onChanged: (_) => _persistScope(),
              ),
              Toggle(
                '전체 범위 확정',
                value: _scopeConfirmed,
                onChanged: (next) {
                  setState(() => _scopeConfirmed = next);
                  _persistScope();
                },
              ),
              Toggle(
                '미송 남음',
                value: _hasBackorder,
                onChanged: (next) {
                  setState(() => _hasBackorder = next);
                  _persistScope();
                },
              ),
              Field(
                '범위 메모',
                controller: _scopeNote,
                multiline: true,
                onChanged: (_) => _persistScope(),
              ),
              if (scopeJob != null)
                Info(
                  '현재 포장 기록 ${packages.where((row) => row.s('jobId') == scopeJob.id).length}개 / 확정 목표 ${scopeJob.n('expectedPackageCount')}개',
                ),
              ActionButton(
                _scopeDraft.retrying ? '같은 범위 확정 다시 저장' : '포장 범위 저장',
                onPressed: () => _submitScope(jobs),
              ),
            ],
          ),
          if (currentUserJobs.isNotEmpty || _custodyDraft.retrying)
            _WorkflowSurface(
              draft: _custodyDraft,
              children: [
                const Section('현장 포장 받기'),
                _OptionChoices(
                  options: [
                    for (final row in currentUserJobs)
                      _Option(
                        row.id,
                        '${row.s('retailerName')} · ${row.s('wholesalerName')}',
                      ),
                  ],
                  value: _selectedCustodyJobId,
                  onChanged: (next) {
                    final job = _recordById(currentUserJobs, next);
                    setState(() {
                      _selectedCustodyJobId = next;
                      _selectedCustodyFinalId = job?.s('finalAssigneeId') ?? '';
                    });
                    _persistCustody();
                  },
                ),
                Field(
                  '포장 이름',
                  controller: _packageLabel,
                  onChanged: (_) => _persistCustody(),
                ),
                Field(
                  '수량',
                  controller: _packageQuantity,
                  numeric: true,
                  onChanged: (_) => _persistCustody(),
                ),
                Field(
                  '단위',
                  controller: _packageUnit,
                  onChanged: (_) => _persistCustody(),
                ),
                _OptionChoices(
                  options: members,
                  value: _selectedCustodyFinalId,
                  onChanged: (next) {
                    setState(() => _selectedCustodyFinalId = next);
                    _persistCustody();
                  },
                  title: '최종 전달 담당',
                ),
                ActionButton(
                  _custodyDraft.retrying ? '같은 포장 다시 기록' : '포장 기록 저장',
                  onPressed: () => _submitCustody(jobs),
                ),
              ],
            ),
          if (handoffGroups.isNotEmpty || _handoffDraft.retrying)
            _WorkflowSurface(
              draft: _handoffDraft,
              children: [
                const Section('인계 요청'),
                _OptionChoices(
                  options: [
                    for (final option in members.where(
                      (member) => member.id != userId,
                    ))
                      option,
                  ],
                  value: _selectedHandoffToId,
                  onChanged: (next) {
                    setState(() => _selectedHandoffToId = next);
                    _persistHandoff();
                  },
                  title: '받는 팀원',
                ),
                _OptionChoices(
                  options: [
                    for (final entry in handoffGroups.entries)
                      _Option(
                        entry.key,
                        '${entry.key} · ${entry.value.length}개',
                      ),
                  ],
                  value: _selectedHandoffWholesaler,
                  onChanged: (next) {
                    setState(() {
                      _selectedHandoffWholesaler = next;
                      _selectedHandoffPackages.clear();
                    });
                    _persistHandoff();
                  },
                  title: '도매처 묶음',
                ),
                for (final row in selectedHandoffPackages)
                  Item(
                    row.s('packageLabel'),
                    subtitle: _packageDescription(row),
                    trailing: TdsCheckbox(
                      checked: _selectedHandoffPackages.contains(row.id),
                      semanticLabel: '${row.s('packageLabel')} 선택',
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedHandoffPackages.add(row.id);
                          } else {
                            _selectedHandoffPackages.remove(row.id);
                          }
                        });
                        _persistHandoff();
                      },
                    ),
                  ),
                Field(
                  '인계 메모',
                  controller: _handoffNote,
                  multiline: true,
                  onChanged: (_) => _persistHandoff(),
                ),
                ActionButton(
                  _handoffDraft.retrying ? '같은 인계 요청 다시 보내기' : '인계 요청 보내기',
                  onPressed: () => _submitHandoff(team),
                ),
              ],
            ),
          if (incomingHandoffs.isNotEmpty || _confirmDraft.retrying)
            _WorkflowSurface(
              draft: _confirmDraft,
              children: [
                const Section('실제 일부 수령 / 인계 확인'),
                _OptionChoices(
                  options: [
                    for (final row in incomingHandoffs)
                      _Option(
                        row.id,
                        '${_displayName(app, row.s('fromId'))} · ${row.s('wholesalerName')}',
                      ),
                  ],
                  value: _selectedConfirmHandoffId,
                  onChanged: (next) {
                    final handoff = _recordById(incomingHandoffs, next);
                    setState(() {
                      _selectedConfirmHandoffId = next;
                      _selectedConfirmedPackages.clear();
                      _confirmNote.text = handoff?.s('note') ?? '';
                    });
                    _persistConfirm();
                  },
                ),
                for (final row in _packagesForHandoff(packages, confirmHandoff))
                  Item(
                    row.s('packageLabel'),
                    subtitle: _packageDescription(row),
                    trailing: TdsCheckbox(
                      checked: _selectedConfirmedPackages.contains(row.id),
                      semanticLabel: '${row.s('packageLabel')} 수령',
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedConfirmedPackages.add(row.id);
                          } else {
                            _selectedConfirmedPackages.remove(row.id);
                          }
                        });
                        _persistConfirm();
                      },
                    ),
                  ),
                Field(
                  '수령 메모',
                  controller: _confirmNote,
                  multiline: true,
                  onChanged: (_) => _persistConfirm(),
                ),
                ActionButton(
                  _confirmDraft.retrying ? '같은 수령 확인 다시 저장' : '받은 포장 확인',
                  onPressed: () => _submitConfirm(incomingHandoffs, packages),
                ),
              ],
            ),
          if (deliverablePackages.isNotEmpty || _deliveryDraft.retrying)
            _WorkflowSurface(
              draft: _deliveryDraft,
              children: [
                const Section('고객 전달 완료'),
                for (final row in deliverablePackages)
                  Item(
                    row.s('packageLabel'),
                    subtitle: _packageDescription(row),
                    trailing: TdsCheckbox(
                      checked: _selectedDeliveryPackages.contains(row.id),
                      semanticLabel: '${row.s('packageLabel')} 전달 완료',
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedDeliveryPackages.add(row.id);
                          } else {
                            _selectedDeliveryPackages.remove(row.id);
                          }
                          if (_selectedDeliveryPackages.length == 1) {
                            final first = _recordById(
                              deliverablePackages,
                              _selectedDeliveryPackages.first,
                            );
                            _deliveryRecipient.text =
                                first?.s('retailerName') ??
                                _deliveryRecipient.text;
                          }
                        });
                        _persistDelivery();
                      },
                    ),
                  ),
                Field(
                  '전달 대상 표기',
                  controller: _deliveryRecipient,
                  onChanged: (_) => _persistDelivery(),
                  placeholder: '예: 가게 A 사장님',
                ),
                Field(
                  '전달 메모',
                  controller: _deliveryNote,
                  multiline: true,
                  onChanged: (_) => _persistDelivery(),
                ),
                ActionButton(
                  _deliveryDraft.retrying ? '같은 전달 완료 다시 저장' : '전달 완료 기록',
                  onPressed: () => _submitDelivery(packages),
                ),
              ],
            ),
        ],
        if (admin && (recoveryPackages.isNotEmpty || _recoveryDraft.retrying))
          _WorkflowSurface(
            draft: _recoveryDraft,
            children: [
              const Section('보관 물건 회수'),
              _OptionChoices(
                title: '회수한 포장',
                options: [
                  for (final row in recoveryPackages)
                    _Option(row.id, '${row.s('packageLabel')} · ${row.id}'),
                ],
                value: _selectedRecoveryPackageId,
                onChanged: (next) {
                  setState(() => _selectedRecoveryPackageId = next);
                  _persistRecovery();
                },
              ),
              for (final row in recoveryPackages.where(
                (row) => row.id == _selectedRecoveryPackageId,
              ))
                Item(
                  row.s('packageLabel'),
                  subtitle:
                      '${_packageDescription(row)}\n이전 보관자 · ${_displayName(app, row.s('currentHolderId'))}',
                ),
              _OptionChoices(
                title: '현재 보관자',
                options: members,
                value: _selectedRecoveryHolderId,
                onChanged: (next) {
                  setState(() => _selectedRecoveryHolderId = next);
                  _persistRecovery();
                },
              ),
              Field(
                '실제 인수 근거',
                controller: _recoveryNote,
                multiline: true,
                onChanged: (_) => _persistRecovery(),
              ),
              ActionButton(
                _recoveryDraft.retrying ? '같은 회수 기록 다시 저장' : '회수 기록 저장',
                onPressed: () => _submitRecovery(packages),
              ),
            ],
          ),
      ],
    );
  }
}

class _AcceptedColleagueCard extends StatelessWidget {
  const _AcceptedColleagueCard({required this.row, required this.teamLabel});

  final Record row;
  final String teamLabel;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final userId = app.session.current!.id;
    final peer = app.workspace.profile(colleaguePeerId(row.data, userId));
    return FigmaSurface(
      children: [
        Item(
          peer?.displayName ?? '사입 동료',
          subtitle: teamLabel,
          leading: const FigmaIcon('person'),
          trailing: StatusBadge(colleagueConnectionLabel(row.data)),
        ),
      ],
    );
  }
}

class _ConnectionPendingCard extends StatelessWidget {
  const _ConnectionPendingCard({
    required this.row,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final Record row;
  final bool incoming;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final userId = app.session.current!.id;
    final peer = app.workspace.profile(colleaguePeerId(row.data, userId));
    return FigmaSurface(
      children: [
        Item(
          peer?.displayName ?? '사입 동료',
          subtitle: incoming ? '받은 연결 요청' : '보낸 연결 요청',
          leading: const FigmaIcon('person'),
          trailing: const StatusBadge('수락 대기'),
        ),
        if (incoming) ...[
          ActionButton('수락', onPressed: onAccept),
          ActionButton('거절', weak: true, onPressed: onDecline),
        ],
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.row,
    required this.title,
    required this.subtitle,
    this.onAccept,
    this.onDecline,
  });

  final Record row;
  final String title;
  final String subtitle;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;

  @override
  Widget build(BuildContext context) {
    return FigmaSurface(
      children: [
        Item(
          title,
          subtitle: subtitle,
          leading: const FigmaIcon('person'),
          trailing: StatusBadge(
            '${teamInviteKindLabel(row.data)} · ${teamInviteLabel(row.data)}',
          ),
        ),
        if (row.s('note').isNotEmpty) Info(row.s('note')),
        if (onAccept != null) ActionButton('수락', onPressed: onAccept!),
        if (onDecline != null)
          ActionButton('거절', weak: true, onPressed: onDecline!),
      ],
    );
  }
}

class _Option {
  const _Option(this.id, this.label);

  final String id;
  final String label;
}

class _OptionChoices extends StatelessWidget {
  const _OptionChoices({
    required this.options,
    required this.value,
    required this.onChanged,
    this.title,
  });

  final List<_Option> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Info('선택할 항목이 아직 없어요.');
    }
    final selected = _labelFor(value, options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: TdsText(
              title!,
              typography: TdsTypography.t7,
              color: TdsTheme.of(context).color('grey600'),
            ),
          ),
        Choices(
          options: [for (final option in options) option.label],
          value: selected,
          onChanged: (next) {
            for (final option in options) {
              if (option.label == next) {
                onChanged(option.id);
                return;
              }
            }
          },
        ),
      ],
    );
  }

  static String _labelFor(String id, List<_Option> options) {
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return '';
  }
}

mixin _WorkflowDraftOwner<T extends StatefulWidget> on State<T> {
  final Map<String, _WorkflowDraft> _drafts = {};

  _WorkflowDraft trackDraft(WorkspaceRepository workspace, String key) =>
      _drafts.putIfAbsent(key, () {
        final session = AppScope.of(context).session;
        final draft = _WorkflowDraft(workspace, key, () => session.current?.id);
        draft.addListener(_draftChanged);
        return draft;
      });

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.removeListener(_draftChanged);
      draft.dispose();
    }
    super.dispose();
  }
}

class _WorkflowSurface extends StatelessWidget {
  const _WorkflowSurface({required this.draft, required this.children});

  final _WorkflowDraft draft;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) => FigmaSurface(
      children: [
        if (draft.locked) const Info('서버 확인을 기다리고 있어요. 같은 내용으로 다시 시도할 수 있어요.'),
        for (final child in children)
          if (child is ActionButton)
            child
          else
            IgnorePointer(
              ignoring: draft.locked,
              child: ExcludeFocus(excluding: draft.locked, child: child),
            ),
      ],
    ),
  );
}

class _WorkflowDraft extends ChangeNotifier {
  _WorkflowDraft(this.workspace, this.key, this.currentActor)
    : actorId = currentActor() {
    final saved = workspace.workflowInput(key);
    operationId = textOf(saved, 'operationId', operationId);
    submitted = _copy(mapOf(saved, 'submitted'));
    _command = textOf(saved, 'command');
    _values = _copy(mapOf(saved, 'values'));
  }

  final WorkspaceRepository workspace;
  final String key;
  final String? Function() currentActor;
  final String? actorId;
  String operationId = newId();
  Data submitted = const {};
  Data _values = {};
  String _command = '';
  Future<void> _writes = Future.value();
  Future<String>? _inFlight;
  bool _disposed = false;

  bool get retrying => submitted.isNotEmpty;
  bool get _sameAccount => actorId != null && actorId == currentActor();
  bool get locked => retrying || _inFlight != null;
  bool get hasInput => _values.isNotEmpty || retrying;

  Record? get pendingRecord => workspace
      .records('workflowPending')
      .where((row) => row.s('operationId') == operationId)
      .firstOrNull;
  bool get rejected => pendingRecord?.s('status') == 'rejected';

  void restore(void Function(Data values) apply) {
    apply(_copy(_values));
  }

  Future<void> persist(Data values) {
    if (locked || !_sameAccount) return Future.value();
    _values = _copy(values);
    return _save();
  }

  static Data _copy(Data values) =>
      Map<String, Object?>.from(jsonDecode(jsonEncode(values)) as Map);

  Future<void> _save({bool clear = false}) {
    final envelope = clear
        ? <String, Object?>{}
        : _copy({
            'values': _values,
            'operationId': operationId,
            'command': _command,
            'submitted': submitted,
          });
    final write = _writes.then((_) {
      _requireSameAccount();
      return workspace.saveWorkflowInput(key, envelope);
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _requireSameAccount() {
    if (!_sameAccount) throw StateError('계정이 변경되었어요. 현재 계정의 화면에서 다시 진행해 주세요.');
  }

  void _reset() {
    submitted = const {};
    _command = '';
    operationId = newId();
  }

  Future<void> discardRejectedWorkflow() async {
    _requireSameAccount();
    if (!rejected) return;
    await workspace.discardRejectedWorkflow(operationId);
    _reset();
    await _save();
    _changed();
  }

  Future<String> submit(String command, Data values) {
    if (!_sameAccount) {
      return Future.error(StateError('계정이 변경되었어요. 현재 계정의 화면에서 다시 진행해 주세요.'));
    }
    if (_inFlight != null) return _inFlight!;
    FocusManager.instance.primaryFocus?.unfocus();
    if (submitted.isEmpty) {
      submitted = _copy(values);
      _command = command;
      _values = _copy({..._values, ...values});
    }
    if (_command.isEmpty) _command = command;
    final future = _send();
    _inFlight = future;
    _changed();
    return future;
  }

  Future<String> _send() async {
    bool acknowledged = false;
    try {
      // 서버 호출 전에 입력과 고정된 명령을 순서대로 저장한다.
      await _save();
      _requireSameAccount();
      final result = await workspace.workflow(_command, submitted, operationId);
      acknowledged = true;
      _requireSameAccount();
      await _save(clear: true);
      _reset();
      _values = {};
      return result;
    } catch (_) {
      final pending = pendingRecord;
      if (_sameAccount &&
          !acknowledged &&
          (pending == null || pending.s('status') == 'rejected')) {
        if (pending != null) {
          await workspace.discardRejectedWorkflow(operationId);
        }
        _reset();
        await _save();
      }
      rethrow;
    } finally {
      _inFlight = null;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Record? _activeTeam(List<Record> teams, String userId) {
  for (final team in teams) {
    if (team.s('status', 'active') != 'active') continue;
    if (teamMemberIdsOf(team.data).contains(userId)) return team;
  }
  return null;
}

String _teamLabel(List<Record> teams, String teamId) {
  final team = _recordById(teams, teamId);
  return team?.s('name') ?? '팀';
}

String _displayName(AppServices app, String userId) {
  if (userId.trim().isEmpty) return '미정';
  return app.workspace.profile(userId)?.displayName ?? '알 수 없음';
}

bool _activeTeamAccount(AppServices app, String userId) {
  final account = app.workspace.profile(userId);
  return account != null && account.complete && !account.b('deletionPending');
}

String _packageDescription(Record package) =>
    '${package.s('retailerName', '거래처')} · ${package.s('wholesalerName', '도매처')}\n'
    '포장 ${package.id} · ${package.n('quantity')} ${package.s('unit', '묶음')}';

Future<void> _openTeamSource(BuildContext context, Record card) async {
  final app = AppScope.of(context);
  final sourceType = card.s('sourceType');
  final collection = switch (sourceType) {
    'pickupJob' => 'teamJobs',
    'handoff' => 'teamHandoffs',
    'package' => 'teamPackages',
    _ => '',
  };
  final source = collection.isEmpty
      ? null
      : _recordById(app.workspace.records(collection), card.s('sourceId'));
  if (source == null) {
    await confirm(context, '업무 기록을 확인할 수 없어요', '현재 팀 권한과 동기화 상태를 확인해 주세요.');
    return;
  }
  final requestId = source.s('requestId');
  await openPage(
    context,
    requestId.isEmpty
        ? TeamWorkPage(sourceType: sourceType, sourceId: source.id)
        : PickupRequestWorkPage(
            requestId: requestId,
            sourceType: sourceType,
            sourceId: source.id,
          ),
  );
}

String _colleagueTeamLabel(AppServices app, String peerId, Record? activeTeam) {
  final teamName = _activeTeamNameForPeer(app, peerId);
  if (teamName.isEmpty) return '외부 동료';
  if (activeTeam != null && teamMemberIdsOf(activeTeam.data).contains(peerId)) {
    return '같은 팀 · $teamName';
  }
  return '외부 동료 · $teamName';
}

String _activeTeamNameForPeer(AppServices app, String peerId) {
  for (final row in app.workspace.snapshot.all('teams')) {
    if (row.s('status', 'active') != 'active') continue;
    if (teamMemberIdsOf(row.data).contains(peerId)) return row.s('name');
  }
  return '';
}

List<Record> _knownColleagueTeams(
  AppServices app,
  String userId,
  List<Record> accepted,
) {
  final connectedIds = {
    for (final row in accepted) colleaguePeerId(row.data, userId),
  };
  final visible = <String>{};
  final teams = <Record>[];
  for (final row in app.workspace.snapshot.all('teams')) {
    if (row.s('status', 'active') != 'active') continue;
    if (teamMemberIdsOf(row.data).contains(userId)) continue;
    final containsColleague = teamMemberIdsOf(
      row.data,
    ).any(connectedIds.contains);
    if (!containsColleague || !visible.add(row.id)) continue;
    teams.add(row);
  }
  teams.sort((a, b) => a.s('name').compareTo(b.s('name')));
  return teams;
}

Record? _recordById(List<Record> rows, String id) {
  for (final row in rows) {
    if (row.id == id) return row;
  }
  return null;
}

String _selectedTeamIdOrEmpty(String value, List<Record> rounds) {
  return _recordById(rounds, value) == null ? '' : value;
}

List<_Option> _wholesalerOptions(Record? request) {
  if (request == null) return const [_Option('0', '기본 도매처')];
  final rows = requestWholesalers(request.data);
  if (rows.isEmpty) return const [_Option('0', '기본 도매처')];
  final options = <_Option>[];
  for (var index = 0; index < rows.length; index++) {
    final wholesaler = textOf(rows[index], 'wholesaler');
    final location = textOf(rows[index], 'location');
    options.add(
      _Option(
        '$index',
        '${index + 1}. ${wholesaler.isEmpty ? '도매처' : wholesaler}${location.isEmpty ? '' : ' · $location'}',
      ),
    );
  }
  return options;
}

List<Record> _packagesForHandoff(List<Record> packages, Record? handoff) {
  if (handoff == null) return const <Record>[];
  final allowed = teamPackageIdsOf(handoff.data).toSet();
  allowed.removeAll(teamAcceptedPackageIdsOf(handoff.data));
  return packages
      .where((row) => allowed.contains(row.id))
      .toList(growable: false);
}
