import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'retailer_orders.dart';

class RetailerDashboard extends StatelessWidget {
  const RetailerDashboard({required this.onTab, super.key});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final requests = app.workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data))
        .toList();
    final available = requests
        .where(retailerIsAwaitingDelivery)
        .fold<int>(0, (total, request) => total + request.available);

    Future<void> openOrders(RetailerOrderFilter filter) =>
        openPage(context, RetailerOrdersPage(initialFilter: filter));

    Widget statusRow(RetailerHomeStatus status) => TdsListRow(
      left: TdsBadge(
        size: TdsBadgeSize.xsmall,
        color: status.chipColor,
        variant: TdsBadgeVariant.weak,
        child: Text(status.chipText),
      ),
      contents: TdsListRowTexts(
        type: TdsListRowTextType.row2TypeA,
        top: Text(
          status == RetailerHomeStatus.awaitingDelivery
              ? '$available장'
              : '${retailerHomeCount(requests, status)}건',
        ),
        bottom: Text(status.label),
      ),
      right: TdsTextButton(
        size: TdsTextButtonSize.small,
        onPressed: () => openOrders(status.filter),
        child: const Text('보기'),
      ),
      onPressed: () => openOrders(status.filter),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Inset(
          child: TdsButton(
            display: TdsButtonDisplay.block,
            onPressed: () => onTab(AppTab.business.index),
            child: const Text('주문 넣기'),
          ),
        ),
        FigmaSurface(
          margin: 12,
          style: FigmaSurfaceStyle.glass,
          grouped: true,
          children: [
            TdsListRow(
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
            statusRow(RetailerHomeStatus.awaitingDelivery),
            statusRow(RetailerHomeStatus.awaitingReceipt),
            const TdsBorder(),
            Item(
              '사입 내역 전체 보기',
              onTap: () => openOrders(RetailerOrderFilter.all),
            ),
          ],
        ),
      ],
    );
  }
}
