import 'package:flutter_test/flutter_test.dart';

import '../../tool/tds_guard/src/scanner.dart';

void main() {
  const app = 'lib/local/presentation/sample.dart';

  group('stripCommentsAndStrings', () {
    test('blanks comments and string contents but keeps offsets', () {
      const source = "a(); // Container()\nb('BoxDecoration'); /* Icon() */";
      final stripped = stripCommentsAndStrings(source);
      expect(stripped.length, source.length);
      expect(stripped.split('\n').length, 2);
      expect(stripped, isNot(contains('Container')));
      expect(stripped, isNot(contains('BoxDecoration')));
      expect(stripped, isNot(contains('Icon')));
      expect(stripped, contains('a();'));
    });

    test('keeps code inside string interpolation', () {
      final stripped = stripCommentsAndStrings(
        r"final s = 'x ${Colors.red} ${m['k']} y';",
      );
      expect(stripped, contains('Colors.red'));
      expect(stripped, isNot(contains('x ')));
    });

    test('handles nested block comments and raw strings', () {
      final stripped = stripCommentsAndStrings(
        "/* a /* Icon() */ Container() */ f(r'\\Icon()'); g('''\nImage\n''');",
      );
      expect(stripped, isNot(contains('Icon')));
      expect(stripped, isNot(contains('Container')));
      expect(stripped, isNot(contains('Image')));
      expect(stripped, contains('f('));
      expect(stripped, contains('g('));
    });
  });

  group('scanSource', () {
    test('reports raw decoration with its line number', () {
      final hits = scanSource(app, 'a();\nfinal d = BoxDecoration();\n');
      expect(hits.keys, ['raw-decoration']);
      expect(hits['raw-decoration'], [2]);
    });

    test('ignores matches inside comments and strings', () {
      final hits = scanSource(
        app,
        "// GestureDetector()\nfinal s = 'Container() Colors.red';\n",
      );
      expect(hits, isEmpty);
    });

    test('allows TDS components and layout primitives', () {
      final hits = scanSource(app, '''
Widget build(BuildContext context) => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(children: [
    TdsText('a', fontWeight: TdsFontWeight.semibold),
    const SizedBox(height: 8),
    Expanded(child: SafeArea(child: Text('b'))),
    TdsBorder(),
    FigmaIcon('bell'),
    TdsButton(fontSize: 15, onPressed: () {}),
    ColorBlock(color: TdsTheme.of(context).color('grey600')),
  ]),
);
void listen(ValueNotifier<int> n) => n.addListener(() {});
final Color? tint = null;
''');
      expect(hits, isEmpty);
    });

    test('flags raw gestures, painting, text styles, icons and images', () {
      final hits = scanSource(app, '''
GestureDetector(onTap: () {});
ClipRRect(child: x);
TextStyle(fontSize: 12);
Icon(Icons.add);
Image.memory(bytes);
AnimatedContainer(duration: d);
OverlayEntry(builder: b);
EditableText();
''');
      expect(hits.keys.toSet(), {
        'raw-gesture',
        'raw-paint',
        'raw-text-style',
        'raw-icon',
        'raw-image',
        'raw-animation',
        'raw-overlay',
        'raw-input',
      });
      expect(hits['raw-icon'], [4, 4]);
    });

    test('flags hard-coded colors and color adjustments', () {
      final hits = scanSource(app, '''
const a = Color(0xFF101010);
final b = Colors.red;
final c = AppColors.charcoal.withValues(alpha: .1);
final d = Color.fromARGB(1, 2, 3, 4);
''');
      expect(hits['raw-color'], [1, 2, 3, 4]);
    });

    test('flags forbidden imports but not commented ones', () {
      final hits = scanSource(app, '''
import 'package:flutter/material.dart' show Icons;
import "package:flutter/cupertino.dart";
import 'dart:ui' show ImageFilter;
import 'package:tds_mobile_flutter/src/foundation/line_box.dart';
// import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
''');
      expect(hits, {
        'material-import': [1],
        'cupertino-import': [2],
        'dart-ui-import': [3],
        'tds-internal-import': [4],
      });
    });

    test('flags TDS impersonation and subclassing in app code', () {
      final hits = scanSource(app, '''
class TdsFancyCard extends StatelessWidget {}
class BigButton extends TdsButton {}
''');
      expect(hits['tds-impersonation'], [1]);
      expect(hits['tds-subclass'], [2]);
    });

    test('theme layer may define colors, fonts and theme subclasses only', () {
      const theme = 'lib/core/theme/app_theme.dart';
      final hits = scanSource(theme, '''
class AppTheme extends TdsThemeData {}
const a = Color(0xFF101010);
final s = TextStyle(fontFamily: 'Paperlogy');
GestureDetector(onTap: () {});
''');
      expect(hits, {
        'raw-gesture': [4],
      });
    });
  });

  test('isGuardedSource covers app Dart files only', () {
    expect(isGuardedSource('lib/app.dart'), isTrue);
    expect(isGuardedSource('lib/local/presentation/home.dart'), isTrue);
    expect(isGuardedSource('test/app_test.dart'), isFalse);
    expect(isGuardedSource('packages/tds_mobile_flutter/lib/a.dart'), isFalse);
    expect(isGuardedSource('lib/readme.md'), isFalse);
  });

  test('every rule has an id, a message and a TDS alternative', () {
    final ids = guardRules.map((rule) => rule.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final rule in guardRules) {
      expect(rule.message, isNotEmpty, reason: rule.id);
      expect(rule.alternative, isNotEmpty, reason: rule.id);
    }
  });
}
