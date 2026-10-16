import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/convenience_models.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/billing.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/favorite_wholesaler_picker.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/team_work.dart';
import 'package:agent_uncle/local/presentation/update_notice.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

const _channel = MethodChannel('agent_uncle/app_release');

Future<void> _putRecord(
  WidgetTester tester,
  Fixture fixture,
  String table,
  String id,
  Data data,
) async {
  // 화면 동작이 시작한 저장 큐는 위젯 테스트의 가상 시계에서 완료된다.
  // 실제 비동기 작업과 예약된 프레임을 함께 진행시켜 그 큐를 기다린다.
  var completed = false;
  final writing = () async {
    final actor = fixture.session.current!.id;
    await fixture.store.write(actor, '', (state) {
      state.put(table, id, data);
      return id;
    });
    await fixture.store.reload();
    completed = true;
  }();
  for (var attempt = 0; attempt < 100 && !completed; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(completed, isTrue, reason: '화면 저장 큐 이후 테스트 레코드 갱신이 완료되어야 한다');
  await writing;
}

Future<AppServices> _startServices(WidgetTester tester, Fixture fixture) async {
  await tester.runAsync(() async {
    await fixture.start();
    await fixture.session.finishOnboarding();
  });
  final services = AppServices(
    session: fixture.session,
    workspace: fixture.workspace,
    attachments: fixture.attachments,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
  return services;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  testWidgets('즐겨찾기 다중 선택은 여러 도매처를 review 로 반환한다', (tester) async {
    final fixture = Fixture();
    final services = await _startServices(tester, fixture);
    await tester.runAsync(() async {
      await fixture.workspace.upsertFavoriteWholesaler({
        'favoriteId': 'favorite-1',
        'wholesaler': '남평화',
        'location': 'A열',
        'paymentMode': 'advance',
      });
      await fixture.workspace.upsertFavoriteWholesaler({
        'favoriteId': 'favorite-2',
        'wholesaler': '디자이너클럽',
        'location': '3층',
        'paymentMode': 'direct',
      });
    });

    Future<List<Data>?>? pickerFuture;
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          Builder(
            builder: (context) => PageFrame(
              title: '호출',
              children: [
                ActionButton(
                  '열기',
                  onPressed: () {
                    pickerFuture = openPage<List<Data>>(
                      context,
                      const FavoriteWholesalerPicker(initialRows: []),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    await tapButton(tester, '열기');
    await settle(tester);
    await tester.tap(find.byType(TdsCheckbox).at(0));
    await settle(tester);
    await tester.tap(find.byType(TdsCheckbox).at(1));
    await settle(tester);
    await tapButton(tester, '선택한 도매처 추가');
    await settle(tester);

    final selected = await tester.runAsync(() async => await pickerFuture!);
    final rows = selected ?? const <Data>[];
    expect(selected, isNotNull);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['paymentMode']).toSet(), {
      conveniencePaymentModeReview,
    });
  });

  testWidgets('업데이트 공지는 버전별 숨김을 유지하고 새 빌드에서 다시 보여 준다', (tester) async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'info') {
        return {'platform': 'android', 'version': '1.0.0', 'buildNumber': 10};
      }
      return true;
    });
    final fixture = Fixture();
    final services = await _startServices(tester, fixture);
    await _putRecord(tester, fixture, 'appReleases', 'release-android', {
      'public': true,
      'published': true,
      'publishedAt': '2026-10-14T12:00:00Z',
      'roles': ['retailer'],
      'title': '11번 빌드 업데이트',
      'body': '새로운 결제 흐름이 추가됐어요.',
      'platform': 'android',
      'versionName': '1.1.0',
      'buildNumber': 11,
      'storeUrl':
          'https://play.google.com/store/apps/details?id=com.agent.uncle',
      'readers': [fixture.retailer],
    });
    await _putRecord(tester, fixture, 'appReleases', 'release-hidden', {
      'public': true,
      'published': true,
      'publishedAt': '2026-10-14T12:00:00Z',
      'roles': ['uncle'],
      'title': '숨겨져야 하는 공지',
      'platform': 'android',
      'versionName': '9.9.9',
      'buildNumber': 99,
      'storeUrl':
          'https://play.google.com/store/apps/details?id=com.agent.uncle',
      'readers': [fixture.retailer],
    });

    await tester.pumpWidget(
      AppScope(services: services, child: branded(const UpdateNotice())),
    );
    await settle(tester);

    expect(find.text('11번 빌드 업데이트'), findsOneWidget);
    expect(find.text('숨겨져야 하는 공지'), findsNothing);

    await tapButton(tester, '나중에 보기');
    await settle(tester);
    expect(find.text('11번 빌드 업데이트'), findsNothing);
    expect(
      fixture.workspace.workflowInput(
        convenienceUpdateDismissalsKey,
      )['dismissedKeys'],
      contains('android:11:available'),
    );

    await _putRecord(
      tester,
      fixture,
      'appReleases',
      'release-android-duplicate',
      {
        'public': true,
        'published': true,
        'title': '중복 등록된 11번 빌드',
        'platform': 'android',
        'buildNumber': 11,
        'storeUrl':
            'https://play.google.com/store/apps/details?id=com.agent.uncle',
        'readers': [fixture.retailer],
      },
    );
    await tester.pumpWidget(
      AppScope(services: services, child: branded(const UpdateNotice())),
    );
    await settle(tester);
    expect(find.text('중복 등록된 11번 빌드'), findsNothing);

    await _putRecord(tester, fixture, 'appReleases', 'release-android', {
      'public': true,
      'published': true,
      'publishedAt': '2026-10-14T12:00:00Z',
      'roles': ['retailer'],
      'title': '12번 빌드 업데이트',
      'body': '새 회차 기능이 추가됐어요.',
      'platform': 'android',
      'versionName': '1.2.0',
      'buildNumber': 12,
      'storeUrl':
          'https://play.google.com/store/apps/details?id=com.agent.uncle',
      'readers': [fixture.retailer],
    });
    await tester.pumpWidget(
      AppScope(services: services, child: branded(const UpdateNotice())),
    );
    await settle(tester);
    expect(find.text('12번 빌드 업데이트'), findsOneWidget);
  });

  testWidgets('설치 안내는 같은 빌드만 보여 주고 더 낮은 빌드는 무시한다', (tester) async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'info') {
        return {'platform': 'ios', 'version': '2.0.0', 'buildNumber': 20};
      }
      return true;
    });
    final fixture = Fixture();
    final services = await _startServices(tester, fixture);
    await _putRecord(tester, fixture, 'appReleases', 'release-old', {
      'public': true,
      'published': true,
      'publishedAt': '2026-10-14T12:00:00Z',
      'roles': ['retailer'],
      'title': '낡은 설치 안내',
      'platform': 'ios',
      'versionName': '1.9.0',
      'buildNumber': 19,
      'readers': [fixture.retailer],
    });
    await _putRecord(tester, fixture, 'appReleases', 'release-current', {
      'public': true,
      'published': true,
      'publishedAt': '2026-10-14T12:00:00Z',
      'roles': ['retailer'],
      'title': '이번 버전 안내',
      'platform': 'ios',
      'versionName': '2.0.0',
      'buildNumber': 20,
      'readers': [fixture.retailer],
    });

    await tester.pumpWidget(
      AppScope(services: services, child: branded(const UpdateNotice())),
    );
    await settle(tester);

    expect(find.text('이번 버전 안내'), findsOneWidget);
    expect(find.text('낡은 설치 안내'), findsNothing);
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('iOS 미공개 빌드는 공통 버전 정보가 있어도 업데이트로 표시하지 않는다', (tester) async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'info') {
        return {'platform': 'ios', 'version': '1.0.0', 'buildNumber': 10};
      }
      return true;
    });
    final fixture = Fixture();
    final services = await _startServices(tester, fixture);
    for (final entry in {
      'absent-ios': <String, Object?>{
        'android': {'buildNumber': 20},
      },
      'private-ios': <String, Object?>{
        'ios': {'public': false, 'buildNumber': 20},
        'android': {'buildNumber': 20},
      },
    }.entries) {
      await _putRecord(tester, fixture, 'appReleases', entry.key, {
        'public': true,
        'published': true,
        'title': entry.key,
        'buildNumber': 20,
        'storeUrl': 'https://apps.apple.com/app/id123456789',
        'platforms': entry.value,
        'readers': [fixture.retailer],
      });
    }
    await tester.pumpWidget(
      AppScope(services: services, child: branded(const UpdateNotice())),
    );
    await settle(tester);
    expect(find.text('absent-ios'), findsNothing);
    expect(find.text('private-ios'), findsNothing);
    expect(find.text('업데이트'), findsNothing);
  });

  testWidgets('요청 상세는 현장 지급과 팀 업무 페이지로 각각 이동한다', (tester) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      final requestId = await fixture.request();
      await fixture.accept(requestId);
      await fixture.session.signIn(fixture.uncle);
      await fixture.store.write(fixture.uncle, '', (state) {
        final current = Map<String, Object?>.from(
          state.require('requests', requestId),
        );
        state.put('requests', requestId, {
          ...current,
          'receivingShop': '가게앞 수령',
          'destinationOverride': true,
          'roundLabel': '야간 1회차',
          'version': numberOf(current, 'version') + 1,
        });
        return requestId;
      });
      await fixture.store.reload();
    });
    final requestId = fixture.workspace.records('requests').first.id;
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, fixture.store.close());
    });

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(RequestDetailPage(requestId)),
      ),
    );
    await settle(tester);
    expect(find.text('수령 상호'), findsOneWidget);
    expect(find.text('영업 회차'), findsOneWidget);

    await tester.ensureVisible(find.text('현장 지급 기록'));
    await tester.tap(find.text('현장 지급 기록'));
    await settle(tester);
    expect(find.byType(FieldPaymentPage), findsOneWidget);

    await tester.tap(find.byType(TdsTopNavigationBackButton));
    await settle(tester);
    await tester.ensureVisible(find.text('팀 업무 보기'));
    await tester.tap(find.text('팀 업무 보기'));
    await settle(tester);
    expect(find.byType(PickupRequestWorkPage), findsOneWidget);
  });
}
