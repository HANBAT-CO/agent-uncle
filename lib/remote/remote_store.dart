import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/domain/models.dart';

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

  Future<void> initialize() async {
    settings = await preferences.record('device').get(device) ?? {};
  }

  Future<void> setSetting(String key, Object? value) async {
    final next = {...settings, key: value};
    await preferences.record('device').put(device, next);
    settings = next;
    notifyListeners();
  }

  Future<void> changeUser() async {
    final generation = ++_generation;
    final id = userId;
    _loadedUser = id;
    snapshot = const WorkspaceSnapshot({});
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
