/// Baseline ratchet, tree checks and protected paths for the TDS UI policy.
library;

import 'dart:convert';
import 'dart:io';

import 'catalog.dart';
import 'scanner.dart';

export 'catalog.dart' show catalogPath;

const baselinePath = 'tool/tds_guard/baseline.json';
const policyDocPath = 'docs/tds-ui-policy.md';
const _checkCommand = 'dart tool/tds_guard/tds_guard.dart';

/// Legacy violation counts per file and rule, plus the approved dependency
/// names. Counts may only go down (see [ratchetBaseline]).
class Baseline {
  Baseline({required this.files, required this.dependencies});

  factory Baseline.empty() => Baseline(files: {}, dependencies: []);

  factory Baseline.fromJson(Map<String, Object?> json) => Baseline(
    files: {
      for (final entry in ((json['files'] ?? {}) as Map).entries)
        entry.key as String: {
          for (final count in (entry.value as Map).entries)
            count.key as String: count.value as int,
        },
    },
    dependencies: [
      for (final name in (json['dependencies'] ?? []) as List) name as String,
    ],
  );

  final Map<String, Map<String, int>> files;
  final List<String> dependencies;

  int count(String file, String rule) => files[file]?[rule] ?? 0;

  Map<String, Object?> toJson() {
    final names = files.keys.toList()..sort();
    return {
      'comment':
          'Legacy violations of docs/tds-ui-policy.md. Counts may only go '
          'down: run `$_checkCommand baseline` after removing violations.',
      'dependencies': [...dependencies]..sort(),
      'files': {
        for (final name in names)
          name: {
            for (final rule in files[name]!.keys.toList()..sort())
              rule: files[name]![rule],
          },
      },
    };
  }
}

Baseline loadBaseline(Directory root) {
  final file = File('${root.path}/$baselinePath');
  if (!file.existsSync()) return Baseline.empty();
  return Baseline.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
  );
}

void saveBaseline(Directory root, Baseline baseline) {
  File('${root.path}/$baselinePath')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(baseline.toJson())}\n',
    );
}

/// App sources as root-relative paths with forward slashes, sorted.
List<String> _appSources(Directory root) {
  final lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) return [];
  final prefix = '${root.path}/';
  return [
    for (final entity in lib.listSync(recursive: true))
      if (entity is File)
        entity.path.substring(prefix.length).replaceAll(r'\', '/'),
  ].where(isGuardedSource).toList()..sort();
}

Baseline measureTree(Directory root) {
  final files = <String, Map<String, int>>{};
  for (final rel in _appSources(root)) {
    final hits = scanSource(rel, File('${root.path}/$rel').readAsStringSync());
    if (hits.isEmpty) continue;
    files[rel] = {
      for (final entry in hits.entries) entry.key: entry.value.length,
    };
  }
  final pubspec = File('${root.path}/pubspec.yaml');
  return Baseline(
    files: files,
    dependencies: pubspec.existsSync()
        ? parseDependencies(pubspec.readAsStringSync())
        : [],
  );
}

/// Keeps the lower of each count; deleted files and removed dependencies
/// drop out. Never raises anything.
Baseline ratchetBaseline(Baseline old, Baseline current) {
  final files = <String, Map<String, int>>{};
  old.files.forEach((file, counts) {
    final kept = <String, int>{};
    counts.forEach((rule, count) {
      final lower = count < current.count(file, rule)
          ? count
          : current.count(file, rule);
      if (lower > 0) kept[rule] = lower;
    });
    if (kept.isNotEmpty) files[file] = kept;
  });
  return Baseline(
    files: files,
    dependencies: old.dependencies
        .where(current.dependencies.contains)
        .toList(),
  );
}

bool isBaselineRaised(Baseline old, Baseline updated) {
  for (final file in updated.files.keys) {
    for (final rule in updated.files[file]!.keys) {
      if (updated.count(file, rule) > old.count(file, rule)) return true;
    }
  }
  return updated.dependencies.any((name) => !old.dependencies.contains(name));
}

/// Names under `dependencies:` and `dev_dependencies:`, sorted.
List<String> parseDependencies(String pubspec) {
  final names = <String>{};
  var inSection = false;
  for (final line in const LineSplitter().convert(pubspec)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      inSection = RegExp(
        r'^(?:dependencies|dev_dependencies):\s*$',
      ).hasMatch(line);
      continue;
    }
    final name = RegExp(r'^  ([A-Za-z_]\w*)\s*:').firstMatch(line);
    if (inSection && name != null) names.add(name.group(1)!);
  }
  return names.toList()..sort();
}

class Violation {
  const Violation({
    required this.file,
    required this.rule,
    required this.detail,
    this.lines = const [],
  });

  final String file, rule, detail;
  final List<int> lines;

  String format() {
    final where = lines.isEmpty ? '' : ' (줄 ${lines.join(', ')})';
    return '- `$file` [$rule] $detail$where';
  }
}

Violation _sourceViolation(
  String file,
  String ruleId,
  List<int> lines,
  int allowed,
) {
  final rule = ruleById(ruleId);
  return Violation(
    file: file,
    rule: ruleId,
    detail:
        '${rule.message} → 대안: ${rule.alternative} '
        '(허용 $allowed건, 현재 ${lines.length}건)',
    lines: lines,
  );
}

