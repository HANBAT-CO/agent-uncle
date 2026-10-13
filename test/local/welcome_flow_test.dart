import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' hide Field;
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/welcome.dart';

const onboardingTitles = [
  '상품과 수량을 정확하게 전달해요',
  '확보부터 수령까지 함께 확인해요',
  '요청과 대화를 이어가요',
];

class CountingSession extends LocalSessionRepository {
  CountingSession(super.store);
  int chooseRoleCalls = 0;
  @override
  Future<void> chooseRole(AppRole role) {
    chooseRoleCalls++;
    return super.chooseRole(role);
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(TdsButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.byWidgetPredicate((w) => w is Field && w.label == label),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await settle(tester);
}

Future<CountingSession> pumpApp(WidgetTester tester) async {
  final store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
  await store.initialize();
  final session = CountingSession(store);
  final workspace = LocalWorkspaceRepository(
    store,
    LocalSessionRepository(store),
  );
  await tester.pumpWidget(
    AgentUncleApp(
      services: AppServices(
        session: session,
        workspace: workspace,
        attachments: LocalAttachmentRepository(store, session, workspace),
      ),
    ),
  );
  await settle(tester);
  return session;
}

Future<void> reachRolePage(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TdsTextButton, '건너뛰기'));
  await settle(tester);
  await enter(tester, '계정 이름', '테스트 매장');
  await tapButton(tester, '로컬 계정 만들기');
}

