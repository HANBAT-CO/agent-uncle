import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'billing.dart';
import 'pickup_progress.dart';
import 'workflow_sync.dart';
import 'update_notice.dart';
import 'retailer_orders.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({required this.onTab, super.key});

  final ValueChanged<int> onTab;

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  final _ordersKey = GlobalKey<RetailerOrdersSectionState>();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final requests = app.workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data))
        .toList();

    void showOrders(RetailerOrderFilter filter) =>
        _ordersKey.currentState?.showFilter(filter);

    Widget statusRow(RetailerHomeStatus status) => TdsListRow(
      semanticLabel: status.label,
      verticalPadding: TdsListRowVerticalPadding.small,
      a11yLeftAlignment: TdsListRowAlignment.center,
      left: OrderStatusChipTheme(
        badgeColor: status.badgeColor,
        child: TdsChip(
          kind: TdsChipKind.action,
          margin: TdsChipMargin.none,
          children: [TdsChipItem(text: status.label, inert: true)],
        ),
      ),
      contents: TdsText(
        '${retailerHomeCount(requests, status, now: now)}건',
        typography: TdsTypography.t4,
        fontWeight: TdsFontWeight.bold,
      ),
      onPressed: () => showOrders(status.filter),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Inset(
          child: TdsButton(
            display: TdsButtonDisplay.block,
            onPressed: () => widget.onTab(AppTab.business.index),
            child: const Text('주문 넣기'),
          ),
        ),
        FigmaSurface(
          margin: 12,
          padding: const EdgeInsets.symmetric(vertical: 8),
          style: FigmaSurfaceStyle.glass,
          grouped: true,
          children: [
            TdsListRow(
              verticalPadding: TdsListRowVerticalPadding.small,
              contents: Semantics(
                header: true,
                child: TdsText(
                  '내 사입 현황',
                  typography: TdsTypography.t4,
                  fontWeight: TdsFontWeight.bold,
                ),
              ),
            ),
            statusRow(RetailerHomeStatus.pendingConfirmation),
            statusRow(RetailerHomeStatus.inProgress),
            statusRow(RetailerHomeStatus.received),
            statusRow(RetailerHomeStatus.completed),
          ],
        ),
        RetailerOrdersSection(key: _ordersKey),
        const RetailerPickupSummary(),
        ActionButton(
          '받은 청구서',
          weak: true,
          onPressed: () => openPage(context, const InvoiceListPage()),
        ),
        const WorkflowSyncNotice(),
        const UpdateNotice(),
      ],
    );
  }
}
