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
  received,
  completed,
}

extension RetailerOrderFilterLabel on RetailerOrderFilter {
  String get label => switch (this) {
    RetailerOrderFilter.all => '전체 내역',
    RetailerOrderFilter.pendingConfirmation => '대기',
    RetailerOrderFilter.inProgress => '진행 중',
    RetailerOrderFilter.received => '수령(입금 전)',
    RetailerOrderFilter.completed => '입금 완료',
  };

  String get emptyTitle => switch (this) {
    RetailerOrderFilter.all => '아직 사입 요청이 없어요',
    RetailerOrderFilter.pendingConfirmation => '대기 중인 요청이 없어요',
    RetailerOrderFilter.inProgress => '진행 중인 요청이 없어요',
    RetailerOrderFilter.received => '수령 후 입금할 요청이 없어요',
    RetailerOrderFilter.completed => '입금 완료한 요청이 아직 없어요',
  };
}

RetailerOrderFilter retailerOrderFilterFromLabel(String label) =>
    RetailerOrderFilter.values.firstWhere((filter) => filter.label == label);

enum RetailerHomeStatus { pendingConfirmation, inProgress, received, completed }

extension RetailerHomeStatusInfo on RetailerHomeStatus {
  String get label => switch (this) {
    RetailerHomeStatus.pendingConfirmation => '대기',
    RetailerHomeStatus.inProgress => '진행 중',
    RetailerHomeStatus.received => '수령(입금 전)',
    RetailerHomeStatus.completed => '입금 완료',
  };

  TdsBadgeColor get badgeColor => switch (this) {
    RetailerHomeStatus.pendingConfirmation => TdsBadgeColor.yellow,
    RetailerHomeStatus.inProgress => TdsBadgeColor.green,
    RetailerHomeStatus.received => TdsBadgeColor.elephant,
    RetailerHomeStatus.completed => TdsBadgeColor.blue,
  };

  RetailerOrderFilter get filter => switch (this) {
    RetailerHomeStatus.pendingConfirmation =>
      RetailerOrderFilter.pendingConfirmation,
    RetailerHomeStatus.inProgress => RetailerOrderFilter.inProgress,
    RetailerHomeStatus.received => RetailerOrderFilter.received,
    RetailerHomeStatus.completed => RetailerOrderFilter.completed,
  };
}

bool retailerHasPendingConfirmation(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) &&
    request.s('status') == 'pending';

bool retailerIsAwaitingDelivery(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) && request.available > 0;

bool retailerIsAwaitingReceipt(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) &&
    request.delivered > request.received;

bool retailerNeedsReply(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) &&
    (request.needsReply || request.n('openIssues') > 0);

bool retailerHasBackorder(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) && request.backorder > 0;

bool retailerIsClosedWithoutCompletion(RequestRecord request) {
  final status = request.s('status');
  return status == 'cancelled' || status == 'rejected';
}

bool retailerIsCompleted(RequestRecord request, {DateTime? now}) =>
    request.paymentComplete;

bool retailerIsReceived(RequestRecord request, {DateTime? now}) =>
    request.receiptComplete && !request.paymentComplete;

bool retailerIsInProgress(RequestRecord request, {DateTime? now}) {
  if (retailerIsClosedWithoutCompletion(request) ||
      retailerHasPendingConfirmation(request) ||
      retailerIsReceived(request, now: now) ||
      retailerIsCompleted(request, now: now)) {
    return false;
  }
  return true;
}

bool retailerMatchesOrderFilter(
  RequestRecord request,
  RetailerOrderFilter filter, {
  DateTime? now,
}) => switch (filter) {
  RetailerOrderFilter.all => true,
  RetailerOrderFilter.pendingConfirmation => retailerHasPendingConfirmation(
    request,
  ),
  RetailerOrderFilter.inProgress => retailerIsInProgress(request, now: now),
  RetailerOrderFilter.received => retailerIsReceived(request, now: now),
  RetailerOrderFilter.completed => retailerIsCompleted(request, now: now),
};

