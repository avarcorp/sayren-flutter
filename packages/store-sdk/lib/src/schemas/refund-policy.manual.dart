// 손으로 쓴 부분 — refund-policy.ts의 정책 해석과 수량 비례 환불 기준액.
part of 'refund-policy.dart';

/// 유효 환불 정책을 해석합니다. 상점 정책 [storePolicy]와 상품별 덮어쓰기([product]의 `refundPolicy`)를 `REFUND_POLICY_DEFAULTS` 위에 합칩니다.
///
/// 기본 통화는 상점·상품의 `currencies`를 통화마다 합쳐 둡니다. [currency](이슈 #130)가 외화면 반품·교환 배송비를
/// 상품 `currencies[통화]` → 상점 `currencies[통화]` 순으로 찾고(부담 규칙 boolean은 통화와 무관합니다), 둘 다 없으면 null입니다 —
/// 그 통화로 배송 상품을 팔지 않습니다(`NO_REFUND_FEE`). 외화 결과의 `currencies`는 지우고 금액 필드가 그 통화 값입니다.
/// 기본 통화의 결과는 null이 아닙니다.
RefundPolicy? resolveRefundPolicy([
  RefundPolicyPatch? storePolicy,
  RefundPolicyProductInput? product,
  String currency = BASE_CURRENCY,
]) {
  final store = <String, Object?>{...REFUND_POLICY_DEFAULTS, if (storePolicy != null) ...jsonOf(storePolicy)};
  final override = productRefundPolicyOverride(product);
  final overrideJson = override == null ? const <String, Object?>{} : jsonOf(override);
  final merged = <String, Object?>{...store, ...overrideJson};
  final storeCurrencies = (store['currencies'] as Map?)?.cast<String, CurrencyRefundFees>();
  final overrideCurrencies = override?.currencies;
  if (currency == BASE_CURRENCY) {
    // 상품 덮어쓰기의 currencies가 상점 맵을 통째로 덮지 않게 통화마다 합친다
    if (storeCurrencies != null || overrideCurrencies != null) {
      merged['currencies'] = <String, CurrencyRefundFees>{...?storeCurrencies, ...?overrideCurrencies};
    }
    return RefundPolicy._(merged);
  }
  final fees = overrideCurrencies?[currency] ?? storeCurrencies?[currency];
  if (fees == null) return null;
  return RefundPolicy._({
    ...merged..remove('currencies'),
    'returnDeliveryFee': fees.returnDeliveryFee,
    'exchangeDeliveryFee': fees.exchangeDeliveryFee,
  });
}

/// 상품의 **덮어쓰기 자체**입니다. 덮어쓰기가 없으면 null입니다.
///
/// [resolveRefundPolicy]가 합친 결과로는 「상품이 정한 값」과 「상점 기본을 물려받은 값」을 가를 수 없습니다.
/// 쿠폰 조건 미달 차감(`couponShortfallCharge`)은 주문 단위라 상점만 정합니다 — 상품 값에 키가 있어도 덮어쓰기로 읽지 않습니다(이슈 #47).
RefundPolicyPatch? productRefundPolicyOverride([RefundPolicyProductInput? product]) {
  final policy = product?.refundPolicy;
  if (policy == null) return null;
  return RefundPolicyPatch._({...jsonOf(policy)}..remove('couponShortfallCharge'));
}

/// 수량 단위 부분 취소의 환불 기준액입니다. **누적 내림의 차분**입니다.
///
/// `floor(주문상품 금액 × 누적 수량 ÷ 전체 수량)`을 두 번 구해 그 차를 씁니다. 부분 취소를 몇 번 나눠도 합이 주문상품 금액과
/// 정확히 같아서 1원이 남거나 넘치지 않습니다. 쿠폰 할인이 있는 주문상품은 실결제 금액을 나누는 [proratedPaidRefundBase]를 쓰십시오.
///
/// - [totalPrice]: 주문상품 금액(할인 반영 단가 × 전체 수량)
/// - [quantity]: 주문상품 전체 수량
/// - [settledQuantity]: 이미 취소·반품된 누적 수량
/// - [cancelQuantity]: 이번에 취소·반품할 수량
int proratedRefundBase(int totalPrice, int quantity, int settledQuantity, int cancelQuantity) {
  if (quantity <= 0 || cancelQuantity <= 0) return 0;
  final before = _floorDivBig(totalPrice, settledQuantity, quantity);
  final after = _floorDivBig(totalPrice, settledQuantity + cancelQuantity, quantity);
  return after - before > 0 ? after - before : 0;
}

/// JS `Math.floor(a * b / c)`(c > 0) — 곱이 크면 BigInt로 계산한다
int _floorDivBig(int a, int b, int c) {
  final product = BigInt.from(a) * BigInt.from(b);
  final divisor = BigInt.from(c);
  var q = product ~/ divisor;
  if (product.remainder(divisor) != BigInt.zero && product.isNegative) q -= BigInt.one;
  return q.toInt();
}
