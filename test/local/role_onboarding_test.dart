import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/role_onboarding.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show settle, tapButton, drainClose, drainWork;
import 'workspace_test.dart' show Fixture;

// 검증된 가입 데이터를 사용하되, 실제 가입과 같은 순서로 안내를 준비한다.
Future<void> prepareSignup(Fixture f, String id) async {
  await f.session.signIn(id);
  await f.store.write(id, '', (s) {
    s.require('accounts', id)['complete'] = false;
    return id;
  });
  await f.session.prepareRoleOnboarding();
  expect(f.session.roleOnboardingPending, isFalse);
  await f.session.saveProfile({}, complete: true);
}

void main() {
  test('가입 안내 상태는 계정별로 저장되며 기존 회원과 프로필 수정에는 생기지 않는다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(() async {
      f.session.dispose();
      f.workspace.dispose();
      await f.store.close();
    });
    expect(f.session.roleOnboardingPending, isFalse);
    await f.session.prepareRoleOnboarding();
    await f.session.saveProfile({'contact': '새 담당자'}, complete: true);
    expect(f.session.roleOnboardingPending, isFalse);
    await prepareSignup(f, f.retailer);
    expect(f.session.roleOnboardingPending, isTrue);
    await f.session.signIn(f.uncle);
    expect(f.session.roleOnboardingPending, isFalse);
    await f.session.signIn(f.retailer);
    await f.store.reload();
    final restored = LocalSessionRepository(f.store);
    expect(restored.roleOnboardingPending, isTrue);
    await restored.finishRoleOnboarding();
    restored.dispose();
    await f.session.signOut();
    await f.session.signIn(f.retailer);
    expect(f.session.roleOnboardingPending, isFalse);
  });

  for (final role in AppRole.values) {
    testWidgets('${role.label} 가입 후 세 장 안내와 이전·완료·재로그인', (tester) async {
      final f = Fixture();
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        await prepareSignup(f, role == AppRole.retailer ? f.retailer : f.uncle);
      });
      final app = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(AgentUncleApp(services: app));
      await settle(tester);
      final titles = role == AppRole.retailer
          ? ['원하는 상품을\n정확하게 전달해요', '챙겨야 할 대금이\n한눈에 보여요', '새로운 시장으로\n사입을 넓혀요']
          : [
              '받을 대금과 지급 현황을\n놓치지 않아요',
              '여러 거래처의 요청을\n한곳에서 관리해요',
              '오늘의 사입도,\n이번 달 실적도 한눈에',
            ];
      expect(find.text(titles[0]), findsOneWidget);
      expect(find.textContaining('30분'), findsNothing);
      expect(find.text('이전'), findsNothing);
      await tapButton(tester, '다음');
      expect(find.text(titles[1]), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(titles[0]), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(titles[0]), findsOneWidget);
      await tapButton(tester, '다음');
      await tapButton(tester, '이전');
      expect(find.text(titles[0]), findsOneWidget);
      await tapButton(tester, '다음');
      await tapButton(tester, '다음');
      expect(find.text(titles[2]), findsOneWidget);
      await tapButton(tester, '사입삼춘 시작하기');
      expect(f.session.roleOnboardingPending, isFalse);
      expect(find.byType(RoleOnboardingPage), findsNothing);
      for (final label in role.tabs) {
        expect(find.widgetWithText(TdsTextButton, label), findsOneWidget);
      }
      await drainWork(tester, () async {
        final id = f.session.current!.id;
        await f.session.signOut();
        await f.session.signIn(id);
      }());
      await settle(tester);
      expect(find.byType(RoleOnboardingPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await drainClose(tester, f.store.close());
    });
  }

  testWidgets('건너뛰기 저장 실패는 안내를 유지하고 재시도하면 홈으로 이동한다', (tester) async {
    final f = Fixture();
    await tester.runAsync(() async {
      await f.start();
      await f.session.finishOnboarding();
      await prepareSignup(f, f.retailer);
    });
    final app = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    f.store.failNextWrite = true;
    await tapButton(tester, '건너뛰기');
    expect(f.session.roleOnboardingPending, isTrue);
    expect(find.text('안내 완료 상태를 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await tapButton(tester, '건너뛰기');
    expect(find.byType(RoleOnboardingPage), findsNothing);
    expect(f.session.roleOnboardingPending, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await drainClose(tester, f.store.close());
  });

  testWidgets('작은 화면·큰 글자·동작 줄이기에서 두 역할의 안내를 넘길 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final role in AppRole.values) {
      await tester.pumpWidget(
        WidgetsApp(
          key: ValueKey(role),
          color: AppColors.background,
          home: RoleOnboardingPage(role: role),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: AppTheme(child: child!),
          ),
        ),
      );
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<TdsStaggerIn>(find.byType(TdsStaggerIn)).play,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        if (i < 2) await tapButton(tester, '다음');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
