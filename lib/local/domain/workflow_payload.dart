import 'dart:convert';

import 'models.dart';

/// 입력 순서와 무관하게 같은 작업의 본문을 비교한다.
String workflowPayload(String command, Data args) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(canonical({'command': command, 'args': args}));
}
