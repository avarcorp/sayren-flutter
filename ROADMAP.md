# sayren-flutter Roadmap

sayren 공개 API를 Flutter(Dart)에서 쓰는 SDK다. 목표는 Node SDK(`@sayren/storefront-sdk`·`@sayren/store-sdk`)와 같은 개발 경험이다.
같은 이름의 팩토리로 클라이언트를 만들고, 같은 네임스페이스·메서드 이름으로 같은 엔드포인트를 부르고, 같은 형태의 `ApiError`로 실패를 받는다.

- 기준 소스: `avarcorp/sayren` `490c9e3`, `@sayren/storefront-sdk` 0.24.0 · `@sayren/store-sdk` 0.36.0
- API 계약의 원천은 sayren 구현 코드다. 이 문서의 목록은 Node SDK `client.ts`에서 뽑았다. Node SDK에 메서드가 추가되면 여기에도 추가한다.

## 패키지 구성

| Node 패키지 | Dart 패키지 | 라이브러리(엔트리포인트) |
|---|---|---|
| `@sayren/storefront-sdk` | `sayren_storefront_sdk` | `sayren_storefront_sdk.dart` |
| `@sayren/storefront-sdk/auth` | 〃 | `auth.dart` |
| `@sayren/storefront-sdk/payments` | 〃 | `payments.dart` |
| `@sayren/storefront-sdk/analytics` | 〃 | `analytics.dart` |
| `@sayren/store-sdk` | `sayren_store_sdk` | `sayren_store_sdk.dart` |
| `@sayren/store-sdk/server` | 제공하지 않음 | 웹훅 서명 검증·`delegateMember`는 시크릿을 다룬다. 앱 번들에 넣지 않는다 |

Dart pub workspace(`packages/*`)로 두 패키지를 한 저장소에서 관리한다. 순수 Dart 코어(`http` 패키지)로 만들고 Flutter 의존은 결제·저장소 어댑터처럼 플랫폼이 필요한 곳에만 둔다.

## 개발 경험 대응

Node:

```ts
const session = createStorefrontSession({ baseUrl, storeCode, storage });
const client = createStorefrontClient({ baseUrl, storeCode, session, onCartToken });

const page = await client.catalog.searchProducts({ keyword: "셔츠", size: 20 });
try {
  await client.myOrders.get(orderId);
} catch (e) {
  if (e instanceof ApiError && e.code === "ORDER_NOT_FOUND") { /* … */ }
}
```

Dart:

```dart
final session = createStorefrontSession(baseUrl: baseUrl, storeCode: storeCode, storage: storage);
final client = createStorefrontClient(baseUrl: baseUrl, storeCode: storeCode, session: session, onCartToken: onCartToken);

final page = await client.catalog.searchProducts(const ProductSearchParams(keyword: '셔츠', size: 20));
try {
  await client.myOrders.get(orderId);
} on ApiError catch (e) {
  if (e.code == 'ORDER_NOT_FOUND') { /* … */ }
}
```

| 항목 | Node | Dart |
|---|---|---|
| 클라이언트 생성 | `createStorefrontClient(options)` | `createStorefrontClient(...)` 네임드 인자 |
| 네임스페이스·메서드 이름 | `client.catalog.searchProducts` | 같은 이름(camelCase 그대로) |
| 동적 값(`TokenSource`) | `string \| () => string` | `TokenSource.value('…')` · `TokenSource.of(() => …)` |
| 요청·응답 스키마 | zod 스키마 + `z.infer` 타입 | 불변 모델 클래스 + `fromJson`·`toJson`. 요청 본문은 보내기 전에 같은 규칙으로 검증한다 |
| 쿼리 파라미터 | `{ page, size, … }` 객체 | `PageParams` 등 파라미터 클래스 |
| 응답 엔벨로프 | `data`만 돌려준다 | 같다 |
| 오류 | `ApiError(status, code, message, traceId, body, details, docs)` | 같은 필드의 `ApiError` 예외 |
| 204 응답 | `Promise<void>` | `Future<void>` |
| 세션 저장소 | `SessionStorage { get, set, remove }` 앱 소유 | 같은 인터페이스. Flutter용 보안 저장소 어댑터를 함께 둔다 |
| 세션 키 | `STOREFRONT_SESSION_KEYS`·`STORE_SESSION_KEYS` | 같은 키 문자열 |
| 401 처리 | refresh 1회 후 재시도, 실패하면 `session.clear()` | 같다(single-flight) |
| 변경 구독 | `session.subscribe(cb)` | `session.subscribe(cb)` + `Stream` |
| 비회원 장바구니 토큰 | `X-Cart-Token` 수신 시 `onCartToken` | 같다 |

## 단계

### Phase 0. 기반

- [ ] 저장소 구성: pub workspace, `analysis_options.yaml`, 라이선스·README
- [ ] http 코어: 엔벨로프 해제, `ApiError`(`toApiError`), `path` 인코딩, `buildQuery`, `TokenSource`, 401 refresh 재시도
- [ ] 공통 모델: `Page<T>`, `PageParams`, 날짜·금액 표현
- [ ] 테스트 하네스: 가짜 HTTP 클라이언트로 메서드별 경로·헤더·본문 단언
- [ ] 계약 대조: Node SDK `client.ts`의 메서드 목록과 Dart 메서드 목록이 같은지 확인하는 스크립트

### Phase 1. 스토어프론트 클라이언트 (`sayren_storefront_sdk`)

구매자 앱이 쓰는 표면이라 먼저 만든다. 엔드포인트 78개.

- [ ] `createStorefrontClient` 옵션: `baseUrl`, `storeCode`, `accessToken`, `auth.accessToken`, `cartToken`, `visitorId`, `sessionId`, `country`, `host`, `locale`, `onCartToken`, `session`, `httpClient`(Node의 `fetch`)
- [ ] 요청 헤더: `X-Store-Code`, `Authorization`, `X-Cart-Token`, 방문 분석 헤더, `X-Buyer-Country`, `X-Storefront-Host`, `Accept-Language`
- [ ] 최상위 멤버: `accessToken`, `refreshToken`, `userinfo()`
- [ ] `createStorefrontSession`: `login`, `signup`, `refresh`, `accessToken`, `refreshToken`, `userinfo`, `clear`, `subscribe`

