import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import '../domain/pickup_progress.dart';
import 'common.dart';
import 'requests.dart';

class RetailerPickupSummary extends StatelessWidget {
  const RetailerPickupSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = AppScope.of(context).workspace.records('pickupProgress');
    if (rows.isEmpty) return const SizedBox.shrink();
    return FigmaSurface(
      children: [
        const Section('포장 픽업 현황'),
        for (final status in [
          'picked',
          'delivered',
          'received',
          'pending',
          'partial',
        ])
          Item(
            pickupProgressLabel(status),
            trailing: TdsText(
              '${rows.where((r) => r.s('status') == status).length}건',
              typography: TdsTypography.t5,
              fontWeight: TdsFontWeight.bold,
            ),
            onTap: () =>
                openPage(context, RetailerPickupListPage(status: status)),
          ),
        if (rows.any((r) => r.n('openIssues') > 0))
          const Info('수령 차이·미해결 문제가 있어요.', error: true),
      ],
    );
  }
}

class RetailerPickupListPage extends StatelessWidget {
  const RetailerPickupListPage({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final rows = AppScope.of(context).workspace
        .records('pickupProgress')
        .where((r) => r.s('status') == status)
        .toList();
    return PageFrame(
      title: pickupProgressLabel(status),
      children: [
        if (rows.isEmpty) const EmptyState.titleOnly('해당하는 픽업 요청이 없어요'),
        for (final row in rows)
          Item(
            row.s('wholesalerName'),
            subtitle:
                '${dataRowsOf(row.data, 'packages').length}개 포장 기록${row.b('hasBackorder') ? ' · 미송 남음' : ''}',
            trailing: row.n('openIssues') > 0
                ? const StatusBadge('문제 확인')
                : null,
            onTap: () =>
                openPage(context, RetailerPickupDetailPage(progressId: row.id)),
          ),
      ],
    );
  }
}

class RetailerPickupDetailPage extends StatefulWidget {
  const RetailerPickupDetailPage({required this.progressId, super.key});
  final String progressId;
  @override
  State<RetailerPickupDetailPage> createState() =>
      _RetailerPickupDetailPageState();
}

class _RetailerPickupDetailPageState extends State<RetailerPickupDetailPage> {
  final _selected = <String>{};
  final _note = TextEditingController();
  WorkspaceRepository? _workspace;
  String _operationId = newId();
  Data? _submitted;
  String get _key => 'pickup-receipt:${widget.progressId}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workspace != null) return;
    _workspace = AppScope.of(context).workspace;
    final saved = _workspace!.workflowInput(_key);
    _selected.addAll(stringsOf(saved, 'packageIds'));
    _note.text = textOf(saved, 'note');
    _operationId = textOf(saved, 'operationId', _operationId);
    final submitted = mapOf(saved, 'submitted');
    if (submitted.isNotEmpty) _submitted = submitted;
  }

  Future<void> _save() => _workspace!.saveWorkflowInput(_key, {
    'packageIds': _selected.toList(),
    'note': _note.text,
    'operationId': _operationId,
    if (_submitted != null) 'submitted': _submitted,
  });

  Future<void> _confirm(List<Data> packages) async {
    final workspace = _workspace!;
    _submitted ??= {
      'packageIds': _selected.toList()..sort(),
      'versions': {
        for (final p in packages)
          if (_selected.contains(textOf(p, 'id')))
            textOf(p, 'id'): numberOf(p, 'version'),
      },
      'note': _note.text.trim(),
    };
    await _save();
    try {
      await workspace.workflow(
        'wf.recordPackageReceipt',
        _submitted!,
        _operationId,
      );
    } catch (_) {
      final pending = workspace
          .records('workflowPending')
          .where((r) => r.s('operationId') == _operationId)
          .firstOrNull;
      if (pending == null || pending.s('status') == 'rejected') {
        if (pending != null) {
          await workspace.discardRejectedWorkflow(_operationId);
        }
        _submitted = null;
        _operationId = newId();
        await _save();
      }
      rethrow;
    }
    await workspace.saveWorkflowInput(_key, {});
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _note.clear();
      _submitted = null;
      _operationId = newId();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = AppScope.of(context).workspace
        .records('pickupProgress')
        .where((r) => r.id == widget.progressId)
        .firstOrNull;
    if (row == null) {
      return const PageFrame(
        title: '포장 수령',
        children: [Info('픽업 기록을 찾을 수 없어요.')],
      );
    }
    final packages = dataRowsOf(row.data, 'packages');
    final delivered = packages
        .where((p) => textOf(p, 'status') == 'delivered')
        .toList();
    return PageFrame(
      title: row.s('wholesalerName'),
      children: [
        Item(
          pickupProgressLabel(row.s('status')),
          subtitle: row.b('scopeConfirmed')
              ? '확정된 포장 ${row.n('expectedPackageCount')}개${row.b('hasBackorder') ? ' · 미송 남음' : ''}'
              : '전체 포장 수 확인 필요',
        ),
        const Info('실제로 받은 포장만 선택해 주세요. 포장 수령은 내용물 검수와 별도로 기록해요.'),
        if (row.n('openIssues') > 0)
          const Info('해결되지 않은 수령 문제가 있어요.', error: true),
        for (final p in packages)
          Item(
            textOf(p, 'packageLabel'),
            subtitle: '${numberOf(p, 'quantity')} ${textOf(p, 'unit')}',
            trailing: textOf(p, 'status') == 'delivered'
                ? TdsCheckbox(
                    checked: _selected.contains(textOf(p, 'id')),
                    disabled: _submitted != null,
                    semanticLabel: '${textOf(p, 'packageLabel')} 수령 선택',
                    onChanged: (checked) async {
                      setState(() {
                        if (checked == true) {
                          _selected.add(textOf(p, 'id'));
                        } else {
                          _selected.remove(textOf(p, 'id'));
                        }
                      });
                      await _save();
                    },
                  )
                : StatusBadge(
                    textOf(p, 'status') == 'received' ? '수령 확인' : '전달 전',
                  ),
          ),
        if (delivered.isNotEmpty || _submitted != null) ...[
          if (_submitted == null)
            Field('수령 메모', controller: _note, onChanged: (_) => _save()),
          ActionButton(
            _submitted == null ? '선택한 포장 수령 확인' : '수령 확인 다시 확인',
            enabled: _selected.isNotEmpty || _submitted != null,
            onPressed: () => _confirm(packages),
          ),
        ],
        ActionButton(
          '원래 픽업 요청 보기',
          weak: true,
          onPressed: () =>
              openPage(context, RequestDetailPage(row.s('requestId'))),
        ),
      ],
    );
  }
}
