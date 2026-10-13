import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'retailer_orders.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({required this.onTab, super.key});

  final ValueChanged<int> onTab;

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final requests = app.workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data))
        .toList();

    Future<void> openOrders(RetailerOrderFilter filter) =>
        openPage(context, RetailerOrdersPage(initialFilter: filter));

    Widget statusRow(RetailerHomeStatus status) => TdsListRow(
      left: TdsText(
        status.label,
        typography: TdsTypography.t5,
        fontWeight: TdsFontWeight.semibold,
      ),
      contents: TdsText(
        '${retailerHomeCount(requests, status, now: now)}건',
        typography: TdsTypography.t4,
        fontWeight: TdsFontWeight.bold,
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
            onPressed: () => widget.onTab(AppTab.business.index),
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
            statusRow(RetailerHomeStatus.received),
          ],
        ),
        RetailerOrdersSection(
          showHeading: true,
          onCompletionBoundary: () => setState(() {}),
        ),
      ],
    );
  }
}
