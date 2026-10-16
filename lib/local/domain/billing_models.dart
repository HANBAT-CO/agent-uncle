import 'models.dart';

const billingCollections = [
  'fieldPayments',
  'supplierPaymentAllocations',
  'supplierRefunds',
  'invoices',
  'invoiceAdjustments',
  'invoiceReceipts',
  'invoiceInquiries',
  'reimbursements',
];

const billingCommands = [
  'billing.recordFieldPayment',
  'billing.allocateSupplierPayment',
  'billing.createInvoiceDraft',
  'billing.sendInvoice',
  'billing.sendInvoices',
  'billing.addAdjustment',
  'billing.reportReceipt',
  'billing.confirmReceipt',
  'billing.recordSupplierRefund',
  'billing.flagInvoiceInquiry',
  'billing.resolveInvoiceInquiry',
  'billing.settleReimbursement',
];

const invoiceStatuses = ['draft', 'sent', 'partial', 'collected'];
const invoiceAdjustmentKinds = ['charge', 'discount', 'cancel'];
const invoiceReceiptStatuses = ['reported', 'confirmed', 'rejected'];
const invoiceInquiryStatuses = ['open', 'resolved'];
const reimbursementKinds = [
  'payer_reimbursement',
  'customer_refund',
  'team_recovery',
];
const reimbursementStatuses = ['open', 'partial', 'settled'];
const fieldPaymentFundingSources = ['personal', 'team_fund', 'unknown'];
const fieldPaymentSettlementKinds = ['advance', 'direct', 'review'];

List<String> billingReadersOf(Data data) => stringsOf(data, 'readers');
List<String> fieldPaymentAllocationIdsOf(Data data) =>
    stringsOf(data, 'allocationIds');
List<String> invoiceFieldPaymentIdsOf(Data data) =>
    stringsOf(data, 'fieldPaymentIds');
List<String> invoiceAllocationIdsOf(Data data) =>
    stringsOf(data, 'allocationIds');
List<String> reimbursementSettlementIdsOf(Data data) =>
    stringsOf(data, 'settlementIds');

List<Data> billingRowsOf(Data data, String key) => [
  for (final value in (data[key] as List? ?? const []))
    if (value is Map) Map<String, Object?>.from(value),
];

int signedAdjustmentAmount(Data data) {
  final amount = numberOf(data, 'amount');
  final kind = textOf(data, 'kind');
  return switch (kind) {
    'charge' => amount,
    'discount' || 'cancel' => -amount,
    _ => 0,
  };
}

int allocationActualAmount(Data data) {
  final explicitCash = nullableNumberOf(data, 'cashAllocatedAmount');
  if (explicitCash != null) return explicitCash;
  return numberOf(data, 'customerChargeAmount') +
      numberOf(data, 'supplierFeeAmount');
}

int billablePrincipalAmount(Data data) =>
    (numberOf(data, 'customerChargeAmount') -
            numberOf(data, 'directPaidAmount'))
        .clamp(0, 0x7fffffff);

String invoiceGroupKeyOf(Data data) => [
  textOf(data, 'retailerId'),
  textOf(data, 'teamId'),
  textOf(data, 'roundId'),
  textOf(data, 'payeeId'),
].join('|');

String invoiceStatusLabel(String status) => switch (status) {
  'draft' => '청구 전',
  'sent' => '청구 완료',
  'partial' => '일부 회수',
  'collected' => '전액 회수',
  _ => '확인 필요',
};

String invoiceAdjustmentLabel(String kind) => switch (kind) {
  'charge' => '추가 청구',
  'discount' => '감액',
  'cancel' => '취소·환급',
  _ => '조정',
};

String invoiceInquiryLabel(String status) => switch (status) {
  'resolved' => '문의 해결',
  _ => '금액 문의',
};

String reimbursementKindLabel(String kind) => switch (kind) {
  'payer_reimbursement' => '개인 대납 반환',
  'customer_refund' => '고객 환급',
  'team_recovery' => '팀 회수',
  _ => '정산',
};

String receiptStatusLabel(String status) => switch (status) {
  'reported' => '입금 확인 필요',
  'confirmed' => '회수 확인',
  'rejected' => '반려됨',
  _ => '확인 필요',
};

String billingMoney(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}$buffer원';
}

class FieldPaymentRecord extends Record {
  const FieldPaymentRecord(super.id, super.data);

