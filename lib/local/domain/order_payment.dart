import 'models.dart';

const platformBankName = '우리은행';
const platformBankAccount = '1002-364-917884';
const platformBankHolder = '강이수';
const platformPayeeId = 'platform';
const bankProfileFields = ['bankName', 'bankAccount', 'bankHolder'];

Data withoutBankAccount(Data data) => {
  for (final entry in data.entries)
    if (!bankProfileFields.contains(entry.key)) entry.key: entry.value,
};

/// 합산 지급에 다른 소매 주문이 포함돼도 해당 청구서의 배분만 연결한다.
List<String> invoiceRequestIds(WorkspaceSnapshot snapshot, Record invoice) {
  final allocations = snapshot.all('supplierPaymentAllocations');
  final linked = allocations.where((row) => row.s('invoiceId') == invoice.id);
  return <String>{
    for (final row in linked) row.s('requestId'),
    for (final payment in snapshot.all('fieldPayments'))
      if (invoice.list('fieldPaymentIds').contains(payment.id) &&
          payment.s('retailerId') == invoice.s('retailerId') &&
          !linked.any((row) => row.s('paymentId') == payment.id))
        payment.s('requestId'),
  }.where((id) => id.isNotEmpty).toList()..sort();
}

Data projectOrderPayment(WorkspaceSnapshot snapshot, Record request) {
  final invoices = snapshot
      .all('invoices')
      .where(
        (invoice) => invoiceRequestIds(snapshot, invoice).contains(request.id),
      )
      .toList();
  final unbilled =
      snapshot
          .all('supplierPaymentAllocations')
          .any(
            (row) =>
                row.s('requestId') == request.id && row.s('invoiceId').isEmpty,
          ) ||
      snapshot
          .all('fieldPayments')
          .any(
            (row) =>
                row.s('requestId') == request.id &&
                (row.n('unallocatedAmount') > 0 ||
                    row.s('invoiceId').isEmpty &&
                        !snapshot
                            .all('supplierPaymentAllocations')
                            .any(
                              (allocation) =>
                                  allocation.s('paymentId') == row.id &&
                                  allocation.s('invoiceId').isNotEmpty,
                            )),
          );
  final issued =
      invoices.isNotEmpty &&
      !unbilled &&
      invoices.every(
        (row) =>
            row.s('status') != 'draft' &&
            row.n('missingAmountCount') == 0 &&
            !row.b('requiresReconciliation'),
      );
  return {
    ...request.data,
    'paymentInvoiceIds': [
      for (final row in invoices)
        if (row.s('status') != 'draft') row.id,
    ],
    'paymentReported':
        issued &&
        invoices.every(
          (row) =>
              row.n('reportedReceiptAmount') >= row.n('adjustedTotalAmount'),
        ),
    'paymentConfirmed':
        issued &&
        invoices.every(
          (row) =>
              row.n('confirmedReceiptAmount') >= row.n('adjustedTotalAmount'),
        ),
    'platformPayoutComplete':
        issued && invoices.every((row) => row.b('platformPayoutComplete')),
  };
}
