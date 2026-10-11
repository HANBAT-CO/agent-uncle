import 'dart:async';
import 'dart:convert';
import 'package:agent_uncle/local/domain/models.dart';
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
  late SupabaseClient client;
  late RemoteStore store;
  late RemoteWorkspaceRepository workspace;
  bool failRead = false, failWrite = false;
  Completer<http.Response>? pendingRead;
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
        final data = request.body.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(request.body) as Map<String, dynamic>? ??
                  <String, dynamic>{});
        if (request.url.path == '/auth/v1/token') {
          final jwt =
              'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': actor, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
          return reply(
            jsonEncode({
              'access_token': jwt,
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': actor,
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
          if (failWrite) {
            return reply('{"code":"P0001","message":"전송 실패"}', 400);
          }
          return reply(jsonEncode((data['args'] as Map)['id'] ?? actor), 200);
        }
        if (request.url.path.endsWith('saip_snapshot')) {
          if (pendingRead != null) return pendingRead!.future;
          if (failRead) return reply('{"code":"P0001","message":"연결 실패"}', 400);
          return reply(jsonEncode(tables), 200);
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
    workspace = RemoteWorkspaceRepository(store);
    await store.changeUser();
    expect(store.error, isNull);
  }

  Future<void> close() async {
    workspace.dispose();
    store.dispose();
    await store.device.close();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
}
