import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/uncle_orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show settle, drainClose;
import 'brand_surfaces_test.dart' show branded;
import '../support/request_workflow.dart';
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets('삼촌 홈 수치와 보기가 같은 단계의 업무 내역으로 연결된다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final fixture = Fixture();
    final ids = <String, String>{};
    await tester.runAsync(() async {
      await fixture.start();
      for (final entry in {
        'pending': '새 셔츠',
        'sourcing': '진행 바지',
        'delivery': '전달 원피스',
        'receipt': '수령 재킷',
        'recheck': '재확인 신발',
        'completed': '완료 모자',
      }.entries) {
        ids[entry.key] = await createRetailerRequest(
          fixture,
          product: entry.value,
        );
      }
      for (final entry in ids.entries.where(
        (entry) => entry.key != 'pending',
      )) {
        await acceptRequest(fixture, entry.value);
      }
      await shareResult(fixture, ids['delivery']!, acquired: 2, backorder: 1);
      await shareResult(fixture, ids['receipt']!, acquired: 3, backorder: 0);
      await deliverRequest(fixture, ids['receipt']!, 2);
      await fixture.workspace.act(
        ids['recheck']!,
        'result',
        {
          'acquired': 1,
          'backorder': 2,
          'recheck': dateOnly(DateTime.now()),
          'reason': '오늘 다시 확인',
          'needsReply': false,
        },
        fixture.workspace.request(ids['recheck']!)!.version,
        newId(),
      );
      await shareResult(fixture, ids['completed']!, acquired: 3, backorder: 0);
      final delivery = await deliverRequest(fixture, ids['completed']!, 3);
      await receiveDelivery(fixture, delivery, 3);
      await fixture.session.signIn(fixture.uncle);
    });
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
    );
    final tabs = <int>[];
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          PageFrame(
            title: '홈',
            back: false,
            children: [BackdropGroup(child: Dashboard(onTab: tabs.add))],
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('업무 시작하기'));
    await settle(tester);
    expect(tabs, [AppTab.business.index]);
    tabs.clear();

    final cases = <UncleOrderFilter, (String, Set<String>)>{
      UncleOrderFilter.awaitingReply: ('1건', {'delivery'}),
      UncleOrderFilter.incoming: ('1건', {'pending'}),
      UncleOrderFilter.inProgress: ('3건', {'sourcing', 'delivery', 'recheck'}),
      UncleOrderFilter.awaitingDelivery: (
        '4장',
        {'delivery', 'receipt', 'recheck'},
      ),
      UncleOrderFilter.awaitingReceipt: ('1건', {'receipt'}),
      UncleOrderFilter.recheck: ('1건', {'recheck'}),
    };
    for (final entry in cases.entries) {
      final status = find.byKey(ValueKey('uncle-status-${entry.key.name}'));
      expect(
        find.descendant(of: status, matching: find.text(entry.value.$1)),
        findsOneWidget,
      );
      final view = find.descendant(
        of: status,
        matching: find.widgetWithText(TdsTextButton, '보기'),
      );
      await tester.ensureVisible(view);
      await tester.tap(view);
      await settle(tester);
      expect(find.byType(UncleOrdersPage), findsOneWidget);
      expect(
        tester
            .widget<UncleOrdersPage>(find.byType(UncleOrdersPage))
            .initialFilter,
        entry.key,
      );
      for (final order in ids.entries) {
        expect(
          find.byKey(ValueKey('uncle-order-${order.value}')),
          entry.value.$2.contains(order.key) ? findsOneWidget : findsNothing,
          reason: '${entry.key.name}: ${order.key}',
        );
      }
      expect(tabs, isEmpty);
      await tester.tap(find.byType(TdsTopNavigationBackButton));
      await settle(tester);
    }

    await tester.ensureVisible(find.text('업무 내역 전체 보기'));
    await tester.tap(find.text('업무 내역 전체 보기'));
    await settle(tester);
    expect(find.text('전체 내역 6건'), findsOneWidget);
    for (final id in ids.values) {
      expect(find.byKey(ValueKey('uncle-order-$id')), findsOneWidget);
    }
    expect(tabs, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
