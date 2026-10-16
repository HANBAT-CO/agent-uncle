import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/retailer_orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

Future<String> createRetailerRequest(
  Fixture fixture, {
  required String product,
  int quantity = 3,
}) async {
  await fixture.session.signIn(fixture.retailer);
  final id = newId();
  await fixture.workspace.saveDraft(id, {
    'uncleId': fixture.uncle,
    'wholesaler': '동대문 도매상',
    'location': 'A동 2층',
    'product': product,
    'option': '기본',
    'quantity': quantity,
    'address': '서울시 중구',
    'addressDetail': '101호',
  });
  await fixture.workspace.sendDraft(id, 'send-$id');
  return id;
}

Future<void> acceptRequest(Fixture fixture, String requestId) async {
  await fixture.session.signIn(fixture.uncle);
  await fixture.workspace.act(
    requestId,
    'accept',
    {},
    fixture.workspace.request(requestId)!.version,
    newId(),
  );
}

Future<void> shareResult(
  Fixture fixture,
  String requestId, {
  required int acquired,
  required int backorder,
  bool needsReply = true,
}) async {
  await fixture.session.signIn(fixture.uncle);
  await fixture.workspace.act(
    requestId,
    'result',
    {
      'acquired': acquired,
      'backorder': backorder,
      'recheck': backorder > 0
          ? dateOnly(DateTime.now().add(const Duration(days: 1)))
          : '',
      'reason': backorder > 0 ? '미송 확인' : '',
      'needsReply': needsReply,
    },
    fixture.workspace.request(requestId)!.version,
    newId(),
  );
}

Future<String> deliverRequest(
  Fixture fixture,
  String requestId,
  int quantity,
) async {
  await fixture.session.signIn(fixture.uncle);
  await fixture.workspace.deliver(
    {requestId: quantity},
    {requestId: fixture.workspace.request(requestId)!.version},
    newId(),
  );
  final deliveries =
      fixture.workspace
          .records('deliveries')
          .where((delivery) => delivery.s('requestId') == requestId)
          .toList()
        ..sort((a, b) => a.s('createdAt').compareTo(b.s('createdAt')));
  return deliveries.last.id;
}

Future<void> receiveDelivery(
  Fixture fixture,
  String deliveryId,
  int quantity,
) async {
  await fixture.session.signIn(fixture.retailer);
  final delivery = fixture.workspace
      .records('deliveries')
      .firstWhere((record) => record.id == deliveryId);
  await fixture.workspace.receive(
    deliveryId,
    quantity,
    '',
    delivery.version,
    newId(),
  );
}

Future<void> chooseWait(Fixture fixture, String requestId) async {
  await fixture.session.signIn(fixture.retailer);
  await fixture.workspace.act(
    requestId,
    'wait',
    {},
    fixture.workspace.request(requestId)!.version,
    newId(),
  );
}

