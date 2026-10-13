import 'dart:typed_data';

import 'package:agent_uncle/core/media/native_media_picker.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

class RecordingAttachments implements AttachmentRepository {
  RecordingAttachments(this.delegate);

  final AttachmentRepository delegate;
  final saved = <({String name, Uint8List bytes, String mime})>[];

  @override
  Future<Uint8List> bytes(String id) => delegate.bytes(id);

  @override
  Future<String?> pick({required bool document}) =>
      delegate.pick(document: document);

  @override
  Future<String> save(String name, Uint8List bytes, String mime) {
    saved.add((name: name, bytes: bytes, mime: mime));
    return delegate.save(name, bytes, mime);
  }
}

class FakeNativeMediaPicker implements NativeMediaPicker {
  FakeNativeMediaPicker(this.selection);

  final NativeMediaSelection? selection;
  final sources = <NativeMediaSource>[];

  @override
  Future<NativeMediaSelection?> pickImage({
    required NativeMediaSource source,
  }) async {
    sources.add(source);
    return selection;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({Fixture fixture, AppServices services, RecordingAttachments attachments})
  >
  boot(WidgetTester tester) async {
    final fixture = Fixture();
    await tester.runAsync(fixture.start);
    final attachments = RecordingAttachments(fixture.attachments);
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: attachments,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, fixture.store.close());
    });
    return (fixture: fixture, services: services, attachments: attachments);
  }

  testWidgets('채팅 카메라 버튼은 TDS 바텀시트로 사진 출처를 고르고 첨부를 저장한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final setup = await boot(tester);
    final picker = FakeNativeMediaPicker(
      NativeMediaSelection(
        name: 'sample.png',
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        mime: 'image/png',
      ),
    );

    await tester.pumpWidget(
      AppScope(
        services: setup.services,
        child: branded(ChatPage(setup.fixture.uncle, mediaPicker: picker)),
      ),
    );
    await settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is TdsIconButton && widget.semanticLabel == '사진 첨부',
      ),
    );
    await settle(tester);

    expect(find.text('사진 촬영'), findsOneWidget);
    expect(find.text('갤러리에서 선택'), findsOneWidget);

    await tester.tap(find.text('갤러리에서 선택'));
    await settle(tester);

    expect(picker.sources, [NativeMediaSource.gallery]);
    expect(setup.attachments.saved.length, 1);
    expect(setup.attachments.saved.single.name, 'sample.png');
    expect(setup.attachments.saved.single.mime, 'image/png');
    expect(find.byType(AttachmentPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('채팅 본문은 320px 큰 글자에서도 본문과 메타 타이포그래피를 유지한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.reset);
    final setup = await boot(tester);
    const body = '긴 본문 메시지입니다. 줄바꿈이 자연스럽게 유지되어야 하고 메타 텍스트는 기존 크기를 유지해야 합니다.';
    await tester.runAsync(() async {
      await setup.fixture.workspace.sendMessage(
        setup.fixture.uncle,
        newId(),
        body,
        const [],
      );
    });

    await tester.pumpWidget(
      AppScope(
        services: setup.services,
        child: branded(ChatPage(setup.fixture.uncle), scale: 180),
      ),
    );
    await settle(tester);

    final messageText = tester.widget<TdsText>(
      find.byWidgetPredicate(
        (widget) => widget is TdsText && widget.data == body,
      ),
    );
    final metaText = tester.widget<TdsText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TdsText &&
            (widget.data.contains('읽음') || widget.data.contains('안 읽음')),
      ),
    );

    expect(messageText.typography, TdsTypography.t5);
    expect(metaText.typography, TdsTypography.t7);
    expect(find.text(body), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
