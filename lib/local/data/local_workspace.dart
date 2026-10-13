import 'dart:math';

import '../domain/chat_content_policy.dart';
import '../domain/models.dart';
import 'local_store.dart';

class LocalWorkspaceRepository extends WorkspaceRepository {
  LocalWorkspaceRepository(this.store, this.session) {
    store.addListener(notifyListeners);
  }
  final LocalStore store;
  final SessionRepository session;
  String get actor =>
      session.current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
  @override
  WorkspaceSnapshot get snapshot => store.snapshot;
  static const _directoryFields = [
    'name',
    'nickname',
    'publicCode',
    'role',
    'complete',
    'photoId',
    'pickupArea',
    'deliveryArea',
    'deadline',
    'holiday',
    'intro',
    'working',
    'fee',
  ];

  Data _directoryProfile(Account account) => {
    for (final key in _directoryFields)
      if (account.data.containsKey(key)) key: account.data[key],
  };

  Account _directoryAccount(Account account) =>
      Account(account.id, _directoryProfile(account));

  bool _belongs(Data r) => [
    textOf(r, 'retailerId'),
    textOf(r, 'uncleId'),
  ].contains(session.current?.id);
  bool _connection(Data r) =>
      [textOf(r, 'from'), textOf(r, 'to')].contains(session.current?.id);
  @override
  List<Record> records(String table) {
    final user = session.current?.id;
    if (user == null) return [];
    final rows = snapshot
        .all(table)
        .where(
          (r) => switch (table) {
            'connections' => _connection(r.data),
            'drafts' => r.s('ownerId') == user,
            'requests' => _belongs(r.data),
            'deliveries' ||
            'receipts' ||
            'events' ||
            'issues' ||
            'proposals' => request(r.s('requestId')) != null,
            'messages' =>
              r.s('senderId') == user ||
                  (r.s('recipientId') == user && r.s('status') == 'sent'),
            'notices' => r.s('ownerId') == user,
            'attachments' => r.s('ownerId') == user,
            _ => false,
          },
        )
        .toList();
    rows.sort((a, b) => b.s('createdAt').compareTo(a.s('createdAt')));
    return rows;
  }

  @override
  List<Account> get partners {
    final ids = records('connections')
        .where((r) => r.s('status') == 'accepted')
        .map((r) => r.s('from') == actor ? r.s('to') : r.s('from'))
        .toSet();
    return snapshot.accounts.where((a) => ids.contains(a.id)).toList();
  }

  @override
  Account? profile(String id) {
    if (id != session.current?.id &&
        !records(
          'connections',
        ).any((r) => r.s('from') == id || r.s('to') == id)) {
      return null;
    }
    final r = snapshot.get('accounts', id);
    return r == null ? null : Account(id, r.data);
  }

  @override
  RequestRecord? request(String id) {
    final r = snapshot.get('requests', id);
    return r == null || !_belongs(r.data) ? null : RequestRecord(id, r.data);
  }

  void _checkVersion(Data record, int version) {
    if (numberOf(record, 'version') != version) {
      throw const AppFailure('다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.');
    }
  }

  Data _request(MutableWorkspace s, String id, String user, [int? version]) {
    final r = s.require('requests', id);
    if (![textOf(r, 'retailerId'), textOf(r, 'uncleId')].contains(user)) {
      throw const AppFailure('이 요청을 볼 수 없어요.');
    }
    if (version != null) _checkVersion(r, version);
    return r;
  }

  void _role(Data r, String user, String role) {
    if (textOf(r, '${role}Id') != user) {
      throw const AppFailure('이 작업을 처리할 권한이 없어요.');
    }
  }

  void _active(Data r) {
    if (RequestRecord('', r).ended) throw const AppFailure('이미 종료된 요청이에요.');
  }

  void _accepted(Data r) {
    _active(r);
    if (textOf(r, 'status') != 'accepted') {
      throw const AppFailure('먼저 요청을 수락해 주세요.');
    }
  }

  void _unheld(Data r) {
    if (textOf(r, 'proposalId').isNotEmpty) {
      throw const AppFailure('진행 중인 변경·취소 협의를 먼저 처리해 주세요.');
    }
  }

  void _connected(MutableWorkspace s, String a, String b) {
    if (!s
        .all('connections')
        .any(
          (c) =>
              textOf(c.value, 'status') == 'accepted' &&
              {
                textOf(c.value, 'from'),
                textOf(c.value, 'to'),
              }.containsAll([a, b]),
        )) {
      throw const AppFailure('연결이 완료된 상대방을 선택해 주세요.');
    }
  }

