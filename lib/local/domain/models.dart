import 'dart:math';

import 'package:flutter/foundation.dart';
import 'billing_models.dart';
import 'team_models.dart';
import 'convenience_models.dart';

typedef Data = Map<String, Object?>;

const maxPartnerFee = 1000000000;

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random.secure().nextInt(0x7fffffff).toRadixString(36)}';
String textOf(Data data, String key, [String fallback = '']) =>
    data[key] as String? ?? fallback;
int numberOf(Data data, String key) => (data[key] as num?)?.toInt() ?? 0;
int? nullableNumberOf(Data data, String key) {
  final value = data[key];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool flagOf(Data data, String key) => data[key] == true;
List<String> stringsOf(Data data, String key) =>
    (data[key] as List?)?.cast<String>() ?? const [];
Data mapOf(Data data, String key) =>
    Map<String, Object?>.from(data[key] as Map? ?? {});

const maxRequestWholesalers = 10;

bool isWholesalerOnlyRequest(Data data) =>
    textOf(data, 'requestType') == 'wholesaler';

/// 기존 단일 도매처 요청도 같은 목록으로 읽는다. 빈 초안 항목은 유지한다.
List<Data> requestWholesalers(Data data) {
  final entries = data['wholesalers'];
  if (entries is List) {
    return [
      for (final entry in entries)
        if (entry is Map)
          {
            'wholesaler': entry['wholesaler'] is String
                ? (entry['wholesaler'] as String).trim()
                : '',
            'location': entry['location'] is String
                ? (entry['location'] as String).trim()
                : '',
            if (entry.containsKey('paymentMode'))
              'paymentMode':
                  const [
                    'advance',
                    'direct',
                    'review',
                  ].contains(entry['paymentMode'])
                  ? entry['paymentMode']
                  : 'review',
          },
    ];
  }
  return [
    {
      'wholesaler': textOf(data, 'wholesaler').trim(),
      'location': textOf(data, 'location').trim(),
    },
  ];
}

String requestTitle(Data data) {
  final product = textOf(data, 'product').trim();
  if (!isWholesalerOnlyRequest(data) && product.isNotEmpty) return product;
  final names = requestWholesalers(data)
      .map((entry) => textOf(entry, 'wholesaler'))
      .where((name) => name.isNotEmpty)
      .toList();
  if (names.isEmpty) return '새 사입 요청';
  return names.length == 1
      ? names.first
      : '${names.first} 외 ${names.length - 1}곳';
}

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

enum AppRole { retailer, uncle }

/// 탭의 논리 ID. 표시 순서는 역할별 [AppRoleLabel.tabOrder]가 정한다.
enum AppTab { business, chat, home, connections, profile }

extension AppRoleLabel on AppRole {
  String get label => this == AppRole.retailer ? '소매업자' : '사입삼촌';
  List<AppTab> get tabOrder => const [
    AppTab.home,
    AppTab.business,
    AppTab.chat,
    AppTab.connections,
    AppTab.profile,
  ];
  String tabLabel(AppTab tab) => switch (tab) {
    AppTab.home => '홈',
    AppTab.business => this == AppRole.retailer ? '사입하기' : '업무',
    AppTab.chat => this == AppRole.retailer ? '채팅' : '대화',
    AppTab.connections => this == AppRole.retailer ? '사입삼촌' : '거래처',
    AppTab.profile => this == AppRole.retailer ? '내 프로필' : '내 정보',
  };
  List<String> get tabs => tabOrder.map(tabLabel).toList(growable: false);
}

@immutable
class Record {
  const Record(this.id, this.data);
  final String id;
  final Data data;
  String s(String key, [String fallback = '']) => textOf(data, key, fallback);
  int n(String key) => numberOf(data, key);
  bool b(String key) => flagOf(data, key);
  List<String> list(String key) => stringsOf(data, key);
  int get version => n('version');
}

class Account extends Record {
  const Account(super.id, super.data);
  AppRole? get role => switch (s('role')) {
    'retailer' => AppRole.retailer,
    'uncle' => AppRole.uncle,
    _ => null,
  };
  String get name => s('name').isEmpty ? s('label', '새 계정') : s('name');
  String get nickname => s('nickname');
  String get publicCode => s('publicCode');
  int? get fee => nullableNumberOf(data, 'fee');
  String get displayName => nickname.isEmpty ? name : nickname;

  /// 무작위로 발급된 계정 ID를 사용해 재로그인·이름 변경에도 같은 얼굴을 유지한다.
  String get defaultAvatarUrl => Uri.https(
    'api.dicebear.com',
    '/9.x/lorelei/png',
    {'seed': id, 'size': '160'},
  ).toString();
  bool get complete => b('complete');
}

class RequestRecord extends Record {
  const RequestRecord(super.id, super.data);
  DateTime? get receivedAt =>
      DateTime.tryParse(s('receivedAt')) ??
      (s('status') == 'completed' ? DateTime.tryParse(s('updatedAt')) : null);
  int get quantity => n('quantity');
  int get acquired => n('acquired');
  int get delivered => n('delivered');
  int get received => n('received');
  int get cancelled => n('cancelled');
  int get acquiredCancelled => n('acquiredCancelled');
  int get remaining =>
      max(0, quantity - cancelled - (acquired - acquiredCancelled));
  int get backorder => b('resultShared') ? remaining : 0;
  int get available =>
      max(0, acquired - acquiredCancelled - delivered - n('held'));
  bool get ended =>
      ['completed', 'cancelled', 'rejected'].contains(s('status'));

  /// 물류 완료와 입금은 별개다. 전액 송금 신고는 운영 입금 확인과 구분한다.
  bool get receiptComplete =>
      s('status') == 'completed' &&
      received > 0 &&
      received == delivered &&
      received == quantity - cancelled &&
      n('held') == 0 &&
      n('openIssues') == 0 &&
      !needsReply &&
      s('proposalId').isEmpty &&
      remaining == 0 &&
      available == 0;
  bool get paymentComplete => receiptComplete && b('paymentReported');
  String get paymentLabel => !paymentComplete
      ? '입금 전'
      : b('paymentConfirmed')
      ? '운영 입금 확인'
      : '운영 확인 대기';
  bool get needsReply => b('needsReply');
  bool get overdue =>
      backorder > 0 &&
      !needsReply &&
      s('recheck').isNotEmpty &&
      s('recheck').compareTo(dateOnly(DateTime.now())) <= 0;
  String stageLabelFor(AppRole role) {
    if (s('status') == 'rejected') return '거절';
    if (s('status') == 'cancelled') return '취소 종료';
    if (paymentComplete) return '입금 완료';
    if (receiptComplete) {
      return role == AppRole.retailer ? '수령(입금 전)' : '완료(입금 전)';
    }
    if (s('status') == 'pending') {
      return role == AppRole.retailer ? '대기' : '사입 요청';
    }
    return role == AppRole.retailer ? '진행 중' : '사입 중';
  }

  String get statusLabel {
    if (s('status') == 'rejected') return '거절';
    if (s('status') == 'cancelled') return '취소 종료';
    if (receiptComplete) {
      return paymentComplete ? '입금 완료' : '수령(입금 전)';
    }
    if (n('openIssues') > 0) return '문제 확인 중';
    if (s('proposalId').isNotEmpty) return '변경·취소 협의 중';
    if (s('status') == 'pending') return '확인 대기';
    if (needsReply) return '답변 필요';
    if (delivered > received) return '수령 대기';
    if (backorder > 0) return overdue ? '미송 재확인' : '미송 대기';
    if (available > 0) return '픽업 완료';
    return '진행 중';
  }
}

String dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String displayTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.month}월 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

