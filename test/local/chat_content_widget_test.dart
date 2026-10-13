import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/chat_content_policy.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets('비속어 안내 후 입력을 보존하고 수정한 내용을 전송한다', (tester) async {
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
      (widget) => widget is TdsTextField && widget.semanticLabel == '메시지',
    );
    final send = find.byWidgetPredicate(
      (widget) => widget is TdsButton && widget.semanticLabel == '메시지 전송',
    );
    await tester.enterText(field, '시1발');
    await tester.tap(send);
    await settle(tester);
    expect(find.text(ChatContentPolicy.rejectionMessage), findsOneWidget);
    expect(tester.widget<TdsTextField>(field).controller!.text, '시1발');
    expect(f.workspace.records('messages'), isEmpty);

    await tester.enterText(field, '상품 18개 확인 부탁드려요');
    await tester.tap(send);
    await settle(tester);
    expect(find.text(ChatContentPolicy.rejectionMessage), findsNothing);
    expect(tester.widget<TdsTextField>(field).controller!.text, isEmpty);
    expect(f.workspace.records('messages').single.s('body'), '상품 18개 확인 부탁드려요');
    expect(tester.takeException(), isNull);
  });
}
