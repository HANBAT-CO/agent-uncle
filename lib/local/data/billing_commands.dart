import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;

import '../domain/billing_models.dart';
import '../domain/models.dart';
import '../domain/order_payment.dart';
import 'local_store.dart';

String applyBilling(
  MutableWorkspace s,
  String actor,
  String command,
  Data args,
) {
  final normalized = command.startsWith('wf.') ? command.substring(3) : command;
  switch (normalized) {
    case 'billing.recordFieldPayment':
      return _recordFieldPayment(s, actor, args);
    case 'billing.allocateSupplierPayment':
      return _allocateSupplierPayment(s, actor, args);
    case 'billing.createInvoiceDraft':
      return _createInvoiceDraft(s, actor, args);
    case 'billing.sendInvoice':
      return _sendInvoice(s, actor, args);
    case 'billing.sendInvoices':
      return _sendInvoices(s, actor, args);
    case 'billing.addAdjustment':
      return _addAdjustment(s, actor, args);
    case 'billing.reportReceipt':
      return _reportReceipt(s, actor, args);
    case 'billing.confirmReceipt':
      return _confirmReceipt(s, actor, args);
    case 'billing.recordSupplierRefund':
      return _recordSupplierRefund(s, actor, args);
    case 'billing.flagInvoiceInquiry':
      return _flagInvoiceInquiry(s, actor, args);
    case 'billing.resolveInvoiceInquiry':
      return _resolveInvoiceInquiry(s, actor, args);
    case 'billing.settleReimbursement':
      return _settleReimbursement(s, actor, args);
  }
  throw AppFailure('지원하지 않는 청구 명령이에요: $command');
}

Map<String, Data> _table(MutableWorkspace s, String name) =>
    s.tables.putIfAbsent(name, () => <String, Data>{});

Data _requireFrom(MutableWorkspace s, String table, String id) =>
    _table(s, table)[id] ??
    (throw const AppFailure('기록을 찾을 수 없어요. 목록을 다시 확인해 주세요.'));

String _now() => DateTime.now().toIso8601String();

List<String> _uniqueStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    result.add(trimmed);
  }
  return result;
}

