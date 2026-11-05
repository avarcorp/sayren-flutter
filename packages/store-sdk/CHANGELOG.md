## 0.2.0

- `@sayren/store-sdk` 0.71.0과 같은 API로 최신화했습니다. 엔드포인트는 360개입니다.
- 관리 API 요청 스키마가 Node(`strictRequest`)처럼 안쪽 객체까지 모르는 키를 `ZodError`(`unrecognized_keys`)로 거절합니다.
- `baseUrl`을 생략하면 운영 주소(`SAYREN_API_BASE_URL`)를 사용합니다(클라이언트·세션). `delegateMember`의 `baseUrl` 기본값은 `SAYREN_API_ORIGIN`이고 `userinfo`를 받습니다.
- 조건 트리(`ConditionGroup`·`evaluateCondition` 등)와 쿠폰 규칙·자동 선택(`couponRuleIssues`·`bestCouponSelection` 등) 함수를 더했습니다.
- 파괴적 변경(Node에서 없어진 것): `subscription.get`·`plans.listPublic`, `storefront.listTemplates`·`getStoreTemplate`·`updateStoreTemplate`·`uploadSourceBlobs`, `isShowcaseStorefrontSlug`를 지웠습니다.
- 새 네임스페이스·메서드: `checkouts`, `noticeTemplates`, `products.imports`, `inventory.lowStock`, `commerceFlows.localizations`와 흐름 편집(`applyOperations` 등), 쿠폰 배포(`coupons.distribute` 등), `customers.export`·`update`·`unlock`·`sendPasswordReset`, `orders.create`·`refund`, `orderItems.listShipping`, 스토어프론트 Git 연결·환경 변수 등 58개.
- 파괴적 변경: 주문 응답의 `payment` 필드 클래스 이름이 `OrderPayment`에서 `OrderPaymentField`로 바뀌었습니다(`OrderPayment`는 이제 주문의 결제 한 건 export입니다). `claims.approve`의 옵션 레코드에 `refundAmount`가 더해졌습니다.

## 0.1.0

- 첫 공개 버전입니다. `@sayren/store-sdk` 0.36.0과 같은 API를 제공합니다.
- 관리 API 클라이언트(`createStoreClient`), 세션·OAuth(`createStoreSession`), 스키마·모델과 금액·정책 계산 함수
- 서버 엔트리포인트(`server.dart`): 웹훅 서명 생성·검증, 구매자 위임
