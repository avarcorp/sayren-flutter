// 손으로 쓴 파일 — Node src/session.ts에 대응한다.
// Node는 탭 간 갱신을 Web Locks로 직렬화한다. Dart 앱에는 탭이 없으므로 앱 안 single-flight만 둔다.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'http.dart';
import 'oauth.dart';
import 'schemas/auth.dart';

/// 세션 토큰을 저장하는 매체입니다. 앱이 만듭니다.
///
/// 읽기·쓰기는 동기입니다. Flutter의 영구 저장소(secure storage 등)는 비동기이므로, 앱 시작 때
/// [STORE_SESSION_KEYS]의 값을 미리 읽어 메모리에 두고, 쓰기는 메모리에 반영한 뒤 영구 저장소에 비동기로 쓰십시오.
///
/// ```dart
/// class PreloadedStorage implements SessionStorage {
///   PreloadedStorage(this._prefs, this._values);
///
///   static Future<PreloadedStorage> load(SharedPreferences prefs) async => PreloadedStorage(prefs, {
///         for (final key in [STORE_SESSION_KEYS.session, STORE_SESSION_KEYS.refresh, STORE_SESSION_KEYS.pkce])
///           if (prefs.getString(key) case final value?) key: value,
///       });
///
///   final SharedPreferences _prefs;
///   final Map<String, String> _values;
///
///   @override
///   String? get(String key) => _values[key];
///
///   @override
///   void set(String key, String value) {
///     _values[key] = value;
///     unawaited(_prefs.setString(key, value));
///   }
///
///   @override
///   void remove(String key) {
///     _values.remove(key);
///     unawaited(_prefs.remove(key));
///   }
/// }
/// ```
abstract interface class SessionStorage {
  /// [key]의 값을 읽습니다. 없으면 null입니다.
  String? get(String key);

  /// [key]에 [value]를 씁니다.
  void set(String key, String value);

  /// [key]를 지웁니다.
  void remove(String key);
}

/// 세션 저장 키입니다. SDK가 정합니다.
///
/// `pkce`는 [StoreSession.authorize]와 [StoreSession.handleCallback] 사이에 한 번 쓰는 PKCE 값(`verifier`·`state`·`redirectUri`)의 키입니다.
const STORE_SESSION_KEYS = (
  session: 'sayren.store.session',
  refresh: 'sayren.store.refresh',
  pkce: 'sayren.store.pkce',
);

/// 로그아웃 폐기 요청 제한 시간
const _revokeTimeout = Duration(milliseconds: 5000);

/// 인가 서버(Sayren 계정, accounts) 주소입니다.
///
/// 예: `https://accounts.sayren.io/api/auth/oauth2/{authorize,token,revoke}`.
/// [resource]를 주면 authorize·code 교환·갱신에 RFC 8707 `resource`를 싣습니다(JWT 액세스 토큰의 `aud`).
class StoreAuthServer {
  /// 주소를 만듭니다.
  const StoreAuthServer({required this.authorizeUrl, required this.tokenUrl, required this.revokeUrl, this.resource});

  /// authorize 엔드포인트 주소입니다.
  final String authorizeUrl;

  /// 토큰 엔드포인트 주소입니다.
  final String tokenUrl;

  /// 토큰 폐기(RFC 7009) 엔드포인트 주소입니다.
  final String revokeUrl;

  /// RFC 8707 리소스 지시자입니다.
  final String? resource;
}

/// [createStoreSession]에 넘기는 옵션입니다.
class StoreSessionOptions {
  /// 옵션을 만듭니다.
  const StoreSessionOptions({
    required this.baseUrl,
    required this.authServer,
    required this.clientId,
    required this.storage,
    this.fetch,
  });

  /// API 주소입니다(예: `https://api.sayren.io/v1`). [StoreSession.userinfo]의 `GET /me`에 사용합니다.
  final String baseUrl;

  /// 인가 서버(accounts) 주소입니다.
  final StoreAuthServer authServer;

  /// OAuth public client id입니다.
  final String clientId;

  /// 토큰 저장 매체입니다(앱 소유).
  final SessionStorage storage;

  /// HTTP 요청을 보내는 함수입니다. 생략하면 `package:http`로 보냅니다.
  final Fetch? fetch;
}

/// [StoreSession.authorize]의 옵션입니다.
class AuthorizeOptions {
  /// 옵션을 만듭니다.
  const AuthorizeOptions({required this.redirectUri, this.scope, this.prompt});

  /// OAuth 콜백 주소입니다. 앱이면 딥링크 주소(예: `com.example.app://auth/callback`)입니다.
  final String redirectUri;

  /// 생략하면 발급자 기본입니다. 갱신이 필요하면 `offline_access`를 넣으십시오.
  final String? scope;

  /// OIDC `prompt` — `login`(재인증)·`create`(가입)·`consent`
  final String? prompt;
}

