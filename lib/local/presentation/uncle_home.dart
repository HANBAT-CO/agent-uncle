import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'billing_summary.dart';
import 'team_work.dart';
import 'workflow_sync.dart';
import 'update_notice.dart';
import 'uncle_orders.dart';

class UncleDashboard extends StatefulWidget {
  const UncleDashboard({required this.onTab, this.ordersKey, super.key});
  final ValueChanged<int> onTab;
  final GlobalKey<UncleOrdersSectionState>? ordersKey;

  @override
  State<UncleDashboard> createState() => _UncleDashboardState();
}

class _UncleDashboardState extends State<UncleDashboard> {
  final _ordersKey = GlobalKey<UncleOrdersSectionState>();
  GlobalKey<UncleOrdersSectionState> get ordersKey =>
      widget.ordersKey ?? _ordersKey;

  @override
  Widget build(BuildContext context) {
    final requests = AppScope.of(context).workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data))
        .toList();
    void showOrders(UncleOrderFilter filter) =>
        ordersKey.currentState?.showFilter(filter);
    Widget statusRow(
      UncleOrderFilter filter, {
      String? label,
      TdsBadgeColor? badgeColor,
    }) {
      final rows = filterUncleOrders(requests, filter);
      final count = filter == UncleOrderFilter.awaitingDelivery
          ? '${rows.fold<int>(0, (sum, request) => sum + request.available)}장'
          : '${rows.length}건';
      return TdsListRow(
        key: ValueKey('uncle-status-${filter.name}'),
        semanticLabel: label ?? filter.label,
        left: badgeColor == null
            ? TdsBadge(
                size: TdsBadgeSize.xsmall,
                color: filter.color,
                variant: TdsBadgeVariant.weak,
                child: Text(filter.label),
              )
            : OrderStatusChipTheme(
                badgeColor: badgeColor,
                child: TdsChip(
                  kind: TdsChipKind.action,
                  margin: TdsChipMargin.none,
                  children: [TdsChipItem(text: label!, inert: true)],
                ),
              ),
        contents: TdsText(
          count,
          typography: TdsTypography.t4,
          fontWeight: TdsFontWeight.bold,
        ),
        onPressed: () => showOrders(filter),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionButton(
          '업무 시작하기',
          onPressed: () => widget.onTab(AppTab.business.index),
        ),
        FigmaSurface(
          margin: 12,
          style: FigmaSurfaceStyle.glass,
          grouped: true,
          children: [
            TdsListRow(
              contents: Semantics(
                header: true,
                child: const TdsText(
                  '내 업무 현황',
                  typography: TdsTypography.t4,
                  fontWeight: TdsFontWeight.bold,
                ),
              ),
            ),
            statusRow(
              UncleOrderFilter.incoming,
              label: '사입 요청',
              badgeColor: TdsBadgeColor.yellow,
            ),
            statusRow(
              UncleOrderFilter.inProgress,
              label: '사입 중',
              badgeColor: TdsBadgeColor.green,
            ),
            statusRow(
              UncleOrderFilter.received,
              label: '완료(입금 전)',
              badgeColor: TdsBadgeColor.elephant,
            ),
            statusRow(UncleOrderFilter.completed),
            const TdsBorder(),
            statusRow(UncleOrderFilter.awaitingReply),
            statusRow(UncleOrderFilter.awaitingDelivery),
            statusRow(UncleOrderFilter.recheck),
            if (filterUncleOrders(requests, UncleOrderFilter.issues).isNotEmpty)
              statusRow(UncleOrderFilter.issues),
          ],
        ),
        UncleOrdersSection(key: ordersKey),
        const InvoiceSummary(),
        ActionButton(
          '팀 픽업·인계 업무',
          weak: true,
          onPressed: () => openPage(context, const TeamWorkPage()),
        ),
        const WorkflowSyncNotice(),
        const UpdateNotice(),
      ],
    );
  }
}

class UncleWorkTab extends StatelessWidget {
  const UncleWorkTab({required this.onOpenOrders, super.key});
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const TdsSpacing(56),
      const Inset(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FigmaIcon('bag', selected: true, size: 44),
        ),
      ),
      const PageHeading('오늘의 사입을\n차근차근 시작해요'),
      const TdsSpacing(16),
      ActionButton('사입 업무 시작하기', onPressed: onOpenOrders),
      ActionButton(
        '팀 픽업·인계 업무',
        weak: true,
        onPressed: () => openPage(context, const TeamWorkPage()),
      ),
      const InvoiceSummary(),
      const WorkflowSyncNotice(),
      const TdsSpacing(32),
    ],
  );
}
