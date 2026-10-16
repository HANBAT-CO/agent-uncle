import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/billing_models.dart';
import 'package:agent_uncle/local/domain/order_payment.dart';
import 'package:agent_uncle/local/presentation/billing.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart'
    show drainClose, drainWork, enter, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;
import '../support/request_workflow.dart';

Future<void> _pumpBillingPage(
  WidgetTester tester,
  Fixture fixture,
  Widget page,
) async {
  final services = AppServices(
    session: fixture.session,
    workspace: fixture.workspace,
    attachments: fixture.attachments,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, fixture.close());
  });
  await tester.pumpWidget(AppScope(services: services, child: branded(page)));
  await settle(tester);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

Map<String, String> _stringEntryIfPresent(String key, String? value) =>
    value == null ? const {} : {key: value};

Future<String> _prepareInvoice(Fixture fixture, {String? dueAt}) async {
  final requestId = await fixture.request();
  await fixture.accept(requestId);
  final paymentId = await fixture.workspace.recordFieldPayment({
    'requestId': requestId,
    'fundingSource': 'personal',
    'settlementKind': 'advance',
    'actualPaidAmount': 100000,
    'cashAllocatedAmount': 100000,
    'customerChargeAmount': 100000,
    'directPaidAmount': 0,
    'supplierFeeAmount': 0,
  });
  final invoiceId = await fixture.workspace.createInvoiceDraft({
    'paymentIds': [paymentId],
    'deliveryFeeAmount': 5000,
    'label': '10월 1차 청구',
    ..._stringEntryIfPresent('dueAt', dueAt),
  });
  final invoice = fixture.workspace.invoices.firstWhere(
    (row) => row.id == invoiceId,
  );
  await fixture.workspace.sendInvoice(invoice.id, invoice.version);
  final quantity = fixture.workspace.request(requestId)!.quantity;
  await shareResult(
    fixture,
    requestId,
    acquired: quantity,
    backorder: 0,
    needsReply: false,
  );
  final deliveryId = await deliverRequest(fixture, requestId, quantity);
  await receiveDelivery(fixture, deliveryId, quantity);
  return invoiceId;
}

