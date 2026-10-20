# sayren-flutter Roadmap

sayren 공개 API를 Flutter(Dart)에서 쓰는 SDK다. Node SDK(`@sayren/storefront-sdk`·`@sayren/store-sdk`)와 이름·목록이 같은 SDK를 만든다.
엔트리포인트, export, 팩토리, 옵션 필드, 네임스페이스, 메서드 이름은 Node SDK와 1:1로 대응한다. 예외는 두 가지다.
Node에서 `@deprecated`인 이름은 만들지 않고, Dart에 없는 언어 기능을 대신하는 이름은 아래 설계 규칙이 정한 것만 더한다.

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
| 네임스페이스·메서드 | `client.catalog.searchProducts(params)` | `client.catalog.searchProducts(params)` |
| 비동기 | `Promise<T>` · `Promise<void>` | `Future<T>` · `Future<void>` |
| 오류 | `ApiError(status, code, message, traceId, body, details, docs)` | 같은 필드의 `ApiError` |
| `fetch` 옵션 | `fetch?: typeof globalThis.fetch` | `fetch` (HTTP 함수 주입, 이름 그대로) |

`get`·`set`은 Dart 내장 식별자지만 메서드 이름으로 쓸 수 있다. 메서드·네임스페이스·export 이름 2,230개 중 Dart 예약어·`dart:core` 타입과 겹치는 이름은 없다.

## 설계 규칙

### 인자

- export된 옵션·파라미터 인터페이스(`StorefrontClientOptions`, `StartOptions`, `ProductSearchParams` 등)는 같은 이름의 클래스이고, 함수는 그 클래스 인스턴스를 인자로 받는다.

  ```dart
  final client = createStorefrontClient(StorefrontClientOptions(baseUrl: baseUrl, storeCode: storeCode, session: session));
  final page = await client.catalog.searchProducts(ProductSearchParams(keyword: '셔츠', size: 20));
  ```

- export되지 않은 인라인 객체 인자(`getProductCalendar`의 `{ from, to, variantId }`, `getGuestOrder`의 `{ phone, orderPassword }` 등)는 같은 이름의 네임드 인자다.
  - 선택 위치 인자 뒤의 인라인 객체(`claims.approve`의 `{ holdRefund }`, `uploads.upload`의 `{ purpose, filename }`)는 레코드 선택 위치 인자다. Dart는 선택 위치 인자와 네임드 인자를 섞을 수 없다.
  - `string | 객체` 인자(`apps.installations.install`)는 `Object`로 받고 실행 중 형태를 본다. `T & { … }` 원소(`dispatchBulk`)는 `(orderItemId:, dispatch: T)` 레코드다.
  - `Omit<T, …>`·`PageParams & Omit<…>` 인자는 T 클래스 또는 네임드 인자다. 모델·인터페이스 인자의 기본값 `= {}`는 생략 가능 인자로 받고 빈 객체로 바꾼다.
- 위치 인자는 같은 순서의 위치 인자다. Node의 선택 인자(`params?`)는 Dart 선택 위치 인자(`[params]`)이고, 기본값(`input = {}`)도 같다.
- `TokenSource`는 `String` 또는 `String? Function()`을 받는다(Dart에 union이 없어 `Object?`로 받고 실행 중 검사한다).
- nullable이면서 선택인 요청 필드(「null을 주면 지운다」)는 `Nullable<T>?`로 받는다. 생략하면 보내지 않고, `Nullable(null)`이면 null, `Nullable(값)`이면 그 값을 보낸다. 그 밖의 선택 필드는 `T?`이고 null이면 보내지 않는다.

### 타입

- 문자열 리터럴 union과 `z.enum`(`AnalyticsConsent`, `ClaimStatus`, `status: "available"` 등)은 `String`이다. 호출부는 Node처럼 `'granted'`를 넘긴다. 타입 별칭은 `typedef AnalyticsConsent = String`이다.
- 판별 union(`PaymentResult`, `AnalyticsTrackInput` 등)은 같은 이름의 sealed class다. 판별 필드(`status`, `name` 등)는 Node와 같은 이름·문자열 값을 갖는다.
  분기는 Node처럼 판별 필드로 하고, 변형별 필드는 하위 클래스로 읽는다. 하위 클래스 이름은 `{union 이름}{판별 값 PascalCase}`다(`PaymentResultCompleted`, `AnalyticsTrackInputProductView`).
- zod 스키마 상수(`productCardSchema`)는 같은 이름의 스키마 상수다. `parse`, `safeParse`(`success`·`data`·`error`), enum 스키마의 `options`, object 스키마의 `shape`를 제공한다.
- `z.infer` 타입(`ProductCard`)은 같은 이름의 불변 클래스다. 모델은 다음을 갖는다.
  - 기본 생성자: 필드를 네임드 인자로 받고 검증하지 않는다(테스트·미리보기 데이터용). 기본값이 있는 필드는 같은 기본값의 선택 인자, nullable 필드는 `required T?`, 선택 필드는 `T?`(null이면 키 없음)다.
  - `fromJson`: 같은 이름의 스키마로 검증해 만든다(`StorefrontStore.fromJson(json)` = `storefrontStoreSchema.parse(json)`). `Page<T>.fromJson(json, item)`은 항목 스키마를 받는다.
  - `toJson`, 값 비교(`==`), `toString`. 검증한 JSON은 비공개이고 필드는 getter로만 읽는다.
- 스키마 타입 `ZodType`·`ZodObject`·`ZodEnum`·`ZodArray`는 export한다(스키마 상수의 문서와 타입 표기용). 스키마 생성자 모음 `z`는 내부용이다.

- TS로만 쓴 인라인 객체 타입(옵션 필드 `auth: { accessToken? }`, 함수 반환 `analyticsIdsFromCookie` 등)은 같은 필드 이름의 레코드다(`auth: (accessToken: '…')`).
- zod 스키마 안의 익명 객체·union은 클래스다. 응답 JSON의 키 있음·없음과 필드 문서를 그대로 지키려는 것이다. 이름 규칙(생성기 `tool/codegen/ir.mjs`)은 다음과 같다.
  - 객체 필드: `{소유 클래스}{필드 PascalCase}`(`StorefrontStore.market` → `StorefrontStoreMarket`). 배열 항목은 끝에 `Item`, record 값은 `Value`를 붙인다.
  - 판별 union의 형태: `{union}{판별 값 PascalCase}`(`PaymentOptionEasyPay`). 판별 필드가 없는 익명 형태: `{union}Option{n}`.
  - 익명 클래스마다 공개 스키마 상수 `{클래스 camelCase}Schema`를 둔다(`fromJson`과 다른 파일의 스키마가 쓴다).
  - transform으로 바로 다른 모델이 되는 객체(모르는 이행 유형의 입력 등)는 클래스를 두지 않는다.
- intersection(`paymentOptionSchema.and({...})`)은 zod처럼 양쪽을 따로 검증하고, 출력은 형태마다 객체를 합친 판별 union 클래스다.
- 제네릭 익명 타입인 `pageSchema(item)`의 출력은 `Page<T>`(`PageInfo` + `contents`)다.
- 클라이언트 네임스페이스(`client.catalog` 등)는 공개 클래스다. pub 문서에 메서드가 나오게 하려는 것이다. 이름은 `{클라이언트 타입}{네임스페이스 PascalCase}`다(`StorefrontClientCatalog`, `client.me.customerInquiries`는 `StorefrontClientMeCustomerInquiries`). 생성자는 비공개다.

### 검증과 오류

- Node처럼 요청 본문은 보내기 전에, 응답은 받은 뒤에 스키마로 검증한다.
- 클라이언트 메서드는 모두 `async`다. 요청 전 검증 실패도 동기 예외가 아니라 Future 오류로 전달한다(Node는 동기로 던지지만 Dart 관례를 따른다).
- 기본 HTTP(`fetch` 생략)는 클라이언트마다 `http.Client` 하나를 재사용한다.
- 검증 실패는 `ZodError`를 던진다. Node SDK는 `zod`의 `ZodError`를 그대로 던지므로, Dart SDK는 같은 이름의 클래스(`issues`)를 기본 엔트리포인트에서 export한다.
- HTTP 실패는 `ApiError`, 관리 API의 승인 대기(202)는 `ApprovalPendingError`다.

### 세션 저장소

- `SessionStorage`는 Node와 같은 동기 인터페이스(`get`·`set`·`remove`)다. 세션 getter(`accessToken`·`refreshToken`)도 동기다.
- Flutter의 영구 저장소는 비동기이므로 앱 어댑터가 시작할 때 키(`STOREFRONT_SESSION_KEYS`·`STORE_SESSION_KEYS`)를 미리 읽어 메모리에 두고, 쓰기는 메모리에 반영한 뒤 영구 저장소에 비동기로 쓴다.
  어댑터는 Node처럼 앱 소유다. README에 이 어댑터 예제를 둔다.

### 플랫폼 의존부(`*Env`)

`PaymentsEnv`·`AnalyticsEnv`는 Node에서도 브라우저 의존부를 주입하는 자리다. 이름은 같다. `AnalyticsEnv`의 멤버는 Node와 같고, `PaymentsEnv`의 멤버는 WebView 결제창 기준으로 정한다.
순수 로직은 `createAnalyticsWith`·`createPaymentsWith`(env를 받는다)에 두고 대조 하네스가 이 함수를 검사한다. `createAnalytics`·`createPayments`는 Flutter 기본 env를 붙인다.

### 생성

`sayren_storefront_sdk`·`sayren_store_sdk`의 스키마·모델·클라이언트는 `tool/codegen`이 npm `@sayren/storefront-sdk`·`@sayren/store-sdk`(버전 고정)에서 생성한다. 생성 파일은 직접 고치지 않는다.
대상별 설정(손으로 쓴 export, 추가 import, 클라이언트 이름·경로)은 `generate.mjs`의 `TARGETS`다. `node generate.mjs store`처럼 대상 하나만 만들 수 있다.

- 원천: 패키지의 TS 원본(`src`, export 순서·JSDoc·인터페이스·클라이언트 정의)과 런타임 zod 스키마(검증 규칙·기본값·`describe`).
- 실행: `cd tool/codegen && npm install && node generate.mjs`. 끝에 `dart format`을 돌린다.
- Node `@deprecated` export·클라이언트 멤버는 만들지 않는다. `@deprecated` 선택 필드는 스키마가 받되 생성자·getter에 내지 않는다.
- 생성 규칙으로 옮길 수 없는 클라이언트 메서드(스프레드·조건식 본문, `string | 객체` 인자, 업로드 등)는 `tool/codegen/client-overrides.mjs`에 Dart로 쓴다. 키마다 Node 원문을 두어, 원문이 바뀌면 생성기가 멈춘다.
- `zod.dart`는 `sayren_storefront_sdk`가 원본이고 생성기가 `sayren_store_sdk`로 복사한다(Node 두 SDK가 같은 zod를 쓰는 것과 같다).
- 클로저(`refine`·`superRefine`·`transform`·`preprocess`·`trim`)는 `tool/codegen/hooks.mjs`가 Node 함수 원문 → Dart 구현으로 잇는다. 모르는 원문이 나오면 생성기가 멈추고 원문을 보여 준다.
- 생성할 수 없는 함수·클래스·상수(`formatOrderNo`, 통화 함수, `CURRENCIES` 등)는 같은 라이브러리의 `{파일}.manual.dart` part에 손으로 쓴다. 생성기는 빠진 이름을 알린다.
- 손으로 쓰는 파일: `http.dart`, `zod.dart`, `analytics-ids.dart`, `session.dart`, `oauth.dart`(store), `url.dart`(store, WHATWG URL 판정), `*.manual.dart`, 클라이언트 옵션·생성자 템플릿(`tool/codegen/templates/`).
- 생성기는 대조 자료(`tool/parity/generated/`), Dart 대조 표(`tool/parity_generated.dart`), getter 테스트(`test/getters_test.dart`)도 만든다.

### 문서

pub.dev API 문서(dartdoc)로 SDK를 익힐 수 있게 한다.

- 공개 API(클래스·생성자·필드·getter·메서드·상수·typedef)는 모두 `///` 주석을 단다. `public_member_api_docs` lint로 강제한다.
- 원천은 Node SDK의 JSDoc과 스키마 `.describe()` 문장이다. 문장은 하십시오체(제품 문장)로 옮긴다. 내부 구현 주석은 한다체다.
- 첫 문장은 한 줄 요약이다. 메서드는 HTTP 경로, 로그인 필요 여부, 던지는 오류 코드를 적고, 자주 쓰는 메서드에는 예제를 단다.
- 문자열 enum 필드·typedef는 허용 값과 각 값의 뜻을 적는다.
- 라이브러리 주석(`library;` 위)에 시작하기·오류 처리 예제를 둔다.
- `dart doc` 경고 0을 확인한다.
- 생성 코드는 Node 설명(한다체)을 하십시오체로 바꿔 옮긴다(`tool/codegen/korean.mjs`). 설명이 없는 필드는 「`key` 값입니다.」로 둔다.

---

## `@sayren/storefront-sdk` → `sayren_storefront_sdk.dart`

### `createStorefrontClient`

- [x] `StorefrontClientOptions`: `baseUrl`, `storeCode?`, `accessToken?`, `auth?`, `cartToken?`, `visitorId?`, `sessionId?`, `country?`, `host?`, `locale?`, `onCartToken?`, `session?`, `fetch?` — `session?`은 세션(`createStorefrontSession`)과 함께 만든다
- [x] 최상위 멤버: `accessToken`, `refreshToken`, `userinfo()`

엔드포인트 78개(경로는 `/storefront/v1` 기준):

#### `auth` (12)

- [x] `auth.anonymous` · `POST /storefront/v1/auth/anonymous`
- [x] `auth.signup` · `POST /storefront/v1/auth/signup`
- [x] `auth.login` · `POST /storefront/v1/auth/login`
- [x] `auth.refresh` · `POST /storefront/v1/auth/token/refresh`
- [x] `auth.logout` · `POST /storefront/v1/auth/logout`
- [x] `auth.idpAuthorize` · `POST /storefront/v1/auth/idp/{provider}/authorize`
- [x] `auth.idpToken` · `POST /storefront/v1/auth/idp/token`
- [x] `auth.withdraw` · `POST /storefront/v1/auth/withdraw`
- [x] `auth.identities` · `GET /storefront/v1/me/identities`
- [x] `auth.linkIdentityAuthorize` · `POST /storefront/v1/me/identities/{provider}/authorize`
- [x] `auth.linkIdentity` · `POST /storefront/v1/me/identities/{provider}`
- [x] `auth.unlinkIdentity` · `DELETE /storefront/v1/me/identities/{provider}`

#### `store` (1)

- [x] `store.get` · `GET /storefront/v1/store`

#### `catalog` (12)

- [x] `catalog.listCategories` · `GET /storefront/v1/categories`
- [x] `catalog.getPointPolicy` · `GET /storefront/v1/point-policy`
- [x] `catalog.searchProducts` · `GET /storefront/v1/products`
- [x] `catalog.getProduct` · `GET /storefront/v1/products/{productId}`
- [x] `catalog.listProductReviews` · `GET /storefront/v1/products/{productId}/reviews`
- [x] `catalog.listProductInquiries` · `GET /storefront/v1/products/{productId}/inquiries`
- [x] `catalog.getProductCalendar` · `GET /storefront/v1/products/{productId}/calendar`
- [x] `catalog.createInquiry` · `POST /storefront/v1/products/{productId}/inquiries`
- [x] `catalog.listCollections` · `GET /storefront/v1/collections`
- [x] `catalog.listCoupons` · `GET /storefront/v1/coupons`
- [x] `catalog.getCollection` · `GET /storefront/v1/collections/{slug}`
- [x] `catalog.listCollectionProducts` · `GET /storefront/v1/collections/{slug}/products`

#### `pickupLocations` (1)

- [x] `pickupLocations.list` · `GET /storefront/v1/pickup-locations`

#### `cart` (5)

- [x] `cart.get` · `GET /storefront/v1/cart`
- [x] `cart.addItem` · `POST /storefront/v1/cart/items`
- [x] `cart.updateItem` · `PATCH /storefront/v1/cart/items/{cartItemId}`
- [x] `cart.removeItem` · `DELETE /storefront/v1/cart/items/{cartItemId}`
- [x] `cart.createInputImageUpload` · `POST /storefront/v1/uploads/order-inputs`

#### `checkout` (5)

- [x] `checkout.create` · `POST /storefront/v1/checkout`
- [x] `checkout.quoteDelivery` · `POST /storefront/v1/checkout/{checkoutId}/delivery-quote`
- [x] `checkout.startPayment` · `POST /storefront/v1/checkout/{checkoutId}/payment`
- [x] `checkout.pricing` · `POST /storefront/v1/checkout/{checkoutId}/pricing`
- [x] `checkout.applicableCoupons` · `GET /storefront/v1/checkout/{checkoutId}/coupons`

#### `payments` (4)

- [x] `payments.getStatus` · `GET /storefront/v1/payments/{paymentId}`
- [x] `payments.retry` · `POST /storefront/v1/payments/{paymentId}/attempts`
- [x] `payments.confirm` · `POST /storefront/v1/payments/{paymentId}/confirm`
- [x] `payments.reportFailure` · `POST /storefront/v1/payments/{paymentId}/failure`

#### `myOrders` (9)

