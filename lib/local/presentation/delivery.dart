import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'requests.dart';
import 'social.dart';

class DeliveryList extends StatefulWidget {
  const DeliveryList({this.peerId, this.onWork, super.key});
  final String? peerId;
  final VoidCallback? onWork;
  @override
  State<DeliveryList> createState() => _DeliveryListState();
}

class _DeliveryListState extends State<DeliveryList> {
  String filter = '전달할 물품';
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        requests = app.workspace
            .records('requests')
            .map((r) => RequestRecord(r.id, r.data))
            .where(
              (r) =>
                  widget.peerId == null || r.s('retailerId') == widget.peerId,
            )
            .toList();
    final rows = app.workspace
        .records('deliveries')
        .where((d) => requests.any((r) => r.id == d.s('requestId')))
        .where(
          (d) =>
              filter != '수령 대기' ||
              d.n('received') < d.n('quantity') ||
              !d.b('receiptRecorded'),
        )
        .toList();
    final groups = <String, List<RequestRecord>>{};
    for (final r in requests.where((r) => r.available > 0 && !r.ended)) {
      groups
          .putIfAbsent(
            '${r.s('retailerId')}|${r.s('address')}|${r.s('addressDetail')}',
            () => [],
          )
          .add(r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Choices(
          options: const ['전달할 물품', '수령 대기', '전달 이력'],
          value: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        if (filter == '전달할 물품') ...[
          if (groups.isEmpty)
            EmptyState(
              '지금 전달할 물품이 없어요',
              '업무에서 실제 확보한 수량을 기록해 주세요.',
              action: widget.onWork == null ? null : '오늘 업무로',
              onAction: widget.onWork,
            ),
          for (final group in groups.values)
            Item(
              app.workspace.profile(group.first.s('retailerId'))?.name ?? '거래처',
              subtitle:
                  '${group.first.s('address')} ${group.first.s('addressDetail')}\n${group.length}개 요청 · 전달 가능 ${group.fold<int>(0, (sum, r) => sum + r.available)}개',
              onTap: () => openPage(
                context,
                DeliveryBatchPage(group.map((r) => r.id).toList()),
              ),
            ),
          for (final r in requests.where((r) => r.n('held') > 0))
            Item(
              '${r.s('product')} · 보류 ${r.n('held')}개',
              subtitle: '변경·취소·문제 처리 후 전달할 수 있어요.',
              onTap: () => openPage(context, RequestDetailPage(r.id)),
            ),
        ] else ...[
          if (rows.isEmpty)
            const EmptyState('전달 내역이 없어요', '실제 전달을 기록하면 회차별로 확인할 수 있어요.'),
          for (final d in rows) ...[
            DeliveryCard(d),
            ActionButton(
              '관련 채팅',
              weak: true,
              onPressed: () => openPage(
                context,
                ChatPage(d.s('retailerId'), requestId: d.s('requestId')),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class DeliveryBatchPage extends StatefulWidget {
  const DeliveryBatchPage(this.requestIds, {super.key});
  final List<String> requestIds;
  @override
  State<DeliveryBatchPage> createState() => _DeliveryBatchPageState();
}

class _DeliveryBatchPageState extends State<DeliveryBatchPage> {
  final initialRequests = <String, RequestRecord>{};
  final quantities = <String, TextEditingController>{},
      versions = <String, int>{};
  bool ready = false;
  final op = newId();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    ready = true;
    final app = AppScope.read(context);
    for (final id in widget.requestIds) {
      final r = app.workspace.request(id);
      if (r != null) {
        initialRequests[id] = r;
        quantities[id] = TextEditingController(text: '${r.available}');
        versions[id] = r.version;
      }
    }
  }

  @override
  void dispose() {
    for (final c in quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PageFrame(
      title: '이번 전달 기록',
      subtitle: '실제로 물품을 전달한 뒤 기록해 주세요',
      bottom: ActionButton(
        '실제 전달한 수량 기록',
        bottom: true,
        enabled: quantities.values.any((c) => (int.tryParse(c.text) ?? 0) > 0),
        onPressed: () async {
          final selected = <String, int>{};
          for (final e in quantities.entries) {
            final n = int.tryParse(e.value.text);
            if (n == null || n < 0) {
              throw const AppFailure('전달 수량은 0 이상의 정수로 입력해 주세요.');
            }
            if (n > 0) selected[e.key] = n;
          }
          if (!await confirm(
            context,
            '물품을 전달했나요?',
            '${selected.length}개 요청, 총 ${selected.values.fold<int>(0, (a, b) => a + b)}개 전달을 기록해요. 소매업자의 수령 확인은 별도로 진행돼요.',
          )) {
            return;
          }
          await app.workspace.deliver(selected, versions, op);
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        const Info('이번에 전달하지 않는 요청은 0개로 입력해 주세요. 남은 수량은 전달할 목록에 유지돼요.'),
        for (final e in quantities.entries)
          Builder(
            builder: (context) {
              final r = initialRequests[e.key]!;
              final count = int.tryParse(e.value.text) ?? 0;
              return FigmaSurface(
                children: [
                  Item(
                    '${r.s('product')} · ${r.s('option')}',
                    subtitle:
                        '${r.s('address')} ${r.s('addressDetail')}\n전달 가능 ${r.available}개',
                  ),
                  const Section('이번 전달'),
                  Center(
                    child: TdsNumericSpinner(
                      size: TdsNumericSpinnerSize.large,
                      number: count,
                      minNumber: 0,
                      maxNumber: r.available,
                      semanticLabel: '이번 전달 수량 · ${r.s('product')}',
                      onNumberChange: (n) =>
                          setState(() => e.value.text = '$n'),
                    ),
                  ),
                  const TdsSpacing(12),
                  QuantityRow(
                    '누적 전달',
                    '${r.delivered}장 → ${r.delivered + count}장',
                  ),
                  QuantityRow('확보 후 전달 대기', '${r.available - count}장'),
                  QuantityRow('남은 미송', '${r.backorder}장'),
                ],
              );
            },
          ),
      ],
    );
  }
}
