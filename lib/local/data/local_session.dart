import '../domain/models.dart';
import 'local_store.dart';

class LocalSessionRepository extends SessionRepository {
  LocalSessionRepository(this.store) {
    store.addListener(notifyListeners);
  }
  final LocalStore store;
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
  ];
  @override
  Future<void> saveProfile(Data fields, {bool complete = false}) async {
    final id = current?.id ?? (throw const AppFailure('로그인이 필요해요.'));
    await store.write(id, '', (s) {
      final old = s.require('accounts', id);
      final next = {
        ...old,
        for (final key in profileFields)
          if (fields.containsKey(key)) key: fields[key],
      };
      if (complete || flagOf(old, 'complete')) {
        final required = {
          'name': '표시 이름',
          'contact': '담당자',
          'phone': '연락처',
          'businessName': '사업자명',
          'businessNumber': '사업자등록번호',
          'documentId': '사업자등록증',
          if (textOf(next, 'role') == 'retailer') ...{
            'address': '배송지',
            'addressDetail': '상세주소',
          } else ...{
            'pickupArea': '도매 픽업 구역',
            'deliveryArea': '소매 배송 지역',
            'deadline': '요청 마감시간',
          },
        };
        for (final entry in required.entries) {
          if (textOf(next, entry.key).trim().isEmpty) {
            if (entry.key == 'documentId') {
              throw const AppFailure('사업자등록증을 첨부해 주세요.');
            }
            throw AppFailure('${entry.value} 항목을 입력해 주세요.');
          }
        }
        if (textOf(next, 'role').isEmpty) {
          throw const AppFailure('역할을 선택해 주세요.');
        }
        if (!RegExp(
          r'^\d{10}$',
        ).hasMatch(textOf(next, 'businessNumber').replaceAll('-', ''))) {
          throw const AppFailure('사업자등록번호 10자리를 확인해 주세요.');
        }
        if (!RegExp(r'^\+?[\d -]{9,16}$').hasMatch(textOf(next, 'phone'))) {
          throw const AppFailure('연락처를 확인해 주세요.');
        }
        final document = s.require('attachments', textOf(next, 'documentId'));
        if (textOf(document, 'ownerId') != id) {
          throw const AppFailure('본인의 사업자 서류를 등록해 주세요.');
        }
        if (!flagOf(next, 'terms') || !flagOf(next, 'privacy')) {
          throw const AppFailure('필수 동의를 확인해 주세요.');
        }
        next['complete'] = true;
      }
      next['version'] = numberOf(old, 'version') + 1;
      s.put('accounts', id, next);
      if (!flagOf(old, 'complete')) {
        s.put('signupProgress', id, {
          'accountId': id,
          'stage': flagOf(next, 'complete') ? 'completed' : 'profile',
          'role': next['role'],
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      return id;
    });
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
