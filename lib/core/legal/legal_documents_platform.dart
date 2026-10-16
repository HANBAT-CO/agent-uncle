import 'package:flutter/services.dart';

const _channel = MethodChannel('agent_uncle/legal_documents');

Future<bool> openLegalDocument(String url) async {
  try {
    return await _channel.invokeMethod<bool>('open', {'url': url}) ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
