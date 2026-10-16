import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'delivery.dart';
import 'requests.dart';

enum UncleOrderFilter {
  all,
  incoming,
  awaitingReply,
  inProgress,
  awaitingDelivery,
  awaitingReceipt,
  backorder,
  recheck,
  issues,
  received,
  completed,
}

extension UncleOrderFilterInfo on UncleOrderFilter {
  String get label => switch (this) {
    UncleOrderFilter.all => '전체 내역',
    UncleOrderFilter.incoming => '사입 요청',
    UncleOrderFilter.awaitingReply => '답변 대기',
    UncleOrderFilter.inProgress => '사입 중',
    UncleOrderFilter.awaitingDelivery => '전달 대기',
    UncleOrderFilter.awaitingReceipt => '수령 대기',
    UncleOrderFilter.backorder => '미송',
    UncleOrderFilter.recheck => '재확인',
    UncleOrderFilter.issues => '문제·협의',
    UncleOrderFilter.received => '완료(입금 전)',
    UncleOrderFilter.completed => '입금 완료',
  };

  TdsBadgeColor get color => switch (this) {
    UncleOrderFilter.inProgress => TdsBadgeColor.yellow,
    UncleOrderFilter.awaitingDelivery => TdsBadgeColor.green,
    UncleOrderFilter.awaitingReceipt => TdsBadgeColor.teal,
    UncleOrderFilter.recheck || UncleOrderFilter.issues => TdsBadgeColor.red,
    UncleOrderFilter.all ||
    UncleOrderFilter.received ||
    UncleOrderFilter.completed => TdsBadgeColor.elephant,
    _ => TdsBadgeColor.blue,
  };

  String get emptyTitle => switch (this) {
    UncleOrderFilter.all => '아직 사입 요청이 없어요',
    UncleOrderFilter.incoming => '확인할 새 요청이 없어요',
    UncleOrderFilter.awaitingReply => '상대방 확인을 기다리는 요청이 없어요',
    UncleOrderFilter.inProgress => '진행 중인 사입이 없어요',
    UncleOrderFilter.awaitingDelivery => '지금 전달할 물품이 없어요',
    UncleOrderFilter.awaitingReceipt => '수령을 기다리는 물품이 없어요',
    UncleOrderFilter.backorder => '남아 있는 미송이 없어요',
    UncleOrderFilter.recheck => '오늘 다시 확인할 미송이 없어요',
    UncleOrderFilter.issues => '확인할 문제나 협의가 없어요',
    UncleOrderFilter.received => '수령 완료 후 입금을 기다리는 사입이 없어요',
    UncleOrderFilter.completed => '입금 완료한 사입이 아직 없어요',
  };
}

/// 홈의 수치와 내역 목록에 같은 조건을 적용한다.
/// 부분 확보·전달 요청은 남아 있는 각 단계에서 함께 표시한다.
bool uncleMatchesOrderFilter(RequestRecord request, UncleOrderFilter filter) {
  if (filter == UncleOrderFilter.all) return true;
  if (filter == UncleOrderFilter.completed) {
    return request.paymentComplete;
  }
  if (filter == UncleOrderFilter.received) {
    return request.receiptComplete && !request.paymentComplete;
  }
  if (request.receiptComplete ||
      ['cancelled', 'rejected'].contains(request.s('status'))) {
    return false;
  }
  return switch (filter) {
    UncleOrderFilter.incoming => request.s('status') == 'pending',
    UncleOrderFilter.awaitingReply => request.needsReply,
    UncleOrderFilter.inProgress => [
      'accepted',
      'completed',
    ].contains(request.s('status')),
    UncleOrderFilter.awaitingDelivery => request.available > 0,
    UncleOrderFilter.awaitingReceipt => request.delivered > request.received,
    UncleOrderFilter.backorder => request.backorder > 0,
    UncleOrderFilter.recheck => request.overdue,
    UncleOrderFilter.issues =>
      request.n('openIssues') > 0 || request.s('proposalId').isNotEmpty,
    _ => false,
  };
}

List<RequestRecord> filterUncleOrders(
  Iterable<RequestRecord> requests,
  UncleOrderFilter filter,
) => requests
    .where((request) => uncleMatchesOrderFilter(request, filter))
    .toList();

int uncleOrderPriority(RequestRecord request) {
  if (request.receiptComplete ||
      ['cancelled', 'rejected'].contains(request.s('status'))) {
    return 7;
  }
  if (request.n('openIssues') > 0 || request.s('proposalId').isNotEmpty) {
    return 0;
  }
  if (request.s('status') == 'pending') return 1;
  if (request.overdue) return 2;
  if (request.available > 0) return 3;
  if (request.needsReply) return 5;
  if (request.delivered > request.received && request.remaining == 0) return 6;
  return 4;
}

class UncleOrdersSection extends StatefulWidget {
  const UncleOrdersSection({
    this.initialFilter = UncleOrderFilter.all,
    super.key,
  });

  final UncleOrderFilter initialFilter;

  @override
  State<UncleOrdersSection> createState() => UncleOrdersSectionState();
}

class UncleOrdersSectionState extends State<UncleOrdersSection> {
  late UncleOrderFilter filter = widget.initialFilter;
  String query = '', group = '거래처별';
  final _headingKey = GlobalKey();

  void showFilter(UncleOrderFilter value) {
    setState(() {
      filter = value;
      query = '';
    });
    scrollToSection(_headingKey);
  }

