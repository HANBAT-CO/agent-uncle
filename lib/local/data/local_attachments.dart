import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:sembast/sembast.dart';
import '../domain/models.dart';
import 'local_store.dart';

class LocalAttachmentRepository implements AttachmentRepository {
  LocalAttachmentRepository(this.store, this.session, this.workspace);
  final LocalStore store;
  final SessionRepository session;
  final WorkspaceRepository workspace;
  @override
  Future<String?> pick({required bool document}) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: document ? '사진 또는 PDF' : '사진',
          extensions: document
              ? ['jpg', 'jpeg', 'png', 'pdf']
              : ['jpg', 'jpeg', 'png'],
          uniformTypeIdentifiers: document
              ? ['public.jpeg', 'public.png', 'com.adobe.pdf']
              : ['public.jpeg', 'public.png'],
          mimeTypes: document
              ? ['image/jpeg', 'image/png', 'application/pdf']
              : ['image/jpeg', 'image/png'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const AppFailure('10MB 이하 파일을 선택해 주세요.');
    }
    final extension = file.name.split('.').last.toLowerCase();
    if (!(document ? ['jpg', 'jpeg', 'png', 'pdf'] : ['jpg', 'jpeg', 'png'])
        .contains(extension)) {
      throw const AppFailure('지원하는 파일 형식을 선택해 주세요.');
    }
    return save(
      file.name,
      await file.readAsBytes(),
      extension == 'pdf'
          ? 'application/pdf'
          : extension == 'png'
          ? 'image/png'
          : 'image/jpeg',
    );
  }

  @override
  Future<String> save(String name, Uint8List bytes, String mime) async {
    final owner = session.current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const AppFailure('파일은 0바이트보다 크고 10MB 이하여야 해요.');
    }
    final id = newId();
    await store.database.transaction((txn) async {
      if (store.failNextWrite) {
        store.failNextWrite = false;
        throw const AppFailure('첨부를 저장하지 못했어요. 다시 시도해 주세요.');
      }
      await store.table('attachmentPayloads').record(id).put(txn, {
        'bytes': base64Encode(bytes),
      });
      await store.table('attachments').record(id).put(txn, {
        'ownerId': owner,
        'name': name,
        'mime': mime,
        'size': bytes.length,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    await store.reload();
    return id;
  }

  @override
  Future<Uint8List> bytes(String id) async {
    final user = session.current?.id;
    final meta = store.snapshot.get('attachments', id);
    final shared =
        workspace
            .records('requests')
            .any((r) => r.list('photos').contains(id)) ||
        workspace
            .records('messages')
            .any((r) => r.list('attachments').contains(id)) ||
        workspace.partners.any((a) => a.s('photoId') == id);
    if (user == null ||
        meta == null ||
        (meta.s('ownerId') != user && !shared)) {
      throw const AppFailure('이 첨부파일을 볼 수 없어요.');
    }
    final payload = await store
        .table('attachmentPayloads')
        .record(id)
        .get(store.database);
    if (payload == null) throw const AppFailure('첨부파일을 찾을 수 없어요.');
    return base64Decode(textOf(payload, 'bytes'));
  }
}
