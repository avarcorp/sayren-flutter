// 손으로 쓴 부분 — checkout.ts의 함수와 zod 클로저 구현.
part of 'checkout.dart';

/// 결제 옵션의 화면 키입니다. 라디오 버튼 값·위젯 키로 사용합니다. 예: `tosspayments:CARD`, `portone:EASY_PAY:NAVERPAY`
String paymentOptionKey(PaymentOption option) => switch (option) {
      PaymentOptionEasyPay(:final pg, :final provider) => '$pg:EASY_PAY:$provider',
      _ => '${option.pg}:${option.method}',
    };

/// 이 결제수단으로 현금영수증을 신청할 수 있는지입니다.
bool cashReceiptAvailable(String method) => CASH_RECEIPT_METHODS.contains(method);

/// 주민등록번호처럼 보이는지입니다(13자리, 월·일·성별 자리가 맞음). 현금영수증 식별 번호로 받지 않습니다.
bool residentNumberLike(String identityNumber) {
  final digits = identityNumber.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^[0-9]{13}$').hasMatch(digits)) return false;
  final month = int.parse(digits.substring(2, 4));
  final day = int.parse(digits.substring(4, 6));
  final genderCode = int.parse(digits[6]);
  return month >= 1 && month <= 12 && day >= 1 && day <= 31 && genderCode >= 1 && genderCode <= 8;
}

/// 현금영수증 식별 번호의 종류입니다. 하이픈·공백은 빼고 판정합니다. 용도에 맞지 않는 번호면 null입니다.
///
/// - 소득공제: 휴대폰 번호(01로 시작하는 10~11자리) 또는 현금영수증카드 번호(13~19자리)
/// - 지출증빙: 사업자등록번호(10자리) 또는 현금영수증카드 번호(13~19자리)
CashReceiptIdentityType? cashReceiptIdentityTypeOf(CashReceiptType type, String identityNumber) {
  final digits = identityNumber.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return null;
  if (residentNumberLike(digits)) return null;
  if (RegExp(r'^[0-9]{13,19}$').hasMatch(digits)) return 'CARD';
  if (type == 'INCOME_DEDUCTION') return RegExp(r'^01[016789][0-9]{7,8}$').hasMatch(digits) ? 'PHONE' : null;
  return RegExp(r'^[0-9]{10}$').hasMatch(digits) ? 'BUSINESS' : null;
}

/// 결제 옵션 목록 preprocess — 모르는 항목(새 결제수단·PG)만 빼고 읽는다
Object? _knownPaymentOptions(Object? value) =>
    value is List ? value.where((item) => availablePaymentOptionSchema.safeParse(item).success).toList() : value;

/// 현금영수증 신청 superRefine — 주민등록번호는 형식 오류와 따로 알린다
void _cashReceiptCheck(CashReceiptRequest value, ZodCheckContext ctx) {
  if (residentNumberLike(value.identityNumber)) {
    ctx.addIssue(
      '주민등록번호는 현금영수증 식별 번호로 쓸 수 없습니다. 휴대폰 번호 또는 현금영수증카드 번호를 입력해주십시오 (RESIDENT_NUMBER_NOT_ALLOWED)',
      path: ['identityNumber'],
    );
    return;
  }
  if (cashReceiptIdentityTypeOf(value.type, value.identityNumber) == null) {
    ctx.addIssue(
      value.type == 'INCOME_DEDUCTION' ? '휴대폰 번호 또는 현금영수증카드 번호를 입력해주십시오' : '사업자등록번호(10자리) 또는 현금영수증카드 번호를 입력해주십시오',
      path: ['identityNumber'],
    );
  }
}
