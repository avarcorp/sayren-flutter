// 손으로 쓴 부분 — fulfillment.ts의 함수·zod 클로저 구현.
part of 'fulfillment.dart';

/// SDK가 아는 이행 유형 — 응답의 열린 유니온이 모르는 유형만 `OTHER`로 읽는다
const _knownFulfillmentTypes = ['SHIPPING', 'MANUAL'];

/// 저장된 값을 유형으로 바꿉니다. null·모르는 값은 `SHIPPING`입니다.
///
/// 이 필드 이전의 상품·주문상품은 모두 배송 상품이었습니다.
FulfillmentType fulfillmentTypeOf(String? value) {
  final parsed = fulfillmentTypeSchema.safeParse(value);
  return parsed.success ? parsed.data! : 'SHIPPING';
}

/// 유형의 규칙([FULFILLMENT_RULES])을 돌려줍니다. 모르는 값은 배송 상품 규칙입니다.
FulfillmentRule fulfillmentRuleOf(String? type) {
  final rule = FULFILLMENT_RULES[fulfillmentTypeOf(type)]!;
  return FulfillmentRule(
    requiresShipping: rule['requiresShipping']!,
    requiresCollection: rule['requiresCollection']!,
    exchangeSupported: rule['exchangeSupported']!,
  );
}

/// 유형의 기본 이행 방식을 돌려줍니다. 허용 방식을 두지 않은 상품·이 필드 이전 주문상품에 씁니다.
FulfillmentMethod defaultFulfillmentMethodOf(String? type) => FULFILLMENT_METHODS_BY_TYPE[fulfillmentTypeOf(type)]![0];

/// 상품의 허용 이행 방식을 돌려줍니다. 두지 않았으면 유형 기본 하나입니다. 모르는 방식은 뺍니다.
List<FulfillmentMethod> fulfillmentMethodsOf({required String type, List<String>? methods}) {
  final known = (methods ?? const <String>[]).where(FULFILLMENT_METHODS.contains).toList();
  return known.isNotEmpty ? known : [defaultFulfillmentMethodOf(type)];
}

/// 저장된 방식을 방식으로 바꿉니다. null·모르는 값은 [type]의 기본 방식입니다.
FulfillmentMethod fulfillmentMethodOf(String? type, String? method) {
  final parsed = fulfillmentMethodSchema.safeParse(method);
  return parsed.success ? parsed.data! : defaultFulfillmentMethodOf(type);
}

/// 택배 배송이 필요한지 판정합니다. 배송비 묶음·배송지·발송 흐름의 판정은 이 함수 하나를 지납니다.
///
/// [method]를 주면 방식 규칙도 봅니다(배송 상품의 방문 수령은 배송이 없습니다). 방식을 모르면 유형 규칙만 봅니다.
bool requiresShipping(String? type, [String? method]) {
  if (!fulfillmentRuleOf(type).requiresShipping) return false;
  return method == null || FULFILLMENT_METHOD_RULES[fulfillmentMethodOf(type, method)]!['requiresAddress']!;
}

/// 반품에 수거가 필요한지 판정합니다. 비실물 반품은 수거 등록·수거 완료 없이 승인합니다.
bool requiresCollection(String? type) => fulfillmentRuleOf(type).requiresCollection;

/// 유형 이름 → 그 유형의 저장된 이행입니다.
///
/// Node는 `Extract<ProductFulfillment, { type: T }>`로 형태 하나를 고릅니다. Dart에는 타입 수준 선택이 없어
/// [ProductFulfillment] 전체이고, 형태는 [ProductFulfillmentShipping]·[ProductFulfillmentManual]로 좁힙니다.
typedef ProductFulfillmentOf<T extends FulfillmentType> = ProductFulfillment;

/// 열린 응답 유니온을 만듭니다. 알려진 유형은 [known]으로 검사하고, 모르는 유형만 [UnknownFulfillment](`type: OTHER`)로 읽습니다.
///
/// 알려진 유형의 모양이 틀린 응답은 폴백으로 숨기지 않고 파싱 오류로 둡니다.
ZodType<Object?> openFulfillmentUnion<T>(ZodType<T> known) => z.union<Object?>([
      known,
      z.pipe<UnknownFulfillment>(
          z.plainObject({
            'type': z.string().refine((v) => !_knownFulfillmentTypes.contains(v), message: '알려진 유형은 해당 유형의 모양이어야 합니다'),
          }, loose: true),
          z.transform<UnknownFulfillment>(_unknownFulfillment)),
    ]);

/// 모르는 이행 유형 transform — SDK가 모르는 유형을 `OTHER`로 읽는다
Object? _unknownFulfillment(Object? value) =>
    UnknownFulfillment(type: 'OTHER', rawType: (value as Map<String, Object?>)['type'] as String);

/// 배송비 필드 사이의 일관성 superRefine(Node `refineShippingConsistency`)
void _shippingConsistency(ParsedObject value, ZodCheckContext ctx) {
  final j = jsonOf(value);
  final deliveryType = j['deliveryType'];
  final deliveryFee = j['deliveryFee'];
  if (deliveryType == 'FREE' && deliveryFee != null && deliveryFee != absent && deliveryFee != 0) {
    ctx.addIssue('무료 배송(FREE)의 배송비는 0이거나 생략해야 합니다', path: ['deliveryFee']);
  }
  final threshold = j['conditionalFreeAmount'];
  final hasThreshold = threshold != null && threshold != absent;
  if (deliveryType == 'CONDITIONAL_FREE' && !hasThreshold) {
    ctx.addIssue('조건부 무료(CONDITIONAL_FREE)는 무료 기준 금액이 필요합니다', path: ['conditionalFreeAmount']);
  }
  if (deliveryType != 'CONDITIONAL_FREE' && hasThreshold) {
    ctx.addIssue('무료 기준 금액은 조건부 무료(CONDITIONAL_FREE)에서만 받습니다', path: ['conditionalFreeAmount']);
  }
}