  String _other(Data r, String user) => textOf(r, 'retailerId') == user
      ? textOf(r, 'uncleId')
      : textOf(r, 'retailerId');
  void _notice(
    MutableWorkspace s,
    String owner,
    String title,
    String kind,
    String target, {
    String requestId = '',
  }) {
    final id = newId();
    s.put('notices', id, {
      'ownerId': owner,
      'title': title,
      'kind': kind,
      'targetId': target,
      'requestId': requestId,
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  void _event(
    MutableWorkspace s,
    String id,
    Data before,
    Data after,
    String user,
    String title, {
    String kind = 'request',
    String target = '',
  }) {
    final now = DateTime.now().toIso8601String();
    final event = newId();
    s.put('events', event, {
      'requestId': id,
      'actorId': user,
      'title': title,
      'before': {...before},
      'after': {...after},
      'createdAt': now,
    });
    s.put('messages', event, {
      'senderId': user,
      'recipientId': _other(after, user),
      'body': title,
      'requestId': id,
      'system': true,
      'status': 'sent',
      'createdAt': now,
      'read': false,
    });
    _notice(
      s,
      _other(after, user),
      title,
      kind,
      target.isEmpty ? id : target,
      requestId: id,
    );
  }

  void _finish(Data r) {
    final q = RequestRecord('', r);
    if (q.received < 0 ||
        q.received > q.delivered ||
        q.delivered > q.acquired ||
        q.acquiredCancelled < 0 ||
        q.acquiredCancelled > q.cancelled ||
        q.acquiredCancelled + q.delivered > q.acquired ||
        q.n('held') < 0 ||
        q.n('held') > q.acquired - q.acquiredCancelled - q.delivered ||
        q.cancelled > q.quantity ||
        q.quantity - q.cancelled < q.acquired - q.acquiredCancelled) {
      throw const AppFailure('확보·전달·수령·취소 수량을 다시 확인해 주세요.');
    }
    if (q.s('status') == 'rejected' || q.s('status') == 'pending') return;
    final fulfilled = q.quantity - q.cancelled;
    if (q.n('openIssues') == 0 &&
        q.s('proposalId').isEmpty &&
        q.backorder == 0 &&
        q.received == fulfilled &&
        q.delivered == fulfilled) {
      r['status'] = fulfilled == 0 ? 'cancelled' : 'completed';
    } else {
      r['status'] = 'accepted';
    }
  }

  void _putRequest(
    MutableWorkspace s,
    String id,
    Data before,
    Data after,
    String user,
    String title, {
    String kind = 'request',
    String target = '',
  }) {
    _finish(after);
    if (numberOf(after, 'received') > numberOf(before, 'received')) {
      after['receivedAt'] = DateTime.now().toIso8601String();
    }
    after['version'] = numberOf(before, 'version') + 1;
    after['updatedAt'] = DateTime.now().toIso8601String();
    s.put('requests', id, after);
    _event(s, id, before, after, user, title, kind: kind, target: target);
  }

  @override
  Future<Account> lookupCode(String code) async {
    final input = code.trim().toUpperCase();
    final match = snapshot.accounts.where((a) => a.s('code') == input);
    if (match.isEmpty) throw const AppFailure('초대 코드를 다시 확인해 주세요.');
    final peer = match.first;
    if (peer.id == actor || peer.role == session.current?.role) {
      throw const AppFailure('다른 역할의 상대방 코드를 입력해 주세요.');
    }
    if (!peer.complete) throw const AppFailure('상대방이 아직 가입을 완료하지 않았어요.');
    if (DateTime.parse(peer.s('codeExpires')).isBefore(DateTime.now())) {
      throw const AppFailure('만료된 코드예요. 상대방에게 새 코드를 요청해 주세요.');
    }
    final existing = records('connections').where(
      (r) =>
          {r.s('from'), r.s('to')}.containsAll([actor, peer.id]) &&
          ['accepted', 'pending'].contains(r.s('status')),
    );
    if (existing.isNotEmpty) {
      throw AppFailure(
        existing.first.s('status') == 'accepted'
            ? '이미 연결된 상대방이에요.'
            : '이미 연결 수락을 기다리고 있어요.',
      );
    }
    return _directoryAccount(peer);
  }

  @override
  Future<List<Account>> searchPartners({
    String query = '',
    String region = '',
    int? minFee,
    int? maxFee,
    int limit = 20,
    int offset = 0,
  }) async {
    final me = session.current ?? (throw const AppFailure('로그인이 필요해요.'));
    if (!me.complete) {
      throw const AppFailure('프로필을 먼저 완료해 주세요.');
    }
    final myRole = me.role ?? (throw const AppFailure('역할을 선택해 주세요.'));
    if (limit < 1 || limit > 50 || offset < 0) {
      throw const AppFailure('검색 조건을 다시 확인해 주세요.');
    }
    if ((minFee != null && (minFee < 0 || minFee > maxPartnerFee)) ||
        (maxFee != null && (maxFee < 0 || maxFee > maxPartnerFee))) {
      throw const AppFailure('검색 조건을 다시 확인해 주세요.');
    }
    if (minFee != null && maxFee != null && minFee > maxFee) {
      throw const AppFailure('검색 조건을 다시 확인해 주세요.');
    }
    final trimmedQuery = query.trim();
    final trimmedRegion = region.trim().toLowerCase();
    final exactPublicCode = RegExp(r'^#[0-9]{4}$').hasMatch(trimmedQuery)
        ? trimmedQuery.toUpperCase()
        : '';
    final lowerQuery = trimmedQuery.toLowerCase();
    final matches =
        snapshot.accounts.where((account) {
          if (!account.complete ||
              account.id == me.id ||
              account.role == null) {
            return false;
          }
          if (account.role == myRole) return false;
          if (exactPublicCode.isNotEmpty &&
              account.publicCode != exactPublicCode) {
            return false;
          }
          if (exactPublicCode.isEmpty && lowerQuery.isNotEmpty) {
            final searchable = [account.nickname, account.name]
                .where((value) => value.trim().isNotEmpty)
                .map((value) => value.toLowerCase())
                .toList();
            if (!searchable.any((value) => value.contains(lowerQuery))) {
              return false;
            }
          }
          if (trimmedRegion.isNotEmpty) {
            final regionText = [
              account.s('pickupArea'),
              account.s('deliveryArea'),
            ].join(' ').toLowerCase();
            if (!regionText.contains(trimmedRegion)) return false;
          }
          if (minFee != null || maxFee != null) {
            final fee = account.fee;
            if (fee == null) return false;
            if (minFee != null && fee < minFee) return false;
            if (maxFee != null && fee > maxFee) return false;
          }
          return true;
        }).toList()..sort((left, right) {
          final byName = left.displayName.toLowerCase().compareTo(
            right.displayName.toLowerCase(),
          );
          if (byName != 0) return byName;
          return left.id.compareTo(right.id);
        });
    if (offset >= matches.length) return const [];
    final end = min(matches.length, offset + limit);
    return matches.sublist(offset, end).map(_directoryAccount).toList();
  }

  @override
  Future<void> renewCode() async {
    final user = actor;
    await store.write(user, '', (s) {
      final a = s.require('accounts', user);
      s.put('accounts', user, {
        ...a,
        'code': newId().toUpperCase(),
        'codeExpires': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });
      return user;
    });
  }

  @override
  Future<String> connect(String peerId, String operationId) async {
    final user = actor;
    return store.write(user, operationId, (s) {
      final peer = s.require('accounts', peerId),
          me = s.require('accounts', user);
      if (peerId == user ||
          textOf(peer, 'role') == textOf(me, 'role') ||
          !flagOf(peer, 'complete') ||
          !flagOf(me, 'complete')) {
        throw const AppFailure('가입을 완료한 다른 역할의 계정과 연결해 주세요.');
      }
      if (s
          .all('connections')
          .any(
            (c) =>
                {
                  textOf(c.value, 'from'),
                  textOf(c.value, 'to'),
                }.containsAll([user, peerId]) &&
                ['pending', 'accepted'].contains(textOf(c.value, 'status')),
          )) {
        throw const AppFailure('이미 연결되었거나 수락 대기 중이에요.');
      }
      final id = newId();
      s.put('connections', id, {
        'from': user,
        'to': peerId,
        'status': 'pending',
        'version': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _notice(s, peerId, '새 거래처 연결 요청', 'connection', id);
      return id;
    });
  }

  @override
  Future<void> respondConnection(
    String id,
    String status,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final r = s.require('connections', id);
      _checkVersion(r, version);
      if (textOf(r, 'status') != 'pending' ||
          !['accepted', 'rejected', 'withdrawn'].contains(status)) {
        throw const AppFailure('이미 처리된 연결 요청이에요.');
      }
      if (textOf(r, status == 'withdrawn' ? 'from' : 'to') != user) {
        throw const AppFailure('이 연결 요청을 처리할 수 없어요.');
      }
      s.put('connections', id, {
        ...r,
        'status': status,
        'version': version + 1,
      });
      final peer = textOf(r, 'from') == user
          ? textOf(r, 'to')
          : textOf(r, 'from');
      _notice(
        s,
        peer,
        '연결 요청이 ${status == 'accepted'
            ? '수락'
            : status == 'rejected'
            ? '거절'
            : '철회'}되었어요',
        'connection',
        id,
      );
      return id;
    });
  }

  static const requestFields = [
    'uncleId',
    'requestType',
    'wholesalers',
    'wholesaler',
    'location',
    'product',
    'option',
    'quantity',
    'address',
    'addressDetail',
    'note',
    'photos',
  ];
  Data _fields(Data input) {
    final fields = <String, Object?>{
      for (final key in requestFields)
        if (input.containsKey(key)) key: input[key],
    };
    if (input.containsKey('wholesalers')) {
      final raw = input['wholesalers'];
      if (raw is! List ||
          raw.length > maxRequestWholesalers ||
          raw.any((entry) => entry is! Map)) {
        throw const AppFailure('도매처는 최대 10곳까지 입력할 수 있어요.');
      }
      final wholesalers = requestWholesalers(input);
      fields['wholesalers'] = wholesalers;
      fields['wholesaler'] = wholesalers.isEmpty
          ? ''
          : textOf(wholesalers.first, 'wholesaler');
      fields['location'] = wholesalers.isEmpty
          ? ''
          : textOf(wholesalers.first, 'location');
    }
    if (isWholesalerOnlyRequest(input)) {
      // 상품 수량을 입력받지 않는 주문은 기존 처리 흐름에서 요청 한 건으로 센다.
      fields.addAll({'product': '', 'option': '', 'photos': <String>[], 'quantity': 1});
    }
    return fields;
  }

  Data _savedDestination(MutableWorkspace s, Data fields, String user) {
    if (!isWholesalerOnlyRequest(fields)) return fields;
    final account = s.require('accounts', user);
    return {
      ...fields,
      'address': textOf(account, 'address'),
      'addressDetail': textOf(account, 'addressDetail'),
      'note': textOf(account, 'deliveryNote'),
    };
  }

  void _validateRequest(MutableWorkspace s, Data r, String user) {
    if (isWholesalerOnlyRequest(r) || r.containsKey('wholesalers')) {
      final wholesalers = requestWholesalers(r);
      if (wholesalers.isEmpty || wholesalers.length > maxRequestWholesalers) {
        throw const AppFailure('도매처를 1곳 이상, 최대 10곳까지 입력해 주세요.');
      }
      for (var index = 0; index < wholesalers.length; index++) {
        final wholesaler = wholesalers[index];
        if (textOf(wholesaler, 'wholesaler').isEmpty ||
            textOf(wholesaler, 'location').isEmpty) {
          throw AppFailure('도매처 ${index + 1}의 이름과 위치를 입력해 주세요.');
        }
      }
    }
    for (final entry in {
      'uncleId': '사입삼촌',
      'wholesaler': '도매처',
      'location': '도매처 위치',
      if (!isWholesalerOnlyRequest(r)) ...{
        'product': '상품명',
        'option': '옵션',
        'address': '배송지',
        'addressDetail': '상세주소',
      },
    }.entries) {
      if (textOf(r, entry.key).trim().isEmpty) {
        throw AppFailure('${entry.value} 항목을 입력해 주세요.');
      }
    }
    if (numberOf(r, 'quantity') <= 0) {
      throw const AppFailure('수량은 1개 이상 입력해 주세요.');
    }
    _connected(s, user, textOf(r, 'uncleId'));
    for (final id in stringsOf(r, 'photos')) {
      if (textOf(s.require('attachments', id), 'ownerId') != user) {
        throw const AppFailure('본인이 첨부한 사진을 선택해 주세요.');
      }
    }
  }

  @override
  Future<String> saveDraft(String id, Data fields) async {
    final user = actor;
    return store.write(user, '', (s) {
      if (textOf(s.require('accounts', user), 'role') != 'retailer') {
        throw const AppFailure('소매업자만 요청을 작성할 수 있어요.');
      }
      final previous = s.tables['drafts']![id];
      if (previous != null && textOf(previous, 'ownerId') != user) {
        throw const AppFailure('다른 계정의 초안이에요.');
      }
      if (s.tables['requests']!.containsKey(id)) {
        throw const AppFailure('이미 전송한 요청이에요.');
      }
      s.put('drafts', id, {
        ...?previous,
        ..._savedDestination(s, _fields(fields), user),
        'ownerId': user,
        'createdAt': previous?['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return id;
    });
  }

  @override
  Future<void> deleteDraft(String id) async {
    final user = actor;
    await store.write(user, '', (s) {
      if (textOf(s.require('drafts', id), 'ownerId') != user) {
        throw const AppFailure('다른 계정의 초안이에요.');
      }
      s.remove('drafts', id);
      return id;
    });
  }

  @override
  Future<String> repeatRequest(String id) async {
    final r = request(id) ?? (throw const AppFailure('요청을 찾을 수 없어요.'));
    final me = session.current!;
    if (r.s('retailerId') != me.id) {
      throw const AppFailure('본인의 요청만 다시 작성할 수 있어요.');
    }
    final next = newId();
    await saveDraft(next, {
      ..._fields(r.data),
      'address': me.s('address'),
      'addressDetail': me.s('addressDetail'),
      'note': me.s('deliveryNote'),
      if (!partners.any((p) => p.id == r.s('uncleId'))) 'uncleId': '',
    });
    return next;
  }

  @override
  Future<String> sendDraft(String id, String operationId) async {
    final user = actor;
    return store.write(user, operationId, (s) {
      if (s.tables['requests']!.containsKey(id)) {
        _role(s.require('requests', id), user, 'retailer');
        return id;
      }
      final draft = _savedDestination(s, s.require('drafts', id), user);
      if (textOf(draft, 'ownerId') != user) {
        throw const AppFailure('본인의 초안만 전송할 수 있어요.');
      }
      _validateRequest(s, draft, user);
      final now = DateTime.now().toIso8601String();
      final r = {
        ..._fields(draft),
        'retailerId': user,
        'status': 'pending',
        'version': 0,
        'createdAt': now,
        'updatedAt': now,
        'acquired': 0,
        'delivered': 0,
        'received': 0,
        'cancelled': 0,
        'acquiredCancelled': 0,
      };
      s.put('requests', id, r);
      s.remove('drafts', id);
      _event(s, id, {}, r, user, '새 사입 요청을 보냈어요');
      return id;
    });
  }

  @override
  Future<void> updateRequest(
    String id,
    Data fields,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final r = _request(s, id, user, version);
      _role(r, user, 'retailer');
      if (textOf(r, 'status') != 'pending') {
        throw const AppFailure('수락한 요청은 변경 협의로 수정해 주세요.');
      }
      final next = _savedDestination(s, {
        ...r,
        ..._fields(fields),
        'uncleId': r['uncleId'],
      }, user);
      _validateRequest(s, next, user);
      _putRequest(s, id, r, next, user, '수락 전 요청 내용을 수정했어요');
      return id;
    });
  }

  @override
  Future<void> act(
    String id,
    String action,
    Data values,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final r = _request(s, id, user, version), next = {...r};
      _active(r);
      switch (action) {
        case 'accept':
        case 'reject':
          _role(r, user, 'uncle');
          if (textOf(r, 'status') != 'pending') {
            throw const AppFailure('최신 요청의 접수 상태를 확인해 주세요.');
          }
          if (action == 'reject' && textOf(values, 'reason').trim().isEmpty) {
            throw const AppFailure('거절 사유를 입력해 주세요.');
          }
          next['status'] = action == 'accept' ? 'accepted' : 'rejected';
        case 'cancel':
          _role(r, user, 'retailer');
          if (textOf(r, 'status') != 'pending') {
            throw const AppFailure('수락 후에는 취소 협의를 진행해 주세요.');
          }
          next.addAll({
            'cancelled': numberOf(r, 'quantity'),
            'status': 'cancelled',
          });
        case 'result':
          _role(r, user, 'uncle');
          _accepted(r);
          _unheld(r);
          final acquired = numberOf(values, 'acquired');
          final left =
              numberOf(r, 'quantity') -
              numberOf(r, 'cancelled') -
              acquired +
              numberOf(r, 'acquiredCancelled');
          if (acquired < numberOf(r, 'acquired')) {
            throw const AppFailure('누적 확보 수량을 줄이려면 오류 정정을 이용해 주세요.');
          }
          if (left < 0 || numberOf(values, 'backorder') != left) {
            throw const AppFailure('요청 잔량과 확보·미송 수량이 맞지 않아요.');
          }
          if (left > 0 &&
              (DateTime.tryParse(textOf(values, 'recheck')) == null ||
                  textOf(values, 'reason').trim().isEmpty)) {
            throw const AppFailure('미송 재확인일과 설명을 입력해 주세요.');
          }
          next.addAll({
            'acquired': acquired,
            'resultShared': true,
            'recheck': left > 0 ? values['recheck'] : '',
            'needsReply': left > 0 && flagOf(values, 'needsReply'),
          });
        case 'wait':
          _role(r, user, 'retailer');
          _accepted(r);
          if (!flagOf(r, 'needsReply')) {
            throw const AppFailure('현재 답변할 미송이 없어요.');
          }
          next['needsReply'] = false;
        default:
          throw const AppFailure('지원하지 않는 처리예요.');
      }
      final title = switch (action) {
        'accept' => '요청을 수락했어요',
        'reject' => '요청을 거절했어요',
        'cancel' => '수락 전 요청을 취소했어요',
        'result' =>
          '확보 ${numberOf(next, 'acquired')}개 · 미송 ${RequestRecord(id, next).backorder}개 결과를 공유했어요',
        _ => '미송을 기다리기로 했어요',
      };
      _putRequest(
        s,
        id,
        r,
        next,
        user,
        '$title${textOf(values, 'reason').isEmpty ? '' : '\n${textOf(values, 'reason')}'}',
      );
      return id;
    });
  }

  @override
  Future<void> deliver(
    Map<String, int> quantities,
    Map<String, int> versions,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      if (quantities.isEmpty) throw const AppFailure('전달할 요청과 수량을 선택해 주세요.');
      String? group;
      for (final entry in quantities.entries) {
        if (!versions.containsKey(entry.key)) {
          throw const AppFailure('최신 전달 수량을 다시 확인해 주세요.');
        }
        final r = _request(s, entry.key, user, versions[entry.key]);
        _role(r, user, 'uncle');
        _accepted(r);
        final destination =
            '${textOf(r, 'retailerId')}|${textOf(r, 'address')}|${textOf(r, 'addressDetail')}';
        group ??= destination;
        if (group != destination) {
          throw const AppFailure('배송지가 다른 요청은 따로 전달 기록을 남겨 주세요.');
        }
        if (entry.value <= 0 ||
            entry.value > RequestRecord(entry.key, r).available) {
          throw const AppFailure('전달 가능한 수량을 넘을 수 없어요.');
        }
        final id = newId();
        s.put('deliveries', id, {
          'requestId': entry.key,
          'quantity': entry.value,
          'received': 0,
          'receiptRecorded': false,
          'product': r['product'],
          'option': r['option'],
          if (r.containsKey('requestType')) 'requestType': r['requestType'],
          if (r.containsKey('wholesalers')) 'wholesalers': r['wholesalers'],
          'wholesaler': r['wholesaler'],
          'location': r['location'],
          'address': r['address'],
          'addressDetail': r['addressDetail'],
          'retailerId': r['retailerId'],
          'uncleId': user,
          'createdAt': DateTime.now().toIso8601String(),
          'version': 0,
        });
        _putRequest(
          s,
          entry.key,
          r,
          {...r, 'delivered': numberOf(r, 'delivered') + entry.value},
          user,
          '${entry.value}개 전달을 기록했어요',
          kind: 'delivery',
          target: id,
        );
      }
      return operationId;
    });
  }

  @override
  Future<void> receive(
    String deliveryId,
    int actual,
    String reason,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final d = s.require('deliveries', deliveryId);
      _checkVersion(d, version);
      final id = textOf(d, 'requestId'), r = _request(s, id, user);
      _role(r, user, 'retailer');
      if (textOf(r, 'proposalId').isNotEmpty) {
        throw const AppFailure('진행 중인 변경·정정을 먼저 확인해 주세요.');
      }
      if (flagOf(d, 'receiptRecorded')) {
        throw const AppFailure('이미 확인한 전달분이에요. 차이는 문제 알리기를 이용해 주세요.');
      }
      if (actual < 0) throw const AppFailure('실제 수량은 0개 이상이어야 해요.');
      final mismatch = actual != numberOf(d, 'quantity');
      if (mismatch && reason.trim().isEmpty) {
        throw const AppFailure('수량 차이의 상황을 입력해 주세요.');
      }
      final confirmed = min(actual, numberOf(d, 'quantity'));
      s.put('receipts', newId(), {
        'requestId': id,
        'deliveryId': deliveryId,
        'actorId': user,
        'actual': actual,
        'confirmed': confirmed,
        'reason': reason,
        'deliveryVersion': version,
        'kind': 'confirmation',
        'createdAt': DateTime.now().toIso8601String(),
      });
      s.put('deliveries', deliveryId, {
        ...d,
        'received': confirmed,
        'actual': actual,
        'receiptRecorded': true,
        'version': version + 1,
      });
      final next = {...r, 'received': numberOf(r, 'received') + confirmed};
      if (mismatch) {
        _addIssue(s, id, next, user, {
          'reason': reason,
          'actual': actual,
          'deliveryId': deliveryId,
          'held': 0,
        });
      }
      _putRequest(
        s,
        id,
        r,
        next,
        user,
        mismatch
            ? '수령 수량 차이를 알렸어요: 실제 $actual개 · 기록 ${numberOf(d, 'quantity')}개'
            : '$actual개 수령을 확인했어요',
        kind: 'delivery',
        target: deliveryId,
      );
      return deliveryId;
    });
  }

  @override
  Future<void> propose(
    String requestId,
    String kind,
    Data values,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final r = _request(s, requestId, user, version);
      _unheld(r);
      if (kind != 'correction') _accepted(r);
      if (!['change', 'cancel', 'correction'].contains(kind)) {
        throw const AppFailure('지원하지 않는 변경이에요.');
      }
      if (textOf(values, 'reason').trim().isEmpty) {
        throw const AppFailure('변경 사유와 협의할 처리 방법을 입력해 주세요.');
      }
      if (kind == 'correction') {
        _role(r, user, 'uncle');
        if ([
          'pending',
          'cancelled',
          'rejected',
        ].contains(textOf(r, 'status'))) {
          throw const AppFailure('확보 후 수량을 정정해 주세요.');
        }
        if (textOf(values, 'deliveryId').isNotEmpty) {
          final d = s.require('deliveries', textOf(values, 'deliveryId'));
          if (textOf(d, 'requestId') != requestId) {
            throw const AppFailure('이 요청의 전달 기록이 아니에요.');
          }
        }
        if (numberOf(values, 'quantity') < 0 ||
            numberOf(values, 'acquired') < 0 ||
            numberOf(values, 'received') < 0) {
          throw const AppFailure('정정 수량을 확인해 주세요.');
        }
        final candidate = {...r, 'acquired': numberOf(values, 'acquired')};
        final deliveryId = textOf(values, 'deliveryId');
        if (deliveryId.isNotEmpty) {
          final d = s.require('deliveries', deliveryId);
          if (numberOf(values, 'received') > numberOf(values, 'quantity')) {
            throw const AppFailure('수령 수량은 전달 수량보다 클 수 없어요.');
          }
          candidate['delivered'] =
              numberOf(r, 'delivered') -
              numberOf(d, 'quantity') +
              numberOf(values, 'quantity');
          candidate['received'] =
              numberOf(r, 'received') -
              numberOf(d, 'received') +
              numberOf(values, 'received');
        }
        _finish(candidate);
        if (RequestRecord(requestId, candidate).remaining > 0 &&
            DateTime.tryParse(
                  textOf(values, 'recheck', textOf(r, 'recheck')),
                ) ==
                null) {
          throw const AppFailure('정정 후 남은 미송의 재확인일을 입력해 주세요.');
        }
      } else if (kind == 'cancel') {
        final qty = numberOf(values, 'quantity'),
            picked = numberOf(values, 'acquiredCancelled');
        final q = RequestRecord(requestId, r);
        if (qty <= 0 ||
            qty > q.quantity - q.cancelled - q.delivered ||
            picked < 0 ||
            picked > qty ||
            picked > q.available ||
            qty - picked > q.remaining) {
          throw const AppFailure('취소 수량과 그중 확보한 수량을 다시 확인해 주세요.');
        }
      } else {
        final candidate = {...r, ..._fields(values), 'uncleId': r['uncleId']};
        _validateRequest(s, candidate, textOf(r, 'retailerId'));
        _finish(candidate);
      }
      final q = RequestRecord(requestId, r);
      final held = kind == 'cancel'
          ? numberOf(values, 'acquiredCancelled')
          : q.available;
      final id = newId();
      s.put('proposals', id, {
        'requestId': requestId,
        'kind': kind,
        'values': values,
        'proposerId': user,
        'status': 'pending',
        'held': held,
        'version': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      final next = {...r, 'proposalId': id, 'held': numberOf(r, 'held') + held};
      _putRequest(
        s,
        requestId,
        r,
        next,
        user,
        kind == 'cancel'
            ? '취소 협의를 요청했어요'
            : kind == 'correction'
            ? '수량 정정을 요청했어요'
            : '요청 변경안을 보냈어요',
      );
      return id;
    });
  }

  @override
  Future<void> respondProposal(
    String proposalId,
    bool approve,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final p = s.require('proposals', proposalId);
      _checkVersion(p, version);
      final id = textOf(p, 'requestId'), r = _request(s, id, user);
      if (textOf(p, 'status') != 'pending' ||
          textOf(r, 'proposalId') != proposalId) {
        throw const AppFailure('이미 처리한 변경안이에요.');
      }
      if (textOf(p, 'proposerId') == user && approve) {
        throw const AppFailure('상대방이 확인해야 확정할 수 있어요.');
      }
      final next = {
        ...r,
        'proposalId': '',
        'held': max(0, numberOf(r, 'held') - numberOf(p, 'held')),
      };
      final values = mapOf(p, 'values');
      if (approve) {
        switch (textOf(p, 'kind')) {
          case 'cancel':
            next['cancelled'] =
                numberOf(r, 'cancelled') + numberOf(values, 'quantity');
            next['acquiredCancelled'] =
                numberOf(r, 'acquiredCancelled') +
                numberOf(values, 'acquiredCancelled');
            if (RequestRecord(id, next).remaining == 0) {
              next['needsReply'] = false;
              next['recheck'] = '';
            }
          case 'change':
            next.addAll(_fields(values));
            next['uncleId'] = r['uncleId'];
            _validateRequest(s, next, textOf(r, 'retailerId'));
            if (RequestRecord(id, next).remaining > 0 &&
                flagOf(r, 'resultShared')) {
              next['needsReply'] = true;
            }
          case 'correction':
            final deliveryId = textOf(values, 'deliveryId');
            next['acquired'] = numberOf(values, 'acquired');
            final remaining = RequestRecord(id, next).remaining;
            next['needsReply'] = remaining > 0;
            next['recheck'] = remaining > 0
                ? textOf(values, 'recheck', textOf(r, 'recheck'))
                : '';
            if (deliveryId.isEmpty) break;
            final d = s.require('deliveries', deliveryId);
            final quantity = numberOf(values, 'quantity'),
                received = numberOf(values, 'received');
            if (received > quantity) {
              throw const AppFailure('수령 수량은 전달 수량보다 클 수 없어요.');
            }
            next['acquired'] = numberOf(values, 'acquired');
            next['delivered'] =
                numberOf(r, 'delivered') - numberOf(d, 'quantity') + quantity;
            next['received'] =
                numberOf(r, 'received') - numberOf(d, 'received') + received;
            final corrected = <String, Object?>{
              ...d,
              'quantity': quantity,
              'received': received,
              'actual': received,
              'receiptRecorded': received == quantity,
              'version': numberOf(d, 'version') + 1,
              'correctedAt': DateTime.now().toIso8601String(),
            };
            s.put('deliveries', deliveryId, corrected);
            s.put('receipts', newId(), {
              'requestId': id,
              'deliveryId': deliveryId,
              'actorId': user,
              'actual': received,
              'confirmed': received,
              'previousConfirmed': numberOf(d, 'received'),
              'reason': textOf(values, 'reason'),
              'proposalId': proposalId,
              'kind': 'correction',
              'createdAt': DateTime.now().toIso8601String(),
            });
            s.put('events', newId(), {
              'requestId': id,
              'actorId': user,
              'title': '전달 회차 정정: ${textOf(values, 'reason')}',
              'before': {...d},
              'after': {...corrected},
              'deliveryId': deliveryId,
              'createdAt': DateTime.now().toIso8601String(),
            });
        }
      }
      s.put('proposals', proposalId, {
        ...p,
        'status': approve
            ? 'approved'
            : textOf(p, 'proposerId') == user
            ? 'withdrawn'
            : 'rejected',
        'version': version + 1,
        'resolvedBy': user,
      });
      _putRequest(
        s,
        id,
        r,
        next,
        user,
        approve ? '협의한 변경·취소·정정을 확정했어요' : '변경·취소·정정안을 종료했어요',
      );
      return proposalId;
    });
  }

  void _addIssue(
    MutableWorkspace s,
    String id,
    Data next,
    String user,
    Data values,
  ) {
    final held = numberOf(values, 'held');
    if (held < 0 || held > RequestRecord(id, next).available) {
      throw const AppFailure('보류할 확보 수량을 확인해 주세요.');
    }
    s.put('issues', newId(), {
      'requestId': id,
      ...values,
      'reporterId': user,
      'status': 'open',
      'version': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    next['openIssues'] = numberOf(next, 'openIssues') + 1;
    next['held'] = numberOf(next, 'held') + held;
  }

  @override
  Future<void> reportIssue(
    String requestId,
    Data values,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final r = _request(s, requestId, user, version);
      _role(r, user, 'retailer');
      if (['pending', 'cancelled', 'rejected'].contains(textOf(r, 'status'))) {
        throw const AppFailure('진행 중이거나 수령한 요청에서 문제를 알려 주세요.');
      }
      if (textOf(values, 'reason').trim().isEmpty) {
        throw const AppFailure('문제 상황을 입력해 주세요.');
      }
      final deliveryId = textOf(values, 'deliveryId');
      if (deliveryId.isNotEmpty &&
          textOf(s.require('deliveries', deliveryId), 'requestId') !=
              requestId) {
        throw const AppFailure('이 요청의 전달 회차를 선택해 주세요.');
      }
      final next = {...r};
      _addIssue(s, requestId, next, user, values);
      _putRequest(
        s,
        requestId,
        r,
        next,
        user,
        '상품 문제를 알렸어요: ${textOf(values, 'reason')}',
        kind: deliveryId.isEmpty ? 'request' : 'delivery',
        target: deliveryId,
      );
      return requestId;
    });
  }

  @override
  Future<void> actOnIssue(
    String id,
    String action,
    String note,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final issue = s.require('issues', id);
      _checkVersion(issue, version);
      final requestId = textOf(issue, 'requestId'),
          r = _request(s, requestId, user),
          next = {...r};
      if (textOf(issue, 'status') == 'resolved') {
        throw const AppFailure('이미 해결한 문제예요.');
      }
      final update = {...issue, 'version': version + 1};
      if (action == 'resolve') {
        _role(r, user, 'retailer');
        final deliveryId = textOf(issue, 'deliveryId');
        if (deliveryId.isNotEmpty && issue.containsKey('actual')) {
          final d = s.require('deliveries', deliveryId);
          if (numberOf(d, 'actual') != numberOf(d, 'quantity')) {
            throw const AppFailure('전달 기록과 실제 수량 차이를 먼저 정정해 주세요.');
          }
        }
        update['status'] = 'resolved';
        next['openIssues'] = numberOf(r, 'openIssues') - 1;
        next['held'] = max(0, numberOf(r, 'held') - numberOf(issue, 'held'));
      } else if (action == 'action') {
        _role(r, user, 'uncle');
        if (note.trim().isEmpty) throw const AppFailure('조치 내용을 입력해 주세요.');
        update.addAll({'status': 'actionTaken', 'action': note});
      } else {
        throw const AppFailure('지원하지 않는 문제 처리예요.');
      }
      s.put('issues', id, update);
      _putRequest(
        s,
        requestId,
        r,
        next,
        user,
        action == 'resolve' ? '소매업자가 문제 해결을 확인했어요' : '문제 조치를 기록했어요: $note',
      );
      return id;
    });
  }

  @override
  Future<void> sendMessage(
    String peerId,
    String messageId,
    String body,
    List<String> attachments, {
    String requestId = '',
  }) async {
    final user = actor;
    ChatContentPolicy.validate(body, attachments);
    bool validated = false;
    try {
      await store.write(user, messageId, (s) {
        _connected(s, user, peerId);
        final existing = s.tables['messages']![messageId];
        if (existing != null &&
            (textOf(existing, 'senderId') != user ||
                textOf(existing, 'recipientId') != peerId)) {
          throw const AppFailure('본인이 작성한 메시지만 다시 보낼 수 있어요.');
        }
        if (existing != null &&
            (flagOf(existing, 'deleted') ||
                flagOf(existing, 'system') ||
                textOf(existing, 'status') != 'failed')) {
          throw const AppFailure('이미 보낸 메시지는 다시 보낼 수 없어요.');
        }
        if (requestId.isNotEmpty) {
          final r = _request(s, requestId, user);
          if (_other(r, user) != peerId) {
            throw const AppFailure('대화 상대방의 요청을 선택해 주세요.');
          }
        }
        for (final id in attachments) {
          if (textOf(s.require('attachments', id), 'ownerId') != user) {
            throw const AppFailure('본인의 사진만 보낼 수 있어요.');
          }
        }
        validated = true;
        s.put('messages', messageId, {
          'senderId': user,
          'recipientId': peerId,
          'body': body.trim(),
          'attachments': attachments,
          'requestId': requestId,
          'status': 'sent',
          'system': false,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
        _notice(
          s,
          peerId,
          body.trim().isEmpty ? '사진을 보냈어요' : body.trim(),
          'chat',
          user,
        );
        return messageId;
      });
    } catch (error) {
      if (validated) {
        // A failed outbox item belongs only to its sender and emits no notice.
        // If storage itself remains unavailable, the composer retains the input.
        try {
          await store.write(user, '', (s) {
            if (textOf(s.tables['messages']![messageId] ?? {}, 'status') ==
                'sent') {
              return messageId;
            }
            s.put('messages', messageId, {
              'senderId': user,
              'recipientId': peerId,
              'body': body.trim(),
              'attachments': attachments,
              'requestId': requestId,
              'status': 'failed',
              'error': error.toString(),
              'read': false,
              'createdAt': DateTime.now().toIso8601String(),
            });
            return messageId;
          });
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> editMessage(
    String messageId,
    String body,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final message = _editableMessage(s, messageId, user, version);
      final text = body.trim();
      ChatContentPolicy.validate(text, stringsOf(message, 'attachments'));
      s.put('messages', messageId, {
        ...message,
        'body': text,
        'editedAt': DateTime.now().toIso8601String(),
        'version': version + 1,
      });
      return messageId;
    });
  }

  @override
  Future<void> deleteMessage(
    String messageId,
    int version,
    String operationId,
  ) async {
    final user = actor;
    await store.write(user, operationId, (s) {
      final message = _editableMessage(s, messageId, user, version);
      s.put('messages', messageId, {
        ...message,
        'body': '',
        'attachments': <String>[],
        'requestId': '',
        'deleted': true,
        'deletedAt': DateTime.now().toIso8601String(),
        'version': version + 1,
      });
      return messageId;
    });
  }

  Data _editableMessage(
    MutableWorkspace s,
    String id,
    String user,
    int version,
  ) {
    final message = s.require('messages', id);
    if (textOf(message, 'senderId') != user) {
      throw const AppFailure('본인이 보낸 메시지만 수정하거나 삭제할 수 있어요.');
    }
    if (flagOf(message, 'deleted')) {
      throw const AppFailure('이미 삭제된 메시지는 변경할 수 없어요.');
    }
    if (flagOf(message, 'system') || textOf(message, 'status') != 'sent') {
      throw const AppFailure('전송된 일반 메시지만 수정하거나 삭제할 수 있어요.');
    }
    _checkVersion(message, version);
    return message;
  }

  @override
  Future<void> markChatRead(String peerId) async {
    final user = actor;
    await store.write(user, '', (s) {
      for (final entry in s.all('messages').toList()) {
        final r = entry.value;
        if (textOf(r, 'recipientId') == user &&
            textOf(r, 'senderId') == peerId &&
            textOf(r, 'status') == 'sent' &&
            !flagOf(r, 'read')) {
          s.put('messages', entry.key, {...r, 'read': true});
        }
      }
      return '';
    });
  }

  @override
  Future<void> readNotice(String id) async {
    final user = actor;
    await store.write(user, '', (s) {
      final r = s.require('notices', id);
      if (textOf(r, 'ownerId') != user) {
        throw const AppFailure('이 알림을 볼 수 없어요.');
      }
      s.put('notices', id, {...r, 'read': true});
      return id;
    });
  }

  @override
  Future<void> refreshReminders() async {
    if (session.current?.role != AppRole.uncle) return;
    final user = actor, today = dateOnly(DateTime.now());
    await store.write(user, '', (s) {
      for (final entry in s.all('requests')) {
        final r = RequestRecord(entry.key, entry.value);
        final id = 'recheck-${entry.key}-${r.s('recheck')}';
        if (r.s('uncleId') == user &&
            r.overdue &&
            !r.ended &&
            !s.tables['notices']!.containsKey(id)) {
          s.put('notices', id, {
            'ownerId': user,
            'title': '미송을 재확인해 주세요',
            'kind': 'request',
            'targetId': entry.key,
            'requestId': entry.key,
            'read': false,
            'createdAt': '${today}T00:00:00',
          });
        }
      }
      return '';
    });
  }

  @override
  void dispose() {
    store.removeListener(notifyListeners);
    super.dispose();
  }
}
