import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:agent_uncle/local/domain/profile_validation.dart';

const retailerValues = <String, Object?>{
  'name': '매장',
  'contact': '담당자',
  'phone': '010-1234-5678',
  'businessName': '사업자',
  'businessNumber': '123-45-67890',
  'documentId': 'doc',
  'address': '서울',
  'addressDetail': '1층',
  'salesChannel': '온라인',
  'terms': true,
  'privacy': true,
};
const uncleValues = <String, Object?>{
  'contact': '삼촌',
  'phone': '01012345678',
  'pickupArea': '동대문',
  'deliveryArea': '서울',
  'deadline': '23:00',
  'terms': true,
  'privacy': true,
};

Map<String, String> retailerErrors(Map<String, Object?> patch) =>
    profileFieldErrors(
      {...retailerValues, ...patch},
      role: AppRole.retailer,
      requireSalesChannel: true,
    );
Map<String, String> uncleErrors(Map<String, Object?> patch) =>
    profileFieldErrors({...uncleValues, ...patch}, role: AppRole.uncle);

void main() {
  group('profileFieldErrors', () {
    test('formatted retailer values pass', () {
      expect(retailerErrors({}), isEmpty);
    });
    test('unformatted numbers also pass', () {
      expect(
        retailerErrors({
          'phone': '01012345678',
          'businessNumber': '1234567890',
        }),
        isEmpty,
      );
      expect(retailerErrors({'phone': '02-1234-5678'}), isEmpty);
      expect(retailerErrors({'phone': '031-123-4567'}), isEmpty);
      expect(retailerErrors({'phone': '+82 10 1234 5678'}), isEmpty);
    });
    test('retailer missing fields are listed in form order', () {
      final errors = profileFieldErrors(
        {'terms': false, 'privacy': false},
        role: AppRole.retailer,
        requireSalesChannel: true,
      );
      expect(errors.keys.toList(), [
        'name',
        'contact',
        'phone',
        'salesChannel',
        'businessName',
        'businessNumber',
        'documentId',
        'address',
        'addressDetail',
        'terms',
        'privacy',
      ]);
      expect(errors['name'], '매장명 항목을 입력해 주세요.');
      expect(errors['contact'], '담당자명 항목을 입력해 주세요.');
      expect(errors['documentId'], '사업자등록증을 첨부해 주세요.');
      expect(errors['salesChannel'], '판매 채널을 한 개 이상 선택해 주세요.');
      expect(errors['terms'], '이용약관 동의가 필요해요.');
      expect(errors['privacy'], '개인정보 처리방침 동의가 필요해요.');
    });
    test('legacy retailer edit does not require sales channel', () {
      expect(
        profileFieldErrors({
          ...retailerValues,
          'salesChannel': '',
        }, role: AppRole.retailer),
        isEmpty,
      );
    });
    test('unknown sales channel text is rejected', () {
      expect(retailerErrors({'salesChannel': '방문'}).keys, ['salesChannel']);
    });
    test('malformed phones are rejected', () {
      for (final phone in [
        '010-12-34',
        '0101234567',
        '010123456789',
        '123',
        'abc',
        '0001234567',
        '0351234567',
        '+1 555',
      ]) {
        expect(
          retailerErrors({'phone': phone})['phone'],
          '연락처를 010-1234-5678 형식으로 입력해 주세요.',
          reason: phone,
        );
      }
    });
    test('malformed business numbers are rejected', () {
      for (final number in ['12345', '12-345-67890', '123-45-678901', 'ab']) {
        expect(
          retailerErrors({'businessNumber': number})['businessNumber'],
          '사업자등록번호 10자리를 확인해 주세요.',
          reason: number,
        );
      }
    });
    test('uncle uses a real contact name without a separate business name', () {
      expect(uncleErrors({}), isEmpty);
      expect(uncleErrors({'contact': ''})['contact'], '이름(실명) 항목을 입력해 주세요.');
      expect(
        uncleErrors({'name': '', 'businessName': '', 'documentId': ''}),
        isEmpty,
      );
    });
    test(
      'uncle is not blocked by business data from an earlier retailer draft',
      () {
        expect(uncleErrors({'businessNumber': '123-45-67890'}), isEmpty);
        expect(uncleErrors({'businessNumber': '12-34'}), isEmpty);
      },
    );
    test('uncle times must be HH:mm', () {
      expect(
        uncleErrors({'deadline': '25:00'})['deadline'],
        '요청 마감시간 항목을 다시 선택해 주세요.',
      );
      expect(uncleErrors({'deadline': ''})['deadline'], '요청 마감시간 항목을 선택해 주세요.');
      expect(
        uncleErrors({'activityStart': '9시'})['activityStart'],
        '활동 시작 항목을 다시 선택해 주세요.',
      );
      expect(
        uncleErrors({'activityEnd': '24:00'})['activityEnd'],
        '활동 종료 항목을 다시 선택해 주세요.',
      );
      expect(uncleErrors({'activityStart': '', 'activityEnd': ''}), isEmpty);
    });
  });

  group('LocalSessionRepository.saveProfile', () {
    late LocalStore store;
    late LocalSessionRepository session;
    late LocalAttachmentRepository attachments;
    setUp(() async {
      store = LocalStore(await databaseFactoryMemory.openDatabase(newId()));
      await store.initialize();
      session = LocalSessionRepository(store);
      attachments = LocalAttachmentRepository(
        store,
        session,
        LocalWorkspaceRepository(store, session),
      );
    });
    tearDown(() => store.close());

    Future<String> document() => attachments.save(
      '사업자.pdf',
      Uint8List.fromList([37, 80, 68, 70]),
      'application/pdf',
    );

    test('uncle completes signup without name or business info', () async {
      await session.createAccount('삼촌 계정');
      await session.chooseRole(AppRole.uncle);
      await session.saveProfile({...uncleValues, 'name': ''}, complete: true);
      expect(session.current!.complete, true);
      expect(session.current!.s('name'), '삼촌');
      expect(session.current!.s('businessNumber'), '');
    });
    test(
      'role switch preserves the draft without requiring hidden business fields',
      () async {
        await session.createAccount('역할 변경');
        await session.chooseRole(AppRole.retailer);
        await session.saveProfile({
          'name': '이전 매장',
          'businessNumber': '123-45',
        });
        await session.chooseRole(AppRole.uncle);
        await session.saveProfile({...uncleValues, 'contact': '김'});
        await session.saveProfile({'contact': '김삼촌'}, complete: true);
        expect(session.current!.complete, isTrue);
        expect(session.current!.name, '김삼촌');
        expect(session.current!.s('businessNumber'), '123-45');
      },
    );
    test('retailer still needs the business document', () async {
      await session.createAccount('매장 계정');
      await session.chooseRole(AppRole.retailer);
      await expectLater(
        session.saveProfile({
          ...retailerValues,
          'documentId': '',
        }, complete: true),
        throwsA(predicate((e) => '$e' == '사업자등록증을 첨부해 주세요.')),
      );
    });
    test('new retailer signup requires a sales channel', () async {
      await session.createAccount('매장 계정');
      await session.chooseRole(AppRole.retailer);
      final doc = await document();
      await expectLater(
        session.saveProfile({
          ...retailerValues,
          'documentId': doc,
          'salesChannel': '',
        }, complete: true),
        throwsA(predicate((e) => '$e' == '판매 채널을 한 개 이상 선택해 주세요.')),
      );
    });
    test('complete retailer may keep a legacy empty sales channel', () async {
      await session.createAccount('매장 계정');
      await session.chooseRole(AppRole.retailer);
      final doc = await document();
      await session.saveProfile({
        ...retailerValues,
        'documentId': doc,
      }, complete: true);
      await session.saveProfile({'salesChannel': '', 'address': '새 주소'});
      expect(session.current!.s('address'), '새 주소');
    });
    test('formatted phone and business number are accepted', () async {
      await session.createAccount('매장 계정');
      await session.chooseRole(AppRole.retailer);
      final doc = await document();
      await session.saveProfile({
        ...retailerValues,
        'documentId': doc,
      }, complete: true);
      expect(session.current!.complete, true);
    });
    test('malformed phone is rejected', () async {
      await session.createAccount('삼촌 계정');
      await session.chooseRole(AppRole.uncle);
      await expectLater(
        session.saveProfile({
          ...uncleValues,
          'phone': '010-12',
        }, complete: true),
        throwsA(predicate((e) => '$e' == '연락처를 010-1234-5678 형식으로 입력해 주세요.')),
      );
    });
    test('another account\'s document is rejected even as an option', () async {
      await session.createAccount('매장 계정');
      await session.chooseRole(AppRole.retailer);
      final foreign = await document();
      await session.createAccount('삼촌 계정');
      await session.chooseRole(AppRole.uncle);
      await expectLater(
        session.saveProfile({
          ...uncleValues,
          'documentId': foreign,
        }, complete: true),
        throwsA(predicate((e) => '$e' == '본인의 사업자 서류를 등록해 주세요.')),
      );
    });
  });
}
