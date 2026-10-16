import 'package:flutter_test/flutter_test.dart';

import 'repositories_test.dart' show Harness, actor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('서버 회원의 가입 안내는 가입 완료 후 표시되고 기기 저장소에 유지된다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    expect(h.session.roleOnboardingPending, isFalse);
    await h.session.prepareRoleOnboarding();
    expect(h.store.settings['roleOnboarding:$actor'], isNull);

    h.tables['accounts'][actor]['complete'] = false;
    await h.store.refresh();
    await h.session.prepareRoleOnboarding();
    expect(h.session.roleOnboardingPending, isFalse);
    h.tables['accounts'][actor]['complete'] = true;
    await h.store.refresh();
    expect(h.session.roleOnboardingPending, isTrue);
    await h.store.initialize();
    expect(h.session.roleOnboardingPending, isTrue);

    await h.session.finishRoleOnboarding();
    await h.store.initialize();
    expect(h.session.roleOnboardingPending, isFalse);
  });
}
