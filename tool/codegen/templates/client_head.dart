
/// [createStorefrontClient]에 넘기는 옵션입니다.
///
/// [TokenSource] 타입 옵션은 문자열 또는 문자열을 돌려주는 함수를 받습니다. 함수를 넘기면 요청마다 다시 읽으므로,
/// 로그인·로그아웃으로 바뀌는 값(회원 토큰, 장바구니 토큰)은 함수로 넘기십시오.
///
/// ```dart
/// final client = createStorefrontClient(StorefrontClientOptions(
///   baseUrl: 'https://api.sayren.io/storefront/v1',
///   storeCode: 'my-store',
///   accessToken: () => tokens.accessToken,
/// ));
/// ```
class StorefrontClientOptions {
  /// 옵션을 만듭니다. [baseUrl]만 필수입니다.
  const StorefrontClientOptions({
    required this.baseUrl,
    this.storeCode,
    this.accessToken,
    this.auth,
    this.cartToken,
    this.visitorId,
    this.sessionId,
    this.country,
    this.host,
    this.locale,
    this.onCartToken,
    this.session,
    this.fetch,
  });

  /// 스토어프론트 API 주소입니다. 예: `https://api.sayren.io/storefront/v1`
  final String baseUrl;

  /// 상점 코드입니다. `X-Store-Code` 헤더로 보내 요청할 상점을 지정합니다.
  ///
  /// 공유 API 주소로 접근할 때 서버가 주소의 서브도메인을 추측하지 않고 이 값으로 상점을 고릅니다.
  final TokenSource storeCode;

  /// 회원 액세스 토큰입니다. `Authorization: Bearer` 헤더로 보냅니다.
  ///
  /// [auth]의 `accessToken`, [session]의 토큰보다 우선합니다.
  final TokenSource accessToken;

  /// [accessToken]의 별칭입니다. `auth: (accessToken: token)` 형태로 넘깁니다.
  ///
  /// [accessToken]을 함께 넘기면 [accessToken]을 사용합니다.
  final ({String? accessToken})? auth;

  /// 비회원 장바구니 토큰입니다. `X-Cart-Token` 헤더로 보냅니다.
  ///
  /// 서버가 새 토큰을 발급하면 [onCartToken]이 호출됩니다. 그 값을 저장해 다음 요청부터 넘기십시오.
  final TokenSource cartToken;

  /// 방문자 ID입니다. 보내면 서버가 장바구니 담기·결제 시작·구매를 이 방문과 이어 기록합니다.
  final TokenSource visitorId;

  /// 방문 세션 ID입니다. [visitorId]와 함께 보냅니다.
  final TokenSource sessionId;

  /// 구매자 국가(ISO 3166-1 alpha-2)입니다. `X-Buyer-Country` 헤더로 보냅니다.
  ///
  /// 서버가 이 국가의 판매 권역과 통화로 가격을 계산합니다.
  final TokenSource country;

  /// 스토어프론트 도메인입니다. `X-Storefront-Host` 헤더로 보냅니다.
  ///
  /// 이 도메인을 판매 권역에 연결했으면 [country]보다 먼저 그 권역으로 판정합니다.
  final TokenSource host;

  /// 구매자 언어입니다. `Accept-Language` 헤더 값으로 보냅니다(예: `en-US,en;q=0.9,ko;q=0.8`).
  ///
  /// 서버가 판매 권역 언어 중 맞는 언어로 번역한 값을 돌려주고, 고른 언어는 [StorefrontStore.locale]로 알려 줍니다.
  final TokenSource locale;

  /// 서버가 응답 헤더로 새 장바구니 토큰을 발급했을 때 호출됩니다.
  final void Function(String token)? onCartToken;

  /// 구매자 세션입니다. 넘기면 회원 토큰을 세션에서 읽고, 401이면 [StorefrontSession.refresh] 뒤 한 번 다시 보내고,
  /// 갱신할 수 없으면 [StorefrontSession.clear]를 부릅니다.
  ///
  /// [accessToken]·[auth]를 함께 넘기면 그쪽 토큰을 사용합니다.
  final StorefrontSession? session;

  /// HTTP 요청을 보내는 함수입니다. 생략하면 `package:http`로 보냅니다.
  ///
  /// 테스트에서 가짜 응답을 돌려주거나, 로깅·프록시가 필요할 때 넘기십시오.
  final Fetch? fetch;
}

/// 스토어프론트 API 클라이언트를 만듭니다.
///
/// 메서드는 네임스페이스로 묶여 있습니다. 예: `client.store.get()`, `client.catalog.listCollections()`.
///
/// 실패하면 다음 예외를 던집니다.
/// - [ApiError]: 서버가 2xx가 아닌 응답을 돌려줬습니다. [ApiError.code]로 분기하십시오.
/// - [ZodError]: 요청 본문이 계약에 맞지 않거나(요청 전), 응답이 계약에 맞지 않습니다.
///
/// ```dart
/// final client = createStorefrontClient(StorefrontClientOptions(
///   baseUrl: 'https://api.sayren.io/storefront/v1',
///   storeCode: 'my-store',
/// ));
/// final store = await client.store.get();
/// print(store.name);
/// ```
StorefrontClient createStorefrontClient(StorefrontClientOptions options) => StorefrontClient._(options);

/// 스토어프론트 API 클라이언트입니다. [createStorefrontClient]로 만듭니다.
