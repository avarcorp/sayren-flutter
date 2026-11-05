/// sayren 호스팅(`{slug}.sayren.co`·내 도메인)에서 도는 사이트의 서버 코드가 구매자 세션을 다룹니다.
/// Node `@sayren/storefront-sdk/server`에 대응합니다.
///
/// 구매자 세션 쿠키는 플랫폼이 소유합니다. 사이트 코드는 토큰을 저장하거나 갱신하지 않습니다.
/// 요청마다 [buyerTokenOf]로 구매자 액세스 토큰을 읽고, 로그인하면 [sessionSetHeader], 로그아웃하면 [sessionClearHeader]를 응답에 싣습니다.
/// 서버 코드 전용입니다. 앱(클라이언트) 코드에서 import하지 마십시오.
library;

export 'src/server/index.dart';
