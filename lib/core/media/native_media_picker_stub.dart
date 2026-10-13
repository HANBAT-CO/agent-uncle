import '../../local/domain/models.dart';
import 'native_media_picker_base.dart';

NativeMediaPicker createNativeMediaPicker() => _UnsupportedNativeMediaPicker();

class _UnsupportedNativeMediaPicker implements NativeMediaPicker {
  @override
  Future<NativeMediaSelection?> pickImage({required NativeMediaSource source}) {
    throw const AppFailure('이 플랫폼에서는 사진 첨부를 지원하지 않아요.');
  }
}
