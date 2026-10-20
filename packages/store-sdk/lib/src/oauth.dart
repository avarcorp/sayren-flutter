// 손으로 쓴 파일 — Node src/oauth.ts에 대응한다.
// OAuth 2.1 authorization_code + PKCE 흐름 도우미입니다. 발급자는 Sayren 계정(accounts)이고 엔드포인트 주소는 호출부가 줍니다.
// 시크릿을 다루지 않습니다.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import 'http.dart';
import 'zod.dart';

/// [OAuthTokenResponse] 스키마입니다. RFC 6749 §5.1 토큰 응답이고 모르는 키를 남깁니다.
final ZodObject<OAuthTokenResponse> oauthTokenResponseSchema = z.object<OAuthTokenResponse>({
  'access_token': z.string(),
  'token_type': z.literal<String>('Bearer'),
  'expires_in': z.number().int_(),
  'scope': z.string().optional(),
  'refresh_token': z.string().optional(),
}, OAuthTokenResponse._, loose: true);

/// RFC 6749 §5.1 토큰 응답입니다.
class OAuthTokenResponse extends ParsedObject {
  /// [OAuthTokenResponse]를 만듭니다. 검증하지 않으므로 테스트·미리보기 데이터에 사용하십시오.
  OAuthTokenResponse({
    required String access_token,
    required String token_type,
    required int expires_in,
    String? scope,
    String? refresh_token,
  }) : super({
          'access_token': access_token,
          'token_type': token_type,
          'expires_in': expires_in,
          if (scope != null) 'scope': scope,
          if (refresh_token != null) 'refresh_token': refresh_token,
        });

  OAuthTokenResponse._(super.json);

  /// JSON을 [oauthTokenResponseSchema]로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.
  factory OAuthTokenResponse.fromJson(Map<String, Object?> json) => oauthTokenResponseSchema.parse(json);

  Map<String, Object?> get _j => jsonOf(this);

  /// 액세스 토큰입니다.
  String get access_token => _j['access_token'] as String;

  /// 토큰 유형입니다. 늘 `Bearer`입니다.
  String get token_type => _j['token_type'] as String;

  /// 액세스 토큰 유효 시간(초)입니다.
  int get expires_in => _j['expires_in'] as int;

  /// 부여된 스코프(공백 구분)입니다.
  String? get scope => _j['scope'] as String?;

  /// 갱신 토큰입니다. 갱신할 때마다 바뀌므로 응답의 새 값으로 바꿔 저장하십시오.
  String? get refresh_token => _j['refresh_token'] as String?;
}

final _random = Random.secure();

String _base64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// PKCE 쌍을 만듭니다. `verifier`(64자)와 S256 `challenge`입니다.
///
/// ```dart
/// final pkce = await createPkcePair();
/// final url = buildAuthorizeUrl(
///   authorizeUrl: authorizeUrl, clientId: clientId, redirectUri: redirectUri,
///   state: state, codeChallenge: pkce.challenge,
/// );
/// ```
Future<({String verifier, String challenge})> createPkcePair() async {
  final verifier = _base64url([for (var i = 0; i < 48; i++) _random.nextInt(256)]);
  return (verifier: verifier, challenge: _base64url(crypto.sha256.convert(utf8.encode(verifier)).bytes));
}

