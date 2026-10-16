import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/convenience_models.dart';
import '../domain/models.dart';
import 'common.dart';

String _favoriteSelectionKey(Data row) =>
    '${textOf(row, 'wholesaler').trim()}|${textOf(row, 'location').trim()}';

class FavoriteWholesalerPicker extends StatefulWidget {
  const FavoriteWholesalerPicker({required this.initialRows, super.key});

  final List<Data> initialRows;

  @override
  State<FavoriteWholesalerPicker> createState() =>
      _FavoriteWholesalerPickerState();
}

class _FavoriteWholesalerPickerState extends State<FavoriteWholesalerPicker> {
  late final Set<String> selectedKeys = {
    for (final row in widget.initialRows)
      if (hasConvenienceWholesalerValue(row)) _favoriteSelectionKey(row),
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final favorites = app.workspace.mergedFavoriteWholesalerRows();
    return PageFrame(
      title: '즐겨찾기 도매처',
      showHeaderDivider: false,
      bottom: favorites.isEmpty
          ? null
          : ActionButton(
              '선택한 도매처 추가',
              bottom: true,
              enabled: selectedKeys.isNotEmpty,
              onPressed: () => Navigator.pop(context, [
                for (final favorite in favorites)
                  if (selectedKeys.contains(_favoriteSelectionKey(favorite)))
                    sanitizeReusableWholesaler(favorite),
              ]),
            ),
      children: [
        if (favorites.isEmpty)
          const EmptyState(
            '저장한 도매처가 없어요',
            '요청서에서 도매처를 입력한 뒤 즐겨찾기로 저장해 두면 다음부터 여러 곳을 한 번에 불러올 수 있어요.',
            icon: 'store',
          )
        else ...[
          const PageHeading(
            '자주 가는 도매처를\n빠르게 불러와요',
            description: '여러 곳을 골라 한 번에 요청서에 추가할 수 있어요.',
          ),
          FigmaSurface(
            children: [
              for (final favorite in favorites)
                Inset(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: TdsCheckbox(
                    checked: selectedKeys.contains(
                      _favoriteSelectionKey(favorite),
                    ),
                    onChanged: (checked) {
                      final key = _favoriteSelectionKey(favorite);
                      setState(() {
                        if (checked) {
                          selectedKeys.add(key);
                        } else {
                          selectedKeys.remove(key);
                        }
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TdsText(
                          textOf(favorite, 'wholesaler').trim(),
                          typography: TdsTypography.t6,
                          fontWeight: TdsFontWeight.semibold,
                        ),
                        const TdsSpacing(4),
                        TdsText(
                          textOf(favorite, 'location').trim(),
                          typography: TdsTypography.t7,
                          color: TdsTheme.of(context).color('grey600'),
                        ),
                        const TdsSpacing(8),
                        TdsBadge(
                          size: TdsBadgeSize.small,
                          variant: TdsBadgeVariant.weak,
                          color: TdsBadgeColor.blue,
                          child: Text(
                            conveniencePaymentModeLabel(
                              textOf(favorite, 'paymentMode'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
