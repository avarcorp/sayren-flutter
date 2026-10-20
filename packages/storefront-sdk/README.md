# sayren_storefront_sdk

sayren 스토어프론트 API를 Flutter에서 호출하는 SDK입니다. Node SDK `@sayren/storefront-sdk`와 이름·사용법이 같습니다.

구매자 앱에서 상점 정보, 카탈로그, 장바구니, 주문, 회원 기능을 호출하고, 소셜 로그인·결제·방문 분석을 붙입니다.

## Features

- Node SDK와 같은 팩토리·옵션·네임스페이스·메서드·모델 이름
- 요청 전·응답 후 Node SDK와 같은 규칙으로 검증(`ZodError`), 서버 오류는 `ApiError`
- 세션: 토큰 저장, 401 시 갱신 후 재시도
- 결제: `payments.start` 한 번의 `await`로 WebView 결제창 표시부터 결과 확정까지
- 엔트리포인트: `sayren_storefront_sdk.dart`(클라이언트·세션·스키마), `auth.dart`(소셜 로그인), `payments.dart`(결제), `analytics.dart`(방문 분석)

## Requirements

- Dart 3.6 이상, Flutter 3.27 이상

## Installation

```sh
flutter pub add sayren_storefront_sdk
```

## Getting Started

클라이언트를 만들고 상점 정보와 상품을 읽습니다.

```dart
import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';

final client = createStorefrontClient(StorefrontClientOptions(
  baseUrl: 'https://api.sayren.io/storefront/v1',
  storeCode: 'my-store',
));

final store = await client.store.get();
final products = await client.catalog.searchProducts(ProductSearchParams(keyword: '셔츠', size: 20));
```

회원 로그인은 세션을 만들어 클라이언트에 넘깁니다. 세션이 토큰을 저장하고, 만료되면 갱신합니다.

```dart
final session = createStorefrontSession(StorefrontSessionOptions(
  baseUrl: 'https://api.sayren.io/storefront/v1',
  storeCode: 'my-store',
  storage: storage, // SessionStorage를 구현한 앱의 저장소
));
final client = createStorefrontClient(StorefrontClientOptions(
  baseUrl: 'https://api.sayren.io/storefront/v1',
  storeCode: 'my-store',
  session: session,
));

await session.login(LoginRequest(email: email, password: password));
final me = await client.userinfo();
```

결제는 `start` 한 번이면 끝납니다.

```dart
import 'package:sayren_storefront_sdk/payments.dart';

final payments = createPayments(PaymentsOptions(
  client: client,
  returnUrl: 'https://shop.example.com/payments/return',
));

final result = await payments.start(checkoutId, StartOptions(option: option, shippingAddress: address));
switch (result) {
  case PaymentResultCompleted(:final orderId): // 주문 완료 화면
  case PaymentResultFailed(:final message): // 실패 안내, payments.retry로 다시 시도
  case PaymentResultCanceled(): // 구매자가 결제창을 닫음
  case PaymentResultProcessing(:final paymentId): // 확인 중, payments.getStatus로 다시 조회
  case PaymentResultInvalid():
}
```

소셜 로그인은 `package:sayren_storefront_sdk/auth.dart`, 방문 분석은 `package:sayren_storefront_sdk/analytics.dart`에 있습니다.

## Documentation

- 공개 API마다 dartdoc이 있습니다. 이 페이지의 API reference를 참고하십시오.
- Node SDK와의 대응과 설계 규칙: [ROADMAP.md](https://github.com/avarcorp/sayren-flutter/blob/HEAD/ROADMAP.md)
- 저장소·이슈: [avarcorp/sayren-flutter](https://github.com/avarcorp/sayren-flutter)

## License

Apache License 2.0. [LICENSE](LICENSE)를 참고하십시오.
