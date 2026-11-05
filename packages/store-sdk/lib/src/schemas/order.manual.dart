// 손으로 쓴 부분 — order.ts의 TS 전용 타입.
part of 'order.dart';

/// `orderItems.listShipping`의 파라미터입니다.
///
/// [orderedFrom]과 [orderItemNos] 가운데 하나는 반드시 주십시오(Node 타입이 둘 중 하나를 요구합니다).
class ShippingOrderItemListParams extends PageParams {
  /// [ShippingOrderItemListParams]을 만듭니다.
  const ShippingOrderItemListParams({
    super.page,
    super.size,
    this.orderedFrom,
    this.orderedTo,
    this.status,
    this.keyword,
    this.testPayment,
    this.orderItemNos,
  });

  /// 주문 시각 시작입니다. [orderItemNos]가 없으면 필요합니다.
  final String? orderedFrom;

  /// 주문 시각 끝입니다.
  final String? orderedTo;

  /// 주문상품 상태 하나([OrderItemStatus]) 또는 여러 상태(`List<String>`)입니다.
  final Object? status;

  /// 검색어입니다.
  final String? keyword;

  /// 테스트 결제 필터입니다. `"true"`면 테스트 결제 주문만, `"false"`면 실결제만, 생략하면 전부입니다.
  final String? testPayment;

  /// 주문상품 번호 목록입니다. [orderedFrom]이 없으면 필요합니다.
  final List<String>? orderItemNos;

  /// 쿼리 파라미터로 바꿉니다. null인 값은 뺍니다.
  @override
  Map<String, Object?> toJson() => {
        ...super.toJson(),
        if (orderedFrom != null) 'orderedFrom': orderedFrom,
        if (orderedTo != null) 'orderedTo': orderedTo,
        if (status != null) 'status': status,
        if (keyword != null) 'keyword': keyword,
        if (testPayment != null) 'testPayment': testPayment,
        if (orderItemNos != null) 'orderItemNos': orderItemNos,
      };
}