엔드포인트 목록(경로는 `/storefront/v1` 기준):

#### `auth` (12)

- [ ] `auth.anonymous` · `POST /storefront/v1/auth/anonymous`
- [ ] `auth.signup` · `POST /storefront/v1/auth/signup`
- [ ] `auth.login` · `POST /storefront/v1/auth/login`
- [ ] `auth.refresh` · `POST /storefront/v1/auth/token/refresh`
- [ ] `auth.logout` · `POST /storefront/v1/auth/logout`
- [ ] `auth.idpAuthorize` · `POST /storefront/v1/auth/idp/{provider}/authorize`
- [ ] `auth.idpToken` · `POST /storefront/v1/auth/idp/token`
- [ ] `auth.withdraw` · `POST /storefront/v1/auth/withdraw`
- [ ] `auth.identities` · `GET /storefront/v1/me/identities`
- [ ] `auth.linkIdentityAuthorize` · `POST /storefront/v1/me/identities/{provider}/authorize`
- [ ] `auth.linkIdentity` · `POST /storefront/v1/me/identities/{provider}`
- [ ] `auth.unlinkIdentity` · `DELETE /storefront/v1/me/identities/{provider}`

#### `store` (1)

- [ ] `store.get` · `GET /storefront/v1/store`

#### `catalog` (12)

- [ ] `catalog.listCategories` · `GET /storefront/v1/categories`
- [ ] `catalog.getPointPolicy` · `GET /storefront/v1/point-policy`
- [ ] `catalog.searchProducts` · `GET /storefront/v1/products`
- [ ] `catalog.getProduct` · `GET /storefront/v1/products/{productId}`
- [ ] `catalog.listProductReviews` · `GET /storefront/v1/products/{productId}/reviews`
- [ ] `catalog.listProductInquiries` · `GET /storefront/v1/products/{productId}/inquiries`
- [ ] `catalog.getProductCalendar` · `GET /storefront/v1/products/{productId}/calendar`
- [ ] `catalog.createInquiry` · `POST /storefront/v1/products/{productId}/inquiries`
- [ ] `catalog.listCollections` · `GET /storefront/v1/collections`
- [ ] `catalog.listCoupons` · `GET /storefront/v1/coupons`
- [ ] `catalog.getCollection` · `GET /storefront/v1/collections/{slug}`
- [ ] `catalog.listCollectionProducts` · `GET /storefront/v1/collections/{slug}/products`

#### `pickupLocations` (1)

- [ ] `pickupLocations.list` · `GET /storefront/v1/pickup-locations`

#### `cart` (5)

- [ ] `cart.get` · `GET /storefront/v1/cart`
- [ ] `cart.addItem` · `POST /storefront/v1/cart/items`
- [ ] `cart.updateItem` · `PATCH /storefront/v1/cart/items/{cartItemId}`
- [ ] `cart.removeItem` · `DELETE /storefront/v1/cart/items/{cartItemId}`
- [ ] `cart.createInputImageUpload` · `POST /storefront/v1/uploads/order-inputs`

#### `checkout` (5)

- [ ] `checkout.create` · `POST /storefront/v1/checkout`
- [ ] `checkout.quoteDelivery` · `POST /storefront/v1/checkout/{checkoutId}/delivery-quote`
- [ ] `checkout.startPayment` · `POST /storefront/v1/checkout/{checkoutId}/payment`
- [ ] `checkout.pricing` · `POST /storefront/v1/checkout/{checkoutId}/pricing`
- [ ] `checkout.applicableCoupons` · `GET /storefront/v1/checkout/{checkoutId}/coupons`

#### `payments` (4)

- [ ] `payments.getStatus` · `GET /storefront/v1/payments/{paymentId}`
- [ ] `payments.retry` · `POST /storefront/v1/payments/{paymentId}/attempts`
- [ ] `payments.confirm` · `POST /storefront/v1/payments/{paymentId}/confirm`
- [ ] `payments.reportFailure` · `POST /storefront/v1/payments/{paymentId}/failure`

#### `myOrders` (9)

- [ ] `myOrders.list` · `GET /storefront/v1/me/orders`
- [ ] `myOrders.get` · `GET /storefront/v1/me/orders/{orderId}`
- [ ] `myOrders.getGuestOrder` · `POST /storefront/v1/guest/orders/{orderId}`
- [ ] `myOrders.getDelivery` · `GET /storefront/v1/me/order-items/{orderItemId}/delivery`
- [ ] `myOrders.decidePurchase` · `POST /storefront/v1/me/order-items/{orderItemId}/purchase-decision`
- [ ] `myOrders.act` · `POST /storefront/v1/me/order-items/{orderItemId}/actions/{key}`
- [ ] `myOrders.guestAct` · `POST /storefront/v1/guest/orders/{orderId}/items/{orderItemId}/actions/{key}`
- [ ] `myOrders.actOnOrder` · `POST /storefront/v1/me/orders/{orderId}/actions/{key}`
- [ ] `myOrders.guestActOnOrder` · `POST /storefront/v1/guest/orders/{orderId}/actions/{key}`

#### `myClaims` (4)

- [ ] `myClaims.create` · `POST /storefront/v1/me/order-items/{orderItemId}/claims`
- [ ] `myClaims.preview` · `POST /storefront/v1/me/order-items/{orderItemId}/claims/preview`
- [ ] `myClaims.list` · `GET /storefront/v1/me/claims`
- [ ] `myClaims.withdraw` · `POST /storefront/v1/me/claims/{claimId}/withdraw`

#### `member` (13)

