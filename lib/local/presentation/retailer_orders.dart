import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'requests.dart';

enum RetailerOrderFilter {
  all,
  pendingConfirmation,
  inProgress,
  awaitingDelivery,
  awaitingReceipt,
  replyNeeded,
  backorder,
  completed,
}

extension RetailerOrderFilterLabel on RetailerOrderFilter {
  String get label => switch (this) {
    RetailerOrderFilter.all => '전체 내역',
    RetailerOrderFilter.pendingConfirmation => '확인 대기',
    RetailerOrderFilter.inProgress => '진행 중',
    RetailerOrderFilter.awaitingDelivery => '전달 대기',
    RetailerOrderFilter.awaitingReceipt => '수령 확인',
    RetailerOrderFilter.replyNeeded => '답변 필요',
    RetailerOrderFilter.backorder => '미송',
    RetailerOrderFilter.completed => '완료',
  };

  String get emptyTitle => switch (this) {
    RetailerOrderFilter.all => '아직 사입 요청이 없어요',
    RetailerOrderFilter.pendingConfirmation => '상대방 확인 대기 요청이 없어요',
    RetailerOrderFilter.inProgress => '진행 중인 요청이 없어요',
    RetailerOrderFilter.awaitingDelivery => '전달을 기다리는 확보분이 없어요',
    RetailerOrderFilter.awaitingReceipt => '확인할 전달분이 없어요',
    RetailerOrderFilter.replyNeeded => '답변이 필요한 요청이 없어요',
    RetailerOrderFilter.backorder => '열린 미송 요청이 없어요',
    RetailerOrderFilter.completed => '완료한 요청이 아직 없어요',
  };

  String get emptyDescription => switch (this) {
    RetailerOrderFilter.all => '사입하기 탭에서 새 주문을 넣거나 초안·재요청을 이어서 진행해 보세요.',
    RetailerOrderFilter.pendingConfirmation => '사입삼촌이 아직 확인하지 않은 요청만 여기에서 보여요.',
    RetailerOrderFilter.inProgress =>
      '확보·전달·수령 중 더 확인할 단계가 생기면 해당 필터에서 바로 볼 수 있어요.',
    RetailerOrderFilter.awaitingDelivery =>
      '확보가 끝나 전달을 기다리는 요청이 생기면 여기에서 모아 볼 수 있어요.',
    RetailerOrderFilter.awaitingReceipt =>
      '전달 기록이 생기면 수령 확인이 필요한 요청을 여기에서 확인해요.',
    RetailerOrderFilter.replyNeeded => '미송 답변이나 문제 확인이 필요한 요청만 모아 보여요.',
    RetailerOrderFilter.backorder => '남은 미송이 있는 요청만 따로 확인할 수 있어요.',
    RetailerOrderFilter.completed => '수령까지 끝난 요청이 생기면 완료 내역으로 남아요.',
  };
}

RetailerOrderFilter retailerOrderFilterFromLabel(String label) =>
    RetailerOrderFilter.values.firstWhere((filter) => filter.label == label);

enum RetailerHomeStatus {
  pendingConfirmation,
  inProgress,
  awaitingDelivery,
  awaitingReceipt,
}

extension RetailerHomeStatusInfo on RetailerHomeStatus {
  String get label => switch (this) {
    RetailerHomeStatus.pendingConfirmation => '상대방 확인 대기',
    RetailerHomeStatus.inProgress => '진행 중인 사입 요청',
    RetailerHomeStatus.awaitingDelivery => '확보 후 전달 대기',
    RetailerHomeStatus.awaitingReceipt => '받은 상품 확인',
  };

  String get chipText => switch (this) {
    RetailerHomeStatus.pendingConfirmation => '대기',
    RetailerHomeStatus.inProgress => '진행',
    RetailerHomeStatus.awaitingDelivery => '전달',
    RetailerHomeStatus.awaitingReceipt => '수령',
  };

  TdsBadgeColor get chipColor => switch (this) {
    RetailerHomeStatus.pendingConfirmation => TdsBadgeColor.blue,
    RetailerHomeStatus.inProgress => TdsBadgeColor.yellow,
    RetailerHomeStatus.awaitingDelivery => TdsBadgeColor.green,
    RetailerHomeStatus.awaitingReceipt => TdsBadgeColor.teal,
  };

