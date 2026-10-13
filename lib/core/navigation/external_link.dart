import 'package:flutter/services.dart';

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

Future<bool> openExternalUrl(String value) async {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https') return false;
  try {
    return await _launcher.invokeMethod<bool>('launch', {
          'url': uri.toString(),
          'useSafariVC': false,
          'useWebView': false,
          'enableJavaScript': false,
          'enableDomStorage': false,
          'universalLinksOnly': false,
          'headers': <String, String>{},
        }) ??
        false;
  } catch (_) {
    return false;
  }
}
