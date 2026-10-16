import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/delivery.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/uncle_orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import '../support/request_workflow.dart';
import 'workspace_test.dart' show Fixture;

void main() {
  test('부분 업무와 완료 후 미해결 요청은 활성 업무에 남고 수령·입금 완료는 분리한다', () {
    RequestRecord order(String id, Data values) =>
        RequestRecord(id, {'status': 'accepted', 'quantity': 5, ...values});
    final today = dateOnly(DateTime.now());
    final rows = [
      order('new', {'status': 'pending'}),
      order('partial', {
        'acquired': 3,
        'delivered': 1,
        'resultShared': true,
        'needsReply': true,
        'recheck': today,
        'proposalId': 'proposal',
      }),
      order('recheck', {
        'acquired': 1,
        'delivered': 1,
        'received': 1,
        'resultShared': true,
        'recheck': today,
      }),
      order('scheduled', {
        'acquired': 2,
        'resultShared': true,
        'recheck': dateOnly(DateTime.now().add(const Duration(days: 1))),
      }),
      order('held', {'acquired': 5, 'held': 5, 'openIssues': 1}),
      order('received', {
        'status': 'completed',
        'acquired': 5,
        'delivered': 5,
        'received': 5,
      }),
      order('paid', {
        'status': 'completed',
        'acquired': 5,
        'delivered': 5,
        'received': 5,
        'paymentReported': true,
      }),
      for (final status in ['completed', 'cancelled', 'rejected'])
        order(status, {
          'status': status,
          'acquired': 3,
          'delivered': 1,
          'resultShared': true,
          'needsReply': true,
          'recheck': today,
          'openIssues': 1,
          'proposalId': 'old-proposal',
        }),
    ];
    final expected = <UncleOrderFilter, Set<String>>{
      UncleOrderFilter.all: rows.map((row) => row.id).toSet(),
      UncleOrderFilter.incoming: {'new'},
      UncleOrderFilter.awaitingReply: {'partial', 'completed'},
      UncleOrderFilter.inProgress: {
        'partial',
        'recheck',
        'scheduled',
        'held',
        'completed',
      },
      UncleOrderFilter.awaitingDelivery: {'partial', 'scheduled', 'completed'},
      UncleOrderFilter.awaitingReceipt: {'partial', 'completed'},
      UncleOrderFilter.backorder: {
        'partial',
        'recheck',
        'scheduled',
        'completed',
      },
      UncleOrderFilter.recheck: {'recheck'},
      UncleOrderFilter.issues: {'partial', 'held', 'completed'},
      UncleOrderFilter.received: {'received'},
      UncleOrderFilter.completed: {'paid'},
    };
    for (final entry in expected.entries) {
      expect(
        filterUncleOrders(rows, entry.key).map((row) => row.id).toSet(),
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  testWidgets('홈 사입 내역에서 상태·검색·묶음과 주문 상세·전달 페이지를 사용할 수 있다', (tester) async {
    final fixture = Fixture();
    late String pending, delivery, receipt;
    await tester.runAsync(() async {
      await fixture.start();
      pending = await createRetailerRequest(fixture, product: '새 셔츠');
      delivery = await createRetailerRequest(fixture, product: '전달 원피스');
      receipt = await createRetailerRequest(fixture, product: '전달 재킷');
      await acceptRequest(fixture, delivery);
      await shareResult(fixture, delivery, acquired: 2, backorder: 1);
      await acceptRequest(fixture, receipt);
      await shareResult(fixture, receipt, acquired: 3, backorder: 0);
      await deliverRequest(fixture, receipt, 2);
    });
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          const PageFrame(
            title: '홈',
            back: false,
            children: [
              UncleOrdersSection(
                initialFilter: UncleOrderFilter.awaitingDelivery,
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
    Finder card(String id) => find.byKey(ValueKey('uncle-order-$id'));
    expect(card(pending), findsNothing);
    expect(card(delivery), findsOneWidget);
    expect(card(receipt), findsOneWidget);

    final search = find.descendant(
      of: find.byType(TdsSearchField),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, '전달 원피스');
    await settle(tester);
    expect(card(delivery), findsOneWidget);
    expect(card(receipt), findsNothing);
    for (final query in ['A동 2층', '소매 닉네임']) {
      await tester.enterText(search, query);
      await settle(tester);
      expect(card(delivery), findsOneWidget);
      expect(card(receipt), findsOneWidget);
    }
    await tester.enterText(search, '없는 상품');
    await settle(tester);
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    await tester.enterText(search, '');
    await settle(tester);
    await tester.ensureVisible(find.widgetWithText(TdsChipItem, '도매처별'));
    await tester.tap(find.widgetWithText(TdsChipItem, '도매처별'));
    await settle(tester);
    expect(find.text('동대문 도매상 · 2건'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TdsChipItem, '사입 요청'));
    await tester.tap(find.widgetWithText(TdsChipItem, '사입 요청'));
    await settle(tester);
    expect(card(pending), findsOneWidget);
    expect(card(delivery), findsNothing);
    expect(card(receipt), findsNothing);
    await tester.ensureVisible(find.text('새 셔츠 · 기본'));
    await tester.tap(find.text('새 셔츠 · 기본'));
    await settle(tester);
    expect(find.byType(RequestDetailPage), findsOneWidget);
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);

    await tester.ensureVisible(find.text('전달 가능 3장'));
    await tester.tap(find.text('전달 가능 3장'));
    await settle(tester);
    expect(find.byType(DeliveryList), findsOneWidget);
    expect(find.text('상품 전달'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
