# sayren-flutter Roadmap

sayren 공개 API를 Flutter(Dart)에서 쓰는 SDK다. Node SDK(`@sayren/storefront-sdk`·`@sayren/store-sdk`)와 이름·목록이 같은 SDK를 만든다.
엔트리포인트, export, 팩토리, 옵션 필드, 네임스페이스, 메서드 이름은 Node SDK와 1:1로 대응한다. Node에 없는 공개 이름은 만들지 않고, Node에 있는 이름은 빼지 않는다.

- 기준 소스: `avarcorp/sayren` `490c9e3`, `@sayren/storefront-sdk` 0.24.0 · `@sayren/store-sdk` 0.36.0
- 이 문서의 목록은 Node SDK 소스(`src/**/*.ts`의 export, `client.ts`의 반환 객체, 옵션 인터페이스)에서 스크립트로 뽑았다. Node SDK가 바뀌면 같은 방식으로 다시 뽑아 맞춘다.

## 네이밍 규칙

| 항목 | Node | Dart |
|---|---|---|
| 저장소 디렉터리 | `packages/storefront-sdk` · `packages/store-sdk` | 같다 |
| 패키지 이름 | `@sayren/storefront-sdk` · `@sayren/store-sdk` | `sayren_storefront_sdk` · `sayren_store_sdk` (pub 이름 규칙상 유일한 차이) |
| 기본 엔트리포인트 | `@sayren/storefront-sdk` | `package:sayren_storefront_sdk/sayren_storefront_sdk.dart` |
| 하위 엔트리포인트 | `@sayren/storefront-sdk/auth` · `/payments` · `/analytics`, `@sayren/store-sdk/server` | `package:sayren_storefront_sdk/auth.dart` · `payments.dart` · `analytics.dart`, `package:sayren_store_sdk/server.dart` |
| 소스 파일 경로 | `src/schemas/commerce-flow.ts` | `lib/src/schemas/commerce-flow.dart` (경로·하이픈 그대로, `file_names` lint 끔) |
| export 이름 | `createStorefrontClient`, `ApiError`, `productCardSchema`, `ProductCard`, `STOREFRONT_SESSION_KEYS` | 같다 (`constant_identifier_names` lint 끔) |
| zod 스키마 상수 | `productCardSchema` (`parse`·`safeParse`) | 같은 이름의 스키마 상수 (`parse`·`safeParse`) |
| 타입·인터페이스 | `ProductCard` (`z.infer`), `StorefrontClientOptions` | 같은 이름의 클래스 |
| 네임스페이스·메서드 | `client.catalog.searchProducts(params)` | `client.catalog.searchProducts(params)` |
| 옵션 객체 인자 | `createStorefrontClient({ baseUrl, storeCode })` | `createStorefrontClient(baseUrl: …, storeCode: …)` 같은 이름의 네임드 인자 |
| 위치 인자 | `getProduct(productId)` | 같은 순서의 위치 인자 |
| `TokenSource` | `string \| null \| undefined \| () => string \| null \| undefined` | `String` 또는 `String? Function()`을 받는 `TokenSource` |
| 비동기 | `Promise<T>` · `Promise<void>` | `Future<T>` · `Future<void>` |
| 오류 | `ApiError(status, code, message, traceId, body, details, docs)` | 같은 필드의 `ApiError` |
| `fetch` 옵션 | `fetch?: typeof globalThis.fetch` | `fetch` (HTTP 함수 주입, 이름 그대로) |

`get`·`set`은 Dart 내장 식별자지만 메서드 이름으로 쓸 수 있다. 메서드·네임스페이스·export 이름 2,239개 중 Dart 예약어·`dart:core` 타입과 겹치는 이름은 없다.

## 단계

| 단계 | 범위 |
|---|---|
| Phase 0 | 기반: `http.ts`(엔벨로프 해제·`ApiError`·`buildQuery`·`TokenSource`·401 refresh 재시도), `schemas/common.ts`, 목록 대조 스크립트 |
| Phase 1 | `@sayren/storefront-sdk` 기본 엔트리포인트(클라이언트·세션·스키마) |
| Phase 2 | `@sayren/storefront-sdk/auth` · `/payments` · `/analytics` |
| Phase 3 | `@sayren/store-sdk` 기본 엔트리포인트 |
| Phase 4 | `@sayren/store-sdk/server` |

목록 대조 스크립트는 Node SDK에서 뽑은 이름 목록과 Dart 패키지의 공개 이름 목록이 같은지 확인한다. 각 Phase는 이 대조를 통과해야 끝난다.

---

## `@sayren/storefront-sdk` → `sayren_storefront_sdk.dart`

### `createStorefrontClient`

- [ ] `StorefrontClientOptions`: `baseUrl`, `storeCode?`, `accessToken?`, `auth?`, `cartToken?`, `visitorId?`, `sessionId?`, `country?`, `host?`, `locale?`, `onCartToken?`, `session?`, `fetch?`
- [ ] 최상위 멤버: `accessToken`, `refreshToken`, `userinfo()`

엔드포인트 78개(경로는 `/storefront/v1` 기준):

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

### `createStorefrontSession`

- [ ] `StorefrontSessionOptions`: `baseUrl`, `storeCode?`, `storage`, `fetch?`
- [ ] `StorefrontSession`: `login()`, `signup()`, `refresh()`, `accessToken`, `refreshToken`, `userinfo()`, `clear()`, `subscribe()`

### export

총 375개.

