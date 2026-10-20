  StoreClient._(StoreClientOptions options) : _session = options.session {
    final session = options.session;
    final fetch = options.fetch ?? defaultFetch();
    // 세션이 있으면 토큰·갱신·onUnauthorized의 기본값을 세션에서 가져온다. 개별 옵션을 주면 그쪽이 우선한다
    final TokenSource tokenSource = options.accessToken ?? (session == null ? null : session.getToken);
    final refresh = options.refresh ?? session?.refresh;
    final onUnauthorized = options.onUnauthorized ?? session?.clear;
    Map<String, String> bearer() {
      final token = resolveToken(tokenSource);
      return token != null && token.isNotEmpty ? {'authorization': 'Bearer $token'} : {};
    }

    final userHttp = Http(HttpOptions(
      baseUrl: options.baseUrl,
      fetch: fetch,
      headers: bearer,
      refresh: refresh,
      onUnauthorized: onUnauthorized,
    ));
    final storeHttp = Http(HttpOptions(
      baseUrl: options.baseUrl,
      fetch: fetch,
      headers: () {
        final storeId = resolveToken(options.storeId);
        return {...bearer(), if (storeId != null && storeId.isNotEmpty) 'x-store-id': storeId};
      },
      refresh: refresh,
      onUnauthorized: onUnauthorized,
    ));
    final http_ = _Https(userHttp, storeHttp, fetch);
/*INIT*/
  }

  final StoreSession? _session;

  StoreSession _requireSession() {
    final session = _session;
    if (session == null) throw StateError('oauth 세션 없음 — createStoreSession 필요');
    return session;
  }

  /// 세션의 현재 액세스 토큰입니다. 세션을 넘기지 않았으면 null입니다.
  String? get accessToken => _session?.accessToken;

  /// 세션의 현재 갱신 토큰입니다. 세션을 넘기지 않았으면 null입니다.
  String? get refreshToken => _session?.refreshToken;

  /// 세션의 [StoreSession.authorize]입니다. 세션을 넘기지 않았으면 [StateError]로 실패합니다.
  Future<String?> authorize(AuthorizeOptions authorizeOptions) async => _requireSession().authorize(authorizeOptions);

  /// 세션의 [StoreSession.userinfo]입니다. 세션을 넘기지 않았으면 [StateError]로 실패합니다.
  Future<MyAccount?> userinfo() async => _requireSession().userinfo();
