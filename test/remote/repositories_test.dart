import 'dart:async';
import 'dart:convert';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/remote/remote_session.dart';
import 'package:agent_uncle/remote/remote_store.dart';
import 'package:agent_uncle/remote/remote_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const actor = '11111111-1111-4111-8111-111111111111';
http.Response reply(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json'},
  request: http.Request(
    'POST',
    Uri.parse('https://example.supabase.co/rest/v1/rpc/test'),
  ),
);

const peer = '22222222-2222-4222-8222-222222222222';

class Harness {
  Future<http.Response?> Function(http.Request)? onRequest;
  late SupabaseClient client;
  late RemoteStore store;
  late RemoteSessionRepository session;
  late RemoteWorkspaceRepository workspace;
  bool failRead = false, failWrite = false;
  String authUserId = actor;
  Completer<http.Response>? pendingWorkflow;
  http.Response? workflowResponse;
  bool phoneAvailable = true;
  http.Response? phoneResponse;
  http.Response? deletionResponse;
  Completer<http.Response>? pendingDeletion;
  int deletionCalls = 0;
  Completer<http.Response>? pendingRead;
  Map<String, dynamic> lookupCodeRow = {
    'id': peer,
    'data': {
      'name': '동대문 삼촌',
      'nickname': '삼촌',
      'publicCode': '#4321',
      'role': 'uncle',
      'complete': true,
    },
  };
  List<Map<String, dynamic>> partnerRows = [
    {
      'id': peer,
      'data': {
        'name': '동대문 삼촌',
        'nickname': '삼촌',
        'publicCode': '#4321',
        'role': 'uncle',
        'complete': true,
        'pickupArea': '동대문',
        'deliveryArea': '서울',
        'fee': 1200,
      },
    },
  ];
  final commands = <Map<String, dynamic>>[];
  Map<String, dynamic> tables = {
    'accounts': {
      actor: {'name': '테스트', 'role': 'retailer', 'complete': true},
    },
    'requests': <String, dynamic>{},
    'messages': <String, dynamic>{},
  };
  Future<void> open() async {
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: MockClient((request) async {
        final intercepted = await onRequest?.call(request);
        if (intercepted != null) return intercepted;
        final data = request.body.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(request.body) as Map<String, dynamic>? ??
                  <String, dynamic>{});
        if (request.url.path == '/auth/v1/token') {
          final jwt =
              'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': authUserId, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
          return reply(
            jsonEncode({
              'access_token': jwt,
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': authUserId,
                'aud': 'authenticated',
                'email': 'test@example.test',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('saip_command')) {
          commands.add(data);
          if ((data['command'] as String).startsWith('wf.')) {
            if (pendingWorkflow != null) return pendingWorkflow!.future;
            if (workflowResponse != null) return workflowResponse!;
          }
          if (failWrite) {
            return reply('{"code":"P0001","message":"전송 실패"}', 400);
          }
          return reply(jsonEncode((data['args'] as Map)['id'] ?? actor), 200);
        }
        if (request.url.path.endsWith('/delete-account')) {
          deletionCalls++;
          expect(data, {'confirm': true});
          return pendingDeletion?.future ??
              deletionResponse ??
              reply('{"deleted":true}', 200);
        }
        if (request.url.path.endsWith('saip_snapshot')) {
          if (pendingRead != null) return pendingRead!.future;
          if (failRead) return reply('{"code":"P0001","message":"연결 실패"}', 400);
          return reply(jsonEncode(tables), 200);
        }
        if (request.url.path.endsWith('saip_check_phone_available')) {
          return phoneResponse ?? reply(jsonEncode(phoneAvailable), 200);
        }
        if (request.url.path.endsWith('saip_search_partners')) {
          return reply(jsonEncode(partnerRows), 200);
        }
        if (request.url.path.endsWith('saip_lookup_code')) {
          return reply(jsonEncode(lookupCodeRow), 200);
        }
        return reply('{}', 200);
      }),
    );
    await client.auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
    store = RemoteStore(
      client,
      await databaseFactoryMemory.openDatabase('remote-${newId()}'),
      liveUpdates: false,
    );
    await store.initialize();
    session = RemoteSessionRepository(store);
    workspace = RemoteWorkspaceRepository(store);
    await store.changeUser();
    expect(store.error, isNull);
  }

  Future<void> close() async {
    workspace.dispose();
    session.dispose();
    await store.device.close();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('연결 거래처의 계좌는 숨기고 본인 계좌만 보여 준다', () async {
    final h = Harness();
    final bank = {
      'bankName': '테스트은행',
      'bankAccount': '123456789012',
      'bankHolder': '예금주',
    };
    (h.tables['accounts'] as Map)[actor].addAll(bank);
    (h.tables['accounts'] as Map)[peer] = {
      'role': 'uncle',
      'complete': true,
      ...bank,
    };
    h.tables['connections'] = {
      'c': {'from': actor, 'to': peer, 'status': 'accepted'},
    };
    await h.open();
    addTearDown(h.close);
    for (final key in bank.keys) {
      expect(h.workspace.profile(actor)!.s(key), bank[key]);
      expect(h.workspace.profile(peer)!.s(key), '');
      expect(h.workspace.partners.single.s(key), '');
    }
  });
  test('a committed command remains successful when refresh fails', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    h.failRead = true;
    expect(
      await h.store.command('sendDraft', {'id': 'req-1'}, 'operation-1'),
      'req-1',
    );
    expect(h.store.error, '연결 실패');
    expect(
      h.commands.where((c) => c['operation_id'] == 'operation-1'),
      hasLength(1),
    );
  });
  test('failed message persists and retry preserves ID and contents', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    h.failWrite = true;
    await expectLater(
      h.workspace.sendMessage(peer, 'message-1', '안녕하세요', []),
      throwsA(isA<AppFailure>()),
    );
    expect(h.workspace.records('messages').single.s('status'), 'failed');
    expect(
      (await h.store.outbox.find(h.store.device)).single.value['senderId'],
      actor,
    );
    final failed = h.commands.last;
    h.failWrite = false;
    h.tables['messages'] = {
      'message-1': {
        'senderId': actor,
        'recipientId': peer,
        'body': '안녕하세요',
        'status': 'sent',
      },
    };
    await h.workspace.sendMessage(peer, 'message-1', '안녕하세요', []);
    expect(h.commands.last, failed);
    expect(await h.store.outbox.find(h.store.device), isEmpty);
    expect(h.workspace.records('messages').single.s('status'), 'sent');
  });
  test('late network response cannot restore data after sign-out', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    h.pendingRead = Completer<http.Response>();
    final pending = h.store.refresh();
    await Future<void>.delayed(Duration.zero);
    await h.client.auth.signOut(scope: SignOutScope.local);
    await h.store.changeUser();
    h.pendingRead!.complete(
      reply(
        jsonEncode({
          'requests': {
            'secret': {'retailerId': actor},
          },
        }),
        200,
      ),
    );
    await pending;
    expect(h.store.snapshot.tables, isEmpty);
    expect(h.workspace.records('requests'), isEmpty);
  });
  test(
    'checkPhoneAvailable forwards to RPC and returns the boolean only',
    () async {
      final h = Harness();
      await h.open();
      addTearDown(h.close);
      h.phoneAvailable = false;
      expect(await h.session.checkPhoneAvailable('+82 10 1234 5678'), isFalse);
      h.phoneAvailable = true;
      expect(await h.session.checkPhoneAvailable('010-9999-8888'), isTrue);
    },
  );
  test(
    'searchPartners forwards filters and parses public partner rows',
    () async {
      final h = Harness();
      await h.open();
      addTearDown(h.close);
      final rows = await h.workspace.searchPartners(
        query: '#4321',
        region: '동대문',
        minFee: 1000,
        maxFee: 1500,
        limit: 10,
        offset: 2,
      );
      expect(rows, hasLength(1));
      expect(rows.single.id, peer);
      expect(rows.single.publicCode, '#4321');
      expect(rows.single.fee, 1200);
    },
  );
  test(
    'connect sends only peerId so directory search results can connect directly',
    () async {
      final h = Harness();
      await h.open();
      addTearDown(h.close);
      await h.workspace.connect(peer, 'connect-op');
      expect(h.commands.last['args'], {'peerId': peer});
      expect(h.commands.last['command'], 'connect');
    },
  );
}
