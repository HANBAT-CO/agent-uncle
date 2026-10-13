import 'native_media_picker_base.dart';
import 'native_media_picker_stub.dart'
    if (dart.library.io) 'native_media_picker_io.dart'
    if (dart.library.js_interop) 'native_media_picker_web.dart'
    as impl;

export 'native_media_picker_base.dart';

final NativeMediaPicker defaultNativeMediaPicker = impl
    .createNativeMediaPicker();
