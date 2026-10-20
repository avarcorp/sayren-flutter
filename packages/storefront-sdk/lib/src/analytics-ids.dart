// 손으로 쓴 파일 — Node src/analytics-ids.ts에 대응한다.
import 'schemas/analytics.dart';

/// 요청의 `Cookie` 헤더에서 방문자·세션 ID를 읽습니다. Dart 서버(SSR)가 스토어프론트 API를 부를 때 사용합니다.
///
/// 형식이 틀리거나 없는 값은 null입니다.
///
/// ```dart
/// final ids = analyticsIdsFromCookie(request.headers['cookie']);
/// createStorefrontClient(StorefrontClientOptions(baseUrl: baseUrl, storeCode: storeCode,
///     visitorId: ids.visitorId, sessionId: ids.sessionId));
/// ```
({String? visitorId, String? sessionId}) analyticsIdsFromCookie(String? cookieHeader) {
  if (cookieHeader == null || cookieHeader.isEmpty) return (visitorId: null, sessionId: null);
  String? pick(String name) {
    for (final part in cookieHeader.split(';')) {
      final pieces = part.trim().split('=');
      if (pieces.first != name) continue;
      final value = _safeDecode(pieces.skip(1).join('='));
      return value != null && analyticsIdSchema.safeParse(value).success ? value : null;
    }
    return null;
  }

  return (visitorId: pick(ANALYTICS_VISITOR_COOKIE), sessionId: pick(ANALYTICS_SESSION_COOKIE));
}

/// 잘못된 퍼센트 인코딩은 버린다 — 쿠키 하나 때문에 요청 전체가 실패하지 않게 한다
String? _safeDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return null;
  }
}
