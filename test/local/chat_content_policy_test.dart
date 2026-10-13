import 'dart:convert';
import 'dart:io';

import 'package:agent_uncle/local/domain/chat_content_policy.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases =
      jsonDecode(
            File('test/fixtures/chat_content_cases.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final body in (cases['blocked'] as List).cast<String>()) {
    test('비속어·우회 표현 차단: ${jsonEncode(body)}', () {
      expect(ChatContentPolicy.containsProfanity(body), isTrue);
    });
  }
  for (final body in (cases['allowed'] as List).cast<String>()) {
    test('정상 문장 허용: ${jsonEncode(body)}', () {
      expect(ChatContentPolicy.containsProfanity(body), isFalse);
    });
  }

  test('사진만 보낼 수 있지만 빈 메시지와 비속어가 있는 사진 메시지는 거절한다', () {
    expect(() => ChatContentPolicy.validate('', ['photo']), returnsNormally);
    expect(
      () => ChatContentPolicy.validate('   ', []),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => ChatContentPolicy.validate('시1발', ['photo']),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          ChatContentPolicy.rejectionMessage,
        ),
      ),
    );
  });

  test('최대 길이는 서버와 동일하게 유니코드 코드 포인트로 계산한다', () {
    expect(() => ChatContentPolicy.validate('😀' * 10000, []), returnsNormally);
    expect(
      () => ChatContentPolicy.validate('a' * 10001, []),
      throwsA(isA<AppFailure>()),
    );
  });

  test('긴 구분자·반복 글자 및 끝에 붙인 비속어도 검사한다', () {
    expect(ChatContentPolicy.containsProfanity('f${'*' * 9000}ck'), isTrue);
    expect(ChatContentPolicy.containsProfanity('f${'u' * 9000}ck'), isTrue);
    expect(ChatContentPolicy.containsProfanity('${'상품 ' * 3000}시1발'), isTrue);
    expect(
      ChatContentPolicy.containsProfanity('a${' ' * 9000}shipping'),
      isFalse,
    );
  });

  test('치환 문자와 구분자를 교차 반복해도 검사 시간이 폭증하지 않는다', () {
    final watch = Stopwatch()..start();
    expect(ChatContentPolicy.containsProfanity('*+' * 4500), isFalse);
    expect(ChatContentPolicy.containsProfanity('${'*+' * 4500}hx'), isFalse);
    expect(ChatContentPolicy.containsProfanity('a${'*+' * 4500}hole'), isTrue);
    expect(ChatContentPolicy.containsProfanity('f${'12!*+' * 1800}ck'), isTrue);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
