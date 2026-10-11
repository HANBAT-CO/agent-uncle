/// TDS UI policy guard. See docs/tds-ui-policy.md.
///
///   dart tool/tds_guard/tds_guard.dart check             exit 1 on violations
///   dart tool/tds_guard/tds_guard.dart baseline          lower counts only
///   dart tool/tds_guard/tds_guard.dart baseline --accept accept current counts
///                                                        (user approval only)
///   dart tool/tds_guard/tds_guard.dart catalog --write   regenerate the catalog
///   dart tool/tds_guard/tds_guard.dart hook              Claude Code hook (stdin)
library;

import 'dart:convert';
import 'dart:io';

import 'src/catalog.dart';
import 'src/hook.dart';
import 'src/policy.dart';

Directory get _scriptRoot =>
    File.fromUri(Platform.script).parent.parent.parent.absolute;

/// The nearest ancestor of [start] that carries this guard.
Directory _rootFrom(String? start) {
  if (start != null && start.isNotEmpty) {
    var directory = Directory(start).absolute;
    while (true) {
      if (File('${directory.path}/$baselinePath').existsSync()) {
        return directory;
      }
      if (directory.path == directory.parent.path) break;
      directory = directory.parent;
    }
  }
  return _scriptRoot;
}

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'check' : args.first;
  switch (command) {
    case 'check':
      final violations = checkTree(_scriptRoot);
      if (violations.isEmpty) {
        stdout.writeln('tds_guard: OK');
        return;
      }
      stderr
        ..writeln('tds_guard: TDS UI 정책 위반 ${violations.length}건')
        ..writeln(violations.map((v) => v.format()).join('\n'))
        ..writeln('규칙: $policyDocPath · 컴포넌트: $catalogPath');
      exitCode = 1;
    case 'baseline':
      final root = _scriptRoot;
      final current = measureTree(root);
      final accept = args.contains('--accept');
      saveBaseline(
        root,
        accept ? current : ratchetBaseline(loadBaseline(root), current),
      );
      stdout.writeln(
        accept
            ? 'tds_guard: 현재 위반 수를 기준선으로 승인했습니다.'
            : 'tds_guard: 줄어든 위반 수만 기준선에 반영했습니다.',
      );
    case 'catalog':
      final catalog = generateCatalog(_scriptRoot);
      if (args.contains('--write')) {
        File('${_scriptRoot.path}/$catalogPath').writeAsStringSync(catalog);
        stdout.writeln('tds_guard: $catalogPath 생성');
      } else {
        stdout.write(catalog);
      }
    case 'hook':
      final raw = await stdin.transform(utf8.decoder).join();
      Map<String, Object?> input;
      try {
        input = jsonDecode(raw) as Map<String, Object?>;
      } on FormatException {
        return;
      }
      final toolInput = input['tool_input'];
      final filePath = toolInput is Map ? toolInput['file_path'] : null;
      final root = _rootFrom(
        filePath is String && filePath.startsWith('/')
            ? File(filePath).parent.path
            : input['cwd'] as String?,
      );
      final outcome = handleHook(input, root);
      stdout.write(outcome.stdout);
      stderr.write(outcome.stderr);
      exitCode = outcome.exitCode;
    default:
      stderr.writeln(
        'usage: tds_guard.dart [check|baseline [--accept]|catalog [--write]|hook]',
      );
      exitCode = 64;
  }
}