- [x] `myOrders.list` · `GET /storefront/v1/me/orders`
- [x] `myOrders.get` · `GET /storefront/v1/me/orders/{orderId}`
- [x] `myOrders.getGuestOrder` · `POST /storefront/v1/guest/orders/{orderId}`
- [x] `myOrders.getDelivery` · `GET /storefront/v1/me/order-items/{orderItemId}/delivery`
- [x] `myOrders.decidePurchase` · `POST /storefront/v1/me/order-items/{orderItemId}/purchase-decision`
- [x] `myOrders.act` · `POST /storefront/v1/me/order-items/{orderItemId}/actions/{key}`
- [x] `myOrders.guestAct` · `POST /storefront/v1/guest/orders/{orderId}/items/{orderItemId}/actions/{key}`
- [x] `myOrders.actOnOrder` · `POST /storefront/v1/me/orders/{orderId}/actions/{key}`
- [x] `myOrders.guestActOnOrder` · `POST /storefront/v1/guest/orders/{orderId}/actions/{key}`

#### `myClaims` (4)

- [x] `myClaims.create` · `POST /storefront/v1/me/order-items/{orderItemId}/claims`
- [x] `myClaims.preview` · `POST /storefront/v1/me/order-items/{orderItemId}/claims/preview`
- [x] `myClaims.list` · `GET /storefront/v1/me/claims`
- [x] `myClaims.withdraw` · `POST /storefront/v1/me/claims/{claimId}/withdraw`

#### `member` (13)

- [x] `member.me` · `GET /storefront/v1/me`
- [x] `member.getPoints` · `GET /storefront/v1/me/points`
- [x] `member.listPointHistory` · `GET /storefront/v1/me/points/history`
- [x] `member.updateMe` · `PATCH /storefront/v1/me`
- [x] `member.consents` · `GET /storefront/v1/me/consents`
- [x] `member.updateConsents` · `POST /storefront/v1/me/consents`
- [x] `member.listAddresses` · `GET /storefront/v1/me/addresses`
- [x] `member.createAddress` · `POST /storefront/v1/me/addresses`
- [x] `member.updateAddress` · `PUT /storefront/v1/me/addresses/{addressId}`
- [x] `member.deleteAddress` · `DELETE /storefront/v1/me/addresses/{addressId}`
- [x] `member.listWishlist` · `GET /storefront/v1/me/wishlist`
- [x] `member.addWishlist` · `POST /storefront/v1/me/wishlist`
- [x] `member.removeWishlist` · `DELETE /storefront/v1/me/wishlist/{productId}`

#### `reviews` (6)

- [x] `reviews.listMine` · `GET /storefront/v1/me/reviews`
- [x] `reviews.listWritable` · `GET /storefront/v1/me/reviews/writable`
- [x] `reviews.createImageUpload` · `POST /storefront/v1/me/uploads`
- [x] `reviews.create` · `POST /storefront/v1/me/order-items/{orderItemId}/review`
- [x] `reviews.update` · `PUT /storefront/v1/me/reviews/{reviewId}`
- [x] `reviews.remove` · `DELETE /storefront/v1/me/reviews/{reviewId}`

#### `inquiries` (1)

- [x] `inquiries.listMine` · `GET /storefront/v1/me/inquiries`

#### `me` (2)

- [x] `me.coupons` · `GET /storefront/v1/me/coupons`
- [x] `me.downloadCoupon` · `POST /storefront/v1/coupons/{couponId}/download`

#### `me.customerInquiries` (3)

- [x] `me.customerInquiries.create` · `POST /storefront/v1/me/customer-inquiries`
- [x] `me.customerInquiries.list` · `GET /storefront/v1/me/customer-inquiries`
- [x] `me.customerInquiries.get` · `GET /storefront/v1/me/customer-inquiries/{inquiryId}`

### `createStorefrontSession`

- [x] `StorefrontSessionOptions`: `baseUrl`, `storeCode?`, `storage`, `fetch?`
- [x] `StorefrontSession`: `login()`, `signup()`, `refresh()`, `accessToken`, `refreshToken`, `userinfo()`, `clear()`, `subscribe()`

### export

총 375개.

- [x] `src/schemas/analytics.ts` → `lib/src/schemas/analytics.dart` (15): `analyticsIdSchema`, `ANALYTICS_VISITOR_COOKIE`, `ANALYTICS_SESSION_COOKIE`, `ANALYTICS_VISITOR_HEADER`, `ANALYTICS_SESSION_HEADER`, `analyticsClientEventNameSchema`, `AnalyticsClientEventName`, `analyticsServerEventNameSchema`, `AnalyticsServerEventName`, `AnalyticsEventName`, `analyticsClientEventSchema`, `AnalyticsClientEvent`, `analyticsBatchSchema`, `AnalyticsBatch`, `ANALYTICS_MAX_BATCH_BYTES`
- [x] `src/schemas/auth.ts` → `lib/src/schemas/auth.dart` (25): `tokenPairSchema`, `TokenPair`, `signupRequestSchema`, `SignupRequest`, `loginRequestSchema`, `LoginRequest`, `anonymousSessionSchema`, `AnonymousSession`, `withdrawRequestSchema`, `WithdrawRequest`, `withdrawalBlockedDetailsSchema`, `WithdrawalBlockedDetails`, `socialProviderSchema`, `SocialProvider`, `idpAgreementsSchema`, `IdpAgreements`, `idpAuthorizeRequestSchema`, `IdpAuthorizeRequest`, `idpAuthorizeResponseSchema`, `idpTokenRequestSchema`, `IdpTokenRequest`, `memberIdentitiesSchema`, `MemberIdentities`, `linkIdentityRequestSchema`, `LinkIdentityRequest`
- [x] `src/schemas/cart.ts` → `lib/src/schemas/cart.dart` (8): `cartItemSchema`, `CartItem`, `cartSchema`, `Cart`, `addCartItemRequestSchema`, `AddCartItemRequest`, `updateCartItemRequestSchema`, `UpdateCartItemRequest`
- [x] `src/schemas/catalog.ts` → `lib/src/schemas/catalog.dart` (30): `CategoryNode`, `categoryNodeSchema`, `productCardSchema`, `ProductCard`, `productNoticeViewSchema`, `ProductNoticeView`, `productCertificationsViewSchema`, `ProductCertificationsView`, `infoSectionViewSchema`, `InfoSectionView`, `productDetailSchema`, `ProductDetail`, `productSortSchema`, `ProductSort`, `ProductSearchParams`, `productFacetsSchema`, `ProductFacets`, `productPageSchema`, `ProductPage`, `storefrontCollectionSchema`, `StorefrontCollection`, `collectionProductSortSchema`, `CollectionProductSortParam`, `storefrontCollectionDetailSchema`, `StorefrontCollectionDetail`, `CollectionProductParams`, `collectionProductQuerySchema`, `collectionProductPageSchema`, `CollectionProductPage`, `storefrontCollectionListQuerySchema`
- [x] `src/schemas/checkout.ts` → `lib/src/schemas/checkout.dart` (73): `createCheckoutRequestSchema`, `CreateCheckoutRequest`, `remoteAreaSchema`, `RemoteArea`, `checkoutDeliverySchema`, `CheckoutDelivery`, `checkoutSessionSchema`, `CheckoutSession`, `deliveryQuoteRequestSchema`, `DeliveryQuoteRequest`, `deliveryQuoteSchema`, `DeliveryQuoteResult`, `paymentMethodSchema`, `PaymentMethod`, `responsePaymentMethodSchema`, `ResponsePaymentMethod`, `pgProviderSchema`, `PgProvider`, `easyPayProviderSchema`, `EasyPayProvider`, `easyPayProviderResponseSchema`, `paymentOptionSchema`, `PaymentOption`, `availablePaymentOptionSchema`, `AvailablePaymentOption`, `paymentOptionListSchema`, `paymentOptionKey`, `CONTACT_PHONE_PATTERN`, `shippingAddressInputSchema`, `ShippingAddressInput`, `INTERNATIONAL_PHONE_PATTERN`, `internationalShippingAddressInputSchema`, `InternationalShippingAddressInput`, `ORDERER_PHONE_PATTERN`, `guestInfoSchema`, `GuestInfo`, `CASH_RECEIPT_METHODS`, `cashReceiptAvailable`, `cashReceiptTypeSchema`, `CashReceiptType`, `CashReceiptIdentityType`, `residentNumberLike`, `cashReceiptIdentityTypeOf`, `cashReceiptRequestSchema`, `CashReceiptRequest`, `startPaymentRequestSchema`, `StartPaymentRequest`, `retryPaymentRequestSchema`, `RetryPaymentRequest`, `paymentLaunchSchema`, `PaymentLaunch`, `confirmPaymentRequestSchema`, `ConfirmPaymentRequest`, `paymentConfirmResultSchema`, `PaymentConfirmResult`, `reportPaymentFailureRequestSchema`, `ReportPaymentFailureRequest`, `paymentFailureResultSchema`, `PaymentFailureResult`, `PAYMENT_START_STATUS_VALUES`, `KnownPaymentStartStatus`, `paymentStartSchema`, `PaymentStart`, `paymentFailureCategorySchema`, `PaymentFailureCategory`, `PAYMENT_STATUS_VALUES`, `KnownPaymentStatus`, `PAYMENT_RESULT_VALUES`, `KnownPaymentResult`, `paymentStatusSchema`, `PaymentStatus`, `paymentMessageSchema`, `PaymentMessage`
- [x] `src/schemas/claim.ts` → `lib/src/schemas/claim.dart` (14): `claimTypeSchema`, `ClaimType`, `claimReasonSchema`, `ClaimReason`, `createClaimRequestSchema`, `CreateClaimRequest`, `createClaimResultSchema`, `CreateClaimResult`, `claimPreviewSchema`, `ClaimPreview`, `claimReturnAddressSchema`, `ClaimReturnAddress`, `myClaimSchema`, `MyClaim`
- [x] `src/schemas/commerce-flow.ts` → `lib/src/schemas/commerce-flow.dart` (19): `flowInputFieldSchema`, `FlowInputField`, `flowActionSchema`, `FlowAction`, `flowFieldValueSchema`, `FlowFieldValue`, `flowStateSchema`, `FlowState`, `ORDER_STEP_TYPES`, `orderStepSchema`, `OrderStep`, `flowActionRequestSchema`, `FlowActionRequest`, `guestFlowActionRequestSchema`, `GuestFlowActionRequest`, `flowActionResultSchema`, `FlowActionResult`, `orderFlowActionResultSchema`, `OrderFlowActionResult`
- [x] `src/schemas/commerce-number.ts` → `lib/src/schemas/commerce-number.dart` (3): `formatOrderNo`, `parseOrderNo`, `commerceNumberField`
- [x] `src/schemas/common.ts` → `lib/src/schemas/common.dart` (8): `pageInfoSchema`, `PageInfo`, `pageSchema`, `PageParams`, `orderItemStatusSchema`, `OrderItemStatus`, `claimStatusSchema`, `ClaimStatus`
- [x] `src/schemas/consent.ts` → `lib/src/schemas/consent.dart` (12): `consentKindSchema`, `ConsentKind`, `consentActionSchema`, `ConsentAction`, `consentSourceSchema`, `ConsentSource`, `consentStateSchema`, `ConsentState`, `memberConsentsSchema`, `MemberConsents`, `consentUpdateRequestSchema`, `ConsentUpdateRequest`
- [x] `src/schemas/coupon.ts` → `lib/src/schemas/coupon.dart` (23): `couponApplicationSchema`, `CouponApplication`, `MAX_COUPONS_PER_CHECKOUT`, `couponApplicationListSchema`, `couponBenefitViewSchema`, `couponResultSchema`, `CouponResult`, `pricingAmountsSchema`, `checkoutPricingRequestSchema`, `CheckoutPricingRequest`, `MIN_PAYMENT_AMOUNT`, `checkoutPricingSchema`, `CheckoutPricing`, `applicableCouponSchema`, `ApplicableCoupon`, `myCouponSchema`, `MyCoupon`, `myCouponListQuerySchema`, `storefrontCouponTargetSchema`, `storefrontCouponSchema`, `StorefrontCoupon`, `storefrontCouponListQuerySchema`, `StorefrontCouponListParams`
- [x] `src/schemas/currency.ts` → `lib/src/schemas/currency.dart` (20): `CurrencySpec`, `CURRENCIES`, `CurrencyCode`, `CURRENCY_CODES`, `BASE_CURRENCY`, `currencyCodeSchema`, `isCurrencyCode`, `currencySpecOf`, `toMinor`, `minorToMajor`, `toDecimalString`, `fromDecimalString`, `floorToSaleUnit`, `isSaleUnitPrice`, `InvalidPriceUnitError`, `assertSaleUnit`, `minPaymentOf`, `MoneyRules`, `moneyRulesOf`, `KRW_MONEY_RULES`
- [x] `src/schemas/customer-inquiry.ts` → `lib/src/schemas/customer-inquiry.dart` (6): `customerInquiryCategorySchema`, `CustomerInquiryCategory`, `customerInquirySchema`, `CustomerInquiry`, `createCustomerInquiryRequestSchema`, `CreateCustomerInquiryRequest`
- [x] `src/schemas/fulfillment.ts` → `lib/src/schemas/fulfillment.dart` (11): `UnknownFulfillmentView`, `productCardFulfillmentSchema`, `ProductCardFulfillment`, `productFulfillmentViewSchema`, `ProductFulfillmentView`, `lineFulfillmentSchema`, `LineFulfillment`, `pickupLocationViewSchema`, `PickupLocationView`, `myOrderItemFulfillmentSnapshotSchema`, `MyOrderItemFulfillmentSnapshot`
- [x] `src/schemas/inquiry.ts` → `lib/src/schemas/inquiry.dart` (8): `productInquiryCategorySchema`, `ProductInquiryCategory`, `publicInquirySchema`, `PublicInquiry`, `createInquiryRequestSchema`, `CreateInquiryRequest`, `createInquiryResultSchema`, `CreateInquiryResult`
- [x] `src/schemas/member.ts` → `lib/src/schemas/member.dart` (14): `memberSchema`, `Member`, `updateProfileRequestSchema`, `UpdateProfileRequest`, `memberAddressSchema`, `MemberAddress`, `memberAddressRequestSchema`, `MemberAddressRequest`, `internationalMemberAddressRequestSchema`, `InternationalMemberAddressRequest`, `memberAddressWriteSchema`, `MemberAddressWrite`, `wishlistAddResultSchema`, `WishlistAddResult`
- [x] `src/schemas/order.ts` → `lib/src/schemas/order.dart` (11): `myOrderItemSchema`, `MyOrderItem`, `orderShippingAddressSchema`, `OrderShippingAddress`, `myOrderSchema`, `MyOrder`, `trackingStageResponseSchema`, `deliveryTrackingSchema`, `DeliveryTracking`, `purchaseDecisionResultSchema`, `PurchaseDecisionResult`
- [x] `src/schemas/points.ts` → `lib/src/schemas/points.dart` (7): `storefrontPointPolicySchema`, `StorefrontPointPolicy`, `memberPointsSchema`, `MemberPoints`, `memberPointEntrySchema`, `MemberPointEntry`, `memberPointEntryPageSchema`
- [x] `src/schemas/product-options.ts` → `lib/src/schemas/product-options.dart` (19): `addonGroupViewSchema`, `AddonGroupView`, `customInputViewSchema`, `CustomInputView`, `parseCustomInputValue`, `normalizeCustomInputValue`, `customInputLength`, `customInputEntrySchema`, `CustomInputEntry`, `addonSelectionSchema`, `AddonSelection`, `lineSelectionRequestShape`, `optionSelectionViewSchema`, `OptionSelectionView`, `customInputValueViewSchema`, `CustomInputValueView`, `lineSelectionResponseShape`, `orderInputUploadRequestSchema`, `OrderInputUploadRequest`
- [x] `src/schemas/review.ts` → `lib/src/schemas/review.dart` (26): `publicReviewSchema`, `PublicReview`, `reviewSummarySchema`, `ReviewSummary`, `myReviewSchema`, `MyReview`, `writableReviewSchema`, `WritableReview`, `createReviewRequestSchema`, `CreateReviewRequest`, `createReviewResultSchema`, `CreateReviewResult`, `updateReviewRequestSchema`, `UpdateReviewRequest`, `productReviewSortSchema`, `ProductReviewSort`, `productReviewQuerySchema`, `ProductReviewParams`, `reviewImageUploadRequestSchema`, `ReviewImageUploadRequest`, `uploadTicketSchema`, `UploadTicket`, `reviewPageSchema`, `ReviewPage`, `updateReviewResultSchema`, `UpdateReviewResult`
- [x] `src/schemas/stay.ts` → `lib/src/schemas/stay.dart` (6): `stayRequestSchema`, `StayRequest`, `stayViewSchema`, `StayView`, `calendarDayViewSchema`, `CalendarDayView`
- [x] `src/schemas/store.ts` → `lib/src/schemas/store.dart` (4): `storefrontMarketSchema`, `StorefrontMarket`, `storefrontStoreSchema`, `StorefrontStore`
- [x] `src/analytics-ids.ts` → `lib/src/analytics-ids.dart` (1): `analyticsIdsFromCookie`
- [x] `src/client.ts` → `lib/src/client.dart` (3): `StorefrontClient`, `StorefrontClientOptions`, `createStorefrontClient`
- [x] `src/http.ts` → `lib/src/http.dart` (4): `Query`, `TokenSource`, `ApiError`, `buildQuery`
- [x] `src/session.ts` → `lib/src/session.dart` (5): `createStorefrontSession`, `SessionStorage`, `STOREFRONT_SESSION_KEYS`, `StorefrontSession`, `StorefrontSessionOptions`
- [x] `ZodError` (설계 규칙 「검증과 오류」)

