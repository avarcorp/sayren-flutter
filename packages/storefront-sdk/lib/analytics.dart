/// 방문 분석입니다. `@sayren/storefront-sdk/analytics`와 같은 이름·사용법입니다.
///
/// 페이지뷰·상품 조회·목록 노출·검색·체류를 모아 배치로 보냅니다. 장바구니·결제·구매는 스토어프론트 API가 서버에서 기록하므로
/// 여기서 보내지 않습니다. [Analytics.ids]를 클라이언트의 `visitorId`·`sessionId`에 넘기면 이어집니다.
///
/// ```dart
/// import 'package:sayren_storefront_sdk/analytics.dart';
///
/// final analytics = createAnalytics(AnalyticsOptions(baseUrl: baseUrl, storeCode: storeCode));
/// analytics.setConsent('granted');
/// ```
library;

export 'src/analytics/flutter.dart';
export 'src/analytics/index.dart';
