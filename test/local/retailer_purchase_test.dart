import 'dart:async';

import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/request_partner_picker.dart';
import 'package:agent_uncle/local/presentation/profile_avatar.dart';
import 'package:agent_uncle/local/presentation/retailer_purchase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart'
    show PickableAttachment, drainClose, enter, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets('사입하기 탭은 단일 CTA만 보여 주고 주문 작성을 연다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.reset);
    final f = Fixture();
    await tester.runAsync(() => f.start());
    final services = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          const PageFrame(
            title: '사입하기',
            back: false,
            children: [RetailerPurchaseTab()],
          ),
          scale: 180,
        ),
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(TdsButton, '삼촌한테 사입하기'), findsOneWidget);
    expect(find.byType(TdsButton), findsOneWidget);
    expect(find.text('새로 작성'), findsNothing);
    expect(find.text('임시저장·다시 요청'), findsNothing);
    await tapButton(tester, '삼촌한테 사입하기');
    expect(find.byType(RequestEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, f.store.close());
  });

  testWidgets('도매처 주문은 담당자 카드와 초안을 복원하고 저장 배송지로 전송한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final f = Fixture();
    await tester.runAsync(() => f.start());
    final services = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: PickableAttachment(f.attachments),
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: WidgetsApp(
          color: AppColors.background,
          // 실제 앱과 같은 키보드 여백 안에서 큰 글씨 폼을 검사한다.
          builder: (context, child) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: TdsMobileProvider(
                theme: const AppThemeData(
                  platform: TdsPlatform(os: TdsOS.android, fontScale: 180),
                ),
                child: child!,
              ),
            ),
          ),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, a, b) => builder(context),
          ),
          home: const PageFrame(title: '주문 테스트', children: []),
        ),
      ),
    );
    await settle(tester);
    Future<void> openEditor(RequestEditor editor) async {
      unawaited(openPage(tester.element(find.byType(PageFrame)), editor));
      await settle(tester);
    }

    await openEditor(const RequestEditor());
    expect(find.byType(AttachmentField), findsNothing);
    expect(find.text('상품 사진 첨부'), findsNothing);
    await enter(tester, '도매처 이름', '집중 도매');
    final productInput = find.descendant(
      of: find.byWidgetPredicate((w) => w is Field && w.label == '도매처 이름'),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(productInput);
    await tester.tap(productInput);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await settle(tester);
    expect(tester.getBottomRight(productInput).dy, lessThanOrEqualTo(552));
    expect(
      tester.getBottomRight(find.widgetWithText(TdsButton, '요청 내용 확인')).dy,
      lessThanOrEqualTo(552),
    );
    tester.view.resetViewInsets();
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tapButton(tester, '초안 저장 후 닫기');
    // Autosave completion can start the route pop at the end of settle under
    // parallel test load. Wait for that route to leave before reopening it.
    for (
      var i = 0;
      i < 20 && find.byType(RequestEditor).evaluate().isNotEmpty;
      i++
    ) {
      await settle(tester);
    }
    expect(find.byType(RequestEditor), findsNothing);
    final draft = f.workspace.records('drafts').single;
    expect(draft.s('wholesaler'), '집중 도매');
    expect(draft.list('photos'), isEmpty);
    expect(draft.n('quantity'), 1);
    await openEditor(RequestEditor(draftId: draft.id));
    expect(find.byType(AttachmentField), findsNothing);
    expect(find.text('집중 도매'), findsOneWidget);
    for (final entry in {'위치': 'A동 2층'}.entries) {
      await enter(tester, entry.key, entry.value);
    }
    await tester.ensureVisible(find.text('담당 삼촌 변경'));
    await tester.tap(find.text('담당 삼촌 변경'));
    await settle(tester);
    expect(find.byType(RequestPartnerPicker), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.text('픽업  동대문 1층'), findsOneWidget);
    expect(find.text('배송  서울'), findsOneWidget);
    expect(find.text('요청 마감  22:00'), findsOneWidget);
    expect(
      tester
          .widget<ActionButton>(
            find.widgetWithText(ActionButton, '선택한 삼촌으로 계속'),
          )
          .enabled,
      isTrue,
    );
    await tester.tap(find.text('사입 업체'));
    await settle(tester);
    expect(find.text('선택됨'), findsOneWidget);
    await tapButton(tester, '선택한 삼촌으로 계속');
    expect(find.byType(RequestPartnerPicker), findsNothing);
    expect(find.byType(RequestPartnerCard), findsOneWidget);
    await tapButton(tester, '요청 내용 확인');
    await tester.tap(find.text('확인').last);
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
    expect(f.workspace.records('requests').single.list('photos'), isEmpty);
    expect(f.workspace.records('requests').single.n('quantity'), 1);
    expect(f.workspace.records('requests').single.s('uncleId'), f.uncle);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, f.store.close());
  });

  testWidgets('기존 상품 초안은 도매처 주문으로 전환하고 불완전한 도매처는 전송하지 않는다', (tester) async {
    final f = Fixture();
    await tester.runAsync(() async {
      await f.start();
      final photo = (await PickableAttachment(
        f.attachments,
      ).pick(document: false))!;
      await f.workspace.saveDraft('bulk-draft', {
        'uncleId': f.uncle,
        'wholesaler': '도매상',
        'location': '상가 2층',
        'product': '셔츠',
        'option': '흰색 M',
        'quantity': 60,
        'address': '이전 배송지',
        'addressDetail': '이전 상세주소',
        'photos': [photo],
      });
    });
    final services = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(const RequestEditor(draftId: 'bulk-draft')),
      ),
    );
    await settle(tester);
    expect(find.text('도매상'), findsOneWidget);
    expect(find.byType(AttachmentField), findsNothing);
    await enter(tester, '위치', '');
    await tapButton(tester, '요청 내용 확인');
    expect(find.text('요청을 보낼까요?'), findsNothing);
    expect(f.workspace.records('requests'), isEmpty);
    await enter(tester, '위치', '상가 3층');
    await tapButton(tester, '도매처 추가 (1/10)');
    final names = find.byWidgetPredicate(
      (w) => w is Field && w.label == '도매처 이름',
    );
    final locations = find.byWidgetPredicate(
      (w) => w is Field && w.label == '위치',
    );
    Future<void> fill(Finder field, String value) async {
      await tester.ensureVisible(field);
      await tester.enterText(
        find.descendant(of: field, matching: find.byType(EditableText)),
        value,
      );
      await settle(tester);
    }

    await fill(names.last, '두 번째 도매');
    await fill(locations.last, 'B동 1층');
    await tapButton(tester, '요청 내용 확인');
    expect(find.text('요청을 보낼까요?'), findsOneWidget);
    await tester.tap(find.text('확인').last);
    for (
      var i = 0;
      i < 5 && find.byType(RequestDetailPage).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    expect(find.byType(RequestDetailPage), findsOneWidget);
    final request = f.workspace.records('requests').single;
    expect(request.s('requestType'), 'wholesaler');
    expect(request.n('quantity'), 1);
    expect(request.s('product'), isEmpty);
    expect(request.data['wholesalers'], [
      {'wholesaler': '도매상', 'location': '상가 3층'},
      {'wholesaler': '두 번째 도매', 'location': 'B동 1층'},
    ]);
    expect(request.s('address'), '서울시 중구');
    expect(request.s('addressDetail'), '101호');
    expect(request.list('photos'), isEmpty);
    expect(f.workspace.records('drafts'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, f.store.close());
  });
}