## `@sayren/storefront-sdk/auth` → `auth.dart`

### `createStorefrontAuth`

- [x] `StorefrontAuthOptions`: `baseUrl`, `storeCode`, `fetch?`
- [x] `StorefrontAuth`: `anonymous()`, `session()`, `signUp()`, `idp()`, `idpCallback()`, `identities()`, `linkIdp()`, `linkIdpCallback()`, `unlinkIdp()`, `refresh()`, `signOut()`, `withdraw()`
- [x] `idp`·`linkIdp`의 복귀는 앱 딥링크로 받아 `idpCallback`·`linkIdpCallback`에 넘긴다(PKCE·state 흐름은 같다)

### export

총 15개.

- [x] `src/auth/index.ts` → `lib/src/auth/index.dart` (6): `IdpStart`, `IdpCallbackInput`, `IdpCallbackError`, `StorefrontAuthOptions`, `createStorefrontAuth`, `StorefrontAuth`
- [x] `src/http.ts` → `lib/src/http.dart` (1): `ApiError`
- [x] `src/schemas/auth.ts` → `lib/src/schemas/auth.dart` (8): `AnonymousSession`, `LoginRequest`, `MemberIdentities`, `SignupRequest`, `SocialProvider`, `TokenPair`, `WithdrawalBlockedDetails`, `WithdrawRequest`

## `@sayren/storefront-sdk/payments` → `payments.dart`

### 기본 사용

결제는 `start` 한 번의 `await`로 끝난다. 결제창 표시, 복귀 처리, 승인, 결과 확정은 SDK가 한다.

```dart
final payments = createPayments(PaymentsOptions(client: client, returnUrl: 'https://shop.example.com/payments/return'));

final result = await payments.start(checkoutId, StartOptions(option: option, shippingAddress: address));
switch (result) {
  case PaymentResultCompleted(:final orderId): // 주문 완료 화면
  case PaymentResultFailed(:final message): // 실패 안내, 다른 결제수단으로 payments.retry
  case PaymentResultCanceled(): // 구매자가 결제창을 닫음
  case PaymentResultProcessing(:final paymentId): // 확인 중, payments.getStatus로 다시 조회
  case PaymentResultInvalid(): // start에서는 나오지 않는다
}
```

### `start`·`retry`·`open` 동작

Node는 결제창이 뜨면 페이지가 떠나므로 끝나지 않는 Promise를 돌려주고, 결과는 복귀 화면의 `result()`가 읽는다. Dart는 같은 화면에서 결과까지 돌려준다.

- [x] 결제가 필요 없으면(`status`가 `pending`이 아님) 결제창 없이 바로 결과를 돌려준다(Node `settleWithoutWindow`와 같다)
- [x] 결제창은 전체 화면 WebView로 띄운다. Node `launch.ts`를 esbuild로 묶은 스크립트(`launch_js.dart`, 생성)를 SDK가 만든 HTML에 넣어 실행하므로 PG 분기는 Node와 같다(스크립트형 PG는 PG JS SDK 실행, 카카오페이·PayPal·mock은 주소 이동). 모르는 `type`이면 `payUrl`을 연다. PC 판정은 하지 않고 늘 모바일 결제창이다
- [x] HTML은 `returnUrl`의 출처를 `baseUrl`로 두고 연다. 결제창을 열지 못하면 JS 채널 `SayrenPayments`로 실패를 받는다
- [x] WebView가 `returnUrl`로 이동하면 그 페이지를 열지 않고 주소를 가로챈다. `readPaymentReturn`으로 읽어 승인(`payments.confirm`) 또는 실패 보고(`payments.reportFailure`)를 한 번 보내고 WebView를 닫는다
- [x] 구매자가 WebView를 닫으면 `USER_CANCELED`로 실패 보고하고 `CANCELED`(`POPUP_CLOSED`)를 돌려준다. `payUrl` 결제창은 결제 서비스가 시도를 다루므로 보고하지 않고 상태로만 정한다
- [x] 결과가 `PROCESSING`이면 `expiresAt`까지 `getStatus`로 조회해 확정된 결과를 돌려준다. 그때까지 확정되지 않을 때만 `PROCESSING`이다
- [x] `ATTEMPT_CAPTURED`(이미 매입) 처리, 같은 복귀의 중복 승인 방지는 Node와 같다
- [x] 카드사·은행·간편결제 앱 호출(`intent://`, 앱 스킴)은 OS로 넘기고, 앱에서 돌아오면 WebView 결제를 이어 간다
- [x] `open(start)`는 결제 시작(`checkout.startPayment`)을 앱이 직접 부른 경우에 쓴다. 이후 동작은 `start`와 같다
- [x] `retry(paymentId, options)`는 같은 결제를 다른 옵션으로 다시 시도한다. 동작은 `start`와 같다
- [x] `result(url)`은 결제 중 앱이 종료돼 복귀 주소를 나중에 받은 경우(딥링크 등)에 쓴다. Node와 같게 승인·실패 보고 후 결과를 만든다
- [ ] 확인 필요: 스크립트형 PG(토스페이먼츠·포트원·네이버페이)가 `returnUrl` 출처(`baseUrl`)의 WebView 페이지를 허용하는지 샌드박스 검증
- [ ] 확인 필요: 실기기(iOS·Android)에서 WebView 결제창·앱 호출·복귀

### `PaymentsEnv` (Flutter)

- [x] `present({html, url, baseUrl, returnUrl})`: 결제창 WebView를 띄우고 `(returnUrl, failure)`를 돌려준다. `returnUrl`에 도착하면 그 주소, 결제창을 열지 못하면 그 실패, 구매자가 닫으면 둘 다 `null`이다
- [x] `currentUrl()`: `result()`에서 주소를 생략했을 때 읽을 주소. 기본 구현은 `null`이고 결과는 `INVALID`다
- [x] `now()`·`wait()`: `PROCESSING` 조회의 시각과 간격(1초). 만료 시각이 없으면 30초까지 조회한다
- [x] 기본 구현은 앱의 루트 `Navigator`를 찾아 WebView 화면을 띄운다. 루트 `Navigator`가 없는 라우팅이면 앱이 `env`를 넘긴다

### `createPayments`

- [x] `PaymentsOptions`: `client`, `returnUrl?`, `env?`
- [x] `Payments`: `start()`, `retry()`, `open()`, `result()`, `getStatus()`
- [x] `StartOptions`: `option?`, `shippingAddress?`, `guest?`, `cashReceipt?`, `coupons?`, `pointAmount?`, `returnUrl?`
- [x] `RetryOptions`: `option`, `returnUrl?`, `cashReceipt?`

### export

총 10개.

- [x] `src/payments/index.ts` → `lib/src/payments/index.dart` (10): `PaymentDevice`, `PaymentResult`, `PaymentsEnv`, `resolvePaymentMode`, `paymentResultOf`, `PaymentsOptions`, `StartOptions`, `RetryOptions`, `Payments`, `createPayments`

`resolvePaymentMode`의 `mode` 인자는 Node에서 deprecated 타입 `PaymentMode`다. Dart는 `PaymentMode` 없이 `String?`으로 받는다.

## `@sayren/storefront-sdk/analytics` → `analytics.dart`

### `createAnalytics`

- [x] `AnalyticsOptions`: `baseUrl`, `storeCode`, `consent?`, `autoPageViews?`, `debug?`, `cookieDomain?`, `flushIntervalMs?`
- [x] `Analytics`: `track()`, `page()`, `setConsent()`, `ids()`, `flush()`, `destroy()`
- [x] Node는 브라우저가 아니면 아무것도 하지 않는 객체를 돌려준다. Dart는 Flutter 기본 `AnalyticsEnv`로 동작한다
- [x] 방문자·세션 ID는 쿠키 대신 앱 저장소에 둔다. `ids()` 값을 `StorefrontClientOptions(visitorId:, sessionId:)`에 넘기는 사용법은 같다
- [x] `autoPageViews`는 루트 `Navigator`의 화면 이름(`RouteSettings.name`)이 바뀔 때(500ms 확인) 페이지뷰를 보낸다. 주소는 `app://{storeCode}{화면 이름}`이다. 이름 없는 화면만 쓰면 `autoPageViews: false`로 두고 앱이 `page()`를 부른다
- [x] 앱 생명주기(백그라운드 전환·종료)를 Node의 `visibilitychange`·`pagehide`로 옮긴다
- [ ] 확인 필요: 서버가 `app://` 주소의 페이지뷰를 받는지
- [x] `cookieDomain`은 받기만 하고 쓰지 않는다(앱에 쿠키 도메인이 없다). 저장은 `shared_preferences`의 `sayren.analytics.` 접두사 키다

### export

총 7개.

- [x] `src/analytics/index.ts` → `lib/src/analytics/index.dart` (7): `AnalyticsConsent`, `AnalyticsOptions`, `AnalyticsTrackInput`, `Analytics`, `AnalyticsEnv`, `createAnalytics`, `createAnalyticsWith`

---

## `@sayren/store-sdk` → `sayren_store_sdk.dart`

### `createStoreClient`

- [x] `StoreClientOptions`: `baseUrl`, `accessToken?`, `storeId?`, `session?`, `refresh?`, `onUnauthorized?`, `fetch?`
- [x] 최상위 멤버: `accessToken`, `refreshToken`, `authorize()`, `userinfo()`
- [x] `uploads.upload(file, (purpose:, filename:))`: Node의 `Blob`·`File` 자리에 `XFile`(`cross_file`)을 받는다. 파일 이름은 `filename`, 없으면 `XFile.name`이다

엔드포인트 308개(경로는 `/v1` 기준):

#### `auth` (2)

- [x] `auth.listMyStores` · `GET /v1/me/stores`
- [x] `auth.me` · `GET /v1/me`

#### `uploads` (2)

- [x] `uploads.create` · `POST /v1/uploads`
- [x] `uploads.upload` · `POST /v1/uploads` + `PUT {uploadUrl}` (자리 발급과 바이트 업로드 합성, 용도별 확장자·크기 선검사)

#### `products` (15)

- [x] `products.list` · `GET /v1/products`
- [x] `products.get` · `GET /v1/products/{productId}`
- [x] `products.create` · `POST /v1/products`
- [x] `products.update` · `PUT /v1/products/{productId}`
- [x] `products.patch` · `PATCH /v1/products/{productId}`
- [x] `products.remove` · `DELETE /v1/products/{productId}`
- [x] `products.bulkUpdateStatus` · `POST /v1/products/bulk/status`
- [x] `products.getOptionModel` · `GET /v1/products/{productId}/options`
- [x] `products.replaceOptionModel` · `PUT /v1/products/{productId}/options`
- [x] `products.updateVariantStock` · `PATCH /v1/products/{productId}/variants/{variantId}/stock`
- [x] `products.getDiscount` · `GET /v1/products/{productId}/discount`
- [x] `products.setDiscount` · `PUT /v1/products/{productId}/discount`
- [x] `products.removeDiscount` · `DELETE /v1/products/{productId}/discount`
- [x] `products.getCalendar` · `GET /v1/products/{productId}/calendar`
- [x] `products.setCalendar` · `PUT /v1/products/{productId}/calendar`

#### `products.localizations` (3)

- [x] `products.localizations.list` · `GET /v1/products/{productId}/localizations`
- [x] `products.localizations.put` · `PUT /v1/products/{productId}/localizations/{locale}`
- [x] `products.localizations.remove` · `DELETE /v1/products/{productId}/localizations/{locale}`

#### `savedOptionSets` (6)

- [x] `savedOptionSets.list` · `GET /v1/saved-option-sets`
- [x] `savedOptionSets.get` · `GET /v1/saved-option-sets/{optionSetId}`
- [x] `savedOptionSets.create` · `POST /v1/saved-option-sets`
- [x] `savedOptionSets.update` · `PUT /v1/saved-option-sets/{optionSetId}`
- [x] `savedOptionSets.remove` · `DELETE /v1/saved-option-sets/{optionSetId}`
- [x] `savedOptionSets.saveFromProduct` · `POST /v1/saved-option-sets/from-product`

#### `savedOptionSets.localizations` (3)

- [x] `savedOptionSets.localizations.list` · `GET /v1/saved-option-sets/{optionSetId}/localizations`
- [x] `savedOptionSets.localizations.put` · `PUT /v1/saved-option-sets/{optionSetId}/localizations/{locale}`
- [x] `savedOptionSets.localizations.remove` · `DELETE /v1/saved-option-sets/{optionSetId}/localizations/{locale}`

#### `infoSchemas` (1)

- [x] `infoSchemas.list` · `GET /v1/info-schemas`

#### `codes` (1)

- [x] `codes.list` · `GET /v1/codes/{setId}`

#### `infoSections` (5)

- [x] `infoSections.list` · `GET /v1/info-sections`
- [x] `infoSections.get` · `GET /v1/info-sections/{infoSectionId}`
- [x] `infoSections.create` · `POST /v1/info-sections`
- [x] `infoSections.update` · `PUT /v1/info-sections/{infoSectionId}`
- [x] `infoSections.remove` · `DELETE /v1/info-sections/{infoSectionId}`

#### `infoSections.localizations` (3)

- [x] `infoSections.localizations.list` · `GET /v1/info-sections/{infoSectionId}/localizations`
- [x] `infoSections.localizations.put` · `PUT /v1/info-sections/{infoSectionId}/localizations/{locale}`
- [x] `infoSections.localizations.remove` · `DELETE /v1/info-sections/{infoSectionId}/localizations/{locale}`

#### `collections` (10)

- [x] `collections.list` · `GET /v1/collections`
- [x] `collections.get` · `GET /v1/collections/{collectionId}`
- [x] `collections.create` · `POST /v1/collections`
- [x] `collections.update` · `PATCH /v1/collections/{collectionId}`
- [x] `collections.remove` · `DELETE /v1/collections/{collectionId}`
- [x] `collections.listProducts` · `GET /v1/collections/{collectionId}/products`
- [x] `collections.replaceProducts` · `PUT /v1/collections/{collectionId}/products`
- [x] `collections.addProducts` · `POST /v1/collections/{collectionId}/products`
- [x] `collections.removeProduct` · `DELETE /v1/collections/{collectionId}/products/{productId}`
- [x] `collections.preview` · `POST /v1/collections/preview`

#### `collections.localizations` (3)

- [x] `collections.localizations.list` · `GET /v1/collections/{collectionId}/localizations`
- [x] `collections.localizations.put` · `PUT /v1/collections/{collectionId}/localizations/{locale}`
- [x] `collections.localizations.remove` · `DELETE /v1/collections/{collectionId}/localizations/{locale}`

#### `categories` (8)

- [x] `categories.list` · `GET /v1/categories`
- [x] `categories.tree` · `GET /v1/categories`
- [x] `categories.search` · `GET /v1/categories`
- [x] `categories.get` · `GET /v1/categories/{categoryId}`
- [x] `categories.listAttributes` · `GET /v1/categories/{categoryId}/attributes`
- [x] `categories.create` · `POST /v1/categories`
- [x] `categories.update` · `PATCH /v1/categories/{categoryId}`
- [x] `categories.remove` · `DELETE /v1/categories/{categoryId}`

#### `categories.localizations` (3)

- [x] `categories.localizations.list` · `GET /v1/categories/{categoryId}/localizations`
- [x] `categories.localizations.put` · `PUT /v1/categories/{categoryId}/localizations/{locale}`
- [x] `categories.localizations.remove` · `DELETE /v1/categories/{categoryId}/localizations/{locale}`

#### `orders` (4)

- [x] `orders.list` · `GET /v1/orders`
- [x] `orders.get` · `GET /v1/orders/{orderId}`
- [x] `orders.reissueCashReceipt` · `POST /v1/orders/{orderId}/cash-receipt/reissue`
- [x] `orders.act` · `POST /v1/orders/{orderId}/actions/{key}`

#### `orderItems` (23)

- [x] `orderItems.listChanged` · `GET /v1/order-items`
- [x] `orderItems.confirm` · `POST /v1/order-items/{orderItemId}/confirm`
- [x] `orderItems.confirmBulk` · `POST /v1/order-items/confirm`
- [x] `orderItems.hold` · `POST /v1/order-items/{orderItemId}/hold`
- [x] `orderItems.releaseHold` · `DELETE /v1/order-items/{orderItemId}/hold`
- [x] `orderItems.cancelPreview` · `GET /v1/order-items/{orderItemId}/cancel-preview`
- [x] `orderItems.cancelBySeller` · `POST /v1/order-items/{orderItemId}/cancel`
- [x] `orderItems.updateMemo` · `PUT /v1/order-items/{orderItemId}/memo`
- [x] `orderItems.requestPurchaseDecision` · `POST /v1/order-items/{orderItemId}/purchase-decision/request`
- [x] `orderItems.extendPurchaseDecision` · `POST /v1/order-items/{orderItemId}/purchase-decision/extend`
- [x] `orderItems.dispatch` · `POST /v1/order-items/{orderItemId}/dispatch`
- [x] `orderItems.dispatchBulk` · `POST /v1/order-items/dispatch`
- [x] `orderItems.updateTracking` · `PUT /v1/order-items/{orderItemId}/dispatch/tracking`
- [x] `orderItems.markDelivered` · `POST /v1/order-items/{orderItemId}/delivered`
- [x] `orderItems.markDeliveredBulk` · `POST /v1/order-items/delivered`
- [x] `orderItems.fulfill` · `POST /v1/order-items/{orderItemId}/fulfill`
- [x] `orderItems.fulfillBulk` · `POST /v1/order-items/fulfill`
- [x] `orderItems.getDelivery` · `GET /v1/order-items/{orderItemId}/delivery`
- [x] `orderItems.getFlow` · `GET /v1/order-items/{orderItemId}/flow`
- [x] `orderItems.act` · `POST /v1/order-items/{orderItemId}/actions/{key}`
- [x] `orderItems.emitEvent` · `POST /v1/order-items/{orderItemId}/events/{key}`
- [x] `orderItems.moveFlow` · `POST /v1/order-items/{orderItemId}/flow/move`
- [x] `orderItems.flowRuns` · `GET /v1/order-items/{orderItemId}/flow/runs`