void main() {
  test('수령 완료 후에도 입금을 신고하기 전까지 입금 전 단계에 남는다', () async {
    final fixture = Fixture();
    await fixture.start();
    final pending = await createRetailerRequest(fixture, product: '대기 셔츠');
    final sourcing = await createRetailerRequest(fixture, product: '진행 바지');
    final delivery = await createRetailerRequest(fixture, product: '전달 원피스');
    final receipt = await createRetailerRequest(fixture, product: '수령 재킷');
    final backorder = await createRetailerRequest(fixture, product: '미송 신발');
    final completed = await createRetailerRequest(fixture, product: '완료 모자');

    await acceptRequest(fixture, sourcing);
    await acceptRequest(fixture, delivery);
    await shareResult(fixture, delivery, acquired: 2, backorder: 1);
    await acceptRequest(fixture, receipt);
    await shareResult(fixture, receipt, acquired: 3, backorder: 0);
    await deliverRequest(fixture, receipt, 2);
    await acceptRequest(fixture, backorder);
    await shareResult(fixture, backorder, acquired: 1, backorder: 2);
    await chooseWait(fixture, backorder);
    final backorderDelivery = await deliverRequest(fixture, backorder, 1);
    await receiveDelivery(fixture, backorderDelivery, 1);
    await acceptRequest(fixture, completed);
    await shareResult(fixture, completed, acquired: 3, backorder: 0);
    final completedDelivery = await deliverRequest(fixture, completed, 3);
    await receiveDelivery(fixture, completedDelivery, 3);
    final receivedAt = fixture.workspace.request(completed)!.receivedAt!;

    final requests = fixture.workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data))
        .toList();

    expect(
      filterRetailerOrders(requests, RetailerOrderFilter.all),
      hasLength(6),
    );
    expect(
      filterRetailerOrders(
        requests,
        RetailerOrderFilter.pendingConfirmation,
      ).map((request) => request.id),
      [pending],
    );
    expect(
      filterRetailerOrders(
        requests,
        RetailerOrderFilter.inProgress,
      ).map((request) => request.id).toSet(),
      {sourcing, delivery, receipt, backorder},
    );
    expect(
      requests
          .where(retailerIsAwaitingDelivery)
          .map((request) => request.id)
          .toSet(),
      {delivery, receipt},
    );
    expect(
      requests.where(retailerIsAwaitingReceipt).map((request) => request.id),
      [receipt],
    );
    expect(requests.where(retailerNeedsReply).map((request) => request.id), [
      delivery,
    ]);
    expect(
      requests.where(retailerHasBackorder).map((request) => request.id).toSet(),
      {delivery, backorder},
    );
    expect(
      filterRetailerOrders(
        requests,
        RetailerOrderFilter.completed,
        now: receivedAt,
      ),
      isEmpty,
    );
    expect(
      filterRetailerOrders(
        requests,
        RetailerOrderFilter.received,
        now: receivedAt
            .add(const Duration(days: 7))
            .subtract(const Duration(microseconds: 1)),
      ).map((request) => request.id).toSet(),
      {completed},
    );
    expect(
      filterRetailerOrders(
        requests,
        RetailerOrderFilter.received,
        now: receivedAt.add(const Duration(days: 7)),
      ).map((request) => request.id),
      [completed],
    );
    expect(
      filterRetailerOrders(
        requests,
        RetailerOrderFilter.completed,
        now: receivedAt.add(const Duration(days: 7)),
      ).map((request) => request.id),
      isEmpty,
    );
    final paid = RequestRecord(completed, {
      ...fixture.workspace.request(completed)!.data,
      'paymentReported': true,
    });
    expect(retailerIsCompleted(paid), isTrue);
    expect(retailerIsReceived(paid), isFalse);
    expect(paid.paymentLabel, '운영 확인 대기');
    await fixture.close();
  });

  testWidgets('사입 내역 페이지가 필터·검색·초안 허브 이동을 유지한다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      final pending = await createRetailerRequest(fixture, product: '대기 셔츠');
      final delivery = await createRetailerRequest(fixture, product: '전달 원피스');
      final receipt = await createRetailerRequest(fixture, product: '수령 재킷');
      await acceptRequest(fixture, delivery);
      await shareResult(fixture, delivery, acquired: 2, backorder: 1);
      await acceptRequest(fixture, receipt);
      await shareResult(fixture, receipt, acquired: 3, backorder: 0);
      final deliveryId = await deliverRequest(fixture, receipt, 3);
      await receiveDelivery(fixture, deliveryId, 3);
      await fixture.session.signIn(fixture.retailer);
      final draftId = newId();
      await fixture.workspace.saveDraft(draftId, {
        'uncleId': fixture.uncle,
        'wholesaler': '임시 저장 도매상',
        'location': 'B동 1층',
        'product': '임시 저장 상의',
        'option': '샘플',
        'quantity': 2,
        'address': '서울시 중구',
        'addressDetail': '101호',
      });
      expect(fixture.workspace.request(pending), isNotNull);
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
            children: [RetailerOrdersSection()],
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('사입 내역'), findsOneWidget);
    expect(find.textContaining('대기 셔츠'), findsOneWidget);
    expect(find.text('전달 원피스 · 기본'), findsOneWidget);
    expect(find.textContaining('수령 재킷'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(TdsTab), matching: find.text('수령(입금 전)')),
    );
    await settle(tester);
    expect(find.textContaining('대기 셔츠'), findsNothing);
    expect(find.textContaining('전달 원피스'), findsNothing);
    expect(find.textContaining('수령 재킷'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(TdsTab), matching: find.text('진행 중')),
    );
    await settle(tester);
    expect(find.textContaining('전달 원피스'), findsOneWidget);
    expect(find.textContaining('수령 재킷'), findsNothing);

    final searchField = find.descendant(
      of: find.byType(TdsSearchField),
      matching: find.byType(EditableText),
    );
    await tester.enterText(searchField, '전달 원피스');
    await settle(tester);
    expect(find.text('전달 원피스 · 기본'), findsOneWidget);
    expect(find.textContaining('대기 셔츠'), findsNothing);

    await tester.enterText(searchField, '없는 상품');
    await settle(tester);
    expect(find.text('검색 결과가 없어요'), findsOneWidget);

    await tester.enterText(searchField, '');
    await settle(tester);
    await tester.tap(find.text('임시저장 1건'));
    await settle(tester);
    expect(find.text('요청 작성'), findsOneWidget);
    expect(find.text('작성 중'), findsOneWidget);
    expect(find.text('이전 요청으로 다시 작성'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