String _textArg(Data args, String key, {bool required = true}) {
  final value = textOf(args, key).trim();
  if (required && value.isEmpty) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

int _intArg(Data args, String key, {int min = 0, bool required = true}) {
  final value = nullableNumberOf(args, key);
  if (value == null) {
    if (required) throw AppFailure('$key 값을 확인해 주세요.');
    return 0;
  }
  if (value < min) throw AppFailure('$key 값을 확인해 주세요.');
  return value;
}

int? _nullableIntArg(Data args, String key) => nullableNumberOf(args, key);

String _dateOnlyArg(Data args, String key, {String fallback = ''}) {
  final value = _textArg(args, key, required: false).ifEmpty(() => fallback);
  if (value.isEmpty) return value;
  final parts = value.split('-');
  if (parts.length != 3 ||
      parts.any((part) => part.isEmpty) ||
      parts[0].length != 4 ||
      parts[1].length != 2 ||
      parts[2].length != 2 ||
      parts.any((part) => int.tryParse(part) == null)) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.year < 1 || dateOnly(parsed) != value) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

bool _hasExplicitArg(Data args, String key) {
  if (!args.containsKey(key)) return false;
  final value = args[key];
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  return true;
}

int? _nonNegativeIntArgOrNull(Data args, String key) {
  if (!_hasExplicitArg(args, key)) return null;
  final value = nullableNumberOf(args, key);
  if (value == null || value < 0) {
    throw AppFailure('$key 값을 확인해 주세요.');
  }
  return value;
}

List<String> _stringListArg(Data args, String key) {
  final raw = args[key];
  if (raw is! List) return const [];
  return [
    for (final value in raw)
      if (value is String && value.trim().isNotEmpty) value.trim(),
  ];
}

List<Data> _dataListArg(Data args, String key) {
  final raw = args[key];
  if (raw is! List) return const [];
  return [
    for (final value in raw)
      if (value is Map) Map<String, Object?>.from(value),
  ];
}

void _checkVersion(Data data, int? version) {
  if (version == null) return;
  if (numberOf(data, 'version') != version) {
    throw const AppFailure('다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.');
  }
}

Data _requireAccount(MutableWorkspace s, String userId) =>
    _requireFrom(s, 'accounts', userId);

void _requireRole(MutableWorkspace s, String userId, AppRole role) {
  final account = Account(userId, _requireAccount(s, userId));
  if (account.role != role || !flagOf(account.data, 'complete')) {
    throw AppFailure('${role.label}만 이 작업을 처리할 수 있어요.');
  }
}

Data _requireAcceptedRequest(MutableWorkspace s, String requestId) {
  final request = _requireFrom(s, 'requests', requestId);
  if (!['accepted', 'completed'].contains(textOf(request, 'status'))) {
    throw const AppFailure('실제로 수락되어 진행 중인 요청만 청구에 연결할 수 있어요.');
  }
  return request;
}

List<String> _teamMemberIds(Data team) => stringsOf(team, 'memberIds');

String _teamStatus(Data team) => textOf(team, 'status', 'active');
String _roundStatus(Data round) => textOf(round, 'status', 'active');

void _requireScopeMember(Data? team, String userId, String label) {
  if (userId.isEmpty) throw AppFailure('$label 값을 확인해 주세요.');
  if (team != null && !_teamMemberIds(team).contains(userId)) {
    throw AppFailure('같은 팀의 $label만 선택해 주세요.');
  }
}

Data? _validateScope(
  MutableWorkspace s,
  String requestId,
  Data request,
  String actor,
  String teamId,
  String roundId,
  String payerId,
  String payeeId, {
  String wholesaler = '',
}) {
  Data? team;
  final scopedJobs = <Data>[];
  if (teamId.isNotEmpty) {
    team = _requireFrom(s, 'teams', teamId);
    if (_teamStatus(team) != 'active') {
      throw const AppFailure('활성 팀만 청구 업무에 연결할 수 있어요.');
    }
    for (final row in _table(s, 'teamJobs').values) {
      if (textOf(row, 'requestId') != requestId) continue;
      if (textOf(row, 'teamId') != teamId) continue;
      if (roundId.isNotEmpty && textOf(row, 'roundId') != roundId) continue;
      if (wholesaler.isNotEmpty &&
          textOf(row, 'wholesalerName') != wholesaler) {
        continue;
      }
      scopedJobs.add(row);
    }
    if (scopedJobs.isEmpty) {
      throw const AppFailure('이 요청에 실제로 연결된 팀·회차만 청구 업무에 사용할 수 있어요.');
    }
    final requestUncleId = textOf(request, 'uncleId');
    for (final memberId in [actor, requestUncleId, payerId, payeeId]) {
      _requireScopeMember(team, memberId, '팀 삼촌');
    }
  } else if (roundId.isNotEmpty) {
    throw const AppFailure('회차를 연결하려면 먼저 같은 팀을 선택해 주세요.');
  } else if (payerId != textOf(request, 'uncleId') ||
      payeeId != textOf(request, 'uncleId')) {
    throw const AppFailure('다른 삼촌의 지급·수취를 기록하려면 실제 팀 업무를 연결해 주세요.');
  }
  if (roundId.isNotEmpty) {
    final round = _requireFrom(s, 'teamRounds', roundId);
    if (_roundStatus(round) != 'active' || textOf(round, 'teamId') != teamId) {
      throw const AppFailure('같은 팀의 실제 회차만 청구 업무에 연결할 수 있어요.');
    }
  }
  for (final userId in [payerId, payeeId]) {
    _requireRole(s, userId, AppRole.uncle);
  }
  return team;
}

bool _canHandleRequestWithTeamJob(
  MutableWorkspace s,
  String actor, {
  required String requestId,
  required String teamId,
  required String roundId,
  String wholesaler = '',
}) {
  if (teamId.isEmpty || roundId.isEmpty) return false;
  for (final row in _table(s, 'teamJobs').values) {
    if (textOf(row, 'requestId') != requestId) continue;
    if (textOf(row, 'teamId') != teamId) continue;
    if (textOf(row, 'roundId') != roundId) continue;
    if (wholesaler.isNotEmpty && textOf(row, 'wholesalerName') != wholesaler) {
      continue;
    }
    if (textOf(row, 'pickupAssigneeId') == actor ||
        textOf(row, 'finalAssigneeId') == actor) {
      return true;
    }
  }
  return false;
}

void _requireFieldPaymentActor(
  MutableWorkspace s,
  Data request,
  String requestId,
  String actor,
  String teamId,
  String roundId, {
  String wholesaler = '',
}) {
  if (textOf(request, 'uncleId') == actor) return;
  if (_canHandleRequestWithTeamJob(
    s,
    actor,
    requestId: requestId,
    teamId: teamId,
    roundId: roundId,
    wholesaler: wholesaler,
  )) {
    return;
  }
  throw const AppFailure('담당 삼촌이나 실제 배정된 팀 동료만 현장 지급을 기록할 수 있어요.');
}

List<ReimbursementRecord> _relatedReimbursementsForInvoice(
  MutableWorkspace s,
  String invoiceId,
  List<String> fieldPaymentIds,
) {
  final paymentSet = fieldPaymentIds.toSet();
  return _table(s, 'reimbursements').entries
      .where((entry) {
        final row = entry.value;
        return textOf(row, 'invoiceId') == invoiceId ||
            paymentSet.contains(textOf(row, 'fieldPaymentId'));
      })
      .map((entry) => ReimbursementRecord(entry.key, entry.value))
      .toList(growable: false);
}

InvoiceRecord? _matchingDraftInvoiceForAllocation(
  MutableWorkspace s,
  SupplierPaymentAllocationRecord allocation,
) {
  for (final entry in _table(s, 'invoices').entries) {
    final invoice = InvoiceRecord(entry.key, entry.value);
    if (invoice.status != 'draft') continue;
    if (invoiceGroupKeyOf(invoice.data) != invoiceGroupKeyOf(allocation.data)) {
      continue;
    }
    return invoice;
  }
  return null;
}

void _putRecord(MutableWorkspace s, String table, String id, Data data) {
  final previous = _table(s, table)[id];
  if (table == 'invoices' &&
      previous != null &&
      previous['platformPayoutComplete'] == true &&
      (numberOf(previous, 'adjustedTotalAmount') !=
              numberOf(data, 'adjustedTotalAmount') ||
          textOf(previous, 'payeeId') != textOf(data, 'payeeId') ||
          !listEquals(
            stringsOf(previous, 'fieldPaymentIds'),
            stringsOf(data, 'fieldPaymentIds'),
          ) ||
          !listEquals(
            stringsOf(previous, 'allocationIds'),
            stringsOf(data, 'allocationIds'),
          ))) {
    throw const AppFailure('지급 완료한 청구서는 금액이나 대상을 변경할 수 없어요. 운영자에게 문의해 주세요.');
  }
  _table(s, table)[id] = {
    ...data,
    'id': id,
    'readers': _uniqueStrings(billingReadersOf(data)),
  };
}

List<SupplierPaymentAllocationRecord> _allocationsForPayment(
  MutableWorkspace s,
  String paymentId,
) => _table(s, 'supplierPaymentAllocations').entries
    .where((entry) => textOf(entry.value, 'paymentId') == paymentId)
    .map((entry) => SupplierPaymentAllocationRecord(entry.key, entry.value))
    .toList(growable: false);

List<SupplierPaymentAllocationRecord> _allocationsForInvoice(
  MutableWorkspace s,
  String invoiceId,
) => _table(s, 'supplierPaymentAllocations').entries
    .where((entry) => textOf(entry.value, 'invoiceId') == invoiceId)
    .map((entry) => SupplierPaymentAllocationRecord(entry.key, entry.value))
    .toList(growable: false);

List<InvoiceAdjustmentRecord> _adjustmentsForInvoice(
  MutableWorkspace s,
  String invoiceId,
) => _table(s, 'invoiceAdjustments').entries
    .where((entry) => textOf(entry.value, 'invoiceId') == invoiceId)
    .map((entry) => InvoiceAdjustmentRecord(entry.key, entry.value))
    .toList(growable: false);

List<InvoiceReceiptRecord> _receiptsForInvoice(
  MutableWorkspace s,
  String invoiceId,
) => _table(s, 'invoiceReceipts').entries
    .where((entry) => textOf(entry.value, 'invoiceId') == invoiceId)
    .map((entry) => InvoiceReceiptRecord(entry.key, entry.value))
    .toList(growable: false);

List<InvoiceInquiryRecord> _inquiriesForInvoice(
  MutableWorkspace s,
  String invoiceId,
) => _table(s, 'invoiceInquiries').entries
    .where((entry) => textOf(entry.value, 'invoiceId') == invoiceId)
    .map((entry) => InvoiceInquiryRecord(entry.key, entry.value))
    .toList(growable: false);

List<ReimbursementRecord> _reimbursementsForInvoice(
  MutableWorkspace s,
  String invoiceId,
) => _table(s, 'reimbursements').entries
    .where((entry) => textOf(entry.value, 'invoiceId') == invoiceId)
    .map((entry) => ReimbursementRecord(entry.key, entry.value))
    .toList(growable: false);

ReimbursementRecord? _reimbursementForPayment(
  MutableWorkspace s,
  String paymentId,
  String kind,
) {
  for (final entry in _table(s, 'reimbursements').entries) {
    final row = entry.value;
    if (textOf(row, 'fieldPaymentId') == paymentId &&
        textOf(row, 'kind') == kind) {
      return ReimbursementRecord(entry.key, row);
    }
  }
  return null;
}

int _settledAmount(Data reimbursement) => billingRowsOf(
  reimbursement,
  'settlements',
).fold<int>(0, (sum, row) => sum + max(numberOf(row, 'amount'), 0));

Data _withReimbursementState(
  Data reimbursement, {
  required int totalAmount,
  List<String>? readers,
  List<Data>? settlements,
}) {
  final nextSettlements =
      settlements ?? billingRowsOf(reimbursement, 'settlements');
  final settledAmount = nextSettlements.fold<int>(
    0,
    (sum, row) => sum + max(numberOf(row, 'amount'), 0),
  );
  final status = totalAmount <= 0
      ? (settledAmount > 0 ? 'settled' : 'open')
      : settledAmount >= totalAmount
      ? 'settled'
      : settledAmount > 0
      ? 'partial'
      : 'open';
  return {
    ...reimbursement,
    'totalAmount': totalAmount,
    'settledAmount': min(settledAmount, max(totalAmount, settledAmount)),
    'status': status,
    'settlementIds': _uniqueStrings([
      for (final row in nextSettlements) textOf(row, 'id'),
    ]),
    'settlements': nextSettlements,
    'readers': ?readers,
    'updatedAt': _now(),
    'version': numberOf(reimbursement, 'version') + 1,
  };
}

void _upsertReimbursement(
  MutableWorkspace s, {
  required String id,
  required String kind,
  required String invoiceId,
  required String fieldPaymentId,
  required String fromId,
  required String toId,
  required int totalAmount,
  required List<String> readers,
}) {
  final current = _table(s, 'reimbursements')[id];
  final reimbursement = {
    ...?current,
    'invoiceId': invoiceId,
    'fieldPaymentId': fieldPaymentId,
    'kind': kind,
    'fromId': fromId,
    'toId': toId,
    'createdAt': textOf(current ?? const {}, 'createdAt', _now()),
    'readers': readers,
    'settlements': billingRowsOf(current ?? const {}, 'settlements'),
  };
  _putRecord(
    s,
    'reimbursements',
    id,
    _withReimbursementState(
      reimbursement,
      totalAmount: totalAmount,
      readers: readers,
    ),
  );
}

void _appendReimbursementSettlement(
  MutableWorkspace s,
  String reimbursementId, {
  required String settlementId,
  required int amount,
  required String kind,
  required String actorId,
  String note = '',
  String sourceId = '',
}) {
  final current = _requireFrom(s, 'reimbursements', reimbursementId);
  final existing = billingRowsOf(current, 'settlements');
  if (existing.any((row) => textOf(row, 'id') == settlementId)) return;
  final settlements = [
    ...existing,
    {
      'id': settlementId,
      'amount': amount,
      'kind': kind,
      'actorId': actorId,
      'note': note,
      'sourceId': sourceId,
      'createdAt': _now(),
    },
  ];
  _putRecord(
    s,
    'reimbursements',
    reimbursementId,
    _withReimbursementState(
      current,
      totalAmount: numberOf(current, 'totalAmount'),
      settlements: settlements,
    ),
  );
}

List<String> _internalReadersForScope(
  MutableWorkspace s,
  String teamId,
  Iterable<String> actorIds,
) {
  // 공동 픽업 참여 자체는 다른 거래처의 금융 장부 열람 권한이 아니다.
  return _uniqueStrings(actorIds);
}

void _rebuildPayment(MutableWorkspace s, String paymentId) {
  final payment = _requireFrom(s, 'fieldPayments', paymentId);
  final allocations = _allocationsForPayment(s, paymentId);
  final charge = allocations.fold<int>(
    0,
    (sum, row) => sum + row.customerChargeAmount,
  );
  final direct = allocations.fold<int>(
    0,
    (sum, row) => sum + row.directPaidAmount,
  );
  final fee = allocations.fold<int>(
    0,
    (sum, row) => sum + row.supplierFeeAmount,
  );
  final allocated = allocations.fold<int>(
    0,
    (sum, row) => sum + row.allocatedAmount,
  );
  final unallocated = max(numberOf(payment, 'actualPaidAmount') - allocated, 0);
  final invoiceIds = _uniqueStrings([
    for (final row in allocations)
      if (row.invoiceId.isNotEmpty) row.invoiceId,
  ]);
  _putRecord(s, 'fieldPayments', paymentId, {
    ...payment,
    'customerChargeAmount': charge,
    'directPaidAmount': direct,
    'supplierFeeAmount': fee,
    'allocatedAmount': allocated,
    'cashAllocatedAmount': allocated,
    if (allocations.isNotEmpty) ...{
      'cashAllocatedAmountMissing': false,
      'customerChargeAmountMissing': false,
      'directPaidAmountMissing': false,
      'supplierFeeAmountMissing': false,
    },
    'unallocatedAmount': unallocated,
    'allocationIds': [for (final row in allocations) row.id],
    'invoiceId': invoiceIds.isEmpty ? '' : invoiceIds.first,
    'updatedAt': _now(),
    'version': numberOf(payment, 'version') + 1,
  });
  _syncPayerReimbursement(s, paymentId);
}

void _syncPayerReimbursement(MutableWorkspace s, String paymentId) {
  final payment = FieldPaymentRecord(
    paymentId,
    _requireFrom(s, 'fieldPayments', paymentId),
  );
  if (payment.fundingSource != 'personal' ||
      payment.payerId == payment.payeeId) {
    if (payment.reimbursementId.isNotEmpty &&
        _table(s, 'reimbursements').containsKey(payment.reimbursementId)) {
      _upsertReimbursement(
        s,
        id: payment.reimbursementId,
        kind: 'payer_reimbursement',
        invoiceId: payment.invoiceId,
        fieldPaymentId: paymentId,
        fromId: payment.payeeId,
        toId: payment.payerId,
        totalAmount: 0,
        readers: _internalReadersForScope(s, payment.teamId, [
          payment.uncleId,
          payment.payerId,
          payment.payeeId,
        ]),
      );
      _putRecord(s, 'fieldPayments', paymentId, {
        ...payment.data,
        'reimbursementId': '',
        'updatedAt': _now(),
        'version': payment.version + 1,
      });
    }
    return;
  }
  final totalAmount = payment.actualPaidAmount;
  final reimbursementId = payment.reimbursementId.isEmpty
      ? 'payer-reimbursement:$paymentId'
      : payment.reimbursementId;
  final readers = _internalReadersForScope(s, payment.teamId, [
    payment.uncleId,
    payment.payerId,
    payment.payeeId,
  ]);
  _upsertReimbursement(
    s,
    id: reimbursementId,
    kind: 'payer_reimbursement',
    invoiceId: payment.invoiceId,
    fieldPaymentId: paymentId,
    fromId: payment.payeeId,
    toId: payment.payerId,
    totalAmount: totalAmount,
    readers: readers,
  );
  final current = FieldPaymentRecord(
    paymentId,
    _requireFrom(s, 'fieldPayments', paymentId),
  );
  if (current.reimbursementId != reimbursementId) {
    _putRecord(s, 'fieldPayments', paymentId, {
      ...current.data,
      'reimbursementId': reimbursementId,
      'updatedAt': _now(),
      'version': current.version + 1,
    });
  }
}

List<String> _invoiceReaders(Data invoice, {required bool includeRetailer}) =>
    _uniqueStrings([
      ...billingReadersOf(
        invoice,
      ).where((id) => id != textOf(invoice, 'retailerId')),
      if (includeRetailer) textOf(invoice, 'retailerId'),
    ]);

void _syncCustomerRefund(
  MutableWorkspace s,
  String invoiceId,
  int baseRefundAmount,
) {
  final invoice = InvoiceRecord(
    invoiceId,
    _requireFrom(s, 'invoices', invoiceId),
  );
  final current = _reimbursementsForInvoice(s, invoiceId).firstWhere(
    (row) => row.kind == 'customer_refund',
    orElse: () => ReimbursementRecord('customer-refund:$invoiceId', const {}),
  );
  final settledAmount = current.data.isEmpty ? 0 : _settledAmount(current.data);
  final totalAmount = max(baseRefundAmount, settledAmount);
  if (totalAmount <= 0 && current.data.isEmpty) return;
  final readers = _invoiceReaders(invoice.data, includeRetailer: true);
  _upsertReimbursement(
    s,
    id: current.id,
    kind: 'customer_refund',
    invoiceId: invoiceId,
    fieldPaymentId: current.fieldPaymentId,
    fromId: invoice.payeeId,
    toId: invoice.retailerId,
    totalAmount: totalAmount,
    readers: readers,
  );
}

void _rebuildInvoice(MutableWorkspace s, String invoiceId) {
  final current = InvoiceRecord(
    invoiceId,
    _requireFrom(s, 'invoices', invoiceId),
  );
  final allocations = _allocationsForInvoice(s, invoiceId);
  final adjustments = _adjustmentsForInvoice(s, invoiceId);
  final receipts = _receiptsForInvoice(s, invoiceId);
  final inquiries = _inquiriesForInvoice(s, invoiceId);
  final linkedPayments = [
    for (final paymentId in current.fieldPaymentIds)
      FieldPaymentRecord(
        paymentId,
        _requireFrom(s, 'fieldPayments', paymentId),
      ),
  ];
  final managerIds = _uniqueStrings([
    current.payeeId,
    for (final allocation in allocations) textOf(allocation.data, 'uncleId'),
    if (allocations.isEmpty)
      for (final payment in linkedPayments) payment.uncleId,
  ]);
  final principalAmount = allocations.fold<int>(
    0,
    (sum, row) => sum + row.billableAmount,
  );
  final baseTotalAmount = principalAmount + current.deliveryFeeAmount;
  final adjustmentTotalAmount = adjustments.fold<int>(
    0,
    (sum, row) => sum + row.signedAmount,
  );
  final adjustedTotalAmount = max(baseTotalAmount + adjustmentTotalAmount, 0);
  if (current.b('platformPayoutComplete') &&
      adjustedTotalAmount != current.adjustedTotalAmount) {
    throw const AppFailure('지급 완료한 청구서는 금액을 변경할 수 없어요. 운영자에게 문의해 주세요.');
  }
  final pendingReceiptRows = receipts
      .where((row) => row.status == 'reported')
      .toList(growable: false);
  final reportedReceiptAmount = receipts
      .where((row) => row.status == 'reported' || row.status == 'confirmed')
      .fold<int>(0, (sum, row) => sum + row.amount);
  final pendingReceiptAmount = pendingReceiptRows.fold<int>(
    0,
    (sum, row) => sum + row.amount,
  );
  final confirmedReceiptAmount = receipts
      .where((row) => row.status == 'confirmed')
      .fold<int>(0, (sum, row) => sum + row.amount);
  final confirmedRefundAmount = _reimbursementsForInvoice(s, invoiceId)
      .where((row) => row.kind == 'customer_refund')
      .fold<int>(0, (sum, row) => sum + row.settledAmount);
  final baseRefundAmount = max(confirmedReceiptAmount - adjustedTotalAmount, 0);
  final remainingDueAmount = max(
    adjustedTotalAmount - confirmedReceiptAmount,
    0,
  );
  final refundRequiredAmount = max(baseRefundAmount - confirmedRefundAmount, 0);
  final missingAmountCount = linkedPayments.where((payment) {
    if (payment.settlementKind == 'review') return true;
    if (payment.unallocatedAmount > 0) return true;
    if (payment.hasMissingAmounts) return true;
    return false;
  }).length;
  final nextStatus = current.status == 'draft'
      ? 'draft'
      : confirmedReceiptAmount >= adjustedTotalAmount
      ? 'collected'
      : confirmedReceiptAmount > 0
      ? 'partial'
      : 'sent';
  _putRecord(s, 'invoices', invoiceId, {
    ...current.data,
    'managerIds': managerIds,
    'readers': _uniqueStrings([
      ...managerIds,
      if (current.status != 'draft') current.retailerId,
    ]),
    'status': nextStatus,
    'principalAmount': principalAmount,
    'baseTotalAmount': baseTotalAmount,
    'adjustmentTotalAmount': adjustmentTotalAmount,
    'adjustedTotalAmount': adjustedTotalAmount,
    'reportedReceiptAmount': reportedReceiptAmount,
    'pendingReceiptCount': pendingReceiptRows.length,
    'pendingReceiptAmount': pendingReceiptAmount,
    'confirmedReceiptAmount': confirmedReceiptAmount,
    'confirmedRefundAmount': confirmedRefundAmount,
    'remainingDueAmount': remainingDueAmount,
    'refundRequiredAmount': refundRequiredAmount,
    'missingAmountCount': missingAmountCount,
    'inquiryOpenCount': inquiries.where((row) => row.status == 'open').length,
    'updatedAt': _now(),
    'version': current.version + 1,
  });
  _syncCustomerRefund(s, invoiceId, baseRefundAmount);
}

bool _canManageInvoice(Data invoice, String actor) =>
    stringsOf(invoice, 'managerIds').contains(actor);

void _linkInvoiceToAllocations(
  MutableWorkspace s,
  String invoiceId,
  List<SupplierPaymentAllocationRecord> allocations,
) {
  for (final allocation in allocations) {
    _putRecord(s, 'supplierPaymentAllocations', allocation.id, {
      ...allocation.data,
      'invoiceId': invoiceId,
      'updatedAt': _now(),
      'version': allocation.version + 1,
    });
    _rebuildPayment(s, allocation.paymentId);
  }
}

String _paymentWholesaler(Data request, String selected) {
  final names = _uniqueStrings([
    textOf(request, 'wholesaler'),
    for (final row in billingRowsOf(request, 'wholesalers'))
      textOf(row, 'wholesaler'),
  ]);
  final name = selected.trim().ifEmpty(
    () => names.length == 1 ? names.single : '',
  );
  if (name.isEmpty || !names.contains(name)) {
    throw const AppFailure('이 요청에 포함된 도매처를 선택해 주세요.');
  }
  return name;
}

String _recordFieldPayment(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final requestId = _textArg(args, 'requestId');
  final request = _requireAcceptedRequest(s, requestId);
  final requestedId = _textArg(args, 'id', required: false);
  final currentPayment =
      requestedId.isNotEmpty &&
          _table(s, 'fieldPayments').containsKey(requestedId)
      ? FieldPaymentRecord(
          requestedId,
          _requireFrom(s, 'fieldPayments', requestedId),
        )
      : null;
  if (currentPayment != null) {
    _checkVersion(currentPayment.data, _nullableIntArg(args, 'version'));
    if (currentPayment.requestId != requestId) {
      throw const AppFailure('같은 요청의 기존 현장 지급만 다시 정리할 수 있어요.');
    }
    if (!billingReadersOf(currentPayment.data).contains(actor)) {
      throw const AppFailure('현장 지급 당사자만 기록을 수정할 수 있어요.');
    }
    final linked = _allocationsForPayment(s, currentPayment.id);
    if (linked.any(
          (row) =>
              row.invoiceId.isNotEmpty &&
              textOf(_requireFrom(s, 'invoices', row.invoiceId), 'status') !=
                  'draft',
        ) ||
        _table(
          s,
          'supplierRefunds',
        ).values.any((row) => textOf(row, 'paymentId') == currentPayment.id) ||
        (currentPayment.reimbursementId.isNotEmpty &&
            _settledAmount(
                  _requireFrom(
                    s,
                    'reimbursements',
                    currentPayment.reimbursementId,
                  ),
                ) >
                0)) {
      throw const AppFailure('발행·환불·반환이 반영된 지급은 덮어쓸 수 없어요. 별도 조정으로 남겨 주세요.');
    }
  }
  final payerId = _textArg(
    args,
    'payerId',
    required: false,
  ).ifEmpty(() => currentPayment?.payerId.ifEmpty(() => actor) ?? actor);
  final payeeId = _textArg(
    args,
    'payeeId',
    required: false,
  ).ifEmpty(() => currentPayment?.payeeId.ifEmpty(() => actor) ?? actor);
  final teamId = _textArg(
    args,
    'teamId',
    required: false,
  ).ifEmpty(() => currentPayment?.teamId ?? '');
  final roundId = _textArg(
    args,
    'roundId',
    required: false,
  ).ifEmpty(() => currentPayment?.roundId ?? '');
  final wholesaler = _paymentWholesaler(
    request,
    _textArg(
      args,
      'wholesaler',
      required: false,
    ).ifEmpty(() => currentPayment?.wholesaler ?? ''),
  );
  _requireFieldPaymentActor(
    s,
    request,
    requestId,
    actor,
    teamId,
    roundId,
    wholesaler: wholesaler,
  );
  _validateScope(
    s,
    requestId,
    request,
    actor,
    teamId,
    roundId,
    payerId,
    payeeId,
    wholesaler: wholesaler,
  );
  if (currentPayment != null &&
      (currentPayment.payerId != payerId ||
          currentPayment.payeeId != payeeId ||
          currentPayment.teamId != teamId ||
          currentPayment.roundId != roundId ||
          currentPayment.wholesaler != wholesaler)) {
    throw const AppFailure('기존 지급의 당사자·팀·회차·도매처는 변경할 수 없어요.');
  }
  final fundingSource = _textArg(
    args,
    'fundingSource',
    required: false,
  ).ifEmpty(() => currentPayment?.fundingSource ?? 'unknown');
  final settlementKind = _textArg(
    args,
    'settlementKind',
    required: false,
  ).ifEmpty(() => currentPayment?.settlementKind ?? 'review');
  if (!fieldPaymentFundingSources.contains(fundingSource)) {
    throw const AppFailure('자금 출처를 다시 확인해 주세요.');
  }
  if (!fieldPaymentSettlementKinds.contains(settlementKind)) {
    throw const AppFailure('결제 방식은 advance/direct/review 중 하나여야 해요.');
  }
  final actualPaidAmount =
      currentPayment == null || _hasExplicitArg(args, 'actualPaidAmount')
      ? _intArg(args, 'actualPaidAmount', min: 0)
      : currentPayment.actualPaidAmount;
  final initialCashAllocatedAmount = _nonNegativeIntArgOrNull(
    args,
    'cashAllocatedAmount',
  );
  final customerChargeAmount = _nonNegativeIntArgOrNull(
    args,
    'customerChargeAmount',
  );
  final directPaidAmount = _nonNegativeIntArgOrNull(args, 'directPaidAmount');
  final supplierFeeAmount = _nonNegativeIntArgOrNull(args, 'supplierFeeAmount');
  var hasInitialAllocationInput = [
    initialCashAllocatedAmount,
    customerChargeAmount,
    directPaidAmount,
    supplierFeeAmount,
  ].any((value) => value != null);
  final existingAmountsMatchCurrent =
      currentPayment != null &&
      currentPayment.allocationIds.isNotEmpty &&
      hasInitialAllocationInput &&
      initialCashAllocatedAmount == currentPayment.cashAllocatedAmount &&
      customerChargeAmount == currentPayment.customerChargeAmount &&
      directPaidAmount == currentPayment.directPaidAmount &&
      supplierFeeAmount == currentPayment.supplierFeeAmount;
  if (existingAmountsMatchCurrent) {
    hasInitialAllocationInput = false;
  }
  if (hasInitialAllocationInput) {
    if (initialCashAllocatedAmount == null ||
        customerChargeAmount == null ||
        directPaidAmount == null ||
        supplierFeeAmount == null) {
      throw const AppFailure('현금 배분액, 고객 부담액, 직접 결제액, 수수료·상계를 모두 명시해 주세요.');
    }
    if (directPaidAmount > customerChargeAmount) {
      throw const AppFailure('직접 결제 금액이 고객 부담액보다 클 수 없어요.');
    }
    if (initialCashAllocatedAmount > actualPaidAmount) {
      throw const AppFailure('배분할 실제 현금이 총 지급액보다 클 수 없어요.');
    }
  }
  final existingAllocations = currentPayment == null
      ? <SupplierPaymentAllocationRecord>[]
      : _allocationsForPayment(s, currentPayment.id);
  final correctingAllocation =
      hasInitialAllocationInput &&
      existingAllocations.length == 1 &&
      existingAllocations.single.requestId == requestId;
  if (settlementKind == 'direct' &&
      (hasInitialAllocationInput
          ? customerChargeAmount != directPaidAmount
          : existingAllocations.any((row) => row.billableAmount != 0))) {
    throw const AppFailure('직접 결제 완료 건은 고객 부담액 전액을 직접 결제액으로 기록해 주세요.');
  }
  final paymentId = requestedId.ifEmpty(() => 'field-payment:${newId()}');
  if (currentPayment == null &&
      _table(s, 'fieldPayments').containsKey(paymentId)) {
    throw const AppFailure('이미 기록된 현장 지급이에요.');
  }
  if (currentPayment != null &&
      !correctingAllocation &&
      actualPaidAmount < currentPayment.allocatedAmount) {
    throw const AppFailure('이미 배분한 실제 현금보다 총 지급액을 작게 바꿀 수 없어요.');
  }
  if (currentPayment != null &&
      currentPayment.allocationIds.isNotEmpty &&
      hasInitialAllocationInput &&
      !correctingAllocation) {
    throw const AppFailure('여러 고객에게 배분한 금액은 개별 배분 기록에서 수정해 주세요.');
  }
  final readers = _internalReadersForScope(s, teamId, [
    actor,
    textOf(request, 'uncleId'),
    payerId,
    payeeId,
  ]);
  final cashMissing = currentPayment?.cashAllocatedAmountMissing ?? true;
  final chargeMissing = currentPayment?.customerChargeAmountMissing ?? true;
  final directMissing = currentPayment?.directPaidAmountMissing ?? true;
  final feeMissing = currentPayment?.supplierFeeAmountMissing ?? true;
  final payment = {
    ...?currentPayment?.data,
    'requestId': requestId,
    'retailerId': textOf(request, 'retailerId'),
    'uncleId': textOf(request, 'uncleId'),
    'teamId': teamId,
    'roundId': roundId,
    'payeeId': payeeId,
    'payerId': payerId,
    'wholesaler': wholesaler,
    'note': _textArg(args, 'note', required: false),
    'fundingSource': fundingSource,
    'settlementKind': settlementKind,
    'actualPaidAmount': actualPaidAmount,
    'cashAllocatedAmount': currentPayment?.cashAllocatedAmount ?? 0,
    'allocatedAmount': currentPayment?.allocatedAmount ?? 0,
    'unallocatedAmount': max(
      actualPaidAmount - (currentPayment?.allocatedAmount ?? 0),
      0,
    ),
    'customerChargeAmount': currentPayment?.customerChargeAmount ?? 0,
    'directPaidAmount': currentPayment?.directPaidAmount ?? 0,
    'supplierFeeAmount': currentPayment?.supplierFeeAmount ?? 0,
    'cashAllocatedAmountMissing': hasInitialAllocationInput
        ? false
        : cashMissing,
    'customerChargeAmountMissing': hasInitialAllocationInput
        ? false
        : chargeMissing,
    'directPaidAmountMissing': hasInitialAllocationInput
        ? false
        : directMissing,
    'supplierFeeAmountMissing': hasInitialAllocationInput ? false : feeMissing,
    'allocationIds': currentPayment?.allocationIds ?? const <String>[],
    'invoiceId': currentPayment?.invoiceId ?? '',
    'reimbursementId':
        currentPayment?.reimbursementId ??
        (fundingSource == 'personal' && payerId != payeeId
            ? 'payer-reimbursement:$paymentId'
            : ''),
    'readers': readers,
    'createdAt': textOf(currentPayment?.data ?? const {}, 'createdAt', _now()),
    'updatedAt': _now(),
    'version': currentPayment == null ? 0 : currentPayment.version + 1,
  };
  _putRecord(s, 'fieldPayments', paymentId, payment);
  _syncPayerReimbursement(s, paymentId);
  if (correctingAllocation) {
    final allocation = existingAllocations.single;
    _putRecord(s, 'supplierPaymentAllocations', allocation.id, {
      ...allocation.data,
      'cashAllocatedAmount': initialCashAllocatedAmount,
      'allocatedAmount': initialCashAllocatedAmount,
      'customerChargeAmount': customerChargeAmount,
      'directPaidAmount': directPaidAmount,
      'supplierFeeAmount': supplierFeeAmount,
      'note': _textArg(args, 'note', required: false),
      'updatedAt': _now(),
      'version': allocation.version + 1,
    });
    _rebuildPayment(s, paymentId);
    if (allocation.invoiceId.isNotEmpty) {
      _rebuildInvoice(s, allocation.invoiceId);
    }
  } else if (hasInitialAllocationInput) {
    _allocateSupplierPayment(s, actor, {
      'paymentId': paymentId,
      'requestId': requestId,
      'version': numberOf(
        _requireFrom(s, 'fieldPayments', paymentId),
        'version',
      ),
      'cashAllocatedAmount': initialCashAllocatedAmount,
      'customerChargeAmount': customerChargeAmount,
      'directPaidAmount': directPaidAmount,
      'supplierFeeAmount': supplierFeeAmount,
      'note': _textArg(args, 'note', required: false),
      'id': 'allocation:$paymentId',
    });
  } else if (currentPayment != null) {
    for (final invoiceId in _uniqueStrings(
      _allocationsForPayment(s, paymentId).map((row) => row.invoiceId),
    )) {
      _rebuildInvoice(s, invoiceId);
    }
  }
  return paymentId;
}

String _allocateSupplierPayment(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final paymentId = _textArg(args, 'paymentId');
  final payment = FieldPaymentRecord(
    paymentId,
    _requireFrom(s, 'fieldPayments', paymentId),
  );
  if (!billingReadersOf(payment.data).contains(actor)) {
    throw const AppFailure('현장 지급 당사자만 배분을 기록할 수 있어요.');
  }
  _checkVersion(payment.data, _nullableIntArg(args, 'version'));
  final correctionId = _textArg(args, 'allocationId', required: false);
  final correction = correctionId.isEmpty
      ? null
      : SupplierPaymentAllocationRecord(
          correctionId,
          _requireFrom(s, 'supplierPaymentAllocations', correctionId),
        );
  if (correction != null) {
    if (correction.paymentId != paymentId ||
        _nullableIntArg(args, 'allocationVersion') == null) {
      throw const AppFailure('수정할 배분의 지급과 최신 버전을 확인해 주세요.');
    }
    _checkVersion(correction.data, _nullableIntArg(args, 'allocationVersion'));
    if (_allocationsForPayment(s, paymentId).any(
          (row) =>
              row.invoiceId.isNotEmpty &&
              textOf(_requireFrom(s, 'invoices', row.invoiceId), 'status') !=
                  'draft',
        ) ||
        _table(
          s,
          'supplierRefunds',
        ).values.any((row) => textOf(row, 'paymentId') == paymentId) ||
        (payment.reimbursementId.isNotEmpty &&
            _settledAmount(
                  _requireFrom(s, 'reimbursements', payment.reimbursementId),
                ) >
                0)) {
      throw const AppFailure('발행·환불·반환이 반영된 배분은 수정할 수 없어요.');
    }
  }
  final requestId = _textArg(
    args,
    'requestId',
    required: false,
  ).ifEmpty(() => correction?.requestId ?? payment.requestId);
  if (correction != null && correction.requestId != requestId) {
    throw const AppFailure('기존 배분의 고객 요청은 변경할 수 없어요.');
  }
  final request = _requireAcceptedRequest(s, requestId);
  _paymentWholesaler(request, payment.wholesaler);
  _requireFieldPaymentActor(
    s,
    request,
    requestId,
    actor,
    payment.teamId,
    payment.roundId,
    wholesaler: payment.wholesaler,
  );
  if (requestId != payment.requestId &&
      (payment.teamId.isEmpty || payment.roundId.isEmpty)) {
    throw const AppFailure('여러 고객에게 배분하려면 같은 팀·회차의 지급을 선택해 주세요.');
  }
  if (payment.teamId.isNotEmpty || payment.roundId.isNotEmpty) {
    _validateScope(
      s,
      requestId,
      request,
      actor,
      payment.teamId,
      payment.roundId,
      payment.payerId,
      payment.payeeId,
      wholesaler: payment.wholesaler,
    );
  }
  final cashAllocatedAmount = _nonNegativeIntArgOrNull(
    args,
    'cashAllocatedAmount',
  );
  final customerChargeAmount = _nonNegativeIntArgOrNull(
    args,
    'customerChargeAmount',
  );
  final directPaidAmount = _nonNegativeIntArgOrNull(args, 'directPaidAmount');
  final supplierFeeAmount = _nonNegativeIntArgOrNull(args, 'supplierFeeAmount');
  if (cashAllocatedAmount == null ||
      customerChargeAmount == null ||
      directPaidAmount == null ||
      supplierFeeAmount == null) {
    throw const AppFailure('현금 배분액, 고객 부담액, 직접 결제액, 수수료·상계를 모두 명시해 주세요.');
  }
  if (directPaidAmount > customerChargeAmount) {
    throw const AppFailure('직접 결제 금액이 고객 부담액보다 클 수 없어요.');
  }
  if (payment.settlementKind == 'direct' &&
      customerChargeAmount != directPaidAmount) {
    throw const AppFailure('직접 결제 완료 건은 고객 부담액 전액을 직접 결제액으로 기록해 주세요.');
  }
  final allocatedAmount = cashAllocatedAmount;
  if (allocatedAmount >
      payment.unallocatedAmount + (correction?.allocatedAmount ?? 0)) {
    throw const AppFailure('남은 미배분 금액보다 크게 배분할 수 없어요.');
  }
  final allocationId =
      correction?.id ??
      _textArg(
        args,
        'id',
        required: false,
      ).ifEmpty(() => 'allocation:${newId()}');
  if (correction == null &&
      _table(s, 'supplierPaymentAllocations').containsKey(allocationId)) {
    throw const AppFailure('이미 반영한 배분이에요.');
  }
  _putRecord(s, 'supplierPaymentAllocations', allocationId, {
    ...?correction?.data,
    'paymentId': paymentId,
    'requestId': requestId,
    'retailerId': textOf(request, 'retailerId'),
    'uncleId': textOf(request, 'uncleId'),
    'teamId': payment.teamId,
    'roundId': payment.roundId,
    'payeeId': payment.payeeId,
    'payerId': payment.payerId,
    'cashAllocatedAmount': cashAllocatedAmount,
    'customerChargeAmount': customerChargeAmount,
    'directPaidAmount': directPaidAmount,
    'supplierFeeAmount': supplierFeeAmount,
    'allocatedAmount': allocatedAmount,
    'invoiceId': correction?.invoiceId ?? '',
    'note': _textArg(args, 'note', required: false),
    'readers': _uniqueStrings([
      textOf(request, 'uncleId'),
      payment.payeeId,
      payment.payerId,
    ]),
    'createdAt': correction?.s('createdAt') ?? _now(),
    'updatedAt': _now(),
    'version': correction == null ? 0 : correction.version + 1,
  });
  final allocation = SupplierPaymentAllocationRecord(
    allocationId,
    _requireFrom(s, 'supplierPaymentAllocations', allocationId),
  );
  final draft = _matchingDraftInvoiceForAllocation(s, allocation);
  if (draft != null && allocation.invoiceId.isEmpty) {
    _putRecord(s, 'supplierPaymentAllocations', allocationId, {
      ...allocation.data,
      'invoiceId': draft.id,
      'updatedAt': _now(),
      'version': allocation.version + 1,
    });
  }
  _rebuildPayment(s, paymentId);
  final linkedInvoiceId = textOf(
    _requireFrom(s, 'supplierPaymentAllocations', allocationId),
    'invoiceId',
  );
  if (linkedInvoiceId.isNotEmpty) {
    final invoice = InvoiceRecord(
      linkedInvoiceId,
      _requireFrom(s, 'invoices', linkedInvoiceId),
    );
    final mergedPaymentIds = _uniqueStrings([
      ...invoice.fieldPaymentIds,
      paymentId,
    ]);
    final mergedAllocationIds = _uniqueStrings([
      ...invoice.allocationIds,
      allocationId,
    ]);
    _putRecord(s, 'invoices', linkedInvoiceId, {
      ...invoice.data,
      'fieldPaymentIds': mergedPaymentIds,
      'allocationIds': mergedAllocationIds,
      'updatedAt': _now(),
      'version': invoice.version + 1,
    });
    _rebuildInvoice(s, linkedInvoiceId);
  }
  return allocationId;
}

String _createInvoiceDraft(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final requestedInvoiceId = _textArg(args, 'invoiceId', required: false);
  InvoiceRecord? currentInvoice;
  if (requestedInvoiceId.isNotEmpty &&
      _table(s, 'invoices').containsKey(requestedInvoiceId)) {
    currentInvoice = InvoiceRecord(
      requestedInvoiceId,
      _requireFrom(s, 'invoices', requestedInvoiceId),
    );
  }
  final allocationIds = _stringListArg(args, 'allocationIds');
  final paymentIds = _stringListArg(args, 'paymentIds');
  final allocations = <SupplierPaymentAllocationRecord>[];
  final selectedPayments = <FieldPaymentRecord>[];
  if (allocationIds.isNotEmpty) {
    for (final id in allocationIds) {
      final allocation = SupplierPaymentAllocationRecord(
        id,
        _requireFrom(s, 'supplierPaymentAllocations', id),
      );
      allocations.add(allocation);
      selectedPayments.add(
        FieldPaymentRecord(
          allocation.paymentId,
          _requireFrom(s, 'fieldPayments', allocation.paymentId),
        ),
      );
    }
  } else {
    for (final paymentId in paymentIds) {
      final payment = FieldPaymentRecord(
        paymentId,
        _requireFrom(s, 'fieldPayments', paymentId),
      );
      selectedPayments.add(payment);
      final rows = _allocationsForPayment(s, paymentId);
      allocations.addAll(rows);
    }
  }
  if (allocations.isEmpty &&
      selectedPayments.isEmpty &&
      currentInvoice != null) {
    _checkVersion(
      currentInvoice.data,
      _nullableIntArg(args, 'invoiceVersion') ??
          _nullableIntArg(args, 'version'),
    );
    if (!_canManageInvoice(currentInvoice.data, actor)) {
      throw const AppFailure('청구 담당 삼촌만 기존 초안을 수정할 수 있어요.');
    }
    for (final allocationId in currentInvoice.allocationIds) {
      allocations.add(
        SupplierPaymentAllocationRecord(
          allocationId,
          _requireFrom(s, 'supplierPaymentAllocations', allocationId),
        ),
      );
    }
    for (final paymentId in currentInvoice.fieldPaymentIds) {
      selectedPayments.add(
        FieldPaymentRecord(
          paymentId,
          _requireFrom(s, 'fieldPayments', paymentId),
        ),
      );
    }
  }
  if (allocations.isEmpty && selectedPayments.isEmpty) {
    throw const AppFailure('청구에 넣을 지급 또는 배분 기록을 선택해 주세요.');
  }
  final firstSource = allocations.isNotEmpty
      ? allocations.first.data
      : selectedPayments.first.data;
  final groupKey = invoiceGroupKeyOf(firstSource);
  final metadataOnlyUpdate =
      currentInvoice != null && allocationIds.isEmpty && paymentIds.isEmpty;
  for (final allocation in allocations) {
    if (!metadataOnlyUpdate &&
        textOf(allocation.data, 'uncleId') != actor &&
        allocation.payeeId != actor) {
      throw const AppFailure('해당 거래처의 청구 담당자만 청구서를 만들 수 있어요.');
    }
    final request = _requireAcceptedRequest(s, allocation.requestId);
    final payment = FieldPaymentRecord(
      allocation.paymentId,
      _requireFrom(s, 'fieldPayments', allocation.paymentId),
    );
    _paymentWholesaler(request, payment.wholesaler);
    _validateScope(
      s,
      allocation.requestId,
      request,
      actor,
      allocation.teamId,
      allocation.roundId,
      allocation.payerId,
      allocation.payeeId,
      wholesaler: payment.wholesaler,
    );
    if (invoiceGroupKeyOf(allocation.data) != groupKey) {
      throw const AppFailure('같은 소매업자·팀·회차·수취 담당 배분만 한 청구서로 묶을 수 있어요.');
    }
    if (allocation.invoiceId.isNotEmpty &&
        allocation.invoiceId != _textArg(args, 'invoiceId', required: false)) {
      throw const AppFailure('이미 다른 청구서에 묶인 배분이 섞여 있어요.');
    }
  }
  for (final payment in selectedPayments) {
    final paymentGroupMatches = _allocationsForPayment(
      s,
      payment.id,
    ).any((row) => invoiceGroupKeyOf(row.data) == groupKey);
    if (!paymentGroupMatches && invoiceGroupKeyOf(payment.data) != groupKey) {
      throw const AppFailure('같은 소매업자·팀·회차·수취 담당 지급만 한 청구서로 묶을 수 있어요.');
    }
    final request = _requireAcceptedRequest(s, payment.requestId);
    _validateScope(
      s,
      payment.requestId,
      request,
      actor,
      payment.teamId,
      payment.roundId,
      payment.payerId,
      payment.payeeId,
    );
    if (!metadataOnlyUpdate &&
        allocations.isEmpty &&
        payment.payeeId != actor &&
        payment.uncleId != actor) {
      throw const AppFailure('같은 팀 범위에서 실제 관련된 지급만 청구 초안에 넣을 수 있어요.');
    }
  }
  final invoiceId = requestedInvoiceId.ifEmpty(() => 'invoice:${newId()}');
  if (_table(s, 'invoices').containsKey(invoiceId)) {
    currentInvoice = InvoiceRecord(
      invoiceId,
      _requireFrom(s, 'invoices', invoiceId),
    );
    if (currentInvoice.status != 'draft' && !metadataOnlyUpdate) {
      throw const AppFailure('발행 전 청구 초안만 다시 묶을 수 있어요.');
    }
    _checkVersion(
      currentInvoice.data,
      _nullableIntArg(args, 'invoiceVersion') ??
          _nullableIntArg(args, 'version'),
    );
    if (!_canManageInvoice(currentInvoice.data, actor)) {
      throw const AppFailure('청구 담당 삼촌만 기존 초안을 수정할 수 있어요.');
    }
    if (invoiceGroupKeyOf(currentInvoice.data) != groupKey) {
      throw const AppFailure('같은 소매업자·팀·회차·수취 담당 초안에만 이어서 반영할 수 있어요.');
    }
  }
  if (currentInvoice != null &&
      currentInvoice.status != 'draft' &&
      _hasExplicitArg(args, 'deliveryFeeAmount')) {
    throw const AppFailure('발행 후에는 배달비를 바꿀 수 없어요.');
  }
  final paymentIdsForInvoice = _uniqueStrings([
    for (final row in allocations) row.paymentId,
    for (final payment in selectedPayments) payment.id,
    if (currentInvoice != null) ...currentInvoice.fieldPaymentIds,
  ]);
  final managerIds = <String>{textOf(firstSource, 'payeeId')};
  for (final row in allocations) {
    managerIds.add(textOf(row.data, 'uncleId'));
  }
  if (allocations.isEmpty) managerIds.add(textOf(firstSource, 'uncleId'));
  for (final paymentId in paymentIdsForInvoice) {
    final payment = FieldPaymentRecord(
      paymentId,
      _requireFrom(s, 'fieldPayments', paymentId),
    );
    final request = _requireAcceptedRequest(s, payment.requestId);
    _validateScope(
      s,
      payment.requestId,
      request,
      actor,
      payment.teamId,
      payment.roundId,
      payment.payerId,
      payment.payeeId,
    );
  }
  final linkedAllocations = _uniqueStrings([
    if (currentInvoice != null) ...currentInvoice.allocationIds,
    for (final row in allocations) row.id,
  ]);
  final invoice = {
    ...?currentInvoice?.data,
    'retailerId': textOf(firstSource, 'retailerId'),
    'teamId': textOf(firstSource, 'teamId'),
    'roundId': textOf(firstSource, 'roundId'),
    'payeeId': textOf(firstSource, 'payeeId'),
    'managerIds': _uniqueStrings(managerIds),
    'fieldPaymentIds': paymentIdsForInvoice,
    'allocationIds': linkedAllocations,
    'label': _textArg(
      args,
      'label',
      required: false,
    ).ifEmpty(() => textOf(currentInvoice?.data ?? const {}, 'label')),
    'status': currentInvoice?.status ?? 'draft',
    'principalAmount': currentInvoice?.principalAmount ?? 0,
    'deliveryFeeAmount': _hasExplicitArg(args, 'deliveryFeeAmount')
        ? _intArg(args, 'deliveryFeeAmount', min: 0, required: false)
        : (currentInvoice?.deliveryFeeAmount ?? 0),
    'baseTotalAmount': 0,
    'adjustmentTotalAmount': 0,
    'adjustedTotalAmount': 0,
    'reportedReceiptAmount': 0,
    'pendingReceiptCount': 0,
    'pendingReceiptAmount': 0,
    'confirmedReceiptAmount': 0,
    'confirmedRefundAmount': 0,
    'remainingDueAmount': 0,
    'refundRequiredAmount': 0,
    'missingAmountCount': 0,
    'inquiryOpenCount': 0,
    'dueAt': _dateOnlyArg(
      args,
      'dueAt',
      fallback: textOf(currentInvoice?.data ?? const {}, 'dueAt'),
    ),
    'sentAt': textOf(currentInvoice?.data ?? const {}, 'sentAt'),
    'readers': _uniqueStrings([
      ...managerIds,
      if (currentInvoice != null && currentInvoice.status != 'draft')
        currentInvoice.retailerId,
    ]),
    'createdAt': textOf(currentInvoice?.data ?? const {}, 'createdAt', _now()),
    'updatedAt': _now(),
    'version': currentInvoice == null ? 0 : currentInvoice.version + 1,
  };
  _putRecord(s, 'invoices', invoiceId, invoice);
  final rowsToLink = <SupplierPaymentAllocationRecord>[
    for (final allocationId in linkedAllocations)
      SupplierPaymentAllocationRecord(
        allocationId,
        _requireFrom(s, 'supplierPaymentAllocations', allocationId),
      ),
  ];
  _linkInvoiceToAllocations(s, invoiceId, rowsToLink);
  _rebuildInvoice(s, invoiceId);
  return invoiceId;
}

void _sendOneInvoice(MutableWorkspace s, String actor, Data item) {
  final invoiceId = _textArg(item, 'invoiceId');
  final invoice = InvoiceRecord(
    invoiceId,
    _requireFrom(s, 'invoices', invoiceId),
  );
  if (!_canManageInvoice(invoice.data, actor)) {
    throw const AppFailure('청구 담당 삼촌만 발행할 수 있어요.');
  }
  _checkVersion(invoice.data, _nullableIntArg(item, 'version'));
  if (invoice.status != 'draft') {
    throw const AppFailure('아직 발행 전인 청구서만 선택해 주세요.');
  }
  for (final paymentId in invoice.fieldPaymentIds) {
    final payment = FieldPaymentRecord(
      paymentId,
      _requireFrom(s, 'fieldPayments', paymentId),
    );
    if (payment.unallocatedAmount > 0) {
      throw const AppFailure('미배분 현장 지급이 남아 있으면 청구서를 발행할 수 없어요.');
    }
    if (payment.settlementKind == 'review') {
      throw const AppFailure('결제 방식이 review 인 현장 지급은 확인 후에만 청구서를 발행할 수 있어요.');
    }
    if (payment.hasMissingAmounts) {
      throw const AppFailure('금액 입력이 비어 있는 현장 지급은 먼저 실제 값을 채워 주세요.');
    }
  }
  final nextReaders = _invoiceReaders(invoice.data, includeRetailer: true);
  _putRecord(s, 'invoices', invoiceId, {
    ...invoice.data,
    'status': 'sent',
    'sentAt': _now(),
    'readers': nextReaders,
    'updatedAt': _now(),
    'version': invoice.version + 1,
  });
  for (final adjustment in _adjustmentsForInvoice(s, invoiceId)) {
    _putRecord(s, 'invoiceAdjustments', adjustment.id, {
      ...adjustment.data,
      'readers': nextReaders,
      'updatedAt': _now(),
      'version': adjustment.version + 1,
    });
  }
  _rebuildInvoice(s, invoiceId);
}

String _sendInvoice(MutableWorkspace s, String actor, Data args) {
  _sendOneInvoice(s, actor, args);
  return _textArg(args, 'invoiceId');
}

String _sendInvoices(MutableWorkspace s, String actor, Data args) {
  final items = _dataListArg(args, 'items');
  if (items.isEmpty) {
    final invoiceId = _textArg(args, 'invoiceId', required: false);
    if (invoiceId.isEmpty) {
      throw const AppFailure('발행할 청구서를 선택해 주세요.');
    }
    _sendOneInvoice(s, actor, args);
    return invoiceId;
  }
  for (final item in items) {
    _sendOneInvoice(s, actor, item);
  }
  return '${items.length}건';
}

String _addAdjustment(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final invoiceId = _textArg(args, 'invoiceId');
  final invoice = InvoiceRecord(
    invoiceId,
    _requireFrom(s, 'invoices', invoiceId),
  );
  if (!_canManageInvoice(invoice.data, actor)) {
    throw const AppFailure('청구 담당 삼촌만 조정을 남길 수 있어요.');
  }
  if (invoice.b('platformPayoutComplete')) {
    throw const AppFailure('지급 완료한 청구서는 금액을 변경할 수 없어요. 운영자에게 문의해 주세요.');
  }
  _checkVersion(
    invoice.data,
    _nullableIntArg(args, 'invoiceVersion') ?? _nullableIntArg(args, 'version'),
  );
  final kind = _textArg(args, 'kind');
  if (!invoiceAdjustmentKinds.contains(kind)) {
    throw const AppFailure('조정 종류를 다시 확인해 주세요.');
  }
  final amount = _intArg(args, 'amount', min: 1);
  final adjustmentId = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'invoice-adjustment:${newId()}');
  if (_table(s, 'invoiceAdjustments').containsKey(adjustmentId)) {
    throw const AppFailure('이미 기록한 조정이에요.');
  }
  _putRecord(s, 'invoiceAdjustments', adjustmentId, {
    'invoiceId': invoiceId,
    'kind': kind,
    'amount': amount,
    'reason': _textArg(args, 'reason', required: false),
    'readers': billingReadersOf(invoice.data),
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
  });
  _rebuildInvoice(s, invoiceId);
  return adjustmentId;
}

