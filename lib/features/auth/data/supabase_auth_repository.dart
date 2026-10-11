import 'package:agent_uncle/core/config/supabase_config.dart';
import 'package:agent_uncle/features/auth/domain/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<User?> get userChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user);

  @override
  Future<bool> signInWithGoogle() {
    return _signInWithOAuth(OAuthProvider.google);
  }

  @override
  Future<bool> signInWithKakao() {
    return _signInWithOAuth(OAuthProvider.kakao);
  }

  Future<bool> _signInWithOAuth(OAuthProvider provider) {
    return _client.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb
          ? SupabaseConfig.webAuthCallback
          : SupabaseConfig.mobileAuthCallback,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
