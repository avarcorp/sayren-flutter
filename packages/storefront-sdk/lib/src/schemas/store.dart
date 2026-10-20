import '../zod.dart';

/// 사업자 정보 필드(이슈 #81) — 셀러가 정하지 않았으면 null이다. 옛 서버 응답에 없으면 null로 읽는다
ZodType<String?> _businessText() => z.string().nullable().optional().withDefault(null);

/// 판매 권역 공개 값(이슈 #130)
final storefrontMarketSchema = z.object({
  'marketId': z.string(),
  'name': z.string(),
  'currency': z.string(),
  'countries': z.array(z.string()),
  'checkoutAvailable': z.boolean().optional().withDefault(true),
  'locales': z.array(z.string()).optional(),
}, StorefrontMarket.fromJson);

class StorefrontMarket extends ParsedObject {
  StorefrontMarket.fromJson(super.json) : super.fromJson();

  String get marketId => json['marketId'] as String;
  String get name => json['name'] as String;
  String get currency => json['currency'] as String;
  List<String> get countries => (json['countries'] as List).cast<String>();
  bool get checkoutAvailable => json['checkoutAvailable'] as bool;
  List<String>? get locales => (json['locales'] as List?)?.cast<String>();
}

/// 상점 공개 설정 — `GET /store`
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

class StorefrontStore extends ParsedObject {
  StorefrontStore.fromJson(super.json) : super.fromJson();

  String get storeCode => json['storeCode'] as String;
  List<StorefrontMarket> get markets => (json['markets'] as List).cast<StorefrontMarket>();

  /// `{ marketId, currency, matched, couponsEnabled }` — Node의 인라인 객체 타입이라 레코드로 둔다
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

  String get locale => json['locale'] as String;
  String get defaultLocale => json['defaultLocale'] as String;
  String get name => json['name'] as String;
  String? get logoUrl => json['logoUrl'] as String?;
  String? get customerCenterPhone => json['customerCenterPhone'] as String?;
  String? get businessHours => json['businessHours'] as String?;
  String? get businessName => json['businessName'] as String?;
  String? get representativeName => json['representativeName'] as String?;
  String? get businessNumber => json['businessNumber'] as String?;
  String? get mailOrderSalesNumber => json['mailOrderSalesNumber'] as String?;
  String? get businessAddress => json['businessAddress'] as String?;
  String? get customerCenterEmail => json['customerCenterEmail'] as String?;
  String? get privacyOfficerName => json['privacyOfficerName'] as String?;
  String? get privacyOfficerEmail => json['privacyOfficerEmail'] as String?;
  bool get guestCheckout => json['guestCheckout'] as bool;
  List<String> get loginMethods => (json['loginMethods'] as List).cast<String>();
  bool get checkoutAvailable => json['checkoutAvailable'] as bool;
  String? get checkoutMode => json['checkoutMode'] as String?;
  String? get checkoutUnavailableReason => json['checkoutUnavailableReason'] as String?;
}
