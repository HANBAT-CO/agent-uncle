import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, enter, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;
import '../support/profile_time_picker.dart';

Future<AppServices> showHomeShell(
  WidgetTester tester,
  Fixture fixture, {
  required double width,
  required double scale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  addTearDown(tester.view.reset);
  final services = AppServices(
    session: fixture.session,
    workspace: fixture.workspace,
    attachments: fixture.attachments,
  );
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: branded(const HomeShell(), scale: scale),
    ),
  );
  await settle(tester);
  return services;
}

Future<void> openProfileTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(TdsTextButton, label);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await settle(tester);
}

Future<void> closeFixture(
  WidgetTester tester,
  Fixture fixture,
  AppServices services,
) async {
  await tester.pumpWidget(const SizedBox());
  services.dispose();
  await drainClose(tester, fixture.store.close());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Paperlogy')
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-5Medium.ttf'));
    await font.load();
  });

  testWidgets('소매 프로필은 업무 정보를 통합하고 수정 버튼을 하나만 제공한다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await fixture.session.finishOnboarding();
      await fixture.session.saveProfile({
        'address': '서울특별시 중구 을지로 281 동대문디자인플라자',
        'addressDetail': '패션몰 5층 501호 긴 상세주소',
        'markets': ['동대문종합시장 A동 1층 액세서리', '남평화시장 B동 2층 원단'],
      });
    });
    final services = await showHomeShell(
      tester,
      fixture,
      width: 320,
      scale: 180,
    );

    await openProfileTab(tester, '내 프로필');

    expect(find.text('내 업무 정보'), findsNothing);
    expect(find.widgetWithText(TdsButton, '프로필 수정'), findsOneWidget);
    expect(find.text('기본 배송지'), findsOneWidget);
    expect(find.text('사입 시장'), findsOneWidget);
    expect(find.textContaining('동대문디자인플라자'), findsOneWidget);
    expect(find.textContaining('패션몰 5층 501호 긴 상세주소'), findsOneWidget);
    expect(find.textContaining('동대문종합시장 A동 1층 액세서리'), findsOneWidget);
    expect(find.byType(ProfileForm), findsNothing);

    await tester.tap(find.textContaining('동대문디자인플라자'));
    await settle(tester);
    expect(find.byType(ProfileForm), findsNothing);

    await tapButton(tester, '프로필 수정');
    expect(find.byType(ProfileForm), findsOneWidget);
    expect(tester.takeException(), isNull);

    await closeFixture(tester, fixture, services);
  });

  testWidgets('삼촌 프로필 요약은 수정 후 활동 정보와 상태를 바로 갱신한다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await fixture.session.finishOnboarding();
      await fixture.session.signIn(fixture.uncle);
    });
    final services = await showHomeShell(
      tester,
      fixture,
      width: 375,
      scale: 100,
    );

    await openProfileTab(tester, '내 정보');

    expect(find.widgetWithText(TdsButton, '프로필 수정'), findsOneWidget);
    expect(find.text('도매 픽업 구역'), findsOneWidget);
    expect(find.text('소매 배송 지역'), findsOneWidget);
    expect(find.text('업무 상태'), findsOneWidget);
    expect(find.text('요청 마감시간'), findsOneWidget);
    expect(find.text('동대문 1층'), findsOneWidget);
    expect(find.text('서울'), findsOneWidget);
    expect(find.text('업무 중'), findsOneWidget);
    expect(find.text('22:00'), findsOneWidget);

    await tapButton(tester, '프로필 수정');
    expect(find.byType(ProfileForm), findsOneWidget);

    await enter(tester, '도매 픽업 구역', '남대문 2층 12호');
    await enter(tester, '소매 배송 지역', '경기 북부 · 의정부');
    await selectTime(tester, '요청 마감시간', '23:30');
    final working = find.byType(TdsSwitch);
    await tester.ensureVisible(working);
    await tester.tap(working);
    await settle(tester);
    await tapButton(tester, '저장하기');

    expect(find.byType(ProfileForm), findsNothing);
    expect(find.text('남대문 2층 12호'), findsOneWidget);
    expect(find.text('경기 북부 · 의정부'), findsOneWidget);
    expect(find.text('휴무 중'), findsOneWidget);
    expect(find.text('23:30'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await closeFixture(tester, fixture, services);
  });
}
