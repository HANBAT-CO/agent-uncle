import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show settle, drainClose;
import 'workspace_test.dart' show Fixture;

void main() {
  for (final role in AppRole.values) {
    testWidgets(
      'home is the third tab for $role and actions reach the right tab',
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
        expect(bar.items[2].label, '홈');
        expect(bar.selectedIndex, 2);
        final home = tester.getCenter(find.widgetWithText(TdsTextButton, '홈'));
        final business = tester.getCenter(
          find.widgetWithText(TdsTextButton, role.tabs[0]),
        );
        final chat = tester.getCenter(find.widgetWithText(TdsTextButton, '채팅'));
        expect(business.dx, lessThan(chat.dx));
        expect(chat.dx, lessThan(home.dx));
        await tester.ensureVisible(find.text('사입 내역 전체 보기'));
        await settle(tester);
        await tester.tap(find.text('사입 내역 전체 보기'));
        await settle(tester);
        expect(
          tester
              .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
              .selectedIndex,
          0,
        );
        expect(find.byType(BusinessList), findsOneWidget);
        await tester.tap(find.widgetWithText(TdsTextButton, '채팅'));
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
    expect(await bar.onSelected(0), isFalse);
    await settle(tester);
    expect(
      tester
          .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
          .selectedIndex,
      2,
    );
    guard.save = null;
    expect(await bar.onSelected(0), isTrue);
    await settle(tester);
    expect(find.byType(BusinessList), findsOneWidget);
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
