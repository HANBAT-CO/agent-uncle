import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/domain/models.dart';
import '../local/domain/workflow_payload.dart';

/// A server snapshot is authoritative. Sembast stores only device preferences
/// and the authenticated user's failed outbox, never shared workspace state.
class RemoteStore extends ChangeNotifier with WidgetsBindingObserver {
  RemoteStore(this.client, this.device, {this.liveUpdates = true}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final SupabaseClient client;
  final Database device;
  final bool liveUpdates;
  WorkspaceSnapshot snapshot = const WorkspaceSnapshot({});
  final preferences = stringMapStoreFactory.store('remotePreferences');
  final outbox = stringMapStoreFactory.store('remoteOutbox');
  final workflowOutbox = stringMapStoreFactory.store('workflowOutbox');
  final workflowInputs = stringMapStoreFactory.store('workflowInputs');
  Map<String, Data> _pendingWorkflows = {};
  Map<String, Data> _savedWorkflowInputs = {};
  final Map<String, Future<String>> _workflowInFlight = {};
  final Set<String> _deletedAccounts = {};
  List<Record> get pendingWorkflows => [
    for (final entry in _pendingWorkflows.entries)
      if (textOf(entry.value, 'ownerId') == userId)
        Record(entry.key, entry.value),
  ];

  Data workflowInput(String key) => Map<String, Object?>.from(
    _savedWorkflowInputs['$userId:$key'] ?? const {},
  );

  Future<void> discardRejectedWorkflow(String operationId) async {
    final id = userId;
    if (id == null) throw const AppFailure('로그인이 필요해요.');
    final key = '$id:$operationId';
    final editableInputs = <String, Data>{};
    await device.transaction((txn) async {
      final record = await workflowOutbox.record(key).get(txn);
      if (record == null) return;
      if (textOf(record, 'status') != 'rejected' ||
          _workflowInFlight.containsKey(key)) {
        throw const AppFailure('결과를 확인 중인 작업은 지울 수 없어요. 같은 작업으로 다시 확인해 주세요.');
      }
      await workflowOutbox.record(key).delete(txn);
      final inputs = await workflowInputs.find(
        txn,
        finder: Finder(filter: Filter.equals('ownerId', id)),
      );
      for (final input in inputs) {
        final values = mapOf(input.value, 'values');
        if (textOf(values, 'operationId') != operationId) continue;
        final editable = {...values, 'submitted': <String, Object?>{}};
        await workflowInputs.record(input.key).put(txn, {
          ...input.value,
          'values': editable,
        });
        editableInputs[input.key] = editable;
      }
    });
    if (id == userId && !_closed && !_deletedAccounts.contains(id)) {
      _pendingWorkflows.remove(key);
      _savedWorkflowInputs.addAll(editableInputs);
      notifyListeners();
    }
  }

  Future<void> saveWorkflowInput(String key, Data values) async {
    final id = userId;
    if (id == null || _deletedAccounts.contains(id) || _closed) {
      throw const AppFailure('로그인이 필요해요.');
    }
    final copy = Map<String, Object?>.from(jsonDecode(jsonEncode(values)) as Map);
    await device.transaction((txn) async {
      if (_deletedAccounts.contains(id)) return;
      await workflowInputs.record('$id:$key').put(txn, {
        'ownerId': id,
        'values': copy,
      });
    });
    if (id == userId && !_closed && !_deletedAccounts.contains(id)) {
      _savedWorkflowInputs['$id:$key'] = copy;
      notifyListeners();
    }
  }

  Future<void> _readWorkflowDeviceState(String id, int generation) async {
    final pending = await workflowOutbox.find(
      device, finder: Finder(filter: Filter.equals('ownerId', id)),
    );
    final inputs = await workflowInputs.find(
      device, finder: Finder(filter: Filter.equals('ownerId', id)),
    );
    if (id != userId || generation != _generation || _closed) return;
    _pendingWorkflows = {for (final row in pending) row.key: row.value};
    _savedWorkflowInputs = {
      for (final row in inputs)
        row.key: Map<String, Object?>.from(row.value['values'] as Map? ?? {}),
    };
    notifyListeners();
  }

  /// 공유 상태는 서버 응답 이후에만 갱신하고, 불확실한 쓰기는 같은 번호로 재시도한다.
  Future<String> workflow(String name, Data args, String operationId) async {
    final id = userId;
    if (id == null || _deletedAccounts.contains(id) || _closed) {
      throw const AppFailure('로그인이 필요해요.');
    }
    if (!name.startsWith('wf.') || operationId.isEmpty || operationId.length > 200) {
      throw const AppFailure('작업 정보를 확인해 주세요.');
    }
    final copy = Map<String, Object?>.from(jsonDecode(jsonEncode(args)) as Map);
    final payload = workflowPayload(name, copy);
    final key = '$id:$operationId';
    final generation = _generation;
    final saved = await device.transaction((txn) async {
      if (_deletedAccounts.contains(id)) {
        throw const AppFailure('탈퇴한 계정의 작업은 보낼 수 없어요.');
      }
      final previous = await workflowOutbox.record(key).get(txn);
      if (previous != null && textOf(previous, 'payload') != payload) {
        throw const AppFailure('같은 작업 번호로 다른 내용을 전송할 수 없어요.');
      }
      final record = previous ?? <String, Object?>{
        'ownerId': id,
        'operationId': operationId,
        'command': name,
        'args': copy,
        'payload': payload,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };
      await workflowOutbox.record(key).put(txn, record);
      return record;
    });
    if (id != userId || generation != _generation || _closed || _deletedAccounts.contains(id)) {
      throw const AppFailure('계정이 변경되어 입력만 저장했어요. 해당 계정에서 다시 확인해 주세요.');
    }
    _pendingWorkflows[key] = saved;
    notifyListeners();
    final running = _workflowInFlight[key];
    if (running != null) return running;
    final future = _sendWorkflow(key, saved, generation);
    _workflowInFlight[key] = future;
    try {
      return await future;
    } finally {
      _workflowInFlight.remove(key);
    }
  }

  Future<String> _sendWorkflow(String key, Data saved, int generation) async {
    final id = textOf(saved, 'ownerId');
    if (id != userId || generation != _generation || _closed || _deletedAccounts.contains(id)) {
      throw const AppFailure('해당 계정으로 로그인한 뒤 다시 확인해 주세요.');
    }
    try {
      final result = await client.rpc('saip_command', params: {
        'command': saved['command'],
        'args': saved['args'],
        'operation_id': saved['operationId'],
      }) as String;
      await workflowOutbox.record(key).delete(device);
      if (id == userId && generation == _generation && !_closed) {
        _pendingWorkflows.remove(key);
        notifyListeners();
        await refresh().catchError((Object _) {});
      }
      return result;
    } catch (e) {
      final rejected = e is PostgrestException && e.code == 'P0001';
      final next = {
        ...saved,
        'status': rejected ? 'rejected' : 'pending',
        'error': friendlyError(e),
      };
      await device.transaction((txn) async {
        if (!_deletedAccounts.contains(id)) {
          await workflowOutbox.record(key).put(txn, next);
        }
      });
      if (id == userId && generation == _generation && !_closed && !_deletedAccounts.contains(id)) {
        _pendingWorkflows[key] = next;
        notifyListeners();
      }
      throw AppFailure(rejected ? friendlyError(e) : '동기화 대기 중이에요. 입력은 보존했으며 서버 확인 후 반영돼요.');
    }
  }
  Data settings = {};
  String? error;
  bool loading = false;
  bool _closed = false;
  int _generation = 0;
  int _refreshSequence = 0;
  RealtimeChannel? _channel;
  Timer? _poll;
  Timer? _debounce;
  String? get userId => client.auth.currentUser?.id;
  String? _loadedUser;
  Future<void>? _changingUser;
  String? _changingUserId;

  Future<void> initialize() async {
    settings = await preferences.record('device').get(device) ?? {};
  }

  Future<void> setSetting(String key, Object? value) async {
    final next = {...settings, key: value};
    await preferences.record('device').put(device, next);
    settings = next;
    notifyListeners();
  }

  Future<void> clearDeletedAccount(String id) async {
    _deletedAccounts.add(id);
    _pendingWorkflows.removeWhere((_, data) => textOf(data, 'ownerId') == id);
    _savedWorkflowInputs.removeWhere((key, _) => key.startsWith('$id:'));
    Data? nextSettings;
    await device.transaction((txn) async {
      await outbox.delete(
        txn,
        finder: Finder(filter: Filter.equals('senderId', id)),
      );
      for (final table in [workflowOutbox, workflowInputs]) {
        await table.delete(txn, finder: Finder(filter: Filter.equals('ownerId', id)));
      }
      if (userId == id) {
        nextSettings = {...settings}
          ..remove('destination')
          ..remove('roleOnboarding:$id');
        await preferences.record('device').put(txn, nextSettings!);
      }
    });
    if (nextSettings != null) settings = nextSettings!;
  }

  Future<void> changeUser() {
    final id = userId;
    final running = _changingUser;
    if (running != null && _changingUserId == id) return running;
    _changingUserId = id;
    late final Future<void> pending;
    pending = _loadUser().whenComplete(() {
      if (identical(_changingUser, pending)) _changingUser = null;
    });
    _changingUser = pending;
    return pending;
  }

  Future<void> _loadUser() async {
    final generation = ++_generation;
    final id = userId;
    _loadedUser = id;
    snapshot = const WorkspaceSnapshot({});
    _pendingWorkflows = {};
    _savedWorkflowInputs = {};
    error = null;
    loading = id != null;
    _poll?.cancel();
    _debounce?.cancel();
    final old = _channel;
    _channel = null;
    if (old != null) unawaited(client.removeChannel(old));
    notifyListeners();
    if (id == null) return;
    try {
      await _readWorkflowDeviceState(id, generation);
      if (generation != _generation || _closed) return;
      await client.rpc(
        'saip_command',
        params: {
          'command': 'bootstrap',
          'args': <String, Object?>{},
          'operation_id': 'bootstrap-$id',
        },
      );
      if (generation != _generation || _closed) return;
      await refresh();
      if (generation != _generation || _closed || !liveUpdates) return;
      _channel = client
          .channel('workspace-$id-$generation')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'saip_records',
            callback: (_) => scheduleRefresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'saip_records',
            callback: (_) => scheduleRefresh(),
          )
          .subscribe((status, e) {
            if (status == RealtimeSubscribeStatus.subscribed) scheduleRefresh();
          });
      // Polling covers reconnects, partner profile changes and delete events.
      _poll = Timer.periodic(
        const Duration(seconds: 20),
        (_) => scheduleRefresh(),
      );
    } catch (e) {
      if (generation == _generation && !_closed) {
        error = friendlyError(e);
        loading = false;
        notifyListeners();
      }
    }
  }

