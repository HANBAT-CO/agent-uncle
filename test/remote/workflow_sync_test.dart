import 'dart:async';

import 'package:sembast/sembast.dart';

import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'repositories_test.dart' show Harness, actor, peer, reply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('통신 실패는 입력과 작업 번호를 보존하고 같은 요청만 재시도한다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    h.workflowResponse = reply('{"message":"network unavailable"}', 503);
    final args = <String, Object?>{'id': 'invoice-1', 'amount': 60000};
    await expectLater(
      h.workspace.workflow('wf.billing.confirmReceipt', args, 'receipt-1'),
      throwsA(isA<AppFailure>()),
    );
    expect(h.workspace.records('invoices'), isEmpty);
    expect(
      h.workspace.records('workflowPending').single.s('status'),
      'pending',
    );
    await expectLater(
      h.workspace.discardRejectedWorkflow('receipt-1'),
      throwsA(isA<AppFailure>()),
    );
    await h.store.changeUser();
    expect(
      h.workspace.records('workflowPending').single.s('operationId'),
      'receipt-1',
    );
    final calls = h.commands.length;
    await expectLater(
      h.workspace.workflow('wf.billing.confirmReceipt', {
        ...args,
        'amount': 70000,
      }, 'receipt-1'),
      throwsA(isA<AppFailure>()),
    );
    expect(h.commands.length, calls);
    h.workflowResponse = null;
    expect(
      await h.workspace.workflow('wf.billing.confirmReceipt', {
        'amount': 60000,
        'id': 'invoice-1',
      }, 'receipt-1'),
      'invoice-1',
    );
    expect(h.workspace.records('workflowPending'), isEmpty);
    final writes = h.commands
        .where((c) => c['operation_id'] == 'receipt-1')
        .toList();
    expect(writes, hasLength(2));
    expect(writes.first, writes.last);
  });

  test('확정 응답 뒤 조회 실패가 발생해도 재전송 대상으로 되돌리지 않는다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    h.failRead = true;
    expect(
      await h.workspace.workflow('wf.billing.sendInvoice', {
        'id': 'invoice-1',
      }, 'send-1'),
      'invoice-1',
    );
    expect(h.workspace.records('workflowPending'), isEmpty);
    expect(await h.store.workflowOutbox.find(h.store.device), isEmpty);
    expect(h.store.error, isNotNull);
  });

  test('서버가 거부한 작업만 지우며 입력 폼은 남긴다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    await h.workspace.saveWorkflowInput('payment:r1', {
      'amount': '60000',
      'operationId': 'payment-1',
      'submitted': {'amount': 60000},
    });
    await h.workspace.saveWorkflowInput('payment:r2', {
      'amount': '70000',
      'operationId': 'payment-2',
      'submitted': {'amount': 70000},
    });
    h.failWrite = true;
    await expectLater(
      h.workspace.workflow('wf.billing.recordFieldPayment', {
        'amount': 60000,
      }, 'payment-1'),
      throwsA(isA<AppFailure>()),
    );
    expect(
      h.workspace.records('workflowPending').single.s('status'),
      'rejected',
    );
    await h.workspace.discardRejectedWorkflow('payment-1');
    expect(h.workspace.records('workflowPending'), isEmpty);
    expect(h.workspace.workflowInput('payment:r1')['amount'], '60000');
    expect(h.workspace.workflowInput('payment:r1')['submitted'], isEmpty);
    expect(h.workspace.workflowInput('payment:r2')['submitted'], {
      'amount': 70000,
    });
    await h.store.changeUser();
    expect(h.workspace.workflowInput('payment:r1')['submitted'], isEmpty);
    expect(h.workspace.workflowInput('payment:r1')['amount'], '60000');
    expect(h.workspace.workflowInput('payment:r2')['submitted'], {
      'amount': 70000,
    });
  });

  test('입력과 재시도 목록은 계정별로 분리되고 다시 로그인하면 복구된다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    await h.workspace.saveWorkflowInput('amount', {'value': '100000'});
    h.workflowResponse = reply('{}', 503);
    await expectLater(
      h.workspace.workflow('wf.billing.sendInvoice', {'id': 'i1'}, 'op1'),
      throwsA(isA<AppFailure>()),
    );
    h.authUserId = peer;
    await h.client.auth.signInWithPassword(
      email: 'peer@example.test',
      password: 'test-password',
    );
    await h.store.changeUser();
    expect(h.workspace.workflowInput('amount'), isEmpty);
    expect(h.workspace.records('workflowPending'), isEmpty);
    await h.workspace.saveWorkflowInput('amount', {'value': '200000'});
    h.authUserId = actor;
    await h.client.auth.signInWithPassword(
      email: 'actor@example.test',
      password: 'test-password',
    );
    await h.store.changeUser();
    expect(h.workspace.workflowInput('amount')['value'], '100000');
    expect(
      h.workspace.records('workflowPending').single.s('operationId'),
      'op1',
    );
  });

  test('탈퇴 정리 이후 도착한 전송 실패가 입력과 재시도 목록을 부활시키지 않는다', () async {
    final h = Harness();
    await h.open();
    addTearDown(h.close);
    await h.workspace.saveWorkflowInput('payment', {'value': 100000});
    h.pendingWorkflow = Completer<http.Response>();
    final sending = h.workspace.workflow('wf.billing.sendInvoice', {
      'id': 'i1',
    }, 'op1');
    final failed = expectLater(sending, throwsA(isA<AppFailure>()));
    while (!h.commands.any((c) => c['operation_id'] == 'op1')) {
      await Future<void>.delayed(Duration.zero);
    }
    await h.store.clearDeletedAccount(actor);
    h.pendingWorkflow!.complete(reply('{}', 503));
    await failed;
    expect(h.workspace.records('workflowPending'), isEmpty);
    expect(h.workspace.workflowInput('payment'), isEmpty);
    expect(await h.store.workflowOutbox.find(h.store.device), isEmpty);
    expect(await h.store.workflowInputs.find(h.store.device), isEmpty);
  });
}
