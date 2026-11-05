// 손으로 쓴 부분 — fulfillment.ts의 zod 클로저 구현.
part of 'fulfillment.dart';

const _knownTypes = ['SHIPPING', 'MANUAL'];

/// 모르는 이행 유형 transform — SDK가 모르는 유형을 `OTHER`로 읽는다
Object? _unknownFulfillmentView(Object? value) {
  final j = value as Map<String, Object?>;
  return UnknownFulfillmentView(
    type: 'OTHER',
    rawType: j['type'] as String,
    requiresShipping: j['requiresShipping'] as bool,
  );
}

/// 상품 상세의 배송 안내입니다. [kind]로 나눕니다(`FREE`·`PAID`·`CONDITIONAL_FREE`·`NO_SHIPPING`·`UNKNOWN`).
sealed class DeliveryNotice {
  const DeliveryNotice();

  /// 안내 구분입니다.
  String get kind;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson();
}

/// 무료 배송입니다.
final class DeliveryNoticeFree extends DeliveryNotice {
  /// 안내를 만듭니다.
  const DeliveryNoticeFree({required this.estimatedDays});

  @override
  String get kind => 'FREE';

  /// 배송 예정 안내입니다. 셀러가 적지 않았으면 null입니다.
  final String? estimatedDays;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'estimatedDays': estimatedDays};
}

/// 유료 배송입니다.
final class DeliveryNoticePaid extends DeliveryNotice {
  /// 안내를 만듭니다.
  const DeliveryNoticePaid({required this.fee, required this.estimatedDays});

  @override
  String get kind => 'PAID';

  /// 배송비입니다.
  final int fee;

  /// 배송 예정 안내입니다. 셀러가 적지 않았으면 null입니다.
  final String? estimatedDays;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'fee': fee, 'estimatedDays': estimatedDays};
}

/// 조건부 무료 배송입니다. [freeOver] 이상 사면 무료입니다.
final class DeliveryNoticeConditionalFree extends DeliveryNotice {
  /// 안내를 만듭니다.
  const DeliveryNoticeConditionalFree({required this.fee, required this.freeOver, required this.estimatedDays});

  @override
  String get kind => 'CONDITIONAL_FREE';

  /// 배송비입니다.
  final int fee;

  /// 무료 배송 기준 금액입니다.
  final int freeOver;

  /// 배송 예정 안내입니다. 셀러가 적지 않았으면 null입니다.
  final String? estimatedDays;

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'fee': fee, 'freeOver': freeOver, 'estimatedDays': estimatedDays};
}

/// 배송이 없습니다(판매자가 직접 제공하는 상품 등).
final class DeliveryNoticeNoShipping extends DeliveryNotice {
  /// 안내를 만듭니다.
  const DeliveryNoticeNoShipping();

  @override
  String get kind => 'NO_SHIPPING';

  @override
  Map<String, Object?> toJson() => {'kind': kind};
}

/// 배송은 있는데 SDK가 모르는 유형이라 배송비를 모릅니다.
final class DeliveryNoticeUnknown extends DeliveryNotice {
  /// 안내를 만듭니다.
  const DeliveryNoticeUnknown();

  @override
  String get kind => 'UNKNOWN';

  @override
  Map<String, Object?> toJson() => {'kind': kind};
}

/// 상품 상세 `fulfillment`에서 배송 안내를 만듭니다.
///
/// 배송비 0원은 유형과 상관없이 무료입니다. 조건부 무료인데 기준 금액이 없으면 유료입니다.
/// 모르는 배송비 유형은 기본 배송비를 유료로 보입니다(기본 배송비는 늘 그 상품의 실제 기본값입니다).
DeliveryNotice deliveryNoticeOf(ProductFulfillmentView fulfillment) {
  switch (fulfillment) {
    case UnknownFulfillmentView():
      return fulfillment.requiresShipping ? const DeliveryNoticeUnknown() : const DeliveryNoticeNoShipping();
    case ProductFulfillmentViewManual():
      return const DeliveryNoticeNoShipping();
    case ProductFulfillmentViewShipping(:final shipping):
      final trimmed = shipping.estimatedDays.trim();
      final estimatedDays = trimmed.isEmpty ? null : trimmed;
      if (shipping.deliveryType == 'FREE' || shipping.deliveryFee == 0) {
        return DeliveryNoticeFree(estimatedDays: estimatedDays);
      }
      final freeOver = shipping.conditionalFreeAmount;
      if (shipping.deliveryType == 'CONDITIONAL_FREE' && freeOver != null) {
        return DeliveryNoticeConditionalFree(
            fee: shipping.deliveryFee, freeOver: freeOver, estimatedDays: estimatedDays);
      }
      return DeliveryNoticePaid(fee: shipping.deliveryFee, estimatedDays: estimatedDays);
  }
}