List<RequestRecord> filterRetailerOrders(
  Iterable<RequestRecord> requests,
  RetailerOrderFilter filter, {
  DateTime? now,
}) => requests
    .where((request) => retailerMatchesOrderFilter(request, filter, now: now))
    .toList(growable: false);

int retailerHomeCount(
  Iterable<RequestRecord> requests,
  RetailerHomeStatus status, {
  DateTime? now,
}) => filterRetailerOrders(requests, status.filter, now: now).length;

int retailerOrderPriority(RequestRecord request, {DateTime? now}) {
  if (retailerHasPendingConfirmation(request)) return 0;
  if (retailerIsReceived(request, now: now)) return 1;
  if (retailerNeedsReply(request)) return 2;
  if (retailerHasBackorder(request)) return 3;
  if (retailerIsAwaitingDelivery(request)) return 4;
  if (retailerIsInProgress(request, now: now)) return 5;
  if (retailerIsCompleted(request, now: now)) return 6;
  if (retailerIsClosedWithoutCompletion(request)) return 7;
  return 8;
}

int compareRetailerOrders(RequestRecord a, RequestRecord b, {DateTime? now}) {
  final priority = retailerOrderPriority(
    a,
    now: now,
  ).compareTo(retailerOrderPriority(b, now: now));
  return priority != 0
      ? priority
      : b.s('updatedAt').compareTo(a.s('updatedAt'));
}

class RetailerOrdersSection extends StatefulWidget {
  const RetailerOrdersSection({
    this.initialFilter = RetailerOrderFilter.all,
    super.key,
  });

  final RetailerOrderFilter initialFilter;

  @override
  State<RetailerOrdersSection> createState() => RetailerOrdersSectionState();
}

class RetailerOrdersSectionState extends State<RetailerOrdersSection> {
  static const _filters = [
    RetailerOrderFilter.all,
    RetailerOrderFilter.pendingConfirmation,
    RetailerOrderFilter.inProgress,
    RetailerOrderFilter.received,
    RetailerOrderFilter.completed,
  ];

  late RetailerOrderFilter filter = widget.initialFilter;
  String query = '';
  final _headingKey = GlobalKey();

  void showFilter(RetailerOrderFilter value) {
    setState(() {
      filter = value;
      query = '';
    });
    scrollToSection(_headingKey);
  }

  @override
  void didUpdateWidget(covariant RetailerOrdersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    if (current?.role != AppRole.retailer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          EmptyState('소매업자 전용 화면이에요', '현재 계정에서는 사입 내역을 열 수 없어요.'),
        ],
      );
    }

    final now = DateTime.now();
    final all =
        app.workspace
            .records('requests')
            .map((record) => RequestRecord(record.id, record.data))
            .toList(growable: false)
          ..sort((a, b) => compareRetailerOrders(a, b, now: now));

    final search = query.trim().toLowerCase();
    final rows =
        filterRetailerOrders(all, filter, now: now)
            .where((request) => _searchText(app, request).contains(search))
            .toList(growable: false)
          ..sort((a, b) => compareRetailerOrders(a, b, now: now));
    final drafts = app.workspace.records('drafts').length;

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
          placeholder: '도매처·사입삼촌 검색',
          value: query,
          onChanged: (value) => setState(() => query = value),
        ),
        TdsTab(
          semanticLabel: '사입 내역 필터',
          fluid: true,
          size: TdsTabSize.small,
          items: [
            for (final candidate in _filters)
              TdsTabItem(text: candidate.label, selected: filter == candidate),
          ],
          onChanged: (index) => setState(() => filter = _filters[index]),
        ),
        FigmaSurface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            Item(
              '임시저장 $drafts건',
              verticalPadding: TdsListRowVerticalPadding.small,
              leading: const FigmaIcon('clock'),
              onTap: () => openPage(
                context,
                const PageFrame(title: '요청 작성', children: [RequestHub()]),
              ),
            ),
          ],
        ),
        if (rows.isEmpty && search.isNotEmpty)
          const EmptyState.titleOnly('검색 결과가 없어요')
        else if (rows.isEmpty)
          EmptyState.titleOnly(filter.emptyTitle)
        else ...[
          Section(
            '${filter.label} ${rows.length}건',
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          ),
          for (final request in rows)
            _RetailerOrderCard(
              request: request,
              now: now,
              onTap: () => openPage(context, RequestDetailPage(request.id)),
            ),
        ],
      ],
    );
  }

  String _searchText(AppServices app, RequestRecord request) {
    final peer = app.workspace.profile(request.s('uncleId'));
    return [
      requestTitle(request.data),
      request.s('option'),
      for (final wholesaler in requestWholesalers(request.data)) ...[
        textOf(wholesaler, 'wholesaler'),
        textOf(wholesaler, 'location'),
      ],
      peer?.name ?? '',
      request.statusLabel,
    ].join(' ').toLowerCase();
  }
}

