import 'package:flutter_test/flutter_test.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/pickup_progress.dart';

void main() {
  Data progress(
    List<String> statuses, {
    bool scope = true,
    bool backorder = false,
    int? expected,
  }) => {
    'scopeConfirmed': scope,
    'hasBackorder': backorder,
    'expectedPackageCount': expected ?? statuses.length,
    'packages': [
      for (final status in statuses) {'status': status},
    ],
  };

  test('도매처 요청은 포장 처리 단계 중 하나에만 집계한다', () {
    expect(pickupProgressStatus(progress([])), 'pending');
    expect(pickupProgressStatus(progress(['picked', 'delivered'])), 'picked');
    expect(
      pickupProgressStatus(progress(['received', 'delivered'])),
      'delivered',
    );
    expect(
      pickupProgressStatus(progress(['received', 'received'])),
      'received',
    );
  });

  test('미확정 총량·미송·일부 포장·알 수 없는 상태는 완료가 아니다', () {
    expect(
      pickupProgressStatus(progress(['received'], scope: false)),
      'partial',
    );
    expect(
      pickupProgressStatus(progress(['received'], backorder: true)),
      'partial',
    );
    expect(
      pickupProgressStatus(progress(['received'], expected: 2)),
      'partial',
    );
    expect(
      pickupProgressStatus(progress(['received'], expected: 0)),
      'partial',
    );
    expect(pickupProgressStatus(progress(['unknown'])), 'partial');
  });

  test('본인 도매처별 포장만 투영하고 팀·장부·다른 고객은 숨긴다', () {
    final snapshot = WorkspaceSnapshot({
      'requests': {
        'request': {
          'retailerId': 'me',
          'status': 'accepted',
          'openIssues': 1,
          'wholesalers': [
            {'wholesaler': '첫 도매처'},
            {'wholesaler': '둘째 도매처'},
          ],
        },
        'other': {
          'retailerId': 'other',
          'status': 'accepted',
          'wholesaler': '비공개',
        },
      },
      'teamJobs': {
        'job': {
          'requestId': 'request',
          'wholesalerIndex': 0,
          'scopeConfirmed': true,
          'expectedPackageCount': 1,
          'teamId': 'secret-team',
        },
      },
      'teamPackages': {
        'package': {
          'jobId': 'job',
          'retailerId': 'me',
          'status': 'received',
          'quantity': 20,
          'unit': '옷',
          'currentHolderId': 'private-holder',
          'payerId': 'private-payer',
          'actualPaidAmount': 100000,
          'version': 2,
        },
        'other-package': {
          'jobId': 'job',
          'retailerId': 'other',
          'status': 'picked',
        },
      },
      'invoices': {
        'invoice': {'status': 'sent', 'remainingDueAmount': 45000},
      },
    });
    final rows = projectRetailerPickups(snapshot, 'me');
    expect(rows.map((r) => r.id), ['request:0', 'request:1']);
    expect(rows.map((r) => r.s('status')), ['received', 'pending']);
    expect(rows.first.n('openIssues'), 1);
    final package = dataRowsOf(rows.first.data, 'packages').single;
    expect(package['id'], 'package');
    expect(package['quantity'], 20); // 상품 수량을 포장 개수로 세지 않는다.
    expect(package.containsKey('currentHolderId'), false);
    expect(package.containsKey('payerId'), false);
    expect(package.containsKey('actualPaidAmount'), false);
    expect(rows.first.data.containsKey('teamId'), false);
    expect(projectRetailerPickups(snapshot, 'stranger'), isEmpty);
  });
}
