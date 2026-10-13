import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Paperlogy')
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-5Medium.ttf'));
    await font.load();
  });

  for (final role in AppRole.values) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [100.0, 180.0]) {
        testWidgets('홈 알림 유지·나머지 탭 헤더 축소: $role / ${width.toInt()} / $scale%', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          tester.view.viewPadding = const FakeViewPadding(bottom: 34);
          tester.view.padding = const FakeViewPadding(bottom: 34);
          addTearDown(tester.view.reset);
          final f = Fixture();
          await tester.runAsync(() async {
            await f.start();
            await f.session.signIn(
              role == AppRole.retailer ? f.retailer : f.uncle,
            );
            await f.session.finishOnboarding();
          });
          final services = AppServices(
            session: f.session,
            workspace: f.workspace,
            attachments: f.attachments,
          );
          await tester.pumpWidget(
            AppScope(
              services: services,
              child: branded(const HomeShell(), scale: scale),
            ),
          );
          await settle(tester);

          final homeHeader = tester.getRect(
            find.byKey(const ValueKey('page-header')),
          );
          final homeBell = tester.getRect(find.byType(TdsGlassIconButton));
          Rect? compactHeader;
          for (final label in role.tabs) {
            await tester.tap(find.widgetWithText(TdsTextButton, label));
            await settle(tester);
            final currentHeader = tester.getRect(
              find.byKey(const ValueKey('page-header')),
            );
            final titleRect = tester.getRect(
              find.byKey(const ValueKey('page-title')),
            );
            final titleText = tester.widget<TdsText>(
              find.descendant(
                of: find.byKey(const ValueKey('page-title')),
                matching: find.byType(TdsText),
              ),
            );
            expect(titleText.ellipsisAfterLines, 1);
            expect(titleRect.left, greaterThanOrEqualTo(currentHeader.left));
            if (label == '홈') {
              expect(find.byType(TdsGlassIconButton), findsOneWidget);
              expect(tester.getRect(find.byType(TdsGlassIconButton)), homeBell);
              expect(currentHeader, homeHeader);
              expect(titleRect.right, lessThanOrEqualTo(homeBell.left));
            } else {
              expect(find.byType(TdsGlassIconButton), findsNothing);
              expect(titleRect.right, lessThanOrEqualTo(currentHeader.right));
              expect(currentHeader.height, lessThan(homeHeader.height));
              compactHeader ??= currentHeader;
              expect(currentHeader, compactHeader);
            }
            expect(tester.takeException(), isNull);
          }

          await tester.pumpWidget(const SizedBox());
          services.dispose();
          await drainClose(tester, f.store.close());
        });
      }
    }
  }

  for (final role in AppRole.values) {
    testWidgets('상세 진입 후 복귀해도 탭 바 상태 유지: $role', (tester) async {
      final f = Fixture();
      await tester.runAsync(() async {
        await f.start();
        await f.session.signIn(role == AppRole.retailer ? f.retailer : f.uncle);
        await f.session.finishOnboarding();
      });
      final services = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(
        AppScope(services: services, child: branded(const HomeShell())),
      );
      await settle(tester);

      final visibleBar = find.byType(TdsLiquidTabBar);
      final retainedBar = find.byType(TdsLiquidTabBar, skipOffstage: false);
      final initialSelected = tester
          .widget<TdsLiquidTabBar>(visibleBar)
          .selectedIndex;
      final originalElement = tester.element(retainedBar);
      final bell = find.byType(TdsGlassIconButton);

      await tester.tap(
        find.descendant(of: bell, matching: find.byType(TdsIconButton)),
      );
      await settle(tester);
      expect(find.byType(NoticesPage), findsOneWidget);
      expect(visibleBar, findsNothing);
      expect(retainedBar, findsOneWidget);
      expect(identical(tester.element(retainedBar), originalElement), isTrue);
      expect(retainedBar.hitTestable(), findsNothing);
      expect(TickerMode.valuesOf(tester.element(retainedBar)).enabled, isFalse);
      expect(
        Focus.of(tester.element(retainedBar)).descendantsAreFocusable,
        isFalse,
      );

      await tester.tap(find.byType(TdsTopNavigationBackButton));
      await settle(tester);
      expect(visibleBar, findsOneWidget);
      expect(identical(tester.element(retainedBar), originalElement), isTrue);
      expect(TickerMode.valuesOf(tester.element(retainedBar)).enabled, isTrue);
      expect(
        Focus.of(tester.element(retainedBar)).descendantsAreFocusable,
        isTrue,
      );
      expect(
        tester.widget<TdsLiquidTabBar>(visibleBar).selectedIndex,
        initialSelected,
      );

      final guard = TabSaveScope.of(tester.element(find.byType(Dashboard)))!;
      guard.save = () async => throw StateError('save failed');
      final bar = tester.widget<TdsLiquidTabBar>(visibleBar);
      final nextIndex = (bar.selectedIndex + 1) % bar.items.length;
      expect(await bar.onSelected(nextIndex), isFalse);
      await settle(tester);
      expect(
        tester.widget<TdsLiquidTabBar>(visibleBar).selectedIndex,
        initialSelected,
      );
      expect(find.byType(Dashboard), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, f.store.close());
    });
  }
}
