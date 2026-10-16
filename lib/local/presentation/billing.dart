import 'dart:async';
import 'dart:convert';

import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:flutter/widgets.dart';

import '../app_services.dart';
import '../domain/billing_models.dart';
import '../domain/models.dart';
import '../domain/order_payment.dart';
import 'common.dart';

const _allInvoiceStatuses = ['all', ...invoiceStatuses];

Widget _billingInputs({required bool ignoring, required Widget child}) =>
    ExcludeFocus(
      excluding: ignoring,
      child: IgnorePointer(ignoring: ignoring, child: child),
    );

// 입력을 연 계정에 묶고, 타이핑 저장이 전송 완료 후의 삭제를 덮어쓰지 않게 한다.
mixin _BillingInputOwner<T extends StatefulWidget> on State<T> {
  AppServices? _inputApp;
  String? _inputActorId;
  Future<void> _inputWrites = Future.value();
  bool _inputSaveFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inputApp == null) {
      _inputApp = AppScope.of(context);
      _inputActorId = _inputApp!.session.current?.id;
    }
  }

  bool _sameInputAccount(AppServices app) =>
      identical(_inputApp, app) &&
      _inputActorId != null &&
      _inputActorId == app.session.current?.id;

  void _requireInputAccount(AppServices app) {
    if (!_sameInputAccount(app)) {
      throw const AppFailure('계정이 변경되었어요. 현재 계정에서 화면을 다시 열어 주세요.');
    }
  }

  Future<void> _saveOwnedInput(AppServices app, String key, Data values) {
    final snapshot = Map<String, Object?>.from(
      jsonDecode(jsonEncode(values)) as Map,
    );
    final write = _inputWrites.then((_) {
      _requireInputAccount(app);
      return app.workspace.saveWorkflowInput(key, snapshot);
    });
    _inputWrites = write.catchError((Object _) {});
    return write;
  }

  void _saveInBackground(Future<void> write) {
    unawaited(
      write
          .then((_) {
            if (mounted && _inputSaveFailed) {
              setState(() => _inputSaveFailed = false);
            }
          })
          .catchError((Object _) {
            if (mounted) setState(() => _inputSaveFailed = true);
          }),
    );
  }
}

bool _hasRejectedWorkflow(WorkspaceRepository workspace, String operationId) =>
    workspace
        .records('workflowPending')
        .any(
          (row) =>
              row.s('operationId') == operationId &&
              row.s('status') == 'rejected',
        );

bool _hasLiveWorkflow(WorkspaceRepository workspace, String operationId) =>
    workspace
        .records('workflowPending')
        .any(
          (row) =>
              row.s('operationId') == operationId &&
              row.s('status') != 'rejected',
        );

Data? _restoreSubmitted(
  WorkspaceRepository workspace,
  Data saved,
  String operationId,
) {
  if (saved['submitted'] is! Map) return null;
  final submitted = mapOf(saved, 'submitted');
  if (submitted.isEmpty) return null;
  // 전송 직전이나 서버 응답 직후에도 저장한 작업번호와 내용을 그대로 재사용한다.
  if (operationId.isEmpty || _hasRejectedWorkflow(workspace, operationId)) {
    return null;
  }
  return submitted;
}

int? _parseOptionalAmount(String text, String label) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value < 0) {
    throw AppFailure('$label 값을 다시 확인해 주세요.');
  }
  return value;
}

DateTime? _dateFromText(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse('${value}T00:00:00');
}

String _dueAtLabel(String value, {required bool overdue}) {
  if (value.isEmpty) return '미정';
  final parts = value.split('-');
  if (parts.length != 3) return value;
  final label =
      '${int.tryParse(parts[1]) ?? parts[1]}월 ${int.tryParse(parts[2]) ?? parts[2]}일';
  return overdue ? '$label · 기한 지남' : label;
}

String _amountTextOrMissing(int value, {required bool missing}) =>
    missing ? '미입력' : billingMoney(value);