  void scheduleRefresh() {
    if (_closed || userId == null) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(refresh().catchError((Object _) {})),
    );
  }

  Future<void> refresh() async {
    final id = userId, generation = _generation, sequence = ++_refreshSequence;
    if (id == null || id != _loadedUser) return;
    try {
      final data = await client.rpc('saip_snapshot');
      final tables = <String, Map<String, Data>>{
        for (final e in (data as Map).entries)
          e.key as String: {
            for (final row in (e.value as Map).entries)
              row.key as String: Map<String, Object?>.from(row.value as Map),
          },
      };
      final pending = await outbox.find(
        device,
        finder: Finder(filter: Filter.equals('senderId', id)),
      );
      for (final record in pending) {
        if (!(tables['messages'] ?? {}).containsKey(record.key)) {
          (tables['messages'] ??= {})[record.key] = record.value;
        } else {
          await outbox.record(record.key).delete(device);
        }
      }
      if (generation != _generation ||
          sequence != _refreshSequence ||
          _closed ||
          id != userId) {
        return;
      }
      snapshot = WorkspaceSnapshot(tables);
      error = null;
      loading = false;
      notifyListeners();
    } catch (e) {
      if (generation == _generation &&
          sequence == _refreshSequence &&
          !_closed) {
        error = friendlyError(e);
        loading = false;
        notifyListeners();
      }
      throw AppFailure(friendlyError(e));
    }
  }

  Future<String> command(String name, Data args, [String? operation]) async {
    final id = userId;
    if (id == null) throw const AppFailure('로그인이 필요해요.');
    try {
      final result =
          await client.rpc(
                'saip_command',
                params: {
                  'command': name,
                  'args': args,
                  'operation_id': operation ?? newId(),
                },
              )
              as String;
      // A committed command stays successful even if the follow-up read fails.
      // Realtime/polling retries the read without repeating the mutation.
      if (id == userId) await refresh().catchError((Object _) {});
      return result;
    } catch (e) {
      if (e is PostgrestException && e.code == 'P0001') scheduleRefresh();
      throw AppFailure(friendlyError(e));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) scheduleRefresh();
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _debounce?.cancel();
    if (_channel != null) unawaited(client.removeChannel(_channel!));
    super.dispose();
  }
}