#### `flowRuns` (1)

- [x] `flowRuns.get` · `GET /v1/flow-runs/{runId}`

#### `commerceFlows` (17)

- [x] `commerceFlows.presets` · `GET /v1/flow-presets`
- [x] `commerceFlows.preset` · `GET /v1/flow-presets/{key}`
- [x] `commerceFlows.list` · `GET /v1/commerce-flows`
- [x] `commerceFlows.get` · `GET /v1/commerce-flows/{flowId}`
- [x] `commerceFlows.create` · `POST /v1/commerce-flows`
- [x] `commerceFlows.saveDraft` · `PUT /v1/commerce-flows/{flowId}/draft`
- [x] `commerceFlows.check` · `POST /v1/commerce-flows/{flowId}/draft/check`
- [x] `commerceFlows.publish` · `POST /v1/commerce-flows/{flowId}/draft/publish`
- [x] `commerceFlows.forProduct` · `GET /v1/products/{productId}/flow`
- [x] `commerceFlows.secrets` · `GET /v1/commerce-flows/secrets`
- [x] `commerceFlows.saveSecret` · `PUT /v1/commerce-flows/secrets/{name}`
- [x] `commerceFlows.removeSecret` · `DELETE /v1/commerce-flows/secrets/{name}`
- [x] `commerceFlows.getVersion` · `GET /v1/commerce-flows/{flowId}/versions/{version}`
- [x] `commerceFlows.migrateVersion` · `POST /v1/commerce-flows/{flowId}/versions/{version}/migrate`
- [x] `commerceFlows.simulate` · `POST /v1/commerce-flows/{flowId}/draft/simulate`
- [x] `commerceFlows.replay` · `POST /v1/commerce-flows/{flowId}/draft/replay`
- [x] `commerceFlows.nodeTypes` · `GET /v1/flow-node-types`

#### `carriers` (1)

- [x] `carriers.list` · `GET /v1/carriers`

#### `claims` (10)

- [x] `claims.list` · `GET /v1/claims`
- [x] `claims.get` · `GET /v1/claims/{claimId}`
- [x] `claims.approve` · `POST /v1/claims/{claimId}/approve`
- [x] `claims.reject` · `POST /v1/claims/{claimId}/reject`
- [x] `claims.registerCollect` · `POST /v1/claims/{claimId}/collect`
- [x] `claims.completeCollect` · `POST /v1/claims/{claimId}/collect/complete`
- [x] `claims.registerRedelivery` · `POST /v1/claims/{claimId}/redelivery`
- [x] `claims.hold` · `POST /v1/claims/{claimId}/hold`
- [x] `claims.releaseHold` · `DELETE /v1/claims/{claimId}/hold`
- [x] `claims.completeExchange` · `POST /v1/claims/{claimId}/complete-exchange`

#### `inquiries` (4)

- [x] `inquiries.list` · `GET /v1/inquiries`
- [x] `inquiries.get` · `GET /v1/inquiries/{inquiryId}`
- [x] `inquiries.answer` · `POST /v1/inquiries/{inquiryId}/answer`
- [x] `inquiries.updateAnswer` · `PUT /v1/inquiries/{inquiryId}/answer`

#### `loginSettings` (6)

- [x] `loginSettings.get` · `GET /v1/store/login-settings`
- [x] `loginSettings.update` · `PATCH /v1/store/login-settings`
- [x] `loginSettings.saveProvider` · `PUT /v1/store/auth-providers/{provider}`
- [x] `loginSettings.setProviderEnabled` · `PATCH /v1/store/auth-providers/{provider}`
- [x] `loginSettings.testProvider` · `POST /v1/store/auth-providers/{provider}/test`
- [x] `loginSettings.removeProvider` · `DELETE /v1/store/auth-providers/{provider}`

#### `points` (1)

- [x] `points.listHistory` · `GET /v1/points/history`

#### `customers` (9)

- [x] `customers.getPoints` · `GET /v1/customers/{customerId}/points`
- [x] `customers.listPointHistory` · `GET /v1/customers/{customerId}/points/history`
- [x] `customers.adjustPoints` · `POST /v1/customers/{customerId}/points/adjustments`
- [x] `customers.list` · `GET /v1/customers`
- [x] `customers.get` · `GET /v1/customers/{customerId}`
- [x] `customers.orders` · `GET /v1/customers/{customerId}/orders`
- [x] `customers.consents` · `GET /v1/customers/{customerId}/consents`
- [x] `customers.coupons` · `GET /v1/customers/{customerId}/coupons`
- [x] `customers.withdraw` · `POST /v1/customers/{customerId}/withdraw`

#### `coupons` (12)

- [x] `coupons.list` · `GET /v1/coupons`
- [x] `coupons.create` · `POST /v1/coupons`
- [x] `coupons.get` · `GET /v1/coupons/{couponId}`
- [x] `coupons.update` · `PATCH /v1/coupons/{couponId}`
- [x] `coupons.pause` · `POST /v1/coupons/{couponId}/pause`
- [x] `coupons.resume` · `POST /v1/coupons/{couponId}/resume`
- [x] `coupons.end` · `POST /v1/coupons/{couponId}/end`
- [x] `coupons.issue` · `POST /v1/coupons/{couponId}/issues`
- [x] `coupons.issues` · `GET /v1/coupons/{couponId}/issues`
- [x] `coupons.redemptions` · `GET /v1/coupons/{couponId}/redemptions`
- [x] `coupons.stats` · `GET /v1/coupons/{couponId}/stats`
- [x] `coupons.revokeIssue` · `POST /v1/coupon-issues/{issueId}/revoke`

#### `customerInquiries` (4)

- [x] `customerInquiries.list` · `GET /v1/customer-inquiries`
- [x] `customerInquiries.get` · `GET /v1/customer-inquiries/{inquiryId}`
- [x] `customerInquiries.answer` · `POST /v1/customer-inquiries/{inquiryId}/answer`
- [x] `customerInquiries.updateAnswer` · `PUT /v1/customer-inquiries/{inquiryId}/answer`

#### `salesReport` (1)

- [x] `salesReport.get` · `GET /v1/sales-report`

#### `analytics` (8)

- [x] `analytics.overview` · `GET /v1/analytics/overview`
- [x] `analytics.products` · `GET /v1/analytics/products`
- [x] `analytics.sources` · `GET /v1/analytics/sources`
- [x] `analytics.realtime` · `GET /v1/analytics/realtime`
- [x] `analytics.devices` · `GET /v1/analytics/devices`
- [x] `analytics.pages` · `GET /v1/analytics/pages`
- [x] `analytics.search` · `GET /v1/analytics/search`
- [x] `analytics.checkout` · `GET /v1/analytics/checkout`

#### `payments` (3)

- [x] `payments.list` · `GET /v1/payments`
- [x] `payments.get` · `GET /v1/payments/{paymentId}`
- [x] `payments.processRefund` · `POST /v1/payments/refunds/{refundId}/process`

#### `paymentSettings` (14)

- [x] `paymentSettings.get` · `GET /v1/store/payment-settings`
- [x] `paymentSettings.update` · `PUT /v1/store/payment-settings`
- [x] `paymentSettings.upsertTossPayments` · `PUT /v1/store/payment-providers/tosspayments`
- [x] `paymentSettings.upsertPortOne` · `PUT /v1/store/payment-providers/portone`
- [x] `paymentSettings.upsertKakaoPay` · `PUT /v1/store/payment-providers/kakaopay`
- [x] `paymentSettings.upsertNaverPay` · `PUT /v1/store/payment-providers/naverpay`
- [x] `paymentSettings.upsertPayPal` · `PUT /v1/store/payment-providers/paypal`
- [x] `paymentSettings.setPlatformTestKeys` · `PUT /v1/store/payment-providers/{provider}/platform-test-keys`
- [x] `paymentSettings.status` · `GET /v1/store/payment-status`
- [x] `paymentSettings.disconnect` · `DELETE /v1/store/payment-providers/{provider}`
- [x] `paymentSettings.removeCredentialSet` · `DELETE /v1/store/payment-providers/{provider}/credentials/{environment}`
- [x] `paymentSettings.verify` · `POST /v1/store/payment-providers/{provider}/verify`
- [x] `paymentSettings.updateProvider` · `PATCH /v1/store/payment-providers/{provider}`
- [x] `paymentSettings.setSandboxMode` · `PATCH /v1/store/payment-providers/{provider}` (`updateProvider`에 `{ sandboxMode }`만 싣는 합성)

#### `appTools` (2)

- [x] `appTools.list` · `GET /v1/apps/tools`
- [x] `appTools.call` · `POST /v1/apps/installations/{installationId}/tools/{name}`

#### `apps.catalog` (2)

- [x] `apps.catalog.list` · `GET /v1/apps/catalog`
- [x] `apps.catalog.get` · `GET /v1/apps/catalog/{appId}`

#### `apps.installations` (8)

- [x] `apps.installations.install` · `POST /v1/apps/installations`
- [x] `apps.installations.list` · `GET /v1/apps/installations`
- [x] `apps.installations.get` · `GET /v1/apps/installations/{installationId}`
- [x] `apps.installations.updateSettings` · `PUT /v1/apps/installations/{installationId}/settings`
- [x] `apps.installations.remove` · `DELETE /v1/apps/installations/{installationId}`
- [x] `apps.installations.activity` · `GET /v1/apps/installations/{installationId}/activity`
- [x] `apps.installations.consent` · `POST /v1/apps/installations/{installationId}/consent`
- [x] `apps.installations.session` · `POST /v1/apps/installations/{installationId}/session`

#### `app` (1)

- [x] `app.installation` · `GET /v1/app/installation`

#### `app.storage` (4)

- [x] `app.storage.list` · `GET /v1/app/storage`
- [x] `app.storage.get` · `GET /v1/app/storage/{key}`
- [x] `app.storage.set` · `PUT /v1/app/storage/{key}`
- [x] `app.storage.delete` · `DELETE /v1/app/storage/{key}`

#### `webhooks` (12)

- [x] `webhooks.list` · `GET /v1/webhooks`
- [x] `webhooks.create` · `POST /v1/webhooks`
- [x] `webhooks.get` · `GET /v1/webhooks/{webhookId}`
- [x] `webhooks.update` · `PUT /v1/webhooks/{webhookId}`
- [x] `webhooks.remove` · `DELETE /v1/webhooks/{webhookId}`
- [x] `webhooks.rotateSecret` · `POST /v1/webhooks/{webhookId}/rotate-secret`
- [x] `webhooks.resume` · `POST /v1/webhooks/{webhookId}/resume`
- [x] `webhooks.listDeliveries` · `GET /v1/webhooks/{webhookId}/deliveries`
- [x] `webhooks.getDelivery` · `GET /v1/webhooks/{webhookId}/deliveries/{deliveryId}`
- [x] `webhooks.redeliver` · `POST /v1/webhooks/{webhookId}/deliveries/{deliveryId}/redeliver`
- [x] `webhooks.redeliverFailed` · `POST /v1/webhooks/{webhookId}/deliveries/redeliver-failed`
- [x] `webhooks.sendTest` · `POST /v1/webhooks/{webhookId}/test`

#### `apiLogs` (2)

- [x] `apiLogs.list` · `GET /v1/api-logs`
- [x] `apiLogs.summary` · `GET /v1/api-logs/summary`

#### `auditLogs` (1)

- [x] `auditLogs.list` · `GET /v1/audit-logs`

#### `approvalRequests` (4)

- [x] `approvalRequests.list` · `GET /v1/approval-requests`
- [x] `approvalRequests.get` · `GET /v1/approval-requests/{approvalId}`
- [x] `approvalRequests.approve` · `POST /v1/approval-requests/{approvalId}/approve`
- [x] `approvalRequests.reject` · `POST /v1/approval-requests/{approvalId}/reject`

#### `reviews` (5)

- [x] `reviews.list` · `GET /v1/reviews`
- [x] `reviews.get` · `GET /v1/reviews/{reviewId}`
- [x] `reviews.createReply` · `POST /v1/reviews/{reviewId}/reply`
- [x] `reviews.updateReply` · `PUT /v1/reviews/{reviewId}/reply`
- [x] `reviews.deleteReply` · `DELETE /v1/reviews/{reviewId}/reply`

#### `sellerAddresses` (5)

- [x] `sellerAddresses.list` · `GET /v1/seller-addresses`
- [x] `sellerAddresses.create` · `POST /v1/seller-addresses`
- [x] `sellerAddresses.update` · `PUT /v1/seller-addresses/{addressId}`
- [x] `sellerAddresses.remove` · `DELETE /v1/seller-addresses/{addressId}`
- [x] `sellerAddresses.setDefault` · `POST /v1/seller-addresses/{addressId}/default`

#### `inventory.locations` (4)

- [x] `inventory.locations.list` · `GET /v1/inventory-locations`
- [x] `inventory.locations.create` · `POST /v1/inventory-locations`
- [x] `inventory.locations.update` · `PUT /v1/inventory-locations/{inventoryLocationId}`
- [x] `inventory.locations.remove` · `DELETE /v1/inventory-locations/{inventoryLocationId}`

#### `inventory` (4)

- [x] `inventory.levels` · `GET /v1/inventory/levels`
- [x] `inventory.movements` · `GET /v1/inventory/movements`
- [x] `inventory.adjust` · `POST /v1/inventory/adjustments`
- [x] `inventory.transfer` · `POST /v1/inventory/transfers`

#### `markets` (5)

- [x] `markets.list` · `GET /v1/markets`
- [x] `markets.get` · `GET /v1/markets/{marketId}`
- [x] `markets.create` · `POST /v1/markets`
- [x] `markets.update` · `PATCH /v1/markets/{marketId}`
- [x] `markets.archive` · `DELETE /v1/markets/{marketId}`

#### `pickupLocations` (4)

- [x] `pickupLocations.list` · `GET /v1/pickup-locations`
- [x] `pickupLocations.create` · `POST /v1/pickup-locations`
- [x] `pickupLocations.update` · `PUT /v1/pickup-locations/{locationId}`
- [x] `pickupLocations.remove` · `DELETE /v1/pickup-locations/{locationId}`

#### `ai` (8)

- [x] `ai.listConversations` · `GET /v1/ai/conversations`
- [x] `ai.createConversation` · `POST /v1/ai/conversations`
- [x] `ai.getConversation` · `GET /v1/ai/conversations/{conversationId}`
- [x] `ai.sendMessage` · `POST /v1/ai/conversations/{conversationId}/messages`
- [x] `ai.cancelRun` · `POST /v1/ai/runs/{runId}/cancel`
- [x] `ai.listFileChanges` · `GET /v1/ai/conversations/{conversationId}/file-changes`
- [x] `ai.getRunFileDiff` · `GET /v1/ai/runs/{runId}/file-changes`
- [x] `ai.revertRun` · `POST /v1/ai/runs/{runId}/revert`

#### `storefront` (41)

- [x] `storefront.listTemplates` · `GET /v1/storefront/templates`
- [x] `storefront.getStoreTemplate` · `GET /v1/storefront/template`
- [x] `storefront.updateStoreTemplate` · `PUT /v1/storefront/template`
- [x] `storefront.get` · `GET /v1/storefront/site`
- [x] `storefront.checkSlug` · `GET /v1/storefront/slug-availability`
- [x] `storefront.create` · `POST /v1/storefront/site`
- [x] `storefront.getDeployment` · `GET /v1/storefront/site/deployment`
- [x] `storefront.retryDeployment` · `POST /v1/storefront/site/deployment/retry`
- [x] `storefront.listVersions` · `GET /v1/storefront/site/versions`
- [x] `storefront.publish` · `POST /v1/storefront/site/versions/{versionId}/publish`
- [x] `storefront.rollback` · `POST /v1/storefront/site/rollback`
- [x] `storefront.changeSlug` · `PUT /v1/storefront/site/slug`
- [x] `storefront.setVisibility` · `PUT /v1/storefront/site/visibility`
- [x] `storefront.createPreviewLink` · `POST /v1/storefront/site/preview-link`
- [x] `storefront.getStarterStatus` · `GET /v1/storefront/starter`
- [x] `storefront.listDomains` · `GET /v1/storefront/site/domains`
- [x] `storefront.addDomain` · `POST /v1/storefront/site/domains`
- [x] `storefront.verifyDomain` · `POST /v1/storefront/site/domains/{domainId}/verify`
- [x] `storefront.setPrimaryDomain` · `POST /v1/storefront/site/domains/{domainId}/primary`
- [x] `storefront.removeDomain` · `DELETE /v1/storefront/site/domains/{domainId}`
- [x] `storefront.disable` · `POST /v1/storefront/site/disable`
- [x] `storefront.getEditing` · `GET /v1/storefront/site/editing`
- [x] `storefront.startEditing` · `POST /v1/storefront/site/editing`
- [x] `storefront.stopEditing` · `DELETE /v1/storefront/site/editing`
- [x] `storefront.createEditPreviewLink` · `POST /v1/storefront/site/editing/preview-link`
- [x] `storefront.listFiles` · `GET /v1/storefront/site/files`
- [x] `storefront.readFile` · `GET /v1/storefront/site/files/content`
- [x] `storefront.writeFiles` · `POST /v1/storefront/site/files/batch`
- [x] `storefront.deleteFile` · `POST /v1/storefront/site/files/delete`
- [x] `storefront.moveFile` · `POST /v1/storefront/site/files/move`
- [x] `storefront.searchFiles` · `POST /v1/storefront/site/files/search`
- [x] `storefront.runCheck` · `POST /v1/storefront/site/checks`
- [x] `storefront.getCheck` · `GET /v1/storefront/site/checks/{checkId}`
- [x] `storefront.verify` · `POST /v1/storefront/site/verify`
- [x] `storefront.createVersion` · `POST /v1/storefront/site/versions`
- [x] `storefront.listBuilds` · `GET /v1/storefront/site/builds`
- [x] `storefront.getBuild` · `GET /v1/storefront/site/builds/{buildId}`
- [x] `storefront.getSource` · `GET /v1/storefront/site/source`
- [x] `storefront.getSourceArchive` · `GET /v1/storefront/site/source/archive`
- [x] `storefront.uploadSourceBlobs` · `POST /v1/storefront/site/source/blobs`
- [x] `storefront.replaceSource` · `PUT /v1/storefront/site/source`

