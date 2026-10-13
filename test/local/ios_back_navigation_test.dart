import 'dart:async';

import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/core/navigation/app_page_route.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, enter, settle;
import 'workspace_test.dart' show Fixture;

// 저장 중/실패 상태에서도 초안을 유지하는지 확인하기 위한 지연 저장소.
class DelayedDraftWorkspace extends LocalWorkspaceRepository {
  DelayedDraftWorkspace(Fixture f) : super(f.store, f.session);
  Completer<void>? nextSave;
  Object? saveError;

  @override
  Future<String> saveDraft(String id, Data values) async {
    final wait = nextSave;
    nextSave = null;
    await wait?.future;
    if (saveError != null) throw saveError!;
    return super.saveDraft(id, values);
  }
}

Future<Fixture> startApp(
  WidgetTester tester, {
  AppRole role = AppRole.retailer,
  WorkspaceRepository Function(Fixture)? workspace,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final f = Fixture();
  await tester.runAsync(() async {
    await f.start();
    await f.session.signIn(role == AppRole.retailer ? f.retailer : f.uncle);
    await f.session.finishOnboarding();
  });
  final repository = workspace?.call(f) ?? f.workspace;
  final services = AppServices(
    session: f.session,
    workspace: repository,
    attachments: f.attachments,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    if (repository != f.workspace) f.workspace.dispose();
    await drainClose(tester, f.store.close());
  });
  await tester.pumpWidget(AgentUncleApp(services: services));
  await settle(tester);
  return f;
}

PageRoute<dynamic> routeOf(WidgetTester tester, Type page) =>
    ModalRoute.of(tester.element(find.byType(page)))! as PageRoute<dynamic>;

Future<TestGesture> startBackSwipe(WidgetTester tester, double distance) async {
  final gesture = await tester.startGesture(const Offset(1, 300));
  await gesture.moveBy(
    const Offset(24, 0),
    timeStamp: const Duration(milliseconds: 80),
  );
  await tester.pump();
  await gesture.moveBy(
    Offset(distance - 24, 0),
    timeStamp: const Duration(milliseconds: 500),
  );
  await tester.pump();
  return gesture;
}