String _reportReceipt(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.retailer);
  final invoiceId = _textArg(args, 'invoiceId');
  final invoice = InvoiceRecord(
    invoiceId,
    _requireFrom(s, 'invoices', invoiceId),
  );
  if (invoice.retailerId != actor) {
    throw const AppFailure('이 청구서에 대한 송금 알림만 남길 수 있어요.');
  }
  if (invoice.status == 'draft') {
    throw const AppFailure('아직 발행되지 않은 청구서에는 송금 알림을 남길 수 없어요.');
  }
  if (invoice.b('requiresReconciliation') || invoice.missingAmountCount > 0) {
    throw const AppFailure('청구 금액을 다시 확인 중이에요. 정리가 끝난 후 입금해 주세요.');
  }
  final requestIds = invoiceRequestIds(WorkspaceSnapshot(s.tables), invoice);
  if (requestIds.isEmpty ||
      requestIds.any(
        (id) =>
            !RequestRecord(id, _requireFrom(s, 'requests', id)).receiptComplete,
      )) {
    throw const AppFailure('청구서에 포함된 상품을 모두 수령 확인한 후 입금해 주세요.');
  }
  final amount = _intArg(args, 'amount', min: 1);
  final paidToId = _textArg(
    args,
    'paidToId',
    required: false,
  ).ifEmpty(() => platformPayeeId);
  if (paidToId != platformPayeeId) {
    throw const AppFailure('소매업자 입금은 안내된 운영 계좌로만 처리해 주세요.');
  }
  if (amount > invoice.adjustedTotalAmount - invoice.reportedReceiptAmount) {
    throw const AppFailure('이미 신고한 금액을 제외한 남은 입금액을 확인해 주세요.');
  }
  final receiptId = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'invoice-receipt:${newId()}');
  if (_table(s, 'invoiceReceipts').containsKey(receiptId)) {
    throw const AppFailure('이미 남긴 송금 알림이에요.');
  }
  _putRecord(s, 'invoiceReceipts', receiptId, {
    'invoiceId': invoiceId,
    'reporterId': actor,
    'paidToId': paidToId,
    'bankName': platformBankName,
    'bankAccount': platformBankAccount,
    'bankHolder': platformBankHolder,
    'amount': amount,
    'note': _textArg(args, 'note', required: false),
    'status': 'reported',
    'reimbursementId': '',
    'readers': _invoiceReaders(invoice.data, includeRetailer: true),
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
  });
  _rebuildInvoice(s, invoiceId);
  return receiptId;
}