- [ ] `src/schemas/analytics.ts` → `lib/src/schemas/analytics.dart` (15): `analyticsIdSchema`, `ANALYTICS_VISITOR_COOKIE`, `ANALYTICS_SESSION_COOKIE`, `ANALYTICS_VISITOR_HEADER`, `ANALYTICS_SESSION_HEADER`, `analyticsClientEventNameSchema`, `AnalyticsClientEventName`, `analyticsServerEventNameSchema`, `AnalyticsServerEventName`, `AnalyticsEventName`, `analyticsClientEventSchema`, `AnalyticsClientEvent`, `analyticsBatchSchema`, `AnalyticsBatch`, `ANALYTICS_MAX_BATCH_BYTES`
- [ ] `src/schemas/auth.ts` → `lib/src/schemas/auth.dart` (25): `tokenPairSchema`, `TokenPair`, `signupRequestSchema`, `SignupRequest`, `loginRequestSchema`, `LoginRequest`, `anonymousSessionSchema`, `AnonymousSession`, `withdrawRequestSchema`, `WithdrawRequest`, `withdrawalBlockedDetailsSchema`, `WithdrawalBlockedDetails`, `socialProviderSchema`, `SocialProvider`, `idpAgreementsSchema`, `IdpAgreements`, `idpAuthorizeRequestSchema`, `IdpAuthorizeRequest`, `idpAuthorizeResponseSchema`, `idpTokenRequestSchema`, `IdpTokenRequest`, `memberIdentitiesSchema`, `MemberIdentities`, `linkIdentityRequestSchema`, `LinkIdentityRequest`
- [ ] `src/schemas/cart.ts` → `lib/src/schemas/cart.dart` (8): `cartItemSchema`, `CartItem`, `cartSchema`, `Cart`, `addCartItemRequestSchema`, `AddCartItemRequest`, `updateCartItemRequestSchema`, `UpdateCartItemRequest`
- [ ] `src/schemas/catalog.ts` → `lib/src/schemas/catalog.dart` (30): `CategoryNode`, `categoryNodeSchema`, `productCardSchema`, `ProductCard`, `productNoticeViewSchema`, `ProductNoticeView`, `productCertificationsViewSchema`, `ProductCertificationsView`, `infoSectionViewSchema`, `InfoSectionView`, `productDetailSchema`, `ProductDetail`, `productSortSchema`, `ProductSort`, `ProductSearchParams`, `productFacetsSchema`, `ProductFacets`, `productPageSchema`, `ProductPage`, `storefrontCollectionSchema`, `StorefrontCollection`, `collectionProductSortSchema`, `CollectionProductSortParam`, `storefrontCollectionDetailSchema`, `StorefrontCollectionDetail`, `CollectionProductParams`, `collectionProductQuerySchema`, `collectionProductPageSchema`, `CollectionProductPage`, `storefrontCollectionListQuerySchema`
- [ ] `src/schemas/checkout.ts` → `lib/src/schemas/checkout.dart` (73): `createCheckoutRequestSchema`, `CreateCheckoutRequest`, `remoteAreaSchema`, `RemoteArea`, `checkoutDeliverySchema`, `CheckoutDelivery`, `checkoutSessionSchema`, `CheckoutSession`, `deliveryQuoteRequestSchema`, `DeliveryQuoteRequest`, `deliveryQuoteSchema`, `DeliveryQuoteResult`, `paymentMethodSchema`, `PaymentMethod`, `responsePaymentMethodSchema`, `ResponsePaymentMethod`, `pgProviderSchema`, `PgProvider`, `easyPayProviderSchema`, `EasyPayProvider`, `easyPayProviderResponseSchema`, `paymentOptionSchema`, `PaymentOption`, `availablePaymentOptionSchema`, `AvailablePaymentOption`, `paymentOptionListSchema`, `paymentOptionKey`, `CONTACT_PHONE_PATTERN`, `shippingAddressInputSchema`, `ShippingAddressInput`, `INTERNATIONAL_PHONE_PATTERN`, `internationalShippingAddressInputSchema`, `InternationalShippingAddressInput`, `ORDERER_PHONE_PATTERN`, `guestInfoSchema`, `GuestInfo`, `CASH_RECEIPT_METHODS`, `cashReceiptAvailable`, `cashReceiptTypeSchema`, `CashReceiptType`, `CashReceiptIdentityType`, `residentNumberLike`, `cashReceiptIdentityTypeOf`, `cashReceiptRequestSchema`, `CashReceiptRequest`, `startPaymentRequestSchema`, `StartPaymentRequest`, `retryPaymentRequestSchema`, `RetryPaymentRequest`, `paymentLaunchSchema`, `PaymentLaunch`, `confirmPaymentRequestSchema`, `ConfirmPaymentRequest`, `paymentConfirmResultSchema`, `PaymentConfirmResult`, `reportPaymentFailureRequestSchema`, `ReportPaymentFailureRequest`, `paymentFailureResultSchema`, `PaymentFailureResult`, `PAYMENT_START_STATUS_VALUES`, `KnownPaymentStartStatus`, `paymentStartSchema`, `PaymentStart`, `paymentFailureCategorySchema`, `PaymentFailureCategory`, `PAYMENT_STATUS_VALUES`, `KnownPaymentStatus`, `PAYMENT_RESULT_VALUES`, `KnownPaymentResult`, `paymentStatusSchema`, `PaymentStatus`, `paymentMessageSchema`, `PaymentMessage`
- [ ] `src/schemas/claim.ts` → `lib/src/schemas/claim.dart` (14): `claimTypeSchema`, `ClaimType`, `claimReasonSchema`, `ClaimReason`, `createClaimRequestSchema`, `CreateClaimRequest`, `createClaimResultSchema`, `CreateClaimResult`, `claimPreviewSchema`, `ClaimPreview`, `claimReturnAddressSchema`, `ClaimReturnAddress`, `myClaimSchema`, `MyClaim`
- [ ] `src/schemas/commerce-flow.ts` → `lib/src/schemas/commerce-flow.dart` (19): `flowInputFieldSchema`, `FlowInputField`, `flowActionSchema`, `FlowAction`, `flowFieldValueSchema`, `FlowFieldValue`, `flowStateSchema`, `FlowState`, `ORDER_STEP_TYPES`, `orderStepSchema`, `OrderStep`, `flowActionRequestSchema`, `FlowActionRequest`, `guestFlowActionRequestSchema`, `GuestFlowActionRequest`, `flowActionResultSchema`, `FlowActionResult`, `orderFlowActionResultSchema`, `OrderFlowActionResult`
- [ ] `src/schemas/commerce-number.ts` → `lib/src/schemas/commerce-number.dart` (3): `formatOrderNo`, `parseOrderNo`, `commerceNumberField`
- [ ] `src/schemas/common.ts` → `lib/src/schemas/common.dart` (8): `pageInfoSchema`, `PageInfo`, `pageSchema`, `PageParams`, `orderItemStatusSchema`, `OrderItemStatus`, `claimStatusSchema`, `ClaimStatus`
- [ ] `src/schemas/consent.ts` → `lib/src/schemas/consent.dart` (12): `consentKindSchema`, `ConsentKind`, `consentActionSchema`, `ConsentAction`, `consentSourceSchema`, `ConsentSource`, `consentStateSchema`, `ConsentState`, `memberConsentsSchema`, `MemberConsents`, `consentUpdateRequestSchema`, `ConsentUpdateRequest`
- [ ] `src/schemas/coupon.ts` → `lib/src/schemas/coupon.dart` (23): `couponApplicationSchema`, `CouponApplication`, `MAX_COUPONS_PER_CHECKOUT`, `couponApplicationListSchema`, `couponBenefitViewSchema`, `couponResultSchema`, `CouponResult`, `pricingAmountsSchema`, `checkoutPricingRequestSchema`, `CheckoutPricingRequest`, `MIN_PAYMENT_AMOUNT`, `checkoutPricingSchema`, `CheckoutPricing`, `applicableCouponSchema`, `ApplicableCoupon`, `myCouponSchema`, `MyCoupon`, `myCouponListQuerySchema`, `storefrontCouponTargetSchema`, `storefrontCouponSchema`, `StorefrontCoupon`, `storefrontCouponListQuerySchema`, `StorefrontCouponListParams`
- [ ] `src/schemas/currency.ts` → `lib/src/schemas/currency.dart` (20): `CurrencySpec`, `CURRENCIES`, `CurrencyCode`, `CURRENCY_CODES`, `BASE_CURRENCY`, `currencyCodeSchema`, `isCurrencyCode`, `currencySpecOf`, `toMinor`, `minorToMajor`, `toDecimalString`, `fromDecimalString`, `floorToSaleUnit`, `isSaleUnitPrice`, `InvalidPriceUnitError`, `assertSaleUnit`, `minPaymentOf`, `MoneyRules`, `moneyRulesOf`, `KRW_MONEY_RULES`
- [ ] `src/schemas/customer-inquiry.ts` → `lib/src/schemas/customer-inquiry.dart` (6): `customerInquiryCategorySchema`, `CustomerInquiryCategory`, `customerInquirySchema`, `CustomerInquiry`, `createCustomerInquiryRequestSchema`, `CreateCustomerInquiryRequest`
- [ ] `src/schemas/fulfillment.ts` → `lib/src/schemas/fulfillment.dart` (11): `UnknownFulfillmentView`, `productCardFulfillmentSchema`, `ProductCardFulfillment`, `productFulfillmentViewSchema`, `ProductFulfillmentView`, `lineFulfillmentSchema`, `LineFulfillment`, `pickupLocationViewSchema`, `PickupLocationView`, `myOrderItemFulfillmentSnapshotSchema`, `MyOrderItemFulfillmentSnapshot`
- [ ] `src/schemas/inquiry.ts` → `lib/src/schemas/inquiry.dart` (8): `productInquiryCategorySchema`, `ProductInquiryCategory`, `publicInquirySchema`, `PublicInquiry`, `createInquiryRequestSchema`, `CreateInquiryRequest`, `createInquiryResultSchema`, `CreateInquiryResult`
- [ ] `src/schemas/member.ts` → `lib/src/schemas/member.dart` (14): `memberSchema`, `Member`, `updateProfileRequestSchema`, `UpdateProfileRequest`, `memberAddressSchema`, `MemberAddress`, `memberAddressRequestSchema`, `MemberAddressRequest`, `internationalMemberAddressRequestSchema`, `InternationalMemberAddressRequest`, `memberAddressWriteSchema`, `MemberAddressWrite`, `wishlistAddResultSchema`, `WishlistAddResult`
- [ ] `src/schemas/order.ts` → `lib/src/schemas/order.dart` (11): `myOrderItemSchema`, `MyOrderItem`, `orderShippingAddressSchema`, `OrderShippingAddress`, `myOrderSchema`, `MyOrder`, `trackingStageResponseSchema`, `deliveryTrackingSchema`, `DeliveryTracking`, `purchaseDecisionResultSchema`, `PurchaseDecisionResult`
- [ ] `src/schemas/points.ts` → `lib/src/schemas/points.dart` (7): `storefrontPointPolicySchema`, `StorefrontPointPolicy`, `memberPointsSchema`, `MemberPoints`, `memberPointEntrySchema`, `MemberPointEntry`, `memberPointEntryPageSchema`
- [ ] `src/schemas/product-options.ts` → `lib/src/schemas/product-options.dart` (19): `addonGroupViewSchema`, `AddonGroupView`, `customInputViewSchema`, `CustomInputView`, `parseCustomInputValue`, `normalizeCustomInputValue`, `customInputLength`, `customInputEntrySchema`, `CustomInputEntry`, `addonSelectionSchema`, `AddonSelection`, `lineSelectionRequestShape`, `optionSelectionViewSchema`, `OptionSelectionView`, `customInputValueViewSchema`, `CustomInputValueView`, `lineSelectionResponseShape`, `orderInputUploadRequestSchema`, `OrderInputUploadRequest`
- [ ] `src/schemas/review.ts` → `lib/src/schemas/review.dart` (26): `publicReviewSchema`, `PublicReview`, `reviewSummarySchema`, `ReviewSummary`, `myReviewSchema`, `MyReview`, `writableReviewSchema`, `WritableReview`, `createReviewRequestSchema`, `CreateReviewRequest`, `createReviewResultSchema`, `CreateReviewResult`, `updateReviewRequestSchema`, `UpdateReviewRequest`, `productReviewSortSchema`, `ProductReviewSort`, `productReviewQuerySchema`, `ProductReviewParams`, `reviewImageUploadRequestSchema`, `ReviewImageUploadRequest`, `uploadTicketSchema`, `UploadTicket`, `reviewPageSchema`, `ReviewPage`, `updateReviewResultSchema`, `UpdateReviewResult`
- [ ] `src/schemas/stay.ts` → `lib/src/schemas/stay.dart` (6): `stayRequestSchema`, `StayRequest`, `stayViewSchema`, `StayView`, `calendarDayViewSchema`, `CalendarDayView`
- [ ] `src/schemas/store.ts` → `lib/src/schemas/store.dart` (4): `storefrontMarketSchema`, `StorefrontMarket`, `storefrontStoreSchema`, `StorefrontStore`
- [ ] `src/analytics-ids.ts` → `lib/src/analytics-ids.dart` (1): `analyticsIdsFromCookie`
- [ ] `src/client.ts` → `lib/src/client.dart` (3): `StorefrontClient`, `StorefrontClientOptions`, `createStorefrontClient`
- [ ] `src/http.ts` → `lib/src/http.dart` (4): `Query`, `TokenSource`, `ApiError`, `buildQuery`
- [ ] `src/session.ts` → `lib/src/session.dart` (5): `createStorefrontSession`, `SessionStorage`, `STOREFRONT_SESSION_KEYS`, `StorefrontSession`, `StorefrontSessionOptions`

## `@sayren/storefront-sdk/auth` → `auth.dart`

### `createStorefrontAuth`

- [ ] `StorefrontAuthOptions`: `baseUrl`, `storeCode`, `fetch?`
- [ ] `StorefrontAuth`: `anonymous()`, `session()`, `signUp()`, `idp()`, `idpCallback()`, `identities()`, `linkIdp()`, `linkIdpCallback()`, `unlinkIdp()`, `refresh()`, `signOut()`, `withdraw()`

### export

총 15개.

- [ ] `src/auth/index.ts` → `lib/src/auth/index.dart` (6): `IdpStart`, `IdpCallbackInput`, `IdpCallbackError`, `StorefrontAuthOptions`, `createStorefrontAuth`, `StorefrontAuth`
- [ ] `src/http.ts` → `lib/src/http.dart` (1): `ApiError`
- [ ] `src/schemas/auth.ts` → `lib/src/schemas/auth.dart` (8): `AnonymousSession`, `LoginRequest`, `MemberIdentities`, `SignupRequest`, `SocialProvider`, `TokenPair`, `WithdrawalBlockedDetails`, `WithdrawRequest`

## `@sayren/storefront-sdk/payments` → `payments.dart`

### `createPayments`

- [ ] `PaymentsOptions`: `client`, `returnUrl?`, `env?`
- [ ] `Payments`: `start()`, `retry()`, `open()`, `prepareWindow()`, `result()`, `getStatus()`
- [ ] `StartOptions`: `option?`, `shippingAddress?`, `guest?`, `cashReceipt?`, `coupons?`, `pointAmount?`, `returnUrl?`, `mode?`, `window?`
- [ ] `RetryOptions`: `option`, `returnUrl?`, `cashReceipt?`, `mode?`, `window?`

### export

총 15개.

- [ ] `src/payments/index.ts` → `lib/src/payments/index.dart` (15): `PaymentMode`, `PaymentDevice`, `PaymentResult`, `PaymentPopup`, `PaymentPostMessage`, `PaymentsEnv`, `resolvePaymentMode`, `paymentResultOf`, `PaymentsOptions`, `StartOptions`, `RetryOptions`, `PREPARED_WINDOW`, `PreparedPaymentWindow`, `Payments`, `createPayments`

## `@sayren/storefront-sdk/analytics` → `analytics.dart`

### `createAnalytics`

