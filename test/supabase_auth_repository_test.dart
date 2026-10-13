import 'dart:convert';

import 'package:agent_uncle/core/config/supabase_config.dart';
import 'package:agent_uncle/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  group('SupabaseAuthRepository', () {
    late _Harness harness;
    late _FakeUrlLauncher launcher;

    setUp(() async {
      launcher = _FakeUrlLauncher();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        launcher.handle,
      );
      harness = await _Harness.open();
    });

    tearDown(() async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      );
      await harness.close();
    });

    test('Google 로그인 후 로그아웃하고 다시 로그인해도 계정 선택을 강제한다', () async {
      expect(await harness.repository.signInWithGoogle(), isTrue);

      final firstRequest = launcher.launchedUrls.single;
      expect(firstRequest.path, '/auth/v1/authorize');
      expect(firstRequest.queryParameters['provider'], 'google');
      expect(firstRequest.queryParameters['prompt'], 'select_account');
      expect(firstRequest.queryParameters['code_challenge'], isNotEmpty);
      expect(firstRequest.queryParameters['code_challenge_method'], 's256');
      expect(
        firstRequest.queryParameters['redirect_to'],
        kIsWeb
            ? SupabaseConfig.webAuthCallback
            : SupabaseConfig.mobileAuthCallback,
      );

      await harness.recoverSignedInSession();
      expect(harness.repository.currentUser?.email, 'test@example.test');

      await harness.repository.signOut();

      expect(harness.repository.currentUser, isNull);
      expect(harness.logoutRequests, hasLength(1));
      final logoutRequest = harness.logoutRequests.single;
      expect(logoutRequest.method, 'POST');
      expect(logoutRequest.url.path, '/auth/v1/logout');
      expect(logoutRequest.url.queryParameters['scope'], 'local');

      expect(await harness.repository.signInWithGoogle(), isTrue);
      expect(launcher.launchedUrls, hasLength(2));
      expect(harness.repository.currentUser, isNull);

      final secondRequest = launcher.launchedUrls.last;
      expect(secondRequest.queryParameters['provider'], 'google');
      expect(secondRequest.queryParameters['prompt'], 'select_account');
      expect(
        secondRequest.queryParameters['redirect_to'],
        kIsWeb
            ? SupabaseConfig.webAuthCallback
            : SupabaseConfig.mobileAuthCallback,
      );
    });

    test('Google 로그인 페이지를 열지 못하면 false를 반환하고 계정 선택 요청은 유지한다', () async {
      launcher.shouldSucceed = false;

      expect(await harness.repository.signInWithGoogle(), isFalse);

      final request = launcher.launchedUrls.single;
      expect(request.queryParameters['provider'], 'google');
      expect(request.queryParameters['prompt'], 'select_account');
    });

    test('카카오 로그인은 기존처럼 prompt를 추가하지 않는다', () async {
      expect(await harness.repository.signInWithKakao(), isTrue);

      final request = launcher.launchedUrls.single;
      expect(request.queryParameters['provider'], 'kakao');
      expect(request.queryParameters.containsKey('prompt'), isFalse);
      expect(
        request.queryParameters['redirect_to'],
        kIsWeb
            ? SupabaseConfig.webAuthCallback
            : SupabaseConfig.mobileAuthCallback,
      );
    });
  });
}

final class _Harness {
  _Harness._({
    required this.client,
    required this.repository,
    required this.logoutRequests,
  });

  final SupabaseClient client;
  final SupabaseAuthRepository repository;
  final List<http.BaseRequest> logoutRequests;

  static Future<_Harness> open() async {
    final logoutRequests = <http.BaseRequest>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.pkce,
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          logoutRequests.add(request);
          return http.Response('', 204, request: request);
        }

        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    return _Harness._(
      client: client,
      repository: SupabaseAuthRepository(client),
      logoutRequests: logoutRequests,
    );
  }

  Future<void> recoverSignedInSession() {
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': '11111111-1111-4111-8111-111111111111',
          'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
        }),
      ),
    );

    return client.auth.recoverSession(
      jsonEncode({
        'access_token': 'e30.$payload.signature',
        'refresh_token': 'refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': '11111111-1111-4111-8111-111111111111',
          'aud': 'authenticated',
          'email': 'test@example.test',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }

  Future<void> close() => client.dispose();
}

final class _MemoryAsyncStorage implements GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }
}

final class _FakeUrlLauncher {
  final launchedUrls = <Uri>[];
  bool shouldSucceed = true;

  Future<bool> handle(MethodCall call) async {
    if (call.method != 'launch') {
      throw StateError('예상하지 못한 URL 런처 호출: ${call.method}');
    }
    launchedUrls.add(Uri.parse((call.arguments as Map)['url'] as String));
    return shouldSucceed;
  }
}
