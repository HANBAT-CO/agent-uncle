import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../test/local/workspace_test.dart' show Fixture;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final platform = ios ? 'ios' : 'android';
  var surfaceConverted = false;

  Finder nativeTabs() => find.byWidgetPredicate(
    (widget) =>
        widget is UiKitView &&
        widget.viewType == 'tds/liquid_glass' &&
        (widget.creationParams as Map?)?['kind'] == 'tabs',
    skipOffstage: false,
  );

  int? nativeTabId(WidgetTester tester) {
    if (!ios) return null;
    final renderView = find.descendant(
      of: nativeTabs(),
      matching: find.byElementPredicate(
        (element) =>
            element is RenderObjectElement &&
            element.renderObject is RenderUiKitView,
        skipOffstage: false,
      ),
      skipOffstage: false,
    );
    return tester.renderObject<RenderUiKitView>(renderView).viewController.id;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Allow the asynchronous platform-view registration to reach UIKit too.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!ios && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await settle(tester);
    }
    await binding.takeScreenshot('saip-$platform-tabs-$name');
  }

  Future<void> selectTab(WidgetTester tester, String label) async {
    final bar = tester.widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar));
    final index = bar.items.indexWhere((item) => item.label == label);
    expect(index, greaterThanOrEqualTo(0));
    final fallback = find.widgetWithText(TdsTextButton, label);
    if (fallback.evaluate().isNotEmpty) {
      await tester.tap(fallback);
    } else {
      // Flutter pointers cannot activate UIKit recognizers. Native view IDs
      // below verify retention; XCUITest separately exercises native gestures.
      expect(await bar.onSelected(index), isTrue);
    }
    await settle(tester);
    expect(
      tester
          .widget<TdsLiquidTabBar>(find.byType(TdsLiquidTabBar))
          .selectedIndex,
      index,
    );
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final target = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Field && widget.label == label,
      ),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
    await tester.enterText(target, value);
    await settle(tester);
  }

  testWidgets('탭 헤더와 네이티브 글라스를 유지하며 연결·프로필을 오간다', (tester) async {
    final f = Fixture();
    await f.start();
    final retailer = await f.account('한밭 매장', AppRole.retailer);
    await f.session.saveProfile({
      'markets': ['동대문', '남대문'],
    });
    await f.session.finishOnboarding();
    final services = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: services));
    await settle(tester);
    if (ios) {
      expect(await TdsLiquidGlass.available, isTrue);
      expect(nativeTabs(), findsOneWidget);
    }
    final barFinder = find.byType(TdsLiquidTabBar);
    final initialBar = tester.element(barFinder);
    final initialId = nativeTabId(tester);
    final initialBell = tester.getRect(find.byType(TdsGlassIconButton));
    final initialHeader = tester.getRect(
      find.byKey(const ValueKey('page-header')),
    );

    Future<void> expectStableTabs({bool hidden = false}) async {
      expect(barFinder, hidden ? findsNothing : findsOneWidget);
      final retained = find.byType(TdsLiquidTabBar, skipOffstage: false);
      expect(tester.element(retained), same(initialBar));
      expect(nativeTabId(tester), initialId);
      if (hidden) {
        expect(retained.hitTestable(), findsNothing);
      }
    }

    Future<void> back() async {
      await expectStableTabs(hidden: true);
      await tester.tap(find.byType(TdsTopNavigationBackButton).hitTestable());
      await settle(tester);
      await expectStableTabs();
    }

    for (final label in AppRole.retailer.tabs) {
      await selectTab(tester, label);
      final currentHeader = tester.getRect(
        find.byKey(const ValueKey('page-header')),
      );
      if (label == '홈') {
        expect(tester.getRect(find.byType(TdsGlassIconButton)), initialBell);
        expect(currentHeader, initialHeader);
      } else {
        expect(find.byType(TdsGlassIconButton), findsNothing);
        expect(currentHeader.height, lessThan(initialHeader.height));
      }
      await expectStableTabs();
      expect(tester.takeException(), isNull);
    }

    await selectTab(tester, '홈');
    expect(find.text('거래처 연결하기'), findsNothing);
    await capture(tester, 'home');
    await selectTab(tester, '채팅');
    expect(find.text('거래처 연결을 수락하면 1:1 채팅을 시작할 수 있어요.'), findsNothing);
    await capture(tester, 'chat');
    await selectTab(tester, '사입삼촌');
    expect(find.text('아직 함께하는 사입삼촌이 없어요'), findsOneWidget);
    expect(find.text('거래처 연결하기'), findsOneWidget);
    await capture(tester, 'connections');
    await tap(tester, '거래처 연결하기');
    expect(find.byType(AddConnectionPage), findsOneWidget);
    await back();
    await capture(tester, 'connection-return');

    await tap(tester, '새 연결');
    expect(find.byType(AddConnectionPage), findsOneWidget);
    await enter(
      tester,
      '초대 코드',
      f.store.snapshot.get('accounts', f.uncle)!.s('code'),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tap(tester, '상대방 확인');
    expect(find.text('사입 업체'), findsOneWidget);
    await tap(tester, '연결 요청 보내기');
    await expectStableTabs();
    expect(f.workspace.records('connections').single.s('status'), 'pending');
    await tap(tester, '연결 대기 1');
    expect(find.byType(ConnectionCard), findsOneWidget);
    expect(find.text('거래처 연결하기'), findsNothing);
    await capture(tester, 'pending');

    await selectTab(tester, '내 프로필');
    expect(find.text('내 업무 정보'), findsNothing);
    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.text('기본 배송지'), findsOneWidget);
    expect(find.text('사입 시장'), findsOneWidget);
    await tap(tester, '프로필 수정');
    expect(find.byType(ProfileForm), findsOneWidget);
    await expectStableTabs(hidden: true);
    await enter(tester, '주소', '서울시 중구 을지로 100');
    await enter(tester, '상세주소', '2층 사입 사무실');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tap(tester, '저장하기');
    await expectStableTabs();
    expect(f.session.current!.s('address'), '서울시 중구 을지로 100');
    expect(find.textContaining('서울시 중구 을지로 100'), findsOneWidget);
    expect(find.textContaining('2층 사입 사무실'), findsOneWidget);
    await capture(tester, 'profile');

    for (final label in ['알림 설정', '계정 연결 정보', '사업자 서류']) {
      await tap(tester, label);
      await back();
    }
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1500),
    );
    await settle(tester);
    await capture(tester, 'profile-return');

    // The uncle keeps the same header contract and the business information
    // that now lives in the profile card. Account changes create a new shell.
    await f.session.signIn(f.uncle);
    await settle(tester);
    final uncleBell = tester.getRect(find.byType(TdsGlassIconButton));
    final uncleId = nativeTabId(tester);
    for (final label in AppRole.uncle.tabs) {
      await selectTab(tester, label);
      expect(tester.getRect(find.byType(TdsGlassIconButton)), uncleBell);
      expect(nativeTabId(tester), uncleId);
    }
    await selectTab(tester, '내 정보');
    expect(find.text('내 업무 정보'), findsNothing);
    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.textContaining('동대문 1층'), findsWidgets);
    expect(find.textContaining('22:00'), findsWidgets);
    await capture(tester, 'uncle-profile');
    await tap(tester, '알림 설정');
    expect(find.byType(TdsLiquidTabBar), findsNothing);
    expect(nativeTabId(tester), uncleId);
    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    expect(nativeTabId(tester), uncleId);
    expect(tester.widget<TdsLiquidTabBar>(barFinder).selectedIndex, 4);
    expect(f.session.current!.id, isNot(retailer));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await f.store.close();
  });
}
