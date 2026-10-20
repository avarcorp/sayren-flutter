/// [createStoreClient]에 넘기는 옵션입니다.
///
/// [TokenSource] 타입 옵션은 문자열 또는 문자열을 돌려주는 함수를 받습니다. 함수를 넘기면 요청마다 다시 읽습니다.
///
/// ```dart
/// final client = createStoreClient(StoreClientOptions(
///   baseUrl: 'https://api.sayren.io/v1',
///   accessToken: personalAccessToken,
///   storeId: storeId,
/// ));
/// ```
class StoreClientOptions {
  /// 옵션을 만듭니다. [baseUrl]만 필수입니다.
  const StoreClientOptions({
    required this.baseUrl,
    this.accessToken,
    this.storeId,
    this.session,
    this.refresh,
    this.onUnauthorized,
    this.fetch,
  });

  /// 관리 API 주소입니다. 예: `https://api.sayren.io/v1`
  final String baseUrl;

  /// 계정 토큰입니다(accounts가 발급한 JWT — 상점 플랫폼 로그인, 개인 액세스 토큰, 연결된 앱의 토큰).
  ///
  /// 계정 API(`/me/*`)와 상점 API 모두에 `Authorization: Bearer`로 보냅니다. [session]을 주면 생략해도 세션 토큰을 사용합니다.
  final TokenSource accessToken;

  /// 대상 상점 id입니다. 상점 API 요청에 `X-Store-Id`로 보냅니다. 계정 API(`/me/*`)에는 보내지 않습니다.
  final TokenSource storeId;

  /// SDK 세션입니다. 주면 Bearer 토큰, 401 갱신, 복구할 수 없을 때 세션 지우기를 이 세션으로 처리합니다.
  ///
  /// [accessToken]·[refresh]·[onUnauthorized]를 직접 주면 그쪽이 우선합니다.
  final StoreSession? session;

  /// 401일 때 부르는 세션 갱신입니다. true면 요청을 한 번 다시 보냅니다(갱신 토큰 회전).
  final Future<bool> Function()? refresh;

  /// 복구할 수 없는 401(갱신 실패, 다시 보낸 뒤에도 401)일 때 부릅니다. 다시 로그인하게 하는 자리입니다.
  final void Function()? onUnauthorized;

  /// HTTP 요청을 보내는 함수입니다. 생략하면 `package:http`로 보냅니다.
  final Fetch? fetch;
}

/// 계정 API(`/me/*`)와 상점 API(`X-Store-Id`)의 HTTP 코어
class _Https {
  _Https(this.user, this.store, this.fetch);

  final Http user;
  final Http store;

  /// 업로드 PUT처럼 API 밖으로 보내는 요청
  final Fetch fetch;
}

Map<String, String>? _idempotency(String? key) => key == null || key.isEmpty ? null : {'idempotency-key': key};

/// 관리 API 클라이언트를 만듭니다.
///
/// ```dart
/// final client = createStoreClient(StoreClientOptions(baseUrl: baseUrl, storeId: storeId, session: session));
/// final page = await client.products.list(ProductListParams(size: 20));
/// ```
StoreClient createStoreClient(StoreClientOptions options) => StoreClient._(options);
