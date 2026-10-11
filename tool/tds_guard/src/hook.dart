/// Claude Code hook handler. One entry point for every event so the policy
/// lives in one place; see `.claude/settings.json` for the wiring.
library;

import 'dart:convert';
import 'dart:io';

import 'catalog.dart';
import 'policy.dart';

const unlockTag = '#tds-unlock';

class HookOutcome {
  const HookOutcome({this.exitCode = 0, this.stdout = '', this.stderr = ''});
  final int exitCode;
  final String stdout, stderr;
}

const _allow = HookOutcome();
const _footer =
    '규칙: $policyDocPath · 사용 가능한 컴포넌트: $catalogPath\n'
    'TDS에 맞는 컴포넌트가 없으면 새로 만들지 말고 작업을 멈춘 뒤 사용자에게 묻는다.';

/// Never throws: a broken guard must not wedge the session, so failures are
/// reported on stderr and the call is allowed.
HookOutcome handleHook(Map<String, Object?> input, Directory root) {
  try {
    final session = _sessionKey(input['session_id']);
    return switch (input['hook_event_name']) {
      'SessionStart' => _sessionStart(root, session),
      'UserPromptSubmit' => _userPrompt(root, session, input['prompt']),
      'PreToolUse' => _preToolUse(root, session, input),
      'Stop' || 'SubagentStop' => _stop(root, session, input),
      _ => _allow,
    };
  } on Object catch (error) {
    return HookOutcome(stderr: 'tds_guard hook skipped: $error\n');
  }
}

String _sessionKey(Object? id) =>
    (id is String && id.isNotEmpty ? id : 'unknown').replaceAll(
      RegExp(r'[^\w.-]'),
      '_',
    );

File _stateFile(Directory root, String kind, String session) =>
    File('${root.path}/.dart_tool/tds_guard/$kind/$session');

bool _isUnlocked(Directory root, String session) =>
    _stateFile(root, 'unlock', session).existsSync();

HookOutcome _json(Map<String, Object?> body) =>
    HookOutcome(stdout: jsonEncode(body));

HookOutcome _sessionStart(Directory root, String session) {
  // Resume/clear/compact keep the snapshot taken when the session began.
  final snapshot = _stateFile(root, 'sessions', session);
  if (!snapshot.existsSync()) {
    snapshot
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'fingerprint': fingerprintProtected(root),
          'sources': fingerprintSources(root),
          'baseline': loadBaseline(root).toJson(),
        }),
      );
  }
  return _allow;
}

HookOutcome _userPrompt(Directory root, String session, Object? prompt) {
  if (prompt is! String || !prompt.contains(unlockTag)) return _allow;
  _stateFile(root, 'unlock', session)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(DateTime.now().toIso8601String());
  return _json({
    'hookSpecificOutput': {
      'hookEventName': 'UserPromptSubmit',
      'additionalContext':
          '[tds_guard] 사용자가 $unlockTag 로 이 세션에서 보호 경로(TDS 패키지, '
          '하네스, SVG 에셋) 수정과 `baseline --accept`를 허용했다. 요청받은 '
          '범위만 바꾼다. 앱 UI는 여전히 TDS 컴포넌트만 사용한다.',
    },
  });
}

HookOutcome _deny(String reason) => _json({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': reason,
  },
});

HookOutcome _preToolUse(
  Directory root,
  String session,
  Map<String, Object?> input,
) {
  final tool = input['tool_name'];
  final toolInput = input['tool_input'];
  if (toolInput is! Map) return _allow;
  final unlocked = _isUnlocked(root, session);

  if (tool == 'Bash') {
    final command = toolInput['command'];
    if (command is String &&
        command.contains('tds_guard') &&
        command.contains('--accept') &&
        !unlocked) {
      return _deny(
        '[tds_guard] `baseline --accept`는 허용 위반 수를 올리는 명령이라 '
        '사용자만 승인할 수 있다. 위반을 고치거나, 사용자에게 요청한다 '
        '(사용자가 프롬프트에 $unlockTag 를 적으면 허용).',
      );
    }
    return _allow;
  }

  if (tool != 'Write' && tool != 'Edit' && tool != 'MultiEdit') return _allow;
  final filePath = toolInput['file_path'];
  if (filePath is! String) return _allow;
  final rel = _relative(root, filePath, input['cwd']);
  if (rel == null) return _allow;

  if (rel == catalogPath) {
    return _deny(
      '[tds_guard] `$catalogPath`는 자동 생성 파일이라 직접 수정하지 않는다. '
      '`dart tool/tds_guard/tds_guard.dart catalog --write`로 다시 생성한다.',
    );
  }
  if (rel.startsWith('assets/') && rel.endsWith('.svg') && !unlocked) {
    return _deny(
      '[tds_guard] SVG를 직접 작성/수정하지 않는다: 아이콘·그림을 창작하지 않는다. '
      '기존 assets/icons 원본이나 TDS 에셋을 쓰고, 새 에셋은 사용자에게 Figma/TDS '
      '원본 파일을 받는다 (사용자가 $unlockTag 를 적으면 허용).',
    );
  }
  if (isProtected(rel) && !unlocked) {
    return _deny(
      '[tds_guard] `$rel`은 보호 경로다. TDS 패키지는 컴포넌트 원본이고 나머지는 '
      '이 정책을 강제하는 하네스라 사용자 요청 없이 바꾸지 않는다. 필요한 변경이면 '
      '이유를 설명하고, 사용자가 프롬프트에 $unlockTag 를 적도록 요청한다.',
    );
  }

  final file = File('${root.path}/$rel');
  final before = file.existsSync() ? file.readAsStringSync() : null;
  final after = _applyTool(tool as String, toolInput, before);
  if (after == null) return _allow;
  final baseline = loadBaseline(root);
  final violations = [
    ...compareSource(rel, before, after, baseline),
    if (rel == 'pubspec.yaml') ...compareDependencies(before, after, baseline),
  ];
  if (violations.isEmpty) return _allow;
  return _deny(
    '[tds_guard] TDS 컴포넌트 밖의 UI 코드라 이 변경을 적용하지 않았다.\n'
    '${violations.map((v) => v.format()).join('\n')}\n$_footer',
  );
}

