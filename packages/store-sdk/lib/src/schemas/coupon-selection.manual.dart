// 손으로 쓴 부분 — coupon-selection.ts의 최대 가중 매칭과 최대 할인 쿠폰 조합.
part of 'coupon-selection.dart';

String _keyOf(PricingCoupon coupon) => coupon.couponKey ?? coupon.rule.couponId;

/// 먼저 끝나는 시각(쿠폰 종료·발급 유효 종료 중 이른 쪽). 없으면 +무한대
double _untilOf(PricingCoupon coupon) {
  final times = [coupon.rule.endsAt, coupon.validUntil]
      .whereType<String>()
      .where((t) => t.isNotEmpty)
      .map(jsDateParse)
      .where((t) => !t.isNaN)
      .toList();
  return times.isEmpty ? double.infinity : times.reduce((a, b) => a < b ? a : b);
}

/// JS `Array.prototype.sort`처럼 안정 정렬한다(Dart `List.sort`는 안정을 보장하지 않는다)
List<T> _stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}

int _compareUntilKey(double untilA, String keyA, double untilB, String keyB) {
  if (untilA < untilB) return -1;
  if (untilA > untilB) return 1;
  return keyA.compareTo(keyB);
}

PricingCoupon _withLine(PricingCoupon coupon, String? lineId) => PricingCoupon(
      rule: coupon.rule,
      couponKey: coupon.couponKey,
      lineId: lineId,
      eligibleLineIds: coupon.eligibleLineIds,
      validFrom: coupon.validFrom,
      validUntil: coupon.validUntil,
      facts: coupon.facts,
    );

/// 최대 가중 매칭(헝가리안, 행 = 쿠폰, 열 = 줄)입니다. `weights[i][j]`가 0이면 배정하지 않는 것과 같습니다.
///
/// 결과는 행마다 열 번호 또는 -1입니다. 크기는 보유 쿠폰 × 주문서 줄이라 작습니다.
List<int> maxWeightAssignment(List<List<num>> weights) {
  final rows = weights.length;
  final cols = rows == 0 ? 0 : weights.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  if (rows == 0 || cols == 0) return List.filled(rows, -1);
  final n = rows > cols ? rows : cols;
  final max = weights.expand((r) => r).fold<num>(0, (m, w) => w > m ? w : m);
  // 비용 = max − 가중치(정사각 행렬로 채운다). 1부터 세는 고전 구현
  num cost(int i, int j) => max - (i < weights.length && j < weights[i].length ? weights[i][j] : 0);
  final u = List<num>.filled(n + 1, 0);
  final v = List<num>.filled(n + 1, 0);
  final p = List<int>.filled(n + 1, 0);
  final way = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= n; i++) {
    p[0] = i;
    var j0 = 0;
    final minv = List<num>.filled(n + 1, double.infinity);
    final used = List<bool>.filled(n + 1, false);
    do {
      used[j0] = true;
      final i0 = p[j0];
      num delta = double.infinity;
      var j1 = 0;
      for (var j = 1; j <= n; j++) {
        if (used[j]) continue;
        final cur = cost(i0 - 1, j - 1) - u[i0] - v[j];
        if (cur < minv[j]) {
          minv[j] = cur;
          way[j] = j0;
        }
        if (minv[j] < delta) {
          delta = minv[j];
          j1 = j;
        }
      }
      for (var j = 0; j <= n; j++) {
        if (used[j]) {
          u[p[j]] = u[p[j]] + delta;
          v[j] = v[j] - delta;
        } else {
          minv[j] = minv[j] - delta;
        }
      }
      j0 = j1;
    } while (p[j0] != 0);
    do {
      final j1 = way[j0];
      p[j0] = p[j1];
      j0 = j1;
    } while (j0 != 0);
  }
  final assignment = List<int>.filled(rows, -1);
  for (var j = 1; j <= n; j++) {
    final i = p[j] - 1;
    if (i >= 0 && i < rows && j - 1 < cols && j - 1 < weights[i].length && weights[i][j - 1] > 0) {
      assignment[i] = j - 1;
    }
  }
  return assignment;
}

