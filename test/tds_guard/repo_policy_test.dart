@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/tds_guard/src/policy.dart';
import '../../tool/tds_guard/src/scanner.dart';

/// Runs the TDS UI policy on the real tree so `flutter test` fails for any
/// agent or person that adds non-TDS UI, even without Claude Code hooks.
void main() {
  final root = Directory.current;

  test('app UI adds no violations beyond the baseline', () {
    final violations = checkTree(root);
    expect(
      violations,
      isEmpty,
      reason: violations.map((v) => v.format()).join('\n'),
    );
  });

  test('the policy document explains every rule', () {
    final policy = File(policyDocPath).readAsStringSync();
    final ids = [
      ...guardRules.map((rule) => rule.id),
      'new-dependency',
      'catalog-stale',
      'protected-path',
      'baseline-raised',
    ];
    for (final id in ids) {
      expect(policy, contains('`$id`'), reason: id);
    }
  });

  test('guidance cites only TDS symbols that exist in the package', () {
    final catalog = File(catalogPath).readAsStringSync();
    final cited = <String>{
      for (final source in [
        File(policyDocPath).readAsStringSync(),
        File('.claude/skills/tds-ui/SKILL.md').readAsStringSync(),
        ...guardRules.map((rule) => rule.alternative),
      ])
        for (final match in RegExp(r'\bTds[A-Z]\w*').allMatches(source))
          match.group(0)!,
    };
    final missing = cited.where((name) => !catalog.contains('| `$name` |'));
    expect(missing, isEmpty);
  });

  test('guidance cites only constructor parameters that exist', () {
    final sources = [
      File(policyDocPath).readAsStringSync(),
      File('.claude/skills/tds-ui/SKILL.md').readAsStringSync(),
      ...guardRules.map((rule) => rule.alternative),
    ];
    final package = Directory('packages/tds_mobile_flutter/lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join('\n');
    String classBody(String name) {
      final start = package.indexOf(RegExp('^class $name ', multiLine: true));
      expect(start, isNonNegative, reason: name);
      final end = package.indexOf(RegExp(r'^}', multiLine: true), start);
      return package.substring(start, end);
    }

    final unknown = <String>[];
    for (final source in sources) {
      for (final call in RegExp(r'\b(Tds\w+)\(([^()]*)\)').allMatches(source)) {
        final body = classBody(call.group(1)!);
        for (final argument in call.group(2)!.split(',')) {
          final name = argument.split(':').first.trim();
          if (!RegExp(r'^[a-z]\w*$').hasMatch(name)) continue;
          if (!RegExp('(?:this|super)\\.$name\\b').hasMatch(body)) {
            unknown.add('${call.group(1)}.$name');
          }
        }
      }
    }
    expect(unknown, isEmpty);
  });

  test('Claude Code runs the guard on every enforcing event', () {
    final settings =
        jsonDecode(File('.claude/settings.json').readAsStringSync())
            as Map<String, Object?>;
    final hooks = settings['hooks'] as Map<String, Object?>;
    String commands(String event) => jsonEncode(hooks[event]);
    for (final event in [
      'SessionStart',
      'UserPromptSubmit',
      'PreToolUse',
      'Stop',
      'SubagentStop',
    ]) {
      expect(commands(event), contains('tds_guard.dart'), reason: event);
    }
    expect(commands('PreToolUse'), contains('Write|Edit|MultiEdit'));
  });

  test('agent instructions point at the policy and the catalog', () {
    final agents = File('AGENTS.md').readAsStringSync();
    expect(agents, contains(policyDocPath));
    expect(agents, contains(catalogPath));
    expect(File('CLAUDE.md').readAsStringSync(), contains('@AGENTS.md'));
  });
}