- [ ] `member.me` · `GET /storefront/v1/me`
- [ ] `member.getPoints` · `GET /storefront/v1/me/points`
- [ ] `member.listPointHistory` · `GET /storefront/v1/me/points/history`
- [ ] `member.updateMe` · `PATCH /storefront/v1/me`
- [ ] `member.consents` · `GET /storefront/v1/me/consents`
- [ ] `member.updateConsents` · `POST /storefront/v1/me/consents`
- [ ] `member.listAddresses` · `GET /storefront/v1/me/addresses`
- [ ] `member.createAddress` · `POST /storefront/v1/me/addresses`
- [ ] `member.updateAddress` · `PUT /storefront/v1/me/addresses/{addressId}`
- [ ] `member.deleteAddress` · `DELETE /storefront/v1/me/addresses/{addressId}`
- [ ] `member.listWishlist` · `GET /storefront/v1/me/wishlist`
- [ ] `member.addWishlist` · `POST /storefront/v1/me/wishlist`
- [ ] `member.removeWishlist` · `DELETE /storefront/v1/me/wishlist/{productId}`

#### `reviews` (6)

- [ ] `reviews.listMine` · `GET /storefront/v1/me/reviews`
- [ ] `reviews.listWritable` · `GET /storefront/v1/me/reviews/writable`
- [ ] `reviews.createImageUpload` · `POST /storefront/v1/me/uploads`
- [ ] `reviews.create` · `POST /storefront/v1/me/order-items/{orderItemId}/review`
- [ ] `reviews.update` · `PUT /storefront/v1/me/reviews/{reviewId}`
- [ ] `reviews.remove` · `DELETE /storefront/v1/me/reviews/{reviewId}`

#### `inquiries` (1)

- [ ] `inquiries.listMine` · `GET /storefront/v1/me/inquiries`

#### `me` (2)

- [ ] `me.coupons` · `GET /storefront/v1/me/coupons`
- [ ] `me.downloadCoupon` · `POST /storefront/v1/coupons/{couponId}/download`

#### `me.customerInquiries` (3)

- [ ] `me.customerInquiries.create` · `POST /storefront/v1/me/customer-inquiries`
- [ ] `me.customerInquiries.list` · `GET /storefront/v1/me/customer-inquiries`
- [ ] `me.customerInquiries.get` · `GET /storefront/v1/me/customer-inquiries/{inquiryId}`

### Phase 2. 스토어프론트 하위 모듈

#### `auth.dart` (`createStorefrontAuth`)

- [ ] `anonymous` · `session` · `signUp` · `refresh` · `withdraw`
- [ ] `idp` · `idpCallback` (PKCE·state 생성과 대조, `IdpCallbackError`)
- [ ] `identities` · `linkIdp` · `linkIdpCallback` · `unlinkIdp`
- [ ] 소셜 로그인 복귀: 브라우저 리디렉트 대신 앱 딥링크(커스텀 스킴·유니버설 링크)로 code·state를 받는다

#### `payments.dart` (`createPayments`)

- [ ] `start` · `retry` · `open` · `result` · `getStatus`
- [ ] `PaymentResult`(`COMPLETED`·`FAILED`·`CANCELED`·`PROCESSING`·`INVALID`), `paymentResultOf`, `readPaymentReturn`
- [ ] 결제창 실행: 웹의 팝업·리디렉트 대신 인앱 WebView로 `payUrl`을 열고, 복귀 주소 진입을 가로채 `result`로 넘긴다
- [ ] 결과 `PROCESSING`이면 `expiresAt`까지 `getStatus` 폴링
- [ ] `prepareWindow`(Node에서 deprecated)는 만들지 않는다

#### `analytics.dart` (`createAnalytics`)

- [ ] `track` · `page` · `setConsent` · `ids` · `flush` · `destroy`
- [ ] 쿠키(`sy_vid`·`sy_sid`) 대신 앱 저장소에 방문자·세션 ID를 둔다. `ids()` 값을 `createStorefrontClient(visitorId:, sessionId:)`에 넘기는 흐름은 같다
- [ ] 페이지뷰: 자동 수집 대신 라우트 관찰자(`NavigatorObserver`)로 `page()`를 부른다
- [ ] `analyticsIdsFromCookie`는 SSR 전용이라 만들지 않는다

### Phase 3. 관리 클라이언트 (`sayren_store_sdk`)

셀러용 관리 앱에서 계정 토큰(accounts OAuth)으로 쓴다. 엔드포인트 311개. 앱 번들에 client_secret·PAT를 넣지 않는다.

- [ ] `createStoreClient` 옵션: `baseUrl`, `accessToken`, `storeId`(`X-Store-Id`), `refresh`, `onUnauthorized`, `session`, `httpClient`
- [ ] 계정 API(`/me/*`)와 상점 API(`X-Store-Id`)의 헤더 분리
- [ ] `ApprovalPendingError`(`APPROVAL_REQUIRED`), `idempotency-key` 헤더
- [ ] 최상위 멤버: `accessToken`, `refreshToken`, `authorize`, `userinfo`
- [ ] `createStoreSession`: `getToken`, `setTokens`, `refresh`, `clear`, `logout`(RFC 7009 폐기), `subscribe`, `authorize`, `handleCallback`, `userinfo`
- [ ] OAuth 헬퍼: `createPkcePair`, `buildAuthorizeUrl`, `exchangeAuthorizationCode`, `refreshUserToken`. 콜백은 앱 딥링크로 받는다
- [ ] `uploads.upload`: Node의 `Blob` 대신 `File`·바이트를 받는다

엔드포인트 목록(경로는 `/v1` 기준):

#### `auth` (2)

- [ ] `auth.listMyStores` · `GET /v1/me/stores`
- [ ] `auth.me` · `GET /v1/me`

#### `uploads` (2)

- [ ] `uploads.create` · `POST /v1/uploads`
- [ ] `uploads.upload` · `POST /v1/uploads` + `PUT {uploadUrl}` (자리 발급과 바이트 업로드 합성, 용도별 확장자·크기 선검사)