String _confirmReceipt(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final receiptId = _textArg(args, 'receiptId');
  final receipt = InvoiceReceiptRecord(
    receiptId,
    _requireFrom(s, 'invoiceReceipts', receiptId),
  );
  if (receipt.paidToId == platformPayeeId) {
    throw const AppFailure('운영 계좌 입금은 운영자만 확인할 수 있어요.');
  }
  final invoice = InvoiceRecord(
    receipt.invoiceId,
    _requireFrom(s, 'invoices', receipt.invoiceId),
  );
  if (!_canManageInvoice(invoice.data, actor)) {
    throw const AppFailure('청구 담당 삼촌만 송금 알림을 처리할 수 있어요.');
  }
  _checkVersion(receipt.data, _nullableIntArg(args, 'version'));
  if (receipt.status != 'reported') {
    throw const AppFailure('확인 대기 중인 송금 알림만 처리할 수 있어요.');
  }
  final confirmed = args['confirmed'] != false;
  // 반환 연결은 확인된 청구 원금과 실제 수취자를 기준으로 계산한다.
  var reimbursementId = '';
  _putRecord(s, 'invoiceReceipts', receiptId, {
    ...receipt.data,
    'status': confirmed ? 'confirmed' : 'rejected',
    'confirmedAt': confirmed ? _now() : '',
    'confirmedBy': confirmed ? actor : '',
    'reimbursementId': reimbursementId,
    'updatedAt': _now(),
    'version': receipt.version + 1,
  });
  if (confirmed && receipt.paidToId != invoice.payeeId) {
    var remainingCredit = receipt.amount;
    final allocations = _allocationsForInvoice(s, invoice.id);
    final previousReceipts = _receiptsForInvoice(s, invoice.id)
        .where((row) => row.id != receiptId && row.status == 'confirmed')
        .fold<int>(0, (sum, row) => sum + row.amount);
    var remainingPrincipal = max(invoice.principalAmount - previousReceipts, 0);
    final related =
        _relatedReimbursementsForInvoice(s, invoice.id, invoice.fieldPaymentIds)
            .where(
              (row) =>
                  row.kind == 'payer_reimbursement' &&
                  row.toId == receipt.paidToId,
            )
            .toList(growable: false);
    for (final reimbursement in related) {
      if (remainingCredit <= 0) break;
      final allocatedPrincipal = allocations
          .where((row) => row.paymentId == reimbursement.fieldPaymentId)
          .fold<int>(
            0,
            (sum, row) => sum + min(row.allocatedAmount, row.billableAmount),
          );
      final previousCredits = billingRowsOf(reimbursement.data, 'settlements')
          .where((row) {
            if (textOf(row, 'kind') != 'receipt_credit') return false;
            final source = _table(
              s,
              'invoiceReceipts',
            )[textOf(row, 'sourceId')];
            return source != null && textOf(source, 'invoiceId') == invoice.id;
          })
          .fold<int>(0, (sum, row) => sum + numberOf(row, 'amount'));
      final applied = min(
        min(remainingCredit, reimbursement.remainingAmount),
        min(remainingPrincipal, max(allocatedPrincipal - previousCredits, 0)),
      );
      if (applied <= 0) continue;
      reimbursementId = reimbursement.id;
      _appendReimbursementSettlement(
        s,
        reimbursement.id,
        settlementId: 'receipt-credit:$receiptId:${reimbursement.id}',
        amount: applied,
        kind: 'receipt_credit',
        actorId: actor,
        sourceId: receiptId,
      );
      remainingCredit -= applied;
      remainingPrincipal -= applied;
    }
    if (remainingCredit > 0) {
      final existingRecovery = _reimbursementsForInvoice(s, invoice.id)
          .firstWhere(
            (row) =>
                row.kind == 'team_recovery' &&
                row.fromId == receipt.paidToId &&
                row.toId == invoice.payeeId,
            orElse: () => ReimbursementRecord('', const {}),
          );
      final teamRecoveryId = existingRecovery.id.ifEmpty(
        () => 'team-recovery:${invoice.id}:${receipt.paidToId}',
      );
      _upsertReimbursement(
        s,
        id: teamRecoveryId,
        kind: 'team_recovery',
        invoiceId: invoice.id,
        fieldPaymentId: existingRecovery.fieldPaymentId,
        fromId: receipt.paidToId,
        toId: invoice.payeeId,
        totalAmount:
            (existingRecovery.data.isEmpty ? 0 : existingRecovery.totalAmount) +
            remainingCredit,
        readers: _uniqueStrings([
          ..._invoiceReaders(invoice.data, includeRetailer: false),
          receipt.paidToId,
        ]),
      );
      reimbursementId = reimbursementId.ifEmpty(() => teamRecoveryId);
    }
    _putRecord(s, 'invoiceReceipts', receiptId, {
      ..._requireFrom(s, 'invoiceReceipts', receiptId),
      'reimbursementId': reimbursementId,
      'updatedAt': _now(),
      'version':
          InvoiceReceiptRecord(
            receiptId,
            _requireFrom(s, 'invoiceReceipts', receiptId),
          ).version +
          1,
    });
  }
  _rebuildInvoice(s, receipt.invoiceId);
  return receiptId;
}

