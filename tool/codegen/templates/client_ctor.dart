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
/*INIT*/
  }