- [ ] `AnalyticsOptions`: `baseUrl`, `storeCode`, `consent?`, `autoPageViews?`, `debug?`, `cookieDomain?`, `flushIntervalMs?`
- [ ] `Analytics`: `track()`, `page()`, `setConsent()`, `ids()`, `flush()`, `destroy()`

### export

총 7개.

- [ ] `src/analytics/index.ts` → `lib/src/analytics/index.dart` (7): `AnalyticsConsent`, `AnalyticsOptions`, `AnalyticsTrackInput`, `Analytics`, `AnalyticsEnv`, `createAnalytics`, `createAnalyticsWith`

---

## `@sayren/store-sdk` → `sayren_store_sdk.dart`

### `createStoreClient`

- [ ] `StoreClientOptions`: `baseUrl`, `accessToken?`, `storeId?`, `session?`, `refresh?`, `onUnauthorized?`, `fetch?`
- [ ] 최상위 멤버: `accessToken`, `refreshToken`, `authorize()`, `userinfo()`

엔드포인트 311개(경로는 `/v1` 기준):

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

### `createStoreSession`

- [ ] `StoreSessionOptions`: `baseUrl`, `authServer`, `clientId`, `storage`, `fetch?`
- [ ] `StoreAuthServer`: `authorizeUrl`, `tokenUrl`, `revokeUrl`, `resource?`
- [ ] `AuthorizeOptions`: `redirectUri`, `scope?`, `prompt?`
- [ ] `StoreSession`: `getToken()`, `setTokens()`, `refresh()`, `clear()`, `logout()`, `subscribe()`, `accessToken`, `refreshToken`, `authorize()`, `handleCallback()`, `userinfo()`

### export

총 1613개.

