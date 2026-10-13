import 'dart:typed_data';

import '../../local/domain/models.dart';

enum NativeMediaSource { camera, gallery }

class NativeMediaSelection {
  const NativeMediaSelection({
    required this.name,
    required this.bytes,
    required this.mime,
  });

  final String name;
  final Uint8List bytes;
  final String mime;
}

abstract class NativeMediaPicker {
  Future<NativeMediaSelection?> pickImage({required NativeMediaSource source});
}

const nativeMediaMaxBytes = 10 * 1024 * 1024;

NativeMediaSelection validateNativeMediaSelection({
  required String name,
  required Uint8List bytes,
  required String mime,
}) {
  if (!{'image/jpeg', 'image/png'}.contains(mime)) {
    throw const AppFailure('지원하는 사진 형식을 선택해 주세요.');
  }
  if (bytes.isEmpty || bytes.length > nativeMediaMaxBytes) {
    throw const AppFailure('10MB 이하 사진을 선택해 주세요.');
  }
  final trimmed = name.trim();
  return NativeMediaSelection(
    name: trimmed.isEmpty ? defaultNativeMediaName(mime) : trimmed,
    bytes: bytes,
    mime: mime,
  );
}

String defaultNativeMediaName(String mime) =>
    'photo.${mime == 'image/png' ? 'png' : 'jpg'}';