Map<String, Object?> _entryIfPresent(String key, Object? value) =>
    value == null ? const {} : {key: value};

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({this.initialStatus, super.key});

  final String? initialStatus;

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage>
    with _BillingInputOwner<InvoiceListPage> {
  late String statusFilter;
  final _selectedDraftIds = <String>{};
  String _sendOperationId = newId();
  Data? _sendSubmitted;
  bool _selectionRestored = false;

  String get _sendKey => 'billing-send-drafts';

  @override
  void initState() {
    super.initState();
    statusFilter = _allInvoiceStatuses.contains(widget.initialStatus)
        ? widget.initialStatus!
        : 'all';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectionRestored) return;
    _selectionRestored = true;
    final app = AppScope.of(context);
    final saved = app.workspace.workflowInput(_sendKey);
    if (_sameInputAccount(app)) {
      _selectedDraftIds.addAll(stringsOf(saved, 'invoiceIds'));
      _sendOperationId = textOf(saved, 'operationId', _sendOperationId);
      _sendSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _sendOperationId,
      );
    }
  }

  Future<void> _saveDraftSelection(AppServices app) =>
      _saveOwnedInput(app, _sendKey, {
        'invoiceIds': _selectedDraftIds.toList()..sort(),
        'operationId': _sendOperationId,
        if (_sendSubmitted != null) 'submitted': _sendSubmitted,
      });

  Future<void> _sendSelected(AppServices app) async {
    _requireInputAccount(app);
    final drafts = app.workspace.invoices
        .where(
          (row) => _selectedDraftIds.contains(row.id) && row.status == 'draft',
        )
        .toList(growable: false);
    if (_sendSubmitted == null && drafts.isEmpty) {
      throw const AppFailure('발행할 청구 초안을 먼저 선택해 주세요.');
    }
    _sendSubmitted ??= {
      'items': [
        for (final invoice in drafts)
          {'invoiceId': invoice.id, 'version': invoice.version},
      ],
    };
    setState(() {});
    await _saveDraftSelection(app);
    _requireInputAccount(app);
    try {
      await app.workspace.sendInvoices([
        for (final item in _dataRows(_sendSubmitted!, 'items'))
          {
            'invoiceId': textOf(item, 'invoiceId'),
            'version': numberOf(item, 'version'),
          },
      ], operationId: _sendOperationId);
    } catch (_) {
      if (!_sameInputAccount(app)) rethrow;
      final rejected = _hasRejectedWorkflow(app.workspace, _sendOperationId);
      if (rejected) {
        await app.workspace.discardRejectedWorkflow(_sendOperationId);
      }
      if (rejected || !_hasLiveWorkflow(app.workspace, _sendOperationId)) {
        _sendSubmitted = null;
        _sendOperationId = newId();
        await _saveDraftSelection(app);
        if (mounted) setState(() {});
      }
      rethrow;
    }
    await _saveOwnedInput(app, _sendKey, {});
    _requireInputAccount(app);
    if (!mounted) return;
    setState(() {
      _selectedDraftIds.clear();
      _sendSubmitted = null;
      _sendOperationId = newId();
    });
  }

  @override
  void didUpdateWidget(covariant InvoiceListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus &&
        _allInvoiceStatuses.contains(widget.initialStatus)) {
      statusFilter = widget.initialStatus!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!_sameInputAccount(app)) {
      return const PageFrame(
        title: '청구',
        children: [EmptyState.titleOnly('현재 계정에서 화면을 다시 열어 주세요')],
      );
    }
    final current = app.session.current;
    final invoices =
        app.workspace.invoices
            .where((invoice) {
              if (statusFilter == 'all') return true;
              return invoice.status == statusFilter;
            })
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final draftInvoices = current?.role == AppRole.uncle
        ? invoices.where((row) => row.status == 'draft').toList(growable: false)
        : const <InvoiceRecord>[];

    return PageFrame(
      title: '청구',
      navigationSubtitle: current?.role == AppRole.retailer
          ? '대납 청구와 회수 상태를 확인해요'
          : '초안·회수·환급 상태를 한곳에서 관리해요',
      header: Choices(
        options: [
          for (final value in _allInvoiceStatuses)
            _invoiceStatusChoiceLabel(value),
        ],
        value: _invoiceStatusChoiceLabel(statusFilter),
        onChanged: (label) =>
            setState(() => statusFilter = _invoiceStatusChoiceValue(label)),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      ),
      children: [
        if (_inputSaveFailed)
          const Inset(child: Info('입력을 저장하지 못했어요. 다시 시도해 주세요.')),
        if ((draftInvoices.isNotEmpty || _sendSubmitted != null) &&
            current?.role == AppRole.uncle) ...[
          Section('청구 초안 일괄 검토'),
          Inset(
            child: Info(
              _selectedDraftIds.isEmpty
                  ? '발행할 초안을 먼저 선택하세요. 미배분 지급이나 review 지급이 섞여 있으면 발행이 막혀요.'
                  : '선택 ${_selectedDraftIds.length}건을 최종 발행합니다. 발행 전까지 소매업자에게 보이지 않아요.',
            ),
          ),
          for (final invoice in draftInvoices)
            FigmaSurface(
              children: [
                Item(
                  '${_selectedDraftIds.contains(invoice.id) ? '선택됨' : '선택'} · ${invoice.label.isEmpty ? '청구 초안' : invoice.label}',
                  subtitle: _invoiceSubtitle(app, invoice),
                  leading: const FigmaIcon('document'),
                  trailing: StatusBadge(
                    _selectedDraftIds.contains(invoice.id) ? '발행 선택' : '대기',
                    attention: _selectedDraftIds.contains(invoice.id),
                  ),
                  onTap: _sendSubmitted != null
                      ? null
                      : () {
                          setState(() {
                            if (!_selectedDraftIds.add(invoice.id)) {
                              _selectedDraftIds.remove(invoice.id);
                            }
                          });
                          _saveInBackground(_saveDraftSelection(app));
                        },
                ),
                Inset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuantityRow(
                        '청구 예정',
                        billingMoney(invoice.adjustedTotalAmount),
                      ),
                      QuantityRow(
                        '남은 확인',
                        billingMoney(invoice.remainingDueAmount),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ActionButton(
            _sendSubmitted != null ? '청구 발행 다시 확인' : '선택한 초안 최종 발행',
            icon: 'send',
            enabled: _selectedDraftIds.isNotEmpty,
            onPressed: () async {
              await _saveDraftSelection(app);
              await _sendSelected(app);
            },
          ),
        ],
        if (invoices.isEmpty)
          EmptyState(
            statusFilter == 'all' ? '청구서가 아직 없어요' : '이 상태의 청구서가 없어요',
            current?.role == AppRole.retailer
                ? '삼촌이 청구서를 보내면 여기에서 회수·환급 상태를 확인할 수 있어요.'
                : '현장 지급과 배분을 마치면 여기에서 청구 상태를 추적할 수 있어요.',
            icon: 'document',
          )
        else
          for (final invoice in invoices)
            _InvoiceListCard(
              invoice: invoice,
              onTap: () => openPage<void>(
                context,
                InvoiceDetailPage(invoiceId: invoice.id),
              ),
            ),
      ],
    );
  }
}

class _InvoiceListCard extends StatelessWidget {
  const _InvoiceListCard({required this.invoice, required this.onTap});

  final InvoiceRecord invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return FigmaSurface(
      children: [
        Item(
          '총 청구 ${billingMoney(invoice.adjustedTotalAmount)}',
          subtitle: _invoiceSubtitle(app, invoice),
          leading: const FigmaIcon('document'),
          trailing: StatusBadge(
            invoice.inquiryOpenCount > 0
                ? '문의 ${invoice.inquiryOpenCount}건'
                : invoice.isOverdue
                ? '기한 지남'
                : invoice.refundRequiredAmount > 0
                ? '환급 ${billingMoney(invoice.refundRequiredAmount)}'
                : invoice.statusLabel,
            attention:
                invoice.inquiryOpenCount > 0 ||
                invoice.refundRequiredAmount > 0 ||
                invoice.isOverdue,
          ),
          onTap: onTap,
        ),
        Inset(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuantityRow(
                '회수 확인',
                billingMoney(invoice.confirmedReceiptAmount),
              ),
              QuantityRow('남은 금액', billingMoney(invoice.remainingDueAmount)),
              if (invoice.pendingReceiptCount > 0)
                QuantityRow(
                  '확인 대기',
                  '${invoice.pendingReceiptCount}건 · ${billingMoney(invoice.pendingReceiptAmount)}',
                ),
              if (invoice.dueAt.isNotEmpty)
                QuantityRow(
                  '입금 기한',
                  _dueAtLabel(invoice.dueAt, overdue: invoice.isOverdue),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage>
    with _BillingInputOwner<InvoiceDetailPage> {
  final adjustmentAmount = TextEditingController();
  final adjustmentReason = TextEditingController();
  final receiptAmount = TextEditingController();
  final receiptNote = TextEditingController();
  final reimbursementAmount = TextEditingController();
  final reimbursementNote = TextEditingController();
  final supplierRefundAmount = TextEditingController();
  final supplierRefundNote = TextEditingController();
  final inquiryNote = TextEditingController();
  final inquiryResolutionNote = TextEditingController();

  String _adjustmentKind = invoiceAdjustmentKinds.first;
  String _selectedReceiptTargetId = '';
  String _selectedReimbursementId = '';
  String _selectedSupplierRefundPaymentId = '';
  String _selectedSupplierRefundRecipientId = '';
  String _selectedOpenInquiryId = '';
  DateTime? _selectedDueAt;
  bool _dueAtEdited = false;
  bool _formsRestored = false;
  bool _resettingForms = false;

  String _adjustmentOperationId = newId();
  Data? _adjustmentSubmitted;
  String _receiptOperationId = newId();
  Data? _receiptSubmitted;
  String _reimbursementOperationId = newId();
  Data? _reimbursementSubmitted;
  String _supplierRefundOperationId = newId();
  Data? _supplierRefundSubmitted;
  String _inquiryOperationId = newId();
  Data? _inquirySubmitted;
  String _resolutionOperationId = newId();
  Data? _resolutionSubmitted;
  String _dueAtOperationId = newId();
  Data? _dueAtSubmitted;

  String get _adjustmentKey => 'billing-adjustment:${widget.invoiceId}';
  String get _receiptKey => 'billing-receipt:${widget.invoiceId}';
  String get _reimbursementKey => 'billing-reimbursement:${widget.invoiceId}';
  String get _supplierRefundKey =>
      'billing-supplier-refund:${widget.invoiceId}';
  String get _inquiryKey => 'billing-inquiry:${widget.invoiceId}';
  String get _resolutionKey => 'billing-resolution:${widget.invoiceId}';
  String get _dueAtKey => 'billing-due-at:${widget.invoiceId}';

  Data _adjustmentInput() => {
    'kind': _adjustmentKind,
    'amount': adjustmentAmount.text,
    'reason': adjustmentReason.text,
    'operationId': _adjustmentOperationId,
    if (_adjustmentSubmitted != null) 'submitted': _adjustmentSubmitted,
  };
  Data _receiptInput() => {
    'amount': receiptAmount.text,
    'note': receiptNote.text,
    'paidToId': _selectedReceiptTargetId,
    'operationId': _receiptOperationId,
    if (_receiptSubmitted != null) 'submitted': _receiptSubmitted,
  };
  Data _reimbursementInput() => {
    'reimbursementId': _selectedReimbursementId,
    'amount': reimbursementAmount.text,
    'note': reimbursementNote.text,
    'operationId': _reimbursementOperationId,
    if (_reimbursementSubmitted != null) 'submitted': _reimbursementSubmitted,
  };
  Data _supplierRefundInput() => {
    'paymentId': _selectedSupplierRefundPaymentId,
    'amount': supplierRefundAmount.text,
    'note': supplierRefundNote.text,
    'actualRecipientId': _selectedSupplierRefundRecipientId,
    'operationId': _supplierRefundOperationId,
    if (_supplierRefundSubmitted != null) 'submitted': _supplierRefundSubmitted,
  };
  Data _inquiryInput() => {
    'note': inquiryNote.text,
    'operationId': _inquiryOperationId,
    if (_inquirySubmitted != null) 'submitted': _inquirySubmitted,
  };
  Data _resolutionInput() => {
    'inquiryId': _selectedOpenInquiryId,
    'note': inquiryResolutionNote.text,
    'operationId': _resolutionOperationId,
    if (_resolutionSubmitted != null) 'submitted': _resolutionSubmitted,
  };
  Data _dueAtInput() => {
    if (_selectedDueAt != null) 'dueAt': dateOnly(_selectedDueAt!),
    'edited': _dueAtEdited,
    'operationId': _dueAtOperationId,
    if (_dueAtSubmitted != null) 'submitted': _dueAtSubmitted,
  };

  void _persistForm(String key, Data Function() values) {
    final app = _inputApp!;
    if (_resettingForms || !_sameInputAccount(app)) return;
    _saveInBackground(_saveForm(app, key, values()));
  }

  void _watchForm(
    List<TextEditingController> controllers,
    String key,
    Data Function() values,
  ) {
    for (final controller in controllers) {
      controller.addListener(() => _persistForm(key, values));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final invoice = app.workspace.invoices
        .where((row) => row.id == widget.invoiceId)
        .firstOrNull;
    if (invoice == null || !_sameInputAccount(app)) return;
    if (!_dueAtEdited) {
      _selectedDueAt = _dateFromText(invoice.dueAt);
    }
    if (_formsRestored) return;
    _formsRestored = true;
    {
      final saved = app.workspace.workflowInput(_adjustmentKey);
      adjustmentAmount.text = textOf(saved, 'amount');
      adjustmentReason.text = textOf(saved, 'reason');
      _adjustmentKind = textOf(saved, 'kind', _adjustmentKind);
      _adjustmentOperationId = textOf(
        saved,
        'operationId',
        _adjustmentOperationId,
      );
      _adjustmentSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _adjustmentOperationId,
      );
    }
    {
      final saved = app.workspace.workflowInput(_receiptKey);
      receiptAmount.text = textOf(saved, 'amount');
      receiptNote.text = textOf(saved, 'note');
      _selectedReceiptTargetId = textOf(saved, 'paidToId');
      _receiptOperationId = textOf(saved, 'operationId', _receiptOperationId);
      _receiptSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _receiptOperationId,
      );
    }
    {
      final saved = app.workspace.workflowInput(_reimbursementKey);
      reimbursementAmount.text = textOf(saved, 'amount');
      reimbursementNote.text = textOf(saved, 'note');
      _selectedReimbursementId = textOf(saved, 'reimbursementId');
      _reimbursementOperationId = textOf(
        saved,
        'operationId',
        _reimbursementOperationId,
      );
      _reimbursementSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _reimbursementOperationId,
      );
    }
    {
      final saved = app.workspace.workflowInput(_supplierRefundKey);
      supplierRefundAmount.text = textOf(saved, 'amount');
      supplierRefundNote.text = textOf(saved, 'note');
      _selectedSupplierRefundPaymentId = textOf(saved, 'paymentId');
      _selectedSupplierRefundRecipientId = textOf(saved, 'actualRecipientId');
      _supplierRefundOperationId = textOf(
        saved,
        'operationId',
        _supplierRefundOperationId,
      );
      _supplierRefundSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _supplierRefundOperationId,
      );
    }
    {
      final saved = app.workspace.workflowInput(_inquiryKey);
      inquiryNote.text = textOf(saved, 'note');
      _inquiryOperationId = textOf(saved, 'operationId', _inquiryOperationId);
      _inquirySubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _inquiryOperationId,
      );
    }
    _watchForm(
      [adjustmentAmount, adjustmentReason],
      _adjustmentKey,
      _adjustmentInput,
    );
    _watchForm([receiptAmount, receiptNote], _receiptKey, _receiptInput);
    _watchForm(
      [reimbursementAmount, reimbursementNote],
      _reimbursementKey,
      _reimbursementInput,
    );
    _watchForm(
      [supplierRefundAmount, supplierRefundNote],
      _supplierRefundKey,
      _supplierRefundInput,
    );
    _watchForm([inquiryNote], _inquiryKey, _inquiryInput);
    {
      final saved = app.workspace.workflowInput(_resolutionKey);
      inquiryResolutionNote.text = textOf(saved, 'note');
      _selectedOpenInquiryId = textOf(saved, 'inquiryId');
      _resolutionOperationId = textOf(
        saved,
        'operationId',
        _resolutionOperationId,
      );
      _resolutionSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _resolutionOperationId,
      );
    }
    {
      final saved = app.workspace.workflowInput(_dueAtKey);
      _dueAtEdited = flagOf(saved, 'edited');
      if (_dueAtEdited) _selectedDueAt = _dateFromText(textOf(saved, 'dueAt'));
      _dueAtOperationId = textOf(saved, 'operationId', _dueAtOperationId);
      _dueAtSubmitted = _restoreSubmitted(
        app.workspace,
        saved,
        _dueAtOperationId,
      );
    }
    _watchForm([inquiryResolutionNote], _resolutionKey, _resolutionInput);
  }

  @override
  void dispose() {
    adjustmentAmount.dispose();
    adjustmentReason.dispose();
    receiptAmount.dispose();
    receiptNote.dispose();
    reimbursementAmount.dispose();
    reimbursementNote.dispose();
    supplierRefundAmount.dispose();
    supplierRefundNote.dispose();
    inquiryNote.dispose();
    inquiryResolutionNote.dispose();
    super.dispose();
  }

  Future<void> _saveForm(AppServices app, String key, Data values) =>
      _saveOwnedInput(app, key, values);

  int _parseRequiredAmount(
    String text,
    String label, {
    bool allowZero = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw AppFailure('$label 값을 입력해 주세요.');
    }
    final value = int.tryParse(trimmed);
    if (value == null || value < 0) {
      throw AppFailure('$label 값을 다시 확인해 주세요.');
    }
    if (!allowZero && value == 0) {
      throw AppFailure('$label 값은 0보다 커야 해요.');
    }
    return value;
  }

  Future<void> _submitWithPersistence({
    required AppServices app,
    required String key,
    required String operationId,
    required Data Function() draftBuilder,
    required Future<void> Function() invoke,
    required VoidCallback onSuccess,
    required void Function() resetSubmitted,
  }) async {
    _requireInputAccount(app);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
    await _saveForm(app, key, draftBuilder());
    _requireInputAccount(app);
    try {
      await invoke();
    } catch (_) {
      if (!_sameInputAccount(app)) rethrow;
      final rejected = _hasRejectedWorkflow(app.workspace, operationId);
      if (rejected) {
        await app.workspace.discardRejectedWorkflow(operationId);
      }
      if (rejected || !_hasLiveWorkflow(app.workspace, operationId)) {
        resetSubmitted();
        await _saveForm(app, key, draftBuilder());
        if (mounted) setState(() {});
      }
      rethrow;
    }
    await _saveOwnedInput(app, key, {});
    _requireInputAccount(app);
    if (!mounted) return;
    _resettingForms = true;
    try {
      setState(onSuccess);
    } finally {
      _resettingForms = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    final invoice = app.workspace.invoices
        .where((row) => row.id == widget.invoiceId)
        .firstOrNull;
    if (invoice == null || !_sameInputAccount(app)) {
      return const PageFrame(
        title: '청구 상세',
        children: [EmptyState.titleOnly('청구를 찾을 수 없어요')],
      );
    }
    final adjustments =
        app.workspace.invoiceAdjustments
            .where((row) => row.invoiceId == invoice.id)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final receipts =
        app.workspace.invoiceReceipts
            .where((row) => row.invoiceId == invoice.id)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final inquiries =
        app.workspace.invoiceInquiries
            .where((row) => row.invoiceId == invoice.id)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final reimbursements =
        app.workspace.reimbursements
            .where((row) => row.invoiceId == invoice.id)
            .toList(growable: false)
          ..sort((left, right) => left.kind.compareTo(right.kind));
    final fieldPayments =
        app.workspace.fieldPayments
            .where((row) => invoice.fieldPaymentIds.contains(row.id))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final supplierRefunds =
        app.workspace.supplierRefunds
            .where((row) => row.invoiceId == invoice.id)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    if (_receiptSubmitted == null) _selectedReceiptTargetId = platformPayeeId;
    final requestIds = stringsOf(invoice.data, 'requestIds');
    final allReceived =
        requestIds.isNotEmpty &&
        requestIds.every(
          (id) => app.workspace.request(id)?.receiptComplete == true,
        );
    final unreported =
        invoice.adjustedTotalAmount - invoice.reportedReceiptAmount;
    final paymentReady =
        !invoice.b('requiresReconciliation') && invoice.missingAmountCount == 0;
    final isRetailer = current?.role == AppRole.retailer;
    final canManageInvoice =
        current != null &&
        stringsOf(invoice.data, 'managerIds').contains(current.id);
    final refundable = reimbursements
        .where(
          (row) =>
              row.remainingAmount > 0 &&
              (canManageInvoice ||
                  row.fromId == current?.id ||
                  row.toId == current?.id),
        )
        .toList(growable: false);
    _selectedReimbursementId = _selectedReimbursementId.isEmpty
        ? (refundable.firstOrNull?.id ?? '')
        : _selectedReimbursementId;
    final refundPayments = fieldPayments
        .where(
          (row) =>
              row.uncleId == current?.id ||
              row.payeeId == current?.id ||
              row.payerId == current?.id,
        )
        .toList(growable: false);
    final refundPayment =
        refundPayments
            .where((row) => row.id == _selectedSupplierRefundPaymentId)
            .firstOrNull ??
        refundPayments.firstOrNull;
    if (_supplierRefundSubmitted == null) {
      _selectedSupplierRefundPaymentId = refundPayment?.id ?? '';
    }
    final supplierRefundTargets = _supplierRefundTargets(
      app,
      refundPayment == null ? const [] : [refundPayment],
    );
    _selectedSupplierRefundRecipientId =
        _supplierRefundSubmitted == null &&
            !supplierRefundTargets.any(
              (row) => row.id == _selectedSupplierRefundRecipientId,
            )
        ? (supplierRefundTargets.firstOrNull?.id ?? '')
        : _selectedSupplierRefundRecipientId;
    final openInquiries = inquiries
        .where((row) => row.status == 'open')
        .toList(growable: false);
    _selectedOpenInquiryId =
        _resolutionSubmitted == null &&
            !openInquiries.any((row) => row.id == _selectedOpenInquiryId)
        ? (openInquiries.firstOrNull?.id ?? '')
        : _selectedOpenInquiryId;

    return PageFrame(
      title: '청구 상세',
      navigationSubtitle: _invoiceSubtitle(app, invoice),
      children: [
        if (_inputSaveFailed)
          const Inset(child: Info('입력을 저장하지 못했어요. 다시 시도해 주세요.')),
        Section(invoice.label.isEmpty ? '청구 요약' : invoice.label),
        FigmaSurface(
          children: [
            Item(
              '총 청구 ${billingMoney(invoice.adjustedTotalAmount)}',
              subtitle: invoice.statusLabel,
              leading: const FigmaIcon('document'),
              trailing: StatusBadge(
                invoice.inquiryOpenCount > 0
                    ? '문의 ${invoice.inquiryOpenCount}건'
                    : invoice.statusLabel,
                attention: invoice.inquiryOpenCount > 0,
              ),
            ),
            Inset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuantityRow(
                    '상품 대납 원금',
                    billingMoney(invoice.principalAmount),
                  ),
                  QuantityRow('배달비', billingMoney(invoice.deliveryFeeAmount)),
                  QuantityRow(
                    '조정 합계',
                    billingMoney(invoice.adjustmentTotalAmount),
                  ),
                  QuantityRow(
                    '입금 확인액',
                    billingMoney(invoice.confirmedReceiptAmount),
                  ),
                  QuantityRow(
                    '남은 금액',
                    billingMoney(invoice.remainingDueAmount),
                  ),
                  if (invoice.pendingReceiptCount > 0)
                    QuantityRow(
                      '확인 대기',
                      '${invoice.pendingReceiptCount}건 · ${billingMoney(invoice.pendingReceiptAmount)}',
                    ),
                  if (invoice.refundRequiredAmount > 0)
                    QuantityRow(
                      '남은 환급',
                      billingMoney(invoice.refundRequiredAmount),
                    ),
                  if (invoice.dueAt.isNotEmpty)
                    QuantityRow(
                      '입금 기한',
                      _dueAtLabel(invoice.dueAt, overdue: invoice.isOverdue),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (invoice.status != 'draft') ...[
          const Section('운영 계좌 입금'),
          const FigmaSurface(
            children: [
              QuantityRow('은행', platformBankName),
              QuantityRow('계좌번호', platformBankAccount),
              QuantityRow('예금주', platformBankHolder),
              Info('소매업자가 운영 계좌로 무통장입금하면, 운영자가 입금을 확인한 뒤 사입삼촌에게 지급해요.'),
            ],
          ),
          if (invoice.adjustedTotalAmount == 0)
            const Info('정산할 금액이 없어요')
          else if (invoice.b('platformPayoutComplete'))
            const Info('사입삼촌 지급 완료')
          else if (invoice.confirmedReceiptAmount >=
              invoice.adjustedTotalAmount)
            const Info('입금 확인 완료 · 사입삼촌 지급 대기')
          else if (invoice.pendingReceiptCount > 0)
            const Info('송금 알림을 남겼어요 · 운영 확인 대기'),
        ],
        if (isRetailer && receipts.isNotEmpty) ...[
          const Section('내 송금 알림'),
          for (final receipt in receipts)
            Item(
              billingMoney(receipt.amount),
              subtitle: receipt.status == 'reported'
                  ? '운영 확인 대기'
                  : receipt.statusLabel,
              trailing: StatusBadge(receipt.statusLabel),
            ),
        ],
        if (inquiries.isNotEmpty) ...[
          Section('금액 문의'),
          for (final inquiry in inquiries)
            FigmaSurface(
              children: [
                Item(
                  inquiry.statusLabel,
                  subtitle: inquiry.note,
                  leading: const FigmaIcon('chat'),
                  trailing: StatusBadge(
                    inquiry.statusLabel,
                    attention: inquiry.status == 'open',
                  ),
                ),
              ],
            ),
          if (!isRetailer &&
              canManageInvoice &&
              (openInquiries.isNotEmpty || _resolutionSubmitted != null))
            FigmaSurface(
              children: [
                Inset(
                  child: _billingInputs(
                    ignoring: _resolutionSubmitted != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_resolutionSubmitted != null)
                          const Info(
                            '문의 해결을 전송 확인 중이에요. 같은 작업번호로 다시 확인할 수 있어요.',
                          ),
                        if (openInquiries.isNotEmpty)
                          Choices(
                            options: [
                              for (final inquiry in openInquiries)
                                '${openInquiries.indexOf(inquiry) + 1}. ${inquiry.note}',
                            ],
                            value: () {
                              final target = openInquiries.firstWhere(
                                (row) => row.id == _selectedOpenInquiryId,
                                orElse: () => openInquiries.first,
                              );
                              return '${openInquiries.indexOf(target) + 1}. ${target.note}';
                            }(),
                            onChanged: (label) {
                              final target = openInquiries.firstWhere(
                                (row) =>
                                    '${openInquiries.indexOf(row) + 1}. ${row.note}' ==
                                    label,
                              );
                              setState(
                                () => _selectedOpenInquiryId = target.id,
                              );
                              _persistForm(_resolutionKey, _resolutionInput);
                            },
                          ),
                        Field(
                          '해결 메모(선택)',
                          controller: inquiryResolutionNote,
                          multiline: true,
                        ),
                      ],
                    ),
                  ),
                ),
                ActionButton(
                  '선택한 문의 해결',
                  icon: 'check',
                  onPressed: () async {
                    _resolutionSubmitted ??= () {
                      final target = openInquiries.firstWhere(
                        (row) => row.id == _selectedOpenInquiryId,
                      );
                      return {
                        'inquiryId': target.id,
                        'version': target.version,
                        'note': inquiryResolutionNote.text.trim(),
                      };
                    }();
                    await _submitWithPersistence(
                      app: app,
                      key: _resolutionKey,
                      operationId: _resolutionOperationId,
                      draftBuilder: _resolutionInput,
                      invoke: () => app.workspace.resolveInvoiceInquiry(
                        _resolutionSubmitted!,
                        operationId: _resolutionOperationId,
                      ),
                      resetSubmitted: () {
                        _resolutionSubmitted = null;
                        _resolutionOperationId = newId();
                      },
                      onSuccess: () {
                        inquiryResolutionNote.clear();
                        _selectedOpenInquiryId = '';
                        _resolutionSubmitted = null;
                        _resolutionOperationId = newId();
                      },
                    );
                  },
                ),
              ],
            ),
        ],
        if (isRetailer) ...[
          Section('송금 알림'),
          if (!allReceived)
            const Info('청구서에 포함된 상품을 모두 수령 확인한 후 입금해 주세요.')
          else if (!paymentReady)
            const Info('청구 금액을 다시 확인 중이에요. 정리가 끝난 후 입금해 주세요.')
          else if (unreported <= 0)
            const Info('청구 금액의 송금 알림을 모두 남겼어요. 중복 입금하지 않도록 확인해 주세요.'),
          if ((allReceived && paymentReady && unreported > 0) ||
              _receiptSubmitted != null)
            FigmaSurface(
              children: [
                if (_receiptSubmitted != null)
                  const Inset(
                    child: Info('이 송금 알림은 전송 확인 중이에요. 다시 누르면 같은 작업번호로 재시도해요.'),
                  ),
                Inset(
                  child: _billingInputs(
                    ignoring: _receiptSubmitted != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Field(
                          '송금 금액',
                          controller: receiptAmount,
                          numeric: true,
                        ),
                        Info('아직 신고하지 않은 금액 ${billingMoney(unreported)}'),
                        const Info(
                          '은행에서 이체를 마친 뒤 송금 알림을 남겨 주세요. 알림만으로 실제 입금이 확인되지는 않아요.',
                        ),
                        Field('메모', controller: receiptNote, multiline: true),
                      ],
                    ),
                  ),
                ),
                ActionButton(
                  '송금 알림 남기기',
                  icon: 'send',
                  onPressed: () async {
                    _receiptSubmitted ??= {
                      'invoiceId': invoice.id,
                      'amount': _parseRequiredAmount(
                        receiptAmount.text,
                        '송금 금액',
                      ),
                      'paidToId': _selectedReceiptTargetId,
                      'note': receiptNote.text.trim(),
                    };
                    await _submitWithPersistence(
                      app: app,
                      key: _receiptKey,
                      operationId: _receiptOperationId,
                      draftBuilder: _receiptInput,
                      invoke: () => app.workspace.reportInvoiceReceipt(
                        _receiptSubmitted!,
                        operationId: _receiptOperationId,
                      ),
                      resetSubmitted: () {
                        _receiptSubmitted = null;
                        _receiptOperationId = newId();
                      },
                      onSuccess: () {
                        receiptAmount.clear();
                        receiptNote.clear();
                        _receiptSubmitted = null;
                        _receiptOperationId = newId();
                      },
                    );
                  },
                ),
              ],
            ),
          Section('금액 문의'),
          FigmaSurface(
            children: [
              Inset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Info('같은 청구서에 대한 문의로 남기며, 채팅에도 문의 플래그가 함께 기록돼요.'),
                    _billingInputs(
                      ignoring: _inquirySubmitted != null,
                      child: Field(
                        '문의 내용',
                        controller: inquiryNote,
                        multiline: true,
                      ),
                    ),
                  ],
                ),
              ),
              ActionButton(
                '금액 문의 보내기',
                icon: 'chat',
                onPressed: () async {
                  final note = inquiryNote.text.trim();
                  if (_inquirySubmitted == null && note.isEmpty) {
                    throw const AppFailure('문의 내용을 입력해 주세요.');
                  }
                  _inquirySubmitted ??= {'invoiceId': invoice.id, 'note': note};
                  await _submitWithPersistence(
                    app: app,
                    key: _inquiryKey,
                    operationId: _inquiryOperationId,
                    draftBuilder: _inquiryInput,
                    invoke: () => app.workspace.flagInvoiceInquiry(
                      _inquirySubmitted!,
                      operationId: _inquiryOperationId,
                    ),
                    resetSubmitted: () {
                      _inquirySubmitted = null;
                      _inquiryOperationId = newId();
                    },
                    onSuccess: () {
                      inquiryNote.clear();
                      _inquirySubmitted = null;
                      _inquiryOperationId = newId();
                    },
                  );
                },
              ),
            ],
          ),
        ] else ...[
          if (fieldPayments.isNotEmpty) ...[
            Section('현장 지급 배경'),
            for (final payment in fieldPayments)
              FigmaSurface(
                children: [
                  Item(
                    payment.wholesaler.isEmpty ? '현장 지급' : payment.wholesaler,
                    subtitle: requestTitle(
                      app.workspace.request(payment.requestId)?.data ??
                          const {},
                    ),
                    leading: const FigmaIcon('money'),
                    trailing: StatusBadge(
                      payment.unallocatedAmount > 0
                          ? '미배분 ${billingMoney(payment.unallocatedAmount)}'
                          : '배분 완료',
                      attention: payment.unallocatedAmount > 0,
                    ),
                  ),
                  Inset(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuantityRow(
                          '총 지급액',
                          billingMoney(payment.actualPaidAmount),
                        ),
                        QuantityRow(
                          '고객 부담',
                          billingMoney(payment.customerChargeAmount),
                        ),
                        QuantityRow(
                          '직접 결제',
                          billingMoney(payment.directPaidAmount),
                        ),
                        QuantityRow(
                          '수수료·차액',
                          billingMoney(payment.supplierFeeAmount),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          Section('회수 처리'),
          for (final receipt in receipts)
            FigmaSurface(
              children: [
                Item(
                  billingMoney(receipt.amount),
                  subtitle: receipt.note.isEmpty
                      ? receipt.statusLabel
                      : '${receipt.statusLabel} · ${receipt.note}',
                  leading: const FigmaIcon('money'),
                  trailing: StatusBadge(
                    receipt.statusLabel,
                    attention: receipt.status == 'reported',
                  ),
                ),
                Inset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuantityRow(
                        '실제 수취자',
                        _displayName(app, receipt.paidToId),
                      ),
                      QuantityRow('알림 시각', displayTime(receipt.s('createdAt'))),
                    ],
                  ),
                ),
                if (receipt.status == 'reported' &&
                    canManageInvoice &&
                    receipt.paidToId != platformPayeeId)
                  ActionButton(
                    '송금 알림 반려',
                    icon: 'close',
                    weak: true,
                    danger: true,
                    onPressed: () async {
                      await app.workspace.confirmInvoiceReceipt({
                        'receiptId': receipt.id,
                        'version': receipt.version,
                        'confirmed': false,
                      });
                    },
                  ),
                if (receipt.status == 'reported' &&
                    canManageInvoice &&
                    receipt.paidToId != platformPayeeId)
                  ActionButton(
                    '회수 확인',
                    icon: 'check',
                    onPressed: () async {
                      await app.workspace.confirmInvoiceReceipt({
                        'receiptId': receipt.id,
                        'version': receipt.version,
                      });
                    },
                  ),
              ],
            ),
          Section('조정'),
          if (adjustments.isNotEmpty)
            for (final adjustment in adjustments)
              FigmaSurface(
                children: [
                  Item(
                    '${invoiceAdjustmentLabel(adjustment.kind)} ${billingMoney(adjustment.amount)}',
                    subtitle: adjustment.reason,
                    leading: const FigmaIcon('edit'),
                  ),
                ],
              ),
          if (canManageInvoice) Section('입금 기한'),
          if (canManageInvoice)
            FigmaSurface(
              children: [
                Inset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Info(
                        invoice.isOverdue
                            ? '기한이 지난 청구서예요. 새 기한을 다시 정할 수 있어요.'
                            : '선택한 기한은 소매업자에게 함께 보여요.',
                      ),
                      if (_dueAtSubmitted != null)
                        const Info('기한 변경을 저장 확인 중이에요. 같은 작업번호로 다시 확인할 수 있어요.'),
                      _billingInputs(
                        ignoring: _dueAtSubmitted != null,
                        child: TdsWheelDatePicker(
                          title: '입금 기한 선택',
                          triggerLabel: '입금 기한',
                          value: _selectedDueAt,
                          initialDate: _selectedDueAt ?? DateTime.now(),
                          onChange: (value) {
                            setState(() {
                              _selectedDueAt = value;
                              _dueAtEdited = true;
                            });
                            _persistForm(_dueAtKey, _dueAtInput);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                ActionButton(
                  '입금 기한 저장',
                  icon: 'check',
                  enabled: _selectedDueAt != null || _dueAtSubmitted != null,
                  onPressed: () async {
                    if (_dueAtSubmitted == null && _selectedDueAt == null) {
                      throw const AppFailure('입금 기한을 먼저 선택해 주세요.');
                    }
                    _dueAtSubmitted ??= {
                      'invoiceId': invoice.id,
                      'invoiceVersion': invoice.version,
                      'dueAt': dateOnly(_selectedDueAt!),
                    };
                    await _submitWithPersistence(
                      app: app,
                      key: _dueAtKey,
                      operationId: _dueAtOperationId,
                      draftBuilder: _dueAtInput,
                      invoke: () => app.workspace.createInvoiceDraft(
                        _dueAtSubmitted!,
                        operationId: _dueAtOperationId,
                      ),
                      resetSubmitted: () {
                        _dueAtSubmitted = null;
                        _dueAtOperationId = newId();
                      },
                      onSuccess: () {
                        _dueAtEdited = false;
                        _dueAtSubmitted = null;
                        _dueAtOperationId = newId();
                      },
                    );
                  },
                ),
              ],
            ),
          if (canManageInvoice)
            FigmaSurface(
              children: [
                if (_adjustmentSubmitted != null)
                  const Inset(
                    child: Info('이 조정은 저장 확인 중이에요. 다시 누르면 같은 작업번호로 재시도해요.'),
                  ),
                Inset(
                  child: _billingInputs(
                    ignoring: _adjustmentSubmitted != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Choices(
                          options: [
                            for (final kind in invoiceAdjustmentKinds)
                              invoiceAdjustmentLabel(kind),
                          ],
                          value: invoiceAdjustmentLabel(_adjustmentKind),
                          onChanged: (label) {
                            setState(
                              () => _adjustmentKind = _adjustmentKindOf(label),
                            );
                            _persistForm(_adjustmentKey, _adjustmentInput);
                          },
                        ),
                        Field(
                          '조정 금액',
                          controller: adjustmentAmount,
                          numeric: true,
                        ),
                        Field(
                          '조정 사유',
                          controller: adjustmentReason,
                          multiline: true,
                        ),
                      ],
                    ),
                  ),
                ),
                ActionButton(
                  '조정 기록',
                  icon: 'edit',
                  onPressed: () async {
                    _adjustmentSubmitted ??= {
                      'invoiceId': invoice.id,
                      'invoiceVersion': invoice.version,
                      'kind': _adjustmentKind,
                      'amount': _parseRequiredAmount(
                        adjustmentAmount.text,
                        '조정 금액',
                      ),
                      'reason': adjustmentReason.text.trim(),
                    };
                    await _submitWithPersistence(
                      app: app,
                      key: _adjustmentKey,
                      operationId: _adjustmentOperationId,
                      draftBuilder: _adjustmentInput,
                      invoke: () => app.workspace.addInvoiceAdjustment(
                        _adjustmentSubmitted!,
                        operationId: _adjustmentOperationId,
                      ),
                      resetSubmitted: () {
                        _adjustmentSubmitted = null;
                        _adjustmentOperationId = newId();
                      },
                      onSuccess: () {
                        adjustmentAmount.clear();
                        adjustmentReason.clear();
                        _adjustmentSubmitted = null;
                        _adjustmentOperationId = newId();
                      },
                    );
                  },
                ),
              ],
            ),
          Section('반환·환급 정산'),
          for (final reimbursement in reimbursements)
            FigmaSurface(
              children: [
                Item(
                  reimbursementKindLabel(reimbursement.kind),
                  subtitle:
                      '${_displayName(app, reimbursement.fromId)} → ${_displayName(app, reimbursement.toId)}',
                  leading: const FigmaIcon('money'),
                  trailing: StatusBadge(
                    reimbursement.status,
                    attention: reimbursement.remainingAmount > 0,
                  ),
                ),
                Inset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuantityRow(
                        '총 대상',
                        billingMoney(reimbursement.totalAmount),
                      ),
                      QuantityRow(
                        '반영 완료',
                        billingMoney(reimbursement.settledAmount),
                      ),
                      QuantityRow(
                        '남은 금액',
                        billingMoney(reimbursement.remainingAmount),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (refundable.isNotEmpty || _reimbursementSubmitted != null)
            FigmaSurface(
              children: [
                if (_reimbursementSubmitted != null)
                  const Inset(
                    child: Info('이 정산은 저장 확인 중이에요. 다시 누르면 같은 작업번호로 재시도해요.'),
                  ),
                Inset(
                  child: _billingInputs(
                    ignoring: _reimbursementSubmitted != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (refundable.isNotEmpty)
                          Choices(
                            options: [
                              for (final row in refundable)
                                _reimbursementChoiceLabel(app, row),
                            ],
                            value: _reimbursementChoiceLabel(
                              app,
                              refundable.firstWhere(
                                (row) => row.id == _selectedReimbursementId,
                                orElse: () => refundable.first,
                              ),
                            ),
                            onChanged: (label) {
                              final target = refundable.firstWhere(
                                (row) =>
                                    _reimbursementChoiceLabel(app, row) ==
                                    label,
                              );
                              setState(
                                () => _selectedReimbursementId = target.id,
                              );
                              _persistForm(
                                _reimbursementKey,
                                _reimbursementInput,
                              );
                            },
                          ),
                        Field(
                          '정산 금액',
                          controller: reimbursementAmount,
                          numeric: true,
                        ),
                        Field(
                          '정산 메모',
                          controller: reimbursementNote,
                          multiline: true,
                        ),
                      ],
                    ),
                  ),
                ),
                ActionButton(
                  '정산 반영',
                  icon: 'check',
                  onPressed: () async {
                    _reimbursementSubmitted ??= () {
                      final target = refundable.firstWhere(
                        (row) => row.id == _selectedReimbursementId,
                        orElse: () => refundable.first,
                      );
                      return {
                        'invoiceId': invoice.id,
                        'reimbursementId': target.id,
                        'version': target.version,
                        'amount': _parseRequiredAmount(
                          reimbursementAmount.text,
                          '정산 금액',
                        ),
                        'note': reimbursementNote.text.trim(),
                      };
                    }();
                    await _submitWithPersistence(
                      app: app,
                      key: _reimbursementKey,
                      operationId: _reimbursementOperationId,
                      draftBuilder: _reimbursementInput,
                      invoke: () => app.workspace.settleReimbursement(
                        _reimbursementSubmitted!,
                        operationId: _reimbursementOperationId,
                      ),
                      resetSubmitted: () {
                        _reimbursementSubmitted = null;
                        _reimbursementOperationId = newId();
                      },
                      onSuccess: () {
                        reimbursementAmount.clear();
                        reimbursementNote.clear();
                        _reimbursementSubmitted = null;
                        _reimbursementOperationId = newId();
                      },
                    );
                  },
                ),
              ],
            ),
          Section('도매처 환급'),
          for (final refund in supplierRefunds)
            FigmaSurface(
              children: [
                Item(
                  billingMoney(refund.amount),
                  subtitle:
                      '${_displayName(app, refund.actualRecipientId)} · ${refund.note}',
                  leading: const FigmaIcon('money'),
                ),
              ],
            ),
          if ((refundPayment != null && supplierRefundTargets.isNotEmpty) ||
              _supplierRefundSubmitted != null)
            FigmaSurface(
              children: [
                if (_supplierRefundSubmitted != null)
                  const Inset(
                    child: Info('이 도매처 환급은 저장 확인 중이에요. 다시 누르면 같은 작업번호로 재시도해요.'),
                  ),
                Inset(
                  child: _billingInputs(
                    ignoring: _supplierRefundSubmitted != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (refundPayments.isNotEmpty)
                          Choices(
                            options: [
                              for (final row in refundPayments)
                                '${refundPayments.indexOf(row) + 1}. ${row.wholesaler.isEmpty ? '현장 지급' : row.wholesaler} · ${billingMoney(row.actualPaidAmount)}',
                            ],
                            value: refundPayment == null
                                ? ''
                                : '${refundPayments.indexOf(refundPayment) + 1}. ${refundPayment.wholesaler.isEmpty ? '현장 지급' : refundPayment.wholesaler} · ${billingMoney(refundPayment.actualPaidAmount)}',
                            onChanged: (label) {
                              final target = refundPayments.firstWhere(
                                (row) =>
                                    '${refundPayments.indexOf(row) + 1}. ${row.wholesaler.isEmpty ? '현장 지급' : row.wholesaler} · ${billingMoney(row.actualPaidAmount)}' ==
                                    label,
                              );
                              setState(() {
                                _selectedSupplierRefundPaymentId = target.id;
                                _selectedSupplierRefundRecipientId =
                                    _supplierRefundTargets(app, [
                                      target,
                                    ]).firstOrNull?.id ??
                                    '';
                              });
                              _persistForm(
                                _supplierRefundKey,
                                _supplierRefundInput,
                              );
                            },
                          ),
                        if (supplierRefundTargets.isNotEmpty)
                          Choices(
                            options: [
                              for (final row in supplierRefundTargets)
                                row.label,
                            ],
                            value: supplierRefundTargets
                                .firstWhere(
                                  (row) =>
                                      row.id ==
                                      _selectedSupplierRefundRecipientId,
                                  orElse: () => supplierRefundTargets.first,
                                )
                                .label,
                            onChanged: (label) {
                              final target = supplierRefundTargets.firstWhere(
                                (row) => row.label == label,
                              );
                              setState(
                                () => _selectedSupplierRefundRecipientId =
                                    target.id,
                              );
                              _persistForm(
                                _supplierRefundKey,
                                _supplierRefundInput,
                              );
                            },
                          ),
                        Field(
                          '도매처 환급 금액',
                          controller: supplierRefundAmount,
                          numeric: true,
                        ),
                        Field(
                          '도매처 환급 메모',
                          controller: supplierRefundNote,
                          multiline: true,
                        ),
                      ],
                    ),
                  ),
                ),
                ActionButton(
                  '도매처 환급 기록',
                  icon: 'plus',
                  onPressed: () async {
                    if (_supplierRefundSubmitted == null &&
                        refundPayment == null) {
                      throw const AppFailure('환급 대상 지급 내역을 선택해 주세요.');
                    }
                    _supplierRefundSubmitted ??= {
                      'paymentId': refundPayment!.id,
                      'version': refundPayment.version,
                      'actualRecipientId': _selectedSupplierRefundRecipientId,
                      'amount': _parseRequiredAmount(
                        supplierRefundAmount.text,
                        '도매처 환급 금액',
                      ),
                      'note': supplierRefundNote.text.trim(),
                    };
                    await _submitWithPersistence(
                      app: app,
                      key: _supplierRefundKey,
                      operationId: _supplierRefundOperationId,
                      draftBuilder: _supplierRefundInput,
                      invoke: () => app.workspace.recordSupplierRefund(
                        _supplierRefundSubmitted!,
                        operationId: _supplierRefundOperationId,
                      ),
                      resetSubmitted: () {
                        _supplierRefundSubmitted = null;
                        _supplierRefundOperationId = newId();
                      },
                      onSuccess: () {
                        supplierRefundAmount.clear();
                        supplierRefundNote.clear();
                        _supplierRefundSubmitted = null;
                        _supplierRefundOperationId = newId();
                      },
                    );
                  },
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class FieldPaymentPage extends StatefulWidget {
  const FieldPaymentPage({required this.requestId, super.key});

  final String requestId;

  @override
  State<FieldPaymentPage> createState() => _FieldPaymentPageState();
}

class _FieldPaymentPageState extends State<FieldPaymentPage>
    with _BillingInputOwner<FieldPaymentPage> {
  final wholesaler = TextEditingController();
  final actualPaidAmount = TextEditingController();
  final cashAllocatedAmount = TextEditingController();
  final customerChargeAmount = TextEditingController();
  final directPaidAmount = TextEditingController();
  final supplierFeeAmount = TextEditingController();
  final note = TextEditingController();
  final allocationCashAllocatedAmount = TextEditingController();
  final allocationCustomerCharge = TextEditingController();
  final allocationDirectPaid = TextEditingController();
  final allocationSupplierFee = TextEditingController();
  final allocationNote = TextEditingController();

  String fundingSource = fieldPaymentFundingSources.first;
  String settlementKind = fieldPaymentSettlementKinds.first;
  String _selectedPayeeId = '';
  String _editingPaymentId = '';
  String _selectedPaymentId = '';
  String _editingAllocationId = '';
  String _recordOperationId = newId();
  Data? _recordSubmitted;
  String _allocationOperationId = newId();
  Data? _allocationSubmitted;
  String? lastRecordedId;
  bool _recordRestored = false;
  bool _allocationRestored = false;

  String get _inputKey => 'billing-field-payment:${widget.requestId}';
  String get _allocationKey => 'billing-allocation:${widget.requestId}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = AppScope.of(context).workspace;
    if (!_recordRestored) {
      final saved = workspace.workflowInput(_inputKey);
      wholesaler.text = textOf(saved, 'wholesaler');
      actualPaidAmount.text = textOf(saved, 'actualPaidAmount');
      cashAllocatedAmount.text = textOf(saved, 'cashAllocatedAmount');
      customerChargeAmount.text = textOf(saved, 'customerChargeAmount');
      directPaidAmount.text = textOf(saved, 'directPaidAmount');
      supplierFeeAmount.text = textOf(saved, 'supplierFeeAmount');
      note.text = textOf(saved, 'note');
      fundingSource = textOf(saved, 'fundingSource', fundingSource);
      settlementKind = textOf(saved, 'settlementKind', settlementKind);
      _selectedPayeeId = textOf(saved, 'payeeId');
      _editingPaymentId = textOf(saved, 'editingPaymentId');
      _recordOperationId = textOf(saved, 'operationId', _recordOperationId);
      _recordSubmitted = _restoreSubmitted(
        workspace,
        saved,
        _recordOperationId,
      );
      _recordRestored = true;
    }
    if (!_allocationRestored) {
      final saved = workspace.workflowInput(_allocationKey);
      allocationCashAllocatedAmount.text = textOf(saved, 'cashAllocatedAmount');
      allocationCustomerCharge.text = textOf(saved, 'customerChargeAmount');
      allocationDirectPaid.text = textOf(saved, 'directPaidAmount');
      allocationSupplierFee.text = textOf(saved, 'supplierFeeAmount');
      allocationNote.text = textOf(saved, 'note');
      _selectedPaymentId = textOf(saved, 'paymentId');
      _editingAllocationId = textOf(saved, 'allocationId');
      _allocationOperationId = textOf(
        saved,
        'operationId',
        _allocationOperationId,
      );
      _allocationSubmitted = _restoreSubmitted(
        workspace,
        saved,
        _allocationOperationId,
      );
      _allocationRestored = true;
    }
  }

  @override
  void dispose() {
    wholesaler.dispose();
    actualPaidAmount.dispose();
    cashAllocatedAmount.dispose();
    customerChargeAmount.dispose();
    directPaidAmount.dispose();
    supplierFeeAmount.dispose();
    note.dispose();
    allocationCashAllocatedAmount.dispose();
    allocationCustomerCharge.dispose();
    allocationDirectPaid.dispose();
    allocationSupplierFee.dispose();
    allocationNote.dispose();
    super.dispose();
  }

  int _parseAmount(
    String text,
    String label, {
    bool required = true,
    bool allowZero = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (!required) return 0;
      throw AppFailure('$label 값을 입력해 주세요.');
    }
    final value = int.tryParse(trimmed);
    if (value == null || value < 0) {
      throw AppFailure('$label 값을 다시 확인해 주세요.');
    }
    if (required && !allowZero && value == 0) {
      throw AppFailure('$label 값은 0보다 커야 해요.');
    }
    return value;
  }

  Future<void> _saveRecordInput(AppServices app) =>
      _saveOwnedInput(app, _inputKey, {
        'wholesaler': wholesaler.text,
        'actualPaidAmount': actualPaidAmount.text,
        'cashAllocatedAmount': cashAllocatedAmount.text,
        'customerChargeAmount': customerChargeAmount.text,
        'directPaidAmount': directPaidAmount.text,
        'supplierFeeAmount': supplierFeeAmount.text,
        'note': note.text,
        'fundingSource': fundingSource,
        'settlementKind': settlementKind,
        'payeeId': _selectedPayeeId,
        'editingPaymentId': _editingPaymentId,
        'operationId': _recordOperationId,
        if (_recordSubmitted != null) 'submitted': _recordSubmitted,
      });

  Future<void> _saveAllocationInput(AppServices app) =>
      _saveOwnedInput(app, _allocationKey, {
        'paymentId': _selectedPaymentId,
        'cashAllocatedAmount': allocationCashAllocatedAmount.text,
        'customerChargeAmount': allocationCustomerCharge.text,
        'directPaidAmount': allocationDirectPaid.text,
        'supplierFeeAmount': allocationSupplierFee.text,
        'note': allocationNote.text,
        'allocationId': _editingAllocationId,
        'operationId': _allocationOperationId,
        if (_allocationSubmitted != null) 'submitted': _allocationSubmitted,
      });

  void _loadPaymentForEdit(FieldPaymentRecord payment) {
    wholesaler.text = payment.wholesaler;
    actualPaidAmount.text = '${payment.actualPaidAmount}';
    final canEditAggregateAmounts = payment.allocationIds.length <= 1;
    cashAllocatedAmount.text =
        canEditAggregateAmounts && !payment.cashAllocatedAmountMissing
        ? '${payment.cashAllocatedAmount}'
        : '';
    customerChargeAmount.text =
        canEditAggregateAmounts && !payment.customerChargeAmountMissing
        ? '${payment.customerChargeAmount}'
        : '';
    directPaidAmount.text =
        canEditAggregateAmounts && !payment.directPaidAmountMissing
        ? '${payment.directPaidAmount}'
        : '';
    supplierFeeAmount.text =
        canEditAggregateAmounts && !payment.supplierFeeAmountMissing
        ? '${payment.supplierFeeAmount}'
        : '';
    note.text = payment.note;
    fundingSource = payment.fundingSource;
    settlementKind = payment.settlementKind;
    _selectedPayeeId = payment.payeeId;
    _editingPaymentId = payment.id;
    _recordSubmitted = null;
    _recordOperationId = newId();
  }

  void _loadAllocationForEdit(SupplierPaymentAllocationRecord allocation) {
    _selectedPaymentId = allocation.paymentId;
    _editingAllocationId = allocation.id;
    allocationCashAllocatedAmount.text = '${allocation.cashAllocatedAmount}';
    allocationCustomerCharge.text = '${allocation.customerChargeAmount}';
    allocationDirectPaid.text = '${allocation.directPaidAmount}';
    allocationSupplierFee.text = '${allocation.supplierFeeAmount}';
    allocationNote.text = allocation.note;
    _allocationSubmitted = null;
    _allocationOperationId = newId();
  }

  void _resetRecordForm() {
    wholesaler.clear();
    actualPaidAmount.clear();
    cashAllocatedAmount.clear();
    customerChargeAmount.clear();
    directPaidAmount.clear();
    supplierFeeAmount.clear();
    note.clear();
    fundingSource = fieldPaymentFundingSources.first;
    settlementKind = fieldPaymentSettlementKinds.first;
    _selectedPayeeId = '';
    _editingPaymentId = '';
    _recordSubmitted = null;
    _recordOperationId = newId();
  }

  void _resetAllocationForm() {
    allocationCashAllocatedAmount.clear();
    allocationCustomerCharge.clear();
    allocationDirectPaid.clear();
    allocationSupplierFee.clear();
    allocationNote.clear();
    _editingAllocationId = '';
    _allocationSubmitted = null;
    _allocationOperationId = newId();
  }

  int _missingAmountCount(FieldPaymentRecord payment) => [
    payment.cashAllocatedAmountMissing,
    payment.customerChargeAmountMissing,
    payment.directPaidAmountMissing,
    payment.supplierFeeAmountMissing,
  ].where((flag) => flag).length;

  List<_LabeledValue> _payeeOptions(
    AppServices app,
    RequestRecord request,
    Data? scope,
  ) {
    final seen = <String>{};
    final result = <_LabeledValue>[];

    void addTarget(String id, String suffix) {
      if (id.isEmpty || !seen.add(id)) return;
      final label = suffix.isEmpty
          ? _displayName(app, id)
          : '${_displayName(app, id)} · $suffix';
      result.add(_LabeledValue(id: id, label: label));
    }

    final requestUncleId = textOf(request.data, 'uncleId');
    addTarget(requestUncleId, '요청 담당');
    final teamId = textOf(scope ?? const {}, 'teamId');
    if (teamId.isEmpty) return result;
    final team = app.workspace
        .records('teams')
        .where((row) => row.id == teamId)
        .firstOrNull;
    for (final memberId in stringsOf(team?.data ?? const {}, 'memberIds')) {
      addTarget(memberId, '팀 멤버');
    }
    return result;
  }

  Data? _requestScope(
    AppServices app,
    RequestRecord request,
    String wholesalerName,
  ) {
    final jobs = app.workspace
        .records('teamJobs')
        .where((row) => row.s('requestId') == request.id);
    Record? matched;
    final normalized = wholesalerName.trim();
    for (final job in jobs) {
      if (normalized.isEmpty || job.s('wholesalerName') == normalized) {
        matched = job;
        break;
      }
    }
    if (matched == null) return null;
    return {
      'teamId': matched.s('teamId'),
      'roundId': matched.s('roundId'),
      'wholesaler': matched.s('wholesalerName').isEmpty
          ? normalized
          : matched.s('wholesalerName'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    final request = app.workspace.request(widget.requestId);
    if (request == null || !_sameInputAccount(app)) {
      return PageFrame(
        title: '현장 지급',
        children: const [EmptyState.titleOnly('요청을 찾을 수 없어요')],
      );
    }
    final requestPayments =
        app.workspace.fieldPayments
            .where((row) => row.requestId == widget.requestId)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final editingPayment = _editingPaymentId.isEmpty
        ? null
        : requestPayments
              .where((row) => row.id == _editingPaymentId)
              .firstOrNull;
    final inferredWholesaler = wholesaler.text.trim().isNotEmpty
        ? wholesaler.text.trim()
        : editingPayment?.wholesaler ?? textOf(request.data, 'wholesaler');
    final scope = _requestScope(app, request, inferredWholesaler);
    final payeeOptions = _payeeOptions(app, request, scope);
    final defaultPayeeId = textOf(request.data, 'uncleId', current?.id ?? '');
    if (editingPayment != null) {
      _selectedPayeeId = editingPayment.payeeId;
    } else if (payeeOptions.every((row) => row.id != _selectedPayeeId)) {
      _selectedPayeeId = payeeOptions
          .firstWhere(
            (row) => row.id == defaultPayeeId,
            orElse: () =>
                payeeOptions.firstOrNull ??
                _LabeledValue(id: defaultPayeeId, label: ''),
          )
          .id;
    }
    final scopedPayments =
        app.workspace.fieldPayments
            .where((row) {
              if (scope != null &&
                  textOf(scope, 'teamId').isNotEmpty &&
                  textOf(scope, 'roundId').isNotEmpty &&
                  textOf(scope, 'wholesaler').isNotEmpty) {
                return row.teamId == textOf(scope, 'teamId') &&
                    row.roundId == textOf(scope, 'roundId') &&
                    row.wholesaler == textOf(scope, 'wholesaler');
              }
              return row.requestId == widget.requestId;
            })
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('createdAt').compareTo(left.s('createdAt')),
          );
    final scopedPaymentById = {
      for (final payment in scopedPayments) payment.id: payment,
    };
    final allocationCandidates = scopedPayments
        .where((row) => row.unallocatedAmount > 0)
        .toList(growable: false);
    final requestAllocations =
        app.workspace.supplierPaymentAllocations
            .where(
              (row) =>
                  row.requestId == widget.requestId &&
                  scopedPaymentById.containsKey(row.paymentId),
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.s('updatedAt').compareTo(left.s('updatedAt')),
          );
    final editingAllocation = _editingAllocationId.isEmpty
        ? null
        : requestAllocations
              .where((row) => row.id == _editingAllocationId)
              .firstOrNull;
    final editingAllocationPayment = editingAllocation == null
        ? null
        : scopedPaymentById[editingAllocation.paymentId];
    if (editingAllocation != null) {
      _selectedPaymentId = editingAllocation.paymentId;
    } else if (allocationCandidates.every(
      (row) => row.id != _selectedPaymentId,
    )) {
      _selectedPaymentId = allocationCandidates.firstOrNull?.id ?? '';
    }
    final canEditAggregateAmounts =
        editingPayment == null || editingPayment.allocationIds.length <= 1;
    final hasPendingSubmission =
        _recordSubmitted != null || _allocationSubmitted != null;

    final actual = int.tryParse(actualPaidAmount.text.trim());
    final cash = int.tryParse(cashAllocatedAmount.text.trim());
    final charge = int.tryParse(customerChargeAmount.text.trim());
    final direct = int.tryParse(directPaidAmount.text.trim());
    final fee = int.tryParse(supplierFeeAmount.text.trim());
    final billable = charge == null || direct == null
        ? null
        : (charge - direct).clamp(0, 0x7fffffff);
    final hasAnyOptionalRecordAmount = [
      cash,
      charge,
      direct,
      fee,
    ].any((value) => value != null);

    return PageFrame(
      title: '현장 지급',
      navigationSubtitle: requestTitle(request.data),
      children: [
        if (_inputSaveFailed)
          const Inset(child: Info('입력을 저장하지 못했어요. 다시 시도해 주세요.')),
        Section('지급 기록'),
        FigmaSurface(
          children: [
            if (_recordSubmitted != null)
              const Inset(
                child: Info('이 지급 기록은 전송 확인 중이에요. 다시 누르면 같은 작업번호로 재시도해요.'),
              ),
            Inset(
              child: _billingInputs(
                ignoring: hasPendingSubmission,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _billingInputs(
                      ignoring: editingPayment != null,
                      child: Field(
                        '도매처',
                        controller: wholesaler,
                        onChanged: (_) =>
                            _saveInBackground(_saveRecordInput(app)),
                      ),
                    ),
                    if (payeeOptions.length > 1 && editingPayment == null)
                      Choices(
                        options: [
                          for (final value in payeeOptions) value.label,
                        ],
                        value: payeeOptions
                            .firstWhere(
                              (row) => row.id == _selectedPayeeId,
                              orElse: () => payeeOptions.first,
                            )
                            .label,
                        onChanged: (label) {
                          final target = payeeOptions.firstWhere(
                            (row) => row.label == label,
                          );
                          setState(() => _selectedPayeeId = target.id);
                          _saveInBackground(_saveRecordInput(app));
                        },
                      ),
                    Choices(
                      options: [
                        for (final value in fieldPaymentFundingSources)
                          _fieldPaymentFundingLabel(value),
                      ],
                      value: _fieldPaymentFundingLabel(fundingSource),
                      onChanged: (label) {
                        setState(
                          () =>
                              fundingSource = _fieldPaymentFundingValue(label),
                        );
                        _saveInBackground(_saveRecordInput(app));
                      },
                    ),
                    Choices(
                      options: [
                        for (final value in fieldPaymentSettlementKinds)
                          _fieldPaymentSettlementLabel(value),
                      ],
                      value: _fieldPaymentSettlementLabel(settlementKind),
                      onChanged: (label) {
                        setState(
                          () => settlementKind = _fieldPaymentSettlementValue(
                            label,
                          ),
                        );
                        _saveInBackground(_saveRecordInput(app));
                      },
                    ),
                    Field(
                      '실제 지급액',
                      controller: actualPaidAmount,
                      numeric: true,
                      onChanged: (_) =>
                          _saveInBackground(_saveRecordInput(app)),
                    ),
                    if (!canEditAggregateAmounts)
                      const Info(
                        '여러 고객으로 배분된 지급이라 총액·메모만 수정할 수 있어요. 배분 금액은 아래 개별 배분에서 수정해 주세요.',
                      ),
                    if (canEditAggregateAmounts)
                      Field(
                        '배분할 실제 현금',
                        controller: cashAllocatedAmount,
                        numeric: true,
                        placeholder: '미입력으로 남기려면 비워 두세요',
                        onChanged: (_) =>
                            _saveInBackground(_saveRecordInput(app)),
                      ),
                    if (canEditAggregateAmounts)
                      Field(
                        '고객 부담액',
                        controller: customerChargeAmount,
                        numeric: true,
                        placeholder: '미입력으로 남기려면 비워 두세요',
                        onChanged: (_) =>
                            _saveInBackground(_saveRecordInput(app)),
                      ),
                    if (canEditAggregateAmounts)
                      Field(
                        '고객 직접 결제액',
                        controller: directPaidAmount,
                        numeric: true,
                        placeholder: '미입력으로 남기려면 비워 두세요',
                        onChanged: (_) =>
                            _saveInBackground(_saveRecordInput(app)),
                      ),
                    if (canEditAggregateAmounts)
                      Field(
                        '도매처 수수료·차액',
                        controller: supplierFeeAmount,
                        numeric: true,
                        placeholder: '미입력으로 남기려면 비워 두세요',
                        onChanged: (_) =>
                            _saveInBackground(_saveRecordInput(app)),
                      ),
                    Field(
                      '메모',
                      controller: note,
                      multiline: true,
                      onChanged: (_) =>
                          _saveInBackground(_saveRecordInput(app)),
                    ),
                  ],
                ),
              ),
            ),
            if (actual != null || hasAnyOptionalRecordAmount)
              Inset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (actual != null)
                      QuantityRow('실제 지급액', billingMoney(actual)),
                    QuantityRow(
                      '배분할 실제 현금',
                      cash == null ? '미입력' : billingMoney(cash),
                    ),
                    QuantityRow(
                      '고객 부담액',
                      charge == null ? '미입력' : billingMoney(charge),
                    ),
                    QuantityRow(
                      '고객 직접 결제',
                      direct == null ? '미입력' : billingMoney(direct),
                    ),
                    QuantityRow(
                      '청구 반영 원금',
                      billable == null ? '미입력' : billingMoney(billable),
                    ),
                    QuantityRow(
                      '수수료·차액',
                      fee == null ? '미입력' : billingMoney(fee),
                    ),
                  ],
                ),
              ),
            ActionButton(
              _editingPaymentId.isEmpty ? '현장 지급 기록' : '현장 지급 수정 저장',
              icon: _editingPaymentId.isEmpty ? 'plus' : 'pencil',
              enabled: _allocationSubmitted == null,
              onPressed: () async {
                _requireInputAccount(app);
                FocusManager.instance.primaryFocus?.unfocus();
                final currentPayment = editingPayment;
                _recordSubmitted ??= () {
                  final actualAmount = _parseAmount(
                    actualPaidAmount.text,
                    '실제 지급액',
                    allowZero: true,
                  );
                  final cashAmount = canEditAggregateAmounts
                      ? _parseOptionalAmount(
                          cashAllocatedAmount.text,
                          '배분할 실제 현금',
                        )
                      : null;
                  final chargeAmount = canEditAggregateAmounts
                      ? _parseOptionalAmount(
                          customerChargeAmount.text,
                          '고객 부담액',
                        )
                      : null;
                  final directAmount = canEditAggregateAmounts
                      ? _parseOptionalAmount(directPaidAmount.text, '고객 직접 결제액')
                      : null;
                  final feeAmount = canEditAggregateAmounts
                      ? _parseOptionalAmount(
                          supplierFeeAmount.text,
                          '도매처 수수료·차액',
                        )
                      : null;
                  final hasAnyOptionalAmount = [
                    cashAmount,
                    chargeAmount,
                    directAmount,
                    feeAmount,
                  ].any((value) => value != null);
                  if (hasAnyOptionalAmount &&
                      [
                        cashAmount,
                        chargeAmount,
                        directAmount,
                        feeAmount,
                      ].any((value) => value == null)) {
                    throw const AppFailure(
                      '배분할 실제 현금, 고객 부담액, 직접 결제액, 수수료·차액은 모두 입력하거나 모두 비워 두세요.',
                    );
                  }
                  if (cashAmount != null && cashAmount > actualAmount) {
                    throw const AppFailure('배분할 실제 현금이 총 지급액보다 클 수 없어요.');
                  }
                  if (chargeAmount != null &&
                      directAmount != null &&
                      directAmount > chargeAmount) {
                    throw const AppFailure('고객 직접 결제액이 고객 부담액보다 클 수 없어요.');
                  }
                  return {
                    'requestId': currentPayment?.requestId ?? request.id,
                    'payerId': currentPayment?.payerId ?? current!.id,
                    'payeeId': currentPayment?.payeeId ?? _selectedPayeeId,
                    if (currentPayment != null) 'id': currentPayment.id,
                    if (currentPayment != null)
                      'version': currentPayment.version,
                    'wholesaler':
                        currentPayment?.wholesaler ?? wholesaler.text.trim(),
                    'fundingSource': fundingSource,
                    'settlementKind': settlementKind,
                    'actualPaidAmount': actualAmount,
                    if (currentPayment == null &&
                        scope != null &&
                        textOf(scope, 'teamId').isNotEmpty)
                      'teamId': textOf(scope, 'teamId'),
                    if (currentPayment == null &&
                        scope != null &&
                        textOf(scope, 'roundId').isNotEmpty)
                      'roundId': textOf(scope, 'roundId'),
                    ..._entryIfPresent('cashAllocatedAmount', cashAmount),
                    ..._entryIfPresent('customerChargeAmount', chargeAmount),
                    ..._entryIfPresent('directPaidAmount', directAmount),
                    ..._entryIfPresent('supplierFeeAmount', feeAmount),
                    'note': note.text.trim(),
                  };
                }();
                setState(() {});
                await _saveRecordInput(app);
                _requireInputAccount(app);
                try {
                  final id = await app.workspace.recordFieldPayment(
                    _recordSubmitted!,
                    operationId: _recordOperationId,
                  );
                  await _saveOwnedInput(app, _inputKey, {});
                  _requireInputAccount(app);
                  if (!mounted) return;
                  setState(() {
                    lastRecordedId = id;
                    _resetRecordForm();
                  });
                } catch (_) {
                  if (!_sameInputAccount(app)) rethrow;
                  final rejected = _hasRejectedWorkflow(
                    app.workspace,
                    _recordOperationId,
                  );
                  if (rejected) {
                    await app.workspace.discardRejectedWorkflow(
                      _recordOperationId,
                    );
                  }
                  if (rejected ||
                      !_hasLiveWorkflow(app.workspace, _recordOperationId)) {
                    _recordSubmitted = null;
                    _recordOperationId = newId();
                    await _saveRecordInput(app);
                  }
                  rethrow;
                }
              },
            ),
            if (_editingPaymentId.isNotEmpty)
              ActionButton(
                '수정 취소',
                icon: 'close',
                weak: true,
                enabled: !hasPendingSubmission,
                onPressed: () async {
                  setState(_resetRecordForm);
                  await _saveRecordInput(app);
                },
              ),
          ],
        ),
        if (requestAllocations.isNotEmpty) ...[
          Section('기존 배분'),
          for (final allocation in requestAllocations)
            if (scopedPaymentById[allocation.paymentId] case final payment?)
              FigmaSurface(
                children: [
                  Item(
                    payment.wholesaler.isEmpty ? '배분 기록' : payment.wholesaler,
                    subtitle: allocation.note.isEmpty
                        ? _paymentChoiceLabel(app, payment)
                        : allocation.note,
                    leading: const FigmaIcon('money'),
                    trailing: StatusBadge(
                      allocation.invoiceId.isEmpty ? '미청구' : '청구 포함',
                      attention: allocation.invoiceId.isEmpty,
                    ),
                    onTap: hasPendingSubmission
                        ? null
                        : () => setState(
                            () => _loadAllocationForEdit(allocation),
                          ),
                  ),
                  Inset(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuantityRow(
                          '배분한 실제 현금',
                          billingMoney(allocation.cashAllocatedAmount),
                        ),
                        QuantityRow(
                          '고객 부담',
                          billingMoney(allocation.customerChargeAmount),
                        ),
                        QuantityRow(
                          '직접 결제',
                          billingMoney(allocation.directPaidAmount),
                        ),
                        QuantityRow(
                          '청구 반영',
                          billingMoney(allocation.billableAmount),
                        ),
                        QuantityRow(
                          '수수료·차액',
                          billingMoney(allocation.supplierFeeAmount),
                        ),
                      ],
                    ),
                  ),
                  ActionButton(
                    '이 배분 수정',
                    icon: 'pencil',
                    weak: true,
                    enabled: !hasPendingSubmission,
                    onPressed: () async {
                      setState(() => _loadAllocationForEdit(allocation));
                      await _saveAllocationInput(app);
                    },
                  ),
                ],
              ),
        ],
        if (allocationCandidates.isNotEmpty ||
            editingAllocation != null ||
            _allocationSubmitted != null) ...[
          Section('미배분 지급 배분'),
          FigmaSurface(
            children: [
              if (_allocationSubmitted != null)
                const Inset(
                  child: Info('이 배분 기록은 전송 확인 중이에요. 다시 누르면 같은 작업번호로 재시도해요.'),
                ),
              Inset(
                child: _billingInputs(
                  ignoring: hasPendingSubmission,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (editingAllocationPayment != null)
                        Item(
                          '수정 대상 지급',
                          subtitle:
                              '${app.workspace.profile(editingAllocationPayment.retailerId)?.displayName ?? '소매업자'} · ${_paymentChoiceLabel(app, editingAllocationPayment)}',
                          leading: const FigmaIcon('money'),
                        ),
                      if (editingAllocation == null &&
                          allocationCandidates.length > 1)
                        Choices(
                          options: [
                            for (final row in allocationCandidates)
                              '${app.workspace.profile(row.s('retailerId'))?.displayName ?? '소매업자'} · ${_paymentChoiceLabel(app, row)}',
                          ],
                          value:
                              '${app.workspace.profile(allocationCandidates.firstWhere((row) => row.id == _selectedPaymentId, orElse: () => allocationCandidates.first).s('retailerId'))?.displayName ?? '소매업자'} · ${_paymentChoiceLabel(app, allocationCandidates.firstWhere((row) => row.id == _selectedPaymentId, orElse: () => allocationCandidates.first))}',
                          onChanged: (label) {
                            final target = allocationCandidates.firstWhere(
                              (row) =>
                                  '${app.workspace.profile(row.s('retailerId'))?.displayName ?? '소매업자'} · ${_paymentChoiceLabel(app, row)}' ==
                                  label,
                            );
                            setState(() => _selectedPaymentId = target.id);
                            _saveInBackground(_saveAllocationInput(app));
                          },
                        ),
                      Field(
                        '배분할 실제 현금',
                        controller: allocationCashAllocatedAmount,
                        numeric: true,
                        onChanged: (_) =>
                            _saveInBackground(_saveAllocationInput(app)),
                      ),
                      Field(
                        '배분할 고객 부담액',
                        controller: allocationCustomerCharge,
                        numeric: true,
                        onChanged: (_) =>
                            _saveInBackground(_saveAllocationInput(app)),
                      ),
                      Field(
                        '배분할 직접 결제액',
                        controller: allocationDirectPaid,
                        numeric: true,
                        onChanged: (_) =>
                            _saveInBackground(_saveAllocationInput(app)),
                      ),
                      Field(
                        '배분할 수수료·차액',
                        controller: allocationSupplierFee,
                        numeric: true,
                        onChanged: (_) =>
                            _saveInBackground(_saveAllocationInput(app)),
                      ),
                      Field(
                        '배분 메모',
                        controller: allocationNote,
                        multiline: true,
                        onChanged: (_) =>
                            _saveInBackground(_saveAllocationInput(app)),
                      ),
                    ],
                  ),
                ),
              ),
              ActionButton(
                editingAllocation == null ? '배분 기록' : '배분 수정 저장',
                icon: editingAllocation == null ? 'plus' : 'pencil',
                enabled: _recordSubmitted == null,
                onPressed: () async {
                  _requireInputAccount(app);
                  FocusManager.instance.primaryFocus?.unfocus();
                  _allocationSubmitted ??= () {
                    final payment =
                        editingAllocationPayment ??
                        allocationCandidates.firstWhere(
                          (row) => row.id == _selectedPaymentId,
                          orElse: () => allocationCandidates.first,
                        );
                    final cashAmount = _parseAmount(
                      allocationCashAllocatedAmount.text,
                      '배분할 실제 현금',
                      allowZero: true,
                    );
                    final chargeAmount = _parseAmount(
                      allocationCustomerCharge.text,
                      '배분할 고객 부담액',
                      allowZero: true,
                    );
                    final directAmount = _parseAmount(
                      allocationDirectPaid.text,
                      '배분할 직접 결제액',
                      allowZero: true,
                    );
                    final feeAmount = _parseAmount(
                      allocationSupplierFee.text,
                      '배분할 수수료·차액',
                      allowZero: true,
                    );
                    final remainingAllowance =
                        payment.unallocatedAmount +
                        (editingAllocation?.allocatedAmount ?? 0);
                    if (cashAmount > remainingAllowance) {
                      throw const AppFailure('배분할 실제 현금이 아직 남은 금액보다 클 수 없어요.');
                    }
                    if (directAmount > chargeAmount) {
                      throw const AppFailure('배분할 직접 결제액이 고객 부담액보다 클 수 없어요.');
                    }
                    return {
                      'paymentId': payment.id,
                      'requestId': editingAllocation?.requestId ?? request.id,
                      'version': payment.version,
                      if (editingAllocation != null)
                        'allocationId': editingAllocation.id,
                      if (editingAllocation != null)
                        'allocationVersion': editingAllocation.version,
                      'cashAllocatedAmount': cashAmount,
                      'customerChargeAmount': chargeAmount,
                      'directPaidAmount': directAmount,
                      'supplierFeeAmount': feeAmount,
                      'note': allocationNote.text.trim(),
                    };
                  }();
                  setState(() {});
                  await _saveAllocationInput(app);
                  _requireInputAccount(app);
                  try {
                    await app.workspace.allocateSupplierPayment(
                      _allocationSubmitted!,
                      operationId: _allocationOperationId,
                    );
                    await _saveOwnedInput(app, _allocationKey, {});
                    _requireInputAccount(app);
                    if (!mounted) return;
                    setState(() {
                      _resetAllocationForm();
                    });
                  } catch (_) {
                    if (!_sameInputAccount(app)) rethrow;
                    final rejected = _hasRejectedWorkflow(
                      app.workspace,
                      _allocationOperationId,
                    );
                    if (rejected) {
                      await app.workspace.discardRejectedWorkflow(
                        _allocationOperationId,
                      );
                    }
                    if (rejected ||
                        !_hasLiveWorkflow(
                          app.workspace,
                          _allocationOperationId,
                        )) {
                      _allocationSubmitted = null;
                      _allocationOperationId = newId();
                      await _saveAllocationInput(app);
                    }
                    rethrow;
                  }
                },
              ),
              if (_editingAllocationId.isNotEmpty)
                ActionButton(
                  '수정 취소',
                  icon: 'close',
                  weak: true,
                  enabled: !hasPendingSubmission,
                  onPressed: () async {
                    setState(_resetAllocationForm);
                    await _saveAllocationInput(app);
                  },
                ),
            ],
          ),
        ],
        if (requestPayments.isNotEmpty) ...[
          Section('이미 기록한 지급'),
          for (final payment in requestPayments)
            FigmaSurface(
              children: [
                Item(
                  payment.wholesaler.isEmpty ? '현장 지급' : payment.wholesaler,
                  subtitle: payment.note.isEmpty
                      ? requestTitle(request.data)
                      : payment.note,
                  leading: const FigmaIcon('money'),
                  trailing: StatusBadge(
                    payment.settlementKind == 'review'
                        ? '현장 확인 필요'
                        : payment.hasMissingAmounts
                        ? '미입력 ${_missingAmountCount(payment)}건'
                        : payment.unallocatedAmount > 0
                        ? '미배분 ${billingMoney(payment.unallocatedAmount)}'
                        : '배분 완료',
                    attention:
                        payment.settlementKind == 'review' ||
                        payment.hasMissingAmounts ||
                        payment.unallocatedAmount > 0,
                  ),
                  onTap: hasPendingSubmission
                      ? null
                      : () => setState(() => _loadPaymentForEdit(payment)),
                ),
                Inset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuantityRow(
                        '총 지급액',
                        billingMoney(payment.actualPaidAmount),
                      ),
                      QuantityRow(
                        '배분한 실제 현금',
                        _amountTextOrMissing(
                          payment.cashAllocatedAmount,
                          missing: payment.cashAllocatedAmountMissing,
                        ),
                      ),
                      QuantityRow(
                        '고객 부담',
                        _amountTextOrMissing(
                          payment.customerChargeAmount,
                          missing: payment.customerChargeAmountMissing,
                        ),
                      ),
                      QuantityRow(
                        '직접 결제',
                        _amountTextOrMissing(
                          payment.directPaidAmount,
                          missing: payment.directPaidAmountMissing,
                        ),
                      ),
                      QuantityRow(
                        '청구 반영',
                        payment.customerChargeAmountMissing ||
                                payment.directPaidAmountMissing
                            ? '미입력'
                            : billingMoney(payment.billableAmount),
                      ),
                      QuantityRow(
                        '수수료·차액',
                        _amountTextOrMissing(
                          payment.supplierFeeAmount,
                          missing: payment.supplierFeeAmountMissing,
                        ),
                      ),
                    ],
                  ),
                ),
                ActionButton(
                  '이 지급 수정',
                  icon: 'pencil',
                  weak: true,
                  enabled: !hasPendingSubmission,
                  onPressed: () async {
                    setState(() => _loadPaymentForEdit(payment));
                    await _saveRecordInput(app);
                  },
                ),
              ],
            ),
        ],
        if (lastRecordedId != null)
          Inset(
            child: Info('현장 지급을 기록했어요. 필요하면 같은 요청 안에서 미배분 금액을 이어서 배분해 주세요.'),
          ),
      ],
    );
  }
}