#### `subscription` (1)

- [x] `subscription.get` · `GET /v1/store/subscription`

#### `plans` (1)

- [x] `plans.listPublic` · `GET /v1/public/plans`

#### `store` (11)

- [x] `store.get` · `GET /v1/store`
- [x] `store.update` · `PATCH /v1/store`
- [x] `store.getPointPolicy` · `GET /v1/store/point-policy`
- [x] `store.updatePointPolicy` · `PUT /v1/store/point-policy`
- [x] `store.listMembers` · `GET /v1/store/members`
- [x] `store.updateMemberRole` · `PATCH /v1/store/members/{userId}`
- [x] `store.removeMember` · `DELETE /v1/store/members/{userId}`
- [x] `store.listInvitations` · `GET /v1/store/invitations`
- [x] `store.invite` · `POST /v1/store/invitations`
- [x] `store.resendInvitation` · `POST /v1/store/invitations/{invitationId}/resend`
- [x] `store.cancelInvitation` · `DELETE /v1/store/invitations/{invitationId}`

### `createStoreSession`

- [x] `StoreSessionOptions`: `baseUrl`, `authServer`, `clientId`, `storage`, `fetch?`
- [x] `StoreAuthServer`: `authorizeUrl`, `tokenUrl`, `revokeUrl`, `resource?`
- [x] `AuthorizeOptions`: `redirectUri`, `scope?`, `prompt?`
- [x] `StoreSession`: `getToken()`, `setTokens()`, `refresh()`, `clear()`, `logout()`, `subscribe()`, `accessToken`, `refreshToken`, `authorize()`, `handleCallback()`, `userinfo()`
- [x] `authorize`의 복귀는 앱 딥링크로 받아 `handleCallback(code, state)`에 넘긴다. Node는 브라우저면 이동하지만 Dart는 늘 주소를 돌려준다
- [x] Node는 탭 간 갱신을 Web Locks로 직렬화한다. Dart 앱에는 탭이 없어 앱 안 single-flight만 둔다

### export

총 1611개.

