import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^tds-native-[a-z0-9-]+$').hasMatch(name)) return false;
    await Directory('.context').create(recursive: true);
    await File('.context/$name.png').writeAsBytes(bytes);
    // Capturing successfully is not an assertion of visual parity.
    return bytes.isNotEmpty;
  },
);