String _recordSupplierRefund(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final paymentId = _textArg(args, 'paymentId');
  final payment = FieldPaymentRecord(
    paymentId,
    _requireFrom(s, 'fieldPayments', paymentId),
  );
  if (payment.uncleId != actor &&
      payment.payeeId != actor &&
      payment.payerId != actor) {
    throw const AppFailure('현장 지급 당사자만 도매처 환급을 기록할 수 있어요.');
  }
  _checkVersion(payment.data, _nullableIntArg(args, 'version'));
  final amount = _intArg(args, 'amount', min: 1);
  final actualRecipientId = _textArg(args, 'actualRecipientId');
  if (actualRecipientId != payment.payerId &&
      actualRecipientId != payment.payeeId) {
    throw const AppFailure('실제 환급을 받은 당사자만 선택해 주세요.');
  }
  final refunded = _table(s, 'supplierRefunds').values
      .where((row) => textOf(row, 'paymentId') == paymentId)
      .fold<int>(0, (sum, row) => sum + numberOf(row, 'amount'));
  if (refunded + amount > payment.actualPaidAmount) {
    throw const AppFailure('실제 지급액보다 많은 금액을 환불로 기록할 수 없어요.');
  }
  final refundId = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'supplier-refund:${newId()}');
  if (_table(s, 'supplierRefunds').containsKey(refundId)) {
    throw const AppFailure('이미 기록한 도매처 환급이에요.');
  }
  _putRecord(s, 'supplierRefunds', refundId, {
    'paymentId': paymentId,
    'invoiceId': payment.invoiceId,
    'actualRecipientId': actualRecipientId,
    'amount': amount,
    'note': _textArg(args, 'note', required: false),
    'reimbursementId': payment.reimbursementId,
    'readers': billingReadersOf(payment.data),
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
  });
  if (payment.reimbursementId.isNotEmpty &&
      actualRecipientId == payment.payerId) {
    final reimbursement = ReimbursementRecord(
      payment.reimbursementId,
      _requireFrom(s, 'reimbursements', payment.reimbursementId),
    );
    final credit = min(amount, reimbursement.remainingAmount);
    if (credit > 0) {
      _appendReimbursementSettlement(
        s,
        payment.reimbursementId,
        settlementId: 'supplier-refund:$refundId',
        amount: credit,
        kind: 'supplier_refund_credit',
        actorId: actor,
        note: _textArg(args, 'note', required: false),
        sourceId: refundId,
      );
    }
    final excess = amount - credit;
    if (actualRecipientId == payment.payerId && excess > 0) {
      final teamRecoveryId = 'team-recovery:$paymentId';
      final existing = _reimbursementForPayment(s, paymentId, 'team_recovery');
      final total = (existing?.totalAmount ?? 0) + excess;
      _upsertReimbursement(
        s,
        id: teamRecoveryId,
        kind: 'team_recovery',
        invoiceId: payment.invoiceId,
        fieldPaymentId: paymentId,
        fromId: payment.payerId,
        toId: payment.payeeId,
        totalAmount: total,
        readers: _internalReadersForScope(s, payment.teamId, [
          payment.uncleId,
          payment.payerId,
          payment.payeeId,
        ]),
      );
    }
  }
  if (payment.invoiceId.isNotEmpty) {
    _rebuildInvoice(s, payment.invoiceId);
  }
  return refundId;
}