- [x] `src/schemas/ai.ts` → `lib/src/schemas/ai.dart` (99): `aiAttachmentSchema`, `aiPreviewSelectionSchema`, `AiPreviewSelection`, `aiRunStatusSchema`, `AiRunStatus`, `AI_RUN_ACTIVE_STATUSES`, `aiStreamAccessSchema`, `AiStreamAccess`, `aiRunSchema`, `AiRun`, `aiActivitySchema`, `AiActivity`, `aiToolChangeSchema`, `AiToolChange`, `AI_AGENT_PHASES`, `aiAgentPhaseSchema`, `AiAgentPhase`, `AI_AGENT_NOTES_DIR`, `AI_TODO_STATUSES`, `aiTodoSchema`, `AiTodo`, `AI_TODOS_MAX`, `isAiAgentNotesPath`, `AI_DESIGN_DIR`, `AI_DESIGN_CANVAS_PATH`, `isAiDesignPath`, `AI_DESIGN_BOARD_FILE_PATTERN`, `AI_DESIGN_BOARD_KINDS`, `AI_DESIGN_VIEWPORTS`, `AI_DESIGN_BOARDS_MAX`, `aiDesignBoardSchema`, `AiDesignBoard`, `aiDesignCanvasSchema`, `AiDesignCanvas`, `aiDesignSelectionSchema`, `AiDesignSelection`, `STORE_SHOP_TYPES`, `storeShopTypeSchema`, `StoreShopType`, `aiChoiceOptionSchema`, `AiChoiceOption`, `aiSetupConfirmItemSchema`, `AiSetupConfirmItem`, `AI_SETUP_CONFIRM_APPROVE`, `aiDesignConfirmBoardSchema`, `AiDesignConfirmBoard`, `AI_DESIGN_CONFIRM_APPROVE`, `aiMessagePartSchema`, `AiMessagePart`, `aiMessageSchema`, `AiMessage`, `aiConversationSummarySchema`, `AiConversationSummary`, `aiConversationSchema`, `AiConversation`, `storeSetupBriefSchema`, `StoreSetupBrief`, `createAiConversationRequestSchema`, `CreateAiConversationRequest`, `createAiConversationResponseSchema`, `CreateAiConversationResponse`, `sendAiMessageRequestSchema`, `SendAiMessageRequest`, `sendAiMessageResponseSchema`, `SendAiMessageResponse`, `aiFocusAreaSchema`, `AiFocusArea`, `aiFocusSchema`, `AiFocus`, `AI_RUN_FILE_CHANGES_RETENTION_DAYS`, `aiRunChangesStatusSchema`, `AiRunChangesStatus`, `aiFileChangeKindSchema`, `AiFileChangeKind`, `aiRunChangesSchema`, `AiRunChanges`, `aiConversationFileChangesSchema`, `AiConversationFileChanges`, `aiRunFileDiffSchema`, `AiRunFileDiff`, `aiRunRevertResultSchema`, `AiRunRevertResult`, `aiRunRevertConflictDetailsSchema`, `AiRunRevertConflictDetails`, `aiStreamEventSchema`, `AiStreamEvent`, `aiStreamRecordSchema`, `AiStreamRecord`, `STORE_DRAFT_MAX_ATTACHMENTS`, `STORE_DRAFT_ATTACHMENT_MAX_BYTES`, `STORE_DRAFT_RETENTION_DAYS`, `createStoreDraftRequestSchema`, `CreateStoreDraftRequest`, `createStoreDraftResponseSchema`, `CreateStoreDraftResponse`, `storeDraftSchema`, `StoreDraft`, `storeDraftPreviewSchema`, `StoreDraftPreview`
- [x] `src/schemas/analytics.ts` → `lib/src/schemas/analytics.dart` (44): `analyticsRangeQuerySchema`, `AnalyticsRangeParams`, `analyticsTotalsSchema`, `AnalyticsTotals`, `analyticsFunnelStepSchema`, `AnalyticsFunnelStep`, `analyticsOverviewSchema`, `AnalyticsOverview`, `analyticsProductSortSchema`, `AnalyticsProductSort`, `analyticsProductsQuerySchema`, `AnalyticsProductsParams`, `analyticsProductRowSchema`, `AnalyticsProductRow`, `analyticsProductsSchema`, `AnalyticsProducts`, `analyticsChannelSchema`, `AnalyticsChannel`, `analyticsSourceGroupBySchema`, `AnalyticsSourceGroupBy`, `analyticsSourcesQuerySchema`, `AnalyticsSourcesParams`, `analyticsSourceRowSchema`, `AnalyticsSourceRow`, `analyticsSourcesSchema`, `AnalyticsSources`, `analyticsRealtimeSchema`, `AnalyticsRealtime`, `analyticsDeviceRowSchema`, `AnalyticsDeviceRow`, `analyticsDevicesSchema`, `AnalyticsDevices`, `analyticsPagesQuerySchema`, `AnalyticsPagesParams`, `analyticsPagesSchema`, `AnalyticsPages`, `analyticsSearchQuerySchema`, `AnalyticsSearchParams`, `analyticsSearchSchema`, `AnalyticsSearch`, `analyticsCheckoutOutcomeSchema`, `AnalyticsCheckoutOutcome`, `analyticsCheckoutSchema`, `AnalyticsCheckout`
- [x] `src/schemas/api-log.ts` → `lib/src/schemas/api-log.dart` (17): `apiLogPrincipalTypeSchema`, `ApiLogPrincipalType`, `apiLogPrincipalSchema`, `ApiLogPrincipal`, `apiLogErrorSchema`, `ApiLogError`, `apiLogSchema`, `ApiLog`, `apiLogStatusFilterSchema`, `ApiLogStatusFilter`, `apiLogListQuerySchema`, `ApiLogListParams`, `ApiLogListOptions`, `apiLogPageSchema`, `ApiLogPage`, `apiLogSummarySchema`, `ApiLogSummary`
- [x] `src/schemas/app-manifest.ts` → `lib/src/schemas/app-manifest.dart` (74): `APP_HANDLE_PATTERN`, `APP_RESERVED_HANDLES`, `appHandleSchema`, `NON_INSTALLABLE_SCOPES`, `INSTALLABLE_SCOPES`, `isInstallableScope`, `appScopeSchema`, `APP_LIFECYCLE_EVENT_TYPES`, `AppLifecycleEventType`, `AppEventType`, `AppLifecycleEventDataMap`, `AppEventDataOf`, `APP_EVENT_SCOPES`, `APP_EVENT_TYPES`, `appEventTypeSchema`, `scopesCoverEvent`, `APP_NETWORK_DENIED_SUFFIXES`, `appNetworkHostProblem`, `appNetworkHostSchema`, `APP_SETTING_FIELD_TYPES`, `AppSettingFieldType`, `APP_SETTINGS_MAX_FIELDS`, `APP_SETTING_KEY_PATTERN`, `appSettingFieldSchema`, `AppSettingField`, `APP_SECRET_NAME_PATTERN`, `APP_SECRETS_MAX`, `APP_EVENTS_MAX`, `APP_NETWORK_HOSTS_MAX`, `APP_PUBLIC_HTTP_MAX`, `APP_SCHEDULES_MAX`, `APP_HTTP_KEY_PATTERN`, `APP_SCHEDULE_NAME_PATTERN`, `APP_SCHEDULE_INTERVALS`, `AppScheduleInterval`, `APP_FLOW_NOTIFICATION_PATTERN`, `APP_FLOW_EVENT_PATTERN`, `APP_FLOW_ITEMS_MAX`, `appFlowParamSchema`, `AppFlowParam`, `appFlowNotificationSchema`, `AppFlowNotification`, `appFlowEventSchema`, `AppFlowEvent`, `APP_TOOL_NAME_PATTERN`, `appToolInputSchema`, `AppToolInput`, `appToolSchema`, `AppTool`, `APP_ICON_MAX_BYTES`, `APP_ICON_MIN_PX`, `APP_README_MAX_BYTES`, `APP_ICON_CONTENT_TYPES`, `AppIconContentType`, `appIconProblem`, `appManifestSchema`, `AppManifest`, `AppManifestInput`, `APP_SECRET_PATTERNS`, `APP_SERVER_BUNDLE_MAX_GZIP_BYTES`, `APP_UI_MAX_BYTES`, `APP_UI_MAX_FILES`, `AppManifestProblem`, `appManifestProblems`, `AppCapabilities`, `appCapabilitiesOf`, `AppCapabilityDefinition`, `APP_CAPABILITIES`, `appHttpKeyMatches`, `appScheduleListOf`, `appFlowSummaryOf`, `appToolListOf`, `appScheduleIntervalLabel`, `appManifestWidens`
- [x] `src/schemas/apps.ts` → `lib/src/schemas/apps.dart` (93): `appDistributionSchema`, `AppDistribution`, `appRuntimeSchema`, `AppRuntime`, `appStatusSchema`, `AppStatus`, `appInstallationStatusSchema`, `AppInstallationStatus`, `appVisibilitySchema`, `AppVisibility`, `appInstallationAppSchema`, `AppInstallationApp`, `appInstallationSettingsSchema`, `AppInstallationSettings`, `appInstallationSettingsUpdateSchema`, `AppInstallationSettingsUpdate`, `appScheduleSummarySchema`, `AppScheduleSummary`, `appFlowNotificationSummarySchema`, `AppFlowNotificationSummary`, `appFlowEventSummarySchema`, `AppFlowEventSummary`, `appInstallationSchema`, `AppInstallation`, `appInstallationRunSchema`, `AppInstallationRun`, `appInstallationActivitySchema`, `AppInstallationActivity`, `appInstallRequestSchema`, `AppInstallRequest`, `appListingSchema`, `AppListing`, `storeAppSchema`, `StoreApp`, `storeAppDetailSchema`, `StoreAppDetail`, `appSessionSchema`, `AppSession`, `appInstallationSelfSchema`, `AppInstallationSelf`, `appToolSummarySchema`, `AppToolSummary`, `appToolCallSchema`, `AppToolCall`, `appToolResultSchema`, `AppToolResult`, `APP_STORAGE_KEY_PATTERN`, `APP_STORAGE_MAX_KEYS`, `APP_STORAGE_MAX_BYTES`, `appStorageEntrySchema`, `AppStorageEntry`, `appStorageKeysSchema`, `AppStorageKeys`, `appStoragePutSchema`, `AppStoragePut`, `appStorageListQuerySchema`, `appBuildStageSchema`, `AppBuildStage`, `appBuildSchema`, `AppBuild`, `appVersionSchema`, `AppVersion`, `appListingReviewStatusSchema`, `AppListingReviewStatus`, `appListingReviewSchema`, `AppListingReview`, `developerAppSchema`, `DeveloperApp`, `developerAppCreateSchema`, `DeveloperAppCreate`, `appArtifactUploadSchema`, `AppArtifactUpload`, `appReleaseResultSchema`, `AppReleaseResult`, `appSecretSummarySchema`, `AppSecretSummary`, `devStoreSchema`, `DevStore`, `developerStoreSchema`, `DeveloperStore`, `developerInstallationSchema`, `DeveloperInstallation`, `appDevTokenSchema`, `AppDevToken`, `appInvocationSchema`, `AppInvocation`, `appDeployKeySchema`, `AppDeployKey`, `appDeployKeyCreatedSchema`, `AppDeployKeyCreated`, `appDeployKeyCreateSchema`, `APP_DEPLOY_KEY_PATTERN`, `APP_DEPLOY_KEY_PREFIX`
- [x] `src/schemas/audit.ts` → `lib/src/schemas/audit.dart` (32): `auditActorTypeSchema`, `AuditActorType`, `auditActorSchema`, `AuditActor`, `auditLogSourceSchema`, `AuditLogSource`, `auditLogOutcomeSchema`, `AuditLogOutcome`, `auditLogSchema`, `AuditLog`, `auditLogListQuerySchema`, `AuditLogListParams`, `AuditLogListOptions`, `auditLogPageSchema`, `AuditLogPage`, `agentPolicyDecisionSchema`, `AgentPolicyDecision`, `writePreviewSchema`, `WritePreview`, `writeDryRunResultSchema`, `WriteDryRunResult`, `approvalStatusSchema`, `ApprovalStatus`, `approvalRequestSchema`, `ApprovalRequest`, `approvalListQuerySchema`, `ApprovalListParams`, `ApprovalListOptions`, `approvalPageSchema`, `ApprovalPage`, `approvalDecisionRequestSchema`, `ApprovalDecisionRequest`
- [x] `src/schemas/auth.ts` → `lib/src/schemas/auth.dart` (6): `storeRoleSchema`, `StoreRole`, `myStoreSchema`, `MyStore`, `myAccountSchema`, `MyAccount`
- [x] `src/schemas/category.ts` → `lib/src/schemas/category.dart` (24): `categoryProductSortSchema`, `CategoryProductSort`, `categorySchema`, `Category`, `CategoryTreeNode`, `categoryTreeNodeSchema`, `categoryWithPathSchema`, `CategoryWithPath`, `categorySearchResultSchema`, `CategorySearchResult`, `categoryAttributeSchema`, `CategoryAttribute`, `categoryCreateRequestSchema`, `CategoryCreateRequest`, `categoryPatchRequestSchema`, `CategoryPatchRequest`, `categoryDeleteStrategySchema`, `CategoryDeleteStrategy`, `categoryListQuerySchema`, `categoryDeleteQuerySchema`, `categoryLocalizationSchema`, `CategoryLocalization`, `categoryLocalizationRequestSchema`, `CategoryLocalizationRequest`
- [x] `src/schemas/claim.ts` → `lib/src/schemas/claim.dart` (20): `claimTypeSchema`, `ClaimType`, `claimStatusSchema`, `ClaimStatus`, `claimReasonSchema`, `ClaimReason`, `claimReturnAddressSchema`, `ClaimReturnAddress`, `claimSchema`, `Claim`, `ClaimListParams`, `claimListQuerySchema`, `claimDetailSchema`, `ClaimDetail`, `claimHoldResultSchema`, `ClaimHoldResult`, `rejectClaimRequestSchema`, `RejectClaimRequest`, `approveClaimResultSchema`, `ApproveClaimResult`
- [x] `src/schemas/collection.ts` → `lib/src/schemas/collection.dart` (64): `MAX_COLLECTIONS`, `MAX_COLLECTION_PRODUCTS`, `MAX_COLLECTION_PRODUCTS_PER_ADD`, `MAX_COLLECTION_TITLE`, `MAX_COLLECTION_DESCRIPTION`, `COLLECTION_SLUG_PATTERN`, `COLLECTION_TYPES`, `CollectionType`, `COLLECTION_PRODUCT_SORTS`, `CollectionProductSort`, `collectionProductSortRequestSchema`, `collectionStateSchema`, `CollectionState`, `collectionStateOf`, `MAX_COLLECTION_RULES`, `MAX_COLLECTION_RULE_CATEGORIES`, `MAX_COLLECTION_CREATED_WITHIN_DAYS`, `COLLECTION_PREVIEW_SIZE`, `COLLECTION_BEST_SELLING_DAYS`, `CollectionBestSellingDays`, `MAX_COLLECTION_BEST_SELLING_TOP`, `COLLECTION_SALES_SORT_DEFAULT_DAYS`, `collectionRuleSchema`, `CollectionRule`, `CollectionRuleField`, `collectionRulesSchema`, `collectionRuleViewSchema`, `CollectionRuleView`, `CollectionRuleProduct`, `CollectionRuleContext`, `descendantCategoryIdsOf`, `collectionRulesPredicate`, `matchesCollectionRules`, `bestSellingRuleOf`, `compareBySales`, `rankBestSelling`, `collectionRuleCategoryIds`, `collectionSchema`, `Collection`, `collectionCreateRequestSchema`, `CollectionCreateRequest`, `CollectionCreateRequestInput`, `collectionPatchRequestSchema`, `CollectionPatchRequest`, `collectionProductsReplaceRequestSchema`, `CollectionProductsReplaceRequest`, `collectionProductsAddRequestSchema`, `CollectionProductsAddRequest`, `collectionProductSchema`, `CollectionProduct`, `collectionStateCountsSchema`, `collectionPageSchema`, `CollectionPage`, `CollectionListParams`, `collectionListQuerySchema`, `collectionProductListQuerySchema`, `collectionPreviewRequestSchema`, `CollectionPreviewRequest`, `collectionPreviewSchema`, `CollectionPreview`, `collectionLocalizationSchema`, `CollectionLocalization`, `collectionLocalizationRequestSchema`, `CollectionLocalizationRequest`
- [x] `src/schemas/commerce-flow.ts` → `lib/src/schemas/commerce-flow.dart` (60): `flowInputFieldSchema`, `FlowInputField`, `flowActionSchema`, `FlowAction`, `flowFieldValueSchema`, `FlowFieldValue`, `flowStateSchema`, `FlowState`, `orderItemFlowSchema`, `OrderItemFlow`, `moveFlowStateRequestSchema`, `MoveFlowStateRequest`, `flowRunStepSchema`, `flowRunSchema`, `FlowRun`, `flowActionRequestSchema`, `FlowActionRequest`, `flowActionResultSchema`, `FlowActionResult`, `flowPresetSummarySchema`, `FlowPresetSummary`, `flowPresetDetailSchema`, `FlowPresetDetail`, `commerceFlowSummarySchema`, `CommerceFlowSummary`, `commerceFlowVersionViewSchema`, `commerceFlowSchema`, `CommerceFlow`, `CommerceFlowVersionView`, `migrateFlowVersionRequestSchema`, `MigrateFlowVersionRequest`, `migrateFlowVersionResultSchema`, `MigrateFlowVersionResult`, `createCommerceFlowRequestSchema`, `CreateCommerceFlowRequest`, `saveFlowDraftRequestSchema`, `SaveFlowDraftRequest`, `commerceFlowCheckSchema`, `CommerceFlowCheck`, `resolvedFlowSchema`, `ResolvedFlow`, `flowSecretNameSchema`, `flowSecretSchema`, `FlowSecret`, `saveFlowSecretRequestSchema`, `SaveFlowSecretRequest`, `orderFlowActionResultSchema`, `OrderFlowActionResult`, `simulateFlowRequestSchema`, `SimulateFlowRequest`, `simulationStepSchema`, `SimulationStep`, `simulateFlowResultSchema`, `SimulateFlowResult`, `replayFlowRequestSchema`, `ReplayFlowRequest`, `replayFlowResultSchema`, `ReplayFlowResult`, `flowNodeTypesSchema`, `FlowNodeTypes`
- [x] `src/schemas/commerce-number.ts` → `lib/src/schemas/commerce-number.dart` (3): `formatOrderNo`, `parseOrderNo`, `commerceNumberField`
- [x] `src/schemas/common.ts` → `lib/src/schemas/common.dart` (11): `pageInfoSchema`, `PageInfo`, `pageSchema`, `pageQueryShape`, `PageParams`, `bulkResultSchema`, `BulkResult`, `orderItemStatusSchema`, `OrderItemStatus`, `changeTypeSchema`, `ChangeType`
- [x] `src/schemas/coupon.ts` → `lib/src/schemas/coupon.dart` (30): `couponStatusSchema`, `CouponStatus`, `couponIssueMethodSchema`, `CouponIssueMethod`, `COUPON_CODE_PATTERN`, `normalizeCouponCode`, `couponConditionsInputSchema`, `couponTargetInputSchema`, `createCouponRequestSchema`, `CreateCouponRequest`, `updateCouponRequestSchema`, `UpdateCouponRequest`, `couponSchema`, `Coupon`, `couponListQuerySchema`, `couponIssueStatusSchema`, `couponIssueSchema`, `CouponIssue`, `couponIssueListQuerySchema`, `issueCouponRequestSchema`, `IssueCouponRequest`, `issueCouponResultSchema`, `IssueCouponResult`, `couponRedemptionSchema`, `CouponRedemption`, `couponRedemptionListQuerySchema`, `couponStatsSchema`, `CouponStats`, `customerCouponSchema`, `CustomerCoupon`
- [x] `src/schemas/currency.ts` → `lib/src/schemas/currency.dart` (20): `CurrencySpec`, `CURRENCIES`, `CurrencyCode`, `CURRENCY_CODES`, `BASE_CURRENCY`, `currencyCodeSchema`, `isCurrencyCode`, `currencySpecOf`, `toMinor`, `minorToMajor`, `toDecimalString`, `fromDecimalString`, `floorToSaleUnit`, `isSaleUnitPrice`, `InvalidPriceUnitError`, `assertSaleUnit`, `minPaymentOf`, `MoneyRules`, `moneyRulesOf`, `KRW_MONEY_RULES`
- [x] `src/schemas/currency-prices.ts` → `lib/src/schemas/currency-prices.dart` (11): `productCurrencyPriceSchema`, `productCurrencyPricesSchema`, `ProductCurrencyPrice`, `shippingCurrencyPriceSchema`, `shippingCurrencyPricesSchema`, `storedShippingCurrencyPriceSchema`, `storedProductCurrencyPriceSchema`, `additionalCurrencyPriceSchema`, `additionalCurrencyPricesSchema`, `AdditionalCurrencyPrice`, `storedAdditionalCurrencyPriceSchema`
- [x] `src/schemas/customer.ts` → `lib/src/schemas/customer.dart` (28): `customerSortSchema`, `CustomerSort`, `customerListQuerySchema`, `customerStatsSchema`, `customerSummarySchema`, `CustomerSummary`, `customerAddressSchema`, `consentKindSchema`, `ConsentKind`, `consentActionSchema`, `ConsentAction`, `consentSourceSchema`, `ConsentSource`, `customerConsentSchema`, `CustomerConsent`, `customerConsentStateSchema`, `CustomerConsentState`, `customerConsentsSchema`, `CustomerConsents`, `customerConsentListQuerySchema`, `customerDetailSchema`, `CustomerDetail`, `customerOrderSchema`, `CustomerOrder`, `withdrawCustomerRequestSchema`, `WithdrawCustomerRequest`, `customerWithdrawalBlockedDetailsSchema`, `CustomerWithdrawalBlockedDetails`
- [x] `src/schemas/customer-delegation.ts` → `lib/src/schemas/customer-delegation.dart` (4): `customerDelegationRequestSchema`, `CustomerDelegationRequest`, `customerDelegationSchema`, `CustomerDelegation`
- [x] `src/schemas/fulfillment.ts` → `lib/src/schemas/fulfillment.dart` (45): `fulfillmentTypeSchema`, `FulfillmentType`, `fulfillmentTypeResponseSchema`, `FulfillmentRule`, `FULFILLMENT_RULES`, `fulfillmentTypeOf`, `fulfillmentRuleOf`, `FULFILLMENT_METHODS`, `fulfillmentMethodSchema`, `FulfillmentMethod`, `FulfillmentMethodRule`, `FULFILLMENT_METHOD_RULES`, `FULFILLMENT_METHODS_BY_TYPE`, `defaultFulfillmentMethodOf`, `fulfillmentMethodsOf`, `fulfillmentMethodOf`, `requiresShipping`, `requiresCollection`, `NO_SHIPPING_BUNDLE_KEY`, `deliveryTypeSchema`, `DeliveryType`, `productFulfillmentCreateSchema`, `ProductFulfillmentCreate`, `ProductFulfillmentCreateInput`, `productFulfillmentUpdateSchema`, `ProductFulfillmentUpdate`, `productFulfillmentSchema`, `ProductFulfillment`, `ProductFulfillmentOf`, `UnknownFulfillment`, `openFulfillmentUnion`, `productFulfillmentResponseSchema`, `ProductFulfillmentView`, `pickupLocationSnapshotSchema`, `PickupLocationSnapshot`, `orderItemFulfillmentSnapshotSchema`, `OrderItemFulfillmentSnapshot`, `orderItemFulfillmentSnapshotResponseSchema`, `OrderItemFulfillmentSnapshotView`, `MAX_PICKUP_LOCATIONS`, `pickupLocationSchema`, `PickupLocation`, `pickupLocationRequestSchema`, `PickupLocationRequest`, `PickupLocationRequestInput`
- [x] `src/schemas/inventory.ts` → `lib/src/schemas/inventory.dart` (32): `inventoryAdjustmentReasonSchema`, `InventoryAdjustmentReason`, `inventoryLocationSchema`, `InventoryLocation`, `inventoryLocationRequestSchema`, `InventoryLocationRequest`, `inventoryLevelSchema`, `InventoryLevel`, `inventoryLevelListQuerySchema`, `InventoryLevelListQuery`, `inventoryLevelPageSchema`, `InventoryLevelPage`, `inventoryMovementKindSchema`, `InventoryMovementKind`, `inventoryMovementSchema`, `InventoryMovement`, `inventoryMovementListQuerySchema`, `InventoryMovementListQuery`, `inventoryMovementPageSchema`, `InventoryMovementPage`, `MAX_INVENTORY_OPERATION_LINES`, `inventoryAdjustmentLineSchema`, `inventoryAdjustmentRequestSchema`, `InventoryAdjustmentRequest`, `inventoryTransferRequestSchema`, `InventoryTransferRequest`, `inventoryOperationResultSchema`, `InventoryOperationResult`, `claimCollectCompleteRequestSchema`, `ClaimCollectCompleteRequest`, `claimRedeliveryRequestSchema`, `ClaimRedeliveryRequest`
- [x] `src/schemas/locale.ts` → `lib/src/schemas/locale.dart` (3): `normalizeLocale`, `DEFAULT_STORE_LOCALE`, `localeCodeSchema`
- [x] `src/schemas/login.ts` → `lib/src/schemas/login.dart` (13): `loginProviderSchema`, `LoginProvider`, `loginProviderStatusSchema`, `LoginProviderStatus`, `loginSettingsSchema`, `LoginSettings`, `updateLoginSettingsRequestSchema`, `UpdateLoginSettingsRequest`, `saveLoginProviderRequestSchema`, `SaveLoginProviderRequest`, `updateLoginProviderRequestSchema`, `loginProviderTestSchema`, `LoginProviderTest`
- [x] `src/schemas/market.ts` → `lib/src/schemas/market.dart` (8): `marketSchema`, `Market`, `createMarketRequestSchema`, `CreateMarketRequest`, `CreateMarketRequestInput`, `updateMarketRequestSchema`, `UpdateMarketRequest`, `UpdateMarketRequestInput`
- [x] `src/schemas/misc.ts` → `lib/src/schemas/misc.dart` (66): `inquirySchema`, `Inquiry`, `customerInquiryCategorySchema`, `CustomerInquiryCategory`, `sellerCustomerInquirySchema`, `SellerCustomerInquiry`, `inquiryListQuerySchema`, `customerInquiryListQuerySchema`, `settlementStatusSchema`, `SettlementStatus`, `settlementSummarySchema`, `SettlementSummary`, `settlementDetailSchema`, `SettlementDetail`, `settlementWithDetailsSchema`, `SettlementWithDetails`, `settlementListQuerySchema`, `settlementDetailQuerySchema`, `SettlementListParams`, `eventTypeSchema`, `EventType`, `webhookStatusSchema`, `WebhookStatus`, `webhookSchema`, `Webhook`, `webhookCreatedSchema`, `WebhookCreated`, `webhookSecretRotatedSchema`, `WebhookSecretRotated`, `webhookDeliveryStatusSchema`, `WebhookDeliveryStatus`, `webhookDeliveryErrorCodeSchema`, `WebhookDeliveryErrorCode`, `WEBHOOK_FAILURE_REASONS`, `WebhookFailureReason`, `webhookFailureReasonSchema`, `WEBHOOK_RESOURCE_TYPES`, `WebhookResourceType`, `webhookResourceTypeSchema`, `webhookDeliveryResourceSchema`, `WebhookDeliveryResource`, `webhookRequestHeaderSchema`, `WebhookRequestHeader`, `webhookDeliverySchema`, `WebhookDelivery`, `WEBHOOK_PAYLOAD_EXCERPT_MAX_BYTES`, `webhookDeliveryDetailSchema`, `WebhookDeliveryDetail`, `webhookDeliveryListQuerySchema`, `WebhookDeliveryListParams`, `webhookRedeliverFailedResultSchema`, `WebhookRedeliverFailedResult`, `webhookTestRequestSchema`, `WebhookTestRequest`, `webhookTestResultSchema`, `WebhookTestResult`, `webhookRequestSchema`, `WebhookRequest`, `reviewSchema`, `Review`, `reviewSortSchema`, `ReviewSort`, `ReviewListParams`, `reviewListQuerySchema`, `reviewReportResultSchema`, `ReviewReportResult`
- [x] `src/schemas/order.ts` → `lib/src/schemas/order.dart` (52): `orderSummarySchema`, `OrderSummary`, `shippingAddressSchema`, `ShippingAddress`, `orderItemFulfillmentSchema`, `OrderItemFulfillment`, `orderItemSchema`, `OrderItem`, `orderDiscountSchema`, `OrderDiscount`, `orderSchema`, `Order`, `orderSummaryPageSchema`, `OrderSummaryPage`, `orderItemPageSchema`, `OrderItemPage`, `orderListQuerySchema`, `orderItemListQuerySchema`, `OrderListParams`, `OrderItemListParams`, `deliveryMethodSchema`, `DeliveryMethod`, `dispatchRequestSchema`, `DispatchRequest`, `deliveryInfoSchema`, `DeliveryInfo`, `trackingStageResponseSchema`, `deliveryStatusSchema`, `DeliveryStatus`, `trackingUpdateResultSchema`, `TrackingUpdateResult`, `carrierSchema`, `Carrier`, `holdOrderItemRequestSchema`, `HoldOrderItemRequest`, `cancelBySellerRequestSchema`, `CancelBySellerRequest`, `fulfillRequestSchema`, `FulfillRequest`, `fulfillBulkRequestSchema`, `FulfillBulkRequest`, `cancelBySellerResultSchema`, `CancelBySellerResult`, `sellerCancelPreviewSchema`, `SellerCancelPreview`, `orderItemMemoResultSchema`, `OrderItemMemoResult`, `purchaseDecisionRequestResultSchema`, `PurchaseDecisionRequestResult`, `purchaseDecisionExtendResultSchema`, `PurchaseDecisionExtendResult`, `addressChangeRequestListSchema`
- [x] `src/schemas/payment.ts` → `lib/src/schemas/payment.dart` (108): `pgProviderSchema`, `PgProvider`, `pgProviderResponseSchema`, `DEDICATED_EASY_PAY_PROVIDER`, `pgPaymentMethodSchema`, `PgPaymentMethod`, `easyPayProviderSchema`, `EasyPayProvider`, `easyPayProviderResponseSchema`, `pgEnvironmentSchema`, `PgEnvironment`, `pgVerificationResultSchema`, `PgVerificationResult`, `TOSS_WIDGET_CLIENT_KEY_PATTERN`, `TOSS_WIDGET_SECRET_KEY_PATTERN`, `TOSS_WIDGET_KEY_MESSAGE`, `tossPaymentsCredentialsInputSchema`, `TossPaymentsCredentialsInput`, `PORTONE_MIN_CHANNELS`, `PORTONE_MAX_CHANNELS`, `PORTONE_CHANNEL_NAME_MAX_LENGTH`, `portOneChannelSchema`, `PortOneChannel`, `portOneCredentialsInputSchema`, `PortOneCredentialsInput`, `KAKAOPAY_TEST_CID`, `kakaoPayCredentialsInputSchema`, `KakaoPayCredentialsInput`, `naverPayCredentialsInputSchema`, `NaverPayCredentialsInput`, `PAYPAL_CURRENCIES`, `payPalCredentialsInputSchema`, `PayPalCredentialsInput`, `upsertTossPaymentsProviderRequestSchema`, `UpsertTossPaymentsProviderRequest`, `upsertPortOneProviderRequestSchema`, `UpsertPortOneProviderRequest`, `upsertKakaoPayProviderRequestSchema`, `UpsertKakaoPayProviderRequest`, `upsertNaverPayProviderRequestSchema`, `UpsertNaverPayProviderRequest`, `upsertPayPalProviderRequestSchema`, `UpsertPayPalProviderRequest`, `updatePaymentProviderRequestSchema`, `UpdatePaymentProviderRequest`, `verifyPaymentProviderRequestSchema`, `VerifyPaymentProviderRequest`, `updatePaymentSettingsRequestSchema`, `UpdatePaymentSettingsRequest`, `maskedSecretSchema`, `MaskedSecret`, `paymentCredentialSetSchema`, `PaymentCredentialSet`, `liveGateConditionCodeSchema`, `LiveGateConditionCode`, `liveGateConditionSchema`, `LiveGateCondition`, `liveGateSchema`, `LiveGate`, `liveGateErrorDetailsSchema`, `LiveGateErrorDetails`, `paymentProviderSchema`, `PaymentProvider`, `PAYMENT_ROUTING_EXCLUSION_CODES`, `KnownPaymentRoutingExclusion`, `paymentFailureWarningSchema`, `PaymentFailureWarning`, `paymentSettingsSchema`, `PaymentSettings`, `paymentProviderVerificationSchema`, `PaymentProviderVerification`, `salesReportGroupBySchema`, `SalesReportGroupBy`, `salesReportQuerySchema`, `SalesReportParams`, `salesTotalsSchema`, `SalesTotals`, `salesReportRowSchema`, `SalesReportRow`, `salesReportCurrencySchema`, `SalesReportCurrency`, `salesReportSchema`, `SalesReport`, `paymentRecordStatusSchema`, `PaymentRecordStatus`, `paymentAttemptStatusSchema`, `CASH_RECEIPT_STATUS_VALUES`, `KnownCashReceiptStatus`, `cashReceiptSchema`, `CashReceipt`, `paymentRecordSchema`, `PaymentRecord`, `paymentRecordPageSchema`, `PaymentRecordPage`, `paymentAttemptRecordSchema`, `PaymentAttemptRecord`, `paymentRefundRecordSchema`, `PaymentRefundRecord`, `paymentRecordDetailSchema`, `PaymentRecordDetail`, `paymentListQuerySchema`, `PaymentListParams`, `setPlatformTestKeysRequestSchema`, `SetPlatformTestKeysRequest`, `paymentStatusProviderSchema`, `PaymentStatusProvider`, `paymentStatusSchema`, `PaymentStatus`
- [ ] `src/schemas/plans.ts` → `lib/src/schemas/plans.dart` (6, npm 0.36.0에 없음 — 다음 npm 릴리스 뒤 생성): `planEntitlementsSchema`, `PlanEntitlementValues`, `publicPlanSchema`, `PublicPlan`, `publicPlansSchema`, `PublicPlans`
- [x] `src/schemas/points.ts` → `lib/src/schemas/points.dart` (48): `POINT_REVIEW_REWARD_MAX`, `POINT_EXPIRY_DAYS_MIN`, `POINT_EXPIRY_DAYS_MAX`, `POINT_EARN_RATE_BP_MAX`, `pointEarnRateBpSchema`, `reviewRewardPolicySchema`, `ReviewRewardPolicy`, `purchaseEarnPolicySchema`, `PurchaseEarnPolicy`, `POINT_USE_UNITS`, `pointUsePolicySchema`, `PointUsePolicy`, `pointPolicySchema`, `PointPolicy`, `POINT_POLICY_DEFAULTS`, `resolvePointPolicy`, `pointEarningEnabled`, `purchaseEarnRateOf`, `pointEarnOf`, `reviewRewardPointOf`, `pointExpiresAtOf`, `POINT_LOT_SOURCES`, `PointLotSource`, `POINT_ENTRY_TYPES`, `PointEntryType`, `pointPolicyNoticeSchema`, `PointPolicyNotice`, `storePointPolicySchema`, `StorePointPolicy`, `updatePointPolicyRequestSchema`, `UpdatePointPolicyRequest`, `responsePointEntryTypeSchema`, `pointEntrySchema`, `PointEntry`, `pointLotSchema`, `PointLot`, `customerPointsSchema`, `CustomerPoints`, `pointHistoryQuerySchema`, `PointHistoryQuery`, `POINT_ADJUSTMENT_MAX`, `pointAdjustmentRequestSchema`, `PointAdjustmentRequest`, `pointAdjustmentResultSchema`, `PointAdjustmentResult`, `PointLotUsage`, `pointRestoreExpiresAtOf`, `splitRefund`
- [x] `src/schemas/product.ts` → `lib/src/schemas/product.dart` (75): `productStatusSchema`, `ProductStatus`, `productSummarySchema`, `ProductSummary`, `optionValueSchema`, `OptionValue`, `optionGroupSchema`, `OptionGroup`, `productVariantSchema`, `ProductVariant`, `MAX_OPTION_GROUPS`, `MAX_VALUES_PER_GROUP`, `MAX_VARIANTS`, `MAX_ADDON_GROUPS`, `MAX_CUSTOM_INPUTS`, `MAX_CUSTOM_INPUT_LENGTH`, `VARIANT_COUNT_WARNING`, `optionSortSchema`, `OptionSort`, `addonValueSchema`, `AddonValue`, `addonGroupSchema`, `AddonGroup`, `CUSTOM_INPUT_TYPES`, `customInputSchema`, `CustomInput`, `CUSTOM_INPUT_FORBIDDEN_WORDS`, `customInputLabelForbiddenWord`, `addonValueRequestSchema`, `AddonValueRequest`, `addonGroupRequestSchema`, `AddonGroupRequest`, `customInputRequestSchema`, `CustomInputRequest`, `optionSelectionSchema`, `OptionSelection`, `customInputValueSchema`, `CustomInputValue`, `discountSchema`, `Discount`, `productSchema`, `Product`, `MAX_PRODUCT_IMAGES`, `productImageUrlSchema`, `ProductImageRejection`, `productImageRejection`, `optionValueRequestSchema`, `OptionValueRequest`, `optionGroupRequestSchema`, `OptionGroupRequest`, `productVariantRequestSchema`, `ProductVariantRequest`, `optionModelRequestSchema`, `OptionModelRequest`, `optionModelSchema`, `OptionModel`, `VARIANT_STOCK_EXCLUSIVE_MESSAGE`, `variantStockRequestSchema`, `VariantStockRequest`, `variantStockSchema`, `VariantStock`, `productCreateRequestSchema`, `ProductCreateRequest`, `ProductCreateRequestInput`, `productReplaceRequestSchema`, `ProductReplaceRequest`, `ProductReplaceRequestInput`, `productPatchRequestSchema`, `ProductPatchRequest`, `productSortSchema`, `ProductSort`, `ProductListParams`, `productListQuerySchema`, `discountRequestSchema`, `DiscountRequest`
- [x] `src/schemas/product-info.ts` → `lib/src/schemas/product-info.dart` (33): `infoFieldSourceSchema`, `InfoFieldSource`, `infoSchemaFieldSchema`, `InfoSchemaField`, `infoSchemaSchema`, `InfoSchema`, `platformCodeSchema`, `PlatformCode`, `PLATFORM_CODE_SETS`, `productNoticeSchema`, `ProductNotice`, `MAX_NOTICE_VALUE_LENGTH`, `productNoticeRequestSchema`, `ProductNoticeRequest`, `CERTIFICATION_STATUSES`, `CertificationStatus`, `MAX_CERTIFICATION_ITEMS`, `productCertificationsSchema`, `ProductCertifications`, `productCertificationsRequestSchema`, `ProductCertificationsRequest`, `ProductCertificationsRequestInput`, `MAX_PRODUCT_INFO_SECTIONS`, `MAX_INFO_SECTION_TITLE`, `infoSectionSchema`, `InfoSection`, `infoSectionRequestSchema`, `InfoSectionRequest`, `InfoSectionRequestInput`, `infoSectionLocalizationSchema`, `InfoSectionLocalization`, `infoSectionLocalizationRequestSchema`, `InfoSectionLocalizationRequest`
- [x] `src/schemas/product-localization.ts` → `lib/src/schemas/product-localization.dart` (5): `productLocalizationSchema`, `ProductLocalization`, `productLocalizationRequestSchema`, `ProductLocalizationRequest`, `productLocalizationNeedsTranslation`
- [x] `src/schemas/promotion.ts` → `lib/src/schemas/promotion.dart` (42): `couponKindSchema`, `CouponKind`, `couponBenefitSchema`, `CouponBenefit`, `couponConditionsSchema`, `CouponConditions`, `COUPON_CONDITIONS_DEFAULTS`, `COUPON_TARGET_LIST_MAX`, `couponTargetSchema`, `CouponTarget`, `COUPON_TARGET_ALL`, `couponRuleSchema`, `CouponRule`, `couponRejectReasonSchema`, `CouponRejectReason`, `MIN_PAYMENT_AMOUNT`, `PricingLine`, `PricingCoupon`, `PricingDelivery`, `PricingPoints`, `PointRejectReason`, `PricingInput`, `CouponAllocation`, `PricingLineResult`, `PricingCouponResult`, `PricingBundleResult`, `PricingResult`, `couponDiscountOf`, `allocateByWeight`, `isCouponTargetLine`, `quotePricing`, `pointUseOf`, `AppliedCouponSnapshot`, `CouponSettlementLine`, `CouponSettlementState`, `CouponSettlementInput`, `CouponSettlementEntry`, `CouponSettlementResult`, `NO_COUPON_SETTLEMENT`, `settleCouponShortfall`, `proratedPaidRefundBase`, `proratedPointRefund`
- [x] `src/schemas/refund-policy.ts` → `lib/src/schemas/refund-policy.dart` (13): `currencyRefundFeesSchema`, `CurrencyRefundFees`, `refundPolicySchema`, `RefundPolicy`, `REFUND_POLICY_DEFAULTS`, `refundPolicyPatchSchema`, `RefundPolicyPatch`, `productRefundPolicyPatchSchema`, `RefundPolicyProductInput`, `resolveRefundPolicy`, `productRefundPolicyOverride`, `REFUND_POLICY_DELIVERY_FEE_KEYS`, `proratedRefundBase`
- [x] `src/schemas/saved-option-set.ts` → `lib/src/schemas/saved-option-set.dart` (32): `MAX_SAVED_OPTION_SETS`, `MAX_SAVED_OPTION_SET_NAME`, `optionGroupKindSchema`, `OptionGroupKind`, `savedOptionValueSchema`, `savedOptionGroupSchema`, `SavedOptionGroup`, `savedCustomInputSchema`, `SavedCustomInput`, `savedOptionSetSchema`, `SavedOptionSet`, `savedOptionValueRequestSchema`, `savedOptionGroupRequestSchema`, `SavedOptionGroupRequest`, `savedCustomInputRequestSchema`, `savedOptionSetRequestSchema`, `SavedOptionSetRequest`, `SavedOptionSetRequestInput`, `savedOptionSetFromProductRequestSchema`, `SavedOptionSetFromProductRequest`, `SavedOptionSetFromProductRequestInput`, `savedOptionSetFromProductResultSchema`, `SavedOptionSetFromProductResult`, `savedOptionSetCompositionSchema`, `savedOptionSetSortSchema`, `SavedOptionSetSort`, `SavedOptionSetListParams`, `savedOptionSetListQuerySchema`, `savedOptionSetLocalizationSchema`, `SavedOptionSetLocalization`, `savedOptionSetLocalizationRequestSchema`, `SavedOptionSetLocalizationRequest`
- [x] `src/schemas/scope.ts` → `lib/src/schemas/scope.dart` (7): `scopeAccessSchema`, `ScopeAccess`, `STORE_SCOPE_RESOURCES`, `StoreScopeResource`, `storeScopeResourceSchema`, `isStoreScope`, `STORE_ROLE_SCOPES`
- [x] `src/schemas/scope-descriptions.ts` → `lib/src/schemas/scope-descriptions.dart` (2): `SCOPE_DESCRIPTIONS`, `describeScope`
- [x] `src/schemas/shipping-policy.ts` → `lib/src/schemas/shipping-policy.dart` (23): `currencyShippingPolicySchema`, `CurrencyShippingPolicy`, `shippingPolicySchema`, `ShippingPolicy`, `SHIPPING_POLICY_DEFAULTS`, `shippingPolicyPatchSchema`, `ShippingPolicyPatch`, `resolveShippingPolicy`, `remoteAreaSchema`, `RemoteArea`, `REMOTE_AREA_ZIP_RANGES`, `remoteAreaOf`, `remoteAreaLabelOf`, `remoteSurchargeOf`, `DeliveryBundleProduct`, `deliveryBundleKeyOf`, `DeliveryFeeLine`, `deliveryFeeWaiverSchema`, `DeliveryFeeWaiver`, `DeliveryBundleQuote`, `DeliveryQuote`, `DeliveryQuoteInput`, `quoteDelivery`
- [x] `src/schemas/starter.ts` → `lib/src/schemas/starter.dart` (22): `storeIndustrySchema`, `StoreIndustry`, `brandBriefProductSourceSchema`, `BrandBriefProductSource`, `BRAND_BRIEF_MAX_REFERENCES`, `brandBriefReferenceSchema`, `BrandBriefReference`, `brandBriefSchema`, `BrandBrief`, `putBrandBriefRequestSchema`, `PutBrandBriefRequest`, `brandBriefViewSchema`, `BrandBriefView`, `STARTER_STAGES`, `starterStageSchema`, `StarterStage`, `STARTER_SELLER_TASKS`, `starterSellerTaskSchema`, `StarterSellerTask`, `starterStoreInfoFieldSchema`, `starterStatusSchema`, `StarterStatus`
- [x] `src/schemas/stay.ts` → `lib/src/schemas/stay.dart` (15): `calendarDateSchema`, `MAX_STAY_NIGHTS`, `MAX_CALENDAR_DAYS`, `inventoryModeSchema`, `InventoryMode`, `stayRangeSchema`, `StayRange`, `staySnapshotSchema`, `StaySnapshot`, `nightsOf`, `calendarDaySchema`, `CalendarDay`, `calendarQuerySchema`, `setCalendarRequestSchema`, `SetCalendarRequest`
- [x] `src/schemas/store.ts` → `lib/src/schemas/store.dart` (40): `STORE_CODE_PATTERN`, `RESERVED_STORE_CODES`, `isReservedStoreCode`, `storeCodeSchema`, `isWebOrigin`, `analyticsOriginSchema`, `MAX_ANALYTICS_ALLOWED_ORIGINS`, `MAX_AUTO_TRANSITION_DAYS`, `policyVersionSchema`, `policyDocumentUrlSchema`, `BUSINESS_NUMBER_PATTERN`, `normalizeBusinessNumber`, `businessNumberSchema`, `BUSINESS_INFO_MAX_LENGTH`, `businessInfoPatchShape`, `businessInfoResponseShape`, `updateStoreRequestSchema`, `UpdateStoreRequest`, `storeSchema`, `Store`, `storeMemberSchema`, `StoreMember`, `invitationDeliveryStatusSchema`, `InvitationDeliveryStatus`, `invitationSchema`, `Invitation`, `inviteMemberRequestSchema`, `InviteMemberRequest`, `updateMemberRoleRequestSchema`, `UpdateMemberRoleRequest`, `invitationListQuerySchema`, `storeMemberRoleUpdatedSchema`, `StoreMemberRoleUpdated`, `addressTypeSchema`, `AddressType`, `sellerAddressListQuerySchema`, `sellerAddressSchema`, `SellerAddress`, `sellerAddressRequestSchema`, `SellerAddressRequest`
- [x] `src/schemas/storefront-hosting.ts` → `lib/src/schemas/storefront-hosting.dart` (184): `STOREFRONT_SLUG_PATTERN`, `RESERVED_STOREFRONT_SLUGS`, `STOREFRONT_EDIT_PREVIEW_SUFFIX`, `STOREFRONT_SHOWCASE_SLUG_PREFIX`, `isShowcaseStorefrontSlug`, `isReservedStorefrontSlug`, `storefrontEditPreviewLabelOf`, `storefrontVersionPreviewLabelOf`, `storefrontSlugSchema`, `STOREFRONT_SLUG_HOLD_DAYS`, `STOREFRONT_CLOSED_SITE_HOLD_DAYS`, `STOREFRONT_SLUG_CHANGE_WINDOW_DAYS`, `STOREFRONT_SLUG_CHANGE_LIMIT`, `STOREFRONT_SITE_CREATE_LIMIT`, `storefrontTemplateSchema`, `StorefrontTemplate`, `storeTemplateSchema`, `StoreTemplate`, `TEMPLATE_STORE_LOCKED_BUSINESS_FIELDS`, `updateStoreTemplateRequestSchema`, `UpdateStoreTemplateRequest`, `storefrontVersionStatusSchema`, `StorefrontVersionStatus`, `storefrontVersionSchema`, `StorefrontVersion`, `storefrontSiteStatusSchema`, `StorefrontSiteStatus`, `storefrontVisibilitySchema`, `StorefrontVisibility`, `storefrontSourceModeSchema`, `storefrontDomainSchema`, `StorefrontDomain`, `storefrontProvisioningSchema`, `StorefrontProvisioning`, `storefrontEditPreviewSchema`, `StorefrontEditPreview`, `storefrontSuspensionSchema`, `StorefrontSuspension`, `storefrontSiteSnapshotSchema`, `StorefrontSiteSnapshot`, `storefrontSiteSchema`, `StorefrontSite`, `storefrontHostingSchema`, `StorefrontHosting`, `storefrontSlugAvailabilitySchema`, `StorefrontSlugAvailability`, `storefrontDeploymentStepSchema`, `StorefrontDeploymentStep`, `storefrontDeploymentLogSchema`, `StorefrontDeploymentLog`, `storefrontDeploymentSchema`, `StorefrontDeployment`, `createStorefrontSiteRequestSchema`, `CreateStorefrontSiteRequest`, `publishStorefrontVersionRequestSchema`, `PublishStorefrontVersionRequest`, `rollbackStorefrontRequestSchema`, `RollbackStorefrontRequest`, `changeStorefrontSlugRequestSchema`, `ChangeStorefrontSlugRequest`, `setStorefrontVisibilityRequestSchema`, `SetStorefrontVisibilityRequest`, `disableStorefrontHostingRequestSchema`, `DisableStorefrontHostingRequest`, `storefrontSlugAvailabilityQuerySchema`, `createStorefrontPreviewLinkRequestSchema`, `CreateStorefrontPreviewLinkRequest`, `storefrontPreviewLinkSchema`, `StorefrontPreviewLink`, `STOREFRONT_PLATFORM_DOMAINS`, `STOREFRONT_PUBLIC_SUFFIXES`, `STOREFRONT_CUSTOM_DOMAIN_LIMIT_DEFAULT`, `STOREFRONT_DOMAIN_DNS_WAIT_DAYS`, `STOREFRONT_DOMAIN_DNS_GRACE_DAYS`, `STOREFRONT_DOMAIN_TXT_LABEL`, `normalizeStorefrontHostname`, `StorefrontHostnameProblem`, `storefrontCustomHostnameProblem`, `storefrontDomainTxtNameOf`, `storefrontCustomDomainStatusSchema`, `StorefrontCustomDomainStatus`, `storefrontDnsRecordSchema`, `StorefrontDnsRecord`, `storefrontSiteDomainSchema`, `StorefrontSiteDomain`, `storefrontSiteDomainsSchema`, `StorefrontSiteDomains`, `addStorefrontDomainRequestSchema`, `AddStorefrontDomainRequest`, `STOREFRONT_EDIT_CAPACITY`, `STOREFRONT_EDIT_IDLE_MINUTES`, `STOREFRONT_EDIT_ACTIVITY_TIMEOUT_MINUTES`, `STOREFRONT_FILE_MAX_BYTES`, `STOREFRONT_WORKSPACE_MAX_BYTES`, `STOREFRONT_FILE_BATCH_MAX`, `STOREFRONT_BLOCKED_PATH_SEGMENTS`, `STOREFRONT_PATH_SEGMENT_PATTERN`, `normalizeStorefrontPath`, `isEditableStorefrontPath`, `storefrontFilePathSchema`, `storefrontFileHashSchema`, `storefrontFileEncodingSchema`, `storefrontEditSessionStatusSchema`, `STOREFRONT_EDIT_START_STAGES`, `storefrontEditSessionSchema`, `StorefrontEditSession`, `storefrontDevLogsSchema`, `StorefrontDevLogs`, `storefrontEditingSchema`, `StorefrontEditing`, `storefrontFileEntrySchema`, `StorefrontFileEntry`, `storefrontFileListSchema`, `StorefrontFileList`, `storefrontFileListQuerySchema`, `storefrontFileContentQuerySchema`, `storefrontFileContentSchema`, `StorefrontFileContent`, `writeStorefrontFilesRequestSchema`, `WriteStorefrontFilesRequest`, `storefrontFileWriteResultSchema`, `StorefrontFileWriteResult`, `storefrontFileConflictDetailsSchema`, `StorefrontFileConflictDetails`, `deleteStorefrontFileRequestSchema`, `DeleteStorefrontFileRequest`, `storefrontFileDeleteResultSchema`, `StorefrontFileDeleteResult`, `moveStorefrontFileRequestSchema`, `MoveStorefrontFileRequest`, `storefrontFileMoveResultSchema`, `StorefrontFileMoveResult`, `STOREFRONT_SEARCH_REGEX_MAX_LENGTH`, `searchStorefrontFilesRequestSchema`, `SearchStorefrontFilesRequest`, `storefrontFileSearchResultSchema`, `StorefrontFileSearchResult`, `runStorefrontCheckRequestSchema`, `RunStorefrontCheckRequest`, `storefrontCheckStatusSchema`, `StorefrontCheckStatus`, `STOREFRONT_CHECK_TERMINAL_STATUSES`, `storefrontCheckSchema`, `StorefrontCheck`, `storefrontRuleSeveritySchema`, `StorefrontRuleSeverity`, `storefrontRuleResultSchema`, `StorefrontRuleResult`, `storefrontVerifyReportSchema`, `StorefrontVerifyReport`, `storefrontBuildStatusSchema`, `StorefrontBuildStatus`, `STOREFRONT_BUILD_TERMINAL_STATUSES`, `STOREFRONT_BUILD_STAGES`, `storefrontDependencyFindingSchema`, `StorefrontDependencyFinding`, `storefrontBuildDependenciesSchema`, `StorefrontBuildDependencies`, `storefrontBuildSchema`, `StorefrontBuild`, `storefrontBuildListQuerySchema`, `createStorefrontVersionRequestSchema`, `CreateStorefrontVersionRequest`, `storefrontVersionCreatedSchema`, `StorefrontVersionCreated`, `createStorefrontEditPreviewLinkRequestSchema`, `CreateStorefrontEditPreviewLinkRequest`, `STOREFRONT_SOURCE_PART_BYTES`, `STOREFRONT_SOURCE_BLOB_BATCH_MAX`, `STOREFRONT_WORKSPACE_MAX_FILES`, `storefrontSourceRefSchema`, `storefrontSourceSchema`, `StorefrontSource`, `storefrontSourceArchiveQuerySchema`, `storefrontSourceArchivePartSchema`, `StorefrontSourceArchivePart`, `uploadStorefrontSourceBlobsRequestSchema`, `UploadStorefrontSourceBlobsRequest`, `storefrontSourceBlobsResultSchema`, `StorefrontSourceBlobsResult`, `replaceStorefrontSourceRequestSchema`, `ReplaceStorefrontSourceRequest`, `storefrontSourceReplacedSchema`, `StorefrontSourceReplaced`
- [x] `src/schemas/subscription.ts` → `lib/src/schemas/subscription.dart` (14): `planCodeSchema`, `PlanCode`, `responsePlanCodeSchema`, `ResponsePlanCode`, `subscriptionStatusSchema`, `SubscriptionStatus`, `subscriptionLimitsSchema`, `SubscriptionLimits`, `subscriptionUsageSchema`, `SubscriptionUsage`, `storeSubscriptionSchema`, `StoreSubscription`, `planErrorDetailsSchema`, `PlanErrorDetails`
- [x] `src/schemas/telemetry.ts` → `lib/src/schemas/telemetry.dart` (5): `mcpRuleResultSchema`, `McpRuleResult`, `MCP_TELEMETRY_MAX_RESULTS`, `mcpToolEventSchema`, `McpToolEvent`
- [x] `src/schemas/upload.ts` → `lib/src/schemas/upload.dart` (11): `uploadPurposeSchema`, `UploadPurpose`, `UploadPurposeLimit`, `UPLOAD_PURPOSE_LIMITS`, `uploadExtensionOf`, `UploadRejection`, `uploadRejection`, `uploadRequestSchema`, `UploadRequest`, `uploadTicketSchema`, `UploadTicket`
- [x] `src/schemas/webhook-event.ts` → `lib/src/schemas/webhook-event.dart` (37): `orderWebhookEventDataSchema`, `OrderWebhookEventData`, `orderFulfilledWebhookEventDataSchema`, `OrderFulfilledWebhookEventData`, `orderCanceledWebhookEventDataSchema`, `OrderCanceledWebhookEventData`, `claimWebhookEventDataSchema`, `ClaimWebhookEventData`, `inquiryWebhookEventDataSchema`, `InquiryWebhookEventData`, `reviewWebhookEventDataSchema`, `ReviewWebhookEventData`, `productOutOfStockWebhookEventDataSchema`, `ProductOutOfStockWebhookEventData`, `inventoryChangedWebhookEventDataSchema`, `InventoryChangedWebhookEventData`, `orderWebhookEventSchema`, `orderFulfilledWebhookEventSchema`, `orderCanceledWebhookEventSchema`, `claimWebhookEventSchema`, `inquiryWebhookEventSchema`, `reviewWebhookEventSchema`, `productOutOfStockWebhookEventSchema`, `inventoryChangedWebhookEventSchema`, `flowNotificationWebhookEventDataSchema`, `flowNotificationWebhookEventSchema`, `flowStateChangedWebhookEventDataSchema`, `flowStateChangedWebhookEventSchema`, `webhookEventSchema`, `WebhookEvent`, `WebhookEventType`, `WebhookEventOf`, `KNOWN_WEBHOOK_EVENT_TYPES`, `unknownWebhookEventSchema`, `UnknownWebhookEvent`, `ParsedWebhookEvent`, `parseWebhookEvent`
- [x] `src/webhook-headers.ts` → `lib/src/webhook-headers.dart` (7): `WEBHOOK_DEFAULT_TOLERANCE_SEC`, `WEBHOOK_DELIVERY_ID_HEADER`, `WEBHOOK_EVENT_ID_HEADER`, `WEBHOOK_EVENT_TYPE_HEADER`, `WEBHOOK_HEADERS`, `WEBHOOK_SIGNATURE_HEADER`, `WEBHOOK_USER_AGENT`
- [x] `src/client.ts` → `lib/src/client.dart` (3): `StoreClient`, `StoreClientOptions`, `createStoreClient`
- [x] `src/http.ts` → `lib/src/http.dart` (7): `Query`, `TokenSource`, `APPROVAL_ALREADY_DECIDED_CODE`, `APPROVAL_REQUIRED_CODE`, `ApiError`, `ApprovalPendingError`, `buildQuery`
- [x] `src/oauth.ts` → `lib/src/oauth.dart` (6): `buildAuthorizeUrl`, `createPkcePair`, `exchangeAuthorizationCode`, `OAuthTokenResponse`, `oauthTokenResponseSchema`, `refreshUserToken`
- [x] `src/session.ts` → `lib/src/session.dart` (7): `AuthorizeOptions`, `createStoreSession`, `SessionStorage`, `STORE_SESSION_KEYS`, `StoreAuthServer`, `StoreSession`, `StoreSessionOptions`
- [x] `ZodError` (설계 규칙 「검증과 오류」)

