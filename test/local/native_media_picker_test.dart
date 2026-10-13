import 'package:agent_uncle/core/media/native_media_picker.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('agent_uncle/native_media_picker');
  final calls = <String>[];

  setUp(() {
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('camera method channel payload를 사진 선택 결과로 변환한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return {
            'name': '',
            'mime': 'image/png',
            'bytes': Uint8List.fromList([
              0x89,
              0x50,
              0x4E,
              0x47,
              0x0D,
              0x0A,
              0x1A,
              0x0A,
            ]),
          };
        });

    final selection = await defaultNativeMediaPicker.pickImage(
      source: NativeMediaSource.camera,
    );

    expect(calls, ['pickCameraImage']);
    expect(selection, isNotNull);
    expect(selection!.name, 'photo.png');
    expect(selection.mime, 'image/png');
    expect(selection.bytes.length, 8);
  });

  test('지원하지 않는 mime payload는 거부한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return {
            'name': 'clip.gif',
            'mime': 'image/gif',
            'bytes': Uint8List.fromList([1, 2, 3]),
          };
        });

    await expectLater(
      defaultNativeMediaPicker.pickImage(source: NativeMediaSource.gallery),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          '지원하는 사진 형식을 선택해 주세요.',
        ),
      ),
    );
    expect(calls, ['pickGalleryImage']);
  });
}