const _networkErrorMessage = '와이파이에 연결해주세요!';

String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is PostgrestException && error.code == 'P0001') {
    return error.message;
  }
  if (error is PostgrestException && error.code == 'PGRST202') {
    return '서버 준비가 아직 완료되지 않았어요. 잠시 후 다시 시도해 주세요.';
  }
  if (_isNetworkError(error)) return _networkErrorMessage;
  if (error is AuthException) return '인증을 완료하지 못했어요. 로그인 화면에서 다시 시도해 주세요.';
  if (error is StorageException) {
    return '첨부파일을 저장하거나 읽지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';
  }
  return _networkErrorMessage;
}

bool _isNetworkError(Object error) {
  if (error is TimeoutException) return true;
  if (error is AuthRetryableFetchException) return true;
  if (error is AuthUnknownException) {
    return _looksLikeNetworkText('${error.message} ${error.originalError}');
  }
  if (error is StorageException) {
    return error.statusCode == null ||
        _looksLikeNetworkText('${error.message} ${error.error ?? ''}');
  }
  if (error is PostgrestException && error.code == null) {
    return _looksLikeNetworkText(
      '${error.message} ${error.details ?? ''} ${error.hint ?? ''}',
    );
  }
  return _looksLikeNetworkText(error.toString());
}

bool _looksLikeNetworkText(String value) {
  final text = value.toLowerCase();
  const markers = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'temporary failure in name resolution',
    'connection refused',
    'connection reset',
    'connection closed',
    'network',
    'offline',
    'timeout',
    'timed out',
    'xmlhttprequest error',
    'fetch failed',
    'broken pipe',
    'host lookup',
    'no address associated with hostname',
  ];
  for (final marker in markers) {
    if (text.contains(marker)) return true;
  }
  return false;
}