## `@sayren/store-sdk/server` → `server.dart`

### export

총 18개. `package:sayren_store_sdk/server.dart`로 공개한다.

- [x] 서명 비교는 WebCrypto `verify` 대신 HMAC-SHA256(`crypto`) 결과를 상수 시간으로 비교한다
- [x] `secret`(`string | string[]`)은 `Object`로 받는다(`String` 또는 `List<String>`). 시크릿이 비면 `ArgumentError`다
- [x] `WebhookSignatureVerification`(판별 값 `ok: true/false`)의 하위 클래스는 `WebhookSignatureVerificationOk`·`WebhookSignatureVerificationFailed`다
- [x] `delegateMember`의 인라인 옵션은 네임드 인자다

- [x] `src/member-delegation.ts` → `lib/src/member-delegation.dart` (3): `DelegatedMemberToken`, `delegateMember`, `MemberDelegationError`
- [x] `src/webhook-headers.ts` → `lib/src/webhook-headers.dart` (7): `WEBHOOK_DEFAULT_TOLERANCE_SEC`, `WEBHOOK_DELIVERY_ID_HEADER`, `WEBHOOK_EVENT_ID_HEADER`, `WEBHOOK_EVENT_TYPE_HEADER`, `WEBHOOK_HEADERS`, `WEBHOOK_SIGNATURE_HEADER`, `WEBHOOK_USER_AGENT`
- [x] `src/webhook-signature.ts` → `lib/src/webhook-signature.dart` (8): `ParsedWebhookSignature`, `parseWebhookSignatureHeader`, `SignWebhookPayloadOptions`, `signWebhookPayload`, `VerifyWebhookSignatureOptions`, `verifyWebhookSignature`, `WebhookSignatureFailureReason`, `WebhookSignatureVerification`

