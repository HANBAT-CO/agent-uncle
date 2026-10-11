import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import '../test/local/workspace_test.dart' show Fixture;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native role screens, partial delivery and keyboard input', (
    tester,
  ) async {
    final f = Fixture();
    await f.start();
    await f.session.finishOnboarding();
    final request = await f.request();
    await f.accept(request);
    await f.result(request, 2, 1);
    final delivery = await f.deliver(request, 1);
    await f.receive(delivery, 1);
    final services = AppServices(
      session: f.session,
      workspace: f.workspace,
      attachments: f.attachments,
    );
    await tester.pumpWidget(AgentUncleApp(services: services));
    await tester.pumpAndSettle();
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    if (platform == 'android') {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('saip-$platform-retailer');
    await tester.tap(find.widgetWithText(TdsTextButton, '요청하기'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(TdsButton, '새로 작성');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byWidgetPredicate((w) => w is Field && w.label == '상품명'),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.enterText(field, '모바일 입력 확인');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('saip-$platform-input');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final close = find.widgetWithText(TdsButton, '초안 저장 후 닫기');
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(f.workspace.records('drafts').single.s('product'), '모바일 입력 확인');
    await f.session.signIn(f.uncle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TdsTextButton, '전달'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('saip-$platform-delivery');
    expect(find.text('전달할 물품'), findsWidgets);
    expect(f.workspace.request(request)!.available, 1);
    expect(f.workspace.request(request)!.backorder, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await f.close();
  });
}