  @override
  void didUpdateWidget(covariant UncleOrdersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.session.current?.role != AppRole.uncle) {
      return const EmptyState('사입삼촌 전용 화면이에요', '사입삼촌 계정에서 업무를 확인해 주세요.');
    }
    final all = app.workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data));
    final search = query.trim().toLowerCase();
    final rows =
        filterUncleOrders(all, filter).where((request) {
          final peer = app.workspace.profile(request.s('retailerId'));
          return [
            request.s('product'),
            request.s('option'),
            request.s('wholesaler'),
            request.s('location'),
            peer?.name ?? '',
            peer?.displayName ?? '',
            for (final entry in requestWholesalers(request.data)) ...[
              textOf(entry, 'wholesaler'),
              textOf(entry, 'location'),
            ],
          ].join(' ').toLowerCase().contains(search);
        }).toList()..sort((a, b) {
          final priority = uncleOrderPriority(
            a,
          ).compareTo(uncleOrderPriority(b));
          return priority != 0
              ? priority
              : b.s('createdAt').compareTo(a.s('createdAt'));
        });
    final groups = <String, List<RequestRecord>>{};
    for (final request in rows) {
      final key = group == '도매처별'
          ? request.s('wholesaler')
          : request.s('retailerId');
      groups.putIfAbsent(key, () => []).add(request);
    }
    final available = filterUncleOrders(
      all,
      UncleOrderFilter.awaitingDelivery,
    ).fold<int>(0, (sum, request) => sum + request.available);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          '사입 내역',
          key: _headingKey,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          typography: TdsTypography.t4,
          fontWeight: TdsFontWeight.bold,
        ),
        AppSearchField(
          placeholder: '도매처·거래처 검색',
          value: query,
          onChanged: (value) => setState(() => query = value),
        ),
        Choices(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          options: [
            for (final value in const [
              UncleOrderFilter.all,
              UncleOrderFilter.incoming,
              UncleOrderFilter.inProgress,
              UncleOrderFilter.received,
              UncleOrderFilter.completed,
            ])
              value.label,
            if (![
              UncleOrderFilter.all,
              UncleOrderFilter.incoming,
              UncleOrderFilter.inProgress,
              UncleOrderFilter.received,
              UncleOrderFilter.completed,
            ].contains(filter))
              filter.label,
          ],
          value: filter.label,
          onChanged: (value) => setState(() {
            filter = UncleOrderFilter.values.firstWhere(
              (item) => item.label == value,
            );
          }),
        ),
        FigmaSurface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            Item(
              '전달 가능 $available장',
              verticalPadding: TdsListRowVerticalPadding.small,
              leading: const FigmaIcon('bag'),
              onTap: () => openPage(
                context,
                const PageFrame(title: '상품 전달', children: [DeliveryList()]),
              ),
            ),
          ],
        ),
        Choices(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          options: const ['거래처별', '도매처별'],
          value: group,
          onChanged: (value) => setState(() => group = value),
        ),
        if (rows.isEmpty)
          EmptyState.titleOnly(
            search.isEmpty ? filter.emptyTitle : '검색 결과가 없어요',
          )
        else ...[
          Section(
            '${filter.label} ${rows.length}건',
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          ),
          for (final entry in groups.entries) ...[
            Section(
              '${group == '도매처별' ? (entry.key.isEmpty ? '도매처 미지정' : entry.key) : app.workspace.profile(entry.key)?.name ?? '거래처'} · ${entry.value.length}건',
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            ),
            for (final request in entry.value)
              _UncleOrderCard(
                request,
                key: ValueKey('uncle-order-${request.id}'),
              ),
          ],
        ],
      ],
    );
  }
}

class _UncleOrderCard extends StatelessWidget {
  const _UncleOrderCard(this.request, {super.key});
  final RequestRecord request;

  @override
  Widget build(BuildContext context) {
    final badges = [
      for (final filter in UncleOrderFilter.values)
        if (filter != UncleOrderFilter.all &&
            uncleMatchesOrderFilter(request, filter))
          filter,
    ];
    return FigmaSurface(
      children: [
        Item(
          isWholesalerOnlyRequest(request.data)
              ? requestTitle(request.data)
              : '${requestTitle(request.data)} · ${request.s('option')}',
          subtitle: isWholesalerOnlyRequest(request.data)
              ? '도매처 ${requestWholesalers(request.data).length}곳'
              : '${request.s('wholesaler')} · 요청 ${request.quantity}장',
          leading: FigmaIcon(
            isWholesalerOnlyRequest(request.data) ? 'store' : 'shirt',
          ),
          onTap: () => openPage(context, RequestDetailPage(request.id)),
        ),
        Inset(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final badge in badges)
                TdsBadge(
                  size: TdsBadgeSize.xsmall,
                  color: badge.color,
                  variant: TdsBadgeVariant.weak,
                  child: Text(badge.label),
                ),
              if (badges.isEmpty) StatusBadge(request.statusLabel),
              if (request.paymentComplete) StatusBadge(request.paymentLabel),
            ],
          ),
        ),
        if (!isWholesalerOnlyRequest(request.data))
          Info(
            '확보 ${request.acquired} · ${request.b('resultShared') ? '미송 ${request.backorder}' : '미확인 ${request.remaining}'} · 전달 ${request.delivered} · 수령 ${request.received}',
          ),
        if (!request.ended && request.s('recheck').isNotEmpty)
          Info('${request.s('recheck')} 재확인'),
      ],
    );
  }
}