const workflowCollections = [
  ...billingCollections,
  ...teamCollections,
  ...convenienceCollections,
];

const collections = [
  'accounts',
  'signupProgress',
  'connections',
  'drafts',
  'requests',
  'deliveries',
  'receipts',
  'events',
  'proposals',
  'issues',
  'messages',
  'notices',
  'attachments',
  'settings',
  'workflowInputs',
  'pickupProgress',
  ...workflowCollections,
];

class WorkspaceSnapshot {
  const WorkspaceSnapshot(this.tables);
  final Map<String, Map<String, Data>> tables;
  List<Record> all(String table) =>
      (tables[table] ?? {}).entries.map((e) => Record(e.key, e.value)).toList();
  Record? get(String table, String id) {
    final data = tables[table]?[id];
    return data == null ? null : Record(id, data);
  }

  List<Account> get accounts =>
      all('accounts').map((r) => Account(r.id, r.data)).toList();
}

abstract class SessionRepository extends ChangeNotifier {
  bool get isRemote => false;
  bool get loading => false;
  bool get authenticated => current != null;
  String? get syncError => null;
  Future<void> retrySync() async {}
  Future<void> signInWithSocial(String provider) async {
    throw const AppFailure('소셜 로그인은 서버 모드에서 이용할 수 있어요.');
  }

