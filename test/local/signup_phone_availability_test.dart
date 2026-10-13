import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, enter, settle, tapButton;
import 'signup_form_test.dart' show input;

class _PhoneSession extends LocalSessionRepository {
  _PhoneSession(super.store);
  Object? failure;
  bool available = true;

  @override
  Future<bool> checkPhoneAvailable(String phone) async {
    if (failure != null) throw failure!;
    return available;
  }
}

void main() {
  for (final role in AppRole.values) {
    testWidgets('${role.label} 연락처 조회 오류와 중복을 구분하고 같은 입력으로 재시도한다', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.reset);
      late LocalStore store;
      late _PhoneSession session;
      late AppServices services;
      await tester.runAsync(() async {
        store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
        await store.initialize();
        session = _PhoneSession(store);
        final workspace = LocalWorkspaceRepository(store, session);
        services = AppServices(
          session: session,
          workspace: workspace,
          attachments: LocalAttachmentRepository(store, session, workspace),
        );
        await session.finishOnboarding();
        await session.createAccount('연락처 확인 테스트');
        await session.chooseRole(role);
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        services.dispose();
        await drainClose(tester, store.close());
      });
      await tester.pumpWidget(AgentUncleApp(services: services));
      await settle(tester);
      if (role == AppRole.retailer) await enter(tester, '매장명', '테스트 매장');
      await enter(
        tester,
        role == AppRole.retailer ? '담당자명' : '이름(실명)',
        '테스트 담당자',
      );
      await enter(tester, '연락처', '01012345678');

      const serverMessage = '서버 준비가 아직 완료되지 않았어요. 잠시 후 다시 시도해 주세요.';
      session.failure = const AppFailure(serverMessage);
      await tapButton(tester, '다음');
      expect(find.text(serverMessage), findsOneWidget);
      var phone = tester.widget<TdsTextField>(input('연락처'));
      expect(phone.controller!.text, '010-1234-5678');
      expect(phone.focusNode!.hasFocus, isTrue);

      const unknownMessage = '연락처 중복 여부를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
      session.failure = const AppFailure(unknownMessage);
      await tapButton(tester, '다음');
      expect(find.text(unknownMessage), findsOneWidget);
      expect(find.text('이미 가입된 연락처예요.'), findsNothing);

      session.failure = StateError('unexpected server response');
      await tapButton(tester, '다음');
      expect(find.text(unknownMessage), findsOneWidget);
      expect(find.textContaining('연결 상태를 확인'), findsNothing);

      session.failure = null;
      session.available = false;
      await tapButton(tester, '다음');
      expect(find.text('이미 가입된 연락처예요.'), findsOneWidget);
      phone = tester.widget<TdsTextField>(input('연락처'));
      expect(phone.controller!.text, '010-1234-5678');

      session.available = true;
      await tapButton(tester, '다음');
      expect(find.text('이미 가입된 연락처예요.'), findsNothing);
      expect(input('연락처'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
