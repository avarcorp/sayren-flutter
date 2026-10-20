// 손으로 쓴 부분 — store.ts의 함수.
part of 'store.dart';

/// 플랫폼이 쓰는 이름이라 상점 코드로 쓸 수 없는지 판정합니다(대소문자 무시).
bool isReservedStoreCode(String code) => RESERVED_STORE_CODES.contains(code.toLowerCase());

/// 웹 출처(`https://shop.example.com`처럼 스킴·호스트·포트만)인지 판정합니다.
///
/// http·https이고 사용자 정보·경로(`/` 외)·쿼리·조각·`*`가 없어야 합니다. 판정은 WHATWG URL 규칙을 따릅니다.
bool isWebOrigin(String value) {
  final url = parseHttpUrl(value);
  if (url == null) return false;
  return url.username.isEmpty &&
      url.password.isEmpty &&
      url.pathname == '/' &&
      url.search.isEmpty &&
      url.hash.isEmpty &&
      !value.contains('*');
}

/// 사업자등록번호에서 숫자만 남깁니다(`123-45-67890` → `1234567890`).
String normalizeBusinessNumber(String value) => value.replaceAll(RegExp(r'\D'), '');