/// authorize 엔드포인트 주소를 만듭니다. 이 주소를 브라우저(외부 브라우저·인앱 브라우저)로 엽니다.
///
/// - [authorizeUrl]: authorize 엔드포인트 전체 주소(예: `https://accounts.sayren.io/api/auth/oauth2/authorize`)
/// - [scope]: 생략하면 발급자 기본입니다. 갱신이 필요하면 `offline_access`를 넣으십시오.
/// - [resource]: RFC 8707 리소스 지시자입니다. 주면 JWT 액세스 토큰(`aud` = 리소스)을 받습니다.
/// - [prompt]: OIDC `prompt` — `login`(재인증)·`create`(가입)·`consent`(동의 다시 받기)
String buildAuthorizeUrl({
  required String authorizeUrl,
  required String clientId,
  required String redirectUri,
  required String state,
  required String codeChallenge,
  String? scope,
  String? resource,
  String? prompt,
}) {
  final uri = Uri.parse(authorizeUrl);
  // URLSearchParams.set처럼 같은 키는 바꾸고 순서는 처음 자리를 지킨다
  final params = <(String, String)>[
    for (final pair in uri.query.isEmpty ? const <String>[] : uri.query.split('&'))
      if (pair.isNotEmpty)
        (
          Uri.decodeQueryComponent(pair.contains('=') ? pair.substring(0, pair.indexOf('=')) : pair),
          Uri.decodeQueryComponent(pair.contains('=') ? pair.substring(pair.indexOf('=') + 1) : ''),
        ),
  ];
  void set(String key, String value) {
    final i = params.indexWhere((p) => p.$1 == key);
    params.removeWhere((p) => p.$1 == key);
    params.insert(i < 0 ? params.length : i, (key, value));
  }

  set('response_type', 'code');
  set('client_id', clientId);
  set('redirect_uri', redirectUri);
  set('state', state);
  set('code_challenge', codeChallenge);
  set('code_challenge_method', 'S256');
  if (scope != null && scope.isNotEmpty) set('scope', scope);
  if (resource != null && resource.isNotEmpty) set('resource', resource);
  if (prompt != null && prompt.isNotEmpty) set('prompt', prompt);
  final base = authorizeUrl.split(RegExp('[?#]')).first;
  final query = params.map((p) => '${formEncode(p.$1)}=${formEncode(p.$2)}').join('&');
  return '${Uri.parse(base).path.isEmpty ? '$base/' : base}?$query${uri.hasFragment ? '#${uri.fragment}' : ''}';
}

/// 토큰 요청 상한 — 응답 없는 요청이 끝나지 않으면 refresh를 기다리는 모든 API 호출이 같이 멈춘다
const _tokenRequestTimeout = Duration(milliseconds: 15000);

Future<OAuthTokenResponse> _tokenRequest(String endpoint, Map<String, String> form, Fetch? fetch) async {
  final request = http.Request('POST', Uri.parse(endpoint))
    ..headers['content-type'] = 'application/x-www-form-urlencoded'
    // body(문자열)는 content-type에 charset을 붙이므로 바이트로 싣는다
    ..bodyBytes = utf8.encode(form.entries.map((e) => '${formEncode(e.key)}=${formEncode(e.value)}').join('&'));
  final response = await (fetch ?? defaultFetch())(request).timeout(_tokenRequestTimeout);
  Object? json;
  try {
    json = jsonDecode(response.body);
  } catch (_) {
    json = null;
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final body = json is Map ? json : null;
    final description = body?['error_description'];
    final error = body?['error'];
    throw Exception(description is String
        ? description
        : error is String
            ? error
            : 'HTTP ${response.statusCode}');
  }
  return oauthTokenResponseSchema.parse(unwrapData(json));
}

/// 콜백에서 받은 `code`를 액세스 토큰으로 바꿉니다. PKCE `verifier`를 함께 보냅니다.
///
/// - [tokenUrl]: 토큰 엔드포인트 전체 주소
/// - [resource]: RFC 8707 리소스 지시자
Future<OAuthTokenResponse> exchangeAuthorizationCode({
  required String tokenUrl,
  required String clientId,
  required String redirectUri,
  required String code,
  required String codeVerifier,
  String? resource,
  Fetch? fetch,
}) =>
    _tokenRequest(
      tokenUrl,
      {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': codeVerifier,
        if (resource != null && resource.isNotEmpty) 'resource': resource,
      },
      fetch,
    );

/// 갱신 토큰으로 새 토큰을 받습니다. 응답의 새 `refresh_token`으로 반드시 바꿔 저장하십시오(회전).
///
/// - [tokenUrl]: 토큰 엔드포인트 전체 주소
/// - [resource]: RFC 8707 리소스 지시자
Future<OAuthTokenResponse> refreshUserToken({
  required String tokenUrl,
  required String clientId,
  required String refreshToken,
  String? resource,
  Fetch? fetch,
}) =>
    _tokenRequest(
      tokenUrl,
      {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        if (resource != null && resource.isNotEmpty) 'resource': resource,
      },
      fetch,
    );
