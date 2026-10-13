import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/presentation/home.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [100.0, 180.0]) {
      testWidgets('검색창 테마 일관성과 입력 흐름: 너비 $width, 글자 크기 $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = Fixture();
        await tester.runAsync(() async {
          await fixture.start();
          await fixture.request();
          await fixture.session.finishOnboarding();
        });
        final services = AppServices(
          session: fixture.session,
          workspace: fixture.workspace,
          attachments: fixture.attachments,
        );
        await tester.pumpWidget(
          AppScope(
            services: services,
            child: branded(const HomeShell(), scale: scale),
          ),
        );
        await settle(tester);

        for (final tab in ['사입 내역', '채팅', '사입삼촌']) {
          if (tab == '사입 내역') {
            await tester.ensureVisible(find.text('사입 내역 전체 보기'));
            await tester.tap(find.text('사입 내역 전체 보기'));
          } else {
            await tester.tap(find.widgetWithText(TdsTextButton, tab));
          }
          await settle(tester);
          final search = find.byType(TdsSearchField);
          final input = find.descendant(
            of: search,
            matching: find.byType(EditableText),
          );
          expect(search, findsOneWidget);
          expect(tester.getRect(search).left, 0);
          expect(tester.getSize(search).width, width);
          final appTheme = TdsTheme.of(tester.element(find.byType(HomeShell)));
          final theme = TdsTheme.of(tester.element(search));
          expect(theme, same(appTheme));
          expect(theme.platform.fontScale, scale);
          final editor = tester.widget<EditableText>(input);
          expect(editor.style.fontFamily, appTheme.textStyle().fontFamily);
          expect(editor.cursorColor, appTheme.primary);
          expect(theme.color('opacity100'), appTheme.color('greyOpacity100'));
          expect(
            tester
                .widget<ColoredBox>(
                  find
                      .descendant(of: search, matching: find.byType(ColoredBox))
                      .first,
                )
                .color,
            appTheme.color('background'),
          );

          // 앞뒤 공백이 있는 검색어도 원래 결과를 찾는다.
          final matchingQuery = tab == '사입 내역' ? '셔츠' : '사입 업체';
          await tester.enterText(input, '  $matchingQuery  ');
          await settle(tester);
          expect(find.text('검색 결과가 없어요'), findsNothing);
          expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);

          // 결과가 사라져도 입력과 포커스를 보존한다.
          await tester.enterText(input, '일치하지않는검색어');
          await settle(tester);
          expect(find.text('검색 결과가 없어요'), findsOneWidget);
          expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await settle(tester);
          expect(
            tester.widget<EditableText>(input).focusNode.hasFocus,
            isFalse,
          );
          expect(
            tester.widget<EditableText>(input).controller.text,
            '일치하지않는검색어',
          );

          // 기본 삭제 버튼은 결과를 복원하고 바로 다시 입력할 수 있게 한다.
          await tester.tap(find.bySemanticsLabel('검색어 삭제'));
          await settle(tester);
          expect(tester.widget<EditableText>(input).controller.text, isEmpty);
          expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
          expect(find.text('검색 결과가 없어요'), findsNothing);
          expect(find.textContaining(matchingQuery), findsWidgets);
          expect(tester.takeException(), isNull);
          if (tab == '사입 내역') {
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.tap(find.byType(TdsTopNavigationBackButton));
            await settle(tester);
          }
        }

        await tester.pumpWidget(const SizedBox());
        services.dispose();
        await drainClose(tester, fixture.store.close());
      });
    }
  }
}