- [ ] `src/schemas/ai.ts` → `lib/src/schemas/ai.dart` (99): `aiAttachmentSchema`, `aiPreviewSelectionSchema`, `AiPreviewSelection`, `aiRunStatusSchema`, `AiRunStatus`, `AI_RUN_ACTIVE_STATUSES`, `aiStreamAccessSchema`, `AiStreamAccess`, `aiRunSchema`, `AiRun`, `aiActivitySchema`, `AiActivity`, `aiToolChangeSchema`, `AiToolChange`, `AI_AGENT_PHASES`, `aiAgentPhaseSchema`, `AiAgentPhase`, `AI_AGENT_NOTES_DIR`, `AI_TODO_STATUSES`, `aiTodoSchema`, `AiTodo`, `AI_TODOS_MAX`, `isAiAgentNotesPath`, `AI_DESIGN_DIR`, `AI_DESIGN_CANVAS_PATH`, `isAiDesignPath`, `AI_DESIGN_BOARD_FILE_PATTERN`, `AI_DESIGN_BOARD_KINDS`, `AI_DESIGN_VIEWPORTS`, `AI_DESIGN_BOARDS_MAX`, `aiDesignBoardSchema`, `AiDesignBoard`, `aiDesignCanvasSchema`, `AiDesignCanvas`, `aiDesignSelectionSchema`, `AiDesignSelection`, `STORE_SHOP_TYPES`, `storeShopTypeSchema`, `StoreShopType`, `aiChoiceOptionSchema`, `AiChoiceOption`, `aiSetupConfirmItemSchema`, `AiSetupConfirmItem`, `AI_SETUP_CONFIRM_APPROVE`, `aiDesignConfirmBoardSchema`, `AiDesignConfirmBoard`, `AI_DESIGN_CONFIRM_APPROVE`, `aiMessagePartSchema`, `AiMessagePart`, `aiMessageSchema`, `AiMessage`, `aiConversationSummarySchema`, `AiConversationSummary`, `aiConversationSchema`, `AiConversation`, `storeSetupBriefSchema`, `StoreSetupBrief`, `createAiConversationRequestSchema`, `CreateAiConversationRequest`, `createAiConversationResponseSchema`, `CreateAiConversationResponse`, `sendAiMessageRequestSchema`, `SendAiMessageRequest`, `sendAiMessageResponseSchema`, `SendAiMessageResponse`, `aiFocusAreaSchema`, `AiFocusArea`, `aiFocusSchema`, `AiFocus`, `AI_RUN_FILE_CHANGES_RETENTION_DAYS`, `aiRunChangesStatusSchema`, `AiRunChangesStatus`, `aiFileChangeKindSchema`, `AiFileChangeKind`, `aiRunChangesSchema`, `AiRunChanges`, `aiConversationFileChangesSchema`, `AiConversationFileChanges`, `aiRunFileDiffSchema`, `AiRunFileDiff`, `aiRunRevertResultSchema`, `AiRunRevertResult`, `aiRunRevertConflictDetailsSchema`, `AiRunRevertConflictDetails`, `aiStreamEventSchema`, `AiStreamEvent`, `aiStreamRecordSchema`, `AiStreamRecord`, `STORE_DRAFT_MAX_ATTACHMENTS`, `STORE_DRAFT_ATTACHMENT_MAX_BYTES`, `STORE_DRAFT_RETENTION_DAYS`, `createStoreDraftRequestSchema`, `CreateStoreDraftRequest`, `createStoreDraftResponseSchema`, `CreateStoreDraftResponse`, `storeDraftSchema`, `StoreDraft`, `storeDraftPreviewSchema`, `StoreDraftPreview`
- [ ] `src/schemas/analytics.ts` → `lib/src/schemas/analytics.dart` (44): `analyticsRangeQuerySchema`, `AnalyticsRangeParams`, `analyticsTotalsSchema`, `AnalyticsTotals`, `analyticsFunnelStepSchema`, `AnalyticsFunnelStep`, `analyticsOverviewSchema`, `AnalyticsOverview`, `analyticsProductSortSchema`, `AnalyticsProductSort`, `analyticsProductsQuerySchema`, `AnalyticsProductsParams`, `analyticsProductRowSchema`, `AnalyticsProductRow`, `analyticsProductsSchema`, `AnalyticsProducts`, `analyticsChannelSchema`, `AnalyticsChannel`, `analyticsSourceGroupBySchema`, `AnalyticsSourceGroupBy`, `analyticsSourcesQuerySchema`, `AnalyticsSourcesParams`, `analyticsSourceRowSchema`, `AnalyticsSourceRow`, `analyticsSourcesSchema`, `AnalyticsSources`, `analyticsRealtimeSchema`, `AnalyticsRealtime`, `analyticsDeviceRowSchema`, `AnalyticsDeviceRow`, `analyticsDevicesSchema`, `AnalyticsDevices`, `analyticsPagesQuerySchema`, `AnalyticsPagesParams`, `analyticsPagesSchema`, `AnalyticsPages`, `analyticsSearchQuerySchema`, `AnalyticsSearchParams`, `analyticsSearchSchema`, `AnalyticsSearch`, `analyticsCheckoutOutcomeSchema`, `AnalyticsCheckoutOutcome`, `analyticsCheckoutSchema`, `AnalyticsCheckout`
- [ ] `src/schemas/api-log.ts` → `lib/src/schemas/api-log.dart` (17): `apiLogPrincipalTypeSchema`, `ApiLogPrincipalType`, `apiLogPrincipalSchema`, `ApiLogPrincipal`, `apiLogErrorSchema`, `ApiLogError`, `apiLogSchema`, `ApiLog`, `apiLogStatusFilterSchema`, `ApiLogStatusFilter`, `apiLogListQuerySchema`, `ApiLogListParams`, `ApiLogListOptions`, `apiLogPageSchema`, `ApiLogPage`, `apiLogSummarySchema`, `ApiLogSummary`
- [ ] `src/schemas/app-manifest.ts` → `lib/src/schemas/app-manifest.dart` (74): `APP_HANDLE_PATTERN`, `APP_RESERVED_HANDLES`, `appHandleSchema`, `NON_INSTALLABLE_SCOPES`, `INSTALLABLE_SCOPES`, `isInstallableScope`, `appScopeSchema`, `APP_LIFECYCLE_EVENT_TYPES`, `AppLifecycleEventType`, `AppEventType`, `AppLifecycleEventDataMap`, `AppEventDataOf`, `APP_EVENT_SCOPES`, `APP_EVENT_TYPES`, `appEventTypeSchema`, `scopesCoverEvent`, `APP_NETWORK_DENIED_SUFFIXES`, `appNetworkHostProblem`, `appNetworkHostSchema`, `APP_SETTING_FIELD_TYPES`, `AppSettingFieldType`, `APP_SETTINGS_MAX_FIELDS`, `APP_SETTING_KEY_PATTERN`, `appSettingFieldSchema`, `AppSettingField`, `APP_SECRET_NAME_PATTERN`, `APP_SECRETS_MAX`, `APP_EVENTS_MAX`, `APP_NETWORK_HOSTS_MAX`, `APP_PUBLIC_HTTP_MAX`, `APP_SCHEDULES_MAX`, `APP_HTTP_KEY_PATTERN`, `APP_SCHEDULE_NAME_PATTERN`, `APP_SCHEDULE_INTERVALS`, `AppScheduleInterval`, `APP_FLOW_NOTIFICATION_PATTERN`, `APP_FLOW_EVENT_PATTERN`, `APP_FLOW_ITEMS_MAX`, `appFlowParamSchema`, `AppFlowParam`, `appFlowNotificationSchema`, `AppFlowNotification`, `appFlowEventSchema`, `AppFlowEvent`, `APP_TOOL_NAME_PATTERN`, `appToolInputSchema`, `AppToolInput`, `appToolSchema`, `AppTool`, `APP_ICON_MAX_BYTES`, `APP_ICON_MIN_PX`, `APP_README_MAX_BYTES`, `APP_ICON_CONTENT_TYPES`, `AppIconContentType`, `appIconProblem`, `appManifestSchema`, `AppManifest`, `AppManifestInput`, `APP_SECRET_PATTERNS`, `APP_SERVER_BUNDLE_MAX_GZIP_BYTES`, `APP_UI_MAX_BYTES`, `APP_UI_MAX_FILES`, `AppManifestProblem`, `appManifestProblems`, `AppCapabilities`, `appCapabilitiesOf`, `AppCapabilityDefinition`, `APP_CAPABILITIES`, `appHttpKeyMatches`, `appScheduleListOf`, `appFlowSummaryOf`, `appToolListOf`, `appScheduleIntervalLabel`, `appManifestWidens`
- [ ] `src/schemas/apps.ts` → `lib/src/schemas/apps.dart` (93): `appDistributionSchema`, `AppDistribution`, `appRuntimeSchema`, `AppRuntime`, `appStatusSchema`, `AppStatus`, `appInstallationStatusSchema`, `AppInstallationStatus`, `appVisibilitySchema`, `AppVisibility`, `appInstallationAppSchema`, `AppInstallationApp`, `appInstallationSettingsSchema`, `AppInstallationSettings`, `appInstallationSettingsUpdateSchema`, `AppInstallationSettingsUpdate`, `appScheduleSummarySchema`, `AppScheduleSummary`, `appFlowNotificationSummarySchema`, `AppFlowNotificationSummary`, `appFlowEventSummarySchema`, `AppFlowEventSummary`, `appInstallationSchema`, `AppInstallation`, `appInstallationRunSchema`, `AppInstallationRun`, `appInstallationActivitySchema`, `AppInstallationActivity`, `appInstallRequestSchema`, `AppInstallRequest`, `appListingSchema`, `AppListing`, `storeAppSchema`, `StoreApp`, `storeAppDetailSchema`, `StoreAppDetail`, `appSessionSchema`, `AppSession`, `appInstallationSelfSchema`, `AppInstallationSelf`, `appToolSummarySchema`, `AppToolSummary`, `appToolCallSchema`, `AppToolCall`, `appToolResultSchema`, `AppToolResult`, `APP_STORAGE_KEY_PATTERN`, `APP_STORAGE_MAX_KEYS`, `APP_STORAGE_MAX_BYTES`, `appStorageEntrySchema`, `AppStorageEntry`, `appStorageKeysSchema`, `AppStorageKeys`, `appStoragePutSchema`, `AppStoragePut`, `appStorageListQuerySchema`, `appBuildStageSchema`, `AppBuildStage`, `appBuildSchema`, `AppBuild`, `appVersionSchema`, `AppVersion`, `appListingReviewStatusSchema`, `AppListingReviewStatus`, `appListingReviewSchema`, `AppListingReview`, `developerAppSchema`, `DeveloperApp`, `developerAppCreateSchema`, `DeveloperAppCreate`, `appArtifactUploadSchema`, `AppArtifactUpload`, `appReleaseResultSchema`, `AppReleaseResult`, `appSecretSummarySchema`, `AppSecretSummary`, `devStoreSchema`, `DevStore`, `developerStoreSchema`, `DeveloperStore`, `developerInstallationSchema`, `DeveloperInstallation`, `appDevTokenSchema`, `AppDevToken`, `appInvocationSchema`, `AppInvocation`, `appDeployKeySchema`, `AppDeployKey`, `appDeployKeyCreatedSchema`, `AppDeployKeyCreated`, `appDeployKeyCreateSchema`, `APP_DEPLOY_KEY_PATTERN`, `APP_DEPLOY_KEY_PREFIX`
- [ ] `src/schemas/audit.ts` → `lib/src/schemas/audit.dart` (32): `auditActorTypeSchema`, `AuditActorType`, `auditActorSchema`, `AuditActor`, `auditLogSourceSchema`, `AuditLogSource`, `auditLogOutcomeSchema`, `AuditLogOutcome`, `auditLogSchema`, `AuditLog`, `auditLogListQuerySchema`, `AuditLogListParams`, `AuditLogListOptions`, `auditLogPageSchema`, `AuditLogPage`, `agentPolicyDecisionSchema`, `AgentPolicyDecision`, `writePreviewSchema`, `WritePreview`, `writeDryRunResultSchema`, `WriteDryRunResult`, `approvalStatusSchema`, `ApprovalStatus`, `approvalRequestSchema`, `ApprovalRequest`, `approvalListQuerySchema`, `ApprovalListParams`, `ApprovalListOptions`, `approvalPageSchema`, `ApprovalPage`, `approvalDecisionRequestSchema`, `ApprovalDecisionRequest`
- [ ] `src/schemas/auth.ts` → `lib/src/schemas/auth.dart` (6): `storeRoleSchema`, `StoreRole`, `myStoreSchema`, `MyStore`, `myAccountSchema`, `MyAccount`
- [ ] `src/schemas/category.ts` → `lib/src/schemas/category.dart` (24): `categoryProductSortSchema`, `CategoryProductSort`, `categorySchema`, `Category`, `CategoryTreeNode`, `categoryTreeNodeSchema`, `categoryWithPathSchema`, `CategoryWithPath`, `categorySearchResultSchema`, `CategorySearchResult`, `categoryAttributeSchema`, `CategoryAttribute`, `categoryCreateRequestSchema`, `CategoryCreateRequest`, `categoryPatchRequestSchema`, `CategoryPatchRequest`, `categoryDeleteStrategySchema`, `CategoryDeleteStrategy`, `categoryListQuerySchema`, `categoryDeleteQuerySchema`, `categoryLocalizationSchema`, `CategoryLocalization`, `categoryLocalizationRequestSchema`, `CategoryLocalizationRequest`
- [ ] `src/schemas/claim.ts` → `lib/src/schemas/claim.dart` (20): `claimTypeSchema`, `ClaimType`, `claimStatusSchema`, `ClaimStatus`, `claimReasonSchema`, `ClaimReason`, `claimReturnAddressSchema`, `ClaimReturnAddress`, `claimSchema`, `Claim`, `ClaimListParams`, `claimListQuerySchema`, `claimDetailSchema`, `ClaimDetail`, `claimHoldResultSchema`, `ClaimHoldResult`, `rejectClaimRequestSchema`, `RejectClaimRequest`, `approveClaimResultSchema`, `ApproveClaimResult`
- [ ] `src/schemas/collection.ts` → `lib/src/schemas/collection.dart` (64): `MAX_COLLECTIONS`, `MAX_COLLECTION_PRODUCTS`, `MAX_COLLECTION_PRODUCTS_PER_ADD`, `MAX_COLLECTION_TITLE`, `MAX_COLLECTION_DESCRIPTION`, `COLLECTION_SLUG_PATTERN`, `COLLECTION_TYPES`, `CollectionType`, `COLLECTION_PRODUCT_SORTS`, `CollectionProductSort`, `collectionProductSortRequestSchema`, `collectionStateSchema`, `CollectionState`, `collectionStateOf`, `MAX_COLLECTION_RULES`, `MAX_COLLECTION_RULE_CATEGORIES`, `MAX_COLLECTION_CREATED_WITHIN_DAYS`, `COLLECTION_PREVIEW_SIZE`, `COLLECTION_BEST_SELLING_DAYS`, `CollectionBestSellingDays`, `MAX_COLLECTION_BEST_SELLING_TOP`, `COLLECTION_SALES_SORT_DEFAULT_DAYS`, `collectionRuleSchema`, `CollectionRule`, `CollectionRuleField`, `collectionRulesSchema`, `collectionRuleViewSchema`, `CollectionRuleView`, `CollectionRuleProduct`, `CollectionRuleContext`, `descendantCategoryIdsOf`, `collectionRulesPredicate`, `matchesCollectionRules`, `bestSellingRuleOf`, `compareBySales`, `rankBestSelling`, `collectionRuleCategoryIds`, `collectionSchema`, `Collection`, `collectionCreateRequestSchema`, `CollectionCreateRequest`, `CollectionCreateRequestInput`, `collectionPatchRequestSchema`, `CollectionPatchRequest`, `collectionProductsReplaceRequestSchema`, `CollectionProductsReplaceRequest`, `collectionProductsAddRequestSchema`, `CollectionProductsAddRequest`, `collectionProductSchema`, `CollectionProduct`, `collectionStateCountsSchema`, `collectionPageSchema`, `CollectionPage`, `CollectionListParams`, `collectionListQuerySchema`, `collectionProductListQuerySchema`, `collectionPreviewRequestSchema`, `CollectionPreviewRequest`, `collectionPreviewSchema`, `CollectionPreview`, `collectionLocalizationSchema`, `CollectionLocalization`, `collectionLocalizationRequestSchema`, `CollectionLocalizationRequest`
- [ ] `src/schemas/commerce-flow.ts` → `lib/src/schemas/commerce-flow.dart` (60): `flowInputFieldSchema`, `FlowInputField`, `flowActionSchema`, `FlowAction`, `flowFieldValueSchema`, `FlowFieldValue`, `flowStateSchema`, `FlowState`, `orderItemFlowSchema`, `OrderItemFlow`, `moveFlowStateRequestSchema`, `MoveFlowStateRequest`, `flowRunStepSchema`, `flowRunSchema`, `FlowRun`, `flowActionRequestSchema`, `FlowActionRequest`, `flowActionResultSchema`, `FlowActionResult`, `flowPresetSummarySchema`, `FlowPresetSummary`, `flowPresetDetailSchema`, `FlowPresetDetail`, `commerceFlowSummarySchema`, `CommerceFlowSummary`, `commerceFlowVersionViewSchema`, `commerceFlowSchema`, `CommerceFlow`, `CommerceFlowVersionView`, `migrateFlowVersionRequestSchema`, `MigrateFlowVersionRequest`, `migrateFlowVersionResultSchema`, `MigrateFlowVersionResult`, `createCommerceFlowRequestSchema`, `CreateCommerceFlowRequest`, `saveFlowDraftRequestSchema`, `SaveFlowDraftRequest`, `commerceFlowCheckSchema`, `CommerceFlowCheck`, `resolvedFlowSchema`, `ResolvedFlow`, `flowSecretNameSchema`, `flowSecretSchema`, `FlowSecret`, `saveFlowSecretRequestSchema`, `SaveFlowSecretRequest`, `orderFlowActionResultSchema`, `OrderFlowActionResult`, `simulateFlowRequestSchema`, `SimulateFlowRequest`, `simulationStepSchema`, `SimulationStep`, `simulateFlowResultSchema`, `SimulateFlowResult`, `replayFlowRequestSchema`, `ReplayFlowRequest`, `replayFlowResultSchema`, `ReplayFlowResult`, `flowNodeTypesSchema`, `FlowNodeTypes`
- [ ] `src/schemas/commerce-number.ts` → `lib/src/schemas/commerce-number.dart` (3): `formatOrderNo`, `parseOrderNo`, `commerceNumberField`
- [ ] `src/schemas/common.ts` → `lib/src/schemas/common.dart` (11): `pageInfoSchema`, `PageInfo`, `pageSchema`, `pageQueryShape`, `PageParams`, `bulkResultSchema`, `BulkResult`, `orderItemStatusSchema`, `OrderItemStatus`, `changeTypeSchema`, `ChangeType`
- [ ] `src/schemas/coupon.ts` → `lib/src/schemas/coupon.dart` (30): `couponStatusSchema`, `CouponStatus`, `couponIssueMethodSchema`, `CouponIssueMethod`, `COUPON_CODE_PATTERN`, `normalizeCouponCode`, `couponConditionsInputSchema`, `couponTargetInputSchema`, `createCouponRequestSchema`, `CreateCouponRequest`, `updateCouponRequestSchema`, `UpdateCouponRequest`, `couponSchema`, `Coupon`, `couponListQuerySchema`, `couponIssueStatusSchema`, `couponIssueSchema`, `CouponIssue`, `couponIssueListQuerySchema`, `issueCouponRequestSchema`, `IssueCouponRequest`, `issueCouponResultSchema`, `IssueCouponResult`, `couponRedemptionSchema`, `CouponRedemption`, `couponRedemptionListQuerySchema`, `couponStatsSchema`, `CouponStats`, `customerCouponSchema`, `CustomerCoupon`
- [ ] `src/schemas/currency.ts` → `lib/src/schemas/currency.dart` (20): `CurrencySpec`, `CURRENCIES`, `CurrencyCode`, `CURRENCY_CODES`, `BASE_CURRENCY`, `currencyCodeSchema`, `isCurrencyCode`, `currencySpecOf`, `toMinor`, `minorToMajor`, `toDecimalString`, `fromDecimalString`, `floorToSaleUnit`, `isSaleUnitPrice`, `InvalidPriceUnitError`, `assertSaleUnit`, `minPaymentOf`, `MoneyRules`, `moneyRulesOf`, `KRW_MONEY_RULES`
- [ ] `src/schemas/currency-prices.ts` → `lib/src/schemas/currency-prices.dart` (11): `productCurrencyPriceSchema`, `productCurrencyPricesSchema`, `ProductCurrencyPrice`, `shippingCurrencyPriceSchema`, `shippingCurrencyPricesSchema`, `storedShippingCurrencyPriceSchema`, `storedProductCurrencyPriceSchema`, `additionalCurrencyPriceSchema`, `additionalCurrencyPricesSchema`, `AdditionalCurrencyPrice`, `storedAdditionalCurrencyPriceSchema`
- [ ] `src/schemas/customer.ts` → `lib/src/schemas/customer.dart` (28): `customerSortSchema`, `CustomerSort`, `customerListQuerySchema`, `customerStatsSchema`, `customerSummarySchema`, `CustomerSummary`, `customerAddressSchema`, `consentKindSchema`, `ConsentKind`, `consentActionSchema`, `ConsentAction`, `consentSourceSchema`, `ConsentSource`, `customerConsentSchema`, `CustomerConsent`, `customerConsentStateSchema`, `CustomerConsentState`, `customerConsentsSchema`, `CustomerConsents`, `customerConsentListQuerySchema`, `customerDetailSchema`, `CustomerDetail`, `customerOrderSchema`, `CustomerOrder`, `withdrawCustomerRequestSchema`, `WithdrawCustomerRequest`, `customerWithdrawalBlockedDetailsSchema`, `CustomerWithdrawalBlockedDetails`
- [ ] `src/schemas/customer-delegation.ts` → `lib/src/schemas/customer-delegation.dart` (4): `customerDelegationRequestSchema`, `CustomerDelegationRequest`, `customerDelegationSchema`, `CustomerDelegation`
- [ ] `src/schemas/fulfillment.ts` → `lib/src/schemas/fulfillment.dart` (45): `fulfillmentTypeSchema`, `FulfillmentType`, `fulfillmentTypeResponseSchema`, `FulfillmentRule`, `FULFILLMENT_RULES`, `fulfillmentTypeOf`, `fulfillmentRuleOf`, `FULFILLMENT_METHODS`, `fulfillmentMethodSchema`, `FulfillmentMethod`, `FulfillmentMethodRule`, `FULFILLMENT_METHOD_RULES`, `FULFILLMENT_METHODS_BY_TYPE`, `defaultFulfillmentMethodOf`, `fulfillmentMethodsOf`, `fulfillmentMethodOf`, `requiresShipping`, `requiresCollection`, `NO_SHIPPING_BUNDLE_KEY`, `deliveryTypeSchema`, `DeliveryType`, `productFulfillmentCreateSchema`, `ProductFulfillmentCreate`, `ProductFulfillmentCreateInput`, `productFulfillmentUpdateSchema`, `ProductFulfillmentUpdate`, `productFulfillmentSchema`, `ProductFulfillment`, `ProductFulfillmentOf`, `UnknownFulfillment`, `openFulfillmentUnion`, `productFulfillmentResponseSchema`, `ProductFulfillmentView`, `pickupLocationSnapshotSchema`, `PickupLocationSnapshot`, `orderItemFulfillmentSnapshotSchema`, `OrderItemFulfillmentSnapshot`, `orderItemFulfillmentSnapshotResponseSchema`, `OrderItemFulfillmentSnapshotView`, `MAX_PICKUP_LOCATIONS`, `pickupLocationSchema`, `PickupLocation`, `pickupLocationRequestSchema`, `PickupLocationRequest`, `PickupLocationRequestInput`
- [ ] `src/schemas/inventory.ts` → `lib/src/schemas/inventory.dart` (32): `inventoryAdjustmentReasonSchema`, `InventoryAdjustmentReason`, `inventoryLocationSchema`, `InventoryLocation`, `inventoryLocationRequestSchema`, `InventoryLocationRequest`, `inventoryLevelSchema`, `InventoryLevel`, `inventoryLevelListQuerySchema`, `InventoryLevelListQuery`, `inventoryLevelPageSchema`, `InventoryLevelPage`, `inventoryMovementKindSchema`, `InventoryMovementKind`, `inventoryMovementSchema`, `InventoryMovement`, `inventoryMovementListQuerySchema`, `InventoryMovementListQuery`, `inventoryMovementPageSchema`, `InventoryMovementPage`, `MAX_INVENTORY_OPERATION_LINES`, `inventoryAdjustmentLineSchema`, `inventoryAdjustmentRequestSchema`, `InventoryAdjustmentRequest`, `inventoryTransferRequestSchema`, `InventoryTransferRequest`, `inventoryOperationResultSchema`, `InventoryOperationResult`, `claimCollectCompleteRequestSchema`, `ClaimCollectCompleteRequest`, `claimRedeliveryRequestSchema`, `ClaimRedeliveryRequest`
- [ ] `src/schemas/locale.ts` → `lib/src/schemas/locale.dart` (3): `normalizeLocale`, `DEFAULT_STORE_LOCALE`, `localeCodeSchema`
- [ ] `src/schemas/login.ts` → `lib/src/schemas/login.dart` (13): `loginProviderSchema`, `LoginProvider`, `loginProviderStatusSchema`, `LoginProviderStatus`, `loginSettingsSchema`, `LoginSettings`, `updateLoginSettingsRequestSchema`, `UpdateLoginSettingsRequest`, `saveLoginProviderRequestSchema`, `SaveLoginProviderRequest`, `updateLoginProviderRequestSchema`, `loginProviderTestSchema`, `LoginProviderTest`
- [ ] `src/schemas/market.ts` → `lib/src/schemas/market.dart` (8): `marketSchema`, `Market`, `createMarketRequestSchema`, `CreateMarketRequest`, `CreateMarketRequestInput`, `updateMarketRequestSchema`, `UpdateMarketRequest`, `UpdateMarketRequestInput`
- [ ] `src/schemas/misc.ts` → `lib/src/schemas/misc.dart` (66): `inquirySchema`, `Inquiry`, `customerInquiryCategorySchema`, `CustomerInquiryCategory`, `sellerCustomerInquirySchema`, `SellerCustomerInquiry`, `inquiryListQuerySchema`, `customerInquiryListQuerySchema`, `settlementStatusSchema`, `SettlementStatus`, `settlementSummarySchema`, `SettlementSummary`, `settlementDetailSchema`, `SettlementDetail`, `settlementWithDetailsSchema`, `SettlementWithDetails`, `settlementListQuerySchema`, `settlementDetailQuerySchema`, `SettlementListParams`, `eventTypeSchema`, `EventType`, `webhookStatusSchema`, `WebhookStatus`, `webhookSchema`, `Webhook`, `webhookCreatedSchema`, `WebhookCreated`, `webhookSecretRotatedSchema`, `WebhookSecretRotated`, `webhookDeliveryStatusSchema`, `WebhookDeliveryStatus`, `webhookDeliveryErrorCodeSchema`, `WebhookDeliveryErrorCode`, `WEBHOOK_FAILURE_REASONS`, `WebhookFailureReason`, `webhookFailureReasonSchema`, `WEBHOOK_RESOURCE_TYPES`, `WebhookResourceType`, `webhookResourceTypeSchema`, `webhookDeliveryResourceSchema`, `WebhookDeliveryResource`, `webhookRequestHeaderSchema`, `WebhookRequestHeader`, `webhookDeliverySchema`, `WebhookDelivery`, `WEBHOOK_PAYLOAD_EXCERPT_MAX_BYTES`, `webhookDeliveryDetailSchema`, `WebhookDeliveryDetail`, `webhookDeliveryListQuerySchema`, `WebhookDeliveryListParams`, `webhookRedeliverFailedResultSchema`, `WebhookRedeliverFailedResult`, `webhookTestRequestSchema`, `WebhookTestRequest`, `webhookTestResultSchema`, `WebhookTestResult`, `webhookRequestSchema`, `WebhookRequest`, `reviewSchema`, `Review`, `reviewSortSchema`, `ReviewSort`, `ReviewListParams`, `reviewListQuerySchema`, `reviewReportResultSchema`, `ReviewReportResult`
- [ ] `src/schemas/order.ts` → `lib/src/schemas/order.dart` (52): `orderSummarySchema`, `OrderSummary`, `shippingAddressSchema`, `ShippingAddress`, `orderItemFulfillmentSchema`, `OrderItemFulfillment`, `orderItemSchema`, `OrderItem`, `orderDiscountSchema`, `OrderDiscount`, `orderSchema`, `Order`, `orderSummaryPageSchema`, `OrderSummaryPage`, `orderItemPageSchema`, `OrderItemPage`, `orderListQuerySchema`, `orderItemListQuerySchema`, `OrderListParams`, `OrderItemListParams`, `deliveryMethodSchema`, `DeliveryMethod`, `dispatchRequestSchema`, `DispatchRequest`, `deliveryInfoSchema`, `DeliveryInfo`, `trackingStageResponseSchema`, `deliveryStatusSchema`, `DeliveryStatus`, `trackingUpdateResultSchema`, `TrackingUpdateResult`, `carrierSchema`, `Carrier`, `holdOrderItemRequestSchema`, `HoldOrderItemRequest`, `cancelBySellerRequestSchema`, `CancelBySellerRequest`, `fulfillRequestSchema`, `FulfillRequest`, `fulfillBulkRequestSchema`, `FulfillBulkRequest`, `cancelBySellerResultSchema`, `CancelBySellerResult`, `sellerCancelPreviewSchema`, `SellerCancelPreview`, `orderItemMemoResultSchema`, `OrderItemMemoResult`, `purchaseDecisionRequestResultSchema`, `PurchaseDecisionRequestResult`, `purchaseDecisionExtendResultSchema`, `PurchaseDecisionExtendResult`, `addressChangeRequestListSchema`
- [ ] `src/schemas/payment.ts` → `lib/src/schemas/payment.dart` (108): `pgProviderSchema`, `PgProvider`, `pgProviderResponseSchema`, `DEDICATED_EASY_PAY_PROVIDER`, `pgPaymentMethodSchema`, `PgPaymentMethod`, `easyPayProviderSchema`, `EasyPayProvider`, `easyPayProviderResponseSchema`, `pgEnvironmentSchema`, `PgEnvironment`, `pgVerificationResultSchema`, `PgVerificationResult`, `TOSS_WIDGET_CLIENT_KEY_PATTERN`, `TOSS_WIDGET_SECRET_KEY_PATTERN`, `TOSS_WIDGET_KEY_MESSAGE`, `tossPaymentsCredentialsInputSchema`, `TossPaymentsCredentialsInput`, `PORTONE_MIN_CHANNELS`, `PORTONE_MAX_CHANNELS`, `PORTONE_CHANNEL_NAME_MAX_LENGTH`, `portOneChannelSchema`, `PortOneChannel`, `portOneCredentialsInputSchema`, `PortOneCredentialsInput`, `KAKAOPAY_TEST_CID`, `kakaoPayCredentialsInputSchema`, `KakaoPayCredentialsInput`, `naverPayCredentialsInputSchema`, `NaverPayCredentialsInput`, `PAYPAL_CURRENCIES`, `payPalCredentialsInputSchema`, `PayPalCredentialsInput`, `upsertTossPaymentsProviderRequestSchema`, `UpsertTossPaymentsProviderRequest`, `upsertPortOneProviderRequestSchema`, `UpsertPortOneProviderRequest`, `upsertKakaoPayProviderRequestSchema`, `UpsertKakaoPayProviderRequest`, `upsertNaverPayProviderRequestSchema`, `UpsertNaverPayProviderRequest`, `upsertPayPalProviderRequestSchema`, `UpsertPayPalProviderRequest`, `updatePaymentProviderRequestSchema`, `UpdatePaymentProviderRequest`, `verifyPaymentProviderRequestSchema`, `VerifyPaymentProviderRequest`, `updatePaymentSettingsRequestSchema`, `UpdatePaymentSettingsRequest`, `maskedSecretSchema`, `MaskedSecret`, `paymentCredentialSetSchema`, `PaymentCredentialSet`, `liveGateConditionCodeSchema`, `LiveGateConditionCode`, `liveGateConditionSchema`, `LiveGateCondition`, `liveGateSchema`, `LiveGate`, `liveGateErrorDetailsSchema`, `LiveGateErrorDetails`, `paymentProviderSchema`, `PaymentProvider`, `PAYMENT_ROUTING_EXCLUSION_CODES`, `KnownPaymentRoutingExclusion`, `paymentFailureWarningSchema`, `PaymentFailureWarning`, `paymentSettingsSchema`, `PaymentSettings`, `paymentProviderVerificationSchema`, `PaymentProviderVerification`, `salesReportGroupBySchema`, `SalesReportGroupBy`, `salesReportQuerySchema`, `SalesReportParams`, `salesTotalsSchema`, `SalesTotals`, `salesReportRowSchema`, `SalesReportRow`, `salesReportCurrencySchema`, `SalesReportCurrency`, `salesReportSchema`, `SalesReport`, `paymentRecordStatusSchema`, `PaymentRecordStatus`, `paymentAttemptStatusSchema`, `CASH_RECEIPT_STATUS_VALUES`, `KnownCashReceiptStatus`, `cashReceiptSchema`, `CashReceipt`, `paymentRecordSchema`, `PaymentRecord`, `paymentRecordPageSchema`, `PaymentRecordPage`, `paymentAttemptRecordSchema`, `PaymentAttemptRecord`, `paymentRefundRecordSchema`, `PaymentRefundRecord`, `paymentRecordDetailSchema`, `PaymentRecordDetail`, `paymentListQuerySchema`, `PaymentListParams`, `setPlatformTestKeysRequestSchema`, `SetPlatformTestKeysRequest`, `paymentStatusProviderSchema`, `PaymentStatusProvider`, `paymentStatusSchema`, `PaymentStatus`
- [ ] `src/schemas/plans.ts` → `lib/src/schemas/plans.dart` (6): `planEntitlementsSchema`, `PlanEntitlementValues`, `publicPlanSchema`, `PublicPlan`, `publicPlansSchema`, `PublicPlans`
- [ ] `src/schemas/points.ts` → `lib/src/schemas/points.dart` (48): `POINT_REVIEW_REWARD_MAX`, `POINT_EXPIRY_DAYS_MIN`, `POINT_EXPIRY_DAYS_MAX`, `POINT_EARN_RATE_BP_MAX`, `pointEarnRateBpSchema`, `reviewRewardPolicySchema`, `ReviewRewardPolicy`, `purchaseEarnPolicySchema`, `PurchaseEarnPolicy`, `POINT_USE_UNITS`, `pointUsePolicySchema`, `PointUsePolicy`, `pointPolicySchema`, `PointPolicy`, `POINT_POLICY_DEFAULTS`, `resolvePointPolicy`, `pointEarningEnabled`, `purchaseEarnRateOf`, `pointEarnOf`, `reviewRewardPointOf`, `pointExpiresAtOf`, `POINT_LOT_SOURCES`, `PointLotSource`, `POINT_ENTRY_TYPES`, `PointEntryType`, `pointPolicyNoticeSchema`, `PointPolicyNotice`, `storePointPolicySchema`, `StorePointPolicy`, `updatePointPolicyRequestSchema`, `UpdatePointPolicyRequest`, `responsePointEntryTypeSchema`, `pointEntrySchema`, `PointEntry`, `pointLotSchema`, `PointLot`, `customerPointsSchema`, `CustomerPoints`, `pointHistoryQuerySchema`, `PointHistoryQuery`, `POINT_ADJUSTMENT_MAX`, `pointAdjustmentRequestSchema`, `PointAdjustmentRequest`, `pointAdjustmentResultSchema`, `PointAdjustmentResult`, `PointLotUsage`, `pointRestoreExpiresAtOf`, `splitRefund`
- [ ] `src/schemas/product.ts` → `lib/src/schemas/product.dart` (75): `productStatusSchema`, `ProductStatus`, `productSummarySchema`, `ProductSummary`, `optionValueSchema`, `OptionValue`, `optionGroupSchema`, `OptionGroup`, `productVariantSchema`, `ProductVariant`, `MAX_OPTION_GROUPS`, `MAX_VALUES_PER_GROUP`, `MAX_VARIANTS`, `MAX_ADDON_GROUPS`, `MAX_CUSTOM_INPUTS`, `MAX_CUSTOM_INPUT_LENGTH`, `VARIANT_COUNT_WARNING`, `optionSortSchema`, `OptionSort`, `addonValueSchema`, `AddonValue`, `addonGroupSchema`, `AddonGroup`, `CUSTOM_INPUT_TYPES`, `customInputSchema`, `CustomInput`, `CUSTOM_INPUT_FORBIDDEN_WORDS`, `customInputLabelForbiddenWord`, `addonValueRequestSchema`, `AddonValueRequest`, `addonGroupRequestSchema`, `AddonGroupRequest`, `customInputRequestSchema`, `CustomInputRequest`, `optionSelectionSchema`, `OptionSelection`, `customInputValueSchema`, `CustomInputValue`, `discountSchema`, `Discount`, `productSchema`, `Product`, `MAX_PRODUCT_IMAGES`, `productImageUrlSchema`, `ProductImageRejection`, `productImageRejection`, `optionValueRequestSchema`, `OptionValueRequest`, `optionGroupRequestSchema`, `OptionGroupRequest`, `productVariantRequestSchema`, `ProductVariantRequest`, `optionModelRequestSchema`, `OptionModelRequest`, `optionModelSchema`, `OptionModel`, `VARIANT_STOCK_EXCLUSIVE_MESSAGE`, `variantStockRequestSchema`, `VariantStockRequest`, `variantStockSchema`, `VariantStock`, `productCreateRequestSchema`, `ProductCreateRequest`, `ProductCreateRequestInput`, `productReplaceRequestSchema`, `ProductReplaceRequest`, `ProductReplaceRequestInput`, `productPatchRequestSchema`, `ProductPatchRequest`, `productSortSchema`, `ProductSort`, `ProductListParams`, `productListQuerySchema`, `discountRequestSchema`, `DiscountRequest`
- [ ] `src/schemas/product-info.ts` → `lib/src/schemas/product-info.dart` (33): `infoFieldSourceSchema`, `InfoFieldSource`, `infoSchemaFieldSchema`, `InfoSchemaField`, `infoSchemaSchema`, `InfoSchema`, `platformCodeSchema`, `PlatformCode`, `PLATFORM_CODE_SETS`, `productNoticeSchema`, `ProductNotice`, `MAX_NOTICE_VALUE_LENGTH`, `productNoticeRequestSchema`, `ProductNoticeRequest`, `CERTIFICATION_STATUSES`, `CertificationStatus`, `MAX_CERTIFICATION_ITEMS`, `productCertificationsSchema`, `ProductCertifications`, `productCertificationsRequestSchema`, `ProductCertificationsRequest`, `ProductCertificationsRequestInput`, `MAX_PRODUCT_INFO_SECTIONS`, `MAX_INFO_SECTION_TITLE`, `infoSectionSchema`, `InfoSection`, `infoSectionRequestSchema`, `InfoSectionRequest`, `InfoSectionRequestInput`, `infoSectionLocalizationSchema`, `InfoSectionLocalization`, `infoSectionLocalizationRequestSchema`, `InfoSectionLocalizationRequest`
- [ ] `src/schemas/product-localization.ts` → `lib/src/schemas/product-localization.dart` (5): `productLocalizationSchema`, `ProductLocalization`, `productLocalizationRequestSchema`, `ProductLocalizationRequest`, `productLocalizationNeedsTranslation`
- [ ] `src/schemas/promotion.ts` → `lib/src/schemas/promotion.dart` (42): `couponKindSchema`, `CouponKind`, `couponBenefitSchema`, `CouponBenefit`, `couponConditionsSchema`, `CouponConditions`, `COUPON_CONDITIONS_DEFAULTS`, `COUPON_TARGET_LIST_MAX`, `couponTargetSchema`, `CouponTarget`, `COUPON_TARGET_ALL`, `couponRuleSchema`, `CouponRule`, `couponRejectReasonSchema`, `CouponRejectReason`, `MIN_PAYMENT_AMOUNT`, `PricingLine`, `PricingCoupon`, `PricingDelivery`, `PricingPoints`, `PointRejectReason`, `PricingInput`, `CouponAllocation`, `PricingLineResult`, `PricingCouponResult`, `PricingBundleResult`, `PricingResult`, `couponDiscountOf`, `allocateByWeight`, `isCouponTargetLine`, `quotePricing`, `pointUseOf`, `AppliedCouponSnapshot`, `CouponSettlementLine`, `CouponSettlementState`, `CouponSettlementInput`, `CouponSettlementEntry`, `CouponSettlementResult`, `NO_COUPON_SETTLEMENT`, `settleCouponShortfall`, `proratedPaidRefundBase`, `proratedPointRefund`
- [ ] `src/schemas/refund-policy.ts` → `lib/src/schemas/refund-policy.dart` (13): `currencyRefundFeesSchema`, `CurrencyRefundFees`, `refundPolicySchema`, `RefundPolicy`, `REFUND_POLICY_DEFAULTS`, `refundPolicyPatchSchema`, `RefundPolicyPatch`, `productRefundPolicyPatchSchema`, `RefundPolicyProductInput`, `resolveRefundPolicy`, `productRefundPolicyOverride`, `REFUND_POLICY_DELIVERY_FEE_KEYS`, `proratedRefundBase`
- [ ] `src/schemas/saved-option-set.ts` → `lib/src/schemas/saved-option-set.dart` (32): `MAX_SAVED_OPTION_SETS`, `MAX_SAVED_OPTION_SET_NAME`, `optionGroupKindSchema`, `OptionGroupKind`, `savedOptionValueSchema`, `savedOptionGroupSchema`, `SavedOptionGroup`, `savedCustomInputSchema`, `SavedCustomInput`, `savedOptionSetSchema`, `SavedOptionSet`, `savedOptionValueRequestSchema`, `savedOptionGroupRequestSchema`, `SavedOptionGroupRequest`, `savedCustomInputRequestSchema`, `savedOptionSetRequestSchema`, `SavedOptionSetRequest`, `SavedOptionSetRequestInput`, `savedOptionSetFromProductRequestSchema`, `SavedOptionSetFromProductRequest`, `SavedOptionSetFromProductRequestInput`, `savedOptionSetFromProductResultSchema`, `SavedOptionSetFromProductResult`, `savedOptionSetCompositionSchema`, `savedOptionSetSortSchema`, `SavedOptionSetSort`, `SavedOptionSetListParams`, `savedOptionSetListQuerySchema`, `savedOptionSetLocalizationSchema`, `SavedOptionSetLocalization`, `savedOptionSetLocalizationRequestSchema`, `SavedOptionSetLocalizationRequest`
- [ ] `src/schemas/scope.ts` → `lib/src/schemas/scope.dart` (7): `scopeAccessSchema`, `ScopeAccess`, `STORE_SCOPE_RESOURCES`, `StoreScopeResource`, `storeScopeResourceSchema`, `isStoreScope`, `STORE_ROLE_SCOPES`
- [ ] `src/schemas/scope-descriptions.ts` → `lib/src/schemas/scope-descriptions.dart` (2): `SCOPE_DESCRIPTIONS`, `describeScope`
- [ ] `src/schemas/shipping-policy.ts` → `lib/src/schemas/shipping-policy.dart` (23): `currencyShippingPolicySchema`, `CurrencyShippingPolicy`, `shippingPolicySchema`, `ShippingPolicy`, `SHIPPING_POLICY_DEFAULTS`, `shippingPolicyPatchSchema`, `ShippingPolicyPatch`, `resolveShippingPolicy`, `remoteAreaSchema`, `RemoteArea`, `REMOTE_AREA_ZIP_RANGES`, `remoteAreaOf`, `remoteAreaLabelOf`, `remoteSurchargeOf`, `DeliveryBundleProduct`, `deliveryBundleKeyOf`, `DeliveryFeeLine`, `deliveryFeeWaiverSchema`, `DeliveryFeeWaiver`, `DeliveryBundleQuote`, `DeliveryQuote`, `DeliveryQuoteInput`, `quoteDelivery`
- [ ] `src/schemas/starter.ts` → `lib/src/schemas/starter.dart` (22): `storeIndustrySchema`, `StoreIndustry`, `brandBriefProductSourceSchema`, `BrandBriefProductSource`, `BRAND_BRIEF_MAX_REFERENCES`, `brandBriefReferenceSchema`, `BrandBriefReference`, `brandBriefSchema`, `BrandBrief`, `putBrandBriefRequestSchema`, `PutBrandBriefRequest`, `brandBriefViewSchema`, `BrandBriefView`, `STARTER_STAGES`, `starterStageSchema`, `StarterStage`, `STARTER_SELLER_TASKS`, `starterSellerTaskSchema`, `StarterSellerTask`, `starterStoreInfoFieldSchema`, `starterStatusSchema`, `StarterStatus`
- [ ] `src/schemas/stay.ts` → `lib/src/schemas/stay.dart` (15): `calendarDateSchema`, `MAX_STAY_NIGHTS`, `MAX_CALENDAR_DAYS`, `inventoryModeSchema`, `InventoryMode`, `stayRangeSchema`, `StayRange`, `staySnapshotSchema`, `StaySnapshot`, `nightsOf`, `calendarDaySchema`, `CalendarDay`, `calendarQuerySchema`, `setCalendarRequestSchema`, `SetCalendarRequest`
- [ ] `src/schemas/store.ts` → `lib/src/schemas/store.dart` (40): `STORE_CODE_PATTERN`, `RESERVED_STORE_CODES`, `isReservedStoreCode`, `storeCodeSchema`, `isWebOrigin`, `analyticsOriginSchema`, `MAX_ANALYTICS_ALLOWED_ORIGINS`, `MAX_AUTO_TRANSITION_DAYS`, `policyVersionSchema`, `policyDocumentUrlSchema`, `BUSINESS_NUMBER_PATTERN`, `normalizeBusinessNumber`, `businessNumberSchema`, `BUSINESS_INFO_MAX_LENGTH`, `businessInfoPatchShape`, `businessInfoResponseShape`, `updateStoreRequestSchema`, `UpdateStoreRequest`, `storeSchema`, `Store`, `storeMemberSchema`, `StoreMember`, `invitationDeliveryStatusSchema`, `InvitationDeliveryStatus`, `invitationSchema`, `Invitation`, `inviteMemberRequestSchema`, `InviteMemberRequest`, `updateMemberRoleRequestSchema`, `UpdateMemberRoleRequest`, `invitationListQuerySchema`, `storeMemberRoleUpdatedSchema`, `StoreMemberRoleUpdated`, `addressTypeSchema`, `AddressType`, `sellerAddressListQuerySchema`, `sellerAddressSchema`, `SellerAddress`, `sellerAddressRequestSchema`, `SellerAddressRequest`
- [ ] `src/schemas/storefront-hosting.ts` → `lib/src/schemas/storefront-hosting.dart` (186): `STOREFRONT_SLUG_PATTERN`, `RESERVED_STOREFRONT_SLUGS`, `STOREFRONT_EDIT_PREVIEW_SUFFIX`, `STOREFRONT_SHOWCASE_SLUG_PREFIX`, `isShowcaseStorefrontSlug`, `isReservedStorefrontSlug`, `storefrontEditPreviewLabelOf`, `storefrontVersionPreviewLabelOf`, `storefrontSlugSchema`, `STOREFRONT_SLUG_HOLD_DAYS`, `STOREFRONT_CLOSED_SITE_HOLD_DAYS`, `STOREFRONT_SLUG_CHANGE_WINDOW_DAYS`, `STOREFRONT_SLUG_CHANGE_LIMIT`, `STOREFRONT_SITE_CREATE_LIMIT`, `storefrontTemplateSchema`, `StorefrontTemplate`, `storeTemplateSchema`, `StoreTemplate`, `TEMPLATE_STORE_LOCKED_BUSINESS_FIELDS`, `updateStoreTemplateRequestSchema`, `UpdateStoreTemplateRequest`, `storefrontVersionStatusSchema`, `StorefrontVersionStatus`, `storefrontVersionSchema`, `StorefrontVersion`, `storefrontSiteStatusSchema`, `StorefrontSiteStatus`, `storefrontVisibilitySchema`, `StorefrontVisibility`, `storefrontSourceModeSchema`, `storefrontDomainSchema`, `StorefrontDomain`, `storefrontProvisioningSchema`, `StorefrontProvisioning`, `storefrontEditPreviewSchema`, `StorefrontEditPreview`, `storefrontSuspensionSchema`, `StorefrontSuspension`, `storefrontSiteSnapshotSchema`, `StorefrontSiteSnapshot`, `storefrontSiteSchema`, `StorefrontSite`, `storefrontHostingSchema`, `StorefrontHosting`, `storefrontSlugAvailabilitySchema`, `StorefrontSlugAvailability`, `storefrontDeploymentStepSchema`, `StorefrontDeploymentStep`, `storefrontDeploymentLogSchema`, `StorefrontDeploymentLog`, `storefrontDeploymentSchema`, `StorefrontDeployment`, `createStorefrontSiteRequestSchema`, `CreateStorefrontSiteRequest`, `changeStorefrontTemplateRequestSchema`, `ChangeStorefrontTemplateRequest`, `publishStorefrontVersionRequestSchema`, `PublishStorefrontVersionRequest`, `rollbackStorefrontRequestSchema`, `RollbackStorefrontRequest`, `changeStorefrontSlugRequestSchema`, `ChangeStorefrontSlugRequest`, `setStorefrontVisibilityRequestSchema`, `SetStorefrontVisibilityRequest`, `disableStorefrontHostingRequestSchema`, `DisableStorefrontHostingRequest`, `storefrontSlugAvailabilityQuerySchema`, `createStorefrontPreviewLinkRequestSchema`, `CreateStorefrontPreviewLinkRequest`, `storefrontPreviewLinkSchema`, `StorefrontPreviewLink`, `STOREFRONT_PLATFORM_DOMAINS`, `STOREFRONT_PUBLIC_SUFFIXES`, `STOREFRONT_CUSTOM_DOMAIN_LIMIT_DEFAULT`, `STOREFRONT_DOMAIN_DNS_WAIT_DAYS`, `STOREFRONT_DOMAIN_DNS_GRACE_DAYS`, `STOREFRONT_DOMAIN_TXT_LABEL`, `normalizeStorefrontHostname`, `StorefrontHostnameProblem`, `storefrontCustomHostnameProblem`, `storefrontDomainTxtNameOf`, `storefrontCustomDomainStatusSchema`, `StorefrontCustomDomainStatus`, `storefrontDnsRecordSchema`, `StorefrontDnsRecord`, `storefrontSiteDomainSchema`, `StorefrontSiteDomain`, `storefrontSiteDomainsSchema`, `StorefrontSiteDomains`, `addStorefrontDomainRequestSchema`, `AddStorefrontDomainRequest`, `STOREFRONT_EDIT_CAPACITY`, `STOREFRONT_EDIT_IDLE_MINUTES`, `STOREFRONT_EDIT_ACTIVITY_TIMEOUT_MINUTES`, `STOREFRONT_FILE_MAX_BYTES`, `STOREFRONT_WORKSPACE_MAX_BYTES`, `STOREFRONT_FILE_BATCH_MAX`, `STOREFRONT_BLOCKED_PATH_SEGMENTS`, `STOREFRONT_PATH_SEGMENT_PATTERN`, `normalizeStorefrontPath`, `isEditableStorefrontPath`, `storefrontFilePathSchema`, `storefrontFileHashSchema`, `storefrontFileEncodingSchema`, `storefrontEditSessionStatusSchema`, `STOREFRONT_EDIT_START_STAGES`, `storefrontEditSessionSchema`, `StorefrontEditSession`, `storefrontDevLogsSchema`, `StorefrontDevLogs`, `storefrontEditingSchema`, `StorefrontEditing`, `storefrontFileEntrySchema`, `StorefrontFileEntry`, `storefrontFileListSchema`, `StorefrontFileList`, `storefrontFileListQuerySchema`, `storefrontFileContentQuerySchema`, `storefrontFileContentSchema`, `StorefrontFileContent`, `writeStorefrontFilesRequestSchema`, `WriteStorefrontFilesRequest`, `storefrontFileWriteResultSchema`, `StorefrontFileWriteResult`, `storefrontFileConflictDetailsSchema`, `StorefrontFileConflictDetails`, `deleteStorefrontFileRequestSchema`, `DeleteStorefrontFileRequest`, `storefrontFileDeleteResultSchema`, `StorefrontFileDeleteResult`, `moveStorefrontFileRequestSchema`, `MoveStorefrontFileRequest`, `storefrontFileMoveResultSchema`, `StorefrontFileMoveResult`, `STOREFRONT_SEARCH_REGEX_MAX_LENGTH`, `searchStorefrontFilesRequestSchema`, `SearchStorefrontFilesRequest`, `storefrontFileSearchResultSchema`, `StorefrontFileSearchResult`, `runStorefrontCheckRequestSchema`, `RunStorefrontCheckRequest`, `storefrontCheckStatusSchema`, `StorefrontCheckStatus`, `STOREFRONT_CHECK_TERMINAL_STATUSES`, `storefrontCheckSchema`, `StorefrontCheck`, `storefrontRuleSeveritySchema`, `StorefrontRuleSeverity`, `storefrontRuleResultSchema`, `StorefrontRuleResult`, `storefrontVerifyReportSchema`, `StorefrontVerifyReport`, `storefrontBuildStatusSchema`, `StorefrontBuildStatus`, `STOREFRONT_BUILD_TERMINAL_STATUSES`, `STOREFRONT_BUILD_STAGES`, `storefrontDependencyFindingSchema`, `StorefrontDependencyFinding`, `storefrontBuildDependenciesSchema`, `StorefrontBuildDependencies`, `storefrontBuildSchema`, `StorefrontBuild`, `storefrontBuildListQuerySchema`, `createStorefrontVersionRequestSchema`, `CreateStorefrontVersionRequest`, `storefrontVersionCreatedSchema`, `StorefrontVersionCreated`, `createStorefrontEditPreviewLinkRequestSchema`, `CreateStorefrontEditPreviewLinkRequest`, `STOREFRONT_SOURCE_PART_BYTES`, `STOREFRONT_SOURCE_BLOB_BATCH_MAX`, `STOREFRONT_WORKSPACE_MAX_FILES`, `storefrontSourceRefSchema`, `storefrontSourceSchema`, `StorefrontSource`, `storefrontSourceArchiveQuerySchema`, `storefrontSourceArchivePartSchema`, `StorefrontSourceArchivePart`, `uploadStorefrontSourceBlobsRequestSchema`, `UploadStorefrontSourceBlobsRequest`, `storefrontSourceBlobsResultSchema`, `StorefrontSourceBlobsResult`, `replaceStorefrontSourceRequestSchema`, `ReplaceStorefrontSourceRequest`, `storefrontSourceReplacedSchema`, `StorefrontSourceReplaced`
- [ ] `src/schemas/subscription.ts` → `lib/src/schemas/subscription.dart` (14): `planCodeSchema`, `PlanCode`, `responsePlanCodeSchema`, `ResponsePlanCode`, `subscriptionStatusSchema`, `SubscriptionStatus`, `subscriptionLimitsSchema`, `SubscriptionLimits`, `subscriptionUsageSchema`, `SubscriptionUsage`, `storeSubscriptionSchema`, `StoreSubscription`, `planErrorDetailsSchema`, `PlanErrorDetails`
- [ ] `src/schemas/telemetry.ts` → `lib/src/schemas/telemetry.dart` (5): `mcpRuleResultSchema`, `McpRuleResult`, `MCP_TELEMETRY_MAX_RESULTS`, `mcpToolEventSchema`, `McpToolEvent`
- [ ] `src/schemas/upload.ts` → `lib/src/schemas/upload.dart` (11): `uploadPurposeSchema`, `UploadPurpose`, `UploadPurposeLimit`, `UPLOAD_PURPOSE_LIMITS`, `uploadExtensionOf`, `UploadRejection`, `uploadRejection`, `uploadRequestSchema`, `UploadRequest`, `uploadTicketSchema`, `UploadTicket`
- [ ] `src/schemas/webhook-event.ts` → `lib/src/schemas/webhook-event.dart` (37): `orderWebhookEventDataSchema`, `OrderWebhookEventData`, `orderFulfilledWebhookEventDataSchema`, `OrderFulfilledWebhookEventData`, `orderCanceledWebhookEventDataSchema`, `OrderCanceledWebhookEventData`, `claimWebhookEventDataSchema`, `ClaimWebhookEventData`, `inquiryWebhookEventDataSchema`, `InquiryWebhookEventData`, `reviewWebhookEventDataSchema`, `ReviewWebhookEventData`, `productOutOfStockWebhookEventDataSchema`, `ProductOutOfStockWebhookEventData`, `inventoryChangedWebhookEventDataSchema`, `InventoryChangedWebhookEventData`, `orderWebhookEventSchema`, `orderFulfilledWebhookEventSchema`, `orderCanceledWebhookEventSchema`, `claimWebhookEventSchema`, `inquiryWebhookEventSchema`, `reviewWebhookEventSchema`, `productOutOfStockWebhookEventSchema`, `inventoryChangedWebhookEventSchema`, `flowNotificationWebhookEventDataSchema`, `flowNotificationWebhookEventSchema`, `flowStateChangedWebhookEventDataSchema`, `flowStateChangedWebhookEventSchema`, `webhookEventSchema`, `WebhookEvent`, `WebhookEventType`, `WebhookEventOf`, `KNOWN_WEBHOOK_EVENT_TYPES`, `unknownWebhookEventSchema`, `UnknownWebhookEvent`, `ParsedWebhookEvent`, `parseWebhookEvent`
- [ ] `src/webhook-headers.ts` → `lib/src/webhook-headers.dart` (7): `WEBHOOK_DEFAULT_TOLERANCE_SEC`, `WEBHOOK_DELIVERY_ID_HEADER`, `WEBHOOK_EVENT_ID_HEADER`, `WEBHOOK_EVENT_TYPE_HEADER`, `WEBHOOK_HEADERS`, `WEBHOOK_SIGNATURE_HEADER`, `WEBHOOK_USER_AGENT`
- [ ] `src/client.ts` → `lib/src/client.dart` (3): `StoreClient`, `StoreClientOptions`, `createStoreClient`
- [ ] `src/http.ts` → `lib/src/http.dart` (7): `Query`, `TokenSource`, `APPROVAL_ALREADY_DECIDED_CODE`, `APPROVAL_REQUIRED_CODE`, `ApiError`, `ApprovalPendingError`, `buildQuery`
- [ ] `src/oauth.ts` → `lib/src/oauth.dart` (6): `buildAuthorizeUrl`, `createPkcePair`, `exchangeAuthorizationCode`, `OAuthTokenResponse`, `oauthTokenResponseSchema`, `refreshUserToken`
- [ ] `src/session.ts` → `lib/src/session.dart` (7): `AuthorizeOptions`, `createStoreSession`, `SessionStorage`, `STORE_SESSION_KEYS`, `StoreAuthServer`, `StoreSession`, `StoreSessionOptions`

