// 함수 대조 어댑터 — 조건 트리·쿠폰 규칙·최대 할인 조합·쿠폰 요청 검증(condition-tree·coupon-rules·coupon-selection·coupon).
import 'dart:convert';
import 'package:sayren_store_sdk/sayren_store_sdk.dart';

import 'money.dart';

Map<String, Object?> _m(Object? v) => (v as Map).cast<String, Object?>();

Object? _at(List<Object?> a, int i) => i < a.length ? a[i] : null;

/// 모델·인터페이스 클래스를 JSON 값으로 — toJson을 따라 내려간다
Object? _json(Object? v) => jsonDecode(jsonEncode(v));

/// 조건 노드 — 검증하지 않고 만든다(TS 함수도 형식을 다시 보지 않는다. 깊이 초과 등 검증 대상 입력을 그대로 넘긴다)
ConditionNode _node(Object? v) {
  final j = _m(v);
  return j.containsKey('combinator') ? _group(j) : _rule(j);
}

ConditionGroup _group(Object? v) {
  final j = _m(v);
  return ConditionGroup(combinator: j['combinator'] as String, rules: [for (final n in j['rules'] as List) _node(n)]);
}

ConditionGroup? _groupOrNull(Object? v) => v == null ? null : _group(v);

ConditionRule _rule(Object? v) {
  final j = _m(v);
  return ConditionRule(field: j['field'] as String, operator: j['operator'] as String, value: j['value']);
}

CouponTargetRules _targetRules(Object? v) {
  final j = _m(v);
  return CouponTargetRules(
    include: [for (final r in j['include'] as List) _rule(r)],
    exclude: [for (final r in j['exclude'] as List) _rule(r)],
  );
}

CouponTargetTree _targetTree(Object? v) {
  final j = _m(v);
  return CouponTargetTree(include: _group(j['include']), exclude: _group(j['exclude']));
}

CouponRuleTrees _ruleTrees(Object? v) {
  final j = _m(v);
  return CouponRuleTrees(
    eligibility: _group(j['eligibility']),
    targetRules: _targetRules(j['targetRules']),
    targetTree: j['targetTree'] == null ? null : _targetTree(j['targetTree']),
  );
}

BirthdateFact? _birthdate(Object? v) {
  if (v == null) return null;
  final j = _m(v);
  return BirthdateFact(age: j['age'] as int?, month: j['month'] as int, isCurrentMonth: j['isCurrentMonth'] as bool);
}

/// 구매자·시각 사실 값(`CouponFacts`) — money.dart의 쿠폰·주문 입력도 쓴다
CouponFacts? couponFactsOfJson(Object? v) {
  if (v == null) return null;
  final j = _m(v);
  final customer = j['customer'] == null ? null : _m(j['customer']);
  final claims = customer?['claims'] == null ? null : _m(customer!['claims']);
  final time = j['time'] == null ? null : _m(j['time']);
  return CouponFacts(
    customer: customer == null
        ? null
        : CouponCustomerFacts(
            daysSinceJoined: customer['daysSinceJoined'] as int?,
            marketingAgreed: customer['marketingAgreed'] as bool?,
            paidOrderCount: customer['paidOrderCount'] as int?,
            daysSinceLastOrder: customer['daysSinceLastOrder'] as int?,
            claims: claims == null
                ? null
                : CouponClaimFacts(
                    gender: claims['gender'] as String?,
                    birthdate: _birthdate(claims['birthdate']),
                    email_verified: claims['email_verified'] as bool?,
                    phone_number_verified: claims['phone_number_verified'] as bool?,
                    locale: (claims['locale'] as List?)?.cast<String>(),
                    addressCountry: claims['addressCountry'] as String?,
                  ),
          ),
    time: time == null
        ? null
        : CouponTimeFacts(weekday: time['weekday'] as String, timeOfDay: time['timeOfDay'] as String),
  );
}

CouponLineContext _lineContext(Object? v) {
  final j = _m(v);
  return CouponLineContext(
    productId: j['productId'] as String,
    categoryIds: (j['categoryIds'] as List).cast<String>(),
    hasInstantDiscount: j['hasInstantDiscount'] as bool,
    unitPrice: j['unitPrice'] as int,
  );
}

CouponOrderContext _orderContext(Object? v) {
  final j = _m(v);
  final cart = j['cart'] == null ? null : _m(j['cart']);
  return CouponOrderContext(
    facts: couponFactsOfJson(j['facts']) ?? const CouponFacts(),
    cart: cart == null
        ? null
        : CouponCartFacts(
            subtotal: cart['subtotal'] as int,
            targetSubtotal: cart['targetSubtotal'] as int,
            targetQuantity: cart['targetQuantity'] as int,
          ),
  );
}

/// `{ "$lookup": { 금액: 문구 } }` → formatMoney. JS처럼 숫자 키를 문자열로 찾는다
String Function(num minor)? _formatMoney(Object? v) {
  if (v == null) return null;
  final table = _m(_m(v)[r'$lookup']);
  String key(num n) => n is double && n == n.truncateToDouble() ? '${n.toInt()}' : '$n';
  return (n) => table[key(n)] as String;
}

