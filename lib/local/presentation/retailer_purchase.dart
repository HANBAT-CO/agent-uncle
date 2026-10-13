import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'common.dart';
import 'requests.dart';

class RetailerPurchaseTab extends StatelessWidget {
  const RetailerPurchaseTab({super.key});

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
        '필요한 상품을\n삼촌에게 부탁해요',
      ),
      const TdsSpacing(16),
      ActionButton(
        '삼촌한테 사입하기',
        onPressed: () => openPage(context, const RequestEditor()),
      ),
      const TdsSpacing(32),
    ],
  );
}