void main() {
  testWidgets('현장 지급 페이지가 기록을 남기고 기존 지급을 보여 준다', (tester) async {
    final fixture = Fixture();
    late String requestId;
    await tester.runAsync(() async {
      await fixture.start();
      requestId = await fixture.request();
      await fixture.accept(requestId);
    });
    await _pumpBillingPage(
      tester,
      fixture,
      FieldPaymentPage(requestId: requestId),
    );

    expect(find.text('현장 지급'), findsOneWidget);
    await enter(tester, '실제 지급액', '105000');
    await enter(tester, '배분할 실제 현금', '70000');
    await enter(tester, '고객 부담액', '100000');
    await enter(tester, '고객 직접 결제액', '30000');
    await enter(tester, '도매처 수수료·차액', '5000');
    await enter(tester, '메모', '현장 확인 완료');
    await tapButton(tester, '현장 지급 기록');
    await settle(tester);

    expect(find.textContaining('이미 기록한 지급'), findsOneWidget);
    expect(find.textContaining('청구 반영'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('0원 현장 지급도 기록할 수 있다', (tester) async {
    final fixture = Fixture();
    late String requestId;
    await tester.runAsync(() async {
      await fixture.start();
      requestId = await fixture.request();
      await fixture.accept(requestId);
    });

    await _pumpBillingPage(
      tester,
      fixture,
      FieldPaymentPage(requestId: requestId),
    );

    await enter(tester, '실제 지급액', '0');
    await enter(tester, '메모', '0원 확인');
    await tapButton(tester, '현장 지급 기록');
    await settle(tester);

    final payment = fixture.workspace.fieldPayments.singleWhere(
      (row) => row.requestId == requestId,
    );
    expect(payment.actualPaidAmount, 0);
    expect(find.textContaining('이미 기록한 지급'), findsOneWidget);
    expect(find.text('0원 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('배분 완료된 지급도 기존 배분을 개별 수정할 수 있다', (tester) async {
    final fixture = Fixture();
    late String requestId;
    late String allocationId;
    await tester.runAsync(() async {
      await fixture.start();
      requestId = await fixture.request();
      await fixture.accept(requestId);
      final paymentId = await fixture.workspace.recordFieldPayment({
        'requestId': requestId,
        'fundingSource': 'personal',
        'settlementKind': 'advance',
        'actualPaidAmount': 100000,
        'cashAllocatedAmount': 100000,
        'customerChargeAmount': 100000,
        'directPaidAmount': 0,
        'supplierFeeAmount': 0,
      });
      allocationId = fixture.workspace.supplierPaymentAllocations
          .firstWhere((row) => row.paymentId == paymentId)
          .id;
    });

    await _pumpBillingPage(
      tester,
      fixture,
      FieldPaymentPage(requestId: requestId),
    );

    expect(find.text('이 배분 수정'), findsOneWidget);
    await tapButton(tester, '이 배분 수정');
    await settle(tester);

    expect(find.text('배분 수정 저장'), findsOneWidget);
    final allocationCash = find.widgetWithText(Field, '배분할 실제 현금').last;
    await tester.ensureVisible(allocationCash);
    await tester.enterText(
      find.descendant(of: allocationCash, matching: find.byType(EditableText)),
      '95000',
    );
    await enter(tester, '배분할 고객 부담액', '100000');
    await enter(tester, '배분할 직접 결제액', '0');
    await enter(tester, '배분할 수수료·차액', '5000');
    await enter(tester, '배분 메모', '배분 수정 완료');
    await tapButton(tester, '배분 수정 저장');
    await settle(tester);

    final allocation = fixture.workspace.supplierPaymentAllocations.firstWhere(
      (row) => row.id == allocationId,
    );
    expect(allocation.cashAllocatedAmount, 95000);
    expect(allocation.customerChargeAmount, 100000);
    expect(allocation.directPaidAmount, 0);
    expect(allocation.supplierFeeAmount, 5000);
    expect(allocation.note, '배분 수정 완료');
    expect(allocation.version, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 submitted 맵은 현장 지급 폼을 고정하지 않는다', (tester) async {
    final fixture = Fixture();
    late String requestId;
    await tester.runAsync(() async {
      await fixture.start();
      requestId = await fixture.request();
      await fixture.accept(requestId);
      await fixture.workspace
          .saveWorkflowInput('billing-field-payment:$requestId', {
            'actualPaidAmount': '120000',
            'note': '다시 입력',
            'operationId': 'stale-op',
            'submitted': <String, Object?>{},
          });
    });

    await _pumpBillingPage(
      tester,
      fixture,
      FieldPaymentPage(requestId: requestId),
    );

    expect(find.textContaining('전송 확인 중'), findsNothing);
    await enter(tester, '메모', '수정 후 재시도');
    await tapButton(tester, '현장 지급 기록');
    await settle(tester);

    expect(find.textContaining('이미 기록한 지급'), findsOneWidget);
    expect(find.text('수정 후 재시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('운영 계좌 송금 신고는 삼촌이 확인할 수 없고 운영 확인을 기다린다', (tester) async {
    final fixture = Fixture();
    late String invoiceId;
    await tester.runAsync(() async {
      await fixture.start();
      invoiceId = await _prepareInvoice(fixture);
      await fixture.session.signIn(fixture.retailer);
    });
    await _pumpBillingPage(
      tester,
      fixture,
      InvoiceDetailPage(invoiceId: invoiceId),
    );

    await enter(tester, '송금 금액', '60000');
    await tapButton(tester, '송금 알림 남기기');
    await settle(tester);

    expect(find.text('확인 대기'), findsWidgets);
    expect(find.text('1건 · 60,000원'), findsOneWidget);
    expect(fixture.workspace.invoiceReceipts.single.status, 'reported');

    await tester.pumpWidget(const SizedBox());
    await drainWork(tester, fixture.session.signIn(fixture.uncle));
    await tester.pumpWidget(
      AppScope(
        services: AppServices(
          session: fixture.session,
          workspace: fixture.workspace,
          attachments: fixture.attachments,
        ),
        child: branded(InvoiceDetailPage(invoiceId: invoiceId)),
      ),
    );
    await settle(tester);

    expect(find.text('회수 확인'), findsNothing);
    expect(find.text('송금 알림 반려'), findsNothing);
    expect(find.textContaining('운영 확인 대기'), findsWidgets);

    final invoice = fixture.workspace.invoices.firstWhere(
      (row) => row.id == invoiceId,
    );
    expect(invoice.confirmedReceiptAmount, 0);
    expect(invoice.remainingDueAmount, 105000);
    expect(fixture.workspace.invoiceReceipts.single.status, 'reported');
    expect(tester.takeException(), isNull);
  });

  testWidgets('청구 기한과 문의 해결은 유지하고 운영 계좌 신고 반려는 숨긴다', (tester) async {
    final fixture = Fixture();
    late String invoiceId;
    await tester.runAsync(() async {
      await fixture.start();
      invoiceId = await _prepareInvoice(
        fixture,
        dueAt: _dateOnly(DateTime.now().subtract(const Duration(days: 1))),
      );
      final invoice = fixture.workspace.invoices.firstWhere(
        (row) => row.id == invoiceId,
      );
      await fixture.session.signIn(fixture.retailer);
      await fixture.workspace.reportInvoiceReceipt({
        'invoiceId': invoice.id,
        'amount': 60000,
        'paidToId': platformPayeeId,
        'note': '오늘 송금했어요',
      });
      await fixture.workspace.flagInvoiceInquiry({
        'invoiceId': invoice.id,
        'note': '정산 금액 확인 부탁드려요',
      });
      await fixture.session.signIn(fixture.uncle);
    });

    await _pumpBillingPage(tester, fixture, const InvoiceListPage());

    expect(find.textContaining('기한 지남'), findsWidgets);
    expect(find.text('확인 대기'), findsOneWidget);
    expect(find.textContaining('1건'), findsWidgets);

    await tester.pumpWidget(
      AppScope(
        services: AppServices(
          session: fixture.session,
          workspace: fixture.workspace,
          attachments: fixture.attachments,
        ),
        child: branded(InvoiceDetailPage(invoiceId: invoiceId)),
      ),
    );
    await settle(tester);

    await enter(tester, '해결 메모(선택)', '확인 후 정리했어요');
    await tapButton(tester, '선택한 문의 해결');
    await settle(tester);
    expect(find.text('송금 알림 반려'), findsNothing);

    final inquiry = fixture.workspace.invoiceInquiries.single;
    final receipt = fixture.workspace.invoiceReceipts.single;
    expect(inquiry.status, 'resolved');
    expect(receipt.status, 'reported');
    expect(find.textContaining('기한 지남'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
