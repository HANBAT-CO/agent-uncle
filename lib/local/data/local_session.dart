import 'dart:math';
import 'package:sembast/sembast.dart';

import '../domain/models.dart';
import '../domain/profile_validation.dart';
import 'local_store.dart';

class LocalSessionRepository extends SessionRepository {
  LocalSessionRepository(this.store) {
    store.addListener(notifyListeners);
  }
  final LocalStore store;
  static final _publicCodePattern = RegExp(r'^#[0-9]{4}$');
  static const _publicCodeCapacity = 10000;
  static const _publicCodeExhaustedMessage =
      '공개 코드를 더 이상 발급할 수 없어요. 관리자에게 문의해 주세요.';
  final Random _publicCodeRandom = Random.secure();

  @override
  List<Account> get accounts => store.snapshot.accounts;
  @override
  Account? get current {
    final id = store.snapshot.get('settings', 'session')?.s('accountId');
    final data = id == null ? null : store.snapshot.get('accounts', id);
    return data == null ? null : Account(data.id, data.data);
  }

  @override
  bool get onboardingSeen =>
      store.snapshot.get('settings', 'app')?.b('onboardingSeen') ?? false;
  @override
  Record? get pendingDestination =>
      store.snapshot.get('settings', 'destination');
  @override
  Future<void> finishOnboarding() async {
    await store.write('', '', (s) {
      s.put('settings', 'app', {'onboardingSeen': true});
      return '';
    });
  }

  @override
  Future<void> signIn(String id) async {
    await store.write(id, '', (s) {
      s.require('accounts', id);
      s.put('settings', 'session', {'accountId': id});
      return id;
    });
  }

  @override
  Future<void> signOut() async {
    await store.write(current?.id ?? '', '', (s) {
      s.remove('settings', 'session');
      return '';
    });
  }

