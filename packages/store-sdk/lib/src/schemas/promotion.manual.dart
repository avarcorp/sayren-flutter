// 손으로 쓴 부분 — promotion.ts의 쿠폰 금액 계산(quotePricing)과 환불 정산의 조건 미달 차감.
part of 'promotion.dart';

/// 쿠폰 혜택 superRefine — 정률은 1~100%, 정액에는 최대 할인액을 두지 않는다
void _couponBenefitCheck(CouponBenefit benefit, ZodCheckContext ctx) {
  if (benefit.type == 'RATE' && benefit.value > 100) {
    ctx.addIssue('정률 할인은 1~100(%)이어야 합니다', path: ['value']);
  }
  if (benefit.type == 'AMOUNT' && benefit.maxDiscountAmount != null) {
    ctx.addIssue('정액 할인에는 최대 할인액을 두지 않습니다', path: ['maxDiscountAmount']);
  }
}

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;

/// JS `Math.floor(a / b)` — 정수 나눗셈을 음의 무한대 쪽으로 내린다(b > 0)
int _floorDiv(int a, int b) => (a - a % b) ~/ b;

const _maxSafeInteger = 9007199254740991;

/// 할인액입니다. 정률은 판매가 단위(`rules.saleUnit`, KRW 10원)로 내리고, 최대 할인액과 기준 금액 [base]를 넘지 않습니다.
/// 기준 금액이 0 이하면 0입니다.
///
/// 곱셈을 먼저 하고 나눕니다. [rules]를 생략하면 KRW 규칙(`KRW_MONEY_RULES`)입니다.
int couponDiscountOf(CouponBenefit benefit, int base, [MoneyRules? rules]) {
  if (base <= 0) return 0;
  final unit = (rules ?? KRW_MONEY_RULES).saleUnit;
  var raw = benefit.type == 'RATE' ? _floorDiv(base * benefit.value, 100 * unit) * unit : benefit.value;
  final max = benefit.maxDiscountAmount;
  if (benefit.type == 'RATE' && max != null) raw = _min(raw, max);
  return _max(0, _min(raw, base));
}

/// 금액 [total]을 가중치 [weights] 비율로 나눕니다. **누적 내림의 차분**입니다.
///
/// `i`번째 몫 = `floor(total × W_i / W) − floor(total × W_{i−1} / W)`(`W_i`는 앞에서부터 누적 가중치).
/// 합이 [total]과 정확히 같고, 입력 순서가 같으면 결과도 같습니다. 음수 가중치는 0으로 봅니다.
/// 금액·가중치가 안전한 정수(±2^53−1)가 아니면 [RangeError]를 던집니다.
List<int> allocateByWeight(int total, List<int> weights) {
  if (total.abs() > _maxSafeInteger || weights.any((w) => w.abs() > _maxSafeInteger)) {
    throw RangeError('allocateByWeight: 금액과 가중치는 안전한 정수여야 합니다');
  }
  final sum = weights.fold<int>(0, (acc, w) => acc + _max(0, w));
  if (total <= 0 || sum <= 0) return [for (final _ in weights) 0];
  final bigTotal = BigInt.from(total);
  final bigSum = BigInt.from(sum);
  var cumulative = BigInt.zero;
  var previous = BigInt.zero;
  return [
    for (final weight in weights)
      () {
        cumulative += BigInt.from(_max(0, weight));
        final upTo = (bigTotal * cumulative) ~/ bigSum;
        final share = upTo - previous;
        previous = upTo;
        return share.toInt();
      }(),
  ];
}

/// 카테고리 경로(`/a/b/c/`)가 그 카테고리 또는 하위를 가리키는가
bool _inCategory(String? categoryPath, List<String> categoryIds) {
  if (categoryPath == null || categoryPath.isEmpty || categoryIds.isEmpty) return false;
  final chain = categoryPath.split('/').where((s) => s.isNotEmpty).toList();
  return categoryIds.any(chain.contains);
}

