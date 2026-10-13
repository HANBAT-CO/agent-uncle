import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' hide Field;
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'workspace_test.dart' show Fixture;

class PickableAttachment implements AttachmentRepository {
  PickableAttachment(this.delegate);
  final AttachmentRepository delegate;
  @override
  Future<String?> pick({required bool document}) => delegate.save(
    'test.png',
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4uoAAAAASUVORK5CYII=',
    ),
    'image/png',
  );
  @override
  Future<String> save(String name, Uint8List bytes, String mime) =>
      delegate.save(name, bytes, mime);
  @override
  Future<Uint8List> bytes(String id) => delegate.bytes(id);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(TdsButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.byWidgetPredicate((w) => w is Field && w.label == label),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await settle(tester);
}

Future<void> drainClose(WidgetTester tester, Future<void> closing) async {
  var done = false;
  closing.whenComplete(() => done = true);
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(
    done,
    isTrue,
    reason: 'Database close completes after queued frame work',
  );
  await closing;
}

void main() {
  testWidgets('empty install onboarding, local signup, role tabs and relogin', (
    tester,
  ) async {
    final store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
    await store.initialize();
    final session = LocalSessionRepository(store),
        workspace = LocalWorkspaceRepository(
          store,
          LocalSessionRepository(store),
        );
    final app = AppServices(
      session: session,
      workspace: workspace,
      attachments: PickableAttachment(
        LocalAttachmentRepository(store, session, workspace),
      ),
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    expect(find.text('상품과 수량을 정확하게 전달해요'), findsOneWidget);
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    await tapButton(tester, '시작하기');
    await enter(tester, '계정 이름', '첫 매장');
    await tapButton(tester, '로컬 계정 만들기');
    await tester.tap(find.widgetWithText(TdsCheckbox, '소매업자'));
    await settle(tester);
    await tapButton(tester, '선택한 역할로 계속');
    for (final e in {
      '매장명·쇼핑몰명': '첫 매장',
      '이름·담당자명': '담당자',
      '연락처': '01012345678',
    }.entries) {
      await enter(tester, e.key, e.value);
    }
    await tapButton(tester, '다음');
    await enter(tester, '사업자명', '첫 매장');
    await enter(tester, '사업자등록번호', '1234567890');
    await tapButton(tester, '다음');
    expect(session.current!.complete, false);
    expect(find.text('사업자등록증을 첨부해 주세요.'), findsOneWidget);
    expect(session.current!.s('contact'), '담당자');
    await tapButton(tester, '사업자등록증 (필수) 첨부');
    await tapButton(tester, '다음');
    await enter(tester, '주소', '서울 중구');
    await enter(tester, '상세주소', '101호');
    await tapButton(tester, '다음');
    await tester.tap(find.widgetWithText(TdsCheckbox, '동대문'));
    await settle(tester);
    await tapButton(tester, '다음');
    expect(session.current!.s('address'), '서울 중구');
    expect(session.current!.list('markets'), ['동대문']);
    await tapButton(tester, '다음');
    for (final label in ['[필수] 서비스 이용 동의 확인', '[필수] 개인정보 처리 동의 확인']) {
      final checkbox = find.widgetWithText(TdsCheckbox, label);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await settle(tester);
    }
    await tapButton(tester, '가입 완료');
    expect(session.current!.complete, true);
    for (final label in AppRole.retailer.tabs) {
      expect(find.widgetWithText(TdsTextButton, label), findsOneWidget);
    }
    expect(find.text('아직 사입 요청이 없어요'), findsOneWidget);
    await tester.tap(find.widgetWithText(TdsTextButton, '내 정보'));
    await settle(tester);
    await tapButton(tester, '로그아웃');
    await tester.tap(find.text('확인').last);
    await settle(tester);
    expect(session.current, isNull);
    expect(find.text('첫 매장'), findsOneWidget);
    await tester.ensureVisible(find.text('첫 매장'));
    await tester.tap(find.text('첫 매장'));
    await settle(tester);
    expect(find.text('아직 사입 요청이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, store.close());
    app.dispose();
  });
  testWidgets(
    'request editor autosaves, persists after back and sends canonical detail',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(() => f.start());
      await tester.runAsync(() => f.session.finishOnboarding());
      final app = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(AgentUncleApp(services: app));
      await settle(tester);
      await tester.tap(find.widgetWithText(TdsTextButton, '사입'));
      await settle(tester);
      await tester.tap(find.text('새로 작성'));
      await settle(tester);
      await enter(tester, '상품명', '자동 저장 셔츠');
      await tapButton(tester, '초안 저장 후 닫기');
      await tester.tap(find.widgetWithText(TdsTextButton, '채팅'));
      await settle(tester);
      expect(find.byType(RequestEditor), findsNothing);
      await tester.tap(find.widgetWithText(TdsTextButton, '사입'));
      await settle(tester);
      await tester.tap(find.text('임시저장·다시 요청'));
      await settle(tester);
      await tester.tap(find.text('자동 저장 셔츠'));
      await settle(tester);
      expect(find.byType(RequestEditor), findsOneWidget);
      expect(find.text('자동 저장 셔츠'), findsOneWidget);
      final viewport = tester.view.physicalSize;
      tester.view.physicalSize = Size.zero;
      await tester.pump();
      tester.view.physicalSize = viewport;
      await settle(tester);
      expect(find.text('자동 저장 셔츠'), findsOneWidget);
      final productInput = find.descendant(
        of: find.byWidgetPredicate((w) => w is Field && w.label == '상품명'),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(productInput);
      await tester.tap(productInput);
      tester.view.viewInsets = FakeViewPadding(
        bottom: 240 * tester.view.devicePixelRatio,
      );
      await settle(tester);
      expect(
        tester.getBottomRight(productInput).dy,
        lessThanOrEqualTo(viewport.height / tester.view.devicePixelRatio - 240),
      );
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tapButton(tester, '초안 저장 후 닫기');
      expect(f.workspace.records('drafts').single.s('product'), '자동 저장 셔츠');
      await tester.tap(find.text('자동 저장 셔츠'));
      await settle(tester);
      expect(find.byType(RequestEditor), findsOneWidget);
      for (final e in {
        '도매처 이름': '도매',
        '시장·상가·건물·층': '상가 1층',
        '색상·사이즈 등 옵션': '검정 L',
        '요청 수량': '3',
      }.entries) {
        await enter(tester, e.key, e.value);
      }
      final choose = find.text('담당 사입삼촌');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await settle(tester);
      await tester.tap(find.text('사입 업체'));
      await settle(tester);
      await tapButton(tester, '요청 내용 확인');
      await tester.tap(find.text('확인').last);
      // 확인창 퇴장 이후 저장과 상세 화면 전환이 차례로 끝날 때까지 기다린다.
      for (
        var i = 0;
        i < 5 && find.byType(RequestDetailPage).evaluate().isEmpty;
        i++
      ) {
        await settle(tester);
      }
      expect(find.byType(RequestDetailPage), findsOneWidget);
      expect(f.workspace.records('drafts'), isEmpty);
      expect(f.workspace.records('requests'), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );
  testWidgets('uncle has five tabs and no retailer request editor tab', (
    tester,
  ) async {
    final f = Fixture();
    await tester.runAsync(() => f.start());
    await tester.runAsync(() => f.session.finishOnboarding());
    await tester.runAsync(() => f.session.signIn(f.uncle));
    final app = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    for (final label in AppRole.uncle.tabs) {
      expect(find.widgetWithText(TdsTextButton, label), findsOneWidget);
    }
    expect(find.widgetWithText(TdsTextButton, '사입'), findsNothing);
    await tester.tap(find.widgetWithText(TdsTextButton, '업무'));
    await settle(tester);
    await tester.tap(find.text('전달할 물품'));
    await settle(tester);
    expect(find.text('지금 전달할 물품이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, f.close());
  });
  testWidgets(
    'tabs keep scroll and filters, detail returns to the same request list',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        for (var i = 0; i < 12; i++) {
          await f.request();
        }
      });
      final app = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(AgentUncleApp(services: app));
      await settle(tester);
      final positions = [
        for (final label in AppRole.retailer.tabs)
          tester.getCenter(find.widgetWithText(TdsTextButton, label)).dx,
      ];
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
      await tester.tap(find.widgetWithText(TdsTextButton, '사입'));
      await settle(tester);
      final scroller = find.byKey(
        PageStorageKey('${f.retailer}-tab-${AppTab.business.index}'),
      );
      await tester.drag(scroller, const Offset(0, -600));
      await settle(tester);
      final scrollable = find.descendant(
        of: scroller,
        matching: find.byType(Scrollable),
      );
      final offset = tester
          .state<ScrollableState>(scrollable.first)
          .position
          .pixels;
      expect(offset, greaterThan(0));
      final card = find.byType(RequestCard).hitTestable().first;
      final requestId = tester.widget<RequestCard>(card).request.id;
      await tester.tap(card);
      await settle(tester);
      expect(
        tester.widget<RequestDetailPage>(find.byType(RequestDetailPage)).id,
        requestId,
      );
      await tester.tap(find.byType(TdsTopNavigationBackButton));
      await settle(tester);
      await tester.tap(find.widgetWithText(TdsTextButton, '채팅'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TdsTextButton, '사입'));
      await settle(tester);
      expect(
        tester.state<ScrollableState>(scrollable.first).position.pixels,
        offset,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );

  testWidgets(
    'login restores a notification and its delivery card follows the latest receipt',
    (tester) async {
      final f = Fixture();
      late String delivery;
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        final request = await f.request();
        await f.accept(request);
        await f.result(request, 3, 0);
        delivery = await f.deliver(request, 3);
        await f.session.signIn(f.retailer);
        final notice = f.workspace
            .records('notices')
            .firstWhere((n) => n.s('targetId') == delivery);
        await f.session.setDestination({...notice.data, 'noticeId': notice.id});
        await f.session.signOut();
      });
      final app = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(AgentUncleApp(services: app));
      await settle(tester);
      await tester.ensureVisible(find.text('소매 매장'));
      await tester.tap(find.text('소매 매장'));
      await settle(tester);
      expect(find.text('전달 내역'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DeliveryCard).last,
          matching: find.text('수령 대기'),
        ),
        findsOneWidget,
      );
      await tapButton(tester, '이번 전달분 수령 확인');
      await tapButton(tester, '3장 수령 확인 · 요청 완료');
      expect(find.text('전달 내역'), findsOneWidget);
      expect(find.widgetWithText(TdsButton, '이번 전달분 수령 확인'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DeliveryCard).last,
          matching: find.text('수령 확인'),
        ),
        findsOneWidget,
      );
      expect(
        f.workspace.records('deliveries').single.b('receiptRecorded'),
        isTrue,
      );
      expect(f.session.pendingDestination, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );

  testWidgets('draft save failure shows retry and preserves typed input', (
    tester,
  ) async {
    final f = Fixture();
    await tester.runAsync(() async {
      await f.start();
      await f.session.finishOnboarding();
    });
    final app = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    await tester.tap(find.widgetWithText(TdsTextButton, '사입'));
    await settle(tester);
    await tester.tap(find.text('새로 작성'));
    await settle(tester);
    f.store.failNextWrite = true;
    await enter(tester, '상품명', '저장 실패 후 복원');
    expect(find.widgetWithText(TdsButton, '초안 저장 다시 시도'), findsOneWidget);
    expect(f.workspace.records('drafts'), isEmpty);
    await tapButton(tester, '초안 저장 다시 시도');
    expect(f.workspace.records('drafts').single.s('product'), '저장 실패 후 복원');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, f.close());
  });
}