  @override
  Future<void> deleteAccount() async {
    final id = current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
    await store.database.transaction((txn) async {
      if (store.failNextWrite) {
        store.failNextWrite = false;
        throw const AppFailure('탈퇴하지 못했어요. 다시 시도해 주세요.');
      }
      for (final collection in ['accounts', 'signupProgress']) {
        await store.table(collection).record(id).delete(txn);
      }
      await store.table('settings').record('roleOnboarding:$id').delete(txn);
      for (final collection in [
        'drafts',
        'notices',
        'attachments',
        'workflowInputs',
        'favoriteWholesalers',
      ]) {
        final owned = await store
            .table(collection)
            .find(txn, finder: Finder(filter: Filter.equals('ownerId', id)));
        for (final row in owned) {
          if (collection == 'attachments') {
            await store.table('attachmentPayloads').record(row.key).delete(txn);
          }
          await store.table(collection).record(row.key).delete(txn);
        }
      }
      await store
          .table('connections')
          .delete(
            txn,
            finder: Finder(
              filter: Filter.or([
                Filter.equals('from', id),
                Filter.equals('to', id),
              ]),
            ),
          );
      final messages = await store
          .table('messages')
          .find(txn, finder: Finder(filter: Filter.equals('senderId', id)));
      await store
          .table('chatBlocks')
          .delete(
            txn,
            finder: Finder(
              filter: Filter.or([
                Filter.equals('ownerId', id),
                Filter.equals('peerId', id),
              ]),
            ),
          );
      for (final row in messages) {
        if (flagOf(row.value, 'system') || flagOf(row.value, 'deleted')) {
          continue;
        }
        await store.table('messages').record(row.key).put(txn, {
          ...row.value,
          'body': '',
          'attachments': <String>[],
          'requestId': '',
          'deleted': true,
          'deletedAt': DateTime.now().toIso8601String(),
          'version': numberOf(row.value, 'version') + 1,
        });
      }
      final remaining = (await store.table('accounts').find(txn))
          .map((row) => row.key)
          .toSet();
      for (final collection in workflowCollections) {
        for (final row in await store.table(collection).find(txn)) {
          final data = Map<String, Object?>.from(row.value);
          final readers = stringsOf(data, 'readers');
          if (!readers.contains(id)) continue;
          final nextReaders = readers.where(remaining.contains).toList();
          if (nextReaders.isEmpty ||
              collection == 'colleagueConnections' ||
              (collection == 'teamInvites' &&
                  [
                    textOf(data, 'fromId'),
                    textOf(data, 'toId'),
                    textOf(data, 'inviterId'),
                    textOf(data, 'inviteeId'),
                  ].contains(id))) {
            await store.table(collection).record(row.key).delete(txn);
            continue;
          }
          data['readers'] = nextReaders;
          data['version'] = numberOf(data, 'version') + 1;
          if (collection == 'teams') {
            final members = stringsOf(
              data,
              'memberIds',
            ).where(remaining.contains).toList();
            final admins = stringsOf(
              data,
              'adminIds',
            ).where(members.contains).toList();
            data.addAll({
              'memberIds': members,
              'adminIds': admins,
              'departedMemberIds': {
                ...stringsOf(data, 'departedMemberIds'),
                id,
              }.toList(),
              'managementRequired': admins.isEmpty,
              if (textOf(data, 'ownerId') == id) 'ownerId': '',
            });
          }
          if (collection == 'teamChats' &&
              textOf(data, 'senderId') == id &&
              !flagOf(data, 'system') &&
              textOf(data, 'kind') != 'system') {
            data.addAll({
              'body': '',
              'attachments': <String>[],
              'deleted': true,
            });
          }
          if ([
                'teamJobs',
                'teamPackages',
                'teamHandoffs',
              ].contains(collection) &&
              [
                'pickupAssigneeId',
                'finalAssigneeId',
                'currentHolderId',
                'fromId',
                'toId',
              ].any((key) => textOf(data, key) == id)) {
            // 실제 보관자와 처리 상태를 추정해서 바꾸지 않는다.
            data['requiresReconciliation'] = true;
            data['reconciliationReason'] = 'account_deleted';
          }
          if ([
                'fieldPayments',
                'supplierPaymentAllocations',
                'supplierRefunds',
                'invoices',
                'invoiceReceipts',
                'reimbursements',
              ].contains(collection) &&
              [
                'retailerId',
                'uncleId',
                'payerId',
                'payeeId',
                'paidToId',
                'recipientId',
              ].any((key) => textOf(data, key) == id)) {
            // 탈퇴로 지급·회수·반환 책임이나 잔액을 없애지 않는다.
            data['requiresReconciliation'] = true;
            data['reconciliationReason'] = 'account_deleted';
          }
          await store.table(collection).record(row.key).put(txn, data);
        }
      }
      final requests = await store.table('requests').find(txn);
      final removedRequests = <String>{};
      for (final row in requests) {
        final participants = [
          textOf(row.value, 'retailerId'),
          textOf(row.value, 'uncleId'),
        ];
        if (participants.contains(id) &&
            !participants.any(remaining.contains)) {
          removedRequests.add(row.key);
          await store.table('requests').record(row.key).delete(txn);
        }
      }
      for (final collection in [
        'deliveries',
        'receipts',
        'events',
        'proposals',
        'issues',
        'messages',
      ]) {
        for (final row in await store.table(collection).find(txn)) {
          final participants = [
            textOf(row.value, 'senderId'),
            textOf(row.value, 'recipientId'),
          ];
          if (removedRequests.contains(textOf(row.value, 'requestId')) ||
              (collection == 'messages' &&
                  participants.contains(id) &&
                  !participants.any(remaining.contains))) {
            await store.table(collection).record(row.key).delete(txn);
          }
        }
      }
      await store
          .table('operations')
          .delete(txn, finder: Finder(filter: Filter.equals('actor', id)));
      await store.table('settings').record('destination').delete(txn);
      await store.table('settings').record('session').delete(txn);
    });
    await store.reload();
  }

