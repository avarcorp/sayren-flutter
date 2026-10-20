/// 결제입니다. `@sayren/storefront-sdk/payments`와 같은 이름·사용법입니다.
///
/// 결제는 [Payments.start] 한 번의 `await`로 끝납니다. 결제창(WebView) 표시, PG 복귀 처리, 승인, 결과 확정은 SDK가 합니다.
///
/// ```dart
/// import 'package:sayren_storefront_sdk/payments.dart';
///
/// final payments = createPayments(PaymentsOptions(client: client, returnUrl: 'https://shop.example.com/payments/return'));
/// final result = await payments.start(checkoutId, StartOptions(option: option, shippingAddress: address));
/// ```
library;

export 'src/payments/flutter.dart';
export 'src/payments/index.dart';
export 'src/payments/launch.dart' show LaunchFailure;