Future<void> finishSwipe(WidgetTester tester, TestGesture gesture) async {
  await gesture.up(timeStamp: const Duration(milliseconds: 650));
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Paperlogy')
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-5Medium.ttf'));
    await font.load();
  });

  for (final role in AppRole.values) {
    testWidgets('iOS $role: 가장자리 뒤로가기 취소·완료 후 탭 상태 유지', (tester) async {
      await startApp(tester, role: role);
      final retainedBar = find.byType(TdsLiquidTabBar, skipOffstage: false);
      final barElement = tester.element(retainedBar);
      final selected = tester
          .widget<TdsLiquidTabBar>(retainedBar)
          .selectedIndex;
      expect(routeOf(tester, HomeTabPage).popGestureEnabled, isFalse);
      await finishSwipe(tester, await startBackSwipe(tester, 300));
      expect(find.byType(HomeShell), findsOneWidget);

      // 실제 홈 알림 버튼도 공통 라우트를 사용하는지 확인한다.
      await tester.tap(
        find.descendant(
          of: find.byType(TdsGlassIconButton),
          matching: find.byType(TdsIconButton),
        ),
      );
      await settle(tester);
      final route = routeOf(tester, NoticesPage);
      expect(route, isA<CupertinoPageRoute<dynamic>>());
      expect(
        route.popGestureEnabled,
        isTrue,
        reason:
            'first=${route.isFirst}, disposition=${route.popDisposition}, '
            'animation=${route.animation!.value}, status=${route.animation!.status}',
      );
      expect(find.byType(TdsLiquidTabBar), findsNothing);

      await tester.timedDragFrom(
        const Offset(100, 300),
        const Offset(250, 0),
        const Duration(milliseconds: 650),
      );
      await settle(tester);
      expect(route.isCurrent, isTrue, reason: '중앙 드래그는 뒤로가기가 아니다');

      final cancel = await startBackSwipe(tester, 80);
      expect(route.navigator!.userGestureInProgress, isTrue);
      expect(route.animation!.value, inExclusiveRange(0, 1));
      await finishSwipe(tester, cancel);
      expect(route.isCurrent, isTrue);
      expect(route.animation!.value, 1);
      expect(find.byType(TdsLiquidTabBar), findsNothing);

      final complete = await startBackSwipe(tester, 300);
      expect(find.byType(TdsLiquidTabBar), findsNothing);
      await complete.up(timeStamp: const Duration(milliseconds: 650));
      await tester.pump();
      expect(
        find.byType(TdsLiquidTabBar),
        findsNothing,
        reason: '뒤로가기 전환이 끝나기 전에는 탭이 나타나지 않는다',
      );
      await settle(tester);
      expect(find.byType(NoticesPage), findsNothing);
      expect(find.byType(TdsLiquidTabBar), findsOneWidget);
      expect(identical(tester.element(retainedBar), barElement), isTrue);
      expect(
        tester.widget<TdsLiquidTabBar>(retainedBar).selectedIndex,
        selected,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('iOS: 요청 상세 위 채팅에서 한 페이지만 돌아가고 뒤로 버튼도 유지', (tester) async {
    final f = await startApp(tester);
    final id = (await tester.runAsync(f.request))!;
    unawaited(
      openPage<void>(
        tester.element(find.byType(HomeTabPage)),
        RequestDetailPage(id),
      ),
    );
    await settle(tester);
    final detailRoute = routeOf(tester, RequestDetailPage);
    unawaited(
      openPage<void>(
        tester.element(find.byType(RequestDetailPage)),
        ChatPage(f.uncle, requestId: id),
      ),
    );
    await settle(tester);
    expect(routeOf(tester, ChatPage).popGestureEnabled, isTrue);
    await finishSwipe(tester, await startBackSwipe(tester, 300));
    expect(find.byType(ChatPage), findsNothing);
    expect(detailRoute.isCurrent, isTrue);
    expect(find.byType(TdsLiquidTabBar), findsNothing);
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(find.byType(RequestDetailPage), findsNothing);
    expect(find.byType(TdsLiquidTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: 자동저장 완료 후 스와이프로 나간 요청은 다시 이어서 작성', (tester) async {
    final f = await startApp(tester);
    unawaited(
      openPage<void>(
        tester.element(find.byType(HomeTabPage)),
        RequestEditor(peerId: f.uncle),
      ),
    );
    await settle(tester);
    await enter(tester, '도매처 이름', '스와이프 후에도 남는 도매처');
    expect(routeOf(tester, RequestEditor).popGestureEnabled, isTrue);
    final draft = f.workspace.records('drafts').single;
    await finishSwipe(tester, await startBackSwipe(tester, 300));
    expect(find.byType(RequestEditor), findsNothing);
    expect(
      requestWholesalers(
        f.workspace.records('drafts').single.data,
      ).single['wholesaler'],
      '스와이프 후에도 남는 도매처',
    );
    unawaited(
      openPage<void>(
        tester.element(find.byType(HomeTabPage)),
        RequestEditor(draftId: draft.id),
      ),
    );
    await settle(tester);
    final input = tester.widget<EditableText>(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is Field && w.label == '도매처 이름'),
        matching: find.byType(EditableText),
      ),
    );
    expect(input.controller.text, '스와이프 후에도 남는 도매처');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: 저장 중·실패한 요청은 보호하고 저장 복구 후 스와이프 허용', (tester) async {
    late DelayedDraftWorkspace workspace;
    final f = await startApp(
      tester,
      workspace: (f) {
        return workspace = DelayedDraftWorkspace(f);
      },
    );
    unawaited(
      openPage<void>(
        tester.element(find.byType(HomeTabPage)),
        RequestEditor(peerId: f.uncle),
      ),
    );
    await settle(tester);
    final pendingSave = Completer<void>();
    workspace.nextSave = pendingSave;
    await enter(tester, '도매처 이름', '저장 대기 도매처');
    final route = routeOf(tester, RequestEditor);
    expect(route.popGestureEnabled, isFalse);
    await finishSwipe(tester, await startBackSwipe(tester, 300));
    expect(route.isCurrent, isTrue);
    expect(route.animation!.value, 1);

    pendingSave.completeError(const AppFailure('테스트 저장 실패'));
    await settle(tester);
    expect(route.popGestureEnabled, isFalse);
    await finishSwipe(tester, await startBackSwipe(tester, 300));
    expect(find.byType(RequestEditor), findsOneWidget);
    expect(workspace.records('drafts'), isEmpty);

    await enter(tester, '도매처 이름', '저장 복구 도매처');
    expect(route.popGestureEnabled, isTrue);
    await finishSwipe(tester, await startBackSwipe(tester, 300));
    expect(find.byType(RequestEditor), findsNothing);
    expect(
      requestWholesalers(
        workspace.records('drafts').single.data,
      ).single['wholesaler'],
      '저장 복구 도매처',
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: 기존 페이지 전환과 뒤로 버튼 유지', (tester) async {
    await startApp(tester);
    const settings = RouteSettings(name: 'notices');
    final route = appPageRoute<void>(
      builder: (_) => const NoticesPage(),
      settings: settings,
    );
    expect(route, isA<PageRouteBuilder<void>>());
    expect(route.settings, same(settings));
    unawaited(
      Navigator.of(tester.element(find.byType(HomeTabPage))).push(route),
    );
    await settle(tester);
    await finishSwipe(tester, await startBackSwipe(tester, 300));
    expect(route.isCurrent, isTrue);
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(find.byType(NoticesPage), findsNothing);
    expect(find.byType(TdsLiquidTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android: 활성 상세만 시스템 뒤로가기로 닫고 루트에서는 종료를 위임한다', (tester) async {
    final f = await startApp(tester, role: AppRole.retailer);
    unawaited(
      openPage<void>(
        tester.element(find.byType(HomeTabPage)),
        ChatPage(f.uncle),
      ),
    );
    await settle(tester);

    expect(find.byType(ChatPage), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.byType(ChatPage), findsNothing);
    expect(find.byType(TdsLiquidTabBar), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android: 비활성 탭의 상세는 시스템 뒤로가기로 닫히지 않는다', (tester) async {
    final f = await startApp(tester, role: AppRole.retailer);
    final dynamic home = tester.state(find.byType(HomeShell));

    await home.selectTab(AppTab.chat.index);
    await settle(tester);
    unawaited(
      openPage<void>(tester.element(find.byType(ChatList)), ChatPage(f.uncle)),
    );
    await settle(tester);
    expect(find.byType(ChatPage), findsOneWidget);

    await home.selectTab(AppTab.home.index);
    await settle(tester);
    expect(find.byType(ChatPage, skipOffstage: false), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(find.byType(ChatPage, skipOffstage: false), findsOneWidget);

    await home.selectTab(AppTab.chat.index);
    await settle(tester);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android: 저장 재시도 중·실패 상태를 보호하고 복구 후 뒤로가기를 허용한다', (tester) async {
    late DelayedDraftWorkspace workspace;
    final f = await startApp(
      tester,
      workspace: (fixture) => workspace = DelayedDraftWorkspace(fixture),
    );
    unawaited(
      openPage<void>(
        tester.element(find.byType(HomeTabPage)),
        RequestEditor(peerId: f.uncle),
      ),
    );
    await settle(tester);

    final pendingSave = Completer<void>();
    workspace.nextSave = pendingSave;
    await enter(tester, '도매처 이름', 'Android 저장 실패 도매처');
    pendingSave.completeError(const AppFailure('테스트 저장 실패'));
    await settle(tester);

    final retrySave = Completer<void>();
    workspace.nextSave = retrySave;
    workspace.saveError = const AppFailure('테스트 재시도 실패');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.byType(RequestEditor), findsOneWidget);

    retrySave.complete();
    await settle(tester);
    expect(find.byType(RequestEditor), findsOneWidget);
    expect(workspace.records('drafts'), isEmpty);

    workspace.saveError = null;
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.byType(RequestEditor), findsNothing);
    expect(
      requestWholesalers(
        workspace.records('drafts').single.data,
      ).single['wholesaler'],
      'Android 저장 실패 도매처',
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
