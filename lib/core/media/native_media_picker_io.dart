import 'package:flutter/services.dart';

import '../../local/domain/models.dart';
import 'native_media_picker_base.dart';

const _channel = MethodChannel('agent_uncle/native_media_picker');

NativeMediaPicker createNativeMediaPicker() =>
    const _ChannelNativeMediaPicker();

class _ChannelNativeMediaPicker implements NativeMediaPicker {
  const _ChannelNativeMediaPicker();

  @override
  Future<NativeMediaSelection?> pickImage({
    required NativeMediaSource source,
  }) async {
    try {
      final payload = await _channel.invokeMethod<Object?>(
        source == NativeMediaSource.camera
            ? 'pickCameraImage'
            : 'pickGalleryImage',
      );
      if (payload == null) return null;
      if (payload is! Map) {
        throw const AppFailure('사진을 불러오지 못했어요. 다시 시도해 주세요.');
      }
      final name = payload['name'];
      final mime = payload['mime'];
      final bytes = payload['bytes'];
      if (name is! String || mime is! String || bytes is! Uint8List) {
        throw const AppFailure('사진을 불러오지 못했어요. 다시 시도해 주세요.');
      }
      return validateNativeMediaSelection(name: name, bytes: bytes, mime: mime);
    } on MissingPluginException {
      throw const AppFailure('사진 첨부 기능이 포함된 최신 앱으로 다시 실행해 주세요.');
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') return null;
      throw AppFailure(error.message ?? '사진을 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }
}
