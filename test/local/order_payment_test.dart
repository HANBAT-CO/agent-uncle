import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/order_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Map<String, Data>> tables;
  setUp(() {
    tables = {for (final name in collections) name: {}};
    tables['requests']!['r1'] = {
      'status': 'completed',
      'quantity': 2,
      'acquired': 2,
      'delivered': 2,
      'received': 2,
    };
    tables['invoices']!['i1'] = {
      'retailerId': 'shop1',
      'status': 'sent',
      'fieldPaymentIds': ['p1'],
      'adjustedTotalAmount': 100,
      'reportedReceiptAmount': 100,
      'confirmedReceiptAmount': 0,
    };
    tables['fieldPayments']!['p1'] = {
      'requestId': 'r1',
      'retailerId': 'shop1',
      'invoiceId': 'i1',
    };
    tables['supplierPaymentAllocations']!['a1'] = {
      'requestId': 'r1',
      'paymentId': 'p1',
      'invoiceId': 'i1',
    };
  });

  RequestRecord project([String id = 'r1']) => RequestRecord(
    id,
    projectOrderPayment(
      WorkspaceSnapshot(tables),
      Record(id, tables['requests']![id]!),
    ),
  );

  test('전액 신고와 실제 운영 확인, 삼촌 지급은 구별한다', () {
    expect(project().paymentComplete, isTrue);
    expect(project().paymentLabel, '운영 확인 대기');
    expect(project().b('platformPayoutComplete'), isFalse);
    tables['invoices']!['i1']!['confirmedReceiptAmount'] = 100;
    expect(project().paymentLabel, '운영 입금 확인');
    tables['invoices']!['i1']!['platformPayoutComplete'] = true;
    expect(project().b('platformPayoutComplete'), isTrue);
  });

  test('양 역할의 단계 이름은 수락·수령·입금에 따라 바뀐다', () {
    void expectLabels(String retailer, String uncle) {
      expect(project().stageLabelFor(AppRole.retailer), retailer);
      expect(project().stageLabelFor(AppRole.uncle), uncle);
    }

    tables['requests']!['r1']!['status'] = 'pending';
    expectLabels('대기', '사입 요청');
    tables['requests']!['r1']!['status'] = 'accepted';
    expectLabels('진행 중', '사입 중');
    tables['requests']!['r1']!['status'] = 'completed';
    tables['invoices']!['i1']!['reportedReceiptAmount'] = 0;
    expectLabels('수령(입금 전)', '완료(입금 전)');
    tables['invoices']!['i1']!['reportedReceiptAmount'] = 100;
    expectLabels('입금 완료', '입금 완료');
    tables['requests']!['r1']!['openIssues'] = 1;
    expectLabels('진행 중', '사입 중');
  });

  test('합산 현장 지급에서도 각 청구의 고객 배분만 요청에 연결한다', () {
    tables['requests']!['r2'] = {...tables['requests']!['r1']!};
    tables['invoices']!['i2'] = {
      ...tables['invoices']!['i1']!,
      'retailerId': 'shop2',
      'reportedReceiptAmount': 0,
    };
    tables['supplierPaymentAllocations']!['a2'] = {
      'requestId': 'r2',
      'paymentId': 'p1',
      'invoiceId': 'i2',
    };
    expect(
      invoiceRequestIds(
        WorkspaceSnapshot(tables),
        Record('i2', tables['invoices']!['i2']!),
      ),
      ['r2'],
    );
    expect(project().paymentComplete, isTrue);
    expect(project('r2').paymentComplete, isFalse);
  });

  test('같은 요청의 청구 여러 개가 모두 신고돼야 입금 완료다', () {
    tables['invoices']!['i2'] = {
      ...tables['invoices']!['i1']!,
      'reportedReceiptAmount': 50,
    };
    tables['supplierPaymentAllocations']!['a2'] = {
      'requestId': 'r1',
      'paymentId': 'p1',
      'invoiceId': 'i2',
    };
    expect(project().paymentComplete, isFalse);
    tables['invoices']!['i2']!['reportedReceiptAmount'] = 100;
    expect(project().paymentComplete, isTrue);
  });

  for (final invalid in <Data>[
    {'status': 'draft'},
    {'reportedReceiptAmount': 99},
    {'missingAmountCount': 1},
    {'requiresReconciliation': true},
  ]) {
    test('미완료 청구는 입금 완료가 아니다: $invalid', () {
      tables['invoices']!['i1']!.addAll(invalid);
      expect(project().paymentComplete, isFalse);
    });
  }

  test('아직 청구하지 않은 배분이나 남은 미배분 금액은 완료를 막는다', () {
    tables['supplierPaymentAllocations']!['a2'] = {
      'requestId': 'r1',
      'paymentId': 'p1',
    };
    expect(project().paymentComplete, isFalse);
    tables['supplierPaymentAllocations']!.remove('a2');
    tables['fieldPayments']!['p1']!['unallocatedAmount'] = 10;
    expect(project().paymentComplete, isFalse);
  });

  test('수령 전이나 미해결 문제가 있으면 입금 신고만으로 완료되지 않는다', () {
    tables['requests']!['r1']!['received'] = 1;
    expect(project().paymentComplete, isFalse);
    tables['requests']!['r1']!['received'] = 2;
    tables['requests']!['r1']!['openIssues'] = 1;
    expect(project().paymentComplete, isFalse);
  });
}
