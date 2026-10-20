// 함수 대조 어댑터 — tool/parity/store/functions/*.json의 인자(JSON)를 Dart 인자로 바꿔 부르고 결과를 JSON 값으로 돌려준다.
// 금액 묶음: promotion·shipping-policy·refund-policy·points.
import 'package:sayren_store_sdk/sayren_store_sdk.dart';

Map<String, Object?> _m(Object? v) => (v as Map).cast<String, Object?>();

Object? _at(List<Object?> a, int i) => i < a.length ? a[i] : null;

/// `{ "$date": ISO }` → DateTime
DateTime _date(Object? v) => DateTime.parse(_m(v)[r'$date'] as String);

String? _iso(DateTime? v) => v?.toUtc().toIso8601String();

MoneyRules? _moneyRules(Object? v) {
  if (v == null) return null;
  final j = _m(v);
  return MoneyRules(
    currency: j['currency'] as String,
    saleUnit: j['saleUnit'] as int,
    minPayment: j['minPayment'] as int,
    maxOrderAmount: j['maxOrderAmount'] as int,
  );
}

PricingLine _pricingLine(Object? v) {
  final j = _m(v);
  return PricingLine(
    lineId: j['lineId'] as String,
    productId: j['productId'] as String,
    categoryPath: j['categoryPath'] as String?,
    quantity: j['quantity'] as int,
    baseAmount: j['baseAmount'] as int,
    amount: j['amount'] as int,
  );
}

PricingCoupon _pricingCoupon(Object? v) {
  final j = _m(v);
  return PricingCoupon(
    rule: CouponRule.fromJson(_m(j['rule'])),
    couponKey: j['couponKey'] as String?,
    lineId: j['lineId'] as String?,
    eligibleLineIds: (j['eligibleLineIds'] as List?)?.cast<String>(),
    validFrom: j['validFrom'] as String?,
    validUntil: j['validUntil'] as String?,
  );
}

PricingPoints? _pricingPoints(Object? v) {
  if (v == null) return null;
  final j = _m(v);
  final r = _m(j['rules']);
  return PricingPoints(
    requested: j['requested'] as int,
    balance: j['balance'] as int,
    rules: (
      minBalance: r['minBalance'] as int,
      minAmount: r['minAmount'] as int,
      unit: r['unit'] as int,
      maxRatioBp: r['maxRatioBp'] as int,
      includeDeliveryFee: r['includeDeliveryFee'] as bool,
    ),
  );
}

PricingInput _pricingInput(Object? v) {
  final j = _m(v);
  final delivery = j['delivery'];
  return PricingInput(
    lines: [for (final l in j['lines'] as List) _pricingLine(l)],
    points: _pricingPoints(j['points']),
    coupons: [for (final c in j['coupons'] as List) _pricingCoupon(c)],
    delivery: delivery == null
        ? null
        : PricingDelivery(bundles: [
            for (final b in _m(delivery)['bundles'] as List)
              (
                bundleKey: _m(b)['bundleKey'] as String,
                fee: _m(b)['fee'] as int,
                remoteSurcharge: _m(b)['remoteSurcharge'] as int,
              ),
          ]),
    firstOrder: j['firstOrder'] as bool,
    isMember: j['isMember'] as bool,
    now: _date(j['now']),
    ignoreEligibility: j['ignoreEligibility'] as bool?,
    moneyRules: _moneyRules(j['moneyRules']),
  );
}

Map<String, Object?> _allocation(CouponAllocation a) => {'couponKey': a.couponKey, 'amount': a.amount};

Map<String, Object?> _pricingResult(PricingResult r) => {
      'lines': [
        for (final l in r.lines)
          {
            'lineId': l.lineId,
            'amount': l.amount,
            'couponDiscount': l.couponDiscount,
            'allocations': [for (final a in l.allocations) _allocation(a)],
            'pointAllocation': l.pointAllocation,
          },
      ],
      'coupons': [
        for (final c in r.coupons)
          {
            'couponKey': c.couponKey,
            'couponId': c.couponId,
            'kind': c.kind,
            'applied': c.applied,
            'discount': c.discount,
            'rejectReason': c.rejectReason,
            'lineId': c.lineId,
            'eligibleLineIds': c.eligibleLineIds,
          },
      ],
      'bundles': [
        for (final b in r.bundles)
          {'bundleKey': b.bundleKey, 'couponDiscount': b.couponDiscount, 'pointAllocation': b.pointAllocation},
      ],
      'productAmount': r.productAmount,
      'couponDiscountAmount': r.couponDiscountAmount,
      'deliveryFee': r.deliveryFee,
      'deliveryDiscountAmount': r.deliveryDiscountAmount,
      'pointAmount': r.pointAmount,
      'pointMaxUsable': r.pointMaxUsable,
      'pointAdjustReason': r.pointAdjustReason,
      'pointRejectReason': r.pointRejectReason,
      'totalAmount': r.totalAmount,
    };

