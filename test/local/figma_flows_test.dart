import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'workspace_test.dart' show Fixture;
import 'app_flow_test.dart' show settle, tapButton, enter, drainClose;

void main() {
  testWidgets(
    'additional acquisition survives a failed save without adding twice',
    (tester) async {
      final f = Fixture();
      late String id;
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        id = await f.request();
        await f.accept(id);
        await f.result(id, 2, 1);
        await f.deliver(id, 1);
      });
      final services = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(AgentUncleApp(services: services));
      await settle(tester);
      unawaited(
        openPage(
          tester.element(find.byType(HomeTabPage).first),
          RequestActionPage(id, 'result'),
        ),
      );
      await settle(tester);
      final spinner = tester.widget<TdsNumericSpinner>(
        find.byType(TdsNumericSpinner),
      );
      expect(spinner.minNumber, 0);
      expect(spinner.maxNumber, 1);
      expect(spinner.number, 0);
      await tester.tap(find.bySemanticsLabel('더하기'));
      await settle(tester);
      expect(find.text('추가 확보 1장 공유'), findsOneWidget);
      f.store.failNextWrite = true;
      await tapButton(tester, '추가 확보 1장 공유');
      expect(f.workspace.request(id)!.acquired, 2);
      expect(
        tester.widget<TdsNumericSpinner>(find.byType(TdsNumericSpinner)).number,
        1,
      );
      await tapButton(tester, '추가 확보 1장 공유');
      expect(f.workspace.request(id)!.acquired, 3);
      expect(f.workspace.request(id)!.available, 2);
      expect(f.workspace.request(id)!.backorder, 0);
      expect(f.workspace.records('deliveries').single.n('quantity'), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );

  testWidgets(
    'receipt labels completion only for the last batch and retains discrepancy flow',
    (tester) async {
      final f = Fixture();
      late String id, first, last;
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        id = await f.request();
        await f.accept(id);
        await f.result(id, 3, 0);
        first = await f.deliver(id, 1);
        last = await f.deliver(id, 2);
        await f.session.signIn(f.retailer);
      });
      await tester.pumpWidget(
        AgentUncleApp(
          services: AppServices(
            session: f.session,
            workspace: f.workspace,
            attachments: f.attachments,
          ),
        ),
      );
      await settle(tester);
      unawaited(
        openPage(
          tester.element(find.byType(HomeTabPage).first),
          RequestActionPage(id, 'receive', deliveryId: first),
        ),
      );
      await settle(tester);
      expect(find.text('1장 수령 확인'), findsOneWidget);
      expect(find.textContaining('· 요청 완료'), findsNothing);
      await tapButton(tester, '1장 수령 확인');
      unawaited(
        openPage(
          tester.element(find.byType(HomeTabPage).first),
          RequestActionPage(id, 'receive', deliveryId: last),
        ),
      );
      await settle(tester);
      expect(find.text('2장 수령 확인'), findsOneWidget);
      await tester.ensureVisible(find.text('상품이나 수량이 달라요'));
      await tester.tap(find.text('상품이나 수량이 달라요'));
      await settle(tester);
      await enter(tester, '실제 받은 수량', '1');
      await enter(tester, '수량 차이 설명 (일치하면 선택)', '한 장이 부족해요');
      expect(find.textContaining('· 요청 완료'), findsNothing);
      await tapButton(tester, '1장 수령 확인');
      expect(f.workspace.request(id)!.received, 2);
      expect(f.workspace.request(id)!.ended, false);
      expect(f.workspace.records('issues').single.s('reason'), '한 장이 부족해요');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('core screens fit width $width at text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final f = Fixture();
        late String id, delivery;
        await tester.runAsync(() async {
          await f.start();
          await f.session.finishOnboarding();
          id = await f.request();
          final draft = f.workspace.request(id)!;
          await f.workspace.updateRequest(
            id,
            {
              ...draft.data,
              'product': '아주 긴 상품명을 가진 프리미엄 코튼 오버핏 스트라이프 셔츠',
              'option': '아이보리와 짙은 남색 스트라이프 · 프리 사이즈',
            },
            draft.version,
            'responsive-request',
          );
          await f.accept(id);
          await f.result(id, 2, 1);
          delivery = await f.deliver(id, 1);
          await f.session.signIn(f.retailer);
          await f.session.saveProfile({'name': '아주 긴 이름을 가진 소매 매장과 온라인 쇼핑몰'});
        });
        await tester.pumpWidget(
          AgentUncleApp(
            services: AppServices(
              session: f.session,
              workspace: f.workspace,
              attachments: f.attachments,
            ),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        for (final page in [
          RequestDetailPage(id),
          RequestActionPage(id, 'receive', deliveryId: delivery),
          ChatPage(f.uncle, requestId: id),
        ]) {
          unawaited(
            openPage(tester.element(find.byType(HomeTabPage).first), page),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          if (page is ChatPage) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await settle(tester);
            expect(
              tester.getBottomRight(find.bySemanticsLabel('메시지 전송')).dy,
              lessThanOrEqualTo(544),
            );
            expect(tester.takeException(), isNull);
            tester.view.resetViewInsets();
            await settle(tester);
          }
          await tester.tap(find.byType(TdsTopNavigationBackButton));
          await settle(tester);
        }
        final switching = f.session.signIn(f.uncle);
        await settle(tester);
        await switching;
        await settle(tester);
        unawaited(
          openPage(
            tester.element(find.byType(HomeTabPage).first),
            RequestActionPage(id, 'result'),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await drainClose(tester, f.close());
      });
    }
  }
}