#### `products` (15)

- [ ] `products.list` · `GET /v1/products`
- [ ] `products.get` · `GET /v1/products/{productId}`
- [ ] `products.create` · `POST /v1/products`
- [ ] `products.update` · `PUT /v1/products/{productId}`
- [ ] `products.patch` · `PATCH /v1/products/{productId}`
- [ ] `products.remove` · `DELETE /v1/products/{productId}`
- [ ] `products.bulkUpdateStatus` · `POST /v1/products/bulk/status`
- [ ] `products.getOptionModel` · `GET /v1/products/{productId}/options`
- [ ] `products.replaceOptionModel` · `PUT /v1/products/{productId}/options`
- [ ] `products.updateVariantStock` · `PATCH /v1/products/{productId}/variants/{variantId}/stock`
- [ ] `products.getDiscount` · `GET /v1/products/{productId}/discount`
- [ ] `products.setDiscount` · `PUT /v1/products/{productId}/discount`
- [ ] `products.removeDiscount` · `DELETE /v1/products/{productId}/discount`
- [ ] `products.getCalendar` · `GET /v1/products/{productId}/calendar`
- [ ] `products.setCalendar` · `PUT /v1/products/{productId}/calendar`

#### `products.localizations` (3)

- [ ] `products.localizations.list` · `GET /v1/products/{productId}/localizations`
- [ ] `products.localizations.put` · `PUT /v1/products/{productId}/localizations/{locale}`
- [ ] `products.localizations.remove` · `DELETE /v1/products/{productId}/localizations/{locale}`

#### `savedOptionSets` (6)

- [ ] `savedOptionSets.list` · `GET /v1/saved-option-sets`
- [ ] `savedOptionSets.get` · `GET /v1/saved-option-sets/{optionSetId}`
- [ ] `savedOptionSets.create` · `POST /v1/saved-option-sets`
- [ ] `savedOptionSets.update` · `PUT /v1/saved-option-sets/{optionSetId}`
- [ ] `savedOptionSets.remove` · `DELETE /v1/saved-option-sets/{optionSetId}`
- [ ] `savedOptionSets.saveFromProduct` · `POST /v1/saved-option-sets/from-product`

#### `savedOptionSets.localizations` (3)

- [ ] `savedOptionSets.localizations.list` · `GET /v1/saved-option-sets/{optionSetId}/localizations`
- [ ] `savedOptionSets.localizations.put` · `PUT /v1/saved-option-sets/{optionSetId}/localizations/{locale}`
- [ ] `savedOptionSets.localizations.remove` · `DELETE /v1/saved-option-sets/{optionSetId}/localizations/{locale}`

#### `infoSchemas` (1)

- [ ] `infoSchemas.list` · `GET /v1/info-schemas`

#### `codes` (1)

- [ ] `codes.list` · `GET /v1/codes/{setId}`

#### `infoSections` (5)

- [ ] `infoSections.list` · `GET /v1/info-sections`
- [ ] `infoSections.get` · `GET /v1/info-sections/{infoSectionId}`
- [ ] `infoSections.create` · `POST /v1/info-sections`
- [ ] `infoSections.update` · `PUT /v1/info-sections/{infoSectionId}`
- [ ] `infoSections.remove` · `DELETE /v1/info-sections/{infoSectionId}`

#### `infoSections.localizations` (3)

- [ ] `infoSections.localizations.list` · `GET /v1/info-sections/{infoSectionId}/localizations`
- [ ] `infoSections.localizations.put` · `PUT /v1/info-sections/{infoSectionId}/localizations/{locale}`
- [ ] `infoSections.localizations.remove` · `DELETE /v1/info-sections/{infoSectionId}/localizations/{locale}`

#### `collections` (10)

- [ ] `collections.list` · `GET /v1/collections`
- [ ] `collections.get` · `GET /v1/collections/{collectionId}`
- [ ] `collections.create` · `POST /v1/collections`
- [ ] `collections.update` · `PATCH /v1/collections/{collectionId}`
- [ ] `collections.remove` · `DELETE /v1/collections/{collectionId}`
- [ ] `collections.listProducts` · `GET /v1/collections/{collectionId}/products`
- [ ] `collections.replaceProducts` · `PUT /v1/collections/{collectionId}/products`
- [ ] `collections.addProducts` · `POST /v1/collections/{collectionId}/products`
- [ ] `collections.removeProduct` · `DELETE /v1/collections/{collectionId}/products/{productId}`
- [ ] `collections.preview` · `POST /v1/collections/preview`

#### `collections.localizations` (3)

- [ ] `collections.localizations.list` · `GET /v1/collections/{collectionId}/localizations`
- [ ] `collections.localizations.put` · `PUT /v1/collections/{collectionId}/localizations/{locale}`
- [ ] `collections.localizations.remove` · `DELETE /v1/collections/{collectionId}/localizations/{locale}`

#### `categories` (8)

- [ ] `categories.list` · `GET /v1/categories`
- [ ] `categories.tree` · `GET /v1/categories`
- [ ] `categories.search` · `GET /v1/categories`
- [ ] `categories.get` · `GET /v1/categories/{categoryId}`
- [ ] `categories.listAttributes` · `GET /v1/categories/{categoryId}/attributes`
- [ ] `categories.create` · `POST /v1/categories`
- [ ] `categories.update` · `PATCH /v1/categories/{categoryId}`
- [ ] `categories.remove` · `DELETE /v1/categories/{categoryId}`

#### `categories.localizations` (3)

- [ ] `categories.localizations.list` · `GET /v1/categories/{categoryId}/localizations`
- [ ] `categories.localizations.put` · `PUT /v1/categories/{categoryId}/localizations/{locale}`
- [ ] `categories.localizations.remove` · `DELETE /v1/categories/{categoryId}/localizations/{locale}`

#### `orders` (4)