CouponSettlementInput _settlementInput(Object? v) {
  final j = _m(v);
  return CouponSettlementInput(
    coupons: [
      for (final c in j['coupons'] as List)
        AppliedCouponSnapshot(
          couponKey: _m(c)['couponKey'] as String,
          rule: CouponRule.fromJson(_m(_m(c)['rule'])),
          lineId: _m(c)['lineId'] as String?,
          eligibleLineIds: (_m(c)['eligibleLineIds'] as List).cast<String>(),
          discount: _m(c)['discount'] as int,
        ),
    ],
    lines: [
      for (final l in j['lines'] as List)
        CouponSettlementLine(
          lineId: _m(l)['lineId'] as String,
          productId: _m(l)['productId'] as String,
          quantity: _m(l)['quantity'] as int,
          activeQuantity: _m(l)['activeQuantity'] as int,
          totalPrice: _m(l)['totalPrice'] as int,
          allocations: [
            for (final a in _m(l)['allocations'] as List)
              CouponAllocation(couponKey: _m(a)['couponKey'] as String, amount: _m(a)['amount'] as int),
          ],
        ),
    ],
    settlements: {
      for (final e in _m(j['settlements']).entries)
        e.key:
            e.value == null ? null : (charged: _m(e.value)['charged'] as int?, waived: _m(e.value)['waived'] as int?),
    },
    shortfallCharge: j['shortfallCharge'] as bool,
    sellerFault: j['sellerFault'] as bool,
    chargeableAmount: j['chargeableAmount'] as int,
  );
}

Map<String, Object?> _settlementResult(CouponSettlementResult r) => {
      'chargeAmount': r.chargeAmount,
      'refundAmount': r.refundAmount,
      'entries': [
        for (final e in r.entries)
          {
            'couponKey': e.couponKey,
            'allocatedRemaining': e.allocatedRemaining,
            'recomputed': e.recomputed,
            'target': e.target,
            'charge': e.charge,
            'refund': e.refund,
            'waive': e.waive,
            'next': {'charged': e.next.charged, 'waived': e.next.waived},
          },
      ],
    };

DeliveryBundleProduct _bundleProduct(Object? v) {
  final j = _m(v);
  return DeliveryBundleProduct(
    deliveryType: j['deliveryType'] as String,
    deliveryFee: j['deliveryFee'] as int,
    conditionalFreeAmount: j['conditionalFreeAmount'] as int?,
    shippingAddressId: j['shippingAddressId'] as String?,
    fulfillmentType: j['fulfillmentType'] as String?,
  );
}

DeliveryQuoteInput _deliveryInput(Object? v) {
  final j = _m(v);
  final table = _m(_m(j['productOf'])[r'$lookup']);
  return DeliveryQuoteInput(
    lines: [
      for (final l in j['lines'] as List)
        DeliveryFeeLine(
          productId: _m(l)['productId'] as String,
          amount: _m(l)['amount'] as int,
          fulfillmentType: _m(l)['fulfillmentType'] as String?,
          fulfillmentMethod: _m(l)['fulfillmentMethod'] as String?,
        ),
    ],
    productOf: (id) => table.containsKey(id) ? _bundleProduct(table[id]) : null,
    policy: ShippingPolicy.fromJson(_m(j['policy'])),
    zipCode: j['zipCode'] as String?,
  );
}

Map<String, Object?> _deliveryQuote(DeliveryQuote q) => {
      'bundles': [
        for (final b in q.bundles)
          {
            'bundleKey': b.bundleKey,
            'productIds': b.productIds,
            'fee': b.fee,
            'waivedBy': b.waivedBy,
            'listFee': b.listFee,
            'freeThreshold': b.freeThreshold,
            'remoteSurcharge': b.remoteSurcharge,
          },
      ],
      'baseFee': q.baseFee,
      'remoteSurcharge': q.remoteSurcharge,
      'deliveryFee': q.deliveryFee,
      'remoteArea': q.remoteArea,
      'freeByThreshold': q.freeByThreshold,
      'shippableAmount': q.shippableAmount,
      'requiresShipping': q.requiresShipping,
    };

RefundPolicyProductInput? _refundProduct(Object? v) {
  if (v == null) return null;
  final policy = _m(v)['refundPolicy'];
  return RefundPolicyProductInput(refundPolicy: policy == null ? null : RefundPolicyPatch.fromJson(_m(policy)));
}

PointPolicy _pointPolicy(Object? v) => PointPolicy.fromJson(_m(v));