/// Rules whose count this change raises above both the previous content and
/// the baseline. Legacy code may be edited as long as it does not grow.
List<Violation> compareSource(
  String rel,
  String? before,
  String after,
  Baseline baseline,
) {
  if (!isGuardedSource(rel)) return [];
  final previous = before == null ? const {} : scanSource(rel, before);
  final violations = <Violation>[];
  scanSource(rel, after).forEach((rule, lines) {
    final allowed = baseline.count(rel, rule);
    if (lines.length > (previous[rule]?.length ?? 0) &&
        lines.length > allowed) {
      violations.add(_sourceViolation(rel, rule, lines, allowed));
    }
  });
  return violations;
}

Violation _dependencyViolation(String name) => Violation(
  file: 'pubspec.yaml',
  rule: 'new-dependency',
  detail:
      '`$name`: 새 의존성은 사용자 승인 필요. UI 패키지는 금지, '
      'TDS 컴포넌트를 사용한다',
);

List<Violation> compareDependencies(
  String? before,
  String after,
  Baseline baseline,
) {
  final previous = before == null
      ? const <String>[]
      : parseDependencies(before);
  return [
    for (final name in parseDependencies(after))
      if (!previous.contains(name) && !baseline.dependencies.contains(name))
        _dependencyViolation(name),
  ];
}

/// Everything in the working tree that exceeds the committed baseline.
List<Violation> checkTree(Directory root) {
  final baseline = loadBaseline(root);
  final current = measureTree(root);
  final violations = <Violation>[];
  for (final rel in _appSources(root)) {
    final hits = scanSource(rel, File('${root.path}/$rel').readAsStringSync());
    hits.forEach((rule, lines) {
      final allowed = baseline.count(rel, rule);
      if (lines.length > allowed) {
        violations.add(_sourceViolation(rel, rule, lines, allowed));
      }
    });
  }
  for (final name in current.dependencies) {
    if (!baseline.dependencies.contains(name)) {
      violations.add(_dependencyViolation(name));
    }
  }
  final catalog = File('${root.path}/$catalogPath');
  final expected = generateCatalog(root);
  if (!catalog.existsSync() || catalog.readAsStringSync() != expected) {
    violations.add(
      const Violation(
        file: catalogPath,
        rule: 'catalog-stale',
        detail: 'TDS 공개 API와 다름 → `$_checkCommand catalog --write`',
      ),
    );
  }
  return violations;
}

/// Paths an agent may change only after the user writes `#tds-unlock`.
/// The TDS package is the component source of truth; the rest is the
/// harness that enforces it.
const protectedPrefixes = [
  'packages/tds_mobile_flutter/',
  'tool/tds_guard/',
  'test/tds_guard/',
  '.githooks/',
  '.claude/skills/tds-ui/',
];
const protectedFiles = [
  'AGENTS.md',
  'CLAUDE.md',
  policyDocPath,
  '.claude/settings.json',
  '.claude/settings.local.json',
];

bool isProtected(String rel) =>
    protectedFiles.contains(rel) || protectedPrefixes.any(rel.startsWith);

const _ignoredDirectories = {'build', '.dart_tool', 'node_modules', '.git'};

String _stamp(File file) {
  final stat = file.statSync();
  return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
}

/// Paths whose stamp differs between two fingerprints, sorted.
List<String> changedPaths(
  Map<String, String> before,
  Map<String, String> now,
) => {
  ...before.keys,
  ...now.keys,
}.where((rel) => before[rel] != now[rel]).toList()..sort();

/// App sources, pubspec and catalog: the files a Stop check attributes to the
/// session when they change after it started.
Map<String, String> fingerprintSources(Directory root) => {
  for (final rel in [..._appSources(root), 'pubspec.yaml', catalogPath])
    if (File('${root.path}/$rel').existsSync())
      rel: _stamp(File('${root.path}/$rel')),
};

/// Size and modification time of every protected file except the baseline,
/// whose content is compared semantically instead.
Map<String, String> fingerprintProtected(Directory root) {
  final prefix = '${root.path}/';
  final result = <String, String>{};
  void add(File file) {
    final rel = file.path.substring(prefix.length).replaceAll(r'\', '/');
    if (rel == baselinePath || rel.endsWith('.DS_Store')) return;
    result[rel] = _stamp(file);
  }

  void walk(Directory directory) {
    for (final entity in directory.listSync(followLinks: false)) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (entity is Directory && !_ignoredDirectories.contains(name)) {
        walk(entity);
      } else if (entity is File) {
        add(entity);
      }
    }
  }

  for (final rel in protectedPrefixes) {
    final directory = Directory('$prefix$rel');
    if (directory.existsSync()) walk(directory);
  }
  for (final rel in protectedFiles) {
    final file = File('$prefix$rel');
    if (file.existsSync()) add(file);
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

List<Violation> protectedChanges(
  Directory root,
  Map<String, String> snapshot,
  Baseline snapshotBaseline,
) {
  return [
    for (final rel in changedPaths(snapshot, fingerprintProtected(root)))
      Violation(
        file: rel,
        rule: 'protected-path',
        detail:
            '세션 중 보호 경로가 바뀜 → 되돌리거나, 사용자가 프롬프트에 '
            '#tds-unlock을 적어 허용해야 함',
      ),
    if (isBaselineRaised(snapshotBaseline, loadBaseline(root)))
      const Violation(
        file: baselinePath,
        rule: 'baseline-raised',
        detail:
            '허용 위반 수가 늘어남 → 되돌리기. 기준선은 '
            '`$_checkCommand baseline`으로만 낮춘다',
      ),
  ];
}