/// 셀러 세션입니다. 계정 토큰을 저장하고, 만료되면 조용히 갱신하고(회전), 로그아웃하면 서버에서 폐기합니다.
///
/// [StoreClientOptions.session]에 넘기면 클라이언트가 토큰을 읽고, 401이면 갱신 뒤 한 번 다시 보내고,
/// 갱신할 수 없으면 세션을 지웁니다.
///
/// 로그인 흐름은 [authorize]로 받은 주소를 브라우저로 열고, 딥링크로 돌아온 `code`·`state`를 [handleCallback]에 넘기는 것입니다.
///
/// @docImport 'client.dart';
abstract interface class StoreSession {
  /// 현재 액세스 토큰입니다. 없으면 null입니다.
  String? getToken();

  /// 토큰을 저장하고 구독자에게 알립니다. [refresh_token]이 있으면 함께 바꿔 저장하고, 없으면 기존 값을 둡니다.
  void setTokens({required String access_token, String? refresh_token});

  /// 토큰을 조용히 갱신합니다. 갱신 토큰으로 새 액세스 토큰을 받아 바꿔 저장합니다.
  ///
  /// 동시에 여러 번 불러도 요청은 한 번입니다. 갱신 토큰이 없으면 false(기존 세션 유지)이고,
  /// 갱신에 실패하면(만료·재사용 폐기) 세션을 지우고 false입니다.
  Future<bool> refresh();

  /// 저장한 토큰을 지우고 구독자에게 알립니다. 서버의 토큰은 그대로이므로 로그아웃은 [logout]을 사용하십시오.
  void clear();

  /// 로그아웃합니다. 인가 서버에서 갱신 토큰(패밀리째)과 액세스 토큰을 폐기(RFC 7009)한 뒤 세션을 지웁니다.
  ///
  /// 폐기 요청 실패(네트워크·이미 무효)는 무시하고 세션은 항상 지웁니다.
  Future<void> logout();

  /// 세션이 바뀔 때 [listener]를 부릅니다. 돌려준 함수를 부르면 구독을 끊습니다.
  void Function() subscribe(void Function() listener);

  /// 현재 액세스 토큰입니다([getToken]과 같습니다). 없으면 null입니다.
  String? get accessToken;

  /// 현재 저장된 갱신 토큰입니다. 없으면 null입니다.
  String? get refreshToken;

  /// 로그인·가입을 시작합니다. PKCE 쌍을 만들어 저장하고 authorize 주소를 돌려줍니다.
  ///
  /// Node SDK는 브라우저면 이 주소로 이동합니다. Dart SDK는 이동하지 않고 늘 주소를 돌려주므로 앱이 브라우저로 여십시오.
  Future<String?> authorize(AuthorizeOptions options);

  /// OAuth 콜백을 처리합니다. 저장한 PKCE 값(1회용)을 꺼내 [state]를 대조하고 [code]를 토큰으로 바꿔 저장합니다.
  ///
  /// PKCE 값이 없거나(만료) [state]가 다르면 실패합니다.
  Future<void> handleCallback(String code, String state);

  /// 로그인한 계정 정보입니다(`GET /me`). 토큰이 없으면 요청하지 않고 null입니다.
  Future<MyAccount?> userinfo();
}

/// 셀러 세션을 만듭니다.
///
/// ```dart
/// final session = createStoreSession(StoreSessionOptions(
///   baseUrl: 'https://api.sayren.io/v1',
///   authServer: const StoreAuthServer(
///     authorizeUrl: 'https://accounts.sayren.io/api/auth/oauth2/authorize',
///     tokenUrl: 'https://accounts.sayren.io/api/auth/oauth2/token',
///     revokeUrl: 'https://accounts.sayren.io/api/auth/oauth2/revoke',
///   ),
///   clientId: clientId,
///   storage: storage,
/// ));
/// final url = await session.authorize(const AuthorizeOptions(redirectUri: 'com.example.app://auth/callback'));
/// // 브라우저로 url을 열고, 딥링크로 돌아오면
/// await session.handleCallback(code, state);
/// ```
StoreSession createStoreSession(StoreSessionOptions options) => _StoreSession(options);

final _random = Random.secure();

class _StoreSession implements StoreSession {
  _StoreSession(this._options) : _fetch = _options.fetch ?? defaultFetch();

  final StoreSessionOptions _options;
  final Fetch _fetch;
  final _listeners = <void Function()>{};
  Future<bool>? _refreshInFlight;

  SessionStorage get _storage => _options.storage;
  StoreAuthServer get _server => _options.authServer;

  void _notify() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  @override
  String? getToken() => _storage.get(STORE_SESSION_KEYS.session);

  @override
  void setTokens({required String access_token, String? refresh_token}) {
    _storage.set(STORE_SESSION_KEYS.session, access_token);
    if (refresh_token != null && refresh_token.isNotEmpty) _storage.set(STORE_SESSION_KEYS.refresh, refresh_token);
    _notify();
  }

