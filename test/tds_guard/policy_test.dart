import 'package:flutter_test/flutter_test.dart';

import '../../tool/tds_guard/src/policy.dart';
import 'fixture.dart';

void main() {
  late GuardFixture fixture;
  setUp(() => fixture = GuardFixture.create());
  tearDown(() => fixture.dispose());

  test('parseDependencies reads top-level dependency names only', () {
    expect(parseDependencies(fixture.read('pubspec.yaml')), [
      'flutter',
      'flutter_test',
      'tds_mobile_flutter',
    ]);
  });

  test('checkTree is clean when counts match the baseline', () {
    expect(checkTree(fixture.root), isEmpty);
  });

  test('checkTree reports counts above the baseline', () {
    fixture.write(
      'lib/legacy.dart',
      'final a = BoxDecoration();\nfinal c = BoxShadow();\n',
    );
    final violations = checkTree(fixture.root);
    expect(violations, hasLength(1));
    expect(violations.single.file, 'lib/legacy.dart');
    expect(violations.single.rule, 'raw-decoration');
    expect(violations.single.lines, [1, 2]);
  });

  test('checkTree reports new files with violations', () {
    fixture.write('lib/new_screen.dart', 'GestureDetector(onTap: f);\n');
    final violations = checkTree(fixture.root);
    expect(violations.map((v) => '${v.file} ${v.rule}'), [
      'lib/new_screen.dart raw-gesture',
    ]);
  });

  test('checkTree reports new pubspec dependencies', () {
    fixture.write(
      'pubspec.yaml',
      fixture
          .read('pubspec.yaml')
          .replaceFirst(
            'dev_dependencies:',
            '  flutter_svg: ^2.0.0\ndev_dependencies:',
          ),
    );
    final violations = checkTree(fixture.root);
    expect(violations.map((v) => '${v.file} ${v.rule}'), [
      'pubspec.yaml new-dependency',
    ]);
    expect(violations.single.detail, contains('flutter_svg'));
  });

  test('checkTree reports a stale TDS catalog', () {
    fixture.write(
      'packages/tds_mobile_flutter/lib/src/components/button.dart',
      'class TdsButton extends StatelessWidget {}\nclass TdsChip {}\n',
    );
    expect(checkTree(fixture.root).map((v) => v.rule), ['catalog-stale']);
  });

  test('ratchet lowers counts, never raises them, and drops deleted files', () {
    final old = loadBaseline(fixture.root);
    fixture.write('lib/legacy.dart', 'final a = TdsBorder();\n');
    fixture.write('lib/clean.dart', 'Icon(x);\n');
    final lowered = ratchetBaseline(old, measureTree(fixture.root));
    expect(lowered.files, isEmpty);

    fixture.write('lib/legacy.dart', 'BoxDecoration(); BoxDecoration();\n');
    final kept = ratchetBaseline(old, measureTree(fixture.root));
    expect(kept.files, {
      'lib/legacy.dart': {'raw-decoration': 1},
    });
  });

  test('isBaselineRaised detects any increase or new dependency', () {
    final old = loadBaseline(fixture.root);
    expect(isBaselineRaised(old, old), isFalse);
    expect(
      isBaselineRaised(old, ratchetBaseline(old, Baseline.empty())),
      isFalse,
    );
    final raised = Baseline(
      files: {
        'lib/legacy.dart': {'raw-decoration': 2},
      },
      dependencies: old.dependencies,
    );
    expect(isBaselineRaised(old, raised), isTrue);
    final newDependency = Baseline(
      files: old.files,
      dependencies: [...old.dependencies, 'flutter_svg'],
    );
    expect(isBaselineRaised(old, newDependency), isTrue);
  });
}
