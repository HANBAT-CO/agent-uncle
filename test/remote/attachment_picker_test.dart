import 'dart:io';
import 'dart:typed_data';

import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/remote/remote_attachments.dart';
import 'package:agent_uncle/remote/remote_store.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakePicker {
  FakePicker([this.file]);
  final XFile? file;
  final captured = <XTypeGroup>[];
  Future<XFile?> call({List<XTypeGroup> acceptedTypeGroups = const []}) async {
    captured.addAll(acceptedTypeGroups);
    return file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database device;
  late RemoteStore store;
  late Directory tempDir;

  setUp(() async {
    device = await databaseFactoryMemory.openDatabase(newId());
    tempDir = await Directory.systemTemp.createTemp('remote-attachment-picker');
    store = RemoteStore(
      SupabaseClient('https://example.supabase.co', 'public-test-key'),
      device,
      liveUpdates: false,
    );
  });
  tearDown(() async {
    store.dispose();
    await tempDir.delete(recursive: true);
    await device.close();
  });

  Future<XFile> tempFile(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return XFile(file.path);
  }

  RemoteAttachmentRepository repo(FakePicker picker) =>
      RemoteAttachmentRepository(store, pickFile: picker.call);

  test('서류는 JPG·JPEG·PNG·PDF, 사진은 이미지로만 파일 창을 연다', () async {
    final picker = FakePicker();
    final repository = repo(picker);
    expect(await repository.pick(document: true), isNull);
    expect(await repository.pick(document: false), isNull);

    final document = picker.captured[0];
    expect(document.extensions, ['jpg', 'jpeg', 'png', 'pdf']);
    expect(document.uniformTypeIdentifiers, [
      'public.jpeg',
      'public.png',
      'com.adobe.pdf',
    ]);
    expect(document.mimeTypes, ['image/jpeg', 'image/png', 'application/pdf']);

    final photo = picker.captured[1];
    expect(photo.extensions, ['jpg', 'jpeg', 'png']);
    expect(photo.uniformTypeIdentifiers, ['public.jpeg', 'public.png']);
    expect(photo.mimeTypes, ['image/jpeg', 'image/png']);
  });

  test('사진 선택에서는 PDF를 받지 않는다', () async {
    final repository = repo(
      FakePicker(await tempFile('a.pdf', [37, 80, 68, 70])),
    );
    await expectLater(
      repository.pick(document: false),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          '지원하는 파일 형식을 선택해 주세요.',
        ),
      ),
    );
  });

  test('10MB를 넘는 파일은 업로드 전에 거부한다', () async {
    final repository = repo(
      FakePicker(await tempFile('a.jpg', Uint8List(10 * 1024 * 1024 + 1))),
    );
    await expectLater(
      repository.pick(document: true),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          '10MB 이하 파일을 선택해 주세요.',
        ),
      ),
    );
  });

  test('유효한 PDF 선택은 저장 경로로 이어져 로그인 검사까지 도달한다', () async {
    final repository = repo(
      FakePicker(await tempFile('a.pdf', [37, 80, 68, 70])),
    );
    await expectLater(
      repository.pick(document: true),
      throwsA(
        isA<AppFailure>().having((e) => e.message, 'message', '로그인이 필요해요.'),
      ),
    );
  });
}
