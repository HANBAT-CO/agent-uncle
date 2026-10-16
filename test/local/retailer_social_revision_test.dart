import 'dart:typed_data';

import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;

class _RetailerSocialFixture {
  late LocalStore store;
  late LocalSessionRepository session;
  late LocalWorkspaceRepository workspace;
  late LocalAttachmentRepository attachments;
  late AppServices services;
  late String retailer;
  late String uncle;

  Future<void> start({
    bool acceptedConnection = false,
    bool pendingConnection = false,
  }) async {
    store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
    await store.initialize();
    session = LocalSessionRepository(store);
    workspace = LocalWorkspaceRepository(store, session);
    attachments = LocalAttachmentRepository(store, session, workspace);
    services = AppServices(
      session: session,
      workspace: workspace,
      attachments: attachments,
    );
    retailer = await _account('소매 매장', AppRole.retailer);
    uncle = await _account('사입 업체', AppRole.uncle);
    await session.signIn(retailer);
    if (acceptedConnection || pendingConnection) {
      final connection = await workspace.connect(uncle, newId());
      if (acceptedConnection) {
        await session.signIn(uncle);
        await workspace.respondConnection(connection, 'accepted', 0, newId());
        await session.signIn(retailer);
      }
    }
    await session.finishOnboarding();
  }

  Future<String> _account(String label, AppRole role) async {
    final id = await session.createAccount(label);
    await session.chooseRole(role);
    final file = await attachments.save(
      '사업자.pdf',
      Uint8List.fromList([37, 80, 68, 70]),
      'application/pdf',
    );
    await session.saveProfile({
      'name': label,
      'contact': role == AppRole.uncle ? label : '담당자',
      'phone': role == AppRole.uncle ? '01087654321' : '01012345678',
      'bankName': '우리은행',
      'bankAccount': '123-456-789012',
      'bankHolder': '테스트 담당자',
      'businessName': label,
      'businessNumber': '1234567890',
      'documentId': file,
      'address': '서울시 중구',
      'addressDetail': '101호',
      'pickupArea': '동대문 1층',
      'deliveryArea': '서울',
      'deadline': '22:00',
      'salesChannel': '온라인',
      'terms': true,
      'privacy': true,
    }, complete: true);
    return id;
  }

  Future<void> close() async {
    services.dispose();
    await store.close();
  }
}

void main() {
  testWidgets('소매업자 사입삼촌 탭 빈 상태 CTA가 연결 페이지를 연다', (tester) async {
    final fixture = _RetailerSocialFixture();
    await tester.runAsync(() => fixture.start());

    await tester.pumpWidget(
      AppScope(
        services: fixture.services,
        child: branded(const ConnectionsList()),
      ),
    );
    await settle(tester);

    expect(find.text('아직 함께하는 사입삼촌이 없어요'), findsOneWidget);
    expect(find.widgetWithText(TdsButton, '거래처 연결하기'), findsOneWidget);

    await tester.tap(find.widgetWithText(TdsButton, '거래처 연결하기'));
    await settle(tester);

    expect(find.byType(AddConnectionPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, fixture.close());
  });

  testWidgets('소매업자 사입삼촌 탭은 검색 빈 상태와 대기 탭에서 CTA를 노출하지 않는다', (tester) async {
    final connected = _RetailerSocialFixture();
    await tester.runAsync(() => connected.start(acceptedConnection: true));

    await tester.pumpWidget(
      AppScope(
        services: connected.services,
        child: branded(const ConnectionsList()),
      ),
    );
    await settle(tester);

    await tester.enterText(find.byType(EditableText).first, '없는 사입삼촌');
    await settle(tester);

    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(find.text('거래처 연결하기'), findsNothing);
    expect(find.text('사입삼촌 이름을 다시 확인해 주세요.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, connected.close());

    final empty = _RetailerSocialFixture();
    await tester.runAsync(() => empty.start());

    await tester.pumpWidget(
      AppScope(
        services: empty.services,
        child: branded(const ConnectionsList()),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('연결 대기 0'));
    await settle(tester);

    expect(find.text('기다리는 연결 요청이 없어요'), findsOneWidget);
    expect(find.text('거래처 연결하기'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, empty.close());
  });

  testWidgets('소매업자 채팅 빈 상태는 기존 연결 안내 문구를 노출하지 않는다', (tester) async {
    final fixture = _RetailerSocialFixture();
    await tester.runAsync(() => fixture.start());

    await tester.pumpWidget(
      AppScope(services: fixture.services, child: branded(const ChatList())),
    );
    await settle(tester);

    expect(find.text('대화할 사입삼촌이 없어요'), findsOneWidget);
    expect(find.text('거래처 연결을 수락하면 1:1 채팅을 시작할 수 있어요.'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await drainClose(tester, fixture.close());
  });
}
