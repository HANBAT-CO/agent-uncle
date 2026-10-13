import 'dart:async';
import 'dart:js_interop';

import '../../local/domain/models.dart';
import 'native_media_picker_base.dart';

@JS('document.createElement')
external JSObject _createElement(String tag);

extension type _FileInput(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external set multiple(bool value);
  external _FileList? get files;
  external void setAttribute(String name, String value);
  external void addEventListener(String event, JSFunction listener);
  external void removeEventListener(String event, JSFunction listener);
  external void click();
}

extension type _FileList(JSObject _) implements JSObject {
  external int get length;
  external _ImageFile? item(int index);
}

extension type _ImageFile(JSObject _) implements JSObject {
  external String get name;
  external String get type;
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

NativeMediaPicker createNativeMediaPicker() => const _WebNativeMediaPicker();

class _WebNativeMediaPicker implements NativeMediaPicker {
  const _WebNativeMediaPicker();

  @override
  Future<NativeMediaSelection?> pickImage({
    required NativeMediaSource source,
  }) async {
    final input = _FileInput(_createElement('input'))
      ..type = 'file'
      ..accept = 'image/jpeg,image/png'
      ..multiple = false;
    if (source == NativeMediaSource.camera) {
      input.setAttribute('capture', 'environment');
    }
    final completer = Completer<NativeMediaSelection?>();
    var reading = false;
    final onCancel = ((JSObject _) {
      if (!completer.isCompleted && !reading) completer.complete(null);
    }).toJS;
    Future<void> readSelection() async {
      if (completer.isCompleted || reading) return;
      reading = true;
      try {
        final files = input.files;
        final file = files == null || files.length == 0 ? null : files.item(0);
        if (file == null) {
          completer.complete(null);
          return;
        }
        if (file.size > nativeMediaMaxBytes) {
          throw const AppFailure('10MB 이하 사진을 선택해 주세요.');
        }
        final mime = file.type.toLowerCase();
        if (!{'image/jpeg', 'image/png'}.contains(mime)) {
          throw const AppFailure('지원하는 사진 형식을 선택해 주세요.');
        }
        final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
        if (!completer.isCompleted) {
          completer.complete(
            validateNativeMediaSelection(
              name: file.name,
              bytes: bytes,
              mime: mime,
            ),
          );
        }
      } catch (error) {
        if (!completer.isCompleted) completer.completeError(error);
      }
    }

    final onChange = ((JSObject _) => unawaited(readSelection())).toJS;
    input.addEventListener('cancel', onCancel);
    input.addEventListener('change', onChange);
    try {
      input.click();
      return await completer.future;
    } finally {
      input.removeEventListener('cancel', onCancel);
      input.removeEventListener('change', onChange);
    }
  }
}
