import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/retailer_orders.dart';
import 'package:agent_uncle/local/presentation/retailer_purchase.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:agent_uncle/local/presentation/uncle_home.dart';
import 'package:agent_uncle/local/presentation/uncle_orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show settle, drainClose;
import 'workspace_test.dart' show Fixture;

void main() {
  for (final role in AppRole.values) {
    testWidgets(
      'role-specific tab order for $role keeps home and purchase destinations',
      (tester) async {
        final f = Fixture();
        await tester.runAsync(() async {
          await f.start();
          await f.session.signIn(
            role == AppRole.retailer ? f.retailer : f.uncle,
          );
          await f.session.finishOnboarding();
        });
        final app = AppServices(
          session: f.session,
          workspace: f.workspace,
          attachments: f.attachments,
        );
        await tester.pumpWidget(AgentUncleApp(services: app));
        await settle(tester);
        final bar = tester.widget<TdsLiquidTabBar>(
          find.byType(TdsLiquidTabBar),
        );
        expect(bar.items.map((i) => i.label), role.tabs);
        final homeIndex = role.tabOrder.indexOf(AppTab.home);
        expect(bar.items[homeIndex].label, '홈');
        expect(bar.selectedIndex, homeIndex);
        final home = tester.getCenter(find.widgetWithText(TdsTextButton, '홈'));
        final business = tester.getCenter(
          find.widgetWithText(TdsTextButton, role.tabLabel(AppTab.business)),
        );
        final chat = tester.getCenter(
          find.widgetWithText(TdsTextButton, role.tabLabel(AppTab.chat)),
        );
        expect(business.dx, lessThan(chat.dx));
        expect(home.dx, lessThan(business.dx));
        if (role == AppRole.retailer) {
          expect(home.dx, lessThan(business.dx));
          expect(bar.items.map((i) => i.label), [
            '홈',
            '사입하기',
            '채팅',
            '사입삼촌',
            '내 프로필',
          ]);
        } else {
          expect(bar.items.map((i) => i.label), [
            '홈',
            '업무',
            '대화',
            '연결',
            '내 정보',
          ]);
        }
        if (role == AppRole.retailer) {
          expect(find.byType(RetailerOrdersSection), findsOneWidget);
          final waiting = find.widgetWithText(TdsListRow, '대기');
          await tester.ensureVisible(waiting);
          await tester.tap(waiting);
          await settle(tester);
          expect(find.byType(TdsLiquidTabBar), findsOneWidget);
          expect(find.text('사입 내역'), findsOneWidget);
          expect(find.byType(TdsTopNavigationBackButton), findsNothing);
          expect(
            tester
                .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
                .selectedIndex,
            homeIndex,
          );
          await tester.ensureVisible(find.text('주문 넣기'));
          await tester.tap(find.text('주문 넣기'));
          await settle(tester);
          expect(find.byType(RetailerPurchaseTab), findsOneWidget);
        } else {
          final waiting = find.byKey(const ValueKey('uncle-status-incoming'));
          await tester.ensureVisible(waiting);
          await tester.tap(waiting);
          await settle(tester);
          expect(find.byType(TdsLiquidTabBar), findsOneWidget);
          expect(find.byType(UncleOrdersSection), findsOneWidget);
          expect(find.byType(TdsTopNavigationBackButton), findsNothing);
          expect(
            tester
                .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
                .selectedIndex,
            homeIndex,
          );
          await tester.ensureVisible(find.text('업무 시작하기'));
          await tester.tap(find.text('업무 시작하기'));
          await settle(tester);
          expect(find.byType(UncleWorkTab), findsOneWidget);
          expect(find.text('내 업무 현황'), findsNothing);
          expect(find.text('업무 내역 전체 보기'), findsNothing);
          await tester.tap(find.text('사입 업무 시작하기'));
          await settle(tester);
          expect(find.byType(UncleOrdersSection), findsOneWidget);
          expect(find.text('사입 내역').hitTestable(), findsOneWidget);
          expect(find.byType(TdsTopNavigationBackButton), findsNothing);
          expect(
            tester
                .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
                .selectedIndex,
            homeIndex,
          );
        }
        await tester.tap(
          find.widgetWithText(TdsTextButton, role.tabLabel(AppTab.chat)),
        );
        await settle(tester);
        expect(find.byType(ChatList), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
        await drainClose(tester, f.store.close());
      },
    );
  }

  testWidgets('failed draft guard rejects native and fallback tab changes', (
    tester,
  ) async {
    final f = Fixture();
    await tester.runAsync(() async {
      await f.start();
      await f.session.finishOnboarding();
    });
    final app = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    final guard = TabSaveScope.of(tester.element(find.byType(Dashboard)))!;
    guard.save = () async => throw StateError('save failed');
    final bar = tester.widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar));
    expect(await bar.onSelected(1), isFalse);
    await settle(tester);
    expect(
      tester
          .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
          .selectedIndex,
      0,
    );
    guard.save = null;
    expect(await bar.onSelected(1), isTrue);
    await settle(tester);
    expect(find.byType(RetailerPurchaseTab), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await drainClose(tester, f.store.close());
  });

  testWidgets('notification bell opens notices and dot follows unread state', (
    tester,
  ) async {
    final f = Fixture();
    await tester.runAsync(() async {
      await f.start();
      await f.session.finishOnboarding();
    });
    final app = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: app));
    await settle(tester);
    final bell = find.byType(TdsGlassIconButton);
    expect(tester.widget<TdsGlassIconButton>(bell).unreadCount, greaterThan(0));
    await tester.tap(
      find.descendant(of: bell, matching: find.byType(TdsIconButton)),
    );
    await settle(tester);
    expect(find.byType(NoticesPage), findsOneWidget);
    expect(find.byType(TdsLiquidTabBar), findsNothing);
    final firstNotice = f.workspace.records('notices').first;
    await tester.tap(
      find.text(
        '안 읽음 ${f.workspace.records('notices').where((n) => !n.b('read')).length}',
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('notice-${firstNotice.id}')));
    await settle(tester);
    expect(find.text('거래처 연결'), findsOneWidget);
    expect(
      f.workspace
          .records('notices')
          .firstWhere((n) => n.id == firstNotice.id)
          .b('read'),
      isTrue,
    );
    expect(f.session.pendingDestination, isNull);
    await tester.tap(find.byType(TdsTopNavigationBackButton).hitTestable());
    await settle(tester);
    expect(find.text('모든 알림을 확인했어요'), findsOneWidget);
    expect(find.byKey(ValueKey('notice-${firstNotice.id}')), findsNothing);
    await tester.tap(find.text('전체 알림 보기'));
    await settle(tester);
    expect(find.byKey(ValueKey('notice-${firstNotice.id}')), findsOneWidget);
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(tester.widget<TdsGlassIconButton>(bell).unreadCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await drainClose(tester, f.store.close());
  });
}
