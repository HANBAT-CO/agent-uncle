import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show settle, drainClose;
import 'workspace_test.dart' show Fixture;

Widget branded(Widget child, {double scale = 100, bool highContrast = false}) =>
    WidgetsApp(
      color: AppColors.background,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        // Exercise actual enlarged TDS metrics, independently of AIT's default
        // font-scale opt-out. MediaQuery scaling alone would not do that.
        child: TdsMobileProvider(
          theme: AppThemeData(
            platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
          ),
          child: child!,
        ),
      ),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, a, b) => builder(context),
      ),
      home: child,
    );

void main() {
  testWidgets(
    'glass keeps actions interactive and high contrast keeps geometry',
    (tester) async {
      var taps = 0;
      Widget view(bool contrast) => branded(
        HomeBackdrop(
          child: Center(
            child: FigmaSurface(
              key: const ValueKey('surface'),
              style: FigmaSurfaceStyle.glass,
              children: [
                TdsButton(onPressed: () => taps++, child: const Text('확인')),
              ],
            ),
          ),
        ),
        highContrast: contrast,
      );
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byKey(const ValueKey('surface')));
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.getRect(find.byKey(const ValueKey('surface'))), bounds);
      await tester.tap(find.text('확인'));
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [100.0, 180.0]) {
      testWidgets('branded screens fit $width with TDS scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = Fixture();
        await tester.runAsync(() async {
          await f.start();
          await f.session.finishOnboarding();
          final request = await f.request();
          await f.accept(request);
          await f.result(request, 2, 1);
          await f.request();
          await f.session.saveProfile({'name': '아주 긴 이름을 가진 소매 매장과 온라인 쇼핑몰'});
        });
        final services = AppServices(
          session: f.session,
          workspace: f.workspace,
          attachments: f.attachments,
        );
        Future<void> show(Widget page) async {
          await tester.pumpWidget(
            AppScope(
              services: services,
              child: branded(page, scale: scale),
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(AppLogo), findsOneWidget);
          expect(
            TdsTheme.of(
              tester.element(find.byType(AppLogo)),
            ).platform.fontScale,
            scale,
          );
        }

        await show(const HomeShell());
        await tester.tap(find.widgetWithText(TdsTextButton, '사입하기'));
        await settle(tester);
        expect(find.byType(AppLogo), findsNothing);
        await tester.tap(find.widgetWithText(TdsTextButton, '홈'));
        await settle(tester);
        expect(find.byType(AppLogo), findsOneWidget);
        await show(const OnboardingPage());
        await show(const SocialLoginPage());
        await tester.pumpWidget(const SizedBox());
        services.dispose();
        await drainClose(tester, f.store.close());
      });
    }
  }
}