/// 줄 [line]이 쿠폰 [rule]의 대상인지입니다. 제외가 포함보다 우선하고, 포함 목록이 모두 비면 전 상품입니다.
///
/// 규칙은 `target`·`conditions`만, 줄은 `productId`·`categoryPath`·`baseAmount`·`amount`만 읽습니다.
bool isCouponTargetLine(CouponRule rule, PricingLine line) {
  final target = rule.target;
  if (!rule.conditions.stackWithInstantDiscount && line.amount < line.baseAmount) return false;
  if (target.excludeProductIds.contains(line.productId)) return false;
  if (_inCategory(line.categoryPath, target.excludeCategoryIds)) return false;
  final noInclude = target.includeProductIds.isEmpty && target.includeCategoryIds.isEmpty;
  if (noInclude) return true;
  return target.includeProductIds.contains(line.productId) || _inCategory(line.categoryPath, target.includeCategoryIds);
}

/// 시각 파싱 — 값이 없으면 null(제한 없음), 읽지 못하면 NaN(판정에서 거절한다)
double? _timeOf(String? value) => value == null || value.isEmpty ? null : jsDateParse(value);

/// 사용 기간 판정 — 쿠폰 기간과 발급 쿠폰 유효 기간 중 좁은 쪽. 시작은 포함, 종료는 제외.
/// 읽지 못하는 시각은 제한 없음이 아니라 거절이다(fail-closed)
CouponRejectReason? _periodRejectOf(PricingCoupon coupon, DateTime now) {
  final at = now.millisecondsSinceEpoch;
  final starts = [_timeOf(coupon.rule.startsAt), _timeOf(coupon.validFrom)].whereType<double>();
  final ends = [_timeOf(coupon.rule.endsAt), _timeOf(coupon.validUntil)].whereType<double>();
  if (starts.any((t) => t.isNaN || at < t)) return 'NOT_STARTED';
  if (ends.any((t) => t.isNaN || at >= t)) return 'EXPIRED';
  return null;
}

class _PricingLineEntry {
  _PricingLineEntry(this.line);

  final PricingLine line;
  var productDiscount = 0;
  final allocations = <CouponAllocation>[];
}

class _PricingCouponState {
  _PricingCouponState(this.couponKey, this.couponId, this.kind);

  final String couponKey;
  final String couponId;
  final CouponKind kind;
  var applied = false;
  var discount = 0;
  CouponRejectReason? rejectReason;
  String? lineId;
  var eligibleLineIds = <String>[];

  PricingCouponResult result() => PricingCouponResult(
        couponKey: couponKey,
        couponId: couponId,
        kind: kind,
        applied: applied,
        discount: discount,
        rejectReason: rejectReason,
        lineId: lineId,
        eligibleLineIds: eligibleLineIds,
      );
}

