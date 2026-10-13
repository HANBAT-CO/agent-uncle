import 'dart:async';

import 'package:agent_uncle/core/presentation/app_splash.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/main.dart' show LocalBootstrap;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sembast/sembast_memory.dart' show databaseFactoryMemory;
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../test/local/app_flow_test.dart' show PickableAttachment;
import '../test/support/profile_time_picker.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';
  var converted = false;

  Future<void> capture(WidgetTester tester, String name) async {
    if (platform == 'android' && !converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('saip-$platform-signup-$name');
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is Field && w.label == label),
    matching: find.byType(EditableText),
  );

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final target = input(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Future<void> dismissKeyboard(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> scrollToTop(WidgetTester tester) async {
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1800),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('양쪽 역할의 가입과 오류 복구를 실제 화면에서 확인한다', (tester) async {
    final store = LocalStore(
      await databaseFactoryMemory.openDatabase('native-signup'),
    );
    await store.initialize();
    final session = LocalSessionRepository(store);
    final workspace = LocalWorkspaceRepository(store, session);
    final services = AppServices(
      session: session,
      workspace: workspace,
      attachments: PickableAttachment(
        LocalAttachmentRepository(store, session, workspace),
      ),
    );

    final startup = Completer<AppServices>();
    await tester.pumpWidget(LocalBootstrap(initialize: () => startup.future));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppSplashScreen.message), findsOneWidget);
    await capture(tester, 'splash');
    startup.complete(services);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    await capture(tester, 'onboarding');
    await tap(tester, '다음');
    expect(find.text('확보부터 수령까지 함께 확인해요'), findsOneWidget);
    await tap(tester, '다음');
    expect(find.text('요청과 대화를 이어가요'), findsOneWidget);
    await tap(tester, '시작하기');

    await session.createAccount('소매 가입 화면 확인');
    await tester.pumpAndSettle();
    await tap(tester, '소매업자');
    expect(find.byType(TdsCheckbox), findsNothing);
    await capture(tester, 'role');
    await tap(tester, '선택한 역할로 계속');
    await enter(tester, '매장명', '한밭 매장');
    await enter(tester, '담당자명', '김한밭');
    await enter(tester, '연락처', '01012');
    await dismissKeyboard(tester);
    await tap(tester, '온라인');
    await tap(tester, '오프라인');
    await tap(tester, '다음');
    expect(find.text('연락처를 010-1234-5678 형식으로 입력해 주세요.'), findsOneWidget);
    await dismissKeyboard(tester);
    await capture(tester, 'phone-error');
    await enter(tester, '연락처', '01012345678');
    expect(
      tester.widget<EditableText>(input('연락처')).controller.text,
      '010-1234-5678',
    );
    await dismissKeyboard(tester);
    await scrollToTop(tester);
    await capture(tester, 'retailer');
    await tester.ensureVisible(find.text('오프라인'));
    await tester.pumpAndSettle();
    await capture(tester, 'channels');

    await tap(tester, '다음');
    await enter(tester, '사업자명', '한밭 상사');
    await enter(tester, '사업자등록번호', '1234567890');
    await dismissKeyboard(tester);
    await tap(tester, '다음');
    expect(find.text('사업자등록증을 첨부해 주세요.'), findsOneWidget);
    await capture(tester, 'document');
    await tap(tester, '사업자등록증 (필수) 첨부');
    await tap(tester, '다음');
    await enter(tester, '주소', '서울 중구');
    await enter(tester, '상세주소', '1층 한밭 매장');
    await tap(tester, '다음');
    await tap(tester, '다음');
    await tap(tester, '다음');
    await tap(tester, '[필수] 서비스 이용 동의 확인');
    await tap(tester, '[필수] 개인정보 처리 동의 확인');
    await tap(tester, '가입 완료');
    expect(session.current!.complete, isTrue);
    expect(session.current!.s('salesChannel'), '온라인·오프라인 병행');

    await session.signOut();
    await session.createAccount('삼촌 가입 화면 확인');
    await tester.pumpAndSettle();
    await tap(tester, '사입삼촌');
    await tap(tester, '선택한 역할로 계속');
    expect(find.text('가입 · 1 / 5'), findsOneWidget);
    expect(input('활동명·업체명'), findsNothing);
    await enter(tester, '이름(실명)', '이삼춘');
    await enter(tester, '연락처', '01098765432');
    await dismissKeyboard(tester);
    await scrollToTop(tester);
    await capture(tester, 'uncle');
    await tap(tester, '다음');
    expect(find.text('가입 · 2 / 5'), findsOneWidget);
    expect(input('사업자명'), findsNothing);
    await enter(tester, '도매 픽업 구역', '동대문 신평화 1층');
    await enter(tester, '소매 배송 지역', '서울·경기');
    await selectTime(tester, '요청 마감시간', '23:00');
    await dismissKeyboard(tester);
    await scrollToTop(tester);
    await capture(tester, 'uncle-area');
    await tap(tester, '다음');
    await tap(tester, '다음');
    await tap(tester, '다음');
    await tap(tester, '[필수] 서비스 이용 동의 확인');
    await tap(tester, '[필수] 개인정보 처리 동의 확인');
    await tap(tester, '가입 완료');
    expect(session.current!.complete, isTrue);
    expect(session.current!.role, AppRole.uncle);
    expect(session.current!.name, '이삼춘');
    expect(session.current!.s('documentId'), isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await store.close();
  });
}
