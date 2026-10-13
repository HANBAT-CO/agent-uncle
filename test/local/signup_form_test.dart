import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/profile_avatar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' show databaseFactoryMemory;
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart'
    show PickableAttachment, drainClose, enter, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import '../support/profile_time_picker.dart';

class _Signup {
  late LocalStore store;
  late LocalSessionRepository session;
  late AppServices services;

  Future<void> open(
    WidgetTester tester,
    AppRole role, {
    double scale = 100,
  }) async {
    await tester.runAsync(() async {
      store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
      await store.initialize();
      session = LocalSessionRepository(store);
      final workspace = LocalWorkspaceRepository(store, session);
      services = AppServices(
        session: session,
        workspace: workspace,
        attachments: PickableAttachment(
          LocalAttachmentRepository(store, session, workspace),
        ),
      );
      await session.finishOnboarding();
      await session.createAccount('가입 테스트');
      await session.chooseRole(role);
    });
    await tester.pumpWidget(
      scale == 100
          ? AgentUncleApp(services: services)
          : AppScope(
              services: services,
              child: branded(const AccountLanding(), scale: scale),
            ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, store.close());
  }
}

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is Field && w.label == label),
  matching: find.byType(TdsTextField),
);

Future<void> channel(WidgetTester tester, String label) async {
  final item = find.widgetWithText(TdsChipItem, label);
  await tester.ensureVisible(item);
  await tester.tap(item);
  await settle(tester);
}

