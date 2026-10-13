import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets('삼촌 거래처 검색에서 미연결 소매업자를 찾아 요청하고 수락 후 상세를 연다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await fixture.store.write('', '', (state) {
        state.put('accounts', 'new-retailer', {
          'name': '대전 소매 매장',
          'nickname': '새봄상점',
          'role': 'retailer',
          'complete': true,
          'publicCode': '#4321',
        });
        return '';
      });
      await fixture.session.signIn(fixture.uncle);
    });
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          const PageFrame(
            title: '거래처',
            back: false,
            children: [ConnectionsList()],
          ),
        ),
      ),
    );
    await settle(tester);
    final directory = find.byKey(const ValueKey('uncle-partner-directory'));
    await tester.ensureVisible(directory);
    await tester.tap(directory);
    await settle(tester);
    expect(find.byType(AddConnectionPage), findsOneWidget);

    final search = find.descendant(
      of: find.byKey(const ValueKey('partner-search')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, '새봄상점');
    await settle(tester);
    final result = find.byKey(const ValueKey('partner-new-retailer'));
    expect(result, findsOneWidget);
    expect(find.byKey(ValueKey('partner-${fixture.retailer}')), findsNothing);
    expect(
      find.descendant(of: result, matching: find.text('새봄상점')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.widgetWithText(TdsButton, '거래 요청 보내기'));
    await tester.tap(find.widgetWithText(TdsButton, '거래 요청 보내기'));
    await settle(tester);
    final connection = fixture.workspace
        .records('connections')
        .singleWhere((record) => record.s('to') == 'new-retailer');
    expect(connection.s('from'), fixture.uncle);
    expect(connection.s('status'), 'pending');
    expect(find.text('수락 대기 중'), findsOneWidget);

    await tester.runAsync(() async {
      await fixture.session.signIn('new-retailer');
      await fixture.workspace.respondConnection(
        connection.id,
        'accepted',
        connection.version,
        newId(),
      );
      await fixture.session.signIn(fixture.uncle);
    });
    await settle(tester);
    await tester.ensureVisible(find.widgetWithText(TdsButton, '연결된 거래처 보기'));
    await tester.tap(find.widgetWithText(TdsButton, '연결된 거래처 보기'));
    await settle(tester);
    expect(find.byType(PartnerPage), findsOneWidget);
    expect(
      fixture.workspace.partners.map((account) => account.id),
      contains('new-retailer'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
