import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('badge content uses source 1.5em and fractional line boxes', (
    tester,
  ) async {
    for (final scale in [100.0, 160.0, 200.0]) {
      for (final size in TdsBadgeSize.values) {
        await tester.pumpWidget(
          testApp(
            Center(
              child: TdsBadge(
                size: size,
                color: TdsBadgeColor.blue,
                variant: TdsBadgeVariant.weak,
                child: const Text('새 소식'),
              ),
            ),
            scale: scale,
          ),
        );
        final type = {
          TdsBadgeSize.xsmall: TdsTypography.t5,
          TdsBadgeSize.small: TdsTypography.t3,
          TdsBadgeSize.medium: TdsTypography.t2,
          TdsBadgeSize.large: TdsTypography.t1,
        }[size]!;
        final theme = TdsTheme.of(tester.element(find.byType(TdsBadge)));
        final metrics = tdsBadgeMetrics[theme.platform.size(type).toInt()]!;
        expect(
          tester.getSize(find.byType(TdsBadge)).height,
          metrics.$1 * 1.5 + 2 * metrics.$2,
        );
      }
    }
  });
}