/// 함수 이름 → 어댑터
final Map<String, Object? Function(List<Object?> a)> moneyFunctions = {
  // promotion
  'couponDiscountOf': (a) => couponDiscountOf(CouponBenefit.fromJson(_m(a[0])), a[1] as int, _moneyRules(_at(a, 2))),
  'allocateByWeight': (a) => allocateByWeight(a[0] as int, (a[1] as List).cast<int>()),
  'isCouponTargetLine': (a) => isCouponTargetLine(CouponRule.fromJson(_m(a[0])), _pricingLine(a[1])),
  'quotePricing': (a) => _pricingResult(quotePricing(_pricingInput(a[0]))),
  'pointUseOf': (a) {
    final amounts = _m(a[1]);
    final r = pointUseOf(
      _pricingPoints(a[0]),
      (
        productPaid: amounts['productPaid'] as int,
        deliveryPaid: amounts['deliveryPaid'] as int,
        total: amounts['total'] as int,
      ),
      _moneyRules(_at(a, 2)),
    );
    return {
      'amount': r.amount,
      'maxUsable': r.maxUsable,
      'adjustReason': r.adjustReason,
      'rejectReason': r.rejectReason
    };
  },
  'settleCouponShortfall': (a) => _settlementResult(settleCouponShortfall(_settlementInput(a[0]))),
  'proratedPaidRefundBase': (a) {
    final item = _m(a[0]);
    return proratedPaidRefundBase(
      (
        totalPrice: item['totalPrice'] as int,
        couponDiscountAmount: item['couponDiscountAmount'] as int?,
        pointAllocation: item['pointAllocation'] as int?,
        quantity: item['quantity'] as int,
      ),
      a[1] as int,
      a[2] as int,
    );
  },
  'proratedPointRefund': (a) {
    final item = _m(a[0]);
    return proratedPointRefund(
      (pointAllocation: item['pointAllocation'] as int?, quantity: item['quantity'] as int),
      a[1] as int,
      a[2] as int,
    );
  },
  // shipping-policy
  'resolveShippingPolicy': (a) => resolveShippingPolicy(
        _at(a, 0) == null ? null : ShippingPolicyPatch.fromJson(_m(a[0])),
        (_at(a, 1) as String?) ?? BASE_CURRENCY,
      )?.toJson(),
  'remoteAreaOf': (a) => remoteAreaOf(_at(a, 0) as String?),
  'remoteAreaLabelOf': (a) => remoteAreaLabelOf(_at(a, 0) as String?),
  'remoteSurchargeOf': (a) => remoteSurchargeOf(ShippingPolicy.fromJson(_m(a[0])), a[1] as String),
  'deliveryBundleKeyOf': (a) => deliveryBundleKeyOf(_bundleProduct(a[0])),
  'quoteDelivery': (a) => _deliveryQuote(quoteDelivery(_deliveryInput(a[0]))),
  // refund-policy
  'resolveRefundPolicy': (a) => resolveRefundPolicy(
        _at(a, 0) == null ? null : RefundPolicyPatch.fromJson(_m(a[0])),
        _refundProduct(_at(a, 1)),
        (_at(a, 2) as String?) ?? BASE_CURRENCY,
      )?.toJson(),
  'productRefundPolicyOverride': (a) => productRefundPolicyOverride(_refundProduct(_at(a, 0)))?.toJson(),
  'proratedRefundBase': (a) => proratedRefundBase(a[0] as int, a[1] as int, a[2] as int, a[3] as int),
  // points
  'resolvePointPolicy': (a) => resolvePointPolicy(_at(a, 0)).toJson(),
  'pointEarningEnabled': (a) => pointEarningEnabled(_pointPolicy(a[0])),
  'purchaseEarnRateOf': (a) => purchaseEarnRateOf(_pointPolicy(a[0]), _at(a, 1) as int?),
  'pointEarnOf': (a) => pointEarnOf(paidBase: _m(a[0])['paidBase'] as int, rateBp: _m(a[0])['rateBp'] as int),
  'reviewRewardPointOf': (a) => reviewRewardPointOf(_pointPolicy(a[0]), a[1] as bool),
  'pointExpiresAtOf': (a) => _iso(pointExpiresAtOf(_date(a[0]), _at(a, 1) as int?)),
  'pointRestoreExpiresAtOf': (a) => _iso(pointRestoreExpiresAtOf(
        [
          for (final u in a[0] as List)
            PointLotUsage(
              lotId: _m(u)['lotId'] as String,
              amount: _m(u)['amount'] as int,
              expiresAt: _m(u)['expiresAt'] as String?,
            ),
        ],
        _date(a[1]),
      )),
  'splitRefund': (a) {
    final j = _m(a[0]);
    final r = splitRefund(cash: j['cash'] as int, points: j['points'] as int, charges: j['charges'] as int);
    return {'cashRefund': r.cashRefund, 'pointRefund': r.pointRefund, 'uncollected': r.uncollected};
  },
};
