/// sayren 스토어프론트 API SDK입니다.
///
/// 구매자가 쓰는 앱에서 상점 정보, 카탈로그, 장바구니, 주문, 회원 기능을 호출합니다.
/// 이름과 사용법은 Node SDK(`@sayren/storefront-sdk`)와 같습니다.
///
/// ## 시작하기
///
/// ```dart
/// import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';
///
/// final client = createStorefrontClient(StorefrontClientOptions(
///   baseUrl: 'https://api.sayren.io/storefront/v1',
///   storeCode: 'my-store',
/// ));
///
/// final store = await client.store.get();
/// final categories = await client.catalog.listCategories();
/// ```
///
/// ## 오류 처리
///
/// 서버 오류는 [ApiError], 계약에 맞지 않는 값은 [ZodError]로 던집니다.
///
/// ```dart
/// try {
///   await client.member.updateConsents(ConsentUpdateRequest(marketing: false));
/// } on ApiError catch (e) {
///   if (e.code == 'UNAUTHORIZED') goToLogin();
/// }
/// ```
///
/// ## 스키마
///
/// 응답 모델마다 같은 이름의 스키마 상수(예: [storefrontStoreSchema])가 있습니다.
/// 저장해 둔 JSON을 다시 읽을 때 `parse`·`safeParse`로 검증하십시오.
library;

export 'src/analytics-ids.dart';
export 'src/client.dart';
export 'src/http.dart' show ApiError, Fetch, Query, TokenSource, buildQuery;
export 'src/session.dart';
export 'src/schemas/analytics.dart';
export 'src/schemas/auth.dart';
export 'src/schemas/cart.dart';
export 'src/schemas/catalog.dart';
export 'src/schemas/checkout.dart';
export 'src/schemas/claim.dart';
export 'src/schemas/commerce-flow.dart';
export 'src/schemas/commerce-number.dart';
export 'src/schemas/common.dart';
export 'src/schemas/consent.dart';
export 'src/schemas/coupon.dart';
export 'src/schemas/currency.dart';
export 'src/schemas/customer-inquiry.dart';
export 'src/schemas/fulfillment.dart';
export 'src/schemas/inquiry.dart';
export 'src/schemas/member.dart';
export 'src/schemas/order.dart';
export 'src/schemas/points.dart';
export 'src/schemas/product-options.dart';
export 'src/schemas/review.dart';
export 'src/schemas/stay.dart';
export 'src/schemas/store.dart';
export 'src/zod.dart' show Nullable, SafeParseResult, ZodArray, ZodEnum, ZodError, ZodIssue, ZodObject, ZodType;