- [ ] `orders.list` · `GET /v1/orders`
- [ ] `orders.get` · `GET /v1/orders/{orderId}`
- [ ] `orders.reissueCashReceipt` · `POST /v1/orders/{orderId}/cash-receipt/reissue`
- [ ] `orders.act` · `POST /v1/orders/{orderId}/actions/{key}`

#### `orderItems` (23)

- [ ] `orderItems.listChanged` · `GET /v1/order-items`
- [ ] `orderItems.confirm` · `POST /v1/order-items/{orderItemId}/confirm`
- [ ] `orderItems.confirmBulk` · `POST /v1/order-items/confirm`
- [ ] `orderItems.hold` · `POST /v1/order-items/{orderItemId}/hold`
- [ ] `orderItems.releaseHold` · `DELETE /v1/order-items/{orderItemId}/hold`
- [ ] `orderItems.cancelPreview` · `GET /v1/order-items/{orderItemId}/cancel-preview`
- [ ] `orderItems.cancelBySeller` · `POST /v1/order-items/{orderItemId}/cancel`
- [ ] `orderItems.updateMemo` · `PUT /v1/order-items/{orderItemId}/memo`
- [ ] `orderItems.requestPurchaseDecision` · `POST /v1/order-items/{orderItemId}/purchase-decision/request`
- [ ] `orderItems.extendPurchaseDecision` · `POST /v1/order-items/{orderItemId}/purchase-decision/extend`
- [ ] `orderItems.dispatch` · `POST /v1/order-items/{orderItemId}/dispatch`
- [ ] `orderItems.dispatchBulk` · `POST /v1/order-items/dispatch`
- [ ] `orderItems.updateTracking` · `PUT /v1/order-items/{orderItemId}/dispatch/tracking`
- [ ] `orderItems.markDelivered` · `POST /v1/order-items/{orderItemId}/delivered`
- [ ] `orderItems.markDeliveredBulk` · `POST /v1/order-items/delivered`
- [ ] `orderItems.fulfill` · `POST /v1/order-items/{orderItemId}/fulfill`
- [ ] `orderItems.fulfillBulk` · `POST /v1/order-items/fulfill`
- [ ] `orderItems.getDelivery` · `GET /v1/order-items/{orderItemId}/delivery`
- [ ] `orderItems.getFlow` · `GET /v1/order-items/{orderItemId}/flow`
- [ ] `orderItems.act` · `POST /v1/order-items/{orderItemId}/actions/{key}`
- [ ] `orderItems.emitEvent` · `POST /v1/order-items/{orderItemId}/events/{key}`
- [ ] `orderItems.moveFlow` · `POST /v1/order-items/{orderItemId}/flow/move`
- [ ] `orderItems.flowRuns` · `GET /v1/order-items/{orderItemId}/flow/runs`

#### `flowRuns` (1)

- [ ] `flowRuns.get` · `GET /v1/flow-runs/{runId}`

#### `commerceFlows` (17)

- [ ] `commerceFlows.presets` · `GET /v1/flow-presets`
- [ ] `commerceFlows.preset` · `GET /v1/flow-presets/{key}`
- [ ] `commerceFlows.list` · `GET /v1/commerce-flows`
- [ ] `commerceFlows.get` · `GET /v1/commerce-flows/{flowId}`
- [ ] `commerceFlows.create` · `POST /v1/commerce-flows`
- [ ] `commerceFlows.saveDraft` · `PUT /v1/commerce-flows/{flowId}/draft`
- [ ] `commerceFlows.check` · `POST /v1/commerce-flows/{flowId}/draft/check`
- [ ] `commerceFlows.publish` · `POST /v1/commerce-flows/{flowId}/draft/publish`
- [ ] `commerceFlows.forProduct` · `GET /v1/products/{productId}/flow`
- [ ] `commerceFlows.secrets` · `GET /v1/commerce-flows/secrets`
- [ ] `commerceFlows.saveSecret` · `PUT /v1/commerce-flows/secrets/{name}`
- [ ] `commerceFlows.removeSecret` · `DELETE /v1/commerce-flows/secrets/{name}`
- [ ] `commerceFlows.getVersion` · `GET /v1/commerce-flows/{flowId}/versions/{version}`
- [ ] `commerceFlows.migrateVersion` · `POST /v1/commerce-flows/{flowId}/versions/{version}/migrate`
- [ ] `commerceFlows.simulate` · `POST /v1/commerce-flows/{flowId}/draft/simulate`
- [ ] `commerceFlows.replay` · `POST /v1/commerce-flows/{flowId}/draft/replay`
- [ ] `commerceFlows.nodeTypes` · `GET /v1/flow-node-types`

#### `carriers` (1)

- [ ] `carriers.list` · `GET /v1/carriers`

#### `claims` (10)

- [ ] `claims.list` · `GET /v1/claims`
- [ ] `claims.get` · `GET /v1/claims/{claimId}`
- [ ] `claims.approve` · `POST /v1/claims/{claimId}/approve`
- [ ] `claims.reject` · `POST /v1/claims/{claimId}/reject`
- [ ] `claims.registerCollect` · `POST /v1/claims/{claimId}/collect`
- [ ] `claims.completeCollect` · `POST /v1/claims/{claimId}/collect/complete`
- [ ] `claims.registerRedelivery` · `POST /v1/claims/{claimId}/redelivery`
- [ ] `claims.hold` · `POST /v1/claims/{claimId}/hold`
- [ ] `claims.releaseHold` · `DELETE /v1/claims/{claimId}/hold`
- [ ] `claims.completeExchange` · `POST /v1/claims/{claimId}/complete-exchange`

#### `inquiries` (4)

- [ ] `inquiries.list` · `GET /v1/inquiries`
- [ ] `inquiries.get` · `GET /v1/inquiries/{inquiryId}`
- [ ] `inquiries.answer` · `POST /v1/inquiries/{inquiryId}/answer`
- [ ] `inquiries.updateAnswer` · `PUT /v1/inquiries/{inquiryId}/answer`

#### `loginSettings` (6)

