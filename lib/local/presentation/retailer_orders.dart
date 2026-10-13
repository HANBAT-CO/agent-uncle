import 'dart:async';

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
    RetailerOrderFilter.received => '수령',
    RetailerOrderFilter.completed => '완료',
  };

  String get emptyTitle => switch (this) {
    RetailerOrderFilter.all => '아직 사입 요청이 없어요',
    RetailerOrderFilter.pendingConfirmation => '대기 중인 요청이 없어요',
    RetailerOrderFilter.inProgress => '진행 중인 요청이 없어요',
    RetailerOrderFilter.received => '수령 단계 요청이 없어요',
    RetailerOrderFilter.completed => '완료한 요청이 아직 없어요',
  };

  String get emptyDescription => switch (this) {
    RetailerOrderFilter.all => '사입하기 탭에서 새 주문을 넣거나 초안·재요청을 이어서 진행해 보세요.',
    RetailerOrderFilter.pendingConfirmation => '사입삼촌 확인을 기다리는 요청만 여기에서 보여요.',
    RetailerOrderFilter.inProgress => '확보·전달·미송·문제 확인이 진행 중인 요청을 여기에서 모아 봐요.',
    RetailerOrderFilter.received => '수령 확인 전이거나 수령 확인 후 7일 이내 요청이 여기에서 보여요.',
    RetailerOrderFilter.completed => '수령 확인 후 7일이 지난 요청만 완료로 옮겨져요.',
  };
}

RetailerOrderFilter retailerOrderFilterFromLabel(String label) =>
    RetailerOrderFilter.values.firstWhere((filter) => filter.label == label);

enum RetailerHomeStatus { pendingConfirmation, inProgress, received }

extension RetailerHomeStatusInfo on RetailerHomeStatus {
  String get label => switch (this) {
    RetailerHomeStatus.pendingConfirmation => '대기',
    RetailerHomeStatus.inProgress => '진행',
    RetailerHomeStatus.received => '수령',
  };

  TdsBadgeColor get chipColor => switch (this) {
    RetailerHomeStatus.pendingConfirmation => TdsBadgeColor.blue,
    RetailerHomeStatus.inProgress => TdsBadgeColor.yellow,
    RetailerHomeStatus.received => TdsBadgeColor.teal,
  };

  RetailerOrderFilter get filter => switch (this) {
    RetailerHomeStatus.pendingConfirmation =>
      RetailerOrderFilter.pendingConfirmation,
    RetailerHomeStatus.inProgress => RetailerOrderFilter.inProgress,
    RetailerHomeStatus.received => RetailerOrderFilter.received,
  };
}

bool retailerHasPendingConfirmation(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) && request.s('status') == 'pending';

bool retailerIsAwaitingDelivery(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) && request.available > 0;

bool retailerIsAwaitingReceipt(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) && request.delivered > request.received;

bool retailerNeedsReply(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) &&
    (request.needsReply || request.n('openIssues') > 0);

bool retailerHasBackorder(RequestRecord request) =>
    !retailerIsClosedWithoutCompletion(request) && request.backorder > 0;

bool retailerIsClosedWithoutCompletion(RequestRecord request) {
  final status = request.s('status');
  return status == 'cancelled' || status == 'rejected';
}

DateTime? retailerCompletionBoundary(RequestRecord request) {
  final receivedAt = request.receivedAt;
  if (receivedAt == null ||
      request.s('status') != 'completed' ||
      request.received <= 0 ||
      request.received != request.delivered ||
      request.received != request.quantity - request.cancelled ||
      request.n('held') > 0) {
    return null;
  }
  if (retailerIsAwaitingReceipt(request) ||
      retailerIsAwaitingDelivery(request) ||
      retailerHasBackorder(request) ||
      retailerNeedsReply(request) ||
      request.remaining > 0 ||
      request.s('proposalId').isNotEmpty) {
    return null;
  }
  return receivedAt.add(const Duration(days: 7));
}

bool retailerIsCompleted(RequestRecord request, {DateTime? now}) {
  final boundary = retailerCompletionBoundary(request);
  if (boundary == null) return false;
  return !boundary.isAfter(now ?? DateTime.now());
}