  Account? get current;
  List<Account> get accounts;
  bool get onboardingSeen;
  Record? get pendingDestination;
  Future<void> finishOnboarding();
  Future<void> signIn(String id);
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<String> createAccount(String label);
  Future<void> chooseRole(AppRole role);
  Future<void> saveProfile(Data fields, {bool complete = false});
  Future<bool> checkPhoneAvailable(String phone);
  Future<void> setDestination(Data? destination);
}

abstract class WorkspaceRepository extends ChangeNotifier {
  Future<String> workflow(String command, Data args, String operationId);
  Future<void> saveWorkflowInput(String key, Data values);
  Data workflowInput(String key);
  Future<void> discardRejectedWorkflow(String operationId);
  WorkspaceSnapshot get snapshot;
  List<Account> get partners;
  List<Record> records(String table);
  Account? profile(String id);
  RequestRecord? request(String id);
  Future<Account> lookupCode(String code);
  Future<List<Account>> searchPartners({
    String query = '',
    String region = '',
    int? minFee,
    int? maxFee,
    int limit = 20,
    int offset = 0,
  });
  Future<void> renewCode();
  Future<String> connect(String peerId, String operationId);
  Future<void> respondConnection(
    String id,
    String status,
    int version,
    String operationId,
  );
  Future<String> saveDraft(String id, Data fields);
  Future<void> deleteDraft(String id);
  Future<String> repeatRequest(String id);
  Future<String> sendDraft(String id, String operationId);
  Future<void> updateRequest(
    String id,
    Data fields,
    int version,
    String operationId,
  );
  Future<void> act(
    String id,
    String action,
    Data values,
    int version,
    String operationId,
  );
  Future<void> deliver(
    Map<String, int> quantities,
    Map<String, int> versions,
    String operationId,
  );
  Future<void> receive(
    String deliveryId,
    int actual,
    String reason,
    int version,
    String operationId,
  );
  Future<void> propose(
    String requestId,
    String kind,
    Data values,
    int version,
    String operationId,
  );
  Future<void> respondProposal(
    String proposalId,
    bool approve,
    int version,
    String operationId,
  );
  Future<void> reportIssue(
    String requestId,
    Data values,
    int version,
    String operationId,
  );
  Future<void> actOnIssue(
    String id,
    String action,
    String note,
    int version,
    String operationId,
  );
  Future<void> sendMessage(
    String peerId,
    String messageId,
    String body,
    List<String> attachments, {
    String requestId = '',
  });
  Future<void> markChatRead(String peerId);
  Future<void> editMessage(
    String messageId,
    String body,
    int version,
    String operationId,
  );
  Future<void> deleteMessage(String messageId, int version, String operationId);
  Future<void> readNotice(String id);
  Future<void> refreshReminders();
}

abstract class AttachmentRepository {
  Future<String?> pick({required bool document});
  Future<String> save(String name, Uint8List bytes, String mime);
  Future<Uint8List> bytes(String id);
}