class _LabeledValue {
  const _LabeledValue({required this.id, required this.label});

  final String id;
  final String label;
}

List<Data> _dataRows(Data data, String key) => [
  for (final value in (data[key] as List? ?? const []))
    if (value is Map) Map<String, Object?>.from(value),
];

String _invoiceSubtitle(AppServices app, InvoiceRecord invoice) {
  final retailer =
      app.workspace.profile(invoice.retailerId)?.displayName ?? '소매업자';
  final payee = app.workspace.profile(invoice.payeeId)?.displayName ?? '수취 담당';
  return [
    retailer,
    payee,
    if (invoice.label.isNotEmpty) invoice.label,
  ].join(' · ');
}

String _displayName(AppServices app, String userId) => userId == platformPayeeId
    ? '운영 계좌'
    : app.workspace.profile(userId)?.displayName ?? userId;

List<_LabeledValue> _supplierRefundTargets(
  AppServices app,
  List<FieldPaymentRecord> payments,
) {
  final seen = <String>{};
  final result = <_LabeledValue>[];
  for (final payment in payments) {
    for (final userId in [payment.payeeId, payment.payerId]) {
      if (userId.isEmpty || !seen.add(userId)) continue;
      result.add(_LabeledValue(id: userId, label: _displayName(app, userId)));
    }
  }
  return result;
}

