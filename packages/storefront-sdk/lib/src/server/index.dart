// 손으로 쓴 파일 — Node src/server/index.ts에 대응한다.
// sayren 호스팅에서 도는 사이트의 서버 코드가 구매자 세션을 다룬다(#298 P3). 구매자 세션 쿠키는 플랫폼이 소유하고,
// 사이트 코드는 토큰을 저장하거나 갱신하지 않는다. Node는 fetch `Request`를 받고 Dart는 요청 헤더 맵을 받는다.
import 'dart:convert';

/// 플랫폼이 사이트에 넘기는 구매자 액세스 토큰 헤더입니다.
const BUYER_TOKEN_HEADER = 'x-sayren-buyer-token';

/// 사이트가 플랫폼에 로그인·로그아웃을 알리는 응답 헤더입니다.
const SESSION_HEADER = 'x-sayren-session';

/// 로그인 응답에 싣는 구매자 토큰입니다.
class SessionTokens {
  /// 값을 만듭니다.
  const SessionTokens({required this.accessToken, required this.refreshToken, required this.expiresIn});

  /// 구매자 액세스 토큰입니다.
  final String accessToken;

  /// 구매자 갱신 토큰입니다.
  final String refreshToken;

  /// 액세스 토큰 수명(초)입니다. 로그인 응답의 `expiresIn`입니다.
  final int expiresIn;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson() => {'accessToken': accessToken, 'refreshToken': refreshToken, 'expiresIn': expiresIn};
}

/// 이 요청의 구매자 액세스 토큰입니다. 로그인하지 않았으면 null입니다.
///
/// [headers]는 요청 헤더입니다. 이름은 대소문자를 가리지 않습니다.
String? buyerTokenOf(Map<String, String> headers) {
  String? raw;
  for (final e in headers.entries) {
    if (e.key.toLowerCase() == BUYER_TOKEN_HEADER) {
      raw = e.value;
      break;
    }
  }
  final value = raw?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// 로그인 응답에 싣는 헤더(이름, 값)입니다.
(String, String) sessionSetHeader(SessionTokens tokens) {
  final payload = base64Url.encode(utf8.encode(jsonEncode(tokens.toJson()))).replaceAll('=', '');
  return (SESSION_HEADER, 'set $payload');
}

/// 로그아웃 응답에 싣는 헤더(이름, 값)입니다.
(String, String) sessionClearHeader() => (SESSION_HEADER, 'clear');
