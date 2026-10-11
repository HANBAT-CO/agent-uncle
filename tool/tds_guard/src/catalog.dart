/// Generates `docs/tds-components.md`: every public declaration the app may
/// use, read from the package barrel so the list cannot drift from the code.
library;

import 'dart:io';

const catalogPath = 'docs/tds-components.md';
const _packageLib = 'packages/tds_mobile_flutter/lib';
const _barrel = '$_packageLib/tds_mobile_flutter.dart';

/// Existing app widgets that already compose TDS. Reuse them instead of
/// creating another card, frame or icon wrapper.
const appCompositionFiles = [
  'lib/local/presentation/layout.dart',
  'lib/local/presentation/common.dart',
];

class _Declaration {
  const _Declaration(this.name, this.kind, this.doc);
  final String name, kind, doc;
}

final _typeDeclaration = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface|mixin)\s+)*'
  r'(class|enum|mixin|typedef|extension\s+type|extension)\s+([A-Za-z_]\w*)(.*)$',
);
final _extendsClause = RegExp(r'\bextends\s+([\w.]+(?:<[^{]*?>)?)');
final _function = RegExp(
  r'^(?!(?:class|enum|mixin|typedef|extension|import|export|part|library|'
  r'const|final|var|late|abstract|base|sealed|interface|external|return)\b)'
  r'[A-Za-z][\w<>?,\s]*?\s+([a-zA-Z]\w*)\s*(?:<[^>()]*>)?\s*\(',
);
final _variable = RegExp(
  r'^(?:const|final)\s+(?:[\w<>?,]+\s+)?([a-zA-Z]\w*)\s*=',
);

List<_Declaration> _declarations(String source) {
  final lines = source.split('\n');
  final result = <_Declaration>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    String? name, kind;
    final type = _typeDeclaration.firstMatch(line);
    if (type != null) {
      name = type.group(2)!;
      kind = type.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
      if (kind == 'class') {
        final parent = _extendsClause.firstMatch(type.group(3)!);
        if (parent != null) kind = 'class extends ${parent.group(1)}';
      }
      if (name == 'on') continue;
    } else if (_variable.firstMatch(line) case final variable?) {
      name = variable.group(1)!;
      kind = 'const';
    } else if (_function.firstMatch(
          // A `Widget Function(Widget)?` return type is not the name.
          line.replaceAll(RegExp(r'\bFunction\s*\([^()]*\)\??'), 'Fn'),
        )
        case final function?) {
      name = function.group(1)!;
      kind = 'function';
    }
    if (name == null || kind == null || name.startsWith('_')) continue;
    result.add(_Declaration(name, kind, _docAbove(lines, i)));
  }
  return result;
}

/// First line of the `///` block above [index], skipping annotations.
String _docAbove(List<String> lines, int index) {
  var i = index - 1;
  while (i >= 0 && lines[i].trimLeft().startsWith('@')) {
    i--;
  }
  String? first;
  while (i >= 0 && lines[i].trimLeft().startsWith('///')) {
    first = lines[i].trimLeft().substring(3).trim();
    i--;
  }
  return first ?? '';
}

String _cell(String text) => text.replaceAll('|', r'\|');

void _section(StringBuffer out, String heading, List<_Declaration> items) {
  if (items.isEmpty) return;
  out
    ..writeln('### `$heading`')
    ..writeln()
    ..writeln('| 심볼 | 종류 | 설명 |')
    ..writeln('| --- | --- | --- |');
  for (final item in items) {
    out.writeln('| `${item.name}` | ${item.kind} | ${_cell(item.doc)} |');
  }
  out.writeln();
}

String generateCatalog(Directory root) {
  final out = StringBuffer()
    ..writeln('# TDS 컴포넌트 카탈로그')
    ..writeln()
    ..writeln(
      '<!-- 자동 생성: dart tool/tds_guard/tds_guard.dart catalog --write'
      ' · 직접 수정 금지 -->',
    )
    ..writeln()
    ..writeln(
      '앱 UI는 이 목록의 공개 API만 사용한다. import는 '
      "`package:tds_mobile_flutter/tds_mobile_flutter.dart` 하나다. 생성자와 "
      '파라미터는 해당 소스 파일에서 확인한다. 규칙은 '
      '[TDS UI 정책](tds-ui-policy.md)을 따른다.',
    )
    ..writeln()
    ..writeln('## TDS 패키지 (`$_packageLib/`)')
    ..writeln();

  final barrel = File('${root.path}/$_barrel');
  if (barrel.existsSync()) {
    final exports = RegExp(r'''^export\s+['"]([^'"]+)['"]''', multiLine: true);
    for (final match in exports.allMatches(barrel.readAsStringSync())) {
      final rel = match.group(1)!;
      final file = File('${root.path}/$_packageLib/$rel');
      if (!file.existsSync()) continue;
      _section(out, rel, _declarations(file.readAsStringSync()));
    }
  }

  out
    ..writeln('## 앱 공용 조합 위젯')
    ..writeln()
    ..writeln('TDS를 조합해 이미 만든 앱 위젯이다. 같은 역할의 위젯을 새로 만들지 말고 재사용한다.')
    ..writeln();
  for (final rel in appCompositionFiles) {
    final file = File('${root.path}/$rel');
    if (!file.existsSync()) continue;
    _section(out, rel, _declarations(file.readAsStringSync()));
  }
  return '${out.toString().trimRight()}\n';
}
