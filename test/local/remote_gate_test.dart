import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/remote_gate.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:agent_uncle/remote/remote_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

class MutableConfigStore extends RemoteConfigRepository {
  MutableConfigStore(this._current);

  RemoteConfig _current;

  set currentConfig(RemoteConfig value) {
    _current = value;
    notifyListeners();
  }

  @override
  RemoteConfig get current => _current;

  @override
  Future<void> load() async {}

  @override
  Future<void> dismissNotice(String id) async {
    final notice = _current.notice(id);
    if (notice == null || !notice.dismissible) return;
    _current = _current.copyWith(
      dismissedNotices: {..._current.dismissedNotices, id: notice.version},
    );
    notifyListeners();
  }

  @override
  Future<void> dismissRecommendedUpdate() async {
    _current = _current.copyWith(
      dismissedRecommendedUpdate: _current.update.recommendationKey,
    );
    notifyListeners();
  }
}

RemoteConfig config({
  bool requiredUpdate = false,
  bool recommendedUpdate = false,
  bool maintenance = false,
  bool suspended = false,
  List<AppNotice> notices = const [],
  Data rawConfig = const {},
  Map<String, int> dismissed = const {},
}) => RemoteConfig.defaults.copyWith(
  rawConfig: rawConfig,
  maintenance: MaintenanceConfig(
    active: maintenance,
    blockWrites: maintenance,
    title: '점검 안내',
    message: '잠시 점검하고 있어요.',
    endsAt: null,
  ),
  update: UpdateConfig(
    platform: 'ios',
    current: '0.1.0+1',
    required: requiredUpdate,
    recommended: recommendedUpdate,
    minimum: '0.1.0',
    latest: '0.2.0',
    storeUrl: 'https://example.com/store',
    message: '새 버전으로 업데이트해 주세요.',
  ),
  account: suspended
      ? const AccountGateConfig(status: 'suspended', message: '제한 사유예요.')
      : null,
  notices: notices,
  dismissedNotices: dismissed,
);

AppNotice notice(
  String id,
  String title,
  AppNoticeSeverity severity, {
  String audience = 'all',
  bool dismissible = true,
  int version = 1,
}) => AppNotice(
  id: id,
  title: title,
  body: '$title 본문이에요.',
  audience: audience,
  severity: severity,
  linkUrl: '',
  startsAt: null,
  endsAt: null,
  dismissible: dismissible,
  version: version,
  updatedAt: DateTime.parse('2026-10-13T00:00:00Z'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RemoteGate checks update, maintenance, then suspension', (
    tester,
  ) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await fixture.session.finishOnboarding();
    });
    final configStore = MutableConfigStore(
      config(requiredUpdate: true, maintenance: true, suspended: true),
    );
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
      config: configStore,
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(const RemoteGate(child: Text('홈 화면'))),
      ),
    );
    await settle(tester);
    expect(find.text('업데이트가 필요해요'), findsOneWidget);
    expect(find.text('스토어로 이동'), findsOneWidget);
    expect(find.text('점검 안내'), findsNothing);

    configStore.currentConfig = config(maintenance: true, suspended: true);
    await settle(tester);
    expect(find.text('점검 안내'), findsOneWidget);
    expect(find.text('이용이 제한된 계정이에요'), findsNothing);

    configStore.currentConfig = config(suspended: true);
    await settle(tester);
    expect(find.text('이용이 제한된 계정이에요'), findsOneWidget);
    await tester.tap(find.text('로그아웃'));
    await settle(tester);
    expect(fixture.session.current, isNull);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });

  testWidgets(
    'Home shows recommended update and top notice with version dismissal',
    (tester) async {
      final fixture = Fixture();
      final criticalV1 = notice(
        'critical',
        '긴급 운영 공지',
        AppNoticeSeverity.critical,
      );
      final info = notice(
        'info',
        '소매 운영 공지',
        AppNoticeSeverity.info,
        audience: 'retailer',
      );
      await tester.runAsync(() async {
        await fixture.start();
        await fixture.session.finishOnboarding();
      });
      final configStore = MutableConfigStore(
        config(recommendedUpdate: true, notices: [info, criticalV1]),
      );
      final services = AppServices(
        session: fixture.session,
        workspace: fixture.workspace,
        attachments: fixture.attachments,
        config: configStore,
      );
      await tester.pumpWidget(
        AppScope(services: services, child: branded(const HomeShell())),
      );
      await settle(tester);

      expect(find.text('새 버전이 준비됐어요'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await settle(tester);
      expect(find.text('새 버전이 준비됐어요'), findsNothing);

      expect(find.text('긴급 운영 공지'), findsOneWidget);
      final homeNotice = find.byKey(
        const ValueKey('home-remote-notice-critical'),
      );
      await tester.tap(
        find.descendant(of: homeNotice, matching: find.text('닫기')),
      );
      await settle(tester);
      expect(find.text('긴급 운영 공지'), findsNothing);
      expect(find.text('소매 운영 공지'), findsOneWidget);

      final criticalV2 = notice(
        'critical',
        '긴급 운영 공지',
        AppNoticeSeverity.critical,
        version: 2,
      );
      configStore.currentConfig = config(
        notices: [info, criticalV2],
        dismissed: configStore.current.dismissedNotices,
      );
      await settle(tester);
      expect(find.text('긴급 운영 공지'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TdsGlassIconButton),
          matching: find.byType(TdsIconButton),
        ),
      );
      await settle(tester);
      expect(find.byType(NoticesPage), findsOneWidget);
      expect(find.text('운영 공지'), findsOneWidget);
      expect(find.text('긴급 운영 공지'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, fixture.store.close());
    },
  );

  testWidgets('내 정보 shows support only when support fields are present', (
    tester,
  ) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await fixture.session.finishOnboarding();
    });
    final configStore = MutableConfigStore(
      config(
        rawConfig: {
          'support': {
            'kakaoChannel': '사입삼춘',
            'email': 'help@example.com',
            'phone': '',
            'hours': '평일 10:00-18:00',
          },
        },
      ),
    );
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
      config: configStore,
    );
    await tester.pumpWidget(
      AppScope(services: services, child: branded(const HomeShell())),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(TdsTextButton, '내 프로필'));
    await settle(tester);
    expect(find.text('고객센터'), findsOneWidget);
    expect(find.textContaining('help@example.com'), findsOneWidget);

    configStore.currentConfig = config();
    await settle(tester);
    expect(find.text('고객센터'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