---

## 만들지 않는 이름 (Node `@deprecated`)

| Node 이름 | 위치 | 비고 |
|---|---|---|
| `PaymentMode` | `payments` export | 결제 서비스 팝업 폐지 |
| `PaymentPopup` · `PaymentPostMessage` | `payments` export | 〃 |
| `PreparedPaymentWindow` · `PREPARED_WINDOW` · `Payments.prepareWindow` | `payments` export·멤버 | 〃 |
| `StartOptions.mode`·`window`, `RetryOptions.mode`·`window`, `open`의 `options` | `payments` 옵션 | 〃 |
| `PaymentsEnv.openPopup`·`subscribe`·`now`·`setInterval`·`clearInterval` | `payments` 의존부 | 〃 |
| `settlements.list` · `settlements.get` | `createStoreClient` | `salesReport.get`으로 대체 |
| `storefront.changeTemplate` · `changeStorefrontTemplateRequestSchema` · `ChangeStorefrontTemplateRequest` | `createStoreClient`·export | 서버가 항상 409 |
| `analyticsAllowedOrigins` 필드 | 상점 수정 요청 스키마(`schemas/store.ts`) | `storefrontOrigins`로 대체 |

목록 대조 스크립트는 이 표의 이름을 Node 목록에서 빼고 비교한다.

## 단계

| 단계 | 범위 |
|---|---|
| Phase 0 | 기반: `http.ts`(엔벨로프 해제·`ApiError`·`buildQuery`·`TokenSource`·401 refresh 재시도), 스키마 상수·`ZodError`, `schemas/common.ts`, 목록 대조 스크립트 |
| Phase 1 | `@sayren/storefront-sdk` 기본 엔트리포인트(클라이언트·세션·스키마) |
| Phase 2 | `@sayren/storefront-sdk/auth` · `/payments` · `/analytics` |
| Phase 3 | `@sayren/store-sdk` 기본 엔트리포인트 |
| Phase 4 | `@sayren/store-sdk/server` |

Phase 0~4가 모두 끝났다. `sayren_store_sdk`는 Flutter 의존이 없는 Dart 패키지다(테스트는 `dart test`).

동작 대조 하네스(`tool/parity`)는 같은 자료를 npm의 `@sayren/storefront-sdk`와 Dart SDK에 넣고 결과를 비교한다.

- 시나리오: 옵션·인자·서버 응답 → 요청(메서드·URL·헤더·본문)과 결과(파싱 값·`ApiError`·`ZodError` 이슈 코드와 경로). 손으로 쓴 `scenarios.json`과 메서드마다 생성한 `generated/scenarios.json`이다.
- 스키마 대조: export 스키마마다 유효 예시·`null`·키 하나 빼기·키 하나 타입 바꾸기(`generated/schema-cases.json`).
- 세션·인증·분석·결제: `session-scenarios.json`·`auth-scenarios.json`·`analytics-scenarios.json`·`payments-scenarios.json`. 분석·결제는 같은 가짜 env를 양쪽에 넣는다.

- 관리 API(`tool/parity/store`): 서버 엔트리포인트(`server-scenarios.json`, 웹훅 서명·파싱·검증과 구매자 위임)도 대조한다.
- 관리 API 기본: 생성 예시와 손 시나리오(`scenarios.json`, 오버라이드 메서드·승인 대기·OAuth 오류·업로드), 스키마 대조, 손으로 쓴 함수 대조(`functions/*.json`, Dart 어댑터 `packages/store-sdk/tool/functions/`), 세션·OAuth(`session-scenarios.json`, 무작위 값은 자리표시로 바꿔 비교).

실행은 `tool/parity`에서 `npm install` 후 `node compare.mjs`(`--verbose`면 모든 항목, `node compare.mjs store`면 대상 하나)다. 대조로 볼 수 없는 Dart 쪽 동작(getter 캐스트, Future 오류 전달, `fromJson` 검증, 모델 생성자, `Nullable`)은 각 패키지 `test`가 확인한다.

목록 대조 스크립트(`tool/parity/names.mjs`)는 Node 엔트리포인트의 export 이름이 Dart 엔트리포인트에서 모두 보이는지 확인한다(Dart에만 있는 익명 클래스 이름은 허용한다). 각 Phase는 이 대조를 통과해야 끝난다.

## 배포

- `sayren_storefront_sdk`·`sayren_store_sdk`는 pub.dev에 공개 게시한다. Node SDK(`@sayren/storefront-sdk`·`@sayren/store-sdk`)도 npm 공개 패키지다
- 라이선스는 Apache-2.0이다. 첫 버전은 두 패키지 모두 0.1.0이고, 0.x 동안 호환되지 않는 변경은 minor를 올린다
- 게시 파일에서 `tool/`(대조 하네스)은 뺀다(`.pubignore`)

## 미정 사항

- 모델 클래스 작성 방식(수기 작성 또는 Node 스키마 기반 코드 생성)
- 지원 플랫폼 범위(iOS·Android 외 Web·데스크톱)
