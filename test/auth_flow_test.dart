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

    expect(find.bySemanticsLabel('Google로 로그인'), findsOneWidget);
    expect(find.bySemanticsLabel('카카오 로그인'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Google로 로그인'));
    await tester.pump();
    expect(repository.googleSignInCount, 1);

    await tester.tap(find.bySemanticsLabel('카카오 로그인'));
    await tester.pump();
    expect(repository.kakaoSignInCount, 1);
  });

  testWidgets('pending login blocks both providers and failure allows retry', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    final pending = Completer<bool>();
    repository.googleResult = pending.future;
    await tester.pumpWidget(AgentUncleApp(authRepository: repository));

    final google = find.bySemanticsLabel('Google로 로그인');
    final kakao = find.bySemanticsLabel('카카오 로그인');
    await tester.tap(google);
    await tester.pump();
    await tester.tap(google);
    await tester.tap(kakao);
    await tester.pump();
    expect(repository.googleSignInCount, 1);
    expect(repository.kakaoSignInCount, 0);

    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('로그인하지 못했어요.'), findsOneWidget);
    await tester.tap(kakao);
    await tester.pumpAndSettle();
    expect(repository.kakaoSignInCount, 1);
    expect(find.textContaining('로그인하지 못했어요.'), findsNothing);
  });
}

final class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<User?>.broadcast();

  int googleSignInCount = 0;
  int kakaoSignInCount = 0;
  Future<bool>? googleResult;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userChanges => _controller.stream;

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCount += 1;
    return googleResult ?? true;
  }

  @override
  Future<bool> signInWithKakao() async {
    kakaoSignInCount += 1;
    return true;
  }

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}
