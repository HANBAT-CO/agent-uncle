import 'package:agent_uncle/core/legal/legal_documents.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('agent_uncle/legal_documents');

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('네이티브 브라우저의 실행 실패를 전달한다', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => false,
    );
    expect(await LegalDocument.terms.open(), isFalse);
  });

  test('플랫폼 오류를 열기 실패로 처리한다', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await LegalDocument.privacy.open(), isFalse);
  });

  test('채널이 없는 환경도 처리하지 않은 예외를 발생시키지 않는다', () async {
    expect(await LegalDocument.terms.open(), isFalse);
  });
}
