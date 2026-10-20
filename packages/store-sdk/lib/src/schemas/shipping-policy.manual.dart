// 손으로 쓴 부분 — shipping-policy.ts의 정책 해석·지역 추가 배송비·배송 묶음·배송비 계산(quoteDelivery).
part of 'shipping-policy.dart';

/// 유효 배송비 정책을 해석합니다. 상점이 정한 항목 [patch]에 `SHIPPING_POLICY_DEFAULTS`를 채웁니다.
///
/// [currency](이슈 #130)를 주면 그 통화의 정책입니다. 기본 통화는 위와 같고, 외화는 `currencies[통화]`의 기본 배송비·무료 기준액에
/// 지역 추가 배송비 0입니다(할증 구간은 국내 값). 외화 값이 없으면 null입니다 — 그 통화로 배송 상품을 팔지 않습니다.
/// 기본 통화의 결과는 null이 아닙니다.
ShippingPolicy? resolveShippingPolicy([ShippingPolicyPatch? patch, String currency = BASE_CURRENCY]) {
  final base = ShippingPolicy._({...SHIPPING_POLICY_DEFAULTS, if (patch != null) ...jsonOf(patch)});
  if (currency == BASE_CURRENCY) return base;
  final foreign = base.currencies?[currency];
  if (foreign == null) return null;
  return ShippingPolicy(
    baseDeliveryFee: foreign.baseDeliveryFee,
    freeThreshold: foreign.freeThreshold,
    jejuSurcharge: 0,
    isolatedSurcharge: 0,
  );
}

final _zipPattern = RegExp(r'^[0-9]{5}$');

/// 우편번호에 맞는 범위(`REMOTE_AREA_ZIP_RANGES`의 항목). 5자리 숫자가 아니거나 맞는 범위가 없으면 null
Map<String, Object?>? _remoteRangeOf(String? zipCode) {
  if (zipCode == null || zipCode.isEmpty || !_zipPattern.hasMatch(zipCode)) return null;
  final zip = int.parse(zipCode);
  for (final range in REMOTE_AREA_ZIP_RANGES) {
    if (zip >= (range['from'] as int) && zip <= (range['to'] as int)) return range;
  }
  return null;
}

/// 우편번호를 지역 구분으로 바꿉니다. 5자리 숫자가 아니면 `NONE`입니다.
///
/// 형식 검증은 배송지 스키마가 하고, 여기서는 **판정하지 못하면 추가 배송비를 받지 않습니다**.
RemoteArea remoteAreaOf(String? zipCode) => _remoteRangeOf(zipCode)?['area'] as String? ?? 'NONE';

/// 지역 구분의 안내 이름입니다. 판정된 범위의 `label`이고, 판정되지 않으면 null입니다.
String? remoteAreaLabelOf(String? zipCode) => _remoteRangeOf(zipCode)?['label'] as String?;

/// 묶음 하나에 붙는 지역 추가 배송비입니다.
int remoteSurchargeOf(ShippingPolicy policy, RemoteArea area) {
  if (area == 'JEJU') return policy.jejuSurcharge;
  if (area == 'ISOLATED') return policy.isolatedSurcharge;
  return 0;
}

/// 배송 묶음 키입니다. **같은 출고지 + 같은 배송 정책이면 같은 키입니다.**
///
/// 키는 주문 시점에 주문상품 행에 스냅샷됩니다. `-`는 「값 없음」입니다.
String deliveryBundleKeyOf(DeliveryBundleProduct product) {
  final origin = product.shippingAddressId ?? '-';
  final threshold = product.deliveryType == 'CONDITIONAL_FREE' ? '${product.conditionalFreeAmount ?? 0}' : '-';
  final fee = product.deliveryType == 'FREE' ? 0 : product.deliveryFee;
  return 'b:$origin:${product.deliveryType}:$fee:$threshold';
}

class _DeliveryGroup {
  _DeliveryGroup(this.product);

  final DeliveryBundleProduct product;
  final ids = <String>{};
  var sum = 0;
}