/// 쿠폰 금액을 계산합니다. **순수 함수입니다.** 규칙 스냅샷을 만드는 조회와 한도·보유 판정(발급 쿠폰 상태, 1인 한도)은 호출부 몫입니다.
///
/// 종류별로 상품 쿠폰 → 주문 쿠폰 → 배송비 쿠폰 순으로 적용합니다. 같은 종류의 자리와 같은 쿠폰 id는 **적용된** 쿠폰만 차지합니다 —
/// 앞선 주문 쿠폰이 최소 금액 미달이면 뒤의 주문 쿠폰이 쓰이고, 같은 쿠폰의 발급 사본 중 앞 장이 만료됐으면 뒤 장이 쓰입니다.
/// 결과의 `coupons`는 입력 순서 그대로입니다. 입력이 같으면 결과도 같습니다.
///
/// ```dart
/// final pricing = quotePricing(PricingInput(
///   lines: [PricingLine(lineId: '1', productId: 'prd_1', quantity: 1, baseAmount: 20000, amount: 18000)],
///   coupons: [PricingCoupon(rule: rule)],
///   firstOrder: false,
///   isMember: true,
///   now: DateTime.now(),
/// ));
/// ```
PricingResult quotePricing(PricingInput input) {
  final rules = input.moneyRules ?? KRW_MONEY_RULES;
  final lines = [for (final line in input.lines) _PricingLineEntry(line)];
  final lineIndex = {for (var i = 0; i < lines.length; i++) lines[i].line.lineId: i};
  _PricingLineEntry? lineOf(String id) {
    final index = lineIndex[id];
    return index == null ? null : lines[index];
  }

  final results = [
    for (final coupon in input.coupons)
      _PricingCouponState(coupon.couponKey ?? coupon.rule.couponId, coupon.rule.couponId, coupon.rule.kind),
  ];

  // 1) 쿠폰마다 공통 조건 — 기간·회원·첫 구매·대상·최소 금액
  CouponRejectReason? commonRejectOf(PricingCoupon coupon, _PricingCouponState result) {
    if (input.ignoreEligibility != true) {
      final period = _periodRejectOf(coupon, input.now);
      if (period != null) return period;
      if (coupon.rule.conditions.memberOnly && !input.isMember) return 'MEMBER_ONLY';
      if (coupon.rule.conditions.firstOrderOnly && !input.firstOrder) return 'FIRST_ORDER_ONLY';
    }
    final pinned = coupon.eligibleLineIds?.toSet();
    final eligible = [
      for (final entry in lines)
        if (pinned != null ? pinned.contains(entry.line.lineId) : isCouponTargetLine(coupon.rule, entry.line)) entry,
    ];
    result.eligibleLineIds = [for (final entry in eligible) entry.line.lineId];
    if (eligible.isEmpty) return 'NO_ELIGIBLE_ITEMS';
    final targetAmount = eligible.fold<int>(0, (sum, entry) => sum + entry.line.amount);
    if (targetAmount < coupon.rule.conditions.minOrderAmount) return 'MIN_ORDER_AMOUNT';
    return null;
  }

  final passed = <int>[];
  for (var index = 0; index < input.coupons.length; index++) {
    final result = results[index];
    final reason = commonRejectOf(input.coupons[index], result);
    if (reason != null) {
      result.rejectReason = reason;
    } else {
      passed.add(index);
    }
  }

  // 적용된 쿠폰 id — 같은 쿠폰 정의는 주문에 한 장
  final appliedCouponIds = <String>{};
  void apply(int index, int discount, String? lineId) {
    final result = results[index]
      ..applied = true
      ..discount = discount
      ..lineId = lineId;
    appliedCouponIds.add(result.couponId);
  }

  bool duplicate(int index) {
    final result = results[index];
    if (!appliedCouponIds.contains(result.couponId)) return false;
    result.rejectReason = 'DUPLICATE_COUPON';
    return true;
  }

  bool hasLine(PricingCoupon coupon) => coupon.lineId != null && coupon.lineId!.isNotEmpty;

  // 2) 상품 쿠폰 — 한 줄에 한 장. 줄을 지정한 쿠폰을 먼저 걸고, 나머지는 대상 줄이 적은 쿠폰부터
  //    할인이 가장 큰 남은 줄(같으면 앞 줄)에 건다. 대상이 넓은 쿠폰이 좁은 쿠폰의 유일한 줄을 먼저 가져가지 않게 한다
  final productIndexes = passed.where((index) => input.coupons[index].rule.kind == 'PRODUCT').toList();
  final unpinned = productIndexes.where((index) => !hasLine(input.coupons[index])).toList()
    ..sort((a, b) {
      final byWidth = results[a].eligibleLineIds.length - results[b].eligibleLineIds.length;
      return byWidth != 0 ? byWidth : a - b;
    });
  final productOrder = [...productIndexes.where((index) => hasLine(input.coupons[index])), ...unpinned];
  final takenLines = <String>{};
  for (final index in productOrder) {
    final coupon = input.coupons[index];
    final result = results[index];
    if (duplicate(index)) continue;
    final candidates = result.eligibleLineIds.where((id) => !takenLines.contains(id)).toList();
    String? chosen;
    var best = 0;
    if (hasLine(coupon)) {
      final lineId = coupon.lineId!;
      if (!candidates.contains(lineId)) {
        result.rejectReason = result.eligibleLineIds.contains(lineId) ? 'STACK_LIMIT' : 'LINE_NOT_ELIGIBLE';
        continue;
      }
      chosen = lineId;
      best = couponDiscountOf(coupon.rule.benefit, lineOf(chosen)?.line.amount ?? 0, rules);
    } else {
      if (candidates.isEmpty) {
        result.rejectReason = 'STACK_LIMIT';
        continue;
      }
      for (final id in candidates) {
        final discount = couponDiscountOf(coupon.rule.benefit, lineOf(id)?.line.amount ?? 0, rules);
        if (chosen == null || discount > best) {
          chosen = id;
          best = discount;
        }
      }
    }
    final entry = chosen == null ? null : lineOf(chosen);
    if (entry == null || chosen == null || best <= 0) {
      result.rejectReason = 'NO_DISCOUNT';
      continue;
    }
    takenLines.add(chosen);
    entry.productDiscount += best;
    entry.allocations.add(CouponAllocation(couponKey: result.couponKey, amount: best));
    apply(index, best, chosen);
  }

  // 3) 주문 쿠폰 — 상품 쿠폰 차감 뒤 금액 기준, 대상 줄에 금액 비율로 배분
  var orderSlot = false;
  for (final index in passed) {
    final coupon = input.coupons[index];
    final result = results[index];
    if (coupon.rule.kind != 'ORDER') continue;
    if (duplicate(index)) continue;
    if (orderSlot) {
      result.rejectReason = 'STACK_LIMIT';
      continue;
    }
    final targets = result.eligibleLineIds.map(lineOf).whereType<_PricingLineEntry>().toList();
    final weights = [for (final entry in targets) _max(0, entry.line.amount - entry.productDiscount)];
    final base = weights.fold<int>(0, (sum, w) => sum + w);
    final discount = couponDiscountOf(coupon.rule.benefit, base, rules);
    if (discount <= 0) {
      result.rejectReason = 'NO_DISCOUNT';
      continue;
    }
    final shares = allocateByWeight(discount, weights);
    for (var i = 0; i < targets.length; i++) {
      final share = i < shares.length ? shares[i] : 0;
      if (share > 0) targets[i].allocations.add(CouponAllocation(couponKey: result.couponKey, amount: share));
    }
    orderSlot = true;
    apply(index, discount, null);
  }

  // 4) 배송비 쿠폰 — 기본 배송비(지역 추가 제외) 기준, 묶음에 기본 배송비 비율로 배분
  final deliveryBundles = input.delivery?.bundles ?? const <({String bundleKey, int fee, int remoteSurcharge})>[];
  final bundleDiscounts = [for (final _ in deliveryBundles) 0];
  final bundlePoints = [for (final _ in deliveryBundles) 0];
  var deliverySlot = false;
  var deliveryDiscountAmount = 0;
  for (final index in passed) {
    final coupon = input.coupons[index];
    final result = results[index];
    if (coupon.rule.kind != 'DELIVERY') continue;
    if (duplicate(index)) continue;
    if (deliverySlot) {
      result.rejectReason = 'STACK_LIMIT';
      continue;
    }
    final weights = [for (final bundle in deliveryBundles) _max(0, bundle.fee)];
    final base = weights.fold<int>(0, (sum, w) => sum + w);
    final discount = couponDiscountOf(coupon.rule.benefit, base, rules);
    if (discount <= 0) {
      result.rejectReason = 'NO_DISCOUNT';
      continue;
    }
    final shares = allocateByWeight(discount, weights);
    for (var i = 0; i < shares.length; i++) {
      bundleDiscounts[i] += shares[i];
    }
    deliverySlot = true;
    deliveryDiscountAmount = discount;
    apply(index, discount, null);
  }

  final lineCoupon = [for (final entry in lines) entry.allocations.fold<int>(0, (sum, a) => sum + a.amount)];
  final linePoints = [for (final _ in lines) 0];
  final productAmount = lines.fold<int>(0, (sum, entry) => sum + entry.line.amount);
  final couponDiscountAmount = lineCoupon.fold<int>(0, (sum, d) => sum + d);
  final deliveryFee = deliveryBundles.fold<int>(0, (sum, bundle) => sum + bundle.fee + bundle.remoteSurcharge);
  final beforePoints = productAmount - couponDiscountAmount + deliveryFee - deliveryDiscountAmount;

  // 5) 적립금(#93 P3) — 쿠폰 뒤 금액에 쓴다. 상품 줄에 먼저(줄 실결제 비율), 남으면 배송 묶음에(묶음 실배송비 비율) 배분한다
  final productWeights = [for (var i = 0; i < lines.length; i++) _max(0, lines[i].line.amount - lineCoupon[i])];
  final bundleWeights = [
    for (var i = 0; i < deliveryBundles.length; i++)
      _max(0, deliveryBundles[i].fee + deliveryBundles[i].remoteSurcharge - bundleDiscounts[i]),
  ];
  final productPaid = productWeights.fold<int>(0, (sum, w) => sum + w);
  final points = pointUseOf(
    input.points,
    (productPaid: productPaid, deliveryPaid: bundleWeights.fold<int>(0, (sum, w) => sum + w), total: beforePoints),
    rules,
  );
  if (points.amount > 0) {
    final toLines = _min(points.amount, productPaid);
    final lineShares = allocateByWeight(toLines, productWeights);
    for (var i = 0; i < lineShares.length; i++) {
      linePoints[i] = lineShares[i];
    }
    final toBundles = points.amount - toLines;
    if (toBundles > 0) {
      final bundleShares = allocateByWeight(toBundles, bundleWeights);
      for (var i = 0; i < bundleShares.length; i++) {
        bundlePoints[i] = bundleShares[i];
      }
    }
  }
  return PricingResult(
    lines: [
      for (var i = 0; i < lines.length; i++)
        PricingLineResult(
          lineId: lines[i].line.lineId,
          amount: lines[i].line.amount,
          couponDiscount: lineCoupon[i],
          allocations: lines[i].allocations,
          pointAllocation: linePoints[i],
        ),
    ],
    coupons: [for (final result in results) result.result()],
    bundles: [
      for (var i = 0; i < deliveryBundles.length; i++)
        PricingBundleResult(
          bundleKey: deliveryBundles[i].bundleKey,
          couponDiscount: bundleDiscounts[i],
          pointAllocation: bundlePoints[i],
        ),
    ],
    productAmount: productAmount,
    couponDiscountAmount: couponDiscountAmount,
    deliveryFee: deliveryFee,
    deliveryDiscountAmount: deliveryDiscountAmount,
    pointAmount: points.amount,
    pointMaxUsable: points.maxUsable,
    pointAdjustReason: points.adjustReason,
    pointRejectReason: points.rejectReason,
    totalAmount: beforePoints - points.amount,
  );
}