String _reimbursementChoiceLabel(AppServices app, ReimbursementRecord row) {
  final from = _displayName(app, row.fromId);
  final to = _displayName(app, row.toId);
  return '${reimbursementKindLabel(row.kind)} · $from → $to · ${billingMoney(row.remainingAmount)}';
}

String _paymentChoiceLabel(AppServices app, FieldPaymentRecord payment) {
  final request = app.workspace.request(payment.requestId);
  final title = request == null ? '현장 지급' : requestTitle(request.data);
  return '$title · ${billingMoney(payment.unallocatedAmount)} 남음';
}

String _invoiceStatusChoiceLabel(String value) => switch (value) {
  'all' => '전체',
  _ => invoiceStatusLabel(value),
};

String _invoiceStatusChoiceValue(String label) => switch (label) {
  '전체' => 'all',
  '청구 전' => 'draft',
  '청구 완료' => 'sent',
  '일부 회수' => 'partial',
  '전액 회수' => 'collected',
  _ => 'all',
};

String _fieldPaymentFundingLabel(String value) => switch (value) {
  'personal' => '개인 돈으로 먼저 지급',
  'team_fund' => '팀 공금으로 지급',
  'unknown' => '출처를 아직 정리 못함',
  _ => '출처 확인 필요',
};

String _fieldPaymentFundingValue(String label) => switch (label) {
  '개인 돈으로 먼저 지급' => 'personal',
  '팀 공금으로 지급' => 'team_fund',
  '출처를 아직 정리 못함' => 'unknown',
  _ => 'unknown',
};

String _fieldPaymentSettlementLabel(String value) => switch (value) {
  'advance' => '삼촌이 대납했어요',
  'direct' => '고객이 도매처에 직접 결제했어요',
  'review' => '현장에서 결제 방식 확인이 더 필요해요',
  _ => '확인 필요',
};

String _fieldPaymentSettlementValue(String label) => switch (label) {
  '삼촌이 대납했어요' => 'advance',
  '고객이 도매처에 직접 결제했어요' => 'direct',
  '현장에서 결제 방식 확인이 더 필요해요' => 'review',
  _ => 'review',
};

String _adjustmentKindOf(String label) => switch (label) {
  '추가 청구' => 'charge',
  '감액' => 'discount',
  '취소·환급' => 'cancel',
  _ => 'charge',
};

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
