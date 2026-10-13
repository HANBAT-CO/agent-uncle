import 'dart:async';

import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
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

  testWidgets('주문 작성은 키보드 위에서 입력하고 사진 포함 초안을 복원·전송한다', (tester) async {
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
    await enter(tester, '상품명', '집중 셔츠');
    await enter(tester, '요청사항', '사진의 색상으로 부탁해요.');
    await tapButton(tester, '상품 사진 첨부');
    expect(find.text('test.png'), findsOneWidget);
    final productInput = find.descendant(
      of: find.byWidgetPredicate((w) => w is Field && w.label == '상품명'),
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
    expect(draft.s('product'), '집중 셔츠');
    expect(draft.list('photos'), hasLength(1));
    await openEditor(RequestEditor(draftId: draft.id));
    expect(find.text('test.png'), findsOneWidget);
    expect(find.text('집중 셔츠'), findsOneWidget);
    for (final entry in {
      '도매처 이름': '동대문 도매',
      '시장·상가·건물·층': 'A동 2층',
      '색상·사이즈 등 옵션': '검정 L',
      '요청 수량': '3',
    }.entries) {
      await enter(tester, entry.key, entry.value);
    }
    await tester.ensureVisible(find.text('담당 사입삼촌'));
    await tester.tap(find.text('담당 사입삼촌'));
    await settle(tester);
    await tester.tap(find.text('사입 업체'));
    await settle(tester);
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
    expect(f.workspace.records('requests').single.list('photos'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, f.store.close());
  });
}