void main() {
  testWidgets('onboarding shows one title per page without filler, with '
      'TDS entrance motion and logo', (tester) async {
    final session = await pumpApp(tester);
    for (var page = 0; page < 3; page++) {
      for (var i = 0; i < 3; i++) {
        expect(
          find.text(onboardingTitles[i]),
          i == page ? findsOneWidget : findsNothing,
          reason: '페이지 ${page + 1}에는 제목 한 문장만 보인다',
        );
      }
      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('${page + 1} / 3'), findsOneWidget);
      expect(find.byType(TdsTooltipMotionSurface), findsOneWidget);
      expect(find.byType(FigmaSurface), findsNothing);
      expect(find.byType(QuantityRow), findsNothing);
      expect(find.text('상품·옵션·수량을 요청에 담고 거래처와 같은 내용을 확인해요.'), findsNothing);
      if (page < 2) await tapButton(tester, '다음');
    }
    await tapButton(tester, '시작하기');
    expect(session.onboardingSeen, isTrue);
    expect(find.text('로컬 계정 만들기'), findsOneWidget);
  });

  testWidgets('reduced motion removes entrance surfaces but keeps the flow '
      'and selection emphasis', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final session = await pumpApp(tester);
    expect(find.text(onboardingTitles[0]), findsOneWidget);
    expect(find.byType(TdsTooltipMotionSurface), findsNothing);
    await tapButton(tester, '다음');
    expect(find.text(onboardingTitles[1]), findsOneWidget);
    expect(find.byType(TdsTooltipMotionSurface), findsNothing);
    await reachRolePage(tester);
    await tester.tap(find.text('소매업자'));
    await settle(tester);
    expect(find.byType(TdsTooltipMotionSurface), findsNothing);
    final tinted = tester
        .widgetList<FigmaSurface>(find.byType(FigmaSurface))
        .where((s) => s.tinted);
    expect(tinted.length, 1, reason: '모션 없이도 선택 강조는 유지된다');
    await tapButton(tester, '선택한 역할로 계속');
    expect(session.current!.role, AppRole.retailer);
  });

  testWidgets('role cards keep their size and position when selected, '
      'change emphasis, then continue', (tester) async {
    final session = await pumpApp(tester);
    await reachRolePage(tester);
    expect(find.byType(TdsCheckbox), findsNothing);
    expect(find.byType(TdsTooltipMotionSurface), findsNothing);

    await tapButton(tester, '선택한 역할로 계속');
    expect(find.text('어떤 일을 하고 계신가요?'), findsOneWidget);
    expect(session.current!.role, isNull, reason: '선택 전에는 계속할 수 없다');

    final roleCards = find.byType(FigmaSurface);
    final initialBounds = [
      for (var i = 0; i < 2; i++) tester.getRect(roleCards.at(i)),
    ];
    await tester.tap(find.text('소매업자'));
    await settle(tester);
    bool selectedIcon(Widget w) => w is FigmaIcon && w.selected && w.size == 40;
    expect(find.byWidgetPredicate(selectedIcon), findsOneWidget);
    expect(find.byType(TdsTooltipMotionSurface), findsNothing);
    for (var i = 0; i < 2; i++) {
      expect(tester.getRect(roleCards.at(i)), initialBounds[i]);
    }
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.selected == true,
      ),
      findsOneWidget,
    );
    var tinted = tester
        .widgetList<FigmaSurface>(find.byType(FigmaSurface))
        .where((s) => s.tinted);
    expect(tinted.length, 1);

    await tester.tap(find.text('사입삼촌'));
    await settle(tester);
    tinted = tester
        .widgetList<FigmaSurface>(find.byType(FigmaSurface))
        .where((s) => s.tinted);
    expect(tinted.length, 1, reason: '선택은 하나만 유지된다');
    expect(find.byWidgetPredicate(selectedIcon), findsOneWidget);
    expect(find.byType(TdsTooltipMotionSurface), findsNothing);
    for (var i = 0; i < 2; i++) {
      expect(tester.getRect(roleCards.at(i)), initialBounds[i]);
    }

    await tapButton(tester, '선택한 역할로 계속');
    expect(session.current!.role, AppRole.uncle);
    expect(session.chooseRoleCalls, 1);
    expect(find.text('연락받을 정보를 알려주세요'), findsOneWidget);
  });

  testWidgets('back to login is a plain text button below continue and '
      'signs out once', (tester) async {
    final session = await pumpApp(tester);
    await reachRolePage(tester);
    final backButton = find.widgetWithText(TdsTextButton, '로그인으로 돌아가기');
    expect(backButton, findsOneWidget);
    expect(find.widgetWithText(TdsButton, '로그인으로 돌아가기'), findsNothing);
    expect(
      find.ancestor(of: backButton, matching: find.byType(FigmaSurface)),
      findsNothing,
      reason: '구분선이나 박스 없이 텍스트 버튼만 둔다',
    );
    final continueButton = find.widgetWithText(TdsButton, '선택한 역할로 계속').last;
    expect(
      tester.getTopLeft(backButton).dy,
      greaterThan(tester.getTopLeft(continueButton).dy),
      reason: '계속 버튼 바로 아래에 둔다',
    );
    await tester.tap(backButton);
    await settle(tester);
    expect(session.current, isNull);
    expect(find.text('로컬 계정 만들기'), findsOneWidget);
    expect(find.text('테스트 매장'), findsOneWidget, reason: '계정은 유지된다');
  });

  testWidgets('double tap on continue chooses the role once', (tester) async {
    final session = await pumpApp(tester);
    await reachRolePage(tester);
    await tester.tap(find.text('소매업자'));
    await settle(tester);
    final button = find.widgetWithText(TdsButton, '선택한 역할로 계속').last;
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await settle(tester);
    expect(session.chooseRoleCalls, 1);
    expect(session.current!.role, AppRole.retailer);
  });

  testWidgets('closeOnSelect keeps back navigation, saves once, and closes', (
    tester,
  ) async {
    final session = await pumpApp(tester);
    await reachRolePage(tester);
    openPage(
      tester.element(find.byType(RolePage).first),
      const RolePage(closeOnSelect: true),
    );
    await settle(tester);

    expect(find.byType(TdsTopNavigationBackButton), findsOneWidget);

    await tester.tap(find.text('사입삼촌').last);
    await settle(tester);
    await tapButton(tester, '선택한 역할로 계속');

    expect(session.current!.role, AppRole.uncle);
    expect(session.chooseRoleCalls, 1);
    expect(find.byType(RolePage), findsNothing);
    expect(find.text('연락받을 정보를 알려주세요'), findsOneWidget);
  });

  testWidgets('onboarding and role pages fit 320 width at 180% type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final session = await pumpApp(tester);
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    await tapButton(tester, '시작하기');
    await enter(tester, '계정 이름', '테스트 매장');
    await tapButton(tester, '로컬 계정 만들기');
    await tester.tap(find.text('소매업자'));
    await settle(tester);
    await tester.tap(find.text('사입삼촌'));
    await settle(tester);
    await tapButton(tester, '선택한 역할로 계속');
    expect(session.current!.role, AppRole.uncle);
  });
}
