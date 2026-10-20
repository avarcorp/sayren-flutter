// 손으로 쓴 부분 — commerce-number.ts의 함수.
part of 'commerce-number.dart';

/// 번호를 화면에 표기합니다. 숫자를 앞에서부터 4자리씩 하이픈으로 나눕니다.
///
/// 주문번호 `26100284731592` → `2610-0284-7315-92`. 숫자만으로 된 값이 아니면(클레임번호 `C…`) 그대로, 없으면 빈 문자열입니다.
/// 화면 표기 전용입니다. API에 보낼 때는 원래 값을 사용하십시오.
String formatOrderNo(String? no) {
  if (no == null || no.isEmpty) return '';
  if (!RegExp(r'^\d+$').hasMatch(no)) return no;
  return RegExp(r'.{1,4}').allMatches(no).map((m) => m[0]).join('-');
}

/// 표기 하이픈·공백을 지운 숫자 번호입니다. 숫자가 아닌 글자가 남거나 비면 null입니다.
String? parseOrderNo(String value) {
  final digits = value.replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^\d+$').hasMatch(digits) ? digits : null;
}

/// 응답 번호 필드 스키마입니다. 서버는 항상 싣고, 옛 서버 응답은 null입니다.
ZodType<String?> commerceNumberField(String description) => z.string().nullable().optional().withDefault(null);