/// 배송비를 계산합니다. **순수 함수입니다.** 장바구니 요약, 주문서 금액, 결제 시작의 최종 확정, 주문 배송비 스냅샷이 모두 이 한 곳을 씁니다.
///
/// 묶음별 조건부 무료를 먼저 보고, 그다음 상점 전체 무료 기준으로 기본 배송비를 한꺼번에 0으로 만들고,
/// 마지막에 지역 추가 배송비를 묶음마다 더합니다. 추가 배송비는 무료 기준에 걸리지 않습니다.
/// 비실물 줄은 묶음도 무료 기준 판정 금액도 만들지 않습니다.
///
/// ```dart
/// final quote = quoteDelivery(DeliveryQuoteInput(
///   lines: [DeliveryFeeLine(productId: 'prd_1', amount: 18000)],
///   productOf: (id) => products[id],
///   policy: resolveShippingPolicy(store.shippingPolicy)!,
///   zipCode: '63000',
/// ));
/// ```
DeliveryQuote quoteDelivery(DeliveryQuoteInput input) {
  final policy = input.policy;
  final area = remoteAreaOf(input.zipCode);
  final surcharge = remoteSurchargeOf(policy, area);

  // 묶음별 소계와 구성 상품
  final groups = <String, _DeliveryGroup>{};
  var shippableAmount = 0;
  for (final line in input.lines) {
    final product = input.productOf(line.productId);
    if (product == null) continue;
    // 비실물은 묶음도 무료 기준 판정 금액도 만들지 않는다 — 디지털 금액이 실물 배송비를 면제시키지 않게 한다
    if (!requiresShipping(line.fulfillmentType ?? product.fulfillmentType, line.fulfillmentMethod)) continue;
    shippableAmount += line.amount;
    final group = groups.putIfAbsent(deliveryBundleKeyOf(product), () => _DeliveryGroup(product));
    group.ids.add(line.productId);
    group.sum += line.amount;
  }

  final threshold = policy.freeThreshold;
  final freeByThreshold = threshold != null && shippableAmount >= threshold && groups.isNotEmpty;

  final bundles = <DeliveryBundleQuote>[];
  for (final MapEntry(key: bundleKey, value: group) in groups.entries) {
    final product = group.product;
    final conditionalFree = product.deliveryType == 'CONDITIONAL_FREE' && product.conditionalFreeAmount != null;
    final freeThreshold = conditionalFree ? (product.conditionalFreeAmount ?? 0) : null;
    final listFee = product.deliveryType == 'FREE' ? 0 : product.deliveryFee;
    // 면제 근거는 센 것부터 본다 — 무료배송 상품 > 상점 전체 무료 기준 > 상품별 조건부 무료.
    // 환불 정산의 미달 차감은 CONDITIONAL만 대상이므로 근거를 뭉개면 안 된다
    final DeliveryFeeWaiver? waivedBy = product.deliveryType == 'FREE'
        ? 'FREE'
        : freeByThreshold
            ? 'STORE_THRESHOLD'
            : freeThreshold != null && group.sum >= freeThreshold
                ? 'CONDITIONAL'
                : null;
    bundles.add(DeliveryBundleQuote(
      bundleKey: bundleKey,
      productIds: [...group.ids],
      fee: waivedBy == null ? listFee : 0,
      waivedBy: waivedBy,
      listFee: listFee,
      freeThreshold: freeThreshold,
      remoteSurcharge: surcharge,
    ));
  }

  final baseFee = bundles.fold<int>(0, (sum, b) => sum + b.fee);
  final remoteSurcharge = bundles.fold<int>(0, (sum, b) => sum + b.remoteSurcharge);
  return DeliveryQuote(
    bundles: bundles,
    baseFee: baseFee,
    remoteSurcharge: remoteSurcharge,
    deliveryFee: baseFee + remoteSurcharge,
    remoteArea: area,
    freeByThreshold: freeByThreshold,
    shippableAmount: shippableAmount,
    requiresShipping: bundles.isNotEmpty,
  );
}