  String get requestId => s('requestId');
  String get retailerId => s('retailerId');
  String get uncleId => s('uncleId');
  String get teamId => s('teamId');
  String get roundId => s('roundId');
  String get payeeId => s('payeeId');
  String get payerId => s('payerId');
  String get wholesaler => s('wholesaler');
  String get note => s('note');
  String get fundingSource => s('fundingSource', 'unknown');
  String get settlementKind => s('settlementKind', 'review');
  String get invoiceId => s('invoiceId');
  String get reimbursementId => s('reimbursementId');
  int get actualPaidAmount => n('actualPaidAmount');
  int get cashAllocatedAmount => n('cashAllocatedAmount');
  int get allocatedAmount => n('allocatedAmount');
  int get unallocatedAmount => n('unallocatedAmount');
  int get customerChargeAmount => n('customerChargeAmount');
  int get supplierFeeAmount => n('supplierFeeAmount');
  int get directPaidAmount => n('directPaidAmount');
  int get billableAmount => billablePrincipalAmount(data);
  List<String> get allocationIds => fieldPaymentAllocationIdsOf(data);
  bool get customerPaidDirectly =>
      directPaidAmount > 0 || settlementKind == 'direct';
  bool get cashAllocatedAmountMissing =>
      flagOf(data, 'cashAllocatedAmountMissing');
  bool get customerChargeAmountMissing =>
      flagOf(data, 'customerChargeAmountMissing');
  bool get directPaidAmountMissing => flagOf(data, 'directPaidAmountMissing');
  bool get supplierFeeAmountMissing => flagOf(data, 'supplierFeeAmountMissing');
  bool get hasMissingAmounts =>
      cashAllocatedAmountMissing ||
      customerChargeAmountMissing ||
      directPaidAmountMissing ||
      supplierFeeAmountMissing;
  bool get needsBillingReview =>
      settlementKind == 'review' || unallocatedAmount > 0;
}

class SupplierPaymentAllocationRecord extends Record {
  const SupplierPaymentAllocationRecord(super.id, super.data);

  String get paymentId => s('paymentId');
  String get requestId => s('requestId');
  String get retailerId => s('retailerId');
  String get teamId => s('teamId');
  String get roundId => s('roundId');
  String get payeeId => s('payeeId');
  String get payerId => s('payerId');
  String get invoiceId => s('invoiceId');
  String get note => s('note');
  int get cashAllocatedAmount => allocationActualAmount(data);
  int get customerChargeAmount => n('customerChargeAmount');
  int get directPaidAmount => n('directPaidAmount');
  int get supplierFeeAmount => n('supplierFeeAmount');
  int get allocatedAmount => allocationActualAmount(data);
  int get billableAmount => billablePrincipalAmount(data);
}

class SupplierRefundRecord extends Record {
  const SupplierRefundRecord(super.id, super.data);

  String get paymentId => s('paymentId');
  String get invoiceId => s('invoiceId');
  String get actualRecipientId => s('actualRecipientId');
  String get reimbursementId => s('reimbursementId');
  int get amount => n('amount');
  String get note => s('note');
}

class InvoiceRecord extends Record {
  const InvoiceRecord(super.id, super.data);

  String get retailerId => s('retailerId');
  String get payeeId => s('payeeId');
  String get teamId => s('teamId');
  String get roundId => s('roundId');
  String get status => s('status', 'draft');
  String get label => s('label');
  int get principalAmount => n('principalAmount');
  int get deliveryFeeAmount => n('deliveryFeeAmount');
  int get baseTotalAmount => n('baseTotalAmount');
  int get adjustmentTotalAmount => n('adjustmentTotalAmount');
  int get adjustedTotalAmount => n('adjustedTotalAmount');
  int get reportedReceiptAmount => n('reportedReceiptAmount');
  int get pendingReceiptCount => n('pendingReceiptCount');
  int get pendingReceiptAmount => n('pendingReceiptAmount');
  int get confirmedReceiptAmount => n('confirmedReceiptAmount');
  int get confirmedRefundAmount => n('confirmedRefundAmount');
  int get remainingDueAmount => n('remainingDueAmount');
  int get refundRequiredAmount => n('refundRequiredAmount');
  int get inquiryOpenCount => n('inquiryOpenCount');
  int get missingAmountCount => n('missingAmountCount');
  String get dueAt => s('dueAt');
  bool get isOverdue =>
      status != 'draft' &&
      dueAt.isNotEmpty &&
      remainingDueAmount > 0 &&
      dueAt.compareTo(dateOnly(DateTime.now())) < 0;
  List<String> get fieldPaymentIds => invoiceFieldPaymentIdsOf(data);
  List<String> get allocationIds => invoiceAllocationIdsOf(data);
  String get statusLabel => invoiceStatusLabel(status);
}

class InvoiceAdjustmentRecord extends Record {
  const InvoiceAdjustmentRecord(super.id, super.data);

  String get invoiceId => s('invoiceId');
  String get kind => s('kind');
  int get amount => n('amount');
  int get signedAmount => signedAdjustmentAmount(data);
  String get reason => s('reason');
}

class InvoiceReceiptRecord extends Record {
  const InvoiceReceiptRecord(super.id, super.data);

