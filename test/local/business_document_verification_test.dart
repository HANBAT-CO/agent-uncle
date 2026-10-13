import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show drainClose, settle;
import 'brand_surfaces_test.dart' show branded;
import 'workspace_test.dart' show Fixture;

void main() {
  test(
    'business document verification label follows document and number state',
    () {
      expect(businessDocumentVerificationLabel({}), '미등록');
      expect(
        businessDocumentVerificationLabel({
          'documentId': 'doc-1',
          'verificationStatus': 'verified',
          'verifiedDocumentId': 'doc-1',
          'businessNumber': '123-45-67890',
          'verifiedBusinessNumber': '1234567890',
        }),
        '검증 완료',
      );
      expect(
        businessDocumentVerificationLabel({
          'documentId': 'doc-2',
          'verificationStatus': 'verified',
          'verifiedDocumentId': 'doc-1',
          'businessNumber': '123-45-67890',
          'verifiedBusinessNumber': '1234567890',
        }),
        '제출됨 · 검증 전',
      );
      expect(
        businessDocumentVerificationLabel({
          'documentId': 'doc-1',
          'verificationStatus': 'verified',
          'verifiedDocumentId': 'doc-1',
          'businessNumber': '123-45-00000',
          'verifiedBusinessNumber': '1234567890',
        }),
        '제출됨 · 검증 전',
      );
      expect(
        businessDocumentVerificationLabel({
          'documentId': 'doc-1',
          'verificationStatus': 'rejected',
          'verificationNote': '번호가 흐리게 보입니다.',
        }),
        '재제출 필요 · 번호가 흐리게 보입니다.',
      );
    },
  );

  testWidgets('MyPage shows the verified business document label', (
    tester,
  ) async {
    final fixture = Fixture();
    await tester.runAsync(() async {
      await fixture.start();
      await fixture.session.finishOnboarding();
      await fixture.store.write(fixture.retailer, '', (state) {
        final account = state.require('accounts', fixture.retailer);
        state.put('accounts', fixture.retailer, {
          ...account,
          'verificationStatus': 'verified',
          'verifiedDocumentId': textOf(account, 'documentId'),
          'verifiedBusinessNumber': textOf(account, 'businessNumber'),
        });
        return fixture.retailer;
      });
    });
    final services = AppServices(
      session: fixture.session,
      workspace: fixture.workspace,
      attachments: fixture.attachments,
    );
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: branded(
          PageFrame(title: '내 프로필', back: false, children: const [MyPage()]),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('사업자 서류'), findsOneWidget);
    expect(find.text('검증 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, fixture.store.close());
  });
}