- [ ] `loginSettings.get` · `GET /v1/store/login-settings`
- [ ] `loginSettings.update` · `PATCH /v1/store/login-settings`
- [ ] `loginSettings.saveProvider` · `PUT /v1/store/auth-providers/{provider}`
- [ ] `loginSettings.setProviderEnabled` · `PATCH /v1/store/auth-providers/{provider}`
- [ ] `loginSettings.testProvider` · `POST /v1/store/auth-providers/{provider}/test`
- [ ] `loginSettings.removeProvider` · `DELETE /v1/store/auth-providers/{provider}`

#### `points` (1)

- [ ] `points.listHistory` · `GET /v1/points/history`

#### `customers` (9)

- [ ] `customers.getPoints` · `GET /v1/customers/{customerId}/points`
- [ ] `customers.listPointHistory` · `GET /v1/customers/{customerId}/points/history`
- [ ] `customers.adjustPoints` · `POST /v1/customers/{customerId}/points/adjustments`
- [ ] `customers.list` · `GET /v1/customers`
- [ ] `customers.get` · `GET /v1/customers/{customerId}`
- [ ] `customers.orders` · `GET /v1/customers/{customerId}/orders`
- [ ] `customers.consents` · `GET /v1/customers/{customerId}/consents`
- [ ] `customers.coupons` · `GET /v1/customers/{customerId}/coupons`
- [ ] `customers.withdraw` · `POST /v1/customers/{customerId}/withdraw`

#### `coupons` (12)

- [ ] `coupons.list` · `GET /v1/coupons`
- [ ] `coupons.create` · `POST /v1/coupons`
- [ ] `coupons.get` · `GET /v1/coupons/{couponId}`
- [ ] `coupons.update` · `PATCH /v1/coupons/{couponId}`
- [ ] `coupons.pause` · `POST /v1/coupons/{couponId}/pause`
- [ ] `coupons.resume` · `POST /v1/coupons/{couponId}/resume`
- [ ] `coupons.end` · `POST /v1/coupons/{couponId}/end`
- [ ] `coupons.issue` · `POST /v1/coupons/{couponId}/issues`
- [ ] `coupons.issues` · `GET /v1/coupons/{couponId}/issues`
- [ ] `coupons.redemptions` · `GET /v1/coupons/{couponId}/redemptions`
- [ ] `coupons.stats` · `GET /v1/coupons/{couponId}/stats`
- [ ] `coupons.revokeIssue` · `POST /v1/coupon-issues/{issueId}/revoke`

#### `customerInquiries` (4)

- [ ] `customerInquiries.list` · `GET /v1/customer-inquiries`
- [ ] `customerInquiries.get` · `GET /v1/customer-inquiries/{inquiryId}`
- [ ] `customerInquiries.answer` · `POST /v1/customer-inquiries/{inquiryId}/answer`
- [ ] `customerInquiries.updateAnswer` · `PUT /v1/customer-inquiries/{inquiryId}/answer`

#### `settlements` (2)

- [ ] `settlements.list` · `GET /v1/settlements`
- [ ] `settlements.get` · `GET /v1/settlements/{settlementId}`

#### `salesReport` (1)

- [ ] `salesReport.get` · `GET /v1/sales-report`

#### `analytics` (8)

- [ ] `analytics.overview` · `GET /v1/analytics/overview`
- [ ] `analytics.products` · `GET /v1/analytics/products`
- [ ] `analytics.sources` · `GET /v1/analytics/sources`
- [ ] `analytics.realtime` · `GET /v1/analytics/realtime`
- [ ] `analytics.devices` · `GET /v1/analytics/devices`
- [ ] `analytics.pages` · `GET /v1/analytics/pages`
- [ ] `analytics.search` · `GET /v1/analytics/search`
- [ ] `analytics.checkout` · `GET /v1/analytics/checkout`

#### `payments` (3)

- [ ] `payments.list` · `GET /v1/payments`
- [ ] `payments.get` · `GET /v1/payments/{paymentId}`
- [ ] `payments.processRefund` · `POST /v1/payments/refunds/{refundId}/process`

#### `paymentSettings` (14)

- [ ] `paymentSettings.get` · `GET /v1/store/payment-settings`
- [ ] `paymentSettings.update` · `PUT /v1/store/payment-settings`
- [ ] `paymentSettings.upsertTossPayments` · `PUT /v1/store/payment-providers/tosspayments`
- [ ] `paymentSettings.upsertPortOne` · `PUT /v1/store/payment-providers/portone`
- [ ] `paymentSettings.upsertKakaoPay` · `PUT /v1/store/payment-providers/kakaopay`
- [ ] `paymentSettings.upsertNaverPay` · `PUT /v1/store/payment-providers/naverpay`
- [ ] `paymentSettings.upsertPayPal` · `PUT /v1/store/payment-providers/paypal`
- [ ] `paymentSettings.setPlatformTestKeys` · `PUT /v1/store/payment-providers/{provider}/platform-test-keys`
- [ ] `paymentSettings.status` · `GET /v1/store/payment-status`
- [ ] `paymentSettings.disconnect` · `DELETE /v1/store/payment-providers/{provider}`
- [ ] `paymentSettings.removeCredentialSet` · `DELETE /v1/store/payment-providers/{provider}/credentials/{environment}`
- [ ] `paymentSettings.verify` · `POST /v1/store/payment-providers/{provider}/verify`
- [ ] `paymentSettings.updateProvider` · `PATCH /v1/store/payment-providers/{provider}`
- [ ] `paymentSettings.setSandboxMode` · `PATCH /v1/store/payment-providers/{provider}` (`updateProvider`에 `{ sandboxMode }`만 싣는 합성)

#### `appTools` (2)

- [ ] `appTools.list` · `GET /v1/apps/tools`
- [ ] `appTools.call` · `POST /v1/apps/installations/{installationId}/tools/{name}`

#### `apps.catalog` (2)

