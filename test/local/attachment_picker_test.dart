import 'dart:io';
import 'dart:typed_data';

import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workspace_test.dart' show Fixture;

class FakePicker {
  FakePicker([this.file]);
  final XFile? file;
  final captured = <XTypeGroup>[];
  Future<XFile?> call({List<XTypeGroup> acceptedTypeGroups = const []}) async {
    captured.addAll(acceptedTypeGroups);
    return file;
  }
}

final pdfBytes = Uint8List.fromList([37, 80, 68, 70]);

void main() {
  late Fixture f;
  late Directory tempDir;
  setUp(() async {
    f = Fixture();
    await f.start();
    tempDir = await Directory.systemTemp.createTemp('local-attachment-picker');
  });
  tearDown(() async {
    await tempDir.delete(recursive: true);
    await f.store.close();
  });

  Future<XFile> tempFile(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return XFile(file.path);
  }

  LocalAttachmentRepository repo(FakePicker picker) =>
      LocalAttachmentRepository(
        f.store,
        f.session,
        f.workspace,
        pickFile: picker.call,
      );

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

  test('대문자 확장자의 PDF 서류도 application/pdf로 저장한다', () async {
    final repository = repo(FakePicker(await tempFile('사업자등록증.PDF', pdfBytes)));
    final id = await repository.pick(document: true);
    final meta = f.store.snapshot.get('attachments', id!)!;
    expect(meta.s('mime'), 'application/pdf');
    expect(meta.s('name'), '사업자등록증.PDF');
    expect(await repository.bytes(id), pdfBytes);
  });

  test('JPEG 사진은 image/jpeg로 저장한다', () async {
    final repository = repo(FakePicker(await tempFile('a.jpeg', [1, 2, 3])));
    final id = await repository.pick(document: false);
    expect(f.store.snapshot.get('attachments', id!)!.s('mime'), 'image/jpeg');
  });

  test('사진 선택에서는 PDF를 받지 않는다', () async {
    final repository = repo(FakePicker(await tempFile('a.pdf', pdfBytes)));
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

  test('지원하지 않는 확장자는 서류에서도 거부한다', () async {
    final repository = repo(FakePicker(await tempFile('a.gif', [1])));
    await expectLater(
      repository.pick(document: true),
      throwsA(isA<AppFailure>()),
    );
  });

  test('10MB를 넘는 파일은 거부한다', () async {
    final repository = repo(
      FakePicker(await tempFile('a.png', Uint8List(10 * 1024 * 1024 + 1))),
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
}
