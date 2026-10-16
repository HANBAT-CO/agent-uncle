import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/account_deletion.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle, tapButton;
import 'workspace_test.dart' show Fixture;

void main() {
  late Fixture f;

  Future<void> open(
    WidgetTester tester, {
    bool pending = false,
    bool completed = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    late AppServices services;
    await tester.runAsync(() async {
      f = Fixture();
      await f.start();
      await f.session.finishOnboarding();
      // 역할 선택에서 미완료 가입자의 삭제 경로도 함께 검증한다.
      if (!completed) {
        await f.store.write(f.retailer, '', (s) {
          s.put('accounts', f.retailer, {
            ...s.require('accounts', f.retailer),
            'complete': false,
            'role': null,
            'deletionPending': pending,
          });
          return '';
        });
      }
      services = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, f.store.close());
    });
    await tester.pumpWidget(AgentUncleApp(services: services));
    await settle(tester);
    if (completed) {
      await tapButton(tester, '내 프로필');
      expect(find.byType(MyPage), findsOneWidget);
      await tapButton(tester, '회원 탈퇴');
    } else if (!pending) {
      await tapButton(tester, '가입 정보 삭제');
    }
    expect(find.byType(AccountDeletionPage), findsOneWidget);
  }

  Future<void> agree(WidgetTester tester) async {
    final checkbox = find.byType(TdsCheckbox);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await settle(tester);
  }

  testWidgets('가입 완료 회원은 내 프로필에서 탈퇴하고 로그인 화면으로 돌아간다', (tester) async {
    await open(tester, completed: true);
    await agree(tester);
    await tapButton(tester, '회원 탈퇴하기');
    await tapButton(tester, '확인');
    expect(f.session.current, isNull);
    expect(find.byType(LocalLoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('삭제 범위 동의와 최종 확인이 필요하고 취소하면 계정을 유지한다', (tester) async {
    await open(tester);
    await tapButton(tester, '회원 탈퇴하기');
    expect(find.text('정말 탈퇴할까요?'), findsNothing);
    expect(f.session.current, isNotNull);
    await agree(tester);
    await tapButton(tester, '회원 탈퇴하기');
    expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
    await tapButton(tester, '취소');
    expect(f.session.current, isNotNull);
    await tapButton(tester, '회원 탈퇴하기');
    await tapButton(tester, '확인');
    expect(f.session.current, isNull);
    expect(find.byType(LocalLoginPage), findsOneWidget);
    expect(find.byType(AccountDeletionPage), findsNothing);
    expect(find.byType(RolePage), findsNothing);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(LocalLoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('탈퇴 실패를 표시하고 다시 시도하면 로그인 화면으로 돌아간다', (tester) async {
    await open(tester);
    await agree(tester);
    f.store.failNextWrite = true;
    await tapButton(tester, '회원 탈퇴하기');
    await tapButton(tester, '확인');
    expect(find.text('탈퇴하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(f.session.current, isNotNull);
    await tapButton(tester, '회원 탈퇴하기');
    await tapButton(tester, '확인');
    expect(find.byType(LocalLoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('삭제 중인 계정은 재시도 화면으로 복귀하고 뒤로 갈 수 없다', (tester) async {
    await open(tester, pending: true);
    expect(find.byType(TdsCheckbox), findsNothing);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(AccountDeletionPage), findsOneWidget);
    await tapButton(tester, '탈퇴 다시 시도');
    expect(find.byType(LocalLoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
