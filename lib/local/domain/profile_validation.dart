import 'models.dart';

/// 판매 채널 저장 값. 복수 선택은 '온라인·오프라인 병행'으로 합쳐 기존 문자열과 호환되게 저장한다.
const salesChannelOptions = ['온라인', '오프라인', '온라인·오프라인 병행'];

final _phoneShape = RegExp(r'^\+?[\d -]+$');
final _phoneDigits = RegExp(
  r'^(010\d{8}|01[16789]\d{7,8}|02\d{7,8}|0(3[1-3]|4[1-4]|5[1-5]|6[1-4])\d{7,8}|070\d{8})$',
);
final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

String normalizeKoreanPhone(String value) {
  final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('82')) return '0${digits.substring(2)}';
  return digits;
}

/// 010-1234-5678처럼 구분 기호가 있어도, 숫자만 있어도 유효한
/// 한국 휴대전화·유선번호만 허용한다. +82 국가번호는 0으로 바꿔 검사한다.
bool isValidKoreanPhone(String value) {
  final text = value.trim();
  if (!_phoneShape.hasMatch(text)) return false;
  return _phoneDigits.hasMatch(normalizeKoreanPhone(text));
}

/// 사업자등록번호는 10자리 숫자 또는 111-11-11111 형식만 허용한다.
bool isValidBusinessNumber(String value) {
  final text = value.trim();
  return RegExp(r'^\d{10}$').hasMatch(text) ||
      RegExp(r'^\d{3}-\d{2}-\d{5}$').hasMatch(text);
}

bool isValidTimeText(String value) => _timePattern.hasMatch(value.trim());

String? validateNickname(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  if (text.runes.length > 30) return '닉네임은 30자 이하로 입력해 주세요.';
  return null;
}

String? validateFee(Object? value) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  final parsed = switch (value) {
    int number => number,
    num number when number == number.roundToDouble() => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null || parsed < 0 || parsed > maxPartnerFee) {
    return '건당 수수료는 0원 이상 1,000,000,000원 이하 정수로 입력해 주세요.';
  }
  return null;
}

/// 역할별 프로필 필드 오류를 화면(폼) 순서 그대로 돌려준다.
/// 키는 입력 필드 키(documentId·terms·privacy 포함), 값은 그대로 노출할 한국어 안내다.
/// 삼촌은 별도의 활동명·사업자 정보·서류를 입력하지 않는다. 역할 변경 전의 사업자 초안은
/// 보존하되, 현재 폼에서 수정할 수 없는 항목으로 가입을 막지 않는다.
/// [requireSalesChannel]은 신규 소매 가입에만 켠다. 기존 계정 수정은 판매 채널이
/// 비어 있어도(과거 데이터) 통과한다.
Map<String, String> profileFieldErrors(
  Data values, {
  required AppRole role,
  bool requireSalesChannel = false,
  bool requireBankAccount = false,
}) {
  final errors = <String, String>{};
  String text(String key) => textOf(values, key).trim();
  void requireText(String key, String label) {
    if (text(key).isEmpty) errors[key] = '$label 항목을 입력해 주세요.';
  }

  void checkTime(String key, String label, {bool required = false}) {
    final time = text(key);
    if (time.isEmpty) {
      if (required) errors[key] = '$label 항목을 선택해 주세요.';
    } else if (!isValidTimeText(time)) {
      errors[key] = '$label 항목을 다시 선택해 주세요.';
    }
  }

  final retailer = role == AppRole.retailer;
  if (retailer) requireText('name', '매장명');
  requireText('contact', retailer ? '담당자명' : '이름(실명)');
  final phone = text('phone');
  if (phone.isEmpty) {
    errors['phone'] = '연락처 항목을 입력해 주세요.';
  } else if (!isValidKoreanPhone(phone)) {
    errors['phone'] = '연락처를 010-1234-5678 형식으로 입력해 주세요.';
  }
  final nicknameError = validateNickname(text('nickname'));
  if (nicknameError != null) errors['nickname'] = nicknameError;
  if (requireBankAccount ||
      [
        'bankName',
        'bankAccount',
        'bankHolder',
      ].any((key) => text(key).isNotEmpty)) {
    requireText('bankName', '은행명');
    requireText('bankAccount', '계좌번호');
    requireText('bankHolder', '예금주명');
    final account = text('bankAccount');
    if (account.isNotEmpty &&
        (!RegExp(r'^[0-9 -]+$').hasMatch(account) ||
            !RegExp(
              r'^\d{8,20}$',
            ).hasMatch(account.replaceAll(RegExp(r'[ -]'), '')))) {
      errors['bankAccount'] = '계좌번호는 8~20자리 숫자로 입력해 주세요.';
    }
    if (text('bankName').length > 50) {
      errors['bankName'] = '은행명은 50자 이하로 입력해 주세요.';
    }
    if (text('bankHolder').length > 100) {
      errors['bankHolder'] = '예금주명은 100자 이하로 입력해 주세요.';
    }
  }
  final feeError = validateFee(values['fee']);
  if (feeError != null) errors['fee'] = feeError;
  final businessNumber = text('businessNumber');
  if (retailer) {
    final channel = text('salesChannel');
    if (channel.isEmpty
        ? requireSalesChannel
        : !salesChannelOptions.contains(channel)) {
      errors['salesChannel'] = '판매 채널을 한 개 이상 선택해 주세요.';
    }
    requireText('businessName', '사업자명');
    if (businessNumber.isEmpty) {
      errors['businessNumber'] = '사업자등록번호 항목을 입력해 주세요.';
    } else if (!isValidBusinessNumber(businessNumber)) {
      errors['businessNumber'] = '사업자등록번호 10자리를 확인해 주세요.';
    }
    if (text('documentId').isEmpty) {
      errors['documentId'] = '사업자등록증을 첨부해 주세요.';
    }
    requireText('address', '주소');
    requireText('addressDetail', '상세주소');
  } else {
    if (text('pickupArea').isEmpty) {
      errors['pickupArea'] = '도매 픽업 지역을 선택해 주세요.';
    }
    if (text('deliveryArea').isEmpty) {
      errors['deliveryArea'] = '소매 배송 지역을 선택해 주세요.';
    }
    checkTime('deadline', '요청 마감시간', required: true);
    checkTime('activityStart', '활동 시작');
    checkTime('activityEnd', '활동 종료');
  }
  if (!flagOf(values, 'terms')) errors['terms'] = '이용약관 동의가 필요해요.';
  if (!flagOf(values, 'privacy')) {
    errors['privacy'] = '개인정보 처리방침 동의가 필요해요.';
  }
  return errors;
}
