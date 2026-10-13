import 'package:flutter_test/flutter_test.dart';

import 'repositories_test.dart' show Harness, actor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('소셜 가입 중단은 세션을 비우고 재로그인한 계정도 미완료로 유지한다', () async {
    final h = Harness();
    h.tables['accounts'] = {
      actor: {'name': '가입 중인 삼촌', 'role': 'uncle', 'complete': false},
    };
    await h.open();
    addTearDown(h.close);
    await h.session.initialize();
    expect(h.session.authenticated, isTrue);
    expect(h.session.current!.complete, isFalse);

    await h.session.signOut();
    expect(h.client.auth.currentSession, isNull);
    expect(h.session.authenticated, isFalse);
    expect(h.session.current, isNull);
    expect(h.session.accounts, isEmpty);
    expect(h.store.snapshot.get('accounts', actor), isNull);

    // 인증 서버 왕복만 대체하며, 재로그인 이후 실제 세션/스냅샷을 확인한다.
    await h.client.auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
    await h.session.initialize();
    expect(h.session.authenticated, isTrue);
    expect(h.session.current!.complete, isFalse);
    expect(h.session.current!.s('name'), '가입 중인 삼촌');
    expect(h.commands.where((c) => c['command'] == 'saveProfile'), isEmpty);
  });
}
