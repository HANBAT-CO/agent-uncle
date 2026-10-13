import 'dart:async';

import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'signup_form_test.dart' show input;

class _PendingSession extends LocalSessionRepository {
  _PendingSession(super.store);
  final saves = <Completer<void>>[];

  @override
  Future<void> saveProfile(Data fields, {bool complete = false}) {
    final save = Completer<void>();
    saves.add(save);
    return save.future;
  }
}

void main() {
  for (final role in AppRole.values) {
    testWidgets('${role.label} 가입 저장 실패·재시도 중 입력 위치와 포커스를 유지한다', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.reset);

      late LocalStore store;
      late _PendingSession session;
      late AppServices services;
      await tester.runAsync(() async {
        store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
        await store.initialize();
        session = _PendingSession(store);
        final workspace = LocalWorkspaceRepository(store, session);
        services = AppServices(
          session: session,
          workspace: workspace,
          attachments: LocalAttachmentRepository(store, session, workspace),
        );
        await session.finishOnboarding();
        await session.createAccount('입력 안정성 테스트');
        await session.chooseRole(role);
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        services.dispose();
        await drainClose(tester, store.close());
      });

      await tester.pumpWidget(AgentUncleApp(services: services));
      await settle(tester);
      final field = find.descendant(
        of: input(role == AppRole.retailer ? '매장명' : '이름(실명)'),
        matching: find.byType(EditableText),
      );
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      tester.testTextInput.enterText('매');
      await tester.pump();
      final editor = tester.widget<EditableText>(field);
      final position = tester.getTopLeft(field);
      expect(editor.focusNode.hasFocus, isTrue);
      expect(session.saves, hasLength(1));

      session.saves.single.completeError(const AppFailure('저장 연결을 확인해 주세요.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(editor.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.getTopLeft(field), position);
      expect(find.text('저장 연결을 확인해 주세요.'), findsOneWidget);

      const composing = TextEditingValue(
        text: '매장',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(editor.controller.value, composing);
      expect(editor.focusNode.hasFocus, isTrue);
      expect(tester.getTopLeft(field), position);
      expect(session.saves, hasLength(2));
      expect(find.text('저장 연결을 확인해 주세요.'), findsOneWidget);
      session.saves.last.completeError(const AppFailure('저장 연결을 확인해 주세요.'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(session.saves, hasLength(2));
      expect(editor.controller.value, composing);
      expect(editor.focusNode.hasFocus, isTrue);
      expect(tester.getTopLeft(field), position);

      tester.testTextInput.enterText('매장 입력 계속');
      await tester.pump();
      expect(session.saves, hasLength(3));
      session.saves.last.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('저장 연결을 확인해 주세요.'), findsNothing);
      expect(editor.controller.text, '매장 입력 계속');
      expect(editor.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.getTopLeft(field), position);
      expect(tester.takeException(), isNull);
    });
  }
}
