import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../local/domain/models.dart';
import 'remote_store.dart';

class RemoteSessionRepository extends SessionRepository {
  RemoteSessionRepository(this.store) {
    store.addListener(notifyListeners);
    _subscription = store.client.auth.onAuthStateChange.listen(
      (event) {
        final id = event.session?.user.id;
        if (id != _authUser) {
          _authUser = id;
          unawaited(store.changeUser());
        }
      },
      onError: (Object e) {
        store.error = friendlyError(e);
        notifyListeners();
      },
    );
  }
  final RemoteStore store;
  StreamSubscription<AuthState>? _subscription;
  String? _authUser;
  Future<void> initialize() async {
    _authUser = store.userId;
    await store.changeUser();
  }

  @override
  bool get isRemote => true;
  @override
  bool get loading => store.loading;
  @override
  String? get syncError => store.error;
  @override
  bool get authenticated => store.userId != null;
  @override
  Future<void> retrySync() =>
      current == null ? store.changeUser() : store.refresh();
  @override
  Account? get current {
    final row = store.snapshot.get('accounts', store.userId ?? '');
    return row == null ? null : Account(row.id, row.data);
  }

  @override
  List<Account> get accounts => current == null ? [] : [current!];
  @override
  bool get onboardingSeen =>
      store.settings['onboardingSeen'] == true || authenticated;
  @override
  Record? get pendingDestination {
    final data = store.settings['destination'];
    return data is Map
        ? Record('destination', Map<String, Object?>.from(data))
        : null;
  }

  @override
  Future<void> finishOnboarding() => store.setSetting('onboardingSeen', true);
  @override
  Future<void> setDestination(Data? destination) =>
      store.setSetting('destination', destination);
  @override
  Future<void> signIn(String id) =>
      throw const AppFailure('Google 또는 카카오로 로그인해 주세요.');
  @override
  Future<String> createAccount(String label) =>
      throw const AppFailure('소셜 로그인 후 가입할 수 있어요.');
  @override
  Future<void> signInWithSocial(String provider) async {
    if (!['google', 'kakao'].contains(provider)) {
      throw const AppFailure('지원하지 않는 로그인 방식이에요.');
    }
    store.error = null;
    notifyListeners();
    try {
      final auth = SupabaseAuthRepository(store.client);
      final launched = await (provider == 'google'
          ? auth.signInWithGoogle()
          : auth.signInWithKakao());
      if (!launched) throw const AppFailure('로그인 페이지를 열지 못했어요. 다시 시도해 주세요.');
    } catch (e) {
      throw AppFailure(friendlyError(e));
    }
  }

  @override
  Future<void> signOut() async {
    // Local scope clears this device only, including when offline.
    await store.client.auth.signOut(scope: SignOutScope.local);
    _authUser = null;
    await store.changeUser();
  }

  @override
  Future<void> chooseRole(AppRole role) async {
    await store.command('chooseRole', {'role': role.name});
  }

  @override
  Future<void> saveProfile(Data fields, {bool complete = false}) async {
    await store.command('saveProfile', {
      'values': fields,
      'complete': complete,
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    store.removeListener(notifyListeners);
    store.dispose();
    super.dispose();
  }
}