## `@sayren/store-sdk/server` → `server.dart`

### export

총 18개.

- [ ] `src/member-delegation.ts` → `lib/src/member-delegation.dart` (3): `DelegatedMemberToken`, `delegateMember`, `MemberDelegationError`
- [ ] `src/webhook-headers.ts` → `lib/src/webhook-headers.dart` (7): `WEBHOOK_DEFAULT_TOLERANCE_SEC`, `WEBHOOK_DELIVERY_ID_HEADER`, `WEBHOOK_EVENT_ID_HEADER`, `WEBHOOK_EVENT_TYPE_HEADER`, `WEBHOOK_HEADERS`, `WEBHOOK_SIGNATURE_HEADER`, `WEBHOOK_USER_AGENT`
- [ ] `src/webhook-signature.ts` → `lib/src/webhook-signature.dart` (8): `ParsedWebhookSignature`, `parseWebhookSignatureHeader`, `SignWebhookPayloadOptions`, `signWebhookPayload`, `VerifyWebhookSignatureOptions`, `verifyWebhookSignature`, `WebhookSignatureFailureReason`, `WebhookSignatureVerification`

---

## 플랫폼 차이

공개 이름과 시그니처는 위 목록 그대로 두고, 브라우저에 기대는 내부 동작만 Flutter 환경에 맞춘다.

