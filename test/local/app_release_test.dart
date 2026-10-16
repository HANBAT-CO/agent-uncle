import 'package:agent_uncle/core/app_release.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('agent_uncle/app_release');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('설치 버전은 네이티브 메타데이터를 사용한다', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'platform': 'ios',
        'version': '2.3.4',
        'buildNumber': 39,
      },
    );
    final installed = await readInstalledAppRelease();
    expect(installed?.platform, 'ios');
    expect(installed?.version, '2.3.4');
    expect(installed?.buildNumber, 39);
  });

  test('설치 정보를 읽지 못하거나 잘못된 값이면 버전을 추정하지 않는다', () async {
    expect(await readInstalledAppRelease(), isNull);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'platform': 'android',
        'version': '1.0',
        'buildNumber': 'unknown',
      },
    );
    expect(await readInstalledAppRelease(), isNull);
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await readInstalledAppRelease(), isNull);
  });

  test('플랫폼의 공식 스토어 상세 링크만 허용한다', () {
    expect(
      isOfficialStoreUrl('https://apps.apple.com/kr/app/example/id123', 'ios'),
      isTrue,
    );
    expect(
      isOfficialStoreUrl(
        'https://play.google.com/store/apps/details?id=com.example.app',
        'android',
      ),
      isTrue,
    );
    for (final url in [
      'http://apps.apple.com/kr/app/example/id123',
      'https://apps.apple.com.evil.test/kr/app/example/id123',
      'https://user@apps.apple.com/kr/app/example/id123',
      'https://apps.apple.com:8443/kr/app/example/id123',
      'https://apps.apple.com/kr/app/example/id123#redirect',
      'https://apps.apple.com/search',
      'https://play.google.com/store/apps/details?id=com.example.app',
    ]) {
      expect(isOfficialStoreUrl(url, 'ios'), isFalse, reason: url);
    }
    expect(
      isOfficialStoreUrl(
        'https://play.google.com/store/apps/details',
        'android',
      ),
      isFalse,
    );
  });

  test('열기 실패는 false로 반환하고 허용되지 않는 링크는 네이티브로 보내지 않는다', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      throw PlatformException(code: 'unavailable');
    });
    expect(await openOfficialAppStore('https://evil.test', 'ios'), isFalse);
    expect(calls, 0);
    expect(
      await openOfficialAppStore(
        'https://apps.apple.com/kr/app/example/id123',
        'ios',
      ),
      isFalse,
    );
    expect(calls, 1);
  });
}