- [ ] `apps.catalog.list` · `GET /v1/apps/catalog`
- [ ] `apps.catalog.get` · `GET /v1/apps/catalog/{appId}`

#### `apps.installations` (8)

- [ ] `apps.installations.install` · `POST /v1/apps/installations`
- [ ] `apps.installations.list` · `GET /v1/apps/installations`
- [ ] `apps.installations.get` · `GET /v1/apps/installations/{installationId}`
- [ ] `apps.installations.updateSettings` · `PUT /v1/apps/installations/{installationId}/settings`
- [ ] `apps.installations.remove` · `DELETE /v1/apps/installations/{installationId}`
- [ ] `apps.installations.activity` · `GET /v1/apps/installations/{installationId}/activity`
- [ ] `apps.installations.consent` · `POST /v1/apps/installations/{installationId}/consent`
- [ ] `apps.installations.session` · `POST /v1/apps/installations/{installationId}/session`

#### `app` (1)

- [ ] `app.installation` · `GET /v1/app/installation`

#### `app.storage` (4)

- [ ] `app.storage.list` · `GET /v1/app/storage`
- [ ] `app.storage.get` · `GET /v1/app/storage/{key}`
- [ ] `app.storage.set` · `PUT /v1/app/storage/{key}`
- [ ] `app.storage.delete` · `DELETE /v1/app/storage/{key}`

#### `webhooks` (12)

- [ ] `webhooks.list` · `GET /v1/webhooks`
- [ ] `webhooks.create` · `POST /v1/webhooks`
- [ ] `webhooks.get` · `GET /v1/webhooks/{webhookId}`
- [ ] `webhooks.update` · `PUT /v1/webhooks/{webhookId}`
- [ ] `webhooks.remove` · `DELETE /v1/webhooks/{webhookId}`
- [ ] `webhooks.rotateSecret` · `POST /v1/webhooks/{webhookId}/rotate-secret`
- [ ] `webhooks.resume` · `POST /v1/webhooks/{webhookId}/resume`
- [ ] `webhooks.listDeliveries` · `GET /v1/webhooks/{webhookId}/deliveries`
- [ ] `webhooks.getDelivery` · `GET /v1/webhooks/{webhookId}/deliveries/{deliveryId}`
- [ ] `webhooks.redeliver` · `POST /v1/webhooks/{webhookId}/deliveries/{deliveryId}/redeliver`
- [ ] `webhooks.redeliverFailed` · `POST /v1/webhooks/{webhookId}/deliveries/redeliver-failed`
- [ ] `webhooks.sendTest` · `POST /v1/webhooks/{webhookId}/test`

#### `apiLogs` (2)

- [ ] `apiLogs.list` · `GET /v1/api-logs`
- [ ] `apiLogs.summary` · `GET /v1/api-logs/summary`

#### `auditLogs` (1)

- [ ] `auditLogs.list` · `GET /v1/audit-logs`

#### `approvalRequests` (4)

- [ ] `approvalRequests.list` · `GET /v1/approval-requests`
- [ ] `approvalRequests.get` · `GET /v1/approval-requests/{approvalId}`
- [ ] `approvalRequests.approve` · `POST /v1/approval-requests/{approvalId}/approve`
- [ ] `approvalRequests.reject` · `POST /v1/approval-requests/{approvalId}/reject`

#### `reviews` (5)

- [ ] `reviews.list` · `GET /v1/reviews`
- [ ] `reviews.get` · `GET /v1/reviews/{reviewId}`
- [ ] `reviews.createReply` · `POST /v1/reviews/{reviewId}/reply`
- [ ] `reviews.updateReply` · `PUT /v1/reviews/{reviewId}/reply`
- [ ] `reviews.deleteReply` · `DELETE /v1/reviews/{reviewId}/reply`

#### `sellerAddresses` (5)

- [ ] `sellerAddresses.list` · `GET /v1/seller-addresses`
- [ ] `sellerAddresses.create` · `POST /v1/seller-addresses`
- [ ] `sellerAddresses.update` · `PUT /v1/seller-addresses/{addressId}`
- [ ] `sellerAddresses.remove` · `DELETE /v1/seller-addresses/{addressId}`
- [ ] `sellerAddresses.setDefault` · `POST /v1/seller-addresses/{addressId}/default`

#### `inventory.locations` (4)

- [ ] `inventory.locations.list` · `GET /v1/inventory-locations`
- [ ] `inventory.locations.create` · `POST /v1/inventory-locations`
- [ ] `inventory.locations.update` · `PUT /v1/inventory-locations/{inventoryLocationId}`
- [ ] `inventory.locations.remove` · `DELETE /v1/inventory-locations/{inventoryLocationId}`

#### `inventory` (4)

- [ ] `inventory.levels` · `GET /v1/inventory/levels`
- [ ] `inventory.movements` · `GET /v1/inventory/movements`
- [ ] `inventory.adjust` · `POST /v1/inventory/adjustments`
- [ ] `inventory.transfer` · `POST /v1/inventory/transfers`

#### `markets` (5)

- [ ] `markets.list` · `GET /v1/markets`
- [ ] `markets.get` · `GET /v1/markets/{marketId}`
- [ ] `markets.create` · `POST /v1/markets`
- [ ] `markets.update` · `PATCH /v1/markets/{marketId}`
- [ ] `markets.archive` · `DELETE /v1/markets/{marketId}`

#### `pickupLocations` (4)

- [ ] `pickupLocations.list` · `GET /v1/pickup-locations`
- [ ] `pickupLocations.create` · `POST /v1/pickup-locations`
- [ ] `pickupLocations.update` · `PUT /v1/pickup-locations/{locationId}`
- [ ] `pickupLocations.remove` · `DELETE /v1/pickup-locations/{locationId}`

#### `ai` (8)

