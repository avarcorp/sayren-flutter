// 손으로 쓴 파일 — Node src/session.ts에 대응한다.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http.dart';
import 'schemas/auth.dart';
import 'schemas/member.dart';

/// 세션 토큰을 저장하는 매체입니다. 앱이 만듭니다.
///
/// 읽기·쓰기는 동기입니다. Flutter의 영구 저장소(secure storage 등)는 비동기이므로, 앱 시작 때
/// [STOREFRONT_SESSION_KEYS]의 값을 미리 읽어 메모리에 두고, 쓰기는 메모리에 반영한 뒤 영구 저장소에 비동기로 쓰십시오.
///
/// ```dart
/// class PreloadedStorage implements SessionStorage {
///   PreloadedStorage(this._prefs, this._values);
///
///   static Future<PreloadedStorage> load(SharedPreferences prefs) async => PreloadedStorage(prefs, {
///         for (final key in [STOREFRONT_SESSION_KEYS.accessToken, STOREFRONT_SESSION_KEYS.refreshToken])
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
const STOREFRONT_SESSION_KEYS = (
  accessToken: 'sayren.storefront.accessToken',
  refreshToken: 'sayren.storefront.refreshToken',
);

/// [createStorefrontSession]에 넘기는 옵션입니다.
class StorefrontSessionOptions {
  /// 옵션을 만듭니다.
  const StorefrontSessionOptions({required this.baseUrl, this.storeCode, required this.storage, this.fetch});

  /// 스토어프론트 API 주소입니다. 예: `https://api.sayren.io/storefront/v1`
  final String baseUrl;

  /// 상점 코드입니다. `X-Store-Code` 헤더로 보냅니다.
  final String? storeCode;

  /// 토큰 저장 매체입니다(앱 소유).
  final SessionStorage storage;

  /// HTTP 요청을 보내는 함수입니다. 생략하면 `package:http`로 보냅니다.
  final Fetch? fetch;
}

/// 구매자 세션입니다. 이메일·비밀번호 로그인 토큰을 저장하고, 만료되면 조용히 갱신합니다.
///
/// [StorefrontClientOptions.session]에 넘기면 클라이언트가 회원 토큰을 읽고, 401이면 갱신 뒤 한 번 다시 보내고,
/// 갱신할 수 없으면 세션을 지웁니다.
///
/// @docImport 'client.dart';
abstract interface class StorefrontSession {
  /// 이메일·비밀번호로 로그인합니다(`POST /auth/login`). 받은 토큰을 저장하고 구독자에게 알립니다.
  Future<void> login(LoginRequest body);

  /// 회원가입합니다(`POST /auth/signup`). [login]처럼 토큰을 저장합니다.
  Future<void> signup(SignupRequest body);

  /// 토큰을 조용히 갱신합니다. 갱신 토큰으로 새 토큰 쌍을 받아 저장합니다.
  ///
  /// 동시에 여러 번 불러도 요청은 한 번입니다. 갱신 토큰이 없거나 갱신에 실패하면(만료·재사용 폐기) 세션을 지우고 false입니다.
  Future<bool> refresh();

  /// 현재 액세스 토큰입니다. 없으면 null입니다.
  String? get accessToken;

  /// 현재 갱신 토큰입니다. 없으면 null입니다.
  String? get refreshToken;

  /// 로그인한 회원 정보입니다(`GET /me`). 토큰이 없으면 요청하지 않고 null입니다.
  Future<Member?> userinfo();

  /// 세션을 지웁니다. 저장한 토큰을 지우고 구독자에게 알린 뒤, 서버 로그아웃(`POST /auth/logout`)을 결과를 기다리지 않고 보냅니다.
  void clear();

  /// 세션이 바뀔 때 [listener]를 부릅니다. 돌려준 함수를 부르면 구독을 끊습니다.
  void Function() subscribe(void Function() listener);
}

