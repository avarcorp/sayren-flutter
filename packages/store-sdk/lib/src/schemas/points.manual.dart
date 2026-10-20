// 손으로 쓴 부분 — points.ts의 정책 해석·적립 금액·만료 시각·환불 나누기.
part of 'points.dart';

PointPolicy _defaultPointPolicy() => PointPolicy(
      reviewReward: ReviewRewardPolicy(enabled: false, textPoint: 0, photoPoint: 0),
      purchaseEarn: PurchaseEarnPolicy(enabled: false, rateBp: 0),
      use: PointUsePolicy(
        enabled: false,
        minBalance: 0,
        minAmount: 0,
        unit: 10,
        maxRatioBp: 10000,
        includeDeliveryFee: true,
      ),
      expiryDays: null,
    );

/// 적립금 유효 기간(일, 30~1825)
final _expiryDaysSchema = z
    .number()
    .int_()
    .greaterThan(POINT_EXPIRY_DAYS_MIN, inclusive: true)
    .lessThan(POINT_EXPIRY_DAYS_MAX, inclusive: true)
    .nullable();

/// 저장된 정책([stored], `stores.point_policy`)을 해석합니다. 항목마다 따로 검증하고, 읽지 못한 항목은 기본값(모두 끔)입니다.
PointPolicy resolvePointPolicy(Object? stored) {
  if (!truthy(stored) || (stored is! Map && stored is! List)) return _defaultPointPolicy();
  final raw = stored is Map ? stored : const {};
  final defaults = _defaultPointPolicy();
  final review = reviewRewardPolicySchema.safeParse(raw.containsKey('reviewReward') ? raw['reviewReward'] : absent);
  final purchase = purchaseEarnPolicySchema.safeParse(raw.containsKey('purchaseEarn') ? raw['purchaseEarn'] : absent);
  final use = pointUsePolicySchema.safeParse(raw.containsKey('use') ? raw['use'] : absent);
  final expiry = _expiryDaysSchema.safeParse(raw['expiryDays']);
  return PointPolicy(
    reviewReward: review.success ? review.data! : defaults.reviewReward,
    purchaseEarn: purchase.success ? purchase.data! : defaults.purchaseEarn,
    use: use.success ? use.data! : defaults.use,
    expiryDays: expiry.success ? expiry.data : null,
  );
}

/// 적립이 하나라도 켜져 있는지입니다(리뷰 적립 또는 구매 적립).
bool pointEarningEnabled(PointPolicy policy) => policy.reviewReward.enabled || policy.purchaseEarn.enabled;

/// 구매 적립률(만분율)입니다. 구매 적립이 꺼져 있으면 0이고, 상품 적립률 [productRateBp]가 있으면 그 값이 상점 기본보다 우선합니다.
int purchaseEarnRateOf(PointPolicy policy, int? productRateBp) {
  if (!policy.purchaseEarn.enabled) return 0;
  return productRateBp ?? policy.purchaseEarn.rateBp;
}

/// 적립 금액입니다. 적립 기준 금액 [paidBase] × 적립률 [rateBp] ÷ 10000을 내립니다. 둘 중 하나라도 0 이하면 0입니다.
int pointEarnOf({required int paidBase, required int rateBp}) {
  if (paidBase <= 0 || rateBp <= 0) return 0;
  return _floorDiv(paidBase * rateBp, 10000);
}

/// 리뷰 적립 금액입니다. 리뷰 적립이 꺼져 있으면 0이고, 사진 리뷰([hasPhoto])는 `textPoint + photoPoint`입니다.
int reviewRewardPointOf(PointPolicy policy, bool hasPhoto) {
  final reviewReward = policy.reviewReward;
  if (!reviewReward.enabled) return 0;
  return reviewReward.textPoint + (hasPhoto ? reviewReward.photoPoint : 0);
}

const _dayMs = 86400000;
const _kstOffsetMs = 9 * 3600000;
const _restoreGraceMs = 30 * _dayMs;

/// JS `Math.floor(a / b)`(b > 0)
int _floorDiv(int a, int b) => (a - a % b) ~/ b;

/// 적립금의 만료 시각입니다. 적립 시각 [earnedAt]으로부터 [days]일이 지난 날의 끝(한국 시간 23:59:59.999)이고, [days]가 null이면 만료가 없습니다(null).
DateTime? pointExpiresAtOf(DateTime earnedAt, int? days) {
  if (days == null) return null;
  final shifted = earnedAt.millisecondsSinceEpoch + days * _dayMs + _kstOffsetMs;
  final endOfDay = _floorDiv(shifted, _dayMs) * _dayMs + _dayMs - 1;
  return DateTime.fromMillisecondsSinceEpoch(endOfDay - _kstOffsetMs, isUtc: true);
}

/// 환불로 돌려주는 적립금의 만료 시각입니다. 결제에 쓴 묶음 [usages] 중 가장 늦은 만료이고, 그 시각이 이미 지났으면
/// 지금 + 30일(한국 시간 날짜 끝)입니다. 쓴 묶음 중 만료 없는 묶음이 있으면 만료 없음(null)이고, 쓴 기록이 없으면 지금 + 30일입니다.
DateTime? pointRestoreExpiresAtOf(List<PointLotUsage> usages, DateTime now) {
  if (usages.any((usage) => usage.expiresAt == null)) return null;
  double? latest;
  for (final usage in usages) {
    final at = jsDateParse(usage.expiresAt!);
    if (at.isFinite && (latest == null || at > latest)) latest = at;
  }
  if (latest != null && latest > now.millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(latest.toInt(), isUtc: true);
  }
  return pointExpiresAtOf(
      DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + _restoreGraceMs, isUtc: true), 0);
}

/// 환불 금액을 현금 몫·적립금 몫으로 나눕니다. 차감 [charges](반품 배송비·쿠폰 조건 미달·추가 차감)를 **현금에서 먼저** 빼고
/// 모자란 몫만 적립금에서 뺍니다. 둘 다 모자라면 0에서 멈추고 못 받은 차감액(`uncollected`)을 돌려줍니다.
({int cashRefund, int pointRefund, int uncollected}) splitRefund({
  required int cash,
  required int points,
  required int charges,
}) {
  final c = cash > 0 ? cash : 0;
  final p = points > 0 ? points : 0;
  final ch = charges > 0 ? charges : 0;
  final fromCash = c < ch ? c : ch;
  final rest = ch - fromCash;
  final fromPoints = p < rest ? p : rest;
  return (cashRefund: c - fromCash, pointRefund: p - fromPoints, uncollected: rest - fromPoints);
}