void main() {
  testWidgets('소매 가입의 하이픈·복수 채널·사진·항목별 오류를 유지한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final f = _Signup();
    await f.open(tester, AppRole.retailer);
    expect(find.text('저장하고 로그아웃'), findsNothing);
    expect(find.byType(TdsTopNavigationBackButton), findsNothing);
    expect(find.text('입력한 정보는 자동으로 저장돼요.'), findsNothing);
    expect(
      tester.getTopLeft(find.text('이전')).dy,
      greaterThan(tester.getBottomLeft(find.text('다음')).dy),
    );
    expect(
      TdsTheme.of(tester.element(input('매장명'))).color('greyOpacity50'),
      TdsPalette.white,
    );

    await enter(tester, '매장명', '한밭 매장');
    await enter(tester, '담당자명', '홍담당');
    await enter(tester, '연락처', '01012');
    await channel(tester, '온라인');
    await channel(tester, '오프라인');
    expect(f.session.current!.s('salesChannel'), '온라인·오프라인 병행');
    expect(find.widgetWithText(TdsChipItem, '온라인·오프라인 병행'), findsNothing);

    await tapButton(tester, '다음');
    final phone = tester.widget<TdsTextField>(input('연락처'));
    expect(phone.hasError, isTrue);
    expect(phone.focusNode!.hasFocus, isTrue);
    expect(
      tester.getRect(input('연락처')).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('page-header'))).bottom,
      ),
    );
    expect(
      tester.getRect(input('연락처')).bottom,
      lessThan(tester.getRect(find.text('다음')).top),
    );
    await enter(tester, '연락처', '0101234567');
    await tapButton(tester, '다음');
    expect(tester.widget<TdsTextField>(input('연락처')).hasError, isTrue);
    await enter(tester, '연락처', '010123456789');
    await tapButton(tester, '다음');
    expect(tester.widget<TdsTextField>(input('연락처')).hasError, isTrue);
    expect(
      tester.widget<TdsTextField>(input('연락처')).controller!.text,
      '010-1234-56789',
    );
    await enter(tester, '연락처', '+82 10 1234 5678');
    expect(
      tester.widget<TdsTextField>(input('연락처')).controller!.text,
      '010-1234-5678',
    );
    expect(tester.widget<TdsTextField>(input('연락처')).hasError, isFalse);

    await tester.ensureVisible(find.byType(ProfileAvatar));
    expect(
      tester.getCenter(find.text('프로필 사진')).dy,
      lessThan(tester.getCenter(find.byType(ProfileAvatar)).dy),
    );
    expect(
      tester.getBottomLeft(find.byType(ProfileAvatar)).dy,
      lessThan(tester.getTopLeft(find.text('프로필 사진 첨부')).dy),
    );
    await tapButton(tester, '프로필 사진 첨부');
    expect(f.session.current!.s('photoId'), isNotEmpty);
    expect(
      find.descendant(
        of: find.byType(ProfileAvatar),
        matching: find.byWidgetPredicate(
          (w) => w is TdsAssetImage && w.bytes != null,
        ),
      ),
      findsOneWidget,
    );

    await tapButton(tester, '다음');
    expect(find.text('사업자 정보를 확인해 주세요'), findsOneWidget);
    expect(find.text('JPG, JPEG, PNG, PDF 파일 · 최대 10MB'), findsOneWidget);
    await enter(tester, '사업자명', '한밭 상사');
    await enter(tester, '사업자등록번호', '12345');
    await tapButton(tester, '다음');
    expect(tester.widget<TdsTextField>(input('사업자등록번호')).hasError, isTrue);
    expect(find.text('사업자등록증을 첨부해 주세요.'), findsOneWidget);
    await enter(tester, '사업자등록번호', '1234567890');
    expect(
      tester.widget<TdsTextField>(input('사업자등록번호')).controller!.text,
      '123-45-67890',
    );
    await tapButton(tester, '사업자등록증 (필수) 첨부');
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    expect(tester.widget<TdsTextField>(input('주소')).hasError, isTrue);
    expect(tester.widget<TdsTextField>(input('상세주소')).hasError, isTrue);
    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  testWidgets('사입삼촌은 실명·시간 선택으로 가입하고 이전 단계로 돌아간다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final f = _Signup();
    await f.open(tester, AppRole.uncle);
    expect(find.text('가입 · 1 / 5'), findsOneWidget);
    expect(input('매장명'), findsNothing);
    expect(input('활동명·업체명'), findsNothing);
    expect(input('담당자명'), findsNothing);
    expect(
      tester.getSize(find.widgetWithText(TdsTextButton, '이전')).height,
      greaterThanOrEqualTo(44),
    );
    await enter(tester, '이름(실명)', '김한밭');
    await enter(tester, '연락처', '01098765432');
    await tapButton(tester, '다음');
    expect(find.text('가입 · 2 / 5'), findsOneWidget);
    expect(input('도매 픽업 구역'), findsOneWidget);
    expect(input('사업자명'), findsNothing);
    await tester.tap(find.text('이전'));
    await settle(tester);
    expect(input('이름(실명)'), findsOneWidget);
    expect(
      tester.widget<TdsTextField>(input('이름(실명)')).controller!.text,
      '김한밭',
    );
    await tapButton(tester, '다음');
    await enter(tester, '도매 픽업 구역', '동대문 1층');
    await enter(tester, '소매 배송 지역', '서울');
    await tapButton(tester, '다음');
    expect(input('요청 마감시간'), findsNothing);
    expect(
      tester.widget<TdsTextFieldButton>(timeInput('요청 마감시간')).hasError,
      isTrue,
    );
    expect(
      tester.getRect(timeInput('요청 마감시간')).bottom,
      lessThan(tester.getRect(find.text('다음')).top),
    );
    await selectTime(tester, '요청 마감시간', '23:00');
    await tapButton(tester, '다음');
    for (final label in ['도보', '기타']) {
      final button = find.widgetWithText(TdsButton, label);
      await tester.ensureVisible(button);
      expect(
        tester.getCenter(find.text(label)).dx,
        closeTo(tester.getCenter(button).dx, .5),
      );
    }
    await tapButton(tester, '도보');
    expect(f.session.current!.s('transport'), '도보');
    await tapButton(tester, '기타');
    expect(f.session.current!.s('transport'), '기타');
    await selectTime(tester, '활동 시작 (선택)', '22:00');
    await selectTime(tester, '활동 종료 (선택)', '06:00');
    await settle(tester);
    expect(f.session.current!.s('activityStart'), '22:00');
    expect(f.session.current!.s('activityEnd'), '06:00');
    await tapButton(tester, '다음');
    expect(find.text('입력한 정보를 확인해 주세요'), findsOneWidget);
    expect(find.text('사업자 서류'), findsNothing);
    await tapButton(tester, '다음');
    await tapButton(tester, '가입 완료');
    expect(f.session.current!.complete, isFalse);
    for (final label in ['[필수] 서비스 이용 동의 확인', '[필수] 개인정보 처리 동의 확인']) {
      final choice = find.widgetWithText(TdsCheckbox, label);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await settle(tester);
    }
    await tapButton(tester, '가입 완료');
    expect(f.session.current!.complete, isTrue);
    expect(f.session.current!.name, '김한밭');
    expect(find.text('김한밭 삼촌'), findsOneWidget);
    expect(f.session.current!.s('documentId'), isEmpty);
    expect(f.session.current!.s('businessNumber'), isEmpty);
    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  testWidgets('소매 사업자 정보를 입력하다 역할을 바꿔도 삼촌 가입을 마친다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final f = _Signup();
    await f.open(tester, AppRole.retailer);
    await enter(tester, '매장명', '이전 매장');
    await enter(tester, '담당자명', '김삼촌');
    await enter(tester, '연락처', '01012345678');
    await channel(tester, '온라인');
    await tapButton(tester, '다음');
    await enter(tester, '사업자등록번호', '12345');
    await tester.tap(find.text('이전'));
    await settle(tester);
    await tester.tap(find.text('이전'));
    await settle(tester);
    await tester.tap(find.text('사입삼촌'));
    await settle(tester);
    await tapButton(tester, '선택한 역할로 계속');
    expect(find.text('가입 · 1 / 5'), findsOneWidget);
    await tapButton(tester, '다음');
    expect(input('사업자등록번호'), findsNothing);
    await enter(tester, '도매 픽업 구역', '동대문');
    await enter(tester, '소매 배송 지역', '서울');
    await selectTime(tester, '요청 마감시간', '23:00');
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    await tapButton(tester, '다음');
    for (final label in ['[필수] 서비스 이용 동의 확인', '[필수] 개인정보 처리 동의 확인']) {
      final checkbox = find.widgetWithText(TdsCheckbox, label);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await settle(tester);
    }
    await tapButton(tester, '가입 완료');
    expect(f.session.current!.complete, isTrue);
    expect(f.session.current!.role, AppRole.uncle);
    expect(f.session.current!.name, '김삼촌');
    expect(f.session.current!.s('businessNumber'), '123-45');
    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('사입삼촌 시간·이동수단 선택이 너비 $width·큰 글자에 맞는다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.reset);
      final f = _Signup();
      await f.open(tester, AppRole.uncle, scale: 180);
      await enter(tester, '이름(실명)', '김한밭');
      await enter(tester, '연락처', '01012345678');
      await tapButton(tester, '다음');
      await enter(tester, '도매 픽업 구역', '동대문');
      await enter(tester, '소매 배송 지역', '서울');
      await selectTime(tester, '요청 마감시간', '00:00');
      await tapButton(tester, '다음');
      for (final label in ['도보', '오토바이', '기타']) {
        await tapButton(tester, label);
        final button = find.widgetWithText(TdsButton, label);
        expect(
          tester.getCenter(find.text(label)).dx,
          closeTo(tester.getCenter(button).dx, .5),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      }
      await selectTime(tester, '활동 시작 (선택)', '23:59');
      await selectTime(tester, '활동 종료 (선택)', '00:00');
      await tapButton(tester, '다음');
      expect(find.text('입력한 정보를 확인해 주세요'), findsOneWidget);
      expect(f.session.current!.s('deadline'), '00:00');
      expect(f.session.current!.s('activityStart'), '23:59');
      expect(f.session.current!.s('activityEnd'), '00:00');
      expect(tester.takeException(), isNull);
      await f.close(tester);
    });

    testWidgets('가입 폼과 오류 안내가 너비 $width·큰 글자에 맞는다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.reset);
      final f = _Signup();
      await f.open(tester, AppRole.retailer, scale: 180);
      await tapButton(tester, '다음');
      expect(tester.widget<TdsTextField>(input('매장명')).hasError, isTrue);
      await channel(tester, '온라인');
      await channel(tester, '오프라인');
      expect(find.widgetWithText(TdsChipItem, '온라인'), findsOneWidget);
      expect(find.widgetWithText(TdsChipItem, '오프라인'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    });
  }
}