- [ ] `ai.listConversations` · `GET /v1/ai/conversations`
- [ ] `ai.createConversation` · `POST /v1/ai/conversations`
- [ ] `ai.getConversation` · `GET /v1/ai/conversations/{conversationId}`
- [ ] `ai.sendMessage` · `POST /v1/ai/conversations/{conversationId}/messages`
- [ ] `ai.cancelRun` · `POST /v1/ai/runs/{runId}/cancel`
- [ ] `ai.listFileChanges` · `GET /v1/ai/conversations/{conversationId}/file-changes`
- [ ] `ai.getRunFileDiff` · `GET /v1/ai/runs/{runId}/file-changes`
- [ ] `ai.revertRun` · `POST /v1/ai/runs/{runId}/revert`

#### `storefront` (42)

- [ ] `storefront.listTemplates` · `GET /v1/storefront/templates`
- [ ] `storefront.getStoreTemplate` · `GET /v1/storefront/template`
- [ ] `storefront.updateStoreTemplate` · `PUT /v1/storefront/template`
- [ ] `storefront.get` · `GET /v1/storefront/site`
- [ ] `storefront.checkSlug` · `GET /v1/storefront/slug-availability`
- [ ] `storefront.create` · `POST /v1/storefront/site`
- [ ] `storefront.getDeployment` · `GET /v1/storefront/site/deployment`
- [ ] `storefront.retryDeployment` · `POST /v1/storefront/site/deployment/retry`
- [ ] `storefront.changeTemplate` · `POST /v1/storefront/site/template`
- [ ] `storefront.listVersions` · `GET /v1/storefront/site/versions`
- [ ] `storefront.publish` · `POST /v1/storefront/site/versions/{versionId}/publish`
- [ ] `storefront.rollback` · `POST /v1/storefront/site/rollback`
- [ ] `storefront.changeSlug` · `PUT /v1/storefront/site/slug`
- [ ] `storefront.setVisibility` · `PUT /v1/storefront/site/visibility`
- [ ] `storefront.createPreviewLink` · `POST /v1/storefront/site/preview-link`
- [ ] `storefront.getStarterStatus` · `GET /v1/storefront/starter`
- [ ] `storefront.listDomains` · `GET /v1/storefront/site/domains`
- [ ] `storefront.addDomain` · `POST /v1/storefront/site/domains`
- [ ] `storefront.verifyDomain` · `POST /v1/storefront/site/domains/{domainId}/verify`
- [ ] `storefront.setPrimaryDomain` · `POST /v1/storefront/site/domains/{domainId}/primary`
- [ ] `storefront.removeDomain` · `DELETE /v1/storefront/site/domains/{domainId}`
- [ ] `storefront.disable` · `POST /v1/storefront/site/disable`
- [ ] `storefront.getEditing` · `GET /v1/storefront/site/editing`
- [ ] `storefront.startEditing` · `POST /v1/storefront/site/editing`
- [ ] `storefront.stopEditing` · `DELETE /v1/storefront/site/editing`
- [ ] `storefront.createEditPreviewLink` · `POST /v1/storefront/site/editing/preview-link`
- [ ] `storefront.listFiles` · `GET /v1/storefront/site/files`
- [ ] `storefront.readFile` · `GET /v1/storefront/site/files/content`
- [ ] `storefront.writeFiles` · `POST /v1/storefront/site/files/batch`
- [ ] `storefront.deleteFile` · `POST /v1/storefront/site/files/delete`
- [ ] `storefront.moveFile` · `POST /v1/storefront/site/files/move`
- [ ] `storefront.searchFiles` · `POST /v1/storefront/site/files/search`
- [ ] `storefront.runCheck` · `POST /v1/storefront/site/checks`
- [ ] `storefront.getCheck` · `GET /v1/storefront/site/checks/{checkId}`
- [ ] `storefront.verify` · `POST /v1/storefront/site/verify`
- [ ] `storefront.createVersion` · `POST /v1/storefront/site/versions`
- [ ] `storefront.listBuilds` · `GET /v1/storefront/site/builds`
- [ ] `storefront.getBuild` · `GET /v1/storefront/site/builds/{buildId}`
- [ ] `storefront.getSource` · `GET /v1/storefront/site/source`
- [ ] `storefront.getSourceArchive` · `GET /v1/storefront/site/source/archive`
- [ ] `storefront.uploadSourceBlobs` · `POST /v1/storefront/site/source/blobs`
- [ ] `storefront.replaceSource` · `PUT /v1/storefront/site/source`

#### `subscription` (1)

- [ ] `subscription.get` · `GET /v1/store/subscription`

#### `plans` (1)

- [ ] `plans.listPublic` · `GET /v1/public/plans`

#### `store` (11)

- [ ] `store.get` · `GET /v1/store`
- [ ] `store.update` · `PATCH /v1/store`
- [ ] `store.getPointPolicy` · `GET /v1/store/point-policy`
- [ ] `store.updatePointPolicy` · `PUT /v1/store/point-policy`
- [ ] `store.listMembers` · `GET /v1/store/members`
- [ ] `store.updateMemberRole` · `PATCH /v1/store/members/{userId}`
- [ ] `store.removeMember` · `DELETE /v1/store/members/{userId}`
- [ ] `store.listInvitations` · `GET /v1/store/invitations`
- [ ] `store.invite` · `POST /v1/store/invitations`
- [ ] `store.resendInvitation` · `POST /v1/store/invitations/{invitationId}/resend`
- [ ] `store.cancelInvitation` · `DELETE /v1/store/invitations/{invitationId}`

### 범위 밖

- `@sayren/store-sdk/server`(웹훅 서명 검증, 회원 위임 토큰 발급): 시크릿을 다루는 서버 전용 기능이다
- 내부 API(`/internal/v1/**`), 플랫폼 API(`/platform/v1/**`): 공개 API가 아니다

## 미정 사항

- 게시 위치(pub.dev 공개 여부)와 버전 정책
- 모델 클래스 작성 방식(수기 작성 또는 OpenAPI 기반 코드 생성)
- 지원 플랫폼 범위(iOS·Android 외 Web·데스크톱)
