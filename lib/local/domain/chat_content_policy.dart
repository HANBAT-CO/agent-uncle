import 'chat_filter_data.dart';
import 'models.dart';

/// 채팅 본문만 검사한다. 정규화한 문자열은 저장하거나 상대방에게 전송하지 않는다.
abstract final class ChatContentPolicy {
  static const rejectionMessage = chatRejectionMessage;
  static const maxLength = 10000;

  static final _folds = <int, String>{
    for (final entry in chatFoldGroups.entries)
      for (final rune in entry.value.runes) rune: entry.key,
  };
  static final _ignored = RegExp(chatIgnoredPattern, unicode: true);
  static final _separators = RegExp(r'[^\p{L}\p{N}!@$|+*]', unicode: true);
  static final _elongation = RegExp(r'([ㅏ-ㅣ])(ㅇ\1)+', unicode: true);
  static final _spacedRepeats = RegExp(
    r'([a-z])([ 0-9!@$|+*]*\1)+',
    unicode: true,
  );
  static final _repeats = RegExp(r'(.)\1+', unicode: true);
  static final _allowed = RegExp(chatAllowedPattern, unicode: true);
  static final _korean = RegExp(chatKoreanPattern, unicode: true);
  static final _masked = RegExp(chatMaskedPattern, unicode: true);
  static final _english = chatEnglishTokens.map(_EnglishRule.new).toList();

  /// 초성·중성·종성을 같은 호환 자모로 바꾸어 완성형/분해형을 함께 검사한다.
  static String _normalize(String input) {
    final result = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0xac00 && rune <= 0xd7a3) {
        final syllable = rune - 0xac00;
        result.write(_folds[0x1100 + syllable ~/ 588]);
        result.write(_folds[0x1161 + (syllable % 588) ~/ 28]);
        if (syllable % 28 != 0) {
          result.write(_folds[0x11a7 + syllable % 28]);
        }
      } else {
        result.write(_folds[rune] ?? String.fromCharCode(rune));
      }
    }
    return result
        .toString()
        .replaceAll(_ignored, '')
        .replaceAll(_separators, ' ')
        .replaceAllMapped(_elongation, (m) => m[1]!)
        .replaceAllMapped(_spacedRepeats, (m) => m[1]!)
        .replaceAllMapped(_repeats, (m) => m[1]!);
  }

  static bool containsProfanity(String body) {
    final normalized = _normalize(
      body,
    ).replaceAllMapped(_allowed, (m) => '${m[1]}~');
    if (_korean.hasMatch(normalized) || _masked.hasMatch(normalized)) {
      return true;
    }
    final runes = normalized.runes.toList(growable: false);
    return _english.any((rule) => rule.matches(runes));
  }

  /// 로컬 저장, 원격 outbox 기록, 재전송보다 먼저 호출한다.
  static void validate(String body, List<String> attachments) {
    if (body.trim().isEmpty && attachments.isEmpty) {
      throw const AppFailure('메시지나 사진을 추가해 주세요.');
    }
    if (body.runes.length > maxLength) {
      throw const AppFailure('메시지를 10,000자 이하로 나누어 보내 주세요.');
    }
    if (containsProfanity(body)) {
      throw const AppFailure(rejectionMessage);
    }
  }
}

/// 숫자/기호가 문자 치환과 구분자 양쪽에 해당할 수 있으므로 가능한 상태를
/// 비트 집합으로 동시에 진행한다. 중첩 정규식 재탐색 없이 입력 길이에 비례한다.
final class _EnglishRule {
  _EnglishRule(List<String> tokens) : end = 1 << tokens.length {
    for (var position = 0; position < tokens.length; position++) {
      for (final rune in tokens[position].runes) {
        positions[rune] = (positions[rune] ?? 0) | (1 << position);
      }
    }
  }

  final positions = <int, int>{};
  final int end;
  static final _gaps = r' 0123456789!@$|+*'.runes.toSet();
  static bool _word(int c) =>
      (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39);

  bool matches(List<int> runes) {
    var states = 0;
    for (var i = 0; i < runes.length; i++) {
      final c = runes[i];
      final started = states | (i == 0 || !_word(runes[i - 1]) ? 1 : 0);
      final advanced = (started & (positions[c] ?? 0)) << 1;
      if ((advanced & end) != 0 &&
          (i + 1 == runes.length || !_word(runes[i + 1]))) {
        return true;
      }
      // 마지막 글자 뒤 숫자를 구분자로 건너뛰어 단어 경계를 우회하지 않는다.
      states = (_gaps.contains(c) ? states : 0) | (advanced & (end - 1));
    }
    return false;
  }
}
