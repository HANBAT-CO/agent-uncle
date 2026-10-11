import 'package:sembast/sembast.dart';
import '../local/domain/models.dart';
import 'remote_store.dart';

class RemoteWorkspaceRepository extends WorkspaceRepository {
  RemoteWorkspaceRepository(this.store) {
    store.addListener(notifyListeners);
  }
  final RemoteStore store;
  final _codes = <String, String>{};
  @override
  WorkspaceSnapshot get snapshot => store.snapshot;
  @override
  List<Record> records(String table) {
    if (store.userId == null) return [];
    final rows = snapshot.all(table);
    rows.sort((a, b) => b.s('createdAt').compareTo(a.s('createdAt')));
    return rows;
  }

  @override
  List<Account> get partners {
    final ids = records('connections')
        .where((r) => r.s('status') == 'accepted')
        .map((r) => r.s('from') == store.userId ? r.s('to') : r.s('from'))
        .toSet();
    return snapshot.accounts.where((a) => ids.contains(a.id)).toList();
  }

  @override
  Account? profile(String id) {
    final row = snapshot.get('accounts', id);
    return row == null ? null : Account(row.id, row.data);
  }

  @override
  RequestRecord? request(String id) {
    final row = snapshot.get('requests', id);
    return row == null ? null : RequestRecord(row.id, row.data);
  }

  @override
  Future<Account> lookupCode(String code) async {
    try {
      final row =
          await store.client.rpc('saip_lookup_code', params: {'code': code})
              as Map;
      final account = Account(
        row['id'] as String,
        Map<String, Object?>.from(row['data'] as Map),
      );
      _codes[account.id] = code;
      return account;
    } catch (e) {
      throw AppFailure(friendlyError(e));
    }
  }

  @override
  Future<void> renewCode() async {
    await store.command('renewCode', {});
  }

  @override
  Future<String> connect(String peerId, String operationId) => store.command(
    'connect',
    {'peerId': peerId, 'code': _codes[peerId] ?? ''},
    operationId,
  );
  @override
  Future<void> respondConnection(
    String id,
    String status,
    int version,
    String operationId,
  ) async {
    await store.command('respondConnection', {
      'id': id,
      'status': status,
      'version': version,
    }, operationId);
  }

  @override
  Future<String> saveDraft(String id, Data fields) =>
      store.command('saveDraft', {'id': id, 'values': fields});
  @override
  Future<void> deleteDraft(String id) async {
    await store.command('deleteDraft', {'id': id});
  }

  @override
  Future<String> repeatRequest(String id) async {
    final r = request(id);
    if (r == null || r.s('retailerId') != store.userId) {
      throw const AppFailure('본인의 요청만 다시 작성할 수 있어요.');
    }
    final me = profile(store.userId!)!;
    return saveDraft(newId(), {
      ...r.data,
      'address': me.s('address'),
      'addressDetail': me.s('addressDetail'),
      'note': me.s('deliveryNote'),
      if (!partners.any((p) => p.id == r.s('uncleId'))) 'uncleId': '',
    });
  }

  @override
  Future<String> sendDraft(String id, String operationId) =>
      store.command('sendDraft', {'id': id}, operationId);
  @override
  Future<void> updateRequest(
    String id,
    Data fields,
    int version,
    String operationId,
  ) async {
    await store.command('updateRequest', {
      'id': id,
      'values': fields,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> act(
    String id,
    String action,
    Data values,
    int version,
    String operationId,
  ) async {
    await store.command('act', {
      'id': id,
      'action': action,
      'values': values,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> deliver(
    Map<String, int> quantities,
    Map<String, int> versions,
    String operationId,
  ) async {
    await store.command('deliver', {
      'quantities': quantities,
      'versions': versions,
    }, operationId);
  }

  @override
  Future<void> receive(
    String deliveryId,
    int actual,
    String reason,
    int version,
    String operationId,
  ) async {
    await store.command('receive', {
      'id': deliveryId,
      'actual': actual,
      'reason': reason,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> propose(
    String requestId,
    String kind,
    Data values,
    int version,
    String operationId,
  ) async {
    await store.command('propose', {
      'id': requestId,
      'kind': kind,
      'values': values,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> respondProposal(
    String proposalId,
    bool approve,
    int version,
    String operationId,
  ) async {
    await store.command('respondProposal', {
      'id': proposalId,
      'approve': approve,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> reportIssue(
    String requestId,
    Data values,
    int version,
    String operationId,
  ) async {
    await store.command('reportIssue', {
      'id': requestId,
      'values': values,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> actOnIssue(
    String id,
    String action,
    String note,
    int version,
    String operationId,
  ) async {
    await store.command('actOnIssue', {
      'id': id,
      'action': action,
      'note': note,
      'version': version,
    }, operationId);
  }

  @override
  Future<void> sendMessage(
    String peerId,
    String messageId,
    String body,
    List<String> attachments, {
    String requestId = '',
  }) async {
    final owner = store.userId;
    if (owner == null) throw const AppFailure('로그인이 필요해요.');
    final data = <String, Object?>{
      'senderId': owner,
      'recipientId': peerId,
      'body': body.trim(),
      'attachments': attachments,
      'requestId': requestId,
      'status': 'failed',
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    // Persist before network I/O so a crash or ambiguous timeout can be retried
    // with the original ID and content. The server deduplicates it atomically.
    await store.outbox.record(messageId).put(store.device, data);
    try {
      await store.command('sendMessage', {
        'id': messageId,
        'peerId': peerId,
        'body': body.trim(),
        'attachments': attachments,
        'requestId': requestId,
      }, messageId);
      await store.outbox.record(messageId).delete(store.device);
    } catch (e) {
      if (owner == store.userId) {
        final tables = {...store.snapshot.tables};
        tables['messages'] = {
          ...?tables['messages'],
          messageId: {...data, 'error': e.toString()},
        };
        store.snapshot = WorkspaceSnapshot(tables);
        notifyListeners();
      }
      rethrow;
    }
  }

  @override
  Future<void> markChatRead(String peerId) async {
    if (!records('messages').any(
      (m) =>
          m.s('senderId') == peerId &&
          m.s('recipientId') == store.userId &&
          !m.b('read'),
    )) {
      return;
    }
    await store.command('markChatRead', {'peerId': peerId});
  }

  @override
  Future<void> readNotice(String id) async {
    await store.command('readNotice', {'id': id});
  }

  @override
  Future<void> refreshReminders() async {
    await store.command('refreshReminders', {});
  }

  @override
  void dispose() {
    store.removeListener(notifyListeners);
    super.dispose();
  }
}