String _flagInvoiceInquiry(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.retailer);
  final invoiceId = _textArg(args, 'invoiceId');
  final invoice = InvoiceRecord(
    invoiceId,
    _requireFrom(s, 'invoices', invoiceId),
  );
  if (invoice.retailerId != actor) {
    throw const AppFailure('해당 소매업자만 금액 문의를 남길 수 있어요.');
  }
  if (invoice.status == 'draft') {
    throw const AppFailure('아직 발행되지 않은 청구서에는 문의를 남길 수 없어요.');
  }
  final note = _textArg(args, 'note');
  final inquiryId = _textArg(
    args,
    'id',
    required: false,
  ).ifEmpty(() => 'invoice-inquiry:${newId()}');
  if (_table(s, 'invoiceInquiries').containsKey(inquiryId)) {
    throw const AppFailure('이미 남긴 금액 문의예요.');
  }
  final messageId = _textArg(
    args,
    'messageId',
    required: false,
  ).ifEmpty(() => 'message:${newId()}');
  if (_table(s, 'messages').containsKey(messageId)) {
    throw const AppFailure('이미 같은 문의 메시지를 보냈어요.');
  }
  final requestId = _allocationsForInvoice(s, invoiceId)
      .map((row) => row.requestId)
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  _table(s, 'messages')[messageId] = {
    'senderId': actor,
    'recipientId': invoice.payeeId,
    'body': note,
    'attachments': const <String>[],
    'status': 'sent',
    'readBy': [actor],
    'requestId': requestId,
    'invoiceId': invoiceId,
    'inquiry': true,
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
  };
  _putRecord(s, 'invoiceInquiries', inquiryId, {
    'invoiceId': invoiceId,
    'requesterId': actor,
    'recipientId': invoice.payeeId,
    'messageId': messageId,
    'note': note,
    'status': 'open',
    'readers': _invoiceReaders(invoice.data, includeRetailer: true),
    'createdAt': _now(),
    'updatedAt': _now(),
    'version': 0,
  });
  _rebuildInvoice(s, invoiceId);
  return inquiryId;
}

