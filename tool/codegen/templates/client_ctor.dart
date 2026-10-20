  StorefrontClient._(StorefrontClientOptions options) : _session = options.session {
    final session = options.session;
    // 우선순위: 명시적 accessToken 옵션 > auth.accessToken 별칭 > session.accessToken
    final TokenSource accessTokenSource =
        options.accessToken ?? options.auth?.accessToken ?? (session == null ? null : () => session.accessToken);
    final http_ = Http(HttpOptions(
      baseUrl: options.baseUrl,
      fetch: options.fetch,
      refresh: session?.refresh,
      onUnauthorized: session?.clear,
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
/*INIT*/
  }

  final StorefrontSession? _session;

  /// 세션의 현재 액세스 토큰입니다. 세션을 넘기지 않았으면 null입니다.
  String? get accessToken => _session?.accessToken;

  /// 세션의 현재 갱신 토큰입니다. 세션을 넘기지 않았으면 null입니다.
  String? get refreshToken => _session?.refreshToken;

  /// 세션의 [StorefrontSession.userinfo]입니다. 세션을 넘기지 않았으면 [StateError]로 실패합니다.
  Future<Member?> userinfo() async {
    final session = _session;
    if (session == null) throw StateError('세션 없음 — createStorefrontSession 필요');
    return session.userinfo();
  }
