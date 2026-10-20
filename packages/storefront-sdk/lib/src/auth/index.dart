// 손으로 쓴 파일 — Node src/auth/index.ts에 대응한다.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;

import '../client.dart';
import '../http.dart';
import '../schemas/auth.dart';

/// 소셜 로그인 시작 결과입니다. [codeVerifier]와 [state]는 돌아올 때까지 앱에 보관합니다.
class IdpStart {
  /// 결과를 만듭니다.
  const IdpStart({required this.url, required this.state, required this.codeVerifier});

  /// 구매자를 보낼 공급자 로그인 주소입니다. 시스템 브라우저나 인앱 브라우저로 여십시오.
  final String url;

  /// 위조 방지 값입니다. 돌아온 주소의 `state`와 비교합니다.
  final String state;

  /// PKCE 검증 값입니다. 돌아온 `code`를 토큰으로 바꿀 때 보냅니다.
  final String codeVerifier;
}

/// 소셜 로그인 복귀 값입니다. [StorefrontAuth.idpCallback]의 인자와 같은 필드입니다.
class IdpCallbackInput {
  /// 값을 만듭니다.
  const IdpCallbackInput({
    required this.code,
    required this.state,
    required this.expectedState,
    required this.codeVerifier,
    this.cartToken,
  });

  /// 돌아온 주소의 `code`(성공)입니다. 실패면 `error`가 옵니다.
  final String? code;

  /// 돌아온 주소의 `state`입니다.
  final String? state;

  /// [StorefrontAuth.idp]가 준 `state`입니다. 보관해 둔 값입니다.
  final String expectedState;

  /// [StorefrontAuth.idp]가 준 `codeVerifier`입니다.
  final String codeVerifier;

  /// 비회원 장바구니 토큰입니다. 넘기면 회원 장바구니로 합칩니다.
  final String? cartToken;
}

/// 소셜 로그인을 마치지 못했습니다. 구매자가 취소했거나(`access_denied`) state가 맞지 않습니다.
class IdpCallbackError implements Exception {
  /// 예외를 만듭니다.
  IdpCallbackError(this.reason);

  /// 실패 사유입니다. `access_denied`·`state_mismatch`·`missing_code` 또는 공급자가 보낸 `error` 값입니다.
  final String reason;

  /// 예외 이름입니다. 항상 `IdpCallbackError`입니다.
  String get name => 'IdpCallbackError';

  /// 사람이 읽는 설명입니다.
  String get message => '소셜 로그인을 마치지 못했습니다 ($reason)';

  @override
  String toString() => '$name: $message';
}

/// [createStorefrontAuth]에 넘기는 옵션입니다.
class StorefrontAuthOptions {
  /// 옵션을 만듭니다.
  const StorefrontAuthOptions({required this.baseUrl, required this.storeCode, this.fetch});

  /// 스토어프론트 API 주소입니다. 예: `https://api.sayren.io/storefront/v1`
  final String baseUrl;

  /// 상점 코드입니다. `X-Store-Code` 헤더로 보냅니다.
  final String storeCode;

  /// HTTP 요청을 보내는 함수입니다. 생략하면 `package:http`로 보냅니다.
  final Fetch? fetch;
}

final _random = Random.secure();

String _base64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _randomToken([int bytes = 32]) => _base64url([for (var i = 0; i < bytes; i++) _random.nextInt(256)]);

String _s256(String verifier) => _base64url(crypto.sha256.convert(utf8.encode(verifier)).bytes);

/// 구매자 인증을 만듭니다.
///
/// 화면은 앱이 그리고, 계정 저장과 인증 처리는 sayren이 합니다. 어느 방식으로 로그인해도 결과는 같은 구매자 토큰([TokenPair])이고
/// `/me/*`·장바구니·주문 API에 그대로 사용합니다. 토큰 보관은 앱 몫입니다.
///
/// ```dart
/// final auth = createStorefrontAuth(StorefrontAuthOptions(baseUrl: baseUrl, storeCode: storeCode));
/// final guest = await auth.anonymous(); // 비회원: 장바구니 토큰
/// final tokens = await auth.session(LoginRequest(email: email, password: password, cartToken: guest.cartToken));
/// ```
StorefrontAuth createStorefrontAuth(StorefrontAuthOptions options) => StorefrontAuth._(options);

/// 구매자 인증입니다. [createStorefrontAuth]로 만듭니다.
class StorefrontAuth {
  StorefrontAuth._(this._options);

  final StorefrontAuthOptions _options;

  StorefrontClient _client([String? accessToken]) => createStorefrontClient(StorefrontClientOptions(
        baseUrl: _options.baseUrl,
        storeCode: _options.storeCode,
        accessToken: accessToken,
        fetch: _options.fetch,
      ));

  /// 비회원 익명 세션을 만듭니다. 구매자 계정은 만들지 않습니다.
  ///
  /// `cartToken`을 `X-Cart-Token`으로 보내면 장바구니·비회원 주문이 쌓이고, [session]·[signUp]에 실으면 회원 장바구니로 합쳐진 뒤 닫힙니다.
  /// 마지막 활동 후 30일이 지나면 만료됩니다.
  Future<AnonymousSession> anonymous() => _client().auth.anonymous();

  /// 이메일·비밀번호로 로그인합니다. `cartToken`을 주면 비회원 장바구니를 합칩니다.
  Future<TokenPair> session(LoginRequest body) => _client().auth.login(body);

  /// 회원가입합니다. 가입과 동시에 로그인 토큰을 받습니다. `cartToken`을 주면 장바구니를 합칩니다.
  Future<TokenPair> signUp(SignupRequest body) => _client().auth.signup(body);