| 이름 | Node 동작 | Dart 동작 |
|---|---|---|
| `createPayments().start`·`retry`·`open`·`result` | 팝업·리디렉트로 PG 결제창, 복귀 주소에서 결과 읽기 | 인앱 WebView로 `payUrl`을 열고 복귀 주소 진입을 가로채 같은 결과를 만든다 |
| `PaymentsEnv`·`AnalyticsEnv` | 브라우저 의존부 주입 | 같은 이름으로 Flutter 의존부 주입 |
| `createAnalytics` | 쿠키(`sy_vid`·`sy_sid`)·자동 페이지뷰 | 앱 저장소에 같은 ID를 둔다. `ids()` 값 사용법은 같다 |
| `analyticsIdsFromCookie` | SSR에서 Cookie 헤더 파싱 | 같은 입력·출력(Dart 서버에서 쓴다) |
| `createStorefrontSession`·`createStoreSession`의 `refresh` | 탭 내 single-flight + `navigator.locks` | 프로세스 내 single-flight |
| `createStorefrontAuth().idp`·`createStoreSession().authorize` | 브라우저 리디렉트 후 콜백 URL | 같은 PKCE·state 흐름, 콜백은 앱 딥링크로 받는다 |
| `uploads.upload` | `Blob`·`File` | 바이트와 파일 이름 |

## 미정 사항

- pub.dev 게시 여부와 버전 정책
- 모델 클래스 작성 방식(수기 작성 또는 Node 스키마 기반 코드 생성)
- 지원 플랫폼 범위(iOS·Android 외 Web·데스크톱)
