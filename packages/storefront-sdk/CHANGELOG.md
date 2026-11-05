## 0.2.0

- `@sayren/storefront-sdk` 0.40.0과 같은 API로 최신화했습니다. 엔드포인트는 84개입니다(새로 `auth.requestPasswordReset`, `catalog.listSitemapProducts`·`getCouponBenefit`, `checkout.get`·`bestCoupons`, `me.registerCoupon`).
- 서버 엔트리포인트 `server.dart`(Node `@sayren/storefront-sdk/server`)를 더했습니다. `buyerTokenOf`는 요청 헤더 맵을 받습니다.
- `baseUrl`을 생략하면 운영 주소(`SAYREN_STOREFRONT_API_BASE_URL`)를 사용합니다(클라이언트·세션·인증·분석).
- `StorefrontAuth.requestPasswordReset`, 결제 `StartOptions.orderPassword`를 더했습니다.
- 파괴적 변경: `PaymentResultCompleted`에 `orderNo`(숫자 주문번호)가 생겨 생성자 인자가 늘었습니다.
- 가격 표시·옵션 선택(`priceViewOf`·`findVariant`·`optionChoicesOf`), 배송 안내(`deliveryNoticeOf`), 판매자 정보(`sellerInfoOf`·`formatBusinessNumber`) 함수를 더했습니다.

## 0.1.0

- 첫 공개 버전입니다. `@sayren/storefront-sdk` 0.24.0과 같은 API를 제공합니다.
- 스토어프론트 클라이언트(`createStorefrontClient`), 세션(`createStorefrontSession`), 스키마·모델
- 소셜 로그인(`auth.dart`), 결제(`payments.dart`, WebView 결제창), 방문 분석(`analytics.dart`)
