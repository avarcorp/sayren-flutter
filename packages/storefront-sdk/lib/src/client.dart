import 'package:http/http.dart' as http;

import 'http.dart';
import 'schemas/analytics.dart';
import 'schemas/catalog.dart';
import 'schemas/common.dart';
import 'schemas/consent.dart';
import 'schemas/store.dart';
import 'zod.dart';

class StorefrontClientOptions {
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

  /// 예: https://demo.store.example.com/api/v1
  final String baseUrl;

  /// 테넌트 상점 코드 — `X-Store-Code` 헤더로 전송한다. 함수로 전달하면 매 요청마다 재평가
  final TokenSource storeCode;

  /// 회원 Access Token. 함수로 전달하면 매 요청마다 재평가
  final TokenSource accessToken;

  /// accessToken의 별칭 옵션. 우선순위: 명시적 `accessToken` > `auth.accessToken` > `session.accessToken`
  final ({String? accessToken})? auth;

  /// 비회원 장바구니 토큰
  final TokenSource cartToken;

  /// 방문 분석 식별자 — 방문자·세션 ID
  final TokenSource visitorId;
  final TokenSource sessionId;

  /// 구매자 국가(ISO 3166-1 alpha-2) — `X-Buyer-Country`
  final TokenSource country;

  /// 스토어프론트 도메인 — `X-Storefront-Host`
  final TokenSource host;

  /// 구매자 언어 — `Accept-Language`
  final TokenSource locale;

  /// 서버가 새 X-Cart-Token을 발급했을 때 호출
  final void Function(String token)? onCartToken;

  final Fetch? fetch;
}

StorefrontClient createStorefrontClient(StorefrontClientOptions options) => StorefrontClient._(options);

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
    store = _Store(http_);
    catalog = _Catalog(http_);
    member = _Member(http_);
  }

  late final _Store store;
  late final _Catalog catalog;
  late final _Member member;
}

class _Store {
  const _Store(this._http);

  final Http _http;

  /// 상점 공개 설정 — 이름·고객센터·비회원 주문 허용 여부
  Future<StorefrontStore> get() => _http.request('GET', '/store', storefrontStoreSchema);
}

class _Catalog {
  const _Catalog(this._http);

  final Http _http;

  Future<List<CategoryNode>> listCategories() => _http.request('GET', '/categories', z.array(categoryNodeSchema));

  /// 노출 중인 컬렉션(노출 켜짐 + 기간 안) — 셀러가 정한 순서
  Future<Page<StorefrontCollection>> listCollections([PageParams? params]) => _http.request(
      'GET', '/collections', pageSchema(storefrontCollectionSchema), RequestOptions(query: params?.toJson()));
}

class _Member {
  const _Member(this._http);

  final Http _http;

  /// 재동의·마케팅 동의 변경 — 바꾼 뒤의 상태를 돌려준다
  Future<MemberConsents> updateConsents(ConsentUpdateRequest body) => _http.request('POST', '/me/consents',
      memberConsentsSchema, RequestOptions(body: consentUpdateRequestSchema.parse(body).toJson()));
}