String _resolveInvoiceInquiry(MutableWorkspace s, String actor, Data args) {
  _requireRole(s, actor, AppRole.uncle);
  final inquiryId = _textArg(args, 'inquiryId');
  final inquiry = InvoiceInquiryRecord(
    inquiryId,
    _requireFrom(s, 'invoiceInquiries', inquiryId),
  );
  final invoice = InvoiceRecord(
    inquiry.invoiceId,
    _requireFrom(s, 'invoices', inquiry.invoiceId),
  );
  if (!_canManageInvoice(invoice.data, actor)) {
    throw const AppFailure('청구 담당 삼촌만 금액 문의를 해결할 수 있어요.');
  }
  _checkVersion(inquiry.data, _nullableIntArg(args, 'version'));
  if (inquiry.status == 'resolved') {
    return inquiryId;
  }
  _putRecord(s, 'invoiceInquiries', inquiryId, {
    ...inquiry.data,
    'status': 'resolved',
    'resolvedAt': _now(),
    'resolvedBy': actor,
    'resolutionNote': _textArg(args, 'note', required: false),
    'updatedAt': _now(),
    'version': inquiry.version + 1,
  });
  _rebuildInvoice(s, inquiry.invoiceId);
  return inquiryId;
}

String _settleReimbursement(MutableWorkspace s, String actor, Data args) {
  final reimbursementId = _textArg(args, 'reimbursementId');
  final reimbursement = ReimbursementRecord(
    reimbursementId,
    _requireFrom(s, 'reimbursements', reimbursementId),
  );
  final invoiceId = _textArg(
    args,
    'invoiceId',
    required: false,
  ).ifEmpty(() => reimbursement.invoiceId);
  if (invoiceId != reimbursement.invoiceId) {
    throw const AppFailure('반환 기록에 연결된 청구서만 사용할 수 있어요.');
  }
  if (invoiceId.isNotEmpty) {
    final invoice = InvoiceRecord(
      invoiceId,
      _requireFrom(s, 'invoices', invoiceId),
    );
    if (!_canManageInvoice(invoice.data, actor) &&
        actor != reimbursement.fromId &&
        actor != reimbursement.toId) {
      throw const AppFailure('정산 당사자만 반환을 기록할 수 있어요.');
    }
  } else if (actor != reimbursement.fromId && actor != reimbursement.toId) {
    throw const AppFailure('정산 당사자만 반환을 기록할 수 있어요.');
  }
  _checkVersion(reimbursement.data, _nullableIntArg(args, 'version'));
  final amount = _intArg(args, 'amount', min: 1);
  if (amount > reimbursement.remainingAmount) {
    throw const AppFailure('남은 반환 대상 금액보다 크게 처리할 수 없어요.');
  }
  final settlementId = _textArg(
    args,
    'settlementId',
    required: false,
  ).ifEmpty(() => 'reimbursement-settlement:${newId()}');
  _appendReimbursementSettlement(
    s,
    reimbursementId,
    settlementId: settlementId,
    amount: amount,
    kind: 'manual',
    actorId: actor,
    note: _textArg(args, 'note', required: false),
  );
  if (invoiceId.isNotEmpty) {
    _rebuildInvoice(s, invoiceId);
  }
  return reimbursementId;
}

extension on String {
  String ifEmpty(String Function() orElse) => trim().isEmpty ? orElse() : this;
}
