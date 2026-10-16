import 'package:agent_uncle/local/data/billing_commands.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/domain/billing_models.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/order_payment.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, Data>> _tables() => {
  for (final name in collections) name: <String, Data>{},
};

class _Fixture {
  _Fixture() : state = MutableWorkspace(_tables()) {
    _putAccount('retailer', '소매 상점', AppRole.retailer);
    _putAccount('owner', '담당 삼촌', AppRole.uncle);
    _putAccount('payer', '개인 대납 삼촌', AppRole.uncle);
    _putAccount('other', '다른 거래처 삼촌', AppRole.uncle);
    _putAccount('stranger', '관련 없는 팀원', AppRole.uncle);
    _putAccount('retailer-2', '다른 상점', AppRole.retailer);
    state.put('teams', 'team-a', {
      'status': 'active',
      'memberIds': ['owner', 'payer', 'other', 'stranger'],
      'ownerId': 'owner',
    });
    state.put('teamRounds', 'round-a', {
      'teamId': 'team-a',
      'status': 'active',
    });
    state.put('requests', 'req-1', {
      'retailerId': 'retailer',
      'uncleId': 'owner',
      'status': 'accepted',
      'product': '셔츠',
      'wholesaler': '동대문 1층',
      'createdAt': '2026-10-15T09:00:00.000',
      'updatedAt': '2026-10-15T09:00:00.000',
      'version': 0,
    });
    state.put('requests', 'req-2', {
      ...row('requests', 'req-1'),
      'retailerId': 'retailer-2',
      'uncleId': 'other',
    });
    for (final id in ['req-1', 'req-2']) {
      state.put('teamJobs', 'job:$id', {
        'requestId': id,
        'teamId': 'team-a',
        'roundId': 'round-a',
        'wholesalerName': '동대문 1층',
        'pickupAssigneeId': 'payer',
        'finalAssigneeId': textOf(row('requests', id), 'uncleId'),
      });
    }
  }

  final MutableWorkspace state;

  void _putAccount(String id, String name, AppRole role) {
    state.put('accounts', id, {
      'name': name,
      'nickname': name,
      'role': role.name,
      'complete': true,
    });
  }

  String run(String actor, String command, Data args) =>
      applyBilling(state, actor, command, args);

  Data row(String table, String id) => state.tables[table]![id]!;

  // 과거 삼촌 직접 수취 기록을 읽고 처리하는 호환 경로용 데이터.
  String legacyReceipt(Data args) {
    final id = newId();
    final invoiceId = textOf(args, 'invoiceId');
    state.put('invoiceReceipts', id, {
      ...args,
      'reporterId': 'retailer',
      'paidToId': args['paidToId'] ?? 'owner',
      'status': 'reported',
      'version': 0,
      'readers': ['retailer', 'owner', 'payer'],
    });
    final invoice = row('invoices', invoiceId);
    invoice['pendingReceiptCount'] =
        numberOf(invoice, 'pendingReceiptCount') + 1;
    invoice['pendingReceiptAmount'] =
        numberOf(invoice, 'pendingReceiptAmount') + numberOf(args, 'amount');
    return id;
  }

  void receiveOrder() => state.put('requests', 'req-1', {
    ...row('requests', 'req-1'),
    'status': 'completed',
    'quantity': 3,
    'acquired': 3,
    'delivered': 3,
    'received': 3,
  });

  String payment({Data values = const {}, String actor = 'owner'}) =>
      run(actor, 'billing.recordFieldPayment', {
        'requestId': 'req-1',
        'payerId': 'owner',
        'payeeId': 'owner',
        'teamId': 'team-a',
        'roundId': 'round-a',
        'fundingSource': 'personal',
        'settlementKind': 'advance',
        'actualPaidAmount': 100000,
        'cashAllocatedAmount': 100000,
        'customerChargeAmount': 100000,
        'directPaidAmount': 0,
        'supplierFeeAmount': 0,
        ...values,
      });

  String invoice(String paymentId, {int deliveryFee = 0, bool send = false}) {
    final id = run('owner', 'billing.createInvoiceDraft', {
      'paymentIds': [paymentId],
      'deliveryFeeAmount': deliveryFee,
    });
    if (send) {
      run('owner', 'billing.sendInvoice', {
        'invoiceId': id,
        'version': numberOf(row('invoices', id), 'version'),
      });
    }
    return id;
  }
}

