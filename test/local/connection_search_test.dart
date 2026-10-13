import 'dart:async';

import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/connection_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;

class _SearchRequest {
  _SearchRequest(
    this.query,
    this.region,
    this.minFee,
    this.maxFee,
    this.limit,
    this.offset,
  );
  final String query, region;
  final int? minFee, maxFee;
  final int limit, offset;
  final result = Completer<List<Account>>();
}

class _DirectoryWorkspace extends LocalWorkspaceRepository {
  _DirectoryWorkspace(super.store, super.session);

  final calls = <_SearchRequest>[];
  List<Account> directory = [];
  bool delaySearch = false;

  @override
  Future<List<Account>> searchPartners({
    String query = '',
    String region = '',
    int? minFee,
    int? maxFee,
    int limit = 20,
    int offset = 0,
  }) {
    final call = _SearchRequest(query, region, minFee, maxFee, limit, offset);
    calls.add(call);
    if (!delaySearch) {
      call.result.complete(directory.skip(offset).take(limit).toList());
    }
    return call.result.future;
  }
}

class _DirectoryFixture {
  late LocalStore store;
  late LocalSessionRepository session;
  late _DirectoryWorkspace workspace;
  late AppServices services;

  static const peer = Account('peer', {
    'name': '김삼촌',
    'nickname': '동대문 파트너',
    'publicCode': '#0002',
    'role': 'uncle',
    'complete': true,
    'pickupArea': '동대문',
    'fee': 500,
  });

  Future<void> start() async {
    store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
    await store.initialize();
    session = LocalSessionRepository(store);
    workspace = _DirectoryWorkspace(store, session);
    services = AppServices(
      session: session,
      workspace: workspace,
      attachments: LocalAttachmentRepository(store, session, workspace),
    );
    await store.write('', '', (state) {
      state.put('accounts', 'me', {
        'name': '소매 매장',
        'role': 'retailer',
        'complete': true,
        'publicCode': '#0001',
        'code': 'MY-INVITE',
        'codeExpires': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });
      state.put('accounts', peer.id, {
        ...peer.data,
        'code': 'PARTNER-INVITE',
        'codeExpires': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });
      state.put('settings', 'session', {'accountId': 'me'});
      return '';
    });
  }

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(services: services, child: branded(const AddConnectionPage())),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, store.close());
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.widgetWithText(TdsButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

void main() {
  testWidgets('더 보기는 마지막 적용한 검색 조건을 유지하고 새 필터는 처음부터 검색한다', (tester) async {
    final fixture = _DirectoryFixture();
    await tester.runAsync(fixture.start);
    fixture.workspace.directory = List.generate(
      21,
      (index) => Account('directory-$index', {
        'name': '검색 삼촌 $index',
        'publicCode': '#${index.toString().padLeft(4, '0')}',
        'role': 'uncle',
        'complete': true,
      }),
    );
    await fixture.show(tester);
    await tester.ensureVisible(find.text('지역·수수료 필터'));
    await tester.tap(find.text('지역·수수료 필터'));
    await settle(tester);
    final region = find.descendant(
      of: find.widgetWithText(TdsTextField, '활동 지역'),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(region);
    await tester.enterText(region, '서울');
    await _tap(tester, '더 보기');
    expect(fixture.workspace.calls.last.region, isEmpty);
    expect(fixture.workspace.calls.last.offset, 20);
    expect(find.text('검색 삼촌 20'), findsOneWidget);

    await _tap(tester, '필터 적용');
    expect(fixture.workspace.calls.last.region, '서울');
    expect(fixture.workspace.calls.last.offset, 0);
    expect(tester.takeException(), isNull);
    await fixture.close(tester);
  });

  testWidgets('검색어가 바뀐 뒤 도착한 이전 검색 응답은 목록을 덮어쓰지 않는다', (tester) async {
    final fixture = _DirectoryFixture();
    await tester.runAsync(fixture.start);
    await fixture.show(tester);
    fixture.workspace.delaySearch = true;
    final search = find.descendant(
      of: find.byKey(const ValueKey('partner-search')),
      matching: find.byType(EditableText),
    );

    await tester.ensureVisible(search);
    await tester.enterText(search, '먼저');
    await tester.pump(const Duration(milliseconds: 400));
    final old = fixture.workspace.calls.last;
    await tester.enterText(search, '나중');
    await tester.pump(const Duration(milliseconds: 400));
    final latest = fixture.workspace.calls.last;
    expect(old.query, '먼저');
    expect(latest.query, '나중');

    latest.result.complete([_DirectoryFixture.peer]);
    await tester.pump();
    old.result.complete([
      const Account('old-peer', {
        'name': '지난 결과',
        'publicCode': '#0003',
        'role': 'uncle',
      }),
    ]);
    await tester.pump();
    expect(find.text('동대문 파트너'), findsOneWidget);
    expect(find.text('지난 결과'), findsNothing);
    expect(tester.takeException(), isNull);
    await fixture.close(tester);
  });

  testWidgets('초대코드 버튼으로 복사하고 붙여넣은 코드로 상대방을 조회한다', (tester) async {
    final fixture = _DirectoryFixture();
    await tester.runAsync(fixture.start);
    String clipboard = 'PARTNER-INVITE';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await fixture.show(tester);

    await tester.ensureVisible(find.text('초대코드'));
    await tester.tap(find.text('초대코드'));
    await settle(tester);
    await _tap(tester, '붙여넣기');
    final field = tester.widget<TdsTextField>(
      find.byKey(const ValueKey('partner-invite-code')),
    );
    expect(field.controller!.text, 'PARTNER-INVITE');
    await _tap(tester, '상대방 확인');
    expect(find.text('동대문 파트너'), findsOneWidget);

    await _tap(tester, '초대 코드 복사');
    expect(clipboard, 'MY-INVITE');
    expect(tester.takeException(), isNull);
    await fixture.close(tester);
  });

  testWidgets('연결 요청 거절 후 다시 요청하면 새 요청을 만들고 수락을 기다린다', (tester) async {
    final fixture = _DirectoryFixture();
    await tester.runAsync(fixture.start);
    fixture.workspace.directory = [_DirectoryFixture.peer];
    await fixture.show(tester);

    await _tap(tester, '거래 요청 보내기');
    final previous = fixture.workspace.records('connections').single;
    expect(find.text('수락 대기 중'), findsOneWidget);
    expect(fixture.workspace.partners, isEmpty);
    await tester.runAsync(() async {
      await fixture.session.signIn('peer');
      await fixture.workspace.respondConnection(
        previous.id,
        'rejected',
        previous.version,
        newId(),
      );
      await fixture.session.signIn('me');
    });
    await settle(tester);
    await _tap(tester, '거래 요청 보내기');

    final requests = fixture.workspace.records('connections');
    expect(requests, hasLength(2));
    expect(
      requests.where((record) => record.s('status') == 'pending'),
      hasLength(1),
    );
    expect(find.text('수락 대기 중'), findsOneWidget);
    expect(fixture.workspace.partners, isEmpty);
    expect(tester.takeException(), isNull);
    await fixture.close(tester);
  });
}
