import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/layout.dart';
import 'package:agent_uncle/local/presentation/profile_avatar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

final photoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
);

class ControlledAttachments implements AttachmentRepository {
  ControlledAttachments(this.delegate);
  final AttachmentRepository delegate;
  final reads = <String>[];
  Future<Uint8List> Function(String)? load;

  @override
  Future<Uint8List> bytes(String id) async {
    reads.add(id);
    return load == null ? delegate.bytes(id) : load!(id);
  }

  @override
  Future<String?> pick({required bool document}) =>
      delegate.pick(document: document);

  @override
  Future<String> save(String name, Uint8List bytes, String mime) =>
      delegate.save(name, bytes, mime);
}

class AvatarHarness {
  final fixture = Fixture();
  late AppServices services;
  late ControlledAttachments attachments;

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(fixture.start);
    attachments = ControlledAttachments(fixture.attachments);
    services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: attachments,
    );
  }

  Future<void> show(
    WidgetTester tester,
    Account account, {
    String? photoId,
  }) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(Center(child: ProfileAvatar(account, photoId: photoId))),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  }
}

Finder get memoryPhoto => find.byWidgetPredicate(
  (widget) => widget is TdsAssetImage && widget.bytes != null,
);
Finder get lorelei => find.byWidgetPredicate(
  (widget) => widget is TdsAssetImage && widget.src.contains('/lorelei/png'),
);

void main() {
  test('계정별 기본 얼굴은 이름 변경·계정 복원 후에도 같은 seed를 사용한다', () {
    const account = Account('random-account-id', {'name': '첫 이름'});
    const renamed = Account('random-account-id', {'name': '변경한 이름'});
    const other = Account('another-random-id', {});
    expect(account.defaultAvatarUrl, renamed.defaultAvatarUrl);
    expect(account.defaultAvatarUrl, isNot(other.defaultAvatarUrl));
    final url = Uri.parse(account.defaultAvatarUrl);
    expect(url.scheme, 'https');
    expect(url.host, 'api.dicebear.com');
    expect(url.path, '/9.x/lorelei/png');
    expect(url.queryParameters, {'seed': account.id, 'size': '160'});
    const specialId = Account('id /?한글&size=999', {});
    expect(
      Uri.parse(specialId.defaultAvatarUrl).queryParameters['seed'],
      specialId.id,
    );
  });

  testWidgets('미등록 사진은 Lorelei API를 사용하고 API 실패는 인물 아이콘으로 대체한다', (
    tester,
  ) async {
    final h = AvatarHarness();
    await h.open(tester);
    final account = h.fixture.session.current!;
    final semantics = tester.ensureSemantics();
    await h.show(tester, account);
    expect(tester.widget<TdsAssetImage>(lorelei).src, account.defaultAvatarUrl);
    expect(h.attachments.reads, isEmpty);
    // 위젯 테스트의 네트워크 요청은 400으로 실패한다.
    expect(find.byType(FigmaIcon), findsOneWidget);
    expect(find.bySemanticsLabel('${account.name} 프로필 사진'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await h.close(tester);
  });

  testWidgets('등록된 사진을 실제 저장소에서 읽고 기본 아바타 요청 없이 렌더링한다', (tester) async {
    final h = AvatarHarness();
    await h.open(tester);
    late String photo;
    await tester.runAsync(() async {
      photo = await h.attachments.save('profile.png', photoBytes, 'image/png');
      await h.fixture.session.saveProfile({'photoId': photo});
    });
    await h.show(tester, h.fixture.session.current!);
    expect(h.attachments.reads, [photo]);
    expect(memoryPhoto, findsOneWidget);
    expect(lorelei, findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    await h.show(tester, h.fixture.session.current!);
    expect(h.attachments.reads, [photo], reason: '리빌드로 파일을 다시 읽지 않는다');
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('연결된 거래처의 등록 사진도 기존 첨부 권한으로 표시한다', (tester) async {
    final h = AvatarHarness();
    await h.open(tester);
    late String photo;
    await tester.runAsync(() async {
      await h.fixture.session.signIn(h.fixture.uncle);
      photo = await h.attachments.save('partner.png', photoBytes, 'image/png');
      await h.fixture.session.saveProfile({'photoId': photo});
      await h.fixture.session.signIn(h.fixture.retailer);
    });
    await h.show(tester, h.fixture.workspace.profile(h.fixture.uncle)!);
    expect(h.attachments.reads, [photo]);
    expect(memoryPhoto, findsOneWidget);
    expect(lorelei, findsNothing);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('사진 교체 후 늦게 도착한 이전 사진은 무시하고 삭제하면 같은 기본 얼굴로 돌아간다', (tester) async {
    final h = AvatarHarness();
    await h.open(tester);
    final first = Completer<Uint8List>(), second = Completer<Uint8List>();
    h.attachments.load = (id) => id == 'first' ? first.future : second.future;
    final account = h.fixture.session.current!;
    await h.show(tester, account, photoId: 'first');
    await h.show(tester, account, photoId: 'second');
    first.complete(photoBytes);
    await settle(tester);
    expect(memoryPhoto, findsNothing);
    expect(lorelei, findsNothing);
    second.complete(photoBytes);
    await settle(tester);
    expect(memoryPhoto, findsOneWidget);
    await h.show(tester, account, photoId: '');
    expect(memoryPhoto, findsNothing);
    expect(tester.widget<TdsAssetImage>(lorelei).src, account.defaultAvatarUrl);
    expect(h.attachments.reads, ['first', 'second']);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  for (final corrupt in [false, true]) {
    testWidgets(corrupt ? '손상된 사진은 Lorelei로 대체한다' : '사진 읽기 실패는 Lorelei로 대체한다', (
      tester,
    ) async {
      final h = AvatarHarness();
      await h.open(tester);
      h.attachments.load = (_) async {
        if (!corrupt) throw const AppFailure('사진을 읽을 수 없어요.');
        return Uint8List.fromList([1, 2, 3]);
      };
      await h.show(tester, h.fixture.session.current!, photoId: 'broken');
      expect(lorelei, findsOneWidget);
      expect(find.byType(FigmaIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }

  testWidgets('연결 전 상대방 사진은 읽지 않으며 계정 전환 후 늦은 사진도 표시하지 않는다', (tester) async {
    final h = AvatarHarness();
    await h.open(tester);
    const stranger = Account('unconnected', {'photoId': 'private-photo'});
    await h.show(tester, stranger);
    expect(h.attachments.reads, isEmpty);
    expect(lorelei, findsOneWidget);
    final pending = Completer<Uint8List>();
    h.attachments.load = (_) => pending.future;
    final old = h.fixture.session.current!;
    await h.show(tester, old, photoId: 'old-private-photo');
    await tester.runAsync(() => h.fixture.account('다른 계정', AppRole.retailer));
    // 같은 화면이 잠시 남아 있어도 새 세션에는 이전 사진을 보여주지 않는다.
    await h.show(tester, old, photoId: 'old-private-photo');
    pending.complete(photoBytes);
    await settle(tester);
    expect(memoryPhoto, findsNothing);
    expect(lorelei, findsOneWidget);
    expect(h.attachments.reads, ['old-private-photo']);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });
}
