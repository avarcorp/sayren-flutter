/// @docImport '../client.dart';
library;

import '../zod.dart';

/// 사업자 정보 필드(이슈 #81) — 셀러가 정하지 않았으면 null이다. 옛 서버 응답에 없으면 null로 읽는다
ZodType<String?> _businessText() => z.string().nullable().optional().withDefault(null);

/// [StorefrontMarket] 스키마입니다.
final storefrontMarketSchema = z.object({
  'marketId': z.string(),
  'name': z.string(),
  'currency': z.string(),
  'countries': z.array(z.string()),
  'checkoutAvailable': z.boolean().optional().withDefault(true),
  'locales': z.array(z.string()).optional(),
}, StorefrontMarket.fromJson);

/// 판매 권역입니다. 국가 선택 메뉴에 사용합니다.
class StorefrontMarket extends ParsedObject {
  /// 검증을 마친 JSON으로 만듭니다. 서버 응답을 직접 읽을 때는 [storefrontMarketSchema]의 `parse`를 사용하십시오.
  StorefrontMarket.fromJson(super.json) : super.fromJson();

  /// 판매 권역 ID입니다.
  String get marketId => json['marketId'] as String;

  /// 판매 권역 이름입니다.
  String get name => json['name'] as String;

  /// 이 권역의 통화(ISO 4217)입니다.
  String get currency => json['currency'] as String;

  /// 이 권역의 국가(ISO 3166-1 alpha-2)입니다.
  List<String> get countries => (json['countries'] as List).cast<String>();

  /// 이 권역 통화로 주문을 받는지입니다.
  ///
  /// 상점이 주문을 받지 않거나 이 통화로 결제할 PG가 없으면 false이고, 주문서 생성이 409 `NO_PAYMENT_FOR_CURRENCY`입니다.
  bool get checkoutAvailable => json['checkoutAvailable'] as bool;

  /// 이 권역 언어(BCP 47)입니다. 첫 언어가 대표 언어이고, 언어 선택 메뉴에 사용합니다.
  ///
  /// 옛 서버 응답에는 없어 null입니다.
  List<String>? get locales => (json['locales'] as List?)?.cast<String>();
}

/// [StorefrontStore] 스키마입니다.
final storefrontStoreSchema = z.object({
  'storeCode': z.string(),
  'markets': z.array(storefrontMarketSchema).optional().withDefault(const []),
  'market': z
      .plainObject({
        'marketId': z.string(),
        'currency': z.string(),
        'matched': z.boolean(),
        'couponsEnabled': z.boolean().optional().withDefault(true),
      })
      .nullable()
      .optional()
      .withDefault(null),
  'locale': z.string().optional().withDefault('ko'),
  'defaultLocale': z.string().optional().withDefault('ko'),
  'name': z.string(),
  'logoUrl': z.string().nullable(),
  'customerCenterPhone': z.string().nullable(),
  'businessHours': z.string().nullable(),
  'businessName': _businessText(),
  'representativeName': _businessText(),
  'businessNumber': _businessText(),
  'mailOrderSalesNumber': _businessText(),
  'businessAddress': _businessText(),
  'customerCenterEmail': _businessText(),
  'privacyOfficerName': _businessText(),
  'privacyOfficerEmail': _businessText(),
  'guestCheckout': z.boolean(),
  'loginMethods': z.array(z.enum_(['password', 'kakao', 'naver', 'google'])),
  'checkoutAvailable': z.boolean().optional().withDefault(true),
  'checkoutMode': z.enum_(['LIVE', 'TEST']).nullable().optional().withDefault(null),
  'checkoutUnavailableReason':
      z.enum_(['PAYMENT_NOT_CONFIGURED', 'PAYMENT_NOT_LIVE']).nullable().optional().withDefault(null),
}, StorefrontStore.fromJson);

/// 상점 공개 설정입니다. 스토어프론트가 화면을 그릴 때 읽는 값만 담습니다.
///
/// `client.store.get()`으로 가져옵니다.
class StorefrontStore extends ParsedObject {
  /// 검증을 마친 JSON으로 만듭니다. 서버 응답을 직접 읽을 때는 [storefrontStoreSchema]의 `parse`를 사용하십시오.
  StorefrontStore.fromJson(super.json) : super.fromJson();

  /// 상점 코드입니다.
  String get storeCode => json['storeCode'] as String;

  /// 판매 권역 목록입니다. 국가 선택 메뉴에 사용합니다. 판매 국가는 모든 권역 국가의 합입니다.
  List<StorefrontMarket> get markets => (json['markets'] as List).cast<StorefrontMarket>();

