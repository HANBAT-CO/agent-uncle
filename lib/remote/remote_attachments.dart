import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/domain/models.dart';
import 'remote_store.dart';

class RemoteAttachmentRepository implements AttachmentRepository {
  RemoteAttachmentRepository(this.store);
  final RemoteStore store;
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
    final ext = file.name.split('.').last.toLowerCase();
    if (!(document ? ['jpg', 'jpeg', 'png', 'pdf'] : ['jpg', 'jpeg', 'png'])
        .contains(ext)) {
      throw const AppFailure('지원하는 파일 형식을 선택해 주세요.');
    }
    return save(
      file.name,
      await file.readAsBytes(),
      ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
          ? 'image/png'
          : 'image/jpeg',
    );
  }

  @override
  Future<String> save(String name, Uint8List bytes, String mime) async {
    final owner = store.userId;
    if (owner == null) throw const AppFailure('로그인이 필요해요.');
    if (bytes.isEmpty ||
        bytes.length > 10 * 1024 * 1024 ||
        !['image/jpeg', 'image/png', 'application/pdf'].contains(mime)) {
      throw const AppFailure('10MB 이하 사진 또는 PDF를 선택해 주세요.');
    }
    final id = newId(), path = '$owner/${newId()}';
    // The same ID names the immutable object and its metadata record.
    final attachmentId = path.split('/').last;
    try {
      await store.client.storage
          .from('saip-attachments')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime),
          );
      if (owner != store.userId) {
        throw const AppFailure('로그인 계정이 변경됐어요. 다시 첨부해 주세요.');
      }
      await store.command('registerAttachment', {
        'id': attachmentId,
        'name': name,
      }, id);
      return attachmentId;
    } catch (e) {
      // Cleanup is best effort. RLS denies deletion if registration committed
      // but its response was lost, preserving any referenced document.
      try {
        await store.client.storage.from('saip-attachments').remove([path]);
      } catch (_) {}
      throw AppFailure(friendlyError(e));
    }
  }

  @override
  Future<Uint8List> bytes(String id) async {
    try {
      // Read access is checked by Storage RLS. Resolve path through a narrow
      // RPC so a partner never needs access to private attachment metadata.
      final path =
          await store.client.rpc(
                'saip_attachment_path',
                params: {'attachment_id': id},
              )
              as String;
      return await store.client.storage.from('saip-attachments').download(path);
    } catch (e) {
      throw AppFailure(friendlyError(e));
    }
  }
}