  /// 소셜 로그인을 시작합니다. PKCE(S256)와 state를 만들고 공급자 로그인 주소를 받습니다.
  ///
  /// 돌려준 `state`·`codeVerifier`를 보관하고 구매자를 `url`로 보냅니다. 로그인을 마치면 [redirectUri]로 `?code=&state=`가 붙어 돌아옵니다.
  /// 앱은 딥링크로 받아 [idpCallback]에 넘깁니다. [redirectUri]는 스토어프론트 도메인 목록 안이어야 합니다.
  ///
  /// 가입 화면에서 받은 약관 동의는 [agreements]로 함께 보냅니다. 이 로그인으로 가입이 되는 경우에만 이력에 남습니다.
  Future<IdpStart> idp(
    SocialProvider provider, {
    required String redirectUri,
    ({bool terms, bool privacy, bool? marketing})? agreements,
  }) async {
    final state = _randomToken(24);
    final codeVerifier = _randomToken();
    final response = await _client().auth.idpAuthorize(
          provider,
          IdpAuthorizeRequest(
            redirectUri: redirectUri,
            codeChallenge: _s256(codeVerifier),
            state: state,
            agreements: agreements == null
                ? null
                : IdpAgreements(terms: true, privacy: true, marketing: agreements.marketing ?? false),
          ),
        );
    return IdpStart(url: response.url, state: state, codeVerifier: codeVerifier);
  }

  /// 소셜 로그인을 마칩니다. 돌아온 [code]를 구매자 토큰으로 바꿉니다.
  ///
  /// [error]가 있거나 state가 다르거나 code가 없으면 [IdpCallbackError]로 실패합니다. code는 1회용이고 1분 안에 바꿔야 합니다.
  Future<TokenPair> idpCallback({
    required String? code,
    required String? state,
    required String expectedState,
    required String codeVerifier,
    String? cartToken,
    String? error,
  }) async {
    if (error != null && error.isNotEmpty) throw IdpCallbackError(error);
    if (state == null || state.isEmpty || state != expectedState) throw IdpCallbackError('state_mismatch');
    if (code == null || code.isEmpty) throw IdpCallbackError('missing_code');
    return _client().auth.idpToken(IdpTokenRequest(code: code, codeVerifier: codeVerifier, cartToken: cartToken));
  }

  /// 로그인 수단입니다. 비밀번호가 있는지, 어떤 소셜 계정이 연결됐는지 알려 줍니다.
  Future<MemberIdentities> identities(String accessToken) => _client(accessToken).auth.identities();

  /// 소셜 계정 연결을 시작합니다. 로그인한 구매자에 공급자 계정을 붙입니다.
  ///
  /// [idp]처럼 `state`·`codeVerifier`를 보관하고 구매자를 `url`로 보냅니다. 돌아오면 [linkIdpCallback]으로 마칩니다.
  Future<IdpStart> linkIdp(String accessToken, SocialProvider provider, {required String redirectUri}) async {
    final state = _randomToken(24);
    final codeVerifier = _randomToken();
    final response = await _client(accessToken).auth.linkIdentityAuthorize(
          provider,
          IdpAuthorizeRequest(redirectUri: redirectUri, codeChallenge: _s256(codeVerifier), state: state),
        );
    return IdpStart(url: response.url, state: state, codeVerifier: codeVerifier);
  }

  /// 소셜 계정 연결을 마칩니다. state를 비교하고 code를 바꿔 연결합니다.
  ///
  /// 다른 구매자에 이미 연결된 계정이면 409 `IDENTITY_IN_USE`, 같은 공급자의 다른 계정을 이미 연결했으면 409 `PROVIDER_ALREADY_LINKED`입니다.
  Future<MemberIdentities> linkIdpCallback(
    String accessToken,
    SocialProvider provider, {
    required String? code,
    required String? state,
    required String expectedState,
    required String codeVerifier,
    String? error,
  }) async {
    if (error != null && error.isNotEmpty) throw IdpCallbackError(error);
    if (state == null || state.isEmpty || state != expectedState) throw IdpCallbackError('state_mismatch');
    if (code == null || code.isEmpty) throw IdpCallbackError('missing_code');
    return _client(accessToken)
        .auth
        .linkIdentity(provider, LinkIdentityRequest(code: code, codeVerifier: codeVerifier));
  }

  /// 소셜 계정 연결을 해제합니다. 마지막 로그인 수단이면 409 `LAST_LOGIN_METHOD`입니다.
  Future<MemberIdentities> unlinkIdp(String accessToken, SocialProvider provider) =>
      _client(accessToken).auth.unlinkIdentity(provider);

  /// 토큰을 갱신합니다. 갱신 토큰은 한 번 쓰면 폐기되고 새 쌍이 옵니다.
  Future<TokenPair> refresh(String refreshToken) => _client().auth.refresh(refreshToken);

  /// 로그아웃합니다. 이 구매자의 갱신 토큰을 모두 폐기합니다. 앱은 보관한 토큰을 지웁니다.
  ///
  /// 액세스 토큰이 이미 만료됐으면(401) 서버에서 할 일이 없으므로 성공으로 봅니다.
  Future<void> signOut(String accessToken) async {
    try {
      await _client(accessToken).auth.logout();
    } on ApiError catch (error) {
      if (error.status == 401) return;
      rethrow;
    }
  }

  /// 구매자 탈퇴입니다. 계정·배송지·위시리스트·장바구니·적립금을 지우고 토큰을 모두 무효로 만듭니다. 되돌릴 수 없습니다.
  ///
  /// 진행 중인 주문이나 처리 중인 클레임이 있으면 409 `WITHDRAWAL_BLOCKED`([ApiError.details]: [WithdrawalBlockedDetails])입니다.
  Future<void> withdraw(String accessToken, WithdrawRequest body) => _client(accessToken).auth.withdraw(body);
}