  Set<String> _usedPublicCodes(
    Iterable<MapEntry<String, Data>> accounts, {
    String? exceptAccountId,
  }) {
    return {
      for (final entry in accounts)
        if (entry.key != exceptAccountId)
          textOf(entry.value, 'publicCode').trim().toUpperCase(),
    }.where(_publicCodePattern.hasMatch).toSet();
  }

  String _newPublicCode(
    Iterable<MapEntry<String, Data>> accounts, {
    String? exceptAccountId,
  }) {
    final used = _usedPublicCodes(accounts, exceptAccountId: exceptAccountId);
    if (used.length >= _publicCodeCapacity) {
      throw const AppFailure(_publicCodeExhaustedMessage);
    }
    for (var attempt = 0; attempt < 32; attempt++) {
      final code = '#${_publicCodeRandom.nextInt(_publicCodeCapacity).toString().padLeft(4, '0')}';
      if (!used.contains(code)) return code;
    }
    final start = _publicCodeRandom.nextInt(_publicCodeCapacity);
    for (var offset = 0; offset < _publicCodeCapacity; offset++) {
      final slot = (start + offset) % _publicCodeCapacity;
      final code = '#${slot.toString().padLeft(4, '0')}';
      if (!used.contains(code)) return code;
    }
    throw const AppFailure(_publicCodeExhaustedMessage);
  }

  Map<String, Object?> _ensurePublicCode(
    MutableWorkspace s,
    String accountId,
    Data account,
  ) {
    final currentCode = textOf(account, 'publicCode').trim().toUpperCase();
    final usedByOther = _usedPublicCodes(
      s.all('accounts'),
      exceptAccountId: accountId,
    );
    if (_publicCodePattern.hasMatch(currentCode) && !usedByOther.contains(currentCode)) {
      return {...account, 'publicCode': currentCode};
    }
    return {
      ...account,
      'publicCode': _newPublicCode(s.all('accounts'), exceptAccountId: accountId),
    };
  }