void main() {
  test('같은 고객의 합산 지급도 선택한 배분만 청구하고 담당자에게만 공개한다', () {
    final f = _Fixture();
    f.row('requests', 'req-2')['retailerId'] = 'retailer';
    final payment = f.payment(
      values: {
        'payerId': 'payer',
        'cashAllocatedAmount': 60000,
        'customerChargeAmount': 60000,
      },
    );
    final firstAllocation =
        (f.row('fieldPayments', payment)['allocationIds'] as List).single
            as String;
    final secondAllocation = f.run('payer', 'billing.allocateSupplierPayment', {
      'paymentId': payment,
      'requestId': 'req-2',
      'cashAllocatedAmount': 40000,
      'customerChargeAmount': 40000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 0,
    });
    expect(
      () => f.run('payer', 'billing.createInvoiceDraft', {
        'allocationIds': [secondAllocation],
      }),
      throwsA(isA<AppFailure>()),
    );
    final invoice = f.run('other', 'billing.createInvoiceDraft', {
      'allocationIds': [secondAllocation],
    });
    expect(f.row('invoices', invoice)['principalAmount'], 40000);
    expect(f.row('invoices', invoice)['allocationIds'], [secondAllocation]);
    expect(
      textOf(f.row('supplierPaymentAllocations', firstAllocation), 'invoiceId'),
      isEmpty,
    );
    expect(
      f.row('invoices', invoice)['managerIds'],
      unorderedEquals(['owner', 'other']),
    );
    expect(
      f.row('invoices', invoice)['readers'],
      unorderedEquals(['owner', 'other']),
    );
    f.run('other', 'billing.sendInvoice', {'invoiceId': invoice});
    expect(
      f.row('invoices', invoice)['readers'],
      unorderedEquals(['owner', 'other', 'retailer']),
    );
  });

  test('추가 지급을 기존 초안에 모으면 새 담당자 권한을 반영하고 수정 후에도 유지한다', () {
    final f = _Fixture();
    f.row('requests', 'req-2')['retailerId'] = 'retailer';
    final invoice = f.invoice(f.payment());
    expect(f.row('invoices', invoice)['managerIds'], ['owner']);
    final nextPayment = f.payment(
      actor: 'other',
      values: {
        'requestId': 'req-2',
        'payerId': 'payer',
        'actualPaidAmount': 30000,
        'cashAllocatedAmount': 30000,
        'customerChargeAmount': 30000,
      },
    );
    expect(
      f.row('invoices', invoice)['fieldPaymentIds'],
      contains(nextPayment),
    );
    expect(f.row('invoices', invoice)['principalAmount'], 130000);
    expect(
      f.row('invoices', invoice)['managerIds'],
      unorderedEquals(['owner', 'other']),
    );
    expect(
      f.row('invoices', invoice)['readers'],
      unorderedEquals(['owner', 'other']),
    );
    f.run('other', 'billing.createInvoiceDraft', {
      'invoiceId': invoice,
      'label': '회차 청구',
    });
    expect(
      f.row('invoices', invoice)['managerIds'],
      unorderedEquals(['owner', 'other']),
    );
    expect(
      f.row('invoices', invoice)['readers'],
      unorderedEquals(['owner', 'other']),
    );
    expect(f.row('invoices', invoice)['principalAmount'], 130000);
  });

  test('재정산 중이거나 금액 미입력인 청구의 송금 신고는 막는다', () {
    final f = _Fixture()..receiveOrder();
    final id = f.invoice(f.payment(), send: true);
    for (final invalid in <Data>[
      {'requiresReconciliation': true},
      {'missingAmountCount': 1},
    ]) {
      f.row('invoices', id).addAll({
        'requiresReconciliation': false,
        'missingAmountCount': 0,
        ...invalid,
      });
      expect(
        () => f.run('retailer', 'billing.reportReceipt', {
          'invoiceId': id,
          'amount': 100000,
        }),
        throwsA(isA<AppFailure>()),
      );
      expect(f.state.tables['invoiceReceipts'], isEmpty);
    }
  });
  test('수령 후 운영 계좌 부분·전액 신고, 중복과 삼촌 직접 확인을 구분한다', () {
    final f = _Fixture();
    final invoice = f.invoice(f.payment(), send: true);
    Data args(int amount) => {'invoiceId': invoice, 'amount': amount};
    expect(
      () => f.run('retailer', 'billing.reportReceipt', args(100000)),
      throwsA(isA<AppFailure>()),
    );
    f.receiveOrder();
    expect(
      () => f.run('retailer-2', 'billing.reportReceipt', args(100000)),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => f.run('retailer', 'billing.reportReceipt', {
        ...args(100000),
        'paidToId': 'owner',
      }),
      throwsA(isA<AppFailure>()),
    );
    final first = f.run('retailer', 'billing.reportReceipt', args(60000));
    expect(f.row('invoiceReceipts', first)['paidToId'], platformPayeeId);
    expect(f.row('invoiceReceipts', first)['bankAccount'], platformBankAccount);
    Data projected() => projectOrderPayment(
      WorkspaceSnapshot(f.state.tables),
      Record('req-1', f.row('requests', 'req-1')),
    );
    expect(projected()['paymentReported'], isFalse);
    f.run('retailer', 'billing.reportReceipt', args(40000));
    expect(projected()['paymentReported'], isTrue);
    expect(projected()['paymentConfirmed'], isFalse);
    expect(
      () => f.run('retailer', 'billing.reportReceipt', args(1)),
      throwsA(isA<AppFailure>()),
    );
    for (final confirmed in [true, false]) {
      expect(
        () => f.run('owner', 'billing.confirmReceipt', {
          'receiptId': first,
          'confirmed': confirmed,
        }),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(f.row('invoices', invoice)['confirmedReceiptAmount'], 0);
  });

  test('수령 후에도 청구를 생성할 수 있고 지급 완료한 금액은 수정할 수 없다', () {
    final f = _Fixture()..receiveOrder();
    final invoice = f.invoice(f.payment(), send: true);
    f.row('invoices', invoice)['platformPayoutComplete'] = true;
    expect(
      () => f.run('owner', 'billing.addAdjustment', {
        'invoiceId': invoice,
        'kind': 'discount',
        'amount': 100,
      }),
      throwsA(isA<AppFailure>()),
    );
  });
  test('개인 대납과 직접 결제를 분리해 기록한다', () {
    final f = _Fixture();

    final paymentId = f.run('owner', 'billing.recordFieldPayment', {
      'requestId': 'req-1',
      'payerId': 'payer',
      'payeeId': 'owner',
      'teamId': 'team-a',
      'roundId': 'round-a',
      'fundingSource': 'personal',
      'settlementKind': 'advance',
      'wholesaler': '동대문 1층',
      'actualPaidAmount': 105000,
      'cashAllocatedAmount': 105000,
      'customerChargeAmount': 100000,
      'directPaidAmount': 30000,
      'supplierFeeAmount': 5000,
      'note': '현장 차액 5천원',
    });

    final payment = FieldPaymentRecord(
      paymentId,
      f.row('fieldPayments', paymentId),
    );
    expect(payment.billableAmount, 70000);
    expect(payment.customerPaidDirectly, isTrue);
    expect(payment.reimbursementId, isNotEmpty);

    final reimbursement = ReimbursementRecord(
      payment.reimbursementId,
      f.row('reimbursements', payment.reimbursementId),
    );
    expect(reimbursement.kind, 'payer_reimbursement');
    expect(reimbursement.totalAmount, 105000);
    expect(reimbursement.fromId, 'owner');
    expect(reimbursement.toId, 'payer');
  });

  test('부분 회수 뒤 남은 금액을 계산한다', () {
    final f = _Fixture();

    final paymentId = f.run('owner', 'billing.recordFieldPayment', {
      'requestId': 'req-1',
      'teamId': 'team-a',
      'roundId': 'round-a',
      'fundingSource': 'personal',
      'settlementKind': 'advance',
      'actualPaidAmount': 100000,
      'cashAllocatedAmount': 100000,
      'customerChargeAmount': 100000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 0,
    });

    final invoiceId = f.run('owner', 'billing.createInvoiceDraft', {
      'paymentIds': [paymentId],
      'deliveryFeeAmount': 5000,
      'label': '10월 1차 청구',
    });
    final createdInvoice = InvoiceRecord(
      invoiceId,
      f.row('invoices', invoiceId),
    );
    expect(createdInvoice.adjustedTotalAmount, 105000);

    f.run('owner', 'billing.sendInvoice', {
      'invoiceId': invoiceId,
      'version': createdInvoice.version,
    });

    final receiptId = f.legacyReceipt({
      'invoiceId': invoiceId,
      'amount': 60000,
      'note': '1차 송금',
    });

    f.run('owner', 'billing.confirmReceipt', {
      'receiptId': receiptId,
      'version': 0,
    });

    final invoice = InvoiceRecord(invoiceId, f.row('invoices', invoiceId));
    expect(invoice.status, 'partial');
    expect(invoice.confirmedReceiptAmount, 60000);
    expect(invoice.remainingDueAmount, 45000);
  });

  test('감액 뒤 환급 필요액과 고객 환급 정산을 만든다', () {
    final f = _Fixture();

    final paymentId = f.run('owner', 'billing.recordFieldPayment', {
      'requestId': 'req-1',
      'teamId': 'team-a',
      'roundId': 'round-a',
      'fundingSource': 'personal',
      'settlementKind': 'advance',
      'actualPaidAmount': 100000,
      'cashAllocatedAmount': 100000,
      'customerChargeAmount': 100000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 0,
    });
    final invoiceId = f.run('owner', 'billing.createInvoiceDraft', {
      'paymentIds': [paymentId],
      'deliveryFeeAmount': 0,
    });
    final invoiceBeforeSend = InvoiceRecord(
      invoiceId,
      f.row('invoices', invoiceId),
    );
    f.run('owner', 'billing.sendInvoice', {
      'invoiceId': invoiceId,
      'version': invoiceBeforeSend.version,
    });
    final receiptId = f.legacyReceipt({
      'invoiceId': invoiceId,
      'amount': 100000,
    });
    f.run('owner', 'billing.confirmReceipt', {
      'receiptId': receiptId,
      'version': 0,
    });

    f.run('owner', 'billing.addAdjustment', {
      'invoiceId': invoiceId,
      'kind': 'discount',
      'amount': 20000,
      'reason': '품절 금액 감액',
    });

    final invoice = InvoiceRecord(invoiceId, f.row('invoices', invoiceId));
    expect(invoice.adjustedTotalAmount, 80000);
    expect(invoice.refundRequiredAmount, 20000);
    expect(invoice.status, 'collected');
    expect(invoice.remainingDueAmount, 0);

    final refund = f.state.tables['reimbursements']!.values.firstWhere(
      (row) =>
          textOf(row, 'invoiceId') == invoiceId &&
          textOf(row, 'kind') == 'customer_refund',
    );
    final refundId = textOf(refund, 'id');
    expect(numberOf(refund, 'totalAmount'), 20000);

    f.run('owner', 'billing.settleReimbursement', {
      'invoiceId': invoiceId,
      'reimbursementId': refundId,
      'version': numberOf(refund, 'version'),
      'amount': 5000,
      'note': '1차 환급',
    });

    final updatedInvoice = InvoiceRecord(
      invoiceId,
      f.row('invoices', invoiceId),
    );
    final updatedRefund = ReimbursementRecord(
      refundId,
      f.row('reimbursements', refundId),
    );
    expect(updatedRefund.status, 'partial');
    expect(updatedRefund.settledAmount, 5000);
    expect(updatedInvoice.confirmedRefundAmount, 5000);
    expect(updatedInvoice.refundRequiredAmount, 15000);
    expect(updatedInvoice.remainingDueAmount, 0);
  });

  test('미배분 개인 현금은 반환 대상으로 남고 팀 수취 환불은 개인 반환이 아니다', () {
    final f = _Fixture();
    final id = f.payment(
      values: {
        'payerId': 'payer',
        'cashAllocatedAmount': null,
        'customerChargeAmount': null,
        'directPaidAmount': null,
        'supplierFeeAmount': null,
      },
    );
    final payment = FieldPaymentRecord(id, f.row('fieldPayments', id));
    expect(payment.hasMissingAmounts, true);
    expect(payment.unallocatedAmount, 100000);
    expect(
      f.row('reimbursements', payment.reimbursementId)['totalAmount'],
      100000,
    );
    f.run('owner', 'billing.recordSupplierRefund', {
      'paymentId': id,
      'amount': 20000,
      'actualRecipientId': 'owner',
    });
    expect(
      f.row('reimbursements', payment.reimbursementId)['settledAmount'],
      0,
    );
    f.run('payer', 'billing.recordSupplierRefund', {
      'paymentId': id,
      'amount': 10000,
      'actualRecipientId': 'payer',
    });
    expect(
      f.row('reimbursements', payment.reimbursementId)['settledAmount'],
      10000,
    );
    expect(
      () => f.run('owner', 'billing.recordSupplierRefund', {
        'paymentId': id,
        'amount': 80000,
        'actualRecipientId': 'payer',
      }),
      throwsA(isA<AppFailure>()),
    );
  });

  test('반환 후 개인이 받은 도매 환불은 팀이 회수할 돈으로 남는다', () {
    final f = _Fixture();
    final id = f.payment(values: {'payerId': 'payer'});
    final reimbursementId = textOf(
      f.row('fieldPayments', id),
      'reimbursementId',
    );
    f.run('owner', 'billing.settleReimbursement', {
      'reimbursementId': reimbursementId,
      'amount': 100000,
    });
    f.run('payer', 'billing.recordSupplierRefund', {
      'paymentId': id,
      'amount': 20000,
      'actualRecipientId': 'payer',
    });
    expect(f.row('reimbursements', 'team-recovery:$id')['totalAmount'], 20000);
    expect(f.row('reimbursements', reimbursementId)['settledAmount'], 100000);
  });

  test('미입력 청구는 발행 차단하고 명시적인 직접 결제 0원은 대납에 넣지 않는다', () {
    final f = _Fixture();
    final missing = f.payment(
      values: {
        'cashAllocatedAmount': null,
        'customerChargeAmount': null,
        'directPaidAmount': null,
        'supplierFeeAmount': null,
      },
    );
    final draft = f.invoice(missing);
    expect(f.row('invoices', draft)['missingAmountCount'], 1);
    expect(
      () => f.run('owner', 'billing.sendInvoice', {'invoiceId': draft}),
      throwsA(isA<AppFailure>()),
    );
    final direct = _Fixture();
    final payment = direct.payment(
      values: {
        'actualPaidAmount': 0,
        'cashAllocatedAmount': 0,
        'customerChargeAmount': 30000,
        'directPaidAmount': 30000,
        'settlementKind': 'direct',
      },
    );
    final invoice = direct.invoice(payment, send: true);
    expect(direct.row('invoices', invoice)['principalAmount'], 0);
    expect(direct.row('invoices', invoice)['adjustedTotalAmount'], 0);
  });

  test('다른 팀원은 지급 ID를 알아도 배분하거나 청구할 수 없다', () {
    final f = _Fixture();
    final payment = f.payment();
    expect(
      f.row('fieldPayments', payment)['readers'],
      isNot(contains('stranger')),
    );
    expect(
      () => f.run('stranger', 'billing.allocateSupplierPayment', {
        'paymentId': payment,
        'requestId': 'req-1',
        'cashAllocatedAmount': 0,
        'customerChargeAmount': 1,
        'directPaidAmount': 0,
        'supplierFeeAmount': 0,
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => f.run('stranger', 'billing.createInvoiceDraft', {
        'paymentIds': [payment],
      }),
      throwsA(isA<AppFailure>()),
    );
    final invoice = f.invoice(payment, send: true);
    expect(
      f.row('invoices', invoice)['readers'],
      unorderedEquals(['owner', 'retailer']),
    );
  });

  test('여러 도매처 요청은 선택한 도매처의 실제 배정 범위에서만 지급한다', () {
    final f = _Fixture();
    f.row('requests', 'req-1')['wholesalers'] = [
      {'wholesaler': '동대문 1층'},
      {'wholesaler': '남평화 2층'},
    ];
    f.state.put('teamJobs', 'job:second-wholesaler', {
      'requestId': 'req-1',
      'teamId': 'team-a',
      'roundId': 'round-a',
      'wholesalerName': '남평화 2층',
      'pickupAssigneeId': 'other',
      'finalAssigneeId': 'owner',
    });
    expect(
      () => f.payment(
        actor: 'payer',
        values: {'payerId': 'payer', 'wholesaler': '남평화 2층'},
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(f.state.tables['fieldPayments'], isEmpty);
    final payment = f.payment(
      actor: 'other',
      values: {'payerId': 'other', 'wholesaler': '남평화 2층'},
    );
    expect(f.row('fieldPayments', payment)['wholesaler'], '남평화 2층');
    expect(
      f.row('fieldPayments', payment)['readers'],
      isNot(contains('payer')),
    );
    expect(
      () => f.payment(values: {'wholesaler': '요청에 없는 도매처'}),
      throwsA(isA<AppFailure>()),
    );
  });

  test('0원 확인은 미입력과 다르고 직접 결제 전환은 기존 청구액을 숨기지 않는다', () {
    final f = _Fixture();
    final payment = f.payment(
      values: {
        'actualPaidAmount': 0,
        'cashAllocatedAmount': 0,
        'customerChargeAmount': 0,
        'directPaidAmount': 0,
        'supplierFeeAmount': 0,
      },
    );
    final invoice = f.invoice(payment, send: true);
    expect(f.row('invoices', invoice)['missingAmountCount'], 0);
    expect(f.row('invoices', invoice)['remainingDueAmount'], 0);

    final payable = f.payment();
    expect(
      () => f.run('owner', 'billing.recordFieldPayment', {
        'id': payable,
        'requestId': 'req-1',
        'version': numberOf(f.row('fieldPayments', payable), 'version'),
        'settlementKind': 'direct',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(f.row('fieldPayments', payable)['settlementKind'], 'advance');
    expect(f.row('fieldPayments', payable)['customerChargeAmount'], 100000);
  });

  test('동일 도매처 지급을 배정된 여러 고객에게 나누고 각 고객 장부를 분리한다', () {
    final f = _Fixture();
    final payment = f.payment(
      actor: 'payer',
      values: {
        'payerId': 'payer',
        'cashAllocatedAmount': 60000,
        'customerChargeAmount': 60000,
      },
    );
    final allocation = f.run('payer', 'billing.allocateSupplierPayment', {
      'paymentId': payment,
      'requestId': 'req-2',
      'cashAllocatedAmount': 40000,
      'customerChargeAmount': 45000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 5000,
    });
    final invoice = f.run('other', 'billing.createInvoiceDraft', {
      'allocationIds': [allocation],
    });
    expect(f.row('invoices', invoice)['principalAmount'], 45000);
    expect(
      f.row('invoices', invoice)['managerIds'],
      unorderedEquals(['owner', 'other']),
    );
    expect(f.row('invoices', invoice)['readers'], isNot(contains('payer')));
    expect(f.row('fieldPayments', payment)['unallocatedAmount'], 0);
    f.row('requests', 'req-2')['wholesaler'] = '다른 도매처';
    expect(
      () => f.run('payer', 'billing.allocateSupplierPayment', {
        'paymentId': payment,
        'requestId': 'req-2',
        'cashAllocatedAmount': 0,
        'customerChargeAmount': 0,
        'directPaidAmount': 0,
        'supplierFeeAmount': 0,
      }),
      throwsA(isA<AppFailure>()),
    );
  });

  test('추가 픽업 지급은 같은 초안에 합쳐지고 발행 후 금액은 덮어쓰지 않는다', () {
    final f = _Fixture();
    final first = f.payment();
    final invoice = f.invoice(first, deliveryFee: 5000);
    f.payment(
      values: {
        'actualPaidAmount': 10000,
        'cashAllocatedAmount': 10000,
        'customerChargeAmount': 10000,
      },
    );
    expect(f.row('invoices', invoice)['principalAmount'], 110000);
    expect(f.row('invoices', invoice)['deliveryFeeAmount'], 5000);
    f.run('owner', 'billing.sendInvoice', {'invoiceId': invoice});
    expect(
      () => f.payment(values: {'id': first, 'actualPaidAmount': 200000}),
      throwsA(isA<AppFailure>()),
    );
  });

  test('송금 알림 반려와 문의 해결은 회수를 늘리지 않고 물류에 영향을 주지 않는다', () {
    final f = _Fixture();
    final invoice = f.invoice(f.payment(), send: true);
    final receipt = f.legacyReceipt({'invoiceId': invoice, 'amount': 60000});
    expect(f.row('invoices', invoice)['pendingReceiptCount'], 1);
    expect(f.row('invoices', invoice)['pendingReceiptAmount'], 60000);
    expect(f.row('invoices', invoice)['confirmedReceiptAmount'], 0);
    f.run('owner', 'billing.confirmReceipt', {
      'receiptId': receipt,
      'confirmed': false,
    });
    expect(f.row('invoices', invoice)['pendingReceiptCount'], 0);
    expect(f.row('invoices', invoice)['remainingDueAmount'], 100000);
    final inquiry = f.run('retailer', 'billing.flagInvoiceInquiry', {
      'invoiceId': invoice,
      'note': '대납액 확인 부탁드려요',
    });
    expect(f.row('invoices', invoice)['inquiryOpenCount'], 1);
    f.run('owner', 'billing.resolveInvoiceInquiry', {'inquiryId': inquiry});
    expect(f.row('invoices', invoice)['inquiryOpenCount'], 0);
    expect(f.row('requests', 'req-1')['status'], 'accepted');
  });

  test('개인 대납자가 직접 받은 돈은 청구 원금만 반환하고 배달비는 팀 회수로 남긴다', () {
    final f = _Fixture();
    final payment = f.payment(
      values: {
        'payerId': 'payer',
        'actualPaidAmount': 105000,
        'cashAllocatedAmount': 105000,
        'customerChargeAmount': 70000,
      },
    );
    final invoice = f.invoice(payment, deliveryFee: 5000, send: true);
    for (final amount in [40000, 35000]) {
      final receipt = f.legacyReceipt({
        'invoiceId': invoice,
        'paidToId': 'payer',
        'amount': amount,
      });
      f.run('owner', 'billing.confirmReceipt', {'receiptId': receipt});
    }
    final reimbursement = f.row(
      'reimbursements',
      'payer-reimbursement:$payment',
    );
    expect(reimbursement['settledAmount'], 70000);
    expect(reimbursement['totalAmount'], 105000);
    final recovery = f.row('reimbursements', 'team-recovery:$invoice:payer');
    expect(recovery['totalAmount'], 5000);
    expect(recovery['readers'], contains('payer'));
    expect(f.row('invoices', invoice)['confirmedReceiptAmount'], 75000);
    expect(f.row('requests', 'req-1')['status'], 'accepted');
  });

  test('개인 대납 직접 회수는 다른 고객 몫과 이미 회수한 원금을 재반환하지 않는다', () {
    final f = _Fixture();
    final payment = f.payment(
      values: {
        'payerId': 'payer',
        'actualPaidAmount': 100000,
        'cashAllocatedAmount': 60000,
        'customerChargeAmount': 60000,
      },
    );
    f.run('payer', 'billing.allocateSupplierPayment', {
      'paymentId': payment,
      'requestId': 'req-2',
      'cashAllocatedAmount': 40000,
      'customerChargeAmount': 40000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 0,
    });
    final allocation = f.state.tables['supplierPaymentAllocations']!.entries
        .firstWhere((row) => row.value['requestId'] == 'req-1');
    final invoice = f.run('owner', 'billing.createInvoiceDraft', {
      'allocationIds': [allocation.key],
      'deliveryFeeAmount': 5000,
    });
    f.run('owner', 'billing.sendInvoice', {'invoiceId': invoice});
    final first = f.legacyReceipt({'invoiceId': invoice, 'amount': 60000});
    f.run('owner', 'billing.confirmReceipt', {'receiptId': first});
    final second = f.legacyReceipt({
      'invoiceId': invoice,
      'paidToId': 'payer',
      'amount': 5000,
    });
    f.run('owner', 'billing.confirmReceipt', {'receiptId': second});
    expect(
      f.row('reimbursements', 'payer-reimbursement:$payment')['settledAmount'],
      0,
    );
    expect(
      f.row('reimbursements', 'team-recovery:$invoice:payer')['totalAmount'],
      5000,
    );
  });

  test('청구기한은 실제 날짜여야 하고 조회 시 지난 기한을 구분한다', () {
    final f = _Fixture();
    final payment = f.payment();
    expect(
      () => f.run('owner', 'billing.createInvoiceDraft', {
        'paymentIds': [payment],
        'dueAt': '2026-02-30',
      }),
      throwsA(isA<AppFailure>()),
    );
    final invoice = f.run('owner', 'billing.createInvoiceDraft', {
      'paymentIds': [payment],
      'dueAt': '2020-01-01',
    });
    expect(InvoiceRecord(invoice, f.row('invoices', invoice)).isOverdue, false);
    f.run('owner', 'billing.sendInvoice', {'invoiceId': invoice});
    expect(InvoiceRecord(invoice, f.row('invoices', invoice)).isOverdue, true);
  });

  test('발행 전 단일 배분의 금액 확인을 수정하면 지급과 초안이 함께 갱신된다', () {
    final f = _Fixture();
    final payment = f.payment(
      values: {'settlementKind': 'review', 'payerId': 'payer'},
    );
    final invoice = f.invoice(payment, deliveryFee: 5000);
    final allocationId =
        (f.row('fieldPayments', payment)['allocationIds'] as List).single;
    f.payment(
      values: {
        'id': payment,
        'version': numberOf(f.row('fieldPayments', payment), 'version'),
        'payerId': 'payer',
        'actualPaidAmount': 80000,
        'cashAllocatedAmount': 80000,
        'customerChargeAmount': 80000,
      },
    );
    expect(f.row('fieldPayments', payment)['allocationIds'], [allocationId]);
    expect(f.row('fieldPayments', payment)['unallocatedAmount'], 0);
    expect(
      f.row('supplierPaymentAllocations', allocationId)['invoiceId'],
      invoice,
    );
    expect(f.row('invoices', invoice)['principalAmount'], 80000);
    expect(f.row('invoices', invoice)['adjustedTotalAmount'], 85000);
    expect(
      f.row('reimbursements', 'payer-reimbursement:$payment')['totalAmount'],
      80000,
    );
    f.run('owner', 'billing.sendInvoice', {'invoiceId': invoice});
    expect(f.row('invoices', invoice)['status'], 'sent');
  });

  test('여러 고객 배분의 개별 수정은 최신 버전과 원래 요청을 유지한다', () {
    final f = _Fixture();
    final payment = f.payment(
      values: {
        'payerId': 'payer',
        'cashAllocatedAmount': 60000,
        'customerChargeAmount': 60000,
      },
    );
    final allocation = f.run('payer', 'billing.allocateSupplierPayment', {
      'paymentId': payment,
      'requestId': 'req-2',
      'cashAllocatedAmount': 40000,
      'customerChargeAmount': 40000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 0,
    });
    final invoice = f.run('other', 'billing.createInvoiceDraft', {
      'allocationIds': [allocation],
    });
    final args = <String, dynamic>{
      'paymentId': payment,
      'allocationId': allocation,
      'version': numberOf(f.row('fieldPayments', payment), 'version'),
      'allocationVersion': numberOf(
        f.row('supplierPaymentAllocations', allocation),
        'version',
      ),
      'requestId': 'req-2',
      'cashAllocatedAmount': 30000,
      'customerChargeAmount': 35000,
      'directPaidAmount': 0,
      'supplierFeeAmount': 5000,
    };
    expect(
      () => f.run('payer', 'billing.allocateSupplierPayment', {
        ...args,
        'requestId': 'req-1',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => f.run('payer', 'billing.allocateSupplierPayment', {
        ...args,
        'cashAllocatedAmount': 40001,
      }),
      throwsA(isA<AppFailure>()),
    );
    f.run('payer', 'billing.allocateSupplierPayment', args);
    expect(f.row('fieldPayments', payment)['unallocatedAmount'], 10000);
    expect(f.row('invoices', invoice)['principalAmount'], 35000);
    expect(
      f.row('supplierPaymentAllocations', allocation)['requestId'],
      'req-2',
    );
    expect(
      () => f.run('payer', 'billing.allocateSupplierPayment', args),
      throwsA(isA<AppFailure>()),
    );
    f.run('owner', 'billing.recordFieldPayment', {
      'id': payment,
      'requestId': 'req-1',
      'version': numberOf(f.row('fieldPayments', payment), 'version'),
      'actualPaidAmount': 90000,
    });
    f.run('other', 'billing.sendInvoice', {'invoiceId': invoice});
    expect(
      () => f.run('payer', 'billing.allocateSupplierPayment', {
        ...args,
        'version': numberOf(f.row('fieldPayments', payment), 'version'),
        'allocationVersion': numberOf(
          f.row('supplierPaymentAllocations', allocation),
          'version',
        ),
      }),
      throwsA(isA<AppFailure>()),
    );
  });
}
