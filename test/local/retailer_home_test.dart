import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/retailer_home.dart';
import 'package:agent_uncle/local/presentation/retailer_orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import '../support/request_workflow.dart'
    show acceptRequest, createRetailerRequest, deliverRequest, shareResult;
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets('소매업자 홈은 현황과 전체 내역을 보여 주고 단계별 내역을 연다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await createRetailerRequest(fixture, product: '대기 셔츠');
      final sourcing = await createRetailerRequest(fixture, product: '진행 바지');
      final delivery = await createRetailerRequest(fixture, product: '전달 원피스');
      final receipt = await createRetailerRequest(fixture, product: '수령 재킷');
      await acceptRequest(fixture, sourcing);
      await acceptRequest(fixture, delivery);
      await shareResult(fixture, delivery, acquired: 2, backorder: 1);
      await acceptRequest(fixture, receipt);
      await shareResult(fixture, receipt, acquired: 3, backorder: 0);
      await deliverRequest(fixture, receipt, 2);
      await fixture.session.signIn(fixture.retailer);
    });
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
    );
    var selectedTab = -1;

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          PageFrame(
            title: '홈',
            back: false,
            children: [
              RetailerDashboard(onTab: (index) => selectedTab = index),
            ],
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('주문 넣기'), findsOneWidget);
    expect(find.text('내 사입 현황'), findsOneWidget);
    expect(find.widgetWithText(TdsListRow, '대기'), findsOneWidget);
    expect(find.widgetWithText(TdsListRow, '진행'), findsOneWidget);
    expect(find.widgetWithText(TdsListRow, '수령'), findsOneWidget);
    expect(find.byType(RetailerOrdersSection), findsOneWidget);
    expect(find.text('전체 내역 4건'), findsOneWidget);
    expect(find.text('사입 내역 전체 보기'), findsNothing);
    expect(find.text('최근 요청'), findsNothing);
    expect(find.text('새 사입 요청하기'), findsNothing);
    expect(find.text('함께하는 사입삼촌'), findsNothing);
    expect(find.text('거래처 연결하기'), findsNothing);

    await tester.tap(find.widgetWithText(TdsButton, '주문 넣기'));
    await settle(tester);
    expect(selectedTab, AppTab.business.index);

    await tester.tap(find.widgetWithText(TdsListRow, '대기'));
    await settle(tester);
    expect(find.text('사입 내역'), findsOneWidget);
    expect(find.textContaining('대기 셔츠'), findsOneWidget);
    expect(find.textContaining('진행 바지'), findsNothing);
    expect(find.textContaining('전달 원피스'), findsNothing);

    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(find.byType(RetailerOrdersPage), findsNothing);
    expect(find.textContaining('대기 셔츠'), findsOneWidget);
    expect(find.textContaining('진행 바지'), findsOneWidget);
    expect(find.textContaining('전달 원피스'), findsOneWidget);
    expect(find.textContaining('수령 재킷'), findsOneWidget);

    await tester.tap(find.widgetWithText(TdsListRow, '진행'));
    await settle(tester);
    expect(find.byType(RetailerOrdersPage), findsOneWidget);
    expect(find.textContaining('대기 셔츠'), findsNothing);
    expect(find.textContaining('진행 바지'), findsOneWidget);
    expect(find.textContaining('전달 원피스'), findsOneWidget);
    expect(find.textContaining('수령 재킷'), findsNothing);
    expect(selectedTab, AppTab.business.index);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
