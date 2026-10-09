import 'dart:async';

import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Google login button starts the OAuth flow', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(AgentUncleApp(authRepository: repository));

    expect(find.text('Google로 로그인'), findsOneWidget);
    // TODO(auth): Restore after Kakao Biz App registration.
    // expect(find.text('카카오로 로그인'), findsOneWidget);

    await tester.tap(find.text('Google로 로그인'));
    await tester.pump();
    expect(repository.googleSignInCount, 1);

    // await tester.tap(find.text('카카오로 로그인'));
    // await tester.pump();
    // expect(repository.kakaoSignInCount, 1);
  });
}

final class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<User?>.broadcast();

  int googleSignInCount = 0;
  // int kakaoSignInCount = 0;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userChanges => _controller.stream;

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCount += 1;
    return true;
  }

  // @override
  // Future<bool> signInWithKakao() async {
  //   kakaoSignInCount += 1;
  //   return true;
  // }

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}
