import 'dart:async';
import 'dart:convert';
import 'package:agent_uncle/remote/push_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'repositories_test.dart' show Harness, actor, peer, reply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/push');
  late Harness h;
  late PushNotifications push;
  late Map<String, Object?> device;
  Map<String, Object?>? tap;
  final calls = <String>[];
  Completer<http.Response>? registration;

  setUp(() async {
    calls.clear();
    tap = null;
    registration = null;
    device = {
      'id': 'device',
      'binding': 'binding',
      'token': 'token',
      'platform': 'ios',
      'enabled': true,
      'configured': true,
      'liveSupported': true,
      'liveEnabled': false,
    };
    h = Harness();
    h.onRequest = (request) async {
      if (!request.url.path.contains('push') &&
          !request.url.path.contains('activity')) {
        return null;
      }
      calls.add(request.url.path.split('/').last);
      if (request.url.path.endsWith('saip_register_push')) {
        expect(jsonDecode(request.body)['device']['binding'], 'binding');
        return registration?.future ?? reply('{}', 200);
      }
      return reply('{}', 200);
    };
    await h.open();
    await h.session.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'bind':
              return device;
            case 'takeTap':
              final value = tap;
              tap = null;
              return value;
            case 'clear':
              calls.add('native-clear');
              return null;
            case 'setLiveEnabled':
              device = {...device, 'liveEnabled': true};
              return null;
            case 'startActivity':
              calls.add('native-start');
              return null;
            default:
              return null;
          }
        });
    push = PushNotifications(h.session, channel: channel);
  });
  tearDown(() async {
    push.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await h.close();
  });
  test('같은 기기는 한 번 등록하고 토큰 변경 시 재등록한다', () async {
    await push.sync();
    await push.sync();
    expect(calls.where((c) => c == 'saip_register_push'), hasLength(1));
    device = {...device, 'token': 'rotated-token'};
    await push.sync();
    expect(calls.where((c) => c == 'saip_register_push'), hasLength(2));
  });
  test('다른 계정 및 오래된 바인딩 알림은 열지 않는다', () async {
    for (final value in [
      {'ownerId': peer, 'binding': 'binding'},
      {'ownerId': actor, 'binding': 'old-binding'},
    ]) {
      tap = value;
      await push.sync();
      expect(h.session.pendingDestination, isNull);
    }
    tap = {
      'ownerId': actor,
      'binding': 'binding',
      'kind': 'chat',
      'targetId': peer,
    };
    await push.sync();
    expect(h.session.pendingDestination?.s('targetId'), peer);
    expect(h.session.pendingDestination?.b('fromPush'), true);
  });
  test('로그아웃은 먼저 OS 바인딩을 지우고 서버 등록을 해제한다', () async {
    await push.sync();
    calls.clear();
    await push.clear();
    await push.sync();
    expect(calls, ['native-clear', 'saip_unregister_push']);
  });
  test('로그아웃 도중 완료된 등록도 다시 해제한다', () async {
    registration = Completer<http.Response>();
    final syncing = push.sync();
    while (!calls.contains('saip_register_push')) {
      await Future<void>.delayed(Duration.zero);
    }
    await push.clear();
    registration!.complete(reply('{}', 200));
    await syncing;
    expect(calls.last, 'saip_unregister_push');
    expect(calls.where((c) => c == 'saip_unregister_push'), hasLength(2));
  });
  test('Live Activity는 서버에서 준비한 후 네이티브에서 시작한다', () async {
    await push.sync();
    calls.clear();
    await push.startActivity('request');
    expect(calls, [
      'saip_register_push',
      'saip_prepare_activity',
      'native-start',
    ]);
  });
  test('Live Activity 시작은 진행 중인 기기 등록과 설정 반영을 기다린다', () async {
    registration = Completer<http.Response>();
    final syncing = push.sync();
    while (!calls.contains('saip_register_push')) {
      await Future<void>.delayed(Duration.zero);
    }
    final starting = push.startActivity('request');
    await Future<void>.delayed(Duration.zero);
    expect(calls, isNot(contains('saip_prepare_activity')));
    registration!.complete(reply('{}', 200));
    await Future.wait([syncing, starting]);
    expect(
      calls.indexOf('saip_prepare_activity'),
      greaterThan(calls.lastIndexOf('saip_register_push')),
    );
    expect(calls.last, 'native-start');
  });
}
