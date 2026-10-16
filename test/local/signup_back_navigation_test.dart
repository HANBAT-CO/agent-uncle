import 'dart:async';

import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, enter, settle, tapButton;

// OAuth 왕복만 대체하고 실제 가입 저장·라우팅·세션 종료를 사용한다.
class _SignupSession extends LocalSessionRepository {
  _SignupSession(super.store);
  int signOutCalls = 0;
  bool failSignOut = false;
  Completer<void>? pendingSave;

  @override
  bool get isRemote => true;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw const AppFailure('로그아웃을 다시 시도해 주세요.');
    await super.signOut();
  }

  @override
  Future<void> saveProfile(Data fields, {bool complete = false}) async {
    await pendingSave?.future;
    await super.saveProfile(fields, complete: complete);
  }
}

void main() {
  late LocalStore store;
  late _SignupSession session;
  late AppServices services;
  late String accountId;

  Future<void> open(WidgetTester tester, {AppRole? role}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
      await store.initialize();
      session = _SignupSession(store);
      final workspace = LocalWorkspaceRepository(store, session);
      services = AppServices(
        session: session,
        workspace: workspace,
        attachments: LocalAttachmentRepository(store, session, workspace),
      );
      await session.finishOnboarding();
      accountId = await session.createAccount('미완료 소셜 가입');
      if (role != null) {
        await session.chooseRole(role);
        await session.saveProfile({
          'name': '테스트 매장',
          'contact': '김담당',
          'phone': '01012345678',
          'bankName': '우리은행',
          'bankAccount': '123-456-789012',
          'bankHolder': '테스트 담당자',
          'salesChannel': '온라인',
        });
      }
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, store.close());
    });
    await tester.pumpWidget(AgentUncleApp(services: services));
    await settle(tester);
  }

  for (final role in AppRole.values) {
    for (final systemBack in [false, true]) {
      testWidgets('$role 가입 이전 → 역할 선택 → 로그인 (시스템 뒤로: $systemBack)', (
        tester,
      ) async {
        await open(tester, role: role);
        await tapButton(tester, '다음');
        expect(find.text('연락받을 정보를 알려주세요'), findsNothing);
        await tester.tap(find.text('이전'));
        await settle(tester);
        expect(find.text('연락받을 정보를 알려주세요'), findsOneWidget);
        await tester.tap(find.text('이전'));
        await settle(tester);
        expect(find.byType(RolePage), findsOneWidget);

        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(TdsTopNavigationBackButton));
        }
        await settle(tester);

        expect(find.byType(SocialLoginPage), findsOneWidget);
        expect(find.byType(ProfileForm), findsNothing);
        expect(session.current, isNull);
        expect(session.signOutCalls, 1);
        final draft = store.snapshot.get('accounts', accountId)!;
        expect(draft.b('complete'), isFalse);
        expect(draft.s('phone'), '01012345678');
        expect(
          store.snapshot.get('signupProgress', accountId)!.s('stage'),
          isNot('completed'),
        );

        // 같은 소셜 계정으로 재로그인해도 업무 홈으로 통과하지 않는다.
        final signingIn = session.signIn(accountId);
        await settle(tester);
        await signingIn;
        expect(find.byType(ProfileForm), findsOneWidget);
        expect(find.byType(HomeShell), findsNothing);
        expect(session.current!.complete, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('최초 역할 선택에서도 뒤로 가면 로그인을 종료한다', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(SocialLoginPage), findsOneWidget);
    expect(session.current, isNull);
    expect(store.snapshot.get('accounts', accountId)!.b('complete'), isFalse);
    final signingIn = session.signIn(accountId);
    await settle(tester);
    await signingIn;
    expect(find.byType(RolePage), findsOneWidget);
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(find.byType(SocialLoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장 중 이전을 연속 눌러도 역할 선택을 한 번만 연다', (tester) async {
    await open(tester, role: AppRole.uncle);
    final pending = Completer<void>();
    session.pendingSave = pending;
    await enter(tester, '이름(실명)', '초안 이름');
    await tester.tap(find.text('이전'));
    await tester.pump();
    await tester.tap(find.text('이전'));
    await tester.binding.handlePopRoute();
    pending.complete();
    await settle(tester);
    expect(find.byType(RolePage, skipOffstage: false), findsOneWidget);
    expect(session.current!.s('contact'), '초안 이름');
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(find.byType(SocialLoginPage), findsOneWidget);
    expect(session.signOutCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그아웃 실패 시 역할 선택을 유지하고 오류 후 재시도한다', (tester) async {
    await open(tester, role: AppRole.uncle);
    await tester.tap(find.text('이전'));
    await settle(tester);
    session.failSignOut = true;
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(find.byType(RolePage), findsOneWidget);
    expect(find.text('로그아웃을 다시 시도해 주세요.'), findsOneWidget);
    expect(session.current!.complete, isFalse);
    expect(tester.takeException(), isNull);
    session.failSignOut = false;
    await tester.tap(find.text('로그인으로 돌아가기'));
    await settle(tester);
    expect(find.byType(SocialLoginPage), findsOneWidget);
  });
}
