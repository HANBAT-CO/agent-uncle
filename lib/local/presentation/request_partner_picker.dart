import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'profile_avatar.dart';

/// 가입 역할 카드와 같은 표면·선택 강조를 사용하는 담당자 카드.
class RequestPartnerCard extends StatelessWidget {
  const RequestPartnerCard({
    required this.account,
    this.selected = false,
    this.onPressed,
    super.key,
  });

  final Account account;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final working = account.b('working');
    return FigmaSurface(
      tinted: selected,
      children: [
        Semantics(
          selected: selected,
          child: TdsListRow(
            verticalPadding: TdsListRowVerticalPadding.large,
            left: ProfileAvatar(account, size: 64),
            leftAlignment: TdsListRowAlignment.top,
            onPressed: onPressed,
            contents: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TdsText(
                  account.name,
                  typography: TdsTypography.t5,
                  fontWeight: TdsFontWeight.semibold,
                  color: selected ? theme.color('blue600') : null,
                ),
                const TdsSpacing(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TdsBadge(
                      size: TdsBadgeSize.small,
                      variant: TdsBadgeVariant.weak,
                      color: working
                          ? TdsBadgeColor.blue
                          : TdsBadgeColor.elephant,
                      child: Text(working ? '업무 중' : '휴무 중'),
                    ),
                    if (selected)
                      const TdsBadge(
                        size: TdsBadgeSize.small,
                        variant: TdsBadgeVariant.weak,
                        color: TdsBadgeColor.blue,
                        child: Text('선택됨'),
                      ),
                  ],
                ),
                const TdsSpacing(12),
                for (final entry in const {
                  'pickupArea': '픽업',
                  'deliveryArea': '배송',
                  'deadline': '요청 마감',
                }.entries)
                  TdsText(
                    '${entry.value}  ${account.s(entry.key).trim().isEmpty ? '등록 전' : account.s(entry.key).trim()}',
                    typography: TdsTypography.t7,
                    color: theme.color('grey600'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RequestPartnerPicker extends StatefulWidget {
  const RequestPartnerPicker({required this.selectedId, super.key});
  final String selectedId;

  @override
  State<RequestPartnerPicker> createState() => _RequestPartnerPickerState();
}

class _RequestPartnerPickerState extends State<RequestPartnerPicker> {
  late String selectedId = widget.selectedId;

  @override
  Widget build(BuildContext context) {
    final partners = AppScope.of(context).workspace.partners;
    final hasSelection = partners.any((a) => a.id == selectedId);
    return PageFrame(
      title: '사입삼촌 선택',
      showHeaderDivider: false,
      bottom: partners.isEmpty
          ? null
          : ActionButton(
              '선택한 삼촌으로 계속',
              bottom: true,
              enabled: hasSelection,
              onPressed: () => Navigator.pop(context, selectedId),
            ),
      children: [
        if (partners.isEmpty)
          const EmptyState('연결된 사입삼촌이 없어요', '초안 작성 후 사입삼촌 탭에서 연결해 주세요.')
        else ...[
          const PageHeading(
            '어느 삼촌에게\n부탁할까요?',
            description: '사입 지역과 마감시간을 확인하고 선택해 주세요.',
          ),
          for (final account in partners)
            RequestPartnerCard(
              account: account,
              selected: account.id == selectedId,
              onPressed: () => setState(() => selectedId = account.id),
            ),
        ],
      ],
    );
  }
}