  String get invoiceId => s('invoiceId');
  String get reporterId => s('reporterId');
  String get paidToId => s('paidToId');
  String get status => s('status', 'reported');
  String get reimbursementId => s('reimbursementId');
  String get note => s('note');
  int get amount => n('amount');
  String get statusLabel => receiptStatusLabel(status);
}

class InvoiceInquiryRecord extends Record {
  const InvoiceInquiryRecord(super.id, super.data);

  String get invoiceId => s('invoiceId');
  String get requesterId => s('requesterId');
  String get recipientId => s('recipientId');
  String get status => s('status', 'open');
  String get messageId => s('messageId');
  String get note => s('note');
  String get statusLabel => invoiceInquiryLabel(status);
}

class ReimbursementRecord extends Record {
  const ReimbursementRecord(super.id, super.data);

  String get invoiceId => s('invoiceId');
  String get fieldPaymentId => s('fieldPaymentId');
  String get kind => s('kind');
  String get fromId => s('fromId');
  String get toId => s('toId');
  String get status => s('status', 'open');
  int get totalAmount => n('totalAmount');
  int get settledAmount => n('settledAmount');
  int get remainingAmount => (totalAmount - settledAmount).clamp(0, 0x7fffffff);
  List<Data> get settlements => billingRowsOf(data, 'settlements');
}

extension BillingWorkspaceView on WorkspaceRepository {
  List<FieldPaymentRecord> get fieldPayments => records(
    'fieldPayments',
  ).map((r) => FieldPaymentRecord(r.id, r.data)).toList(growable: false);
  List<SupplierPaymentAllocationRecord> get supplierPaymentAllocations =>
      records('supplierPaymentAllocations')
          .map((r) => SupplierPaymentAllocationRecord(r.id, r.data))
          .toList(growable: false);
  List<SupplierRefundRecord> get supplierRefunds => records(
    'supplierRefunds',
  ).map((r) => SupplierRefundRecord(r.id, r.data)).toList(growable: false);
  List<InvoiceRecord> get invoices => records(
    'invoices',
  ).map((r) => InvoiceRecord(r.id, r.data)).toList(growable: false);
  List<InvoiceAdjustmentRecord> get invoiceAdjustments => records(
    'invoiceAdjustments',
  ).map((r) => InvoiceAdjustmentRecord(r.id, r.data)).toList(growable: false);
  List<InvoiceReceiptRecord> get invoiceReceipts => records(
    'invoiceReceipts',
  ).map((r) => InvoiceReceiptRecord(r.id, r.data)).toList(growable: false);
  List<InvoiceInquiryRecord> get invoiceInquiries => records(
    'invoiceInquiries',
  ).map((r) => InvoiceInquiryRecord(r.id, r.data)).toList(growable: false);
  List<ReimbursementRecord> get reimbursements => records(
    'reimbursements',
  ).map((r) => ReimbursementRecord(r.id, r.data)).toList(growable: false);

  Future<String> recordFieldPayment(Data args, {String? operationId}) =>
      workflow('wf.billing.recordFieldPayment', args, operationId ?? newId());
  Future<String> allocateSupplierPayment(Data args, {String? operationId}) =>
      workflow(
        'wf.billing.allocateSupplierPayment',
        args,
        operationId ?? newId(),
      );
  Future<String> createInvoiceDraft(Data args, {String? operationId}) =>
      workflow('wf.billing.createInvoiceDraft', args, operationId ?? newId());
  Future<String> sendInvoice(
    String invoiceId,
    int version, {
    String? operationId,
  }) => workflow('wf.billing.sendInvoice', {
    'invoiceId': invoiceId,
    'version': version,
  }, operationId ?? newId());
  Future<String> sendInvoices(List<Data> items, {String? operationId}) =>
      workflow('wf.billing.sendInvoices', {
        'items': items,
      }, operationId ?? newId());
  Future<String> addInvoiceAdjustment(Data args, {String? operationId}) =>
      workflow('wf.billing.addAdjustment', args, operationId ?? newId());
  Future<String> reportInvoiceReceipt(Data args, {String? operationId}) =>
      workflow('wf.billing.reportReceipt', args, operationId ?? newId());
  Future<String> confirmInvoiceReceipt(Data args, {String? operationId}) =>
      workflow('wf.billing.confirmReceipt', args, operationId ?? newId());
  Future<String> recordSupplierRefund(Data args, {String? operationId}) =>
      workflow('wf.billing.recordSupplierRefund', args, operationId ?? newId());
  Future<String> flagInvoiceInquiry(Data args, {String? operationId}) =>
      workflow('wf.billing.flagInvoiceInquiry', args, operationId ?? newId());
  Future<String> resolveInvoiceInquiry(Data args, {String? operationId}) =>
      workflow(
        'wf.billing.resolveInvoiceInquiry',
        args,
        operationId ?? newId(),
      );
  Future<String> settleReimbursement(Data args, {String? operationId}) =>
      workflow('wf.billing.settleReimbursement', args, operationId ?? newId());
}