  RetailerOrderFilter get filter => switch (this) {
    RetailerHomeStatus.pendingConfirmation =>
      RetailerOrderFilter.pendingConfirmation,
    RetailerHomeStatus.inProgress => RetailerOrderFilter.inProgress,
    RetailerHomeStatus.awaitingDelivery => RetailerOrderFilter.awaitingDelivery,
    RetailerHomeStatus.awaitingReceipt => RetailerOrderFilter.awaitingReceipt,
  };
}

bool retailerHasPendingConfirmation(RequestRecord request) =>
    !request.ended && request.s('status') == 'pending';

bool retailerIsAwaitingDelivery(RequestRecord request) =>
    !request.ended && request.available > 0;

bool retailerIsAwaitingReceipt(RequestRecord request) =>
    !request.ended && request.delivered > request.received;

bool retailerNeedsReply(RequestRecord request) =>
    !request.ended && (request.needsReply || request.n('openIssues') > 0);

bool retailerHasBackorder(RequestRecord request) =>
    !request.ended && request.backorder > 0;

bool retailerIsInProgress(RequestRecord request) =>
    !request.ended &&
    !retailerHasPendingConfirmation(request) &&
    (request.remaining > 0 ||
        (!retailerIsAwaitingDelivery(request) &&
            !retailerIsAwaitingReceipt(request)));

bool retailerMatchesOrderFilter(
  RequestRecord request,
  RetailerOrderFilter filter,
) => switch (filter) {
  RetailerOrderFilter.all => true,
  RetailerOrderFilter.pendingConfirmation => retailerHasPendingConfirmation(
    request,
  ),
  RetailerOrderFilter.inProgress => retailerIsInProgress(request),
  RetailerOrderFilter.awaitingDelivery => retailerIsAwaitingDelivery(request),
  RetailerOrderFilter.awaitingReceipt => retailerIsAwaitingReceipt(request),
  RetailerOrderFilter.replyNeeded => retailerNeedsReply(request),
  RetailerOrderFilter.backorder => retailerHasBackorder(request),
  RetailerOrderFilter.completed => request.s('status') == 'completed',
};

List<RequestRecord> filterRetailerOrders(
  Iterable<RequestRecord> requests,
  RetailerOrderFilter filter,
) => requests
    .where((request) => retailerMatchesOrderFilter(request, filter))
    .toList(growable: false);

int retailerHomeCount(
  Iterable<RequestRecord> requests,
  RetailerHomeStatus status,
) => filterRetailerOrders(requests, status.filter).length;

int retailerOrderPriority(RequestRecord request) {
  if (retailerIsAwaitingReceipt(request)) return 0;
  if (retailerNeedsReply(request)) return 1;
  if (retailerIsAwaitingDelivery(request)) return 2;
  if (retailerHasPendingConfirmation(request)) return 3;
  if (retailerHasBackorder(request)) return 4;
  if (retailerIsInProgress(request)) return 5;
  if (request.s('status') == 'completed') return 6;
  return 7;
}

int compareRetailerOrders(RequestRecord a, RequestRecord b) {
  final priority = retailerOrderPriority(a).compareTo(retailerOrderPriority(b));
  return priority != 0
      ? priority
      : b.s('updatedAt').compareTo(a.s('updatedAt'));
}

class RetailerOrdersPage extends StatefulWidget {
  const RetailerOrdersPage({
    this.initialFilter = RetailerOrderFilter.all,
    super.key,
  });

  final RetailerOrderFilter initialFilter;

  @override
  State<RetailerOrdersPage> createState() => _RetailerOrdersPageState();
}

