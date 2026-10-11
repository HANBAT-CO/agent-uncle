import 'dart:io';

import '../../tool/tds_guard/src/catalog.dart';
import '../../tool/tds_guard/src/policy.dart';

/// A minimal app + TDS package tree whose baseline and catalog are current.
class GuardFixture {
  GuardFixture._(this.root);

  final Directory root;

  static GuardFixture create() {
    final fixture = GuardFixture._(
      Directory.systemTemp.createTempSync('tds_guard_'),
    );
    fixture
      ..write('pubspec.yaml', '''
name: fixture
dependencies:
  flutter:
    sdk: flutter
  tds_mobile_flutter:
    path: packages/tds_mobile_flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''')
      ..write('lib/legacy.dart', 'final a = BoxDecoration();\n')
      ..write('lib/clean.dart', "final b = TdsText('clean');\n")
      ..write(
        'packages/tds_mobile_flutter/lib/tds_mobile_flutter.dart',
        "export 'src/components/button.dart';\n",
      )
      ..write(
        'packages/tds_mobile_flutter/lib/src/components/button.dart',
        '/// Primary action.\nclass TdsButton extends StatelessWidget {}\n',
      )
      ..write('AGENTS.md', '# rules\n');
    saveBaseline(fixture.root, measureTree(fixture.root));
    fixture.write(catalogPath, generateCatalog(fixture.root));
    return fixture;
  }

  String path(String rel) => '${root.path}/$rel';

  String read(String rel) => File(path(rel)).readAsStringSync();

  void write(String rel, String content) {
    File(path(rel))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  void dispose() => root.deleteSync(recursive: true);
}
