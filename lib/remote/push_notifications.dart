import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../core/config/supabase_config.dart';
import '../local/domain/models.dart';
import 'remote_session.dart';

/// OS 알림과 서버 기기 등록을 연결한다. 실제 데이터 접근은 기존 세션/RLS가 담당한다.
class PushNotifications extends ChangeNotifier with WidgetsBindingObserver {
  PushNotifications(this.session, {MethodChannel? channel})
    : channel = channel ?? const MethodChannel('agent_uncle/notifications');

  final RemoteSessionRepository session;
  final MethodChannel channel;
  Data state = {};
  String? error;
  bool _disposed = false, _busy = false, _again = false, _suspended = false;
  Completer<void>? _syncCompletion;
  String? _registered;
  Timer? _retry;
  bool get enabled => state['enabled'] == true;
  bool get configured => state['configured'] == true;
  bool get liveSupported => state['liveSupported'] == true;
  bool get liveEnabled => state['liveEnabled'] == true;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_changed);
    session.beforeSignOut = clear;
    session.afterSignOut = resumeAfterSignOut;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _changed();
    });
    _retry = Timer.periodic(const Duration(seconds: 30), (_) => _changed());
    _changed();
  }

  void _changed() {
    unawaited(sync());
  }

  Future<void> sync() async {
    if (_disposed || _suspended) return;
    if (_busy) {
      _again = true;
      return _syncCompletion!.future;
    }
    _busy = true;
    _syncCompletion = Completer<void>();
    try {
      do {
        _again = false;
        final account = session.current;
        final owner =
            account != null && account.complete && !account.b('deletionPending')
            ? account.id
            : '';
        final raw = await channel.invokeMapMethod<String, Object?>('bind', {
          'ownerId': owner,
          'url': SupabaseConfig.url,
          'key': SupabaseConfig.publishableKey,
        });
        if (_disposed || _suspended) return;
        final next = raw ?? <String, Object?>{};
        if (jsonEncode(next) != jsonEncode(state)) {
          state = next;
          notifyListeners();
        }
        if (owner.isEmpty) {
          _registered = null;
          return;
        }
        if (owner != session.current?.id) {
          _again = true;
          continue;
        }
        final signature = jsonEncode([
          owner,
          session.store.client.auth.currentSession?.accessToken,
          state,
        ]);
        if ((state['token'] as String? ?? '').isNotEmpty &&
            signature != _registered) {
          await session.store.client.rpc(
            'saip_register_push',
            params: {'device': state},
          );
          if (_disposed || _suspended || owner != session.current?.id) {
            await session.store.client.rpc(
              'saip_unregister_push',
              params: {'device_id': next['id'], 'binding_id': next['binding']},
            );
            return;
          }
          _registered = signature;
        }
        await channel.invokeMethod<void>('syncActivities');
        final tap = await channel.invokeMapMethod<String, Object?>('takeTap');
        if (_disposed || _suspended) return;
        if (tap != null &&
            tap['ownerId'] == owner &&
            tap['binding'] == state['binding'] &&
            owner == session.current?.id) {
          // 조회가 실패해도 목적지는 보관하고 다음 진입에서 다시 열 수 있게 한다.
          await session
              .retrySync()
              .timeout(const Duration(seconds: 8))
              .catchError((Object _) {});
          if (owner == session.current?.id && !_suspended) {
            await session.setDestination({...tap, 'fromPush': true});
          }
        }
        if (error != null) {
          error = null;
          notifyListeners();
        }
      } while (_again && !_disposed && !_suspended);
    } on MissingPluginException {
      // 웹/데스크톱/로컬 테스트에는 OS 알림 브리지가 없다.
    } catch (_) {
      if (!_disposed && error == null) {
        error = '알림 기기 등록을 다시 시도하고 있어요. 잠시 후에도 계속되면 앱을 다시 열어 주세요.';
        notifyListeners();
      }
    } finally {
      _busy = false;
      _syncCompletion!.complete();
      _syncCompletion = null;
    }
  }

  Future<void> requestPermission() async {
    await channel.invokeMethod<void>('requestPermission');
    await sync();
  }

  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
  Future<void> setLiveEnabled(bool value) async {
    await channel.invokeMethod<void>('setLiveEnabled', {'enabled': value});
    await sync();
  }

  Future<void> startActivity(String requestId) async {
    await setLiveEnabled(true);
    await session.store.client.rpc(
      'saip_prepare_activity',
      params: {
        'device_id': state['id'],
        'binding_id': state['binding'],
        'request_id': requestId,
      },
    );
    await channel.invokeMethod<void>('startActivity', {'requestId': requestId});
    await sync();
  }

  Future<void> clear() async {
    _suspended = true;
    final device = Map<String, Object?>.from(state);
    try {
      // OS 쪽 바인딩은 네트워크와 무관하게 즉시 폐기한다.
      await channel.invokeMethod<void>('clear');
      if (device['id'] != null && device['binding'] != null) {
        await session.store.client
            .rpc(
              'saip_unregister_push',
              params: {
                'device_id': device['id'],
                'binding_id': device['binding'],
              },
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // 오프라인 로그아웃을 막지 않는다. 서버에서도 auth.sessions를 다시 확인한다.
    } finally {
      _registered = null;
      // signOut이 끝나기 전에는 재등록하지 않는다.
    }
  }

  void resumeAfterSignOut() {
    _suspended = false;
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    session.removeListener(_changed);
    session.beforeSignOut = null;
    session.afterSignOut = null;
    WidgetsBinding.instance.removeObserver(this);
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
