import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/chat_message_actions.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  Future<({Fixture f, AppServices services})> boot(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final f = Fixture();
    await tester.runAsync(() async {
      await f.start();
      await f.workspace.sendMessage(f.uncle, 'm', '원본 메시지', []);
    });
    final services = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await drainClose(tester, f.store.close());
    });
    await tester.pumpWidget(
      AppScope(services: services, child: branded(ChatPage(f.uncle))),
    );
    await settle(tester);
    return (f: f, services: services);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TdsTextField && w.semanticLabel == label,
  );

  Future<void> choose(WidgetTester tester, String action) async {
    await tester.longPress(find.text('원본 메시지'));
    await settle(tester);
    await tester.tap(find.text(action));
    await settle(tester);
  }

  testWidgets('길게 눌러 본문을 수정하고 새 메시지 초안은 유지한다', (tester) async {
    final setup = await boot(tester);
    await tester.enterText(field('메시지'), '작성 중인 새 메시지');
    await tester.tap(find.text('원본 메시지'));
    await settle(tester);
    expect(find.text('메시지 수정'), findsNothing);
    await choose(tester, '메시지 수정');
    expect(
      tester.widget<TdsTextField>(field('수정할 메시지')).controller!.text,
      '원본 메시지',
    );
    await tester.enterText(field('수정할 메시지'), '수정한 메시지');
    await tester.tap(find.text('수정 저장'));
    await settle(tester);
    expect(find.text('수정한 메시지'), findsOneWidget);
    expect(find.textContaining(' · 수정됨'), findsOneWidget);
    expect(
      tester.widget<TdsTextField>(field('메시지')).controller!.text,
      '작성 중인 새 메시지',
    );
    expect(setup.f.workspace.records('messages').single.version, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('삭제 확인 후 흔적만 남고 다시 메뉴를 열 수 없으며 목록에도 반영한다', (tester) async {
    final setup = await boot(tester);
    await choose(tester, '메시지 삭제');
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(find.text('원본 메시지'), findsOneWidget);
    await choose(tester, '메시지 삭제');
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('원본 메시지'), findsNothing);
    expect(find.text(deletedMessageLabel), findsOneWidget);
    await tester.longPress(find.text(deletedMessageLabel));
    await settle(tester);
    expect(find.text('메시지 수정'), findsNothing);
    expect(find.text('메시지 삭제'), findsNothing);
    expect(find.byType(TdsMenuTrigger), findsNothing);
    await tester.pumpWidget(
      AppScope(
        services: setup.services,
        child: branded(const PageFrame(title: '대화', children: [ChatList()])),
      ),
    );
    await settle(tester);
    expect(find.text(deletedMessageLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final deleted in [false, true]) {
    testWidgets('편집 중 다른 기기에서 ${deleted ? '삭제' : '수정'}하면 저장을 막는다', (
      tester,
    ) async {
      final setup = await boot(tester);
      await choose(tester, '메시지 수정');
      await tester.enterText(field('수정할 메시지'), '오래된 편집');
      await tester.runAsync(() async {
        if (deleted) {
          await setup.f.workspace.deleteMessage('m', 0, 'other-delete');
        } else {
          await setup.f.workspace.editMessage('m', '다른 기기 변경', 0, 'other-edit');
        }
      });
      await settle(tester);
      expect(field('수정할 메시지'), findsNothing);
      expect(find.text('수정 저장'), findsNothing);
      expect(find.text('돌아가기'), findsOneWidget);
      await tester.tap(find.text('돌아가기'));
      await settle(tester);
      expect(
        find.text(deleted ? deletedMessageLabel : '다른 기기 변경'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('메뉴가 열린 동안 삭제되면 열린 메뉴도 사라진다', (tester) async {
    final setup = await boot(tester);
    await tester.longPress(find.text('원본 메시지'));
    await settle(tester);
    expect(find.text('메시지 삭제'), findsOneWidget);
    await tester.runAsync(
      () => setup.f.workspace.deleteMessage('m', 0, 'delete'),
    );
    await settle(tester);
    expect(find.text('메시지 삭제'), findsNothing);
    expect(find.text(deletedMessageLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('상대방 메시지에는 수정·삭제 메뉴가 없다', (tester) async {
    final setup = await boot(tester);
    await tester.runAsync(() => setup.f.session.signIn(setup.f.uncle));
    await tester.pumpWidget(
      AppScope(
        services: setup.services,
        child: branded(ChatPage(setup.f.retailer)),
      ),
    );
    await settle(tester);
    await tester.longPress(find.text('원본 메시지'));
    await settle(tester);
    expect(find.byType(TdsMenuTrigger), findsNothing);
    expect(find.text('메시지 수정'), findsNothing);
    expect(find.text('메시지 삭제'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