bool retailerIsReceived(RequestRecord request, {DateTime? now}) {
  if (retailerIsClosedWithoutCompletion(request)) return false;
  if (retailerIsAwaitingReceipt(request)) return true;
  final boundary = retailerCompletionBoundary(request);
  if (boundary == null) return false;
  return boundary.isAfter(now ?? DateTime.now());
}

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
}) =>
    filterRetailerOrders(requests, status.filter, now: now).length;

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
  final priority = retailerOrderPriority(a, now: now).compareTo(
    retailerOrderPriority(b, now: now),
  );
  return priority != 0
      ? priority
      : b.s('updatedAt').compareTo(a.s('updatedAt'));
}

class RetailerOrdersPage extends StatelessWidget {
  const RetailerOrdersPage({
    this.initialFilter = RetailerOrderFilter.all,
    super.key,
  });

  final RetailerOrderFilter initialFilter;

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '사입 내역',
    children: [RetailerOrdersSection(initialFilter: initialFilter)],
  );
}

class RetailerOrdersSection extends StatefulWidget {
  const RetailerOrdersSection({
    this.initialFilter = RetailerOrderFilter.all,
    this.showHeading = false,
    this.onCompletionBoundary,
    super.key,
  });

  final RetailerOrderFilter initialFilter;
  final bool showHeading;
  final VoidCallback? onCompletionBoundary;

  @override
  State<RetailerOrdersSection> createState() => _RetailerOrdersSectionState();
}

class _RetailerOrdersSectionState extends State<RetailerOrdersSection>
    with WidgetsBindingObserver {
  static const _filters = [
    RetailerOrderFilter.all,
    RetailerOrderFilter.pendingConfirmation,
    RetailerOrderFilter.inProgress,
    RetailerOrderFilter.received,
    RetailerOrderFilter.completed,
  ];

  late RetailerOrderFilter filter = widget.initialFilter;
  String query = '';
  Timer? _completionBoundaryTimer;
  DateTime? _scheduledBoundary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshCompletion();
  }

  void _refreshCompletion() {
    if (!mounted) return;
    setState(() {});
    widget.onCompletionBoundary?.call();
  }

  @override
  void didUpdateWidget(covariant RetailerOrdersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      filter = widget.initialFilter;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _completionBoundaryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.session.current;
    if (current?.role != AppRole.retailer) {
      _cancelBoundaryRefresh();
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
    _syncBoundaryRefresh(all, now);

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
        if (widget.showHeading) const Section('사입 내역'),
        AppSearchField(
          placeholder: '상품·도매처·사입삼촌 검색',
          onChanged: (value) => setState(() => query = value),
        ),
        TdsTab(
          semanticLabel: '사입 내역 필터',
          fluid: true,
          items: [
            for (final candidate in _filters)
              TdsTabItem(text: candidate.label, selected: filter == candidate),
          ],
          onChanged: (index) => setState(() => filter = _filters[index]),
        ),
        const TdsSpacing(12),
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
              now: now,
              onTap: () => openPage(context, RequestDetailPage(request.id)),
            ),
        ],
      ],
    );
  }

  void _cancelBoundaryRefresh() {
    _scheduledBoundary = null;
    _completionBoundaryTimer?.cancel();
    _completionBoundaryTimer = null;
  }

  void _syncBoundaryRefresh(List<RequestRecord> requests, DateTime now) {
    final nextBoundary = requests
        .map(retailerCompletionBoundary)
        .whereType<DateTime>()
        .where((boundary) => boundary.isAfter(now))
        .fold<DateTime?>(
          null,
          (earliest, boundary) =>
              earliest == null || boundary.isBefore(earliest)
              ? boundary
              : earliest,
        );
    if (nextBoundary == _scheduledBoundary) return;
    _cancelBoundaryRefresh();
    _scheduledBoundary = nextBoundary;
    if (nextBoundary == null) return;
    final delay = nextBoundary.difference(now);
    _completionBoundaryTimer = Timer(
      (delay.isNegative ? Duration.zero : delay) + const Duration(seconds: 1),
      _refreshCompletion,
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
      return [(color: TdsBadgeColor.blue, label: '완료')];
    }
    final badges = <({TdsBadgeColor color, String label})>[];
    if (retailerHasPendingConfirmation(request)) {
      badges.add((color: TdsBadgeColor.blue, label: '확인 대기'));
    }
    if (retailerIsReceived(request, now: now)) {
      badges.add((color: TdsBadgeColor.teal, label: '수령'));
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
    return labels.length == 1 ? labels.first : '${labels.first} 외 ${labels.length - 1}곳';
  }
}
