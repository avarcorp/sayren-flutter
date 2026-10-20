/// 구매자 인증입니다. `@sayren/storefront-sdk/auth`와 같은 이름·사용법입니다.
///
/// 이메일·비밀번호 로그인, 회원가입, 비회원 익명 세션, 소셜 로그인(PKCE)과 소셜 계정 연결을 다룹니다.
///
/// ```dart
/// import 'package:sayren_storefront_sdk/auth.dart';
///
/// final auth = createStorefrontAuth(StorefrontAuthOptions(baseUrl: baseUrl, storeCode: storeCode));
/// final start = await auth.idp('kakao', redirectUri: 'https://shop.example.com/auth/callback');
/// // start.url을 브라우저로 열고, 딥링크로 돌아온 code·state를 idpCallback에 넘긴다
/// ```
library;

export 'src/auth/index.dart';
export 'src/http.dart' show ApiError;
export 'src/schemas/auth.dart'
    show
        AnonymousSession,
        LoginRequest,
        MemberIdentities,
        SignupRequest,
        SocialProvider,
        TokenPair,
        WithdrawalBlockedDetails,
        WithdrawRequest;