/// Node `{ ...coupon, lineId }` — 최대 조합 결과의 쿠폰은 늘 `lineId` 키가 있다
Map<String, Object?> _selectedCoupon(PricingCoupon c) => {
      'rule': c.rule.toJson(),
      if (c.couponKey != null) 'couponKey': c.couponKey,
      'lineId': c.lineId,
      if (c.eligibleLineIds != null) 'eligibleLineIds': c.eligibleLineIds,
      if (c.validFrom != null) 'validFrom': c.validFrom,
      if (c.validUntil != null) 'validUntil': c.validUntil,
      if (c.facts != null) 'facts': _json(c.facts),
    };

CouponSelectionInput _selectionInput(Object? v) {
  final j = _m(v);
  final delivery = j['delivery'];
  return CouponSelectionInput(
    lines: [for (final l in j['lines'] as List) pricingLineOfJson(l)],
    delivery: delivery == null
        ? null
        : PricingDelivery(
            bundles: [
              for (final b in _m(delivery)['bundles'] as List)
                (
                  bundleKey: _m(b)['bundleKey'] as String,
                  fee: _m(b)['fee'] as int,
                  remoteSurcharge: _m(b)['remoteSurcharge'] as int,
                ),
            ],
          ),
    firstOrder: j['firstOrder'] as bool?,
    isMember: j['isMember'] as bool,
    now: dateOfJson(j['now']),
    facts: couponFactsOfJson(j['facts']),
    ignoreEligibility: j['ignoreEligibility'] as bool?,
    moneyRules: moneyRulesOfJson(j['moneyRules']),
    candidates: [for (final c in j['candidates'] as List) pricingCouponOfJson(c)],
  );
}