/// 사용 적립금 금액을 정합니다(순수). 요청·잔액·최대 비율 중 작은 값을 씁니다(#93 P3·P4).
///
/// - 결제 금액 전체를 덮을 수 있으면 전액을 씁니다(0원 결제, 이때만 사용 단위를 보지 않습니다).
/// - 그 밖에는 사용 단위로 내리고, 남는 결제 금액이 1~99원이면 적립금을 줄여 100원을 남깁니다(`MIN_PAYMENT`).
///
/// 최소 보유액·최소 사용액에 못 미치면 0입니다. [moneyRules]를 생략하면 KRW 규칙입니다.
({int amount, int maxUsable, String? adjustReason, PointRejectReason? rejectReason}) pointUseOf(
  PricingPoints? points,
  ({int productPaid, int deliveryPaid, int total}) amounts, [
  MoneyRules? moneyRules,
]) {
  const none = (amount: 0, maxUsable: 0, adjustReason: null, rejectReason: null);
  if (points == null) return none;
  final money = moneyRules ?? KRW_MONEY_RULES;
  final rules = points.rules;
  final unit = _max(1, rules.unit);
  final base = amounts.productPaid + (rules.includeDeliveryFee ? amounts.deliveryPaid : 0);
  final byRatio = _floorDiv(base * rules.maxRatioBp, 10000);
  final balance = _max(0, points.balance);
  final total = _max(0, amounts.total);
  int floorUnit(int value) => _floorDiv(_max(0, value), unit) * unit;
  // 상한 cap으로 쓸 수 있는 금액 — 전액이면 0원 결제, 아니면 단위 내림 + 100원 남기기
  ({int amount, bool adjusted}) usableWithin(int cap) {
    if (total > 0 && cap >= total) return (amount: total, adjusted: false);
    final amount = floorUnit(_min(cap, total));
    final remaining = total - amount;
    if (remaining > 0 && remaining < money.minPayment) {
      return (amount: floorUnit(total - money.minPayment), adjusted: true);
    }
    return (amount: amount, adjusted: false);
  }

  final eligible = balance >= rules.minBalance;
  final ceiling = usableWithin(_min(balance, byRatio)).amount;
  final maxUsable = eligible && ceiling > 0 && ceiling >= rules.minAmount ? ceiling : 0;
  final requested = _max(0, points.requested);
  if (requested == 0) return (amount: 0, maxUsable: maxUsable, adjustReason: null, rejectReason: null);
  if (!eligible) return (amount: 0, maxUsable: maxUsable, adjustReason: null, rejectReason: 'MIN_BALANCE');
  final used = usableWithin(_min(requested, _min(balance, byRatio)));
  if (used.amount <= 0) return (amount: 0, maxUsable: maxUsable, adjustReason: null, rejectReason: 'NOT_PAYABLE');
  if (used.amount < rules.minAmount) {
    return (amount: 0, maxUsable: maxUsable, adjustReason: null, rejectReason: 'MIN_AMOUNT');
  }
  return (
    amount: used.amount,
    maxUsable: maxUsable,
    adjustReason: used.adjusted ? 'MIN_PAYMENT' : null,
    rejectReason: null
  );
}

