# sayren_store_sdk

sayren 관리 API를 Dart에서 호출하는 SDK입니다. Node SDK `@sayren/store-sdk`와 이름·사용법이 같습니다.

셀러 도구·서버에서 상품, 주문, 클레임, 설정을 관리하고 웹훅 서명을 검증합니다. Flutter 없이 Dart만으로 동작합니다.

## Features

- Node SDK와 같은 팩토리·옵션·네임스페이스·메서드·모델 이름
- 요청 전·응답 후 Node SDK와 같은 규칙으로 검증(`ZodError`), 서버 오류는 `ApiError`, 승인 대기는 `ApprovalPendingError`
- 세션·OAuth(PKCE): 토큰 저장, 401 시 갱신 후 재시도, 로그아웃 시 토큰 폐기
- 금액·정책 계산 함수(`quotePricing`, `quoteDelivery` 등)를 Node와 같은 결과로 제공
- 엔트리포인트: `sayren_store_sdk.dart`(클라이언트·세션·스키마), `server.dart`(웹훅 서명, 구매자 위임 — 서버 전용)

## Requirements

- Dart 3.6 이상

## Installation

```sh
dart pub add sayren_store_sdk
```

## Getting Started

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

- 공개 API마다 dartdoc이 있습니다. 이 페이지의 API reference를 참고하십시오.
- Node SDK와의 대응과 설계 규칙: [ROADMAP.md](https://github.com/avarcorp/sayren-flutter/blob/HEAD/ROADMAP.md)
- 저장소·이슈: [avarcorp/sayren-flutter](https://github.com/avarcorp/sayren-flutter)

## License

Apache License 2.0. [LICENSE](LICENSE)를 참고하십시오.
