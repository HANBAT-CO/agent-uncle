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

  testWidgets('초기화 중 원본 로고를 중앙에 표시하고 준비되면 바로 온보딩으로 이동한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final startup = Completer<AppServices>();
    await tester.pumpWidget(LocalBootstrap(initialize: () => startup.future));
    await settle(tester);

    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is TdsAssetImage && widget.src == AppSplashScreen.logoAsset,
    );
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(tester.getSize(logo), const Size(192, 192));
    expect(tester.getCenter(logo), const Offset(195, 422));
    expect(find.byType(TdsLoader), findsNothing);

    startup.complete(services);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AppSplashScreen), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('초기화 실패 후 재시도하는 동안 이전 오류 대신 스플래시를 표시한다', (tester) async {
    final first = Completer<AppServices>();
    final retry = Completer<AppServices>();
    var attempts = 0;
    await tester.pumpWidget(
      LocalBootstrap(
        initialize: () => ++attempts == 1 ? first.future : retry.future,
      ),
    );
    first.completeError(StateError('초기화 실패'));
    await settle(tester);
    expect(find.text('앱을 시작하지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(AppSplashScreen), findsOneWidget);
    expect(find.text('앱을 시작하지 못했어요'), findsNothing);

    retry.complete(services);
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnboardingPage), findsOneWidget);
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
