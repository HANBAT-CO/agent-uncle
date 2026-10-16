import 'dart:async';

import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/requests.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'app_flow_test.dart' show drainClose, enter, settle, tapButton;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

class _DraftWorkspace extends LocalWorkspaceRepository {
  _DraftWorkspace(Fixture fixture) : super(fixture.store, fixture.session);

  int saves = 0, deletions = 0;
  Completer<void>? nextSave;
  bool failDeletion = false;

  @override
  Future<String> saveDraft(String id, Data values) async {
    saves++;
    final wait = nextSave;
    nextSave = null;
    await wait?.future;
    return super.saveDraft(id, values);
  }

  @override
  Future<void> deleteDraft(String id) async {
    deletions++;
    if (failDeletion) throw const AppFailure('초안을 비우지 못했어요');
    return super.deleteDraft(id);
  }
}

class _DraftHarness {
  final fixture = Fixture();
  final guard = TabSaveGuard();
  late _DraftWorkspace workspace;

  Future<void> start(WidgetTester tester, {Data? draft}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await fixture.start();
      workspace = _DraftWorkspace(fixture);
      if (draft != null) await workspace.saveDraft('saved-draft', draft);
      workspace.saves = 0;
    });
    final services = AppServices(
      session: fixture.session,
      workspace: workspace,
      attachments: fixture.attachments,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      fixture.workspace.dispose();
      await drainClose(tester, fixture.store.close());
    });
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: TabSaveScope(
          guard: guard,
          child: branded(
            const PageFrame(title: '요청 작성', children: [RequestHub()]),
          ),
        ),
      ),
    );
    await settle(tester);
    unawaited(
      openPage<void>(
        tester.element(find.byType(RequestHub)),
        RequestEditor(draftId: draft == null ? null : 'saved-draft'),
      ),
    );
    await settle(tester);
  }
}

void main() {
  testWidgets('기본 담당자·배송지와 빈 도매처만 있으면 탭 전환·닫기에도 저장하지 않는다', (tester) async {
    final harness = _DraftHarness();
    await harness.start(tester);
    expect(find.text('초안 저장됨'), findsNothing);
    await enter(tester, '도매처 이름', '   ');
    await tapButton(tester, '도매처 추가 (1/10)');
    final remove = find.widgetWithText(TdsTextButton, '이 도매처 삭제').last;
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await settle(tester);

    expect(harness.guard.save, isNotNull);
    await tester.runAsync(() => harness.guard.save!());
    await settle(tester);
    await tapButton(tester, '닫기');
    expect(find.byType(RequestEditor), findsNothing);
    expect(harness.workspace.saves, 0);
    expect(harness.workspace.deletions, 0);
    expect(harness.workspace.records('drafts'), isEmpty);
    expect(find.text('작성 중인 요청이 없어요'), findsOneWidget);
    expect(find.text('연결 전에도 초안을 작성할 수 있어요.'), findsNothing);
    expect(find.text('최근 요청'), findsNothing);
    expect(find.text('이전 요청으로 다시 작성'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 초안을 모두 비우면 삭제하고 실패 시 재시도할 때까지 뒤로가기를 보호한다', (tester) async {
    final harness = _DraftHarness();
    await harness.start(
      tester,
      draft: {
        'requestType': 'wholesaler',
        'wholesaler': '기존 도매처',
        'location': '상가 2층',
        'quantity': 1,
      },
    );
    await enter(tester, '도매처 이름', '');
    expect(harness.workspace.records('drafts').single.s('location'), '상가 2층');
    harness.workspace.failDeletion = true;
    await enter(tester, '위치', '');
    expect(find.text('초안을 비우지 못했어요'), findsOneWidget);
    final popScope = find.descendant(
      of: find.byType(RequestEditor),
      matching: find.byWidgetPredicate((widget) => widget is PopScope),
    );
    expect(tester.widget<PopScope>(popScope).canPop, isFalse);
    await tapButton(tester, '닫기');
    expect(find.byType(RequestEditor), findsOneWidget);
    expect(harness.workspace.records('drafts'), hasLength(1));

    harness.workspace.failDeletion = false;
    await tapButton(tester, '초안 저장 다시 시도');
    expect(harness.workspace.records('drafts'), isEmpty);
    expect(find.text('초안 저장됨'), findsNothing);
    expect(tester.widget<PopScope>(popScope).canPop, isTrue);
    await tapButton(tester, '닫기');
    expect(find.byType(RequestEditor), findsNothing);
    expect(harness.workspace.records('drafts'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final failSave in [false, true]) {
    testWidgets(
      '저장 대기 중 내용을 지우면 ${failSave ? '저장 실패' : '저장 완료'} 후에도 빈 초안을 남기지 않는다',
      (tester) async {
        final harness = _DraftHarness();
        await harness.start(tester);
        final save = Completer<void>();
        harness.workspace.nextSave = save;
        await enter(tester, '도매처 이름', '저장 대기 도매처');
        await enter(tester, '도매처 이름', '');
        expect(harness.workspace.saves, 1);
        expect(harness.workspace.records('drafts'), isEmpty);

        if (failSave) {
          save.completeError(const AppFailure('저장 실패'));
        } else {
          save.complete();
        }
        await settle(tester);
        expect(harness.workspace.records('drafts'), isEmpty);
        expect(harness.workspace.saves, 1);
        expect(harness.workspace.deletions, failSave ? 0 : 1);
        expect(find.text('초안 저장됨'), findsNothing);
        await tapButton(tester, '닫기');
        expect(find.byType(RequestEditor), findsNothing);
        expect(harness.workspace.saves, 1);
        expect(harness.workspace.records('drafts'), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
