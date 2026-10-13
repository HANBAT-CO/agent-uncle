import 'dart:async';

import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/core/presentation/app_splash.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;

class _CheckingSession extends LocalSessionRepository {
  _CheckingSession(super.store);
  bool checking = false;
  bool failed = false;

  @override
  bool get loading => checking;
  @override
  bool get authenticated => failed;
  @override
  String? get syncError => failed ? '계정 정보를 확인하지 못했어요.' : null;

  void finish({bool withError = false}) {
    checking = false;
    failed = withError;
    notifyListeners();
  }
}

void main() {
  late LocalStore store;
  late _CheckingSession session;
  late AppServices services;

  setUp(() async {
    store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
    await store.initialize();
    session = _CheckingSession(store);
    final workspace = LocalWorkspaceRepository(store, session);
    services = AppServices(
      session: session,
      workspace: workspace,
      attachments: LocalAttachmentRepository(store, session, workspace),
    );
  });

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, store.close());
  }

  testWidgets('초기화가 즉시 끝나도 로고와 안내 문구를 3초 동안 유지한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final startup = Completer<AppServices>();
    await tester.pumpWidget(LocalBootstrap(initialize: () => startup.future));
    startup.complete(services);
    await settle(tester); // 0.6초 경과

    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is TdsAssetImage && widget.src == AppSplashScreen.logoAsset,
    );
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(tester.getSize(logo), const Size(192, 192));
    expect(tester.getCenter(logo).dx, 195);
    expect(find.text(AppSplashScreen.message), findsOneWidget);
    expect(find.byType(TdsLoader), findsNothing);

    await tester.pump(const Duration(seconds: 2)); // 2.6초: 아직 최소 유지 시간
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 500)); // 3.1초: 유지 종료
    await tester.pump();
    expect(find.byType(AppSplashScreen), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('초기화가 3초보다 오래 걸리면 끝날 때까지 스플래시를 유지한다', (tester) async {
    final startup = Completer<AppServices>();
    await tester.pumpWidget(LocalBootstrap(initialize: () => startup.future));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.text(AppSplashScreen.message), findsOneWidget);
    expect(find.text('앱을 시작하지 못했어요'), findsNothing);

    startup.complete(services);
    await settle(tester); // 추가 3초 대기 없이 바로 전환된다
    expect(find.byType(AppSplashScreen), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('첫 실행은 직접 누를 때만 진행하고 로그인 입력과 포커스를 유지한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LocalBootstrap(initialize: () async => services));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    const firstTitle = '상품과 수량을 정확하게 전달해요';
    expect(find.text(firstTitle), findsOneWidget);
    final titleBounds = tester.getRect(find.text(firstTitle));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(firstTitle), findsOneWidget);
    expect(tester.getRect(find.text(firstTitle)), titleBounds);
    expect(session.onboardingSeen, isFalse);

    for (final title in ['확보부터 수령까지 함께 확인해요', '요청과 대화를 이어가요']) {
      await tester.tap(find.widgetWithText(TdsButton, '다음'));
      await settle(tester);
      expect(find.text(title), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(TdsButton, '시작하기'));
    await settle(tester);
    expect(find.byType(LocalLoginPage), findsOneWidget);

    final input = find.descendant(
      of: find.byType(TdsTextField),
      matching: find.byType(EditableText),
    );
    await tester.tap(input);
    await tester.enterText(input, '첫 입력 유지');
    await settle(tester);
    await tester.pump(const Duration(seconds: 30));
    final editable = tester.widget<EditableText>(input);
    expect(editable.controller.text, '첫 입력 유지');
    expect(editable.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(session.current, isNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('초기화 실패도 3초 뒤에 보여 주고 재시도하면 스플래시를 다시 유지한다', (tester) async {
    final first = Completer<AppServices>();
    final retry = Completer<AppServices>();
    var attempts = 0;
    await tester.pumpWidget(
      LocalBootstrap(
        initialize: () => ++attempts == 1 ? first.future : retry.future,
      ),
    );
    first.completeError(StateError('초기화 실패'));
    await settle(tester); // 0.6초: 오류도 최소 유지 시간 전에는 숨긴다
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.text('앱을 시작하지 못했어요'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('앱을 시작하지 못했어요'), findsOneWidget);
    expect(find.byType(AppSplashScreen), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.text('앱을 시작하지 못했어요'), findsNothing);

    retry.complete(services);
    await tester.pump(const Duration(seconds: 2)); // 재시도도 최소 3초 유지
    expect(find.byType(AppSplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1001));
    await settle(tester);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('최소 유지 시간이 끝나기 전에 화면을 내려도 타이머가 안전하게 정리된다', (tester) async {
    final startup = Completer<AppServices>();
    await tester.pumpWidget(LocalBootstrap(initialize: () => startup.future));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AppSplashScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('서비스 준비 이후 계정 확인이 끝날 때까지 같은 스플래시를 유지한다', (tester) async {
    session.checking = true;
    await tester.pumpWidget(AgentUncleApp(services: services));
    await settle(tester);
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);

    session.finish();
    await tester.pump();
    expect(find.byType(AppSplashScreen), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('계정 확인 실패 시 스플래시에서 빠져나와 복구 동작을 제공한다', (tester) async {
    session.checking = true;
    await tester.pumpWidget(AgentUncleApp(services: services));
    session.finish(withError: true);
    await settle(tester);

    expect(find.byType(AppSplashScreen), findsNothing);
    expect(find.text('계정 정보를 확인하지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
