import 'package:flutter_test/flutter_test.dart';

import '../../tool/tds_guard/src/catalog.dart';
import 'fixture.dart';

void main() {
  late GuardFixture fixture;
  setUp(() => fixture = GuardFixture.create());
  tearDown(() => fixture.dispose());

  test('lists public exported declarations with their first doc line', () {
    fixture
      ..write('packages/tds_mobile_flutter/lib/src/components/button.dart', '''
/// Primary action.
///
/// Second paragraph.
class TdsButton extends StatelessWidget {}

enum TdsButtonSize { small, large }

class _Private extends StatelessWidget {}

/// Opens a TDS dialog.
Future<bool?> showTdsConfirm(BuildContext context) async => null;

Widget Function(Widget)? tdsMask(bool squircle) => null;
''')
      ..write(
        'packages/tds_mobile_flutter/lib/src/components/unexported.dart',
        'class TdsHidden {}\n',
      );
    final catalog = generateCatalog(fixture.root);
    expect(
      catalog,
      contains(
        '| `TdsButton` | class extends StatelessWidget | Primary action. |',
      ),
    );
    expect(catalog, contains('| `TdsButtonSize` | enum |  |'));
    expect(
      catalog,
      contains('| `showTdsConfirm` | function | Opens a TDS dialog. |'),
    );
    expect(catalog, contains('| `tdsMask` | function |  |'));
    expect(catalog, isNot(contains('`Function`')));
    expect(catalog, isNot(contains('_Private')));
    expect(catalog, isNot(contains('TdsHidden')));
  });

  test('lists public app composition widgets separately', () {
    fixture.write(
      'lib/local/presentation/layout.dart',
      '/// Card | surface.\nclass FigmaSurface extends StatelessWidget {}\n',
    );
    final catalog = generateCatalog(fixture.root);
    expect(catalog, contains('lib/local/presentation/layout.dart'));
    expect(
      catalog,
      contains(
        r'| `FigmaSurface` | class extends StatelessWidget | Card \| surface. |',
      ),
    );
  });

  test('is deterministic', () {
    expect(generateCatalog(fixture.root), generateCatalog(fixture.root));
  });
}
