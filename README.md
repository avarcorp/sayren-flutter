# sayren-flutter

sayren 공개 API를 Dart·Flutter에서 호출하는 SDK입니다. Node SDK(`@sayren/storefront-sdk`·`@sayren/store-sdk`)와 이름·사용법이 같습니다.

| 패키지 | 대응 Node SDK | 용도 | 런타임 |
|---|---|---|---|
| [`sayren_storefront_sdk`](packages/storefront-sdk) | `@sayren/storefront-sdk` 0.24.0 | 구매자 앱 — 상점·카탈로그·장바구니·주문·회원, 로그인, 결제, 방문 분석 | Flutter |
| [`sayren_store_sdk`](packages/store-sdk) | `@sayren/store-sdk` 0.36.0 | 셀러 도구 — 상품·주문·클레임·설정 관리, 웹훅 서명 검증 | Dart |

## Features

- **Node SDK와 같은 API**: 팩토리, 옵션, 네임스페이스, 메서드, 스키마, 모델 이름이 Node SDK와 1:1로 대응합니다. Node 문서와 예제를 그대로 따라 쓸 수 있습니다.
- **같은 검증 규칙**: 요청 본문은 보내기 전에, 응답은 받은 뒤에 Node SDK와 같은 zod 규칙으로 검증합니다. 계약에 맞지 않으면 `ZodError`, 서버 오류는 `ApiError`입니다.
- **타입 있는 모델**: 응답은 불변 모델 클래스(`fromJson`·`toJson`·값 비교)이고, 판별 union은 sealed class입니다.
- **한 번의 `await`로 끝나는 결제**: `payments.start`가 결제창(WebView) 표시, 복귀 처리, 승인, 결과 확정까지 합니다.
- **세션 관리**: 토큰 저장, 401 시 갱신 후 재시도, 갱신 토큰 회전을 SDK가 처리합니다. 저장 매체는 앱이 정합니다.
- **Node와 대조한 동작**: 같은 입력을 Node SDK와 Dart SDK에 넣어 요청·응답·오류가 같은지 확인합니다([Development](#development)).

## Requirements

- Dart 3.6 이상
- `sayren_storefront_sdk`: Flutter 3.27 이상(결제 WebView·방문 분석 저장소를 사용합니다)
- `sayren_store_sdk`: Flutter 없이 Dart만으로 동작합니다(서버·CLI에서도 사용할 수 있습니다)

## Installation

pub.dev 게시 전에는 git 의존성으로 설치합니다.

```yaml
dependencies:
  sayren_storefront_sdk:
    git:
      url: https://github.com/avarcorp/sayren-flutter.git
      path: packages/storefront-sdk
  sayren_store_sdk:
    git:
      url: https://github.com/avarcorp/sayren-flutter.git
      path: packages/store-sdk
```

```sh
flutter pub get
```

## Getting Started

### 스토어프론트 (구매자 앱)

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

### 관리 API (셀러 도구)

계정 토큰(개인 액세스 토큰 등)과 상점 id로 관리 API를 호출합니다.

```dart
import 'package:sayren_store_sdk/sayren_store_sdk.dart';

final client = createStoreClient(StoreClientOptions(
  baseUrl: 'https://api.sayren.io/v1',
  accessToken: personalAccessToken,
  storeId: storeId,
));

final page = await client.products.list(ProductListParams(size: 20));
for (final product in page.contents) {
  print(product.name);
}
```

에이전트의 쓰기가 승인 대기로 보류되면 `ApprovalPendingError`를 던집니다.

```dart
try {
  await client.products.remove(productId);
} on ApprovalPendingError catch (e) {
  print('승인이 필요합니다: ${e.approval.approvalUrl}');
} on ApiError catch (e) {
  print('${e.code}: ${e.message}');
}
```

### 웹훅 서명 검증 (서버)

시크릿을 다루는 도우미는 서버 엔트리포인트에 있습니다. 앱 코드에서 import하지 마십시오.

```dart
import 'package:sayren_store_sdk/server.dart';

final result = await verifyWebhookSignature(VerifyWebhookSignatureOptions(
  payload: rawBody, // JSON 파싱 전 본문 원문
  header: signatureHeader, // Sayren-Signature 헤더
  secret: webhookSecret,
));
if (!result.ok) {
  // 400으로 거절합니다
}
```

## Documentation

- API 레퍼런스: 공개 API마다 dartdoc을 달았습니다. `dart doc`으로 만들거나 pub.dev 게시 후 pub 문서에서 볼 수 있습니다.
- Node SDK와의 대응, 설계 규칙, 진행 현황: [ROADMAP.md](ROADMAP.md)
- 공개 API 계약: sayren 문서 사이트의 API 레퍼런스를 따릅니다.

## Development

이 저장소는 pub workspace입니다. 스키마·모델·클라이언트는 npm의 Node SDK에서 생성하고, 생성할 수 없는 함수는 `*.manual.dart`에 손으로 씁니다. 생성 파일은 직접 고치지 않습니다.

```sh
# 의존성
dart pub get

# 코드 생성 (Node SDK → Dart)
cd tool/codegen && npm install && node generate.mjs   # node generate.mjs store 처럼 대상 하나만 만들 수 있습니다

# Node SDK와 동작 대조
cd tool/parity && npm install && node compare.mjs     # --verbose면 모든 항목
node names.mjs                                        # 공개 이름 목록 대조

# 정적 분석·테스트
cd packages/storefront-sdk && flutter analyze && flutter test
cd packages/store-sdk && dart analyze && dart test
```

| 경로 | 내용 |
|---|---|
| `packages/storefront-sdk` | `sayren_storefront_sdk` |
| `packages/store-sdk` | `sayren_store_sdk` |
| `tool/codegen` | 생성기 — 대상별 설정은 `generate.mjs`의 `TARGETS`, 클로저 구현은 `hooks.mjs`, 생성 규칙 밖 메서드는 `client-overrides.mjs` |
| `tool/parity` | Node·Dart 동작 대조 하네스 |

## Contributing

1. 이슈로 바꾸려는 내용을 먼저 알려 주십시오.
2. Node SDK에 있는 이름·동작은 Node와 같게 맞춥니다. 다르게 해야 하면 [ROADMAP.md](ROADMAP.md) 「설계 규칙」에 이유를 적습니다.
3. 생성 파일 대신 생성기, `hooks.mjs`, `*.manual.dart`를 고칩니다.
4. 풀 리퀘스트 전에 `node compare.mjs`, `node names.mjs`, 두 패키지의 analyze·test가 모두 통과해야 합니다.

## License

라이선스는 아직 정하지 않았습니다. 정해지면 이 절과 `LICENSE` 파일에 적습니다.