/// 쿠폰 조건 미달 차감을 정산합니다. **순수 함수입니다.** 부분 취소·반품으로 남은 주문상품이 쿠폰 조건을 잃으면,
/// 남은 주문상품이 받던 할인만큼을 이번 환불에서 뺍니다.
///
/// 쿠폰마다 남은 수량에 배분된 할인(`allocatedRemaining`)과, 주문 시점 규칙·대상 줄로 남은 금액만 넣어 [quotePricing]을 다시 돌린
/// 할인(`recomputed`)을 구합니다. 쿠폰이 여전히 적용되면 목표는 0, 조건을 잃었으면 목표는 `allocatedRemaining`입니다.
/// 목표와 누적(차감 + 면제)의 차이가 양수면 청구하고(판매자 귀책·정책 꺼짐이면 면제로 기록), 음수면 앞서 뺀 차감부터 돌려줍니다.
/// 청구는 이번 환불에서 실제로 뺄 수 있는 금액(`chargeableAmount` + 이번에 되돌린 금액)을 넘지 않습니다.
///
/// 배송비 쿠폰은 다루지 않습니다.
CouponSettlementResult settleCouponShortfall(CouponSettlementInput input) {
  final coupons = input.coupons.where((coupon) => coupon.rule.kind != 'DELIVERY').toList();
  if (coupons.isEmpty) return const CouponSettlementResult(chargeAmount: 0, refundAmount: 0, entries: []);

  final pricingLines = [
    for (final line in input.lines)
      () {
        final remaining = proratedRefundBase(line.totalPrice, line.quantity, 0, line.activeQuantity);
        // 대상은 주문 시점 목록으로 고정하므로 즉시할인 판정에 쓰는 정가는 금액과 같게 둔다
        return PricingLine(
          lineId: line.lineId,
          productId: line.productId,
          quantity: line.activeQuantity,
          baseAmount: remaining,
          amount: remaining,
        );
      }(),
  ];
  final recomputed = quotePricing(PricingInput(
    lines: pricingLines,
    coupons: [
      for (final coupon in coupons)
        PricingCoupon(
          rule: coupon.rule,
          couponKey: coupon.couponKey,
          lineId: coupon.lineId,
          eligibleLineIds: coupon.eligibleLineIds,
        ),
    ],
    // 기간·회원·첫 구매 조건은 결제 시작에서 이미 통과했다 — 대상과 최소 금액만 남은 금액으로 다시 본다
    firstOrder: true,
    isMember: true,
    now: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ignoreEligibility: true,
  ));

  final base = [
    for (var index = 0; index < coupons.length; index++)
      () {
        final coupon = coupons[index];
        final allocatedRemaining = input.lines.fold<int>(0, (sum, line) {
          final allocation =
              line.allocations.where((a) => a.couponKey == coupon.couponKey).fold<int>(0, (acc, a) => acc + a.amount);
          return sum + proratedRefundBase(allocation, line.quantity, 0, line.activeQuantity);
        });
        final result = index < recomputed.coupons.length ? recomputed.coupons[index] : null;
        final stillApplied = result?.applied == true;
        final state = input.settlements[coupon.couponKey];
        return (
          couponKey: coupon.couponKey,
          allocatedRemaining: allocatedRemaining,
          recomputed: stillApplied ? result!.discount : 0,
          target: stillApplied ? 0 : allocatedRemaining,
          charged: _max(0, state?.charged ?? 0),
          waived: _max(0, state?.waived ?? 0),
        );
      }(),
  ];

  // 되돌림을 먼저 정한다 — 되돌린 금액만큼 이번 환불에서 뺄 수 있는 여유가 생긴다
  final entries = <({String couponKey, int allocatedRemaining, int recomputed, int target, int refund})>[];
  final charges = <int>[];
  final waives = <int>[];
  final nexts = <CouponSettlementState>[];
  var refundAmount = 0;
  for (final item in base) {
    final delta = item.target - (item.charged + item.waived);
    var refund = 0;
    var waived = item.waived;
    if (delta < 0) {
      // 구매자에게 유리하게 앞서 뺀 차감부터 돌려주고, 남은 초과분은 면제 기록에서 지운다
      refund = _min(item.charged, -delta);
      waived = _max(0, waived - (-delta - refund));
    }
    refundAmount += refund;
    entries.add((
      couponKey: item.couponKey,
      allocatedRemaining: item.allocatedRemaining,
      recomputed: item.recomputed,
      target: item.target,
      refund: refund,
    ));
    charges.add(0);
    waives.add(0);
    nexts.add(CouponSettlementState(charged: item.charged - refund, waived: waived));
  }

  var capacity = _max(0, input.chargeableAmount) + refundAmount;
  var chargeAmount = 0;
  final chargeAllowed = input.shortfallCharge && !input.sellerFault;
  for (var i = 0; i < entries.length; i++) {
    final next = nexts[i];
    final delta = entries[i].target - (next.charged + next.waived);
    if (delta <= 0) continue;
    if (!chargeAllowed) {
      waives[i] = delta;
      nexts[i] = CouponSettlementState(charged: next.charged, waived: next.waived + delta);
      continue;
    }
    final charge = _min(delta, capacity);
    if (charge <= 0) continue;
    capacity -= charge;
    chargeAmount += charge;
    charges[i] = charge;
    nexts[i] = CouponSettlementState(charged: next.charged + charge, waived: next.waived);
  }
  return CouponSettlementResult(
    chargeAmount: chargeAmount,
    refundAmount: refundAmount,
    entries: [
      for (var i = 0; i < entries.length; i++)
        CouponSettlementEntry(
          couponKey: entries[i].couponKey,
          allocatedRemaining: entries[i].allocatedRemaining,
          recomputed: entries[i].recomputed,
          target: entries[i].target,
          charge: charges[i],
          refund: entries[i].refund,
          waive: waives[i],
          next: nexts[i],
        ),
    ],
  );
}