class _RetailerOrderCard extends StatelessWidget {
  const _RetailerOrderCard({
    required this.request,
    required this.now,
    required this.onTap,
  });

  final RequestRecord request;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final uncle = app.workspace.profile(request.s('uncleId'));
    final wholesalerOnly = isWholesalerOnlyRequest(request.data);
    return FigmaSurface(
      children: [
        TdsListRow(
          left: FigmaIcon(wholesalerOnly ? 'store' : 'shirt'),
          contents: TdsListRowTexts(
            type: TdsListRowTextType.row2TypeA,
            top: Text(_titleText()),
            bottom: Text(_subtitleText(uncle?.name ?? '사입삼촌')),
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
              for (final badge in _badgesFor(request, now))
                TdsBadge(
                  size: TdsBadgeSize.xsmall,
                  color: badge.color,
                  variant: TdsBadgeVariant.weak,
                  child: Text(badge.label),
                ),
            ],
          ),
        ),
        if (!wholesalerOnly)
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
    DateTime now,
  ) {
    if (request.s('status') == 'cancelled') {
      return [(color: TdsBadgeColor.elephant, label: '취소 종료')];
    }
    if (request.s('status') == 'rejected') {
      return [(color: TdsBadgeColor.red, label: '거절')];
    }
    if (retailerIsCompleted(request, now: now)) {
      return [
        (color: TdsBadgeColor.blue, label: '입금 완료'),
        (color: TdsBadgeColor.elephant, label: request.paymentLabel),
      ];
    }
    final badges = <({TdsBadgeColor color, String label})>[];
    if (retailerHasPendingConfirmation(request)) {
      badges.add((color: TdsBadgeColor.blue, label: '대기'));
    }
    if (retailerIsReceived(request, now: now)) {
      badges.add((color: TdsBadgeColor.teal, label: '수령(입금 전)'));
    } else {
      if (retailerIsAwaitingDelivery(request)) {
        badges.add((color: TdsBadgeColor.green, label: '전달 대기'));
      }
      if (retailerIsInProgress(request, now: now)) {
        badges.add((color: TdsBadgeColor.yellow, label: '진행 중'));
      }
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

  String _titleText() {
    final title = requestTitle(request.data);
    final option = request.s('option').trim();
    if (isWholesalerOnlyRequest(request.data) || option.isEmpty) return title;
    return '$title · $option';
  }

  String _subtitleText(String uncleName) {
    final wholesalerSummary = _wholesalerSummary();
    final parts = <String>[uncleName];
    if (wholesalerSummary.isNotEmpty) {
      parts.add(wholesalerSummary);
    }
    if (!isWholesalerOnlyRequest(request.data)) {
      parts.add('요청 ${request.quantity}장');
    }
    return parts.join(' · ');
  }

  String _wholesalerSummary() {
    final labels = requestWholesalers(request.data)
        .map((entry) {
          final wholesaler = textOf(entry, 'wholesaler').trim();
          final location = textOf(entry, 'location').trim();
          if (wholesaler.isEmpty && location.isEmpty) return '';
          if (wholesaler.isEmpty) return location;
          if (location.isEmpty) return wholesaler;
          return '$wholesaler · $location';
        })
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) return '';
    return labels.length == 1
        ? labels.first
        : '${labels.first} 외 ${labels.length - 1}곳';
  }
}