/// 함수 이름 → 어댑터
final Map<String, Object? Function(List<Object?> a)> couponFunctions = {
  // condition-tree
  'isConditionGroup': (a) => isConditionGroup(_node(a[0])),
  'birthdateFactOf': (a) {
    final today = _m(a[1]);
    return birthdateFactOf(
      a[0] as String?,
      (year: today['year'] as int, month: today['month'] as int, day: today['day'] as int),
    )?.toJson();
  },
  'canonicalizeConditionRule': (a) => canonicalizeConditionRule(_rule(a[0])).toJson(),
  'canonicalizeConditionGroup': (a) => canonicalizeConditionGroup(_group(a[0])).toJson(),
  'conditionFields': (a) => conditionFields(_group(a[0])).toList(),
  // coupon-rules
  'canonicalLocale': (a) => canonicalLocale(a[0] as String?),
  'couponClaimFactsOf': (a) {
    final c = _m(a[0]);
    return _json(couponClaimFactsOf(
      (
        gender: c['gender'] as String?,
        birthdate: c['birthdate'] as String?,
        email_verified: c['email_verified'] as bool?,
        phone_number_verified: c['phone_number_verified'] as bool?,
        locale: c['locale'] as String?,
        addressCountry: c['addressCountry'] as String?,
      ),
      dateOfJson(a[1]),
    ));
  },
  'couponTodayAt': (a) {
    final d = couponTodayAt(dateOfJson(a[0]));
    return {'year': d.year, 'month': d.month, 'day': d.day};
  },
  'couponTimeFactsAt': (a) => couponTimeFactsAt(dateOfJson(a[0])).toJson(),
  'daysBetween': (a) => daysBetween(a[0] is Map ? dateOfJson(a[0]) : a[0], dateOfJson(a[1])),
  'couponLineContextOf': (a) {
    final l = _m(a[0]);
    return couponLineContextOf(
      productId: l['productId'] as String,
      categoryPath: l['categoryPath'] as String?,
      quantity: l['quantity'] as int,
      baseAmount: l['baseAmount'] as int,
      amount: l['amount'] as int,
    ).toJson();
  },
  'canonicalizeCouponTargetRules': (a) => canonicalizeCouponTargetRules(_targetRules(a[0])).toJson(),
  'canonicalizeCouponTargetTree': (a) => canonicalizeCouponTargetTree(_targetTree(a[0])).toJson(),
  'couponTargetTreeFromRules': (a) => couponTargetTreeFromRules(_targetRules(a[0])).toJson(),
  'couponTargetRulesFromTree': (a) {
    final r = couponTargetRulesFromTree(_targetTree(a[0]));
    return {'targetRules': r.targetRules.toJson(), 'rulesOnly': r.rulesOnly};
  },
  'canonicalizeCouponStacking': (a) => canonicalizeCouponStacking(CouponStacking.fromJson(_m(a[0]))).toJson(),
  'couponTargetTreeOf': (a) => couponTargetTreeOf(_ruleTrees(a[0])).toJson(),
  'couponRulesFromLegacy': (a) {
    final c = _m(a[0]);
    final t = _m(a[1]);
    return _json(couponRulesFromLegacy(
      LegacyCouponConditions(
        minOrderAmount: c['minOrderAmount'] as int,
        firstOrderOnly: c['firstOrderOnly'] as bool,
        memberOnly: c['memberOnly'] as bool,
        stackWithInstantDiscount: c['stackWithInstantDiscount'] as bool,
      ),
      LegacyCouponTarget(
        includeProductIds: (t['includeProductIds'] as List).cast<String>(),
        includeCategoryIds: (t['includeCategoryIds'] as List).cast<String>(),
        excludeProductIds: (t['excludeProductIds'] as List).cast<String>(),
        excludeCategoryIds: (t['excludeCategoryIds'] as List).cast<String>(),
      ),
    ));
  },
  'legacyFromCouponRules': (a) {
    final r = legacyFromCouponRules(_ruleTrees(a[0]), a[1] as bool);
    return {'conditions': r.conditions.toJson(), 'target': r.target.toJson(), 'rulesOnly': r.rulesOnly};
  },
  'couponTargetTreeMatches': (a) => couponTargetTreeMatches(_targetTree(a[0]), _lineContext(a[1])),
  'couponLineMatches': (a) => couponLineMatches(_targetRules(a[0]), _lineContext(a[1])),
  'evaluateCouponEligibility': (a) => evaluateCouponEligibility(_group(a[0]), _orderContext(a[1]), a[2] as String),
  'assumeCouponFactRules': (a) =>
      assumeCouponFactRules(_group(a[0]), couponFactsOfJson(a[1]) ?? const CouponFacts()).toJson(),
  'couponAudienceMatches': (a) => couponAudienceMatches(_group(a[0]), couponFactsOfJson(a[1]) ?? const CouponFacts()),
  'couponCustomerFactNames': (a) => couponCustomerFactNames([for (final g in a) _group(g)]).toList(),
  'pickCouponFacts': (a) => _json(pickCouponFacts(couponFactsOfJson(a[0]) ?? const CouponFacts(), _group(a[1]))),
  'couponRuleIssues': (a) {
    final j = _m(a[0]);
    return _json(couponRuleIssues(
      memberOnly: j['memberOnly'] as bool,
      issueMethod: j['issueMethod'] as String,
      perMemberUseLimit: j['perMemberUseLimit'] as int?,
      eligibility: _groupOrNull(j['eligibility']),
      targetRules: j['targetRules'] == null ? null : _targetRules(j['targetRules']),
      targetTree: j['targetTree'] == null ? null : _targetTree(j['targetTree']),
      audience: _groupOrNull(j['audience']),
    ));
  },
  'canonicalizeCouponTrees': (a) => _json(canonicalizeCouponTrees(_ruleTrees(a[0]))),
  'describeCouponRule': (a) => describeCouponRule(_rule(a[0]), _formatMoney(_at(a, 1))),
  'describeCouponGroup': (a) => describeCouponGroup(_group(a[0]), _formatMoney(_at(a, 1))),
  'describeCouponTargetRules': (a) => describeCouponTargetRules(_targetRules(a[0]), _formatMoney(_at(a, 1))),
  'describeCouponTargetTree': (a) => describeCouponTargetTree(_targetTree(a[0]), _formatMoney(_at(a, 1))),
  'couponRequirementsOf': (a) => _json(couponRequirementsOf(_group(a[0]), _formatMoney(_at(a, 1)))),
  // coupon-selection
  'maxWeightAssignment': (a) => maxWeightAssignment([for (final r in a[0] as List) (r as List).cast<num>()]),
  'bestCouponSelection': (a) {
    final s = bestCouponSelection(_selectionInput(a[0]));
    return {
      'coupons': [for (final c in s.coupons) _selectedCoupon(c)],
      'result': pricingResultJson(s.result),
      'discountAmount': s.discountAmount,
      'withPoints': s.withPoints,
    };
  },
  // coupon
  'couponRequestRuleIssues': (a) {
    final j = _m(a[0]);
    final issues = couponRequestRuleIssues(
      kind: j['kind'] as String?,
      issueMethod: j['issueMethod'] as String,
      conditions: j['conditions'] == null ? null : CouponConditionsInput.fromJson(_m(j['conditions'])),
      target: j['target'] == null ? null : CouponTargetInput.fromJson(_m(j['target'])),
      eligibility: _groupOrNull(j['eligibility']),
      targetRules: j['targetRules'] == null ? null : _targetRules(j['targetRules']),
      targetTree: j['targetTree'] == null ? null : _targetTree(j['targetTree']),
      audience: _groupOrNull(j['audience']),
      stacking: j['stacking'] == null ? null : CouponStacking.fromJson(_m(j['stacking'])),
      reward: j['reward'] == null ? null : CouponReward.fromJson(_m(j['reward'])),
      benefit: j['benefit'],
      perMemberUseLimit: j['perMemberUseLimit'] as int?,
      dailyIssueLimit: j['dailyIssueLimit'] as int?,
      issueStartsAt: j['issueStartsAt'] as String?,
      issueEndsAt: j['issueEndsAt'] as String?,
      visibleFrom: j['visibleFrom'] as String?,
      endsAt: j['endsAt'] as String?,
    );
    return [
      for (final i in issues) {'path': i.path, 'message': i.message},
    ];
  },
};
