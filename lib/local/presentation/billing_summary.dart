import 'package:flutter/widgets.dart';
import '../app_services.dart';
import '../domain/billing_models.dart';
import 'billing.dart';
import 'common.dart';

class InvoiceSummary extends StatelessWidget {
  const InvoiceSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final workspace = AppScope.of(context).workspace;
    final invoices = workspace.invoices;
    final pendingReceipts = workspace
        .records('invoiceReceipts')
        .where((r) => r.s('status') == 'reported')
        .toList();
    final pendingReceiptAmount = pendingReceipts.fold<int>(
      0,
      (sum, receipt) => sum + receipt.n('amount'),
    );
    final inquiries = invoices.fold<int>(
      0,
      (sum, i) => sum + i.inquiryOpenCount,
    );
    final overdue = invoices
        .where((i) => i.status != 'draft' && i.isOverdue)
        .length;
    return FigmaSurface(
      children: [
        const Section('청구·회수 현황'),
        const Info('전체 기간 기준'),
        for (final status in invoiceStatuses)
          Builder(
            builder: (context) {
              final rows = invoices
                  .where(
                    (i) =>
                        i.status == status &&
                        (status == 'draft' || i.adjustedTotalAmount > 0),
                  )
                  .toList();
              final amount = rows.fold<int>(
                0,
                (sum, row) =>
                    sum +
                    (status == 'draft'
                        ? row.adjustedTotalAmount
                        : row.remainingDueAmount),
              );
              final collected = rows.fold<int>(
                0,
                (sum, row) => sum + row.confirmedReceiptAmount,
              );
              final missing = rows.fold<int>(
                0,
                (sum, row) => sum + row.missingAmountCount,
              );
              return Item(
                '${invoiceStatusLabel(status)} ${rows.length}건',
                subtitle: status == 'draft'
                    ? '잠정 ${billingMoney(amount)}${missing > 0 ? ' · 금액 확인 필요 $missing건' : ''}'
                    : status == 'sent'
                    ? '남은 회수액 ${billingMoney(amount)}'
                    : '회수 ${billingMoney(collected)} · 잔액 ${billingMoney(amount)}',
                onTap: () =>
                    openPage(context, InvoiceListPage(initialStatus: status)),
              );
            },
          ),
        if (pendingReceipts.isNotEmpty)
          Info(
            '입금 확인 필요 ${pendingReceipts.length}건 · ${billingMoney(pendingReceiptAmount)}',
          ),
        if (inquiries > 0) Info('금액 문의 중 $inquiries건'),
        if (overdue > 0) Info('기한 지남 $overdue건', error: true),
        if (invoices.any((i) => i.refundRequiredAmount > 0))
          const Info('환급이 필요한 청구가 있어요.', error: true),
        ActionButton(
          '청구 내역 모두 보기',
          weak: true,
          onPressed: () => openPage(context, const InvoiceListPage()),
        ),
      ],
    );
  }
}
