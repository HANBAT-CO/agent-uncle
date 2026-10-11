import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/tds_guard/src/hook.dart';
import '../../tool/tds_guard/src/policy.dart';
import 'fixture.dart';

void main() {
  late GuardFixture fixture;
  setUp(() => fixture = GuardFixture.create());
  tearDown(() => fixture.dispose());

  Map<String, Object?>? run(Map<String, Object?> input) {
    final outcome = handleHook({
      'session_id': 's1',
      'cwd': fixture.root.path,
      ...input,
    }, fixture.root);
    expect(outcome.exitCode, 0);
    if (outcome.stdout.isEmpty) return null;
    return jsonDecode(outcome.stdout) as Map<String, Object?>;
  }

  Map<String, Object?>? preTool(
    String tool,
    Map<String, Object?> toolInput, {
    String session = 's1',
  }) => run({
    'session_id': session,
    'hook_event_name': 'PreToolUse',
    'tool_name': tool,
    'tool_input': toolInput,
  });

  String? denial(Map<String, Object?>? output) {
    if (output == null) return null;
    final specific = output['hookSpecificOutput'] as Map<String, Object?>;
    expect(specific['hookEventName'], 'PreToolUse');
    expect(specific['permissionDecision'], 'deny');
    return specific['permissionDecisionReason'] as String;
  }

  void unlock({String session = 's1'}) {
    final output = run({
      'session_id': session,
      'hook_event_name': 'UserPromptSubmit',
      'prompt': '#tds-unlock TDS 패키지 버그를 고쳐줘',
    });
    expect(jsonEncode(output), contains('#tds-unlock'));
  }

  group('PreToolUse on app sources', () {
    test('denies an edit that adds a raw gesture', () {
      final reason = denial(
        preTool('Edit', {
          'file_path': fixture.path('lib/clean.dart'),
          'old_string': "TdsText('clean')",
          'new_string': 'GestureDetector(onTap: f)',
        }),
      );
      expect(reason, contains('lib/clean.dart'));
      expect(reason, contains('raw-gesture'));
      expect(reason, contains('TdsButton'));
      expect(reason, contains(catalogPath));
    });

    test('allows edits that keep legacy violations at the baseline', () {
      expect(
        preTool('Edit', {
          'file_path': fixture.path('lib/legacy.dart'),
          'old_string': 'final a',
          'new_string': 'final legacy',
        }),
        isNull,
      );
    });

    test('allows fixing a file that is already above the baseline', () {
      // Written outside Edit/Write; the agent must still be able to repair it.
      fixture.write(
        'lib/clean.dart',
        'GestureDetector(); GestureDetector();\n',
      );
      expect(
        preTool('Edit', {
          'file_path': fixture.path('lib/clean.dart'),
          'old_string': 'GestureDetector(); GestureDetector();',
          'new_string': "GestureDetector(); TdsText('fixed');",
        }),
        isNull,
      );
    });

    test('denies an edit that adds another legacy-kind violation', () {
      final reason = denial(
        preTool('Edit', {
          'file_path': fixture.path('lib/legacy.dart'),
          'old_string': 'BoxDecoration();',
          'new_string': 'BoxDecoration(); final c = BoxShadow();',
        }),
      );
      expect(reason, contains('raw-decoration'));
    });

    test('allows a new screen composed of TDS components', () {
      expect(
        preTool('Write', {
          'file_path': fixture.path('lib/screen.dart'),
          'content':
              "Widget build(c) => Padding(padding: p, child: TdsButton(onPressed: f));\n",
        }),
        isNull,
      );
    });

    test('applies MultiEdit edits in order', () {
      final reason = denial(
        preTool('MultiEdit', {
          'file_path': fixture.path('lib/clean.dart'),
          'edits': [
            {'old_string': 'clean', 'new_string': 'step'},
            {'old_string': "TdsText('step')", 'new_string': 'Icon(Icons.add)'},
          ],
        }),
      );
      expect(reason, contains('raw-icon'));
    });

    test('denies new pubspec dependencies', () {
      final reason = denial(
        preTool('Edit', {
          'file_path': fixture.path('pubspec.yaml'),
          'old_string': 'dev_dependencies:',
          'new_string': '  flutter_svg: ^2.0.0\ndev_dependencies:',
        }),
      );
      expect(reason, contains('new-dependency'));
      expect(reason, contains('flutter_svg'));
    });

    test('ignores files outside the project', () {
      expect(
        preTool('Write', {
          'file_path': '/tmp/elsewhere/lib/x.dart',
          'content': 'GestureDetector();',
        }),
        isNull,
      );
    });
  });

  group('protected paths', () {
    final packageFile =
        'packages/tds_mobile_flutter/lib/src/components/button.dart';

    test('denies TDS package edits until the user unlocks the session', () {
      final input = {
        'file_path': fixture.path(packageFile),
        'old_string': 'Primary',
        'new_string': 'Main',
      };
      expect(denial(preTool('Edit', input)), contains('#tds-unlock'));
      unlock();
      expect(preTool('Edit', input), isNull);
      expect(denial(preTool('Edit', input, session: 'other')), isNotNull);
    });

    test('denies hand-written SVG assets', () {
      expect(
        denial(
          preTool('Write', {
            'file_path': fixture.path('assets/icons/new.svg'),
            'content': '<svg/>',
          }),
        ),
        contains('SVG'),
      );
    });

    test('denies direct catalog edits even when unlocked', () {
      unlock();
      expect(
        denial(
          preTool('Write', {
            'file_path': fixture.path(catalogPath),
            'content': '# made up',
          }),
        ),
        contains('catalog --write'),
      );
    });

    test('denies harness edits until unlocked', () {
      expect(
        denial(
          preTool('Edit', {
            'file_path': fixture.path('AGENTS.md'),
            'old_string': 'rules',
            'new_string': 'none',
          }),
        ),
        isNotNull,
      );
    });

    test('denies accepting a raised baseline until unlocked', () {
      final accept = {
        'command': 'dart tool/tds_guard/tds_guard.dart baseline --accept',
      };
      expect(denial(preTool('Bash', accept)), contains('--accept'));
      expect(
        preTool('Bash', {
          'command': 'dart tool/tds_guard/tds_guard.dart check',
        }),
        isNull,
      );
      unlock();
      expect(preTool('Bash', accept), isNull);
    });
  });

  group('Stop', () {
    Map<String, Object?>? stop({bool active = false}) =>
        run({'hook_event_name': 'Stop', 'stop_hook_active': active});

    void start() => expect(
      run({'hook_event_name': 'SessionStart', 'source': 'startup'}),
      isNull,
    );

    test('lets a clean session stop', () {
      start();
      expect(stop(), isNull);
    });

    test('blocks once for violations written outside Edit/Write', () {
      start();
      fixture.write('lib/clean.dart', 'ClipRRect(child: x);\n');
      final blocked = stop()!;
      expect(blocked['decision'], 'block');
      expect(blocked['reason'], contains('lib/clean.dart'));
      expect(blocked['reason'], contains('raw-paint'));

      final escalated = stop(active: true)!;
      expect(escalated.containsKey('decision'), isFalse);
      expect(escalated['systemMessage'], contains('raw-paint'));
    });

    test('ignores violations that existed before the session started', () {
      // e.g. another worker's uncommitted change in the same worktree
      fixture.write('lib/other.dart', 'GestureDetector(onTap: f);\n');
      start();
      expect(stop(), isNull);
    });

    test('checks the whole tree when the session has no snapshot', () {
      fixture.write('lib/other.dart', 'GestureDetector(onTap: f);\n');
      expect(stop()!['reason'], contains('lib/other.dart'));
    });

    test('reports a stale catalog after unlocked package changes', () {
      start();
      unlock();
      fixture.write(
        'packages/tds_mobile_flutter/lib/src/components/button.dart',
        'class TdsButton extends StatelessWidget {}\nclass TdsChip {}\n',
      );
      expect(stop()!['reason'], contains('catalog-stale'));
    });

    test('blocks protected files changed during the session', () {
      start();
      fixture.write('AGENTS.md', '# no rules\n');
      final blocked = stop()!;
      expect(blocked['decision'], 'block');
      expect(blocked['reason'], contains('AGENTS.md'));
    });

    test('allows protected changes in an unlocked session', () {
      start();
      unlock();
      fixture.write('AGENTS.md', '# updated rules\n');
      expect(stop(), isNull);
    });

    test('allows lowering the baseline but not raising it', () {
      start();
      fixture.write('lib/legacy.dart', "final a = TdsText('fixed');\n");
      saveBaseline(
        fixture.root,
        ratchetBaseline(loadBaseline(fixture.root), measureTree(fixture.root)),
      );
      expect(stop(), isNull);

      // Raised above the count recorded when the session started.
      fixture.write('lib/legacy.dart', 'BoxDecoration(); BoxShadow();\n');
      saveBaseline(fixture.root, measureTree(fixture.root));
      final blocked = stop()!;
      expect(blocked['reason'], contains(baselinePath));
    });
  });

  test('malformed input never blocks', () {
    final outcome = handleHook({'hook_event_name': 'PreToolUse'}, fixture.root);
    expect(outcome.exitCode, 0);
    expect(outcome.stdout, isEmpty);
  });
}
