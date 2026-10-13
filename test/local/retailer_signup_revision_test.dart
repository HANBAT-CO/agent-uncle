import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' show databaseFactoryMemory;
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart'
    show PickableAttachment, drainClose, enter, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import '../support/address_search.dart';

class _Signup {
  late LocalStore store;
  late LocalSessionRepository session;
  late AppServices services;

  Future<void> open(WidgetTester tester, AppRole role) async {
    await tester.runAsync(() async {
      store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
      await store.initialize();
      session = LocalSessionRepository(store);
      final workspace = LocalWorkspaceRepository(store, session);
      services = AppServices(
        session: session,
        workspace: workspace,
        attachments: PickableAttachment(
          LocalAttachmentRepository(store, session, workspace),
        ),
      );
      await session.finishOnboarding();
      await session.createAccount('소매 가입 테스트');
      await session.chooseRole(role);
    });
    await tester.pumpWidget(AgentUncleApp(services: services));
    await settle(tester);
  }

  Future<void> reopen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(AgentUncleApp(services: services));
    await settle(tester);
  }

  Future<void> openEdit(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      AppScope(services: services, child: branded(const ProfileForm())),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, store.close());
  }
}

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is Field && w.label == label),
  matching: find.byType(TdsTextField),
);

Future<void> chip(WidgetTester tester, String label) async {
  final item = find.widgetWithText(TdsChipItem, label);
  await tester.ensureVisible(item);
  await tester.tap(item);
  await settle(tester);
}

Future<void> agreeAll(WidgetTester tester) async {
  for (final label in ['[필수] 서비스 이용 동의 확인', '[필수] 개인정보 처리 동의 확인']) {
    final checkbox = find.widgetWithText(TdsCheckbox, label);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await settle(tester);
  }
}

Future<void> goToRetailerMarketStep(WidgetTester tester) async {
  await enter(tester, '매장명', '평화상회');
  await enter(tester, '담당자명', '김소매');
  await enter(tester, '연락처', '01012345678');
  await chip(tester, '온라인');
  await tapButton(tester, '다음');
  await enter(tester, '사업자명', '평화상회');
  await enter(tester, '사업자등록번호', '1234567890');
  await tapButton(tester, '사업자등록증 (필수) 첨부');
  await tapButton(tester, '다음');
  await selectAddress(tester);
  await enter(tester, '상세주소', '101호');
  await tapButton(tester, '다음');
  expect(find.text('어디에서 사입하시나요?'), findsOneWidget);
}

Future<void> completeRetailerSignup(WidgetTester tester) async {
  await tapButton(tester, '다음');
  await tapButton(tester, '다음');
  await agreeAll(tester);
  await tapButton(tester, '가입 완료');
}

void main() {
  testWidgets('소매 가입은 이전 버튼만 남기고 안내 문구를 정리한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);

    final f = _Signup();
    await f.open(tester, AppRole.retailer);

    expect(find.byType(TdsTopNavigationBackButton), findsNothing);
    expect(find.text('이전'), findsOneWidget);
    expect(find.text('이전으로 돌아가기'), findsNothing);
    expect(find.text('입력한 정보는 자동으로 저장돼요.'), findsNothing);

    await goToRetailerMarketStep(tester);
    expect(input('배송 참고사항'), findsNothing);

    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    expect(
      find.text('개발용 동의 화면이에요. 정식 약관·개인정보 처리방침은 서비스 운영 전에 확정돼요.'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  testWidgets('소매 사입 시장은 칩과 직접 입력으로 저장되고 재진입·프로필 수정에서 유지된다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);

    final f = _Signup();
    await f.open(tester, AppRole.retailer);
    await goToRetailerMarketStep(tester);

    expect(find.widgetWithText(TdsCheckbox, '동대문'), findsNothing);
    expect(find.widgetWithText(TdsChipItem, '동대문'), findsOneWidget);
    expect(find.widgetWithText(TdsChipItem, '남대문'), findsOneWidget);
    expect(find.widgetWithText(TdsChipItem, '그 외'), findsOneWidget);

    await chip(tester, '동대문');
    await chip(tester, '그 외');
    expect(input('사입 시장 직접 입력'), findsOneWidget);
    await enter(tester, '사입 시장 직접 입력', '평화시장');

    expect(f.session.current!.list('markets'), ['동대문', '평화시장']);
    expect(f.session.current!.list('markets'), isNot(contains('그 외')));
    expect(
      tester.getRect(input('사입 시장 직접 입력')).bottom,
      lessThan(tester.getRect(find.text('다음')).top),
    );

    await tester.tap(find.text('이전'));
    await settle(tester);
    await tapButton(tester, '다음');
    expect(find.widgetWithText(TdsChipItem, '동대문'), findsOneWidget);
    expect(
      tester.widget<TdsTextField>(input('사입 시장 직접 입력')).controller!.text,
      '평화시장',
    );

    await f.reopen(tester);
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    expect(
      tester.widget<TdsTextField>(input('사입 시장 직접 입력')).controller!.text,
      '평화시장',
    );
    expect(f.session.current!.list('markets'), ['동대문', '평화시장']);

    await completeRetailerSignup(tester);
    expect(f.session.current!.complete, isTrue);

    await f.openEdit(tester);
    expect(find.widgetWithText(TdsChipItem, '동대문'), findsOneWidget);
    expect(
      tester.widget<TdsTextField>(input('사입 시장 직접 입력')).controller!.text,
      '평화시장',
    );
    expect(input('배송 참고사항'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  testWidgets('빈 그외 시장은 저장하지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);

    final f = _Signup();
    await f.open(tester, AppRole.retailer);
    await goToRetailerMarketStep(tester);

    await chip(tester, '그 외');
    expect(f.session.current!.list('markets'), isEmpty);
    await enter(tester, '사입 시장 직접 입력', '평화시장');
    expect(f.session.current!.list('markets'), ['평화시장']);
    await enter(tester, '사입 시장 직접 입력', '');
    expect(f.session.current!.list('markets'), isEmpty);

    expect(tester.takeException(), isNull);
    await f.close(tester);
  });
}
