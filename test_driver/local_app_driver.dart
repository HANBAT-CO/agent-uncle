import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^saip-(ios|android)-[a-z-]+$').hasMatch(name)) return false;
    await Directory('.context').create(recursive: true);
    await File('.context/$name.png').writeAsBytes(bytes);
    return bytes.isNotEmpty;
  },
);