  @override
  void clear() {
    _storage
      ..remove(STORE_SESSION_KEYS.session)
      ..remove(STORE_SESSION_KEYS.refresh);
    _notify();
  }

  /// RFC 7009 — 무효 토큰이어도 200이다. 실패는 호출부가 무시한다. 응답이 늦어도 로그아웃이 멈추지 않게 5초로 끊는다
  Future<void> _revokeToken(String token) async {
    final request = http.Request('POST', Uri.parse(_server.revokeUrl))
      ..headers['content-type'] = 'application/x-www-form-urlencoded'
      ..bodyBytes = utf8.encode('token=${formEncode(token)}&client_id=${formEncode(_options.clientId)}');
    await _fetch(request).timeout(_revokeTimeout);
  }

  @override
  Future<void> logout() async {
    // 진행 중인 갱신이 있으면 끝나기를 기다린다 — 그 사이 회전된 새 갱신 토큰을 폐기해야 한다
    final inFlight = _refreshInFlight;
    if (inFlight != null) await inFlight.catchError((Object _) => false);
    final refreshToken = _storage.get(STORE_SESSION_KEYS.refresh);
    final accessToken = getToken();
    // 갱신 토큰 먼저 — 패밀리를 폐기해야 새 액세스 토큰 발급이 끊긴다
    for (final token in [refreshToken, accessToken]) {
      if (token == null || token.isEmpty) continue;
      try {
        await _revokeToken(token);
      } catch (_) {
        // 네트워크 실패여도 로그아웃은 진행한다
      }
    }
    clear();
  }

  @override
  Future<bool> refresh() => _refreshInFlight ??= _rotate(getToken()).whenComplete(() => _refreshInFlight = null);

  Future<bool> _rotate(String? before) async {
    // 세션 토큰이 이미 바뀌었으면 다른 곳에서 회전한 것 → 내 갱신 토큰은 소비하지 않는다
    if (getToken() != before) return true;
    final refreshToken = _storage.get(STORE_SESSION_KEYS.refresh);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final tokens = await refreshUserToken(
        clientId: _options.clientId,
        refreshToken: refreshToken,
        tokenUrl: _server.tokenUrl,
        resource: _server.resource,
        fetch: _fetch,
      );
      setTokens(access_token: tokens.access_token, refresh_token: tokens.refresh_token);
      return true;
    } catch (_) {
      clear(); // 갱신 토큰까지 함께 지운다
      return false;
    }
  }

  @override
  void Function() subscribe(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  @override
  String? get accessToken => getToken();

  @override
  String? get refreshToken => _storage.get(STORE_SESSION_KEYS.refresh);

  /// Node `crypto.randomUUID()`와 같은 형식(UUID v4)
  String _randomState() {
    final b = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  Future<String?> authorize(AuthorizeOptions options) async {
    final pkce = await createPkcePair();
    final state = _randomState();
    _storage.set(
      STORE_SESSION_KEYS.pkce,
      jsonEncode({'verifier': pkce.verifier, 'state': state, 'redirectUri': options.redirectUri}),
    );
    return buildAuthorizeUrl(
      authorizeUrl: _server.authorizeUrl,
      clientId: _options.clientId,
      redirectUri: options.redirectUri,
      state: state,
      codeChallenge: pkce.challenge,
      scope: options.scope,
      resource: _server.resource,
      prompt: options.prompt,
    );
  }

  @override
  Future<void> handleCallback(String code, String state) async {
    final raw = _storage.get(STORE_SESSION_KEYS.pkce);
    _storage.remove(STORE_SESSION_KEYS.pkce); // 1회용
    if (raw == null || raw.isEmpty) throw StateError('로그인 세션이 만료되었습니다. 다시 시도해주십시오');
    final saved = jsonDecode(raw) as Map<String, Object?>;
    if (saved['state'] != state) throw StateError('state가 일치하지 않습니다. 다시 시도해주십시오');
    final tokens = await exchangeAuthorizationCode(
      clientId: _options.clientId,
      redirectUri: saved['redirectUri'] as String,
      code: code,
      codeVerifier: saved['verifier'] as String,
      tokenUrl: _server.tokenUrl,
      resource: _server.resource,
      fetch: _fetch,
    );
    setTokens(access_token: tokens.access_token, refresh_token: tokens.refresh_token);
  }

  @override
  Future<MyAccount?> userinfo() async {
    final token = getToken();
    if (token == null || token.isEmpty) return null;
    final request = http.Request('GET', Uri.parse('${_options.baseUrl}/me'))
      ..headers['authorization'] = 'Bearer $token';
    final response = await _fetch(request);
    Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      json = null;
    }
    if (response.statusCode < 200 || response.statusCode > 299) throw toApiError(response.statusCode, json);
    return myAccountSchema.parse(unwrapData(json));
  }
}