  /// 이 요청의 판매 권역입니다. 금액은 이 통화로 표시합니다. 옛 서버 응답은 null입니다.
  ///
  /// - `marketId`: 판매 권역 ID
  /// - `currency`: 통화
  /// - `matched`: 요청 국가·도메인이 권역에 맞았는지. false면 기본 권역 가격으로 둘러보기만 하고 결제할 수 없습니다.
  /// - `couponsEnabled`: 이 권역에서 쿠폰을 사용할 수 있는지. false면 쿠폰 적용이 409 `COUPONS_UNAVAILABLE_IN_MARKET`입니다.
  ({String marketId, String currency, bool matched, bool couponsEnabled})? get market {
    final m = json['market'] as Map<String, Object?>?;
    if (m == null) return null;
    return (
      marketId: m['marketId'] as String,
      currency: m['currency'] as String,
      matched: m['matched'] as bool,
      couponsEnabled: m['couponsEnabled'] as bool,
    );
  }

  /// 이 요청의 언어입니다.
  ///
  /// [StorefrontClientOptions.locale]을 권역 언어에 맞춰 고른 값이고, 맞는 언어가 없으면 권역 대표 언어입니다.
  /// 카테고리 이름 등 번역 값이 이 언어입니다.
  String get locale => json['locale'] as String;

  /// 상점 기본 언어입니다. 번역이 없는 값은 이 언어로 보입니다.
  String get defaultLocale => json['defaultLocale'] as String;

  /// 상점 이름입니다.
  String get name => json['name'] as String;

  /// 로고 이미지 주소입니다. 없으면 null입니다.
  String? get logoUrl => json['logoUrl'] as String?;

  /// 고객센터 전화번호입니다. 없으면 null입니다.
  String? get customerCenterPhone => json['customerCenterPhone'] as String?;

  /// 고객센터 운영 시간입니다. 없으면 null입니다.
  String? get businessHours => json['businessHours'] as String?;

  /// 상호(사업자등록증의 상호)입니다. 상점 이름([name])과 다를 수 있습니다. 정하지 않았으면 null입니다.
  String? get businessName => json['businessName'] as String?;

  /// 대표자명입니다. 정하지 않았으면 null입니다.
  String? get representativeName => json['representativeName'] as String?;

  /// 사업자등록번호입니다. 숫자 10자리(하이픈 없음)이고, 표시할 때 `123-45-67890`으로 끊으십시오. 정하지 않았으면 null입니다.
  String? get businessNumber => json['businessNumber'] as String?;

  /// 통신판매업 신고번호입니다. 셀러가 입력한 그대로입니다. 정하지 않았으면 null입니다.
  String? get mailOrderSalesNumber => json['mailOrderSalesNumber'] as String?;

  /// 사업장 주소입니다. 정하지 않았으면 null입니다.
  String? get businessAddress => json['businessAddress'] as String?;

  /// 고객센터 이메일입니다. 정하지 않았으면 null입니다.
  String? get customerCenterEmail => json['customerCenterEmail'] as String?;

  /// 개인정보 보호책임자 성명입니다. 정하지 않았으면 null입니다.
  String? get privacyOfficerName => json['privacyOfficerName'] as String?;

  /// 개인정보 보호책임자 이메일입니다. 정하지 않았으면 null입니다.
  String? get privacyOfficerEmail => json['privacyOfficerEmail'] as String?;

  /// 비회원 주문을 허용하는지입니다.
  ///
  /// false면 로그인하지 않은 구매자의 주문서 생성·결제 요청이 403 `GUEST_CHECKOUT_DISABLED`입니다.
  /// 장바구니 담기는 됩니다. 주문 버튼을 로그인 안내로 바꾸십시오.
  bool get guestCheckout => json['guestCheckout'] as bool;

  /// 켜진 로그인 방법입니다. 이 순서대로 버튼을 그리십시오.
  ///
  /// 값은 `password`·`kakao`·`naver`·`google`입니다. `password`가 없으면 이메일·비밀번호 가입과 로그인이 꺼져 있습니다.
  List<String> get loginMethods => (json['loginMethods'] as List).cast<String>();

  /// 지금 주문(결제)을 받을 수 있는지입니다.
  ///
  /// false면 결제 요청이 409 `PAYMENT_NOT_CONFIGURED`이므로 장바구니·주문 버튼을 숨기거나 문의 안내로 바꾸십시오.
  bool get checkoutAvailable => json['checkoutAvailable'] as bool;

  /// 주문을 받을 때의 결제 환경입니다.
  ///
  /// 값은 `LIVE`·`TEST`입니다. `TEST`면 테스트 결제라 돈이 오가지 않습니다. 주문을 받지 않으면 null입니다.
  String? get checkoutMode => json['checkoutMode'] as String?;

  /// 주문을 받지 않는 사유입니다. 주문을 받으면 null입니다.
  ///
  /// - `PAYMENT_NOT_CONFIGURED`: 사용 중인 결제 수단이 없습니다.
  /// - `PAYMENT_NOT_LIVE`: 공개한 쇼핑몰인데 실결제가 아직 열리지 않았습니다.
  String? get checkoutUnavailableReason => json['checkoutUnavailableReason'] as String?;
}
