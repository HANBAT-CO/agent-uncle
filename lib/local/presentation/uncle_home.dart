import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'uncle_orders.dart';

class UncleDashboard extends StatelessWidget {
  const UncleDashboard({required this.onTab, super.key});
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final requests = AppScope.of(context).workspace
        .records('requests')
        .map((record) => RequestRecord(record.id, record.data))
        .toList();
    Future<void> openOrders(UncleOrderFilter filter) =>
        openPage(context, UncleOrdersPage(initialFilter: filter));
    Widget statusRow(UncleOrderFilter filter) {
      final rows = filterUncleOrders(requests, filter);
      final count = filter == UncleOrderFilter.awaitingDelivery
          ? '${rows.fold<int>(0, (sum, request) => sum + request.available)}장'
          : '${rows.length}건';
      return TdsListRow(
        key: ValueKey('uncle-status-${filter.name}'),
        left: TdsBadge(
          size: TdsBadgeSize.xsmall,
          color: filter.color,
          variant: TdsBadgeVariant.weak,
          child: Text(filter.label),
        ),
        contents: TdsListRowTexts(
          type: TdsListRowTextType.row2TypeA,
          top: Text(count),
          bottom: Text(filter.homeLabel),
        ),
        right: TdsTextButton(
          size: TdsTextButtonSize.small,
          onPressed: () => openOrders(filter),
          child: const Text('보기'),
        ),
        onPressed: () => openOrders(filter),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionButton('업무 시작하기', onPressed: () => onTab(AppTab.business.index)),
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
            statusRow(UncleOrderFilter.awaitingReply),
            statusRow(UncleOrderFilter.incoming),
            statusRow(UncleOrderFilter.inProgress),
            statusRow(UncleOrderFilter.awaitingDelivery),
            statusRow(UncleOrderFilter.awaitingReceipt),
            statusRow(UncleOrderFilter.recheck),
            if (filterUncleOrders(requests, UncleOrderFilter.issues).isNotEmpty)
              statusRow(UncleOrderFilter.issues),
            const TdsBorder(),
            Item('업무 내역 전체 보기', onTap: () => openOrders(UncleOrderFilter.all)),
          ],
        ),
      ],
    );
  }
}

class UncleWorkTab extends StatelessWidget {
  const UncleWorkTab({super.key});

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
      const PageHeading(
        '오늘의 사입을\n차근차근 시작해요',
        description: '새 요청 확인부터 확보와 전달까지\n필요한 업무를 한곳에서 처리해요.',
      ),
      const TdsSpacing(16),
      ActionButton(
        '사입 업무 시작하기',
        onPressed: () => openPage(context, const UncleOrdersPage()),
      ),
      const TdsSpacing(32),
    ],
  );
}
