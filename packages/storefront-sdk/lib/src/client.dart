import 'package:http/http.dart' as http;

import 'http.dart';
import 'schemas/analytics.dart';
import 'schemas/catalog.dart';
import 'schemas/common.dart';
import 'schemas/consent.dart';
import 'schemas/store.dart';
import 'zod.dart';

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
  /// [auth]의 `accessToken`보다 우선합니다.
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
class StorefrontClient {
  StorefrontClient._(StorefrontClientOptions options) {
    // 우선순위: 명시적 accessToken 옵션 > auth.accessToken 별칭
    final TokenSource accessTokenSource = options.accessToken ?? options.auth?.accessToken;
    final http_ = Http(HttpOptions(
      baseUrl: options.baseUrl,
      fetch: options.fetch,
      headers: () {
        final headers = <String, String>{};
        void put(String name, TokenSource source, [String prefix = '']) {
          final value = resolveToken(source);
          if (value != null && value.isNotEmpty) headers[name] = '$prefix$value';
        }

        put('x-store-code', options.storeCode);
        put('authorization', accessTokenSource, 'Bearer ');
        put('x-cart-token', options.cartToken);
        put(ANALYTICS_VISITOR_HEADER, options.visitorId);
        put(ANALYTICS_SESSION_HEADER, options.sessionId);
        put('x-buyer-country', options.country);
        put('x-storefront-host', options.host);
        put('accept-language', options.locale);
        return headers;
      },
      onResponse: (http.Response response) {
        final issued = response.headers['x-cart-token'];
        if (issued != null && issued.isNotEmpty) options.onCartToken?.call(issued);
      },
    ));
    store = StorefrontClientStore._(http_);
    catalog = StorefrontClientCatalog._(http_);
    member = StorefrontClientMember._(http_);
  }

  /// 상점 공개 설정입니다.
  late final StorefrontClientStore store;

  /// 카테고리·상품·컬렉션 등 카탈로그입니다.
  late final StorefrontClientCatalog catalog;

  /// 로그인한 회원의 정보·동의·주소·찜입니다.
  late final StorefrontClientMember member;
}

/// `client.store` 네임스페이스입니다. 상점 공개 설정을 다룹니다.
class StorefrontClientStore {
  const StorefrontClientStore._(this._http);

  final Http _http;

  /// 상점 공개 설정을 가져옵니다. `GET /store`
  ///
  /// 상점 이름, 고객센터, 사업자 정보, 판매 권역, 로그인 방법, 비회원 주문·결제 가능 여부를 담습니다.
  Future<StorefrontStore> get() async => _http.request('GET', '/store', storefrontStoreSchema);
}

/// `client.catalog` 네임스페이스입니다. 카테고리·상품·컬렉션 등 카탈로그를 다룹니다.
class StorefrontClientCatalog {
  const StorefrontClientCatalog._(this._http);

  final Http _http;

  /// 카테고리 트리를 가져옵니다. `GET /categories`
  ///
  /// 최상위 카테고리 목록이고, 하위 카테고리는 [CategoryNode.children]에 있습니다.
  Future<List<CategoryNode>> listCategories() async => _http.request('GET', '/categories', z.array(categoryNodeSchema));

  /// 노출 중인 컬렉션 목록을 가져옵니다. `GET /collections`
  ///
  /// 노출이 켜져 있고 노출 기간 안인 컬렉션만, 셀러가 정한 순서로 돌려줍니다.
  Future<Page<StorefrontCollection>> listCollections([PageParams? params]) async => _http.request(
      'GET', '/collections', pageSchema(storefrontCollectionSchema), RequestOptions(query: params?.toJson()));
}

/// `client.member` 네임스페이스입니다. 로그인한 회원의 정보·동의·주소·찜을 다룹니다.
class StorefrontClientMember {
  const StorefrontClientMember._(this._http);

  final Http _http;

  /// 약관 재동의와 마케팅 수신 동의를 바꿉니다. `POST /me/consents`
  ///
  /// 바꿀 항목만 [body]에 넣습니다. 바꾼 뒤의 동의 상태를 돌려줍니다. 로그인이 필요합니다.
  ///
  /// [body]에 항목이 하나도 없거나 필수 동의(`terms`·`privacy`)에 `false`를 넣으면 요청을 보내지 않고 [ZodError]로 실패합니다.
  ///
  /// ```dart
  /// final consents = await client.member.updateConsents(ConsentUpdateRequest(marketing: false));
  /// ```
  Future<MemberConsents> updateConsents(ConsentUpdateRequest body) async => _http.request('POST', '/me/consents',
      memberConsentsSchema, RequestOptions(body: consentUpdateRequestSchema.parse(body).toJson()));
}