/// 구매자 세션을 만듭니다.
///
/// ```dart
/// final session = createStorefrontSession(StorefrontSessionOptions(baseUrl: baseUrl, storeCode: storeCode, storage: storage));
/// final client = createStorefrontClient(StorefrontClientOptions(baseUrl: baseUrl, storeCode: storeCode, session: session));
/// await session.login(LoginRequest(email: email, password: password));
/// ```
StorefrontSession createStorefrontSession(StorefrontSessionOptions options) => _StorefrontSession(options);

class _StorefrontSession implements StorefrontSession {
  _StorefrontSession(this._options) : _fetch = _options.fetch ?? defaultFetch();

  final StorefrontSessionOptions _options;
  final Fetch _fetch;
  final _listeners = <void Function()>{};
  Future<bool>? _refreshInFlight;

  SessionStorage get _storage => _options.storage;

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  Map<String, String> _headers([String? accessToken]) => {
        if (_options.storeCode case final code? when code.isNotEmpty) 'x-store-code': code,
        if (accessToken != null && accessToken.isNotEmpty) 'authorization': 'Bearer $accessToken',
      };

  Future<Object?> _postJson(String path, Object? body, [String? accessToken]) async {
    final request = http.Request('POST', Uri.parse('${_options.baseUrl}$path'))
      ..headers.addAll({'content-type': 'application/json', ..._headers(accessToken)})
      ..bodyBytes = utf8.encode(jsonEncode(body ?? const {}));
    final response = await _fetch(request);
    final json = _readJson(response);
    if (response.statusCode < 200 || response.statusCode > 299) throw toApiError(response.statusCode, json);
    return unwrapData(json);
  }

  static Object? _readJson(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  void _setTokens(TokenPair tokens) {
    _storage.set(STOREFRONT_SESSION_KEYS.accessToken, tokens.accessToken);
    _storage.set(STOREFRONT_SESSION_KEYS.refreshToken, tokens.refreshToken);
    _notify();
  }

  @override
  String? get accessToken => _storage.get(STOREFRONT_SESSION_KEYS.accessToken);

  @override
  String? get refreshToken => _storage.get(STOREFRONT_SESSION_KEYS.refreshToken);

  @override
  void clear() {
    final token = accessToken;
    _storage.remove(STOREFRONT_SESSION_KEYS.accessToken);
    _storage.remove(STOREFRONT_SESSION_KEYS.refreshToken);
    _notify();
    unawaited(_postJson('/auth/logout', const {}, token).then<void>((_) {}, onError: (_) {}));
  }

  @override
  Future<void> login(LoginRequest body) async {
    final parsed = loginRequestSchema.parse(body);
    _setTokens(tokenPairSchema.parse(await _postJson('/auth/login', parsed.toJson())));
  }

  @override
  Future<void> signup(SignupRequest body) async {
    final parsed = signupRequestSchema.parse(body);
    _setTokens(tokenPairSchema.parse(await _postJson('/auth/signup', parsed.toJson())));
  }

  @override
  Future<bool> refresh() => _refreshInFlight ??= _rotate(accessToken).whenComplete(() => _refreshInFlight = null);

  Future<bool> _rotate(String? before) async {
    if (accessToken != before) return true;
    final token = refreshToken;
    if (token == null) {
      clear();
      return false;
    }
    try {
      _setTokens(tokenPairSchema.parse(await _postJson('/auth/token/refresh', {'refreshToken': token})));
      return true;
    } catch (_) {
      clear(); // 갱신 토큰까지 함께 폐기
      return false;
    }
  }

  @override
  Future<Member?> userinfo() async {
    final token = accessToken;
    if (token == null) return null;
    final response =
        await _fetch(http.Request('GET', Uri.parse('${_options.baseUrl}/me'))..headers.addAll(_headers(token)));
    final json = _readJson(response);
    if (response.statusCode < 200 || response.statusCode > 299) throw toApiError(response.statusCode, json);
    return memberSchema.parse(unwrapData(json));
  }

  @override
  void Function() subscribe(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}
