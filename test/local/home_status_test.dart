import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show settle, drainClose;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  testWidgets(
    'uncle status clocks respect pending work, visibility and reduced motion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 600);
      addTearDown(tester.view.reset);
      final f = Fixture();
      await tester.runAsync(() async {
        await f.start();
        final request = await f.request();
        await f.accept(request);
        await f.result(request, 2, 1);
        await f.session.signIn(f.uncle);
      });
      final services = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      Future<void> show({bool reduced = false, bool visible = true}) async {
        await tester.pumpWidget(
          AppScope(
            services: services,
            child: branded(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: reduced),
                  child: TickerMode(
                    enabled: visible,
                    child: SingleChildScrollView(
                      child: BackdropGroup(child: Dashboard(onTab: (_) {})),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await settle(tester);
      }

      Finder motion(String clock) => find.descendant(
        of: find.byKey(ValueKey(clock)),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is TdsListRowShinePainter,
        ),
      );
      await show();
      // 삼촌의 미송 답변 대기 시계는 화면에 들어올 때만 동작한다.
      expect(motion('recheck-clock'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('recheck-clock')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(motion('recheck-clock'), findsOneWidget);
      final title = tester.getRect(find.text('다음 미송 재확인'));
      final clock = tester.getRect(find.byKey(const ValueKey('recheck-clock')));
      expect(clock.center.dy, closeTo(title.center.dy, 1));
      expect(
        clock.bottom,
        lessThan(tester.getTopLeft(find.text('2026-10-12')).dy),
      );
      await tester.pumpAndSettle();
      expect(motion('recheck-clock'), findsNothing);

      await show(visible: false);
      expect(motion('recheck-clock'), findsNothing);
      await show();
      expect(motion('recheck-clock'), findsOneWidget);
      await show(reduced: true);
      expect(motion('recheck-clock'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );
}