/// 주문상품의 실결제 금액 중 이번 취소 수량의 몫입니다. **실결제 금액(`totalPrice − couponDiscountAmount − pointAllocation`)을
/// 누적 내림의 차분으로 나눕니다.** 몫이 항상 0 이상이고 전량 취소의 합이 실결제 금액과 정확히 같습니다.
///
/// [item]의 `pointAllocation`은 주문상품에 배분된 사용 적립금(#93 P3)이고 현금 환불 기준에서 뺍니다. 없으면 null입니다.
int proratedPaidRefundBase(
  ({int totalPrice, int? couponDiscountAmount, int? pointAllocation, int quantity}) item,
  int settledQuantity,
  int cancelQuantity,
) {
  final paid = _max(0, item.totalPrice - (item.couponDiscountAmount ?? 0) - (item.pointAllocation ?? 0));
  return proratedRefundBase(paid, item.quantity, settledQuantity, cancelQuantity);
}

/// 주문상품의 사용 적립금 중 이번 취소 수량의 몫입니다(#93 P3). 누적 내림의 차분이라 나눠 취소해도 합이 배분액과 같습니다.
/// 현금 환불([proratedPaidRefundBase])과 따로 돌려줍니다(`pointRefundAmount`).
int proratedPointRefund(({int? pointAllocation, int quantity}) item, int settledQuantity, int cancelQuantity) =>
    proratedRefundBase(item.pointAllocation ?? 0, item.quantity, settledQuantity, cancelQuantity);
