import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/retailer_purchase.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // 한국어 탭은 테스트 기본 Ahem 대신 실제 앱 글꼴의 너비로 검사한다.
    final font = FontLoader('Paperlogy')
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-5Medium.ttf'));
    await font.load();
  });
  for (final width in [320.0, 375.0]) {
    for (final scale in [100.0, 180.0]) {
      testWidgets('소매업자 탭 라벨·터치 영역 유지: $width px, 글자 $scale%', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 812);
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        tester.view.padding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.reset);
        final f = Fixture();
        await tester.runAsync(() async {
          await f.start();
          await f.session.finishOnboarding();
          await f.request();
          await f.session.signIn(f.uncle);
          await f.workspace.sendMessage(f.retailer, newId(), '상품 확인 부탁드려요', []);
          await f.session.signIn(f.retailer);
        });
        final services = AppServices(
          session: f.session,
          workspace: f.workspace,
          attachments: f.attachments,
        );
        await tester.pumpWidget(
          AppScope(
            services: services,
            child: branded(const HomeShell(), scale: scale),
          ),
        );
        await settle(tester);
        final barFinder = find.byType(TdsLiquidTabBar);
        final bar = tester.widget<TdsLiquidTabBar>(barFinder);
        expect(bar.items.map((item) => item.label), AppRole.retailer.tabs);
        expect(bar.selectedIndex, 0);
        expect(bar.items[2].badge, 1);
        for (final label in AppRole.retailer.tabs) {
          final button = find.descendant(
            of: barFinder,
            matching: find.widgetWithText(TdsTextButton, label),
          );
          final bounds = tester.getRect(button);
          expect(bounds.width, greaterThanOrEqualTo(44));
          expect(bounds.height, greaterThanOrEqualTo(44));
          final text = find.descendant(of: button, matching: find.text(label));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          expect(tester.getRect(text).left, greaterThanOrEqualTo(bounds.left));
          expect(tester.getRect(text).right, lessThanOrEqualTo(bounds.right));
        }
        for (final (label, destination) in <(String, Type)>[
          ('사입하기', RetailerPurchaseTab),
          ('채팅', ChatList),
          ('사입삼촌', ConnectionsList),
          ('내 프로필', MyPage),
          ('홈', Dashboard),
        ]) {
          await tester.tap(find.widgetWithText(TdsTextButton, label));
          await settle(tester);
          expect(find.byType(destination), findsOneWidget);
          expect(
            tester.widget<TdsLiquidTabBar>(barFinder).selectedIndex,
            AppRole.retailer.tabs.indexOf(label),
          );
          expect(tester.takeException(), isNull);
        }
        expect(
          TdsTheme.of(
            tester.element(find.byType(Dashboard)),
          ).platform.fontScale,
          scale,
          reason: '본문 글자 크기는 탭 바의 제한에 영향을 받지 않는다',
        );
        await tester.pumpWidget(const SizedBox());
        services.dispose();
        await drainClose(tester, f.store.close());
      });
    }
  }
}