typedef _Candidate = ({PricingCoupon coupon, String key, double until});
typedef _Entry = ({_Candidate candidate, PricingCouponResult? result});
typedef _Scored = ({List<PricingCoupon> coupons, PricingResult result, int discount, List<(double, String)> tie});

/// 후보 쿠폰 중 할인 합이 가장 큰 조합을 고릅니다. **순수 함수입니다.** 금액은 고른 조합을 [quotePricing]에 다시 넣어 계산합니다.
///
/// 적립금은 목표에 넣지 않습니다. 동률이면 장수가 적은 조합, 그다음 먼저 끝나는 쿠폰을 쓰는 조합, 그다음 쿠폰 키 순입니다.
CouponSelection bestCouponSelection(CouponSelectionInput input) {
  final rules = input.moneyRules ?? KRW_MONEY_RULES;
  PricingResult price(List<PricingCoupon> coupons) => quotePricing(PricingInput(
        lines: input.lines,
        points: null,
        coupons: coupons,
        delivery: input.delivery,
        firstOrder: input.firstOrder,
        isMember: input.isMember,
        now: input.now,
        facts: input.facts,
        ignoreEligibility: input.ignoreEligibility,
        moneyRules: input.moneyRules,
      ));

  // 1) 혼자서도 적용되는 후보 — 먼저 끝나는 쿠폰, 쿠폰 키 순으로 줄 세워 결과가 결정적이다
  final ordered = _stableSorted<_Candidate>(
    [
      for (final coupon in input.candidates)
        (coupon: _withLine(coupon, null), key: _keyOf(coupon), until: _untilOf(coupon)),
    ],
    (a, b) => _compareUntilKey(a.until, a.key, b.until, b.key),
  );
  final solo = <_Entry>[
    for (final candidate in ordered) (candidate: candidate, result: price([candidate.coupon]).coupons.firstOrNull),
  ].where((entry) => entry.result?.applied == true).toList();

  final products = solo.where((e) => e.candidate.coupon.rule.kind == 'PRODUCT').toList();
  final orders = solo.where((e) => e.candidate.coupon.rule.kind == 'ORDER').toList();
  final deliveries = solo.where((e) => e.candidate.coupon.rule.kind == 'DELIVERY').toList();
  final lineIds = [for (final line in input.lines) line.lineId];
  final lineById = {for (final line in input.lines) line.lineId: line};

  // 상품 쿠폰 한 장의 줄별 할인 — 대상 줄만, 줄 금액 기준
  List<int> weightsOf(_Entry entry) {
    final eligible = (entry.result?.eligibleLineIds ?? const <String>[]).toSet();
    return [
      for (final id in lineIds)
        eligible.contains(id)
            ? couponRuleDiscountOf(
                entry.candidate.coupon.rule,
                lineById[id]?.amount ?? 0,
                lineById[id] == null ? null : (quantity: lineById[id]!.quantity),
                rules,
              )
            : 0,
    ];
  }

  // 같은 쿠폰 정의는 perOrderLimit 장까지만 후보로 둔다(사본끼리는 규칙이 같아 앞 장이면 된다)
  List<_Entry> withinLimit(List<_Entry> entries) {
    final seen = <String, int>{};
    return entries.where((entry) {
      final rule = entry.candidate.coupon.rule;
      final count = seen[rule.couponId] ?? 0;
      if (count >= couponStackingOf(rule).perOrderLimit) return false;
      seen[rule.couponId] = count + 1;
      return true;
    }).toList();
  }

  final planCache = <String, List<List<PricingCoupon>>>{};
  // 상품 쿠폰 배정안 — 함께 쓰는 쿠폰들의 최대 매칭 하나 + 혼자 쓰는 쿠폰마다 하나
  List<List<PricingCoupon>> productPlans(List<_Entry> allowed) {
    final signature = allowed.map((e) => e.candidate.key).join('\n');
    final cached = planCache[signature];
    if (cached != null) return cached;
    final plans = <List<PricingCoupon>>[];
    final sociable =
        withinLimit(allowed.where((e) => couponStackingOf(e.candidate.coupon.rule).combinesWith.product).toList());
    final assignment = maxWeightAssignment([for (final entry in sociable) weightsOf(entry)]);
    plans.add([
      for (var i = 0; i < sociable.length; i++)
        if (i < assignment.length && assignment[i] >= 0)
          _withLine(sociable[i].candidate.coupon, assignment[i] < lineIds.length ? lineIds[assignment[i]] : null),
    ]);
    for (final entry in allowed) {
      if (couponStackingOf(entry.candidate.coupon.rule).combinesWith.product) continue;
      final weights = weightsOf(entry);
      var best = 0;
      for (var i = 0; i < weights.length; i++) {
        if (weights[i] > weights[best]) best = i;
      }
      if (weights.isNotEmpty && weights[best] > 0) {
        plans.add([_withLine(entry.candidate.coupon, best < lineIds.length ? lineIds[best] : null)]);
      }
    }
    planCache[signature] = plans;
    return plans;
  }

  // 동률 비교 — 먼저 끝나는 쿠폰을 쓰는 쪽이 앞선다(만료 없음은 가장 뒤). 숫자는 숫자로 비교한다
  bool tieLess(List<(double, String)> a, List<(double, String)> b) {
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final (ua, ka) = a[i];
      final (ub, kb) = b[i];
      if (ua != ub) return ua < ub;
      if (ka != kb) return ka.compareTo(kb) < 0;
    }
    return a.length < b.length;
  }

  _Scored? best;
  void consider(List<PricingCoupon> coupons) {
    final result = price(coupons);
    if (!result.coupons.every((c) => c.applied)) return;
    if (result.totalAmount > 0 && result.totalAmount < rules.minPayment) {
      // 결제를 시작할 수 없는 금액 — 할인이 가장 작은 상품 쿠폰을 빼고 다시 본다
      final productCoupons = _stableSorted<(PricingCouponResult, int)>(
        [
          for (var i = 0; i < result.coupons.length; i++)
            if (result.coupons[i].kind == 'PRODUCT') (result.coupons[i], i),
        ],
        (a, b) {
          final byDiscount = a.$1.discount - b.$1.discount;
          return byDiscount != 0 ? byDiscount : b.$2 - a.$2;
        },
      );
      if (productCoupons.isNotEmpty) {
        final drop = productCoupons.first.$2;
        consider([
          for (var i = 0; i < coupons.length; i++)
            if (i != drop) coupons[i],
        ]);
      }
      return;
    }
    final discount = result.couponDiscountAmount + result.deliveryDiscountAmount;
    final tie = _stableSorted<(double, String)>(
      [for (final c in coupons) (_untilOf(c), _keyOf(c))],
      (a, b) => _compareUntilKey(a.$1, a.$2, b.$1, b.$2),
    );
    final current = best;
    if (current == null ||
        discount > current.discount ||
        (discount == current.discount &&
            (coupons.length < current.coupons.length ||
                (coupons.length == current.coupons.length && tieLess(tie, current.tie))))) {
      best = (coupons: coupons, result: result, discount: discount, tie: tie);
    }
  }

  for (final order in <_Entry?>[null, ...orders]) {
    for (final delivery in <_Entry?>[null, ...deliveries]) {
      final o = order?.candidate.coupon;
      final d = delivery?.candidate.coupon;
      if (o != null && d != null && !couponsCombinable(o, d)) continue;
      final allowed = products
          .where((e) =>
              (o == null || couponsCombinable(e.candidate.coupon, o)) &&
              (d == null || couponsCombinable(e.candidate.coupon, d)))
          .toList();
      for (final plan in productPlans(allowed)) {
        consider([...plan, if (o != null) o, if (d != null) d]);
      }
    }
  }

  final chosen = best;
  if (chosen == null) {
    return CouponSelection(coupons: const [], result: price(const []), discountAmount: 0, withPoints: true);
  }
  return CouponSelection(
    coupons: chosen.coupons,
    result: chosen.result,
    discountAmount: chosen.discount,
    withPoints: chosen.coupons.every((c) => couponStackingOf(c.rule).withPoints),
  );
}