class _RetailerOrdersPageState extends State<RetailerOrdersPage> {
  late RetailerOrderFilter filter = widget.initialFilter;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    if (current?.role != AppRole.retailer) {
      return const PageFrame(
        title: '사입 내역',
        children: [EmptyState('소매업자 전용 화면이에요', '현재 계정에서는 사입 내역을 열 수 없어요.')],
      );
    }
    final all =
        app.workspace
            .records('requests')
            .map((record) => RequestRecord(record.id, record.data))
            .toList()
          ..sort(compareRetailerOrders);
    final search = query.trim().toLowerCase();
    final rows =
        filterRetailerOrders(all, filter)
            .where((request) => _searchText(app, request).contains(search))
            .toList(growable: false)
          ..sort(compareRetailerOrders);
    final drafts = app.workspace.records('drafts').length;
    return PageFrame(
      title: '사입 내역',
      children: [
        AppSearchField(
          placeholder: '상품·도매처·사입삼촌 검색',
          onChanged: (value) => setState(() => query = value),
        ),
        Choices(
          options: [
            for (final candidate in RetailerOrderFilter.values) candidate.label,
          ],
          value: filter.label,
          onChanged: (value) =>
              setState(() => filter = retailerOrderFilterFromLabel(value)),
        ),
        FigmaSurface(
          children: [
            Item(
              '임시저장·다시 요청',
              leading: const FigmaIcon('clock'),
              subtitle: '임시저장 $drafts건',
              onTap: () => openPage(
                context,
                const PageFrame(title: '요청 작성', children: [RequestHub()]),
              ),
            ),
          ],
        ),
        if (rows.isEmpty && search.isNotEmpty)
          const EmptyState('검색 결과가 없어요', '상품명이나 도매처, 사입삼촌 이름을 다시 확인해 주세요.')
        else if (rows.isEmpty)
          EmptyState(filter.emptyTitle, filter.emptyDescription)
        else ...[
          Section('${filter.label} ${rows.length}건'),
          for (final request in rows)
            _RetailerOrderCard(
              request: request,
              onTap: () => openPage(context, RequestDetailPage(request.id)),
            ),
        ],
      ],
    );
  }

  String _searchText(AppServices app, RequestRecord request) {
    final peer = app.workspace.profile(request.s('uncleId'));
    return [
      request.s('product'),
      request.s('option'),
      request.s('wholesaler'),
      request.s('location'),
      peer?.name ?? '',
      request.statusLabel,
    ].join(' ').toLowerCase();
  }
}

class _RetailerOrderCard extends StatelessWidget {
  const _RetailerOrderCard({required this.request, required this.onTap});

  final RequestRecord request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final uncle = app.workspace.profile(request.s('uncleId'));
    return FigmaSurface(
      children: [
        TdsListRow(
          left: const FigmaIcon('shirt'),
          contents: TdsListRowTexts(
            type: TdsListRowTextType.row2TypeA,
            top: Text('${request.s('product')} · ${request.s('option')}'),
            bottom: Text('${uncle?.name ?? '사입삼촌'} · 요청 ${request.quantity}장'),
          ),
          onPressed: onTap,
          withArrow: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final badge in _badgesFor(request))
                TdsBadge(
                  size: TdsBadgeSize.xsmall,
                  color: badge.color,
                  variant: TdsBadgeVariant.weak,
                  child: Text(badge.label),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: TdsText(
            '확보 ${request.acquired} · ${request.b('resultShared') ? '미송 ${request.backorder}' : '미확인 ${request.remaining}'} · 전달 ${request.delivered} · 수령 ${request.received}',
            typography: TdsTypography.t7,
          ),
        ),
        if (request.s('recheck').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: TdsText(
              '${request.s('recheck')} 재확인',
              typography: TdsTypography.t7,
              color: TdsTheme.of(context).color('grey600'),
            ),
          ),
      ],
    );
  }

  List<({TdsBadgeColor color, String label})> _badgesFor(
    RequestRecord request,
  ) {
    if (request.s('status') == 'completed') {
      return [(color: TdsBadgeColor.blue, label: '완료')];
    }
    if (request.s('status') == 'cancelled') {
      return [(color: TdsBadgeColor.elephant, label: '취소 종료')];
    }
    if (request.s('status') == 'rejected') {
      return [(color: TdsBadgeColor.red, label: '거절')];
    }
    final badges = <({TdsBadgeColor color, String label})>[];
    if (retailerHasPendingConfirmation(request)) {
      badges.add((color: TdsBadgeColor.blue, label: '확인 대기'));
    }
    if (retailerIsInProgress(request)) {
      badges.add((color: TdsBadgeColor.yellow, label: '진행 중'));
    }
    if (retailerIsAwaitingDelivery(request)) {
      badges.add((color: TdsBadgeColor.green, label: '전달 대기'));
    }
    if (retailerIsAwaitingReceipt(request)) {
      badges.add((color: TdsBadgeColor.teal, label: '수령 확인'));
    }
    if (retailerNeedsReply(request)) {
      badges.add((color: TdsBadgeColor.red, label: '답변 필요'));
    }
    if (retailerHasBackorder(request)) {
      badges.add((color: TdsBadgeColor.blue, label: '미송'));
    }
    if (request.s('proposalId').isNotEmpty) {
      badges.add((color: TdsBadgeColor.elephant, label: '협의 중'));
    }
    return badges.isEmpty
        ? [(color: TdsBadgeColor.yellow, label: request.statusLabel)]
        : badges;
  }
}
