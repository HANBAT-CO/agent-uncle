import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets('채팅 차단 취소·확정·해제와 상대 차단 반영', (tester) async {
    final f = Fixture();
    await tester.runAsync(f.start);
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
    final field = find.byWidgetPredicate(
      (w) => w is TdsTextField && w.semanticLabel == '메시지',
    );
    final block = find.byWidgetPredicate(
      (w) => w is TdsTextButton && w.semanticLabel == '사용자 차단',
    );
    final unblock = find.byWidgetPredicate(
      (w) => w is TdsTextButton && w.semanticLabel == '사용자 차단 해제',
    );
    await tester.enterText(field, '작성 중인 메시지');
    await tester.tap(block);
    await settle(tester);
    expect(find.text('이 사용자를 차단할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(f.workspace.isChatBlocked(f.uncle), isFalse);
    await tester.tap(block);
    await settle(tester);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(f.workspace.hasBlockedUser(f.uncle), isTrue);
    expect(field, findsNothing);
    expect(unblock, findsOneWidget);
    await tester.tap(unblock);
    await settle(tester);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(f.workspace.isChatBlocked(f.uncle), isFalse);
    expect(tester.widget<TdsTextField>(field).controller!.text, '작성 중인 메시지');
    // 다른 기기에서 상대가 차단한 상황을 같은 저장소 변경으로 전달한다.
    final incomingBlock = f.store.write(f.uncle, '', (s) {
      s.put('chatBlocks', '${f.uncle}:${f.retailer}', {
        'ownerId': f.uncle,
        'peerId': f.retailer,
        'blocked': true,
      });
      return '';
    });
    await settle(tester);
    await incomingBlock;
    expect(field, findsNothing);
    expect(find.text('지금은 이 사용자와 대화할 수 없어요.'), findsOneWidget);
    expect(unblock, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