  int? _parseFee(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    final parsed = switch (value) {
      int number => number,
      num number when number == number.roundToDouble() => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (parsed == null || parsed < 0 || parsed > maxPartnerFee) return null;
    return parsed;
  }

  bool _phoneUsedByOtherComplete(
    MutableWorkspace s,
    String accountId,
    String normalizedPhone,
  ) {
    if (normalizedPhone.isEmpty) return false;
    return s
        .all('accounts')
        .any(
          (entry) =>
              entry.key != accountId &&
              flagOf(entry.value, 'complete') &&
              normalizeKoreanPhone(textOf(entry.value, 'phone')) ==
                  normalizedPhone,
        );
  }

  @override
  Future<String> createAccount(String label) async {
    if (label.trim().isEmpty) throw const AppFailure('계정 이름을 입력해 주세요.');
    final id = newId();
    await store.write(id, id, (s) {
      s.put('accounts', id, {
        'label': label.trim(),
        'complete': false,
        'version': 0,
        'code': newId().toUpperCase(),
        'codeExpires': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
        'publicCode': _newPublicCode(s.all('accounts')),
        'working': true,
      });
      s.put('settings', 'session', {'accountId': id});
      s.put('signupProgress', id, {
        'accountId': id,
        'stage': 'role',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return id;
    });
    return id;
  }

  @override
  Future<void> chooseRole(AppRole role) async {
    final id = current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
    await store.write(id, '', (s) {
      final account = s.require('accounts', id);
      if (flagOf(account, 'complete')) {
        throw const AppFailure('가입 후에는 역할을 바꿀 수 없어요.');
      }
      s.put('accounts', id, {
        ...account,
        'role': role.name,
        'version': numberOf(account, 'version') + 1,
      });
      s.put('signupProgress', id, {
        'accountId': id,
        'stage': 'profile',
        'role': role.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return id;
    });
  }

  static const profileFields = [
    'name',
    'contact',
    'phone',
    'businessName',
    'businessNumber',
    'documentId',
    'photoId',
    'address',
    'addressDetail',
    'deliveryNote',
    'pickupArea',
    'deliveryArea',
    'deadline',
    'holiday',
    'intro',
    'working',
    'terms',
    'privacy',
    'notificationSettings',
    'salesChannel',
    'markets',
    'transport',
    'activityHours',
    'activityStart',
    'activityEnd',
    'activityDays',
    'nickname',
    'fee',
    'postcode',
    'addressSource',
    'addressRoad',
    'addressJibun',
  ];

  @override
  Future<void> saveProfile(Data fields, {bool complete = false}) async {
    final id = current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
    await store.write(id, '', (s) {
      final old = _ensurePublicCode(s, id, s.require('accounts', id));
      final feeError = fields.containsKey('fee')
          ? validateFee(fields['fee'])
          : null;
      if (feeError != null) throw AppFailure(feeError);
      final next = <String, Object?>{
        ...old,
        for (final key in profileFields)
          if (fields.containsKey(key)) key: fields[key],
      };
      if (fields.containsKey('nickname')) {
        next['nickname'] = textOf(next, 'nickname').trim();
      }
      if (fields.containsKey('fee')) {
        next['fee'] = _parseFee(fields['fee']);
      }
      for (final key in [
        'postcode',
        'addressSource',
        'addressRoad',
        'addressJibun',
      ]) {
        if (fields.containsKey(key)) next[key] = textOf(next, key).trim();
      }
      if (textOf(next, 'role') == 'uncle' &&
          (!flagOf(old, 'complete') || textOf(next, 'name').trim().isEmpty) &&
          textOf(next, 'contact').trim().isNotEmpty) {
        next['name'] = textOf(next, 'contact').trim();
      }
      final documentId = textOf(next, 'documentId');
      if (documentId.isNotEmpty) {
        final document = s.require('attachments', documentId);
        if (textOf(document, 'ownerId') != id) {
          throw const AppFailure('본인의 사업자 서류를 등록해 주세요.');
        }
      }
      if (complete || flagOf(old, 'complete')) {
        final role = switch (textOf(next, 'role')) {
          'retailer' => AppRole.retailer,
          'uncle' => AppRole.uncle,
          _ => throw const AppFailure('역할을 선택해 주세요.'),
        };
        final errors = profileFieldErrors(
          next,
          role: role,
          requireSalesChannel:
              role == AppRole.retailer && !flagOf(old, 'complete'),
        );
        if (errors.isNotEmpty) throw AppFailure(errors.values.first);
        final normalizedPhone = normalizeKoreanPhone(textOf(next, 'phone'));
        if (_phoneUsedByOtherComplete(s, id, normalizedPhone)) {
          throw const AppFailure('이미 가입을 완료한 다른 계정에서 사용 중인 연락처예요.');
        }
        next['complete'] = true;
      }
      final now = DateTime.now().toIso8601String();
      next['version'] = numberOf(old, 'version') + 1;
      s.put('accounts', id, next);
      if (!flagOf(old, 'complete')) {
        s.put('signupProgress', id, {
          'accountId': id,
          'stage': flagOf(next, 'complete') ? 'completed' : 'profile',
          'role': next['role'],
          'updatedAt': now,
        });
      }
      return id;
    });
  }

  @override
  Future<bool> checkPhoneAvailable(String phone) async {
    final accountId = current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
    if (phone.trim().isEmpty) return true;
    if (!isValidKoreanPhone(phone)) {
      throw const AppFailure('연락처를 010-1234-5678 형식으로 입력해 주세요.');
    }
    final normalizedPhone = normalizeKoreanPhone(phone);
    return !store.snapshot.accounts.any(
      (account) =>
          account.complete &&
          account.id != accountId &&
          normalizeKoreanPhone(account.s('phone')) == normalizedPhone,
    );
  }

  @override
  Future<void> setDestination(Data? destination) async {
    await store.write(current?.id ?? '', '', (s) {
      if (destination == null) {
        s.remove('settings', 'destination');
      } else {
        s.put('settings', 'destination', destination);
      }
      return '';
    });
  }

  @override
  void dispose() {
    store.removeListener(notifyListeners);
    super.dispose();
  }
}
