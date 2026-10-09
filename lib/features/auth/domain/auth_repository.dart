import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  User? get currentUser;

  Stream<User?> get userChanges;

  Future<bool> signInWithGoogle();

  // TODO(auth): Re-enable after Kakao Biz App registration is complete.
  // Future<bool> signInWithKakao();

  Future<void> signOut();
}
