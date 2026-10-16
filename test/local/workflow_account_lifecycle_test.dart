import 'package:flutter_test/flutter_test.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'workspace_test.dart' show Fixture;

void main() {
  test('탈퇴는 개인 입력과 팀 접근을 정리하고 실제 보관·미정산 사실을 보존한다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    final colleague = await f.account('다른 삼촌', AppRole.uncle);
    await f.session.signIn(f.uncle);
    await f.workspace.saveWorkflowInput('amount', {'amount': '100000'});
    await f.store.write(f.uncle, '', (s) {
      s.put('favoriteWholesalers', 'favorite', {
        'ownerId': f.uncle,
        'readers': [f.uncle],
      });
      s.put('teams', 'team', {
        'memberIds': [f.uncle, colleague],
        'adminIds': [f.uncle],
        'ownerId': f.uncle,
        'readers': [f.uncle, colleague],
      });
      s.put('teamPackages', 'package', {
        'currentHolderId': f.uncle,
        'status': 'held',
        'readers': [f.uncle, colleague],
      });
      s.put('teamChats', 'private-message', {
        'senderId': f.uncle,
        'kind': 'text',
        'body': '개인 메모',
        'readers': [f.uncle, colleague],
      });
      s.put('teamChats', 'system-message', {
        'senderId': f.uncle,
        'kind': 'system',
        'body': '인계 완료',
        'readers': [f.uncle, colleague],
      });
      s.put('teamInvites', 'invite', {
        'inviterId': f.uncle,
        'inviteeId': colleague,
        'readers': [f.uncle, colleague],
      });
      s.put('invoices', 'invoice', {
        'payeeId': f.uncle,
        'remainingDueAmount': 45000,
        'status': 'partial',
        'readers': [f.uncle, f.retailer],
      });
      s.put('reimbursements', 'reimbursement', {
        'payerId': f.uncle,
        'principalAmount': 100000,
        'remainingAmount': 40000,
        'status': 'partial',
        'readers': [f.uncle, colleague],
      });
      return '';
    });
    await f.session.deleteAccount();
    expect(f.store.snapshot.all('workflowInputs'), isEmpty);
    expect(f.store.snapshot.get('favoriteWholesalers', 'favorite'), isNull);
    final team = f.store.snapshot.get('teams', 'team')!;
    expect(team.list('memberIds'), [colleague]);
    expect(team.list('adminIds'), isEmpty);
    expect(team.s('ownerId'), '');
    expect(team.b('managementRequired'), true);
    final package = f.store.snapshot.get('teamPackages', 'package')!;
    expect(package.s('currentHolderId'), f.uncle);
    expect(package.s('status'), 'held');
    expect(package.b('requiresReconciliation'), true);
    expect(package.s('reconciliationReason'), 'account_deleted');
    expect(package.list('readers'), [colleague]);
    expect(f.store.snapshot.get('teamChats', 'private-message')!.s('body'), '');
    expect(
      f.store.snapshot.get('teamChats', 'system-message')!.s('body'),
      '인계 완료',
    );
    expect(f.store.snapshot.get('teamInvites', 'invite'), isNull);
    final invoice = f.store.snapshot.get('invoices', 'invoice')!;
    expect(invoice.n('remainingDueAmount'), 45000);
    expect(invoice.s('status'), 'partial');
    expect(invoice.b('requiresReconciliation'), true);
    expect(invoice.list('readers'), [f.retailer]);
    final reimbursement = f.store.snapshot.get('reimbursements', 'reimbursement')!;
    expect(reimbursement.n('remainingAmount'), 40000);
    expect(reimbursement.s('payerId'), f.uncle);
    expect(reimbursement.b('requiresReconciliation'), true);
    expect(reimbursement.list('readers'), [colleague]);
  });
}