/// Content after the tool runs, or null when the edit cannot apply (the tool
/// itself will report that).
String? _applyTool(String tool, Map toolInput, String? before) {
  if (tool == 'Write') return toolInput['content'] as String?;
  final edits = tool == 'MultiEdit'
      ? [for (final edit in toolInput['edits'] as List) edit as Map]
      : [toolInput];
  var content = before ?? '';
  for (final edit in edits) {
    final oldString = edit['old_string'] as String? ?? '';
    final newString = edit['new_string'] as String? ?? '';
    if (oldString.isEmpty) {
      if (content.isNotEmpty) return null;
      content = newString;
    } else if (!content.contains(oldString)) {
      return null;
    } else {
      content = edit['replace_all'] == true
          ? content.replaceAll(oldString, newString)
          : content.replaceFirst(oldString, newString);
    }
  }
  return content;
}

String _normalize(String path) =>
    Uri.file(path).normalizePath().toFilePath().replaceAll(r'\', '/');

/// Root-relative path, or null when [filePath] is outside [root].
String? _relative(Directory root, String filePath, Object? cwd) {
  final absolute = filePath.startsWith('/') || cwd is! String
      ? filePath
      : '$cwd/$filePath';
  final target = _normalize(absolute);
  final roots = {_normalize(root.path), _normalize(root.absolute.path)};
  try {
    roots.add(_normalize(root.resolveSymbolicLinksSync()));
  } on FileSystemException {
    // Keep the literal roots.
  }
  var parent = File(target).parent;
  while (!parent.existsSync() && parent.path != parent.parent.path) {
    parent = parent.parent;
  }
  final candidates = {target};
  try {
    final real = _normalize(parent.resolveSymbolicLinksSync());
    candidates.add(target.replaceFirst(_normalize(parent.path), real));
  } on FileSystemException {
    // Keep the literal target.
  }
  for (final candidate in candidates) {
    for (final base in roots) {
      final prefix = base.endsWith('/') ? base : '$base/';
      if (candidate.startsWith(prefix)) {
        return candidate.substring(prefix.length);
      }
    }
  }
  return null;
}

HookOutcome _stop(Directory root, String session, Map<String, Object?> input) {
  var violations = checkTree(root);
  final snapshotFile = _stateFile(root, 'sessions', session);
  if (snapshotFile.existsSync()) {
    final snapshot =
        jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
    final protectedBefore = (snapshot['fingerprint'] as Map)
        .cast<String, String>();
    // Only what changed since the session started is this session's to fix;
    // older uncommitted work is left to `check`, pre-commit and flutter test.
    final sources = snapshot['sources'];
    final changed = sources is Map
        ? changedPaths(
            sources.cast<String, String>(),
            fingerprintSources(root),
          ).toSet()
        : {for (final violation in violations) violation.file};
    final catalogInputsChanged =
        changed.contains(catalogPath) ||
        changed.any(appCompositionFiles.contains) ||
        changedPaths(
          protectedBefore,
          fingerprintProtected(root),
        ).any((rel) => rel.startsWith('packages/tds_mobile_flutter/lib/'));
    violations = [
      for (final violation in violations)
        if (changed.contains(violation.file) ||
            (violation.rule == 'catalog-stale' && catalogInputsChanged))
          violation,
    ];
    if (!_isUnlocked(root, session)) {
      violations.addAll(
        protectedChanges(
          root,
          protectedBefore,
          Baseline.fromJson(snapshot['baseline'] as Map<String, Object?>),
        ),
      );
    }
  }
  if (violations.isEmpty) return _allow;
  final list = violations.map((v) => v.format()).join('\n');
  if (input['stop_hook_active'] == true) {
    // Already blocked once: hand the decision to the user instead of looping.
    return _json({
      'systemMessage':
          '[tds_guard] TDS 정책 위반 ${violations.length}건이 남아 있습니다. '
          '확인이 필요합니다.\n$list',
    });
  }
  return _json({
    'decision': 'block',
    'reason':
        '[tds_guard] 종료 전 검사에서 TDS 정책 위반 ${violations.length}건을 '
        '찾았다. TDS 컴포넌트로 바꾸거나 되돌린다. 다른 작업자가 바꾼 파일이면 '
        '건드리지 않는다. 고칠 수 없으면 무엇이 왜 막혔는지 사용자에게 보고하고 '
        '결정을 요청한다.\n$list\n$_footer',
  });
}
