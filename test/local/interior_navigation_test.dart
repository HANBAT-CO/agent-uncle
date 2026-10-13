import 'dart:async';
import 'dart:typed_data';
import 'package:agent_uncle/core/media/native_media_picker.dart';
import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:agent_uncle/local/presentation/social.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:agent_uncle/local/presentation/delivery.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'app_flow_test.dart' show settle, drainClose, PickableAttachment;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;
import 'chat_media_navigation_test.dart' show FakeNativeMediaPicker;

void main() {
  testWidgets(
    'chat icon controls keep request, photo and retry behavior accessible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 844);
      addTearDown(tester.view.reset);
      final f = Fixture();
      late String request;
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        request = await f.request();
      });
      await tester.pumpWidget(
        AgentUncleApp(
          services: AppServices(
            session: f.session,
            workspace: f.workspace,
            attachments: PickableAttachment(f.attachments),
          ),
        ),
      );
      await settle(tester);
      unawaited(
        openPage(
          tester.element(find.byType(HomeTabPage).first),
          ChatPage(
            f.uncle,
            mediaPicker: FakeNativeMediaPicker(
              NativeMediaSelection(
                name: 'photo.png',
                bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
                mime: 'image/png',
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      for (final label in ['새 사입 요청', '사진 첨부', '요청 연결', '메시지 전송']) {
        final button = find.bySemanticsLabel(label);
        expect(button.hitTestable(), findsOneWidget);
        final rect = tester.getRect(button);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(
          tester.getSemantics(button),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      }
      await tester.tap(find.bySemanticsLabel('요청 연결'));
      await settle(tester);
      await tester.tap(find.text('셔츠'));
      await settle(tester);
      expect(find.text('연결된 요청 보기'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('연결된 요청 변경'));
      await settle(tester);
      await tester.tap(find.text('요청 연결 안 함'));
      await settle(tester);
      expect(find.text('연결된 요청 보기'), findsNothing);
      await tester.tap(find.bySemanticsLabel('요청 연결'));
      await settle(tester);
      await tester.tap(find.text('셔츠'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('사진 첨부'));
      await settle(tester);
      await tester.tap(find.text('갤러리에서 선택'));
      await settle(tester);
      expect(find.bySemanticsLabel('사진 추가, 1장 첨부됨'), findsOneWidget);
      final input = find.descendant(
        of: find.byType(ChatPage),
        matching: find.byType(EditableText),
      );
      await tester.enterText(input, '첨부 사진을 확인해 주세요');
      f.store.failNextWrite = true;
      await tester.tap(find.bySemanticsLabel('메시지 전송'));
      await settle(tester);
      expect(
        tester.widget<EditableText>(input).controller.text,
        '첨부 사진을 확인해 주세요',
      );
      expect(find.bySemanticsLabel('사진 추가, 1장 첨부됨'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('메시지 전송'));
      await settle(tester);
      final sent = f.workspace
          .records('messages')
          .where((m) => m.s('body') == '첨부 사진을 확인해 주세요');
      expect(sent, hasLength(1));
      expect(sent.single.s('requestId'), request);
      expect(sent.single.list('attachments'), hasLength(1));
      expect(tester.widget<EditableText>(input).controller.text, isEmpty);
      expect(find.bySemanticsLabel('사진 첨부'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );

  testWidgets(
    'chat opens at the latest message and sends from older history with the keyboard open',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final f = Fixture();
      late String request;
      await tester.runAsync(() async {
        await f.start();
        await f.session.finishOnboarding();
        request = await f.request();
        for (var i = 0; i < 18; i++) {
          await f.workspace.sendMessage(
            f.uncle,
            'history-$i',
            '상품 확인 메시지 $i',
            [],
            requestId: request,
          );
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      final services = AppServices(
        session: f.session,
        workspace: f.workspace,
        attachments: f.attachments,
      );
      await tester.pumpWidget(AgentUncleApp(services: services));
      await settle(tester);
      unawaited(
        openPage(
          tester.element(find.byType(HomeTabPage).first),
          ChatPage(f.uncle, requestId: request),
        ),
      );
      await settle(tester);
      expect(find.text('상품 확인 메시지 17').hitTestable(), findsOneWidget);
      final header = find.byKey(const ValueKey('page-header'));
      final headerBounds = tester.getRect(header);
      final scroll = find.descendant(
        of: find.byType(ChatPage),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, 600));
      await settle(tester);
      expect(find.text('상품 확인 메시지 17').hitTestable(), findsNothing);
      expect(tester.getRect(header), headerBounds);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await settle(tester);
      expect(tester.getRect(header), headerBounds);
      final input = find.descendant(
        of: find.byType(ChatPage),
        matching: find.byType(EditableText),
      );
      await tester.enterText(input, '마지막 메시지 확인');
      await tester.tap(find.bySemanticsLabel('메시지 전송'));
      await settle(tester);
      expect(find.text('마지막 메시지 확인').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomRight(find.bySemanticsLabel('메시지 전송')).dy,
        lessThanOrEqualTo(544),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drainClose(tester, f.close());
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'interior forms and conversation fit $width with actual TDS large type',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = Fixture();
        late String request;
        await tester.runAsync(() async {
          await f.start();
          request = await f.request();
          await f.accept(request);
          await f.result(request, 2, 1);
          await f.session.signIn(f.retailer);
        });
        final services = AppServices(
          session: f.session,
          workspace: f.workspace,
          attachments: f.attachments,
        );
        for (final page in <Widget>[
          RequestDetailPage(request),
          RequestEditor(peerId: f.uncle),
          ChatPage(f.uncle, requestId: request),
          PartnerPage(f.uncle),
          const AddConnectionPage(),
          const ProfileForm(),
          const NotificationSettingsPage(),
          const NoticesPage(),
          DeliveryBatchPage([request]),
          ProposalPage(request, 'change'),
        ]) {
          await tester.pumpWidget(
            AppScope(services: services, child: branded(page, scale: 180)),
          );
          await settle(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: page.runtimeType.toString(),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('page-title')),
          );
          final back = tester.getRect(find.byType(TdsTopNavigationBackButton));
          expect(title.left, greaterThanOrEqualTo(back.right));
          if (page is ChatPage) {
            final action = tester.getRect(find.bySemanticsLabel('새 사입 요청'));
            expect(title.right, lessThanOrEqualTo(action.left));
          }
          await tester.pumpWidget(const SizedBox());
        }
        await drainClose(tester, f.close());
      },
    );
  }

  for (final (platform, inset, gap) in [
    (TargetPlatform.iOS, 0.0, 0.0),
    (TargetPlatform.iOS, 34.0, 10.0),
    (TargetPlatform.android, 0.0, 0.0),
    (TargetPlatform.android, 24.0, 24.0),
    (TargetPlatform.android, 34.0, 34.0),
    (TargetPlatform.android, 48.0, 48.0),
  ]) {
    testWidgets(
      'bottom navigation keeps $gap spacing on $platform with inset $inset',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.viewPadding = FakeViewPadding(bottom: inset);
        tester.view.padding = FakeViewPadding(bottom: inset);
        addTearDown(tester.view.reset);
        final f = Fixture();
        await tester.runAsync(() async {
          await f.start();
          await f.session.finishOnboarding();
        });
        await tester.pumpWidget(
          AgentUncleApp(
            services: AppServices(
              session: f.session,
              workspace: f.workspace,
              attachments: f.attachments,
            ),
          ),
        );
        await settle(tester);
        final bar = tester.getRect(find.byType(TdsLiquidTabBar));
        final bottomGap = 844 - bar.bottom;
        expect(bottomGap, closeTo(gap, .01));
        await tester.tap(find.widgetWithText(TdsTextButton, '채팅'));
        await settle(tester);
        expect(find.byType(ChatList), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await drainClose(tester, f.close());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
