// 손으로 쓴 부분 — coupon.ts의 함수·zod 클로저 구현.
part of 'coupon.dart';

/// 쿠폰 코드를 정규화합니다. 대문자로 바꾸고 앞뒤 공백을 지웁니다. 입력·저장·조회가 같은 함수를 씁니다.
String normalizeCouponCode(String code) => code.trim().toUpperCase();

/// 트리와 옛 칸을 한 번에 검사합니다. 트리를 주면 그 트리, 아니면 옛 칸에서 만든 트리로 같은 규칙을 봅니다(검증 원천 `couponRuleIssues`).
///
/// 생성 요청과 수정 뒤 합친 결과가 이 함수를 지납니다. 문제가 없으면 빈 목록입니다. [benefit]은 null이면 생략으로 봅니다.
List<({List<Object?> path, String message})> couponRequestRuleIssues({
  String? kind,
  required String issueMethod,
  CouponConditionsInput? conditions,
  CouponTargetInput? target,
  ConditionGroup? eligibility,
  CouponTargetRules? targetRules,
  CouponTargetTree? targetTree,
  ConditionGroup? audience,
  CouponStacking? stacking,
  CouponReward? reward,
  Object? benefit,
  int? perMemberUseLimit,
  int? dailyIssueLimit,
  String? issueStartsAt,
  String? issueEndsAt,
  String? visibleFrom,
  String? endsAt,
}) {
  final issues = <({List<Object?> path, String message})>[];
  void add(List<Object?> path, String message) => issues.add((path: path, message: message));
  final legacyConditions = LegacyCouponConditions(
    minOrderAmount: conditions?.minOrderAmount ?? COUPON_CONDITIONS_DEFAULTS['minOrderAmount'] as int,
    firstOrderOnly: conditions?.firstOrderOnly ?? COUPON_CONDITIONS_DEFAULTS['firstOrderOnly'] as bool,
    memberOnly: conditions?.memberOnly ?? COUPON_CONDITIONS_DEFAULTS['memberOnly'] as bool,
    stackWithInstantDiscount:
        conditions?.stackWithInstantDiscount ?? COUPON_CONDITIONS_DEFAULTS['stackWithInstantDiscount'] as bool,
  );
  if (eligibility != null && (conditions?.minOrderAmount != null || conditions?.firstOrderOnly != null)) {
    add(['conditions'], '사용 조건 트리를 주면 최소 주문 금액·첫 구매는 트리로 둡니다');
  }
  if (targetRules != null && (target != null || conditions?.stackWithInstantDiscount != null)) {
    add(['target'], '할인 대상 규칙을 주면 대상 상품·즉시할인 제외는 규칙으로 둡니다');
  }
  if (targetTree != null && (targetRules != null || target != null || conditions?.stackWithInstantDiscount != null)) {
    add(['targetTree'], '할인 대상 트리를 주면 할인 대상 규칙·대상 상품·즉시할인 제외는 트리로 둡니다');
  }
  final legacy = couponRulesFromLegacy(
    legacyConditions,
    LegacyCouponTarget(
      includeProductIds: target?.includeProductIds ?? const [],
      includeCategoryIds: target?.includeCategoryIds ?? const [],
      excludeProductIds: target?.excludeProductIds ?? const [],
      excludeCategoryIds: target?.excludeCategoryIds ?? const [],
    ),
  );
  for (final issue in couponRuleIssues(
    memberOnly: legacyConditions.memberOnly,
    issueMethod: issueMethod,
    perMemberUseLimit: perMemberUseLimit,
    eligibility: eligibility ?? legacy.eligibility,
    targetRules: targetRules ?? legacy.targetRules,
    targetTree: targetTree,
    audience: audience,
  )) {
    add(issue.path, issue.message);
  }
  if (reward == null && benefit == null) add(['benefit'], '혜택(benefit 또는 reward)이 필요합니다');
  if (reward != null && kind != null && !(COUPON_REWARD_KINDS[reward.type] ?? const []).contains(kind)) {
    add(
      ['reward', 'type'],
      reward.type == 'POINT'
          ? '적립금 지급은 주문 쿠폰만 쓸 수 있습니다'
          : reward.type == 'BUY_X_GET_Y'
              ? 'N+1은 상품 쿠폰만 쓸 수 있습니다'
              : '구간 할인은 배송비 쿠폰에 쓸 수 없습니다',
    );
  }
  if (reward?.type == 'POINT' && !legacyConditions.memberOnly) {
    add(['reward', 'type'], '적립금 지급은 회원 전용 쿠폰만 쓸 수 있습니다');
  }
  if (stacking != null && stacking.perOrderLimit > 1 && kind != 'PRODUCT') {
    add(['stacking', 'perOrderLimit'], '한 주문에 두 장 이상은 상품 쿠폰만 쓸 수 있습니다');
  }
  if (issueMethod == 'CODE' && dailyIssueLimit != null) {
    add(['dailyIssueLimit'], '하루 발급 한도는 발급형(셀러 지급·받기·회원가입) 쿠폰에만 둡니다');
  }
  if (issueMethod != 'DOWNLOAD' && (issueStartsAt != null || issueEndsAt != null || visibleFrom != null)) {
    add(['issueStartsAt'], '받기 기간·노출 시작은 받기 쿠폰에만 둡니다');
  }
  if (truthy(issueStartsAt) && truthy(issueEndsAt) && jsDateParse(issueEndsAt!) <= jsDateParse(issueStartsAt!)) {
    add(['issueEndsAt'], '받기 종료 시각은 받기 시작 시각보다 뒤여야 합니다');
  }
  // 받기 기간은 사용 기간 안이다 — 넘으면 받는 순간 유효 기간이 지난 쿠폰을 준다
  if (truthy(endsAt) && truthy(issueEndsAt) && jsDateParse(issueEndsAt!) > jsDateParse(endsAt!)) {
    add(['issueEndsAt'], '받기 종료 시각은 사용 종료 시각보다 늦을 수 없습니다');
  }
  if (truthy(endsAt) && truthy(issueStartsAt) && jsDateParse(issueStartsAt!) >= jsDateParse(endsAt!)) {
    add(['issueStartsAt'], '받기 시작 시각은 사용 종료 시각보다 앞이어야 합니다');
  }
  return issues;
}

/// 쿠폰 등록 superRefine — 발급 방식과 코드·번호·한도·기간의 조합, 트리·혜택 규칙(couponRequestRuleIssues)을 검사한다
void _createCouponCheck(CreateCouponRequest body, ZodCheckContext ctx) {
  void issue(String path, String message) => ctx.addIssue(message, path: [path]);
  final issueMethod = body.issueMethod;
  final hasCode = truthy(body.code);
  if (issueMethod == 'CODE' && !hasCode) issue('code', '코드 입력형 쿠폰은 코드가 필요합니다');
  if (body.reward != null && body.benefit != null) issue('benefit', '확장 혜택(reward)을 주면 benefit을 생략합니다');
  if (issueMethod == 'VOUCHER' && body.voucher == null) issue('voucher', '쿠폰 번호 쿠폰은 번호 설정이 필요합니다');
  if (issueMethod != 'VOUCHER' && body.voucher != null) issue('voucher', '번호 설정은 쿠폰 번호 쿠폰에만 둡니다');
  if (issueMethod != 'CODE' && hasCode) issue('code', '코드는 코드 입력형 쿠폰에만 둡니다');
  if (issueMethod == 'CODE' && body.validDaysAfterIssue != null) {
    issue('validDaysAfterIssue', '발급 후 유효 일수는 셀러 지급 쿠폰에만 둡니다');
  }
  if (issueMethod == 'CODE' && body.perMemberIssueLimit != null) {
    issue('perMemberIssueLimit', '1인 발급 수 한도는 발급형 쿠폰에만 둡니다');
  }
  if (issueMethod == 'SIGNUP' && body.perMemberIssueLimit != null && body.perMemberIssueLimit != 1) {
    issue('perMemberIssueLimit', '회원가입 쿠폰은 1인 1장입니다');
  }
  if (issueMethod != 'CODE' && body.perMemberUseLimit != null) {
    issue('perMemberUseLimit', '발급형 쿠폰은 발급 한 장이 한 번 쓰입니다. 1인 발급 수 한도를 사용하십시오');
  }
  final memberOnly = body.conditions?.memberOnly ?? COUPON_CONDITIONS_DEFAULTS['memberOnly'] as bool;
  if (!memberOnly && (issueMethod != 'CODE' || body.perMemberUseLimit != null)) {
    issue('conditions', '비회원에게 여는 쿠폰은 코드 입력형이면서 1인 사용 한도가 없어야 합니다');
  }
  final startsAt = body.startsAt;
  final endsAt = body.endsAt;
  if (truthy(startsAt) && truthy(endsAt) && jsDateParse(endsAt!) <= jsDateParse(startsAt!)) {
    issue('endsAt', '종료 시각은 시작 시각보다 뒤여야 합니다');
  }
  for (final found in couponRequestRuleIssues(
    kind: body.kind,
    issueMethod: issueMethod,
    conditions: body.conditions,
    target: body.target,
    eligibility: body.eligibility,
    targetRules: body.targetRules,
    targetTree: body.targetTree,
    audience: body.audience,
    stacking: body.stacking,
    reward: body.reward,
    benefit: body.benefit,
    perMemberUseLimit: body.perMemberUseLimit,
    dailyIssueLimit: body.dailyIssueLimit,
    issueStartsAt: body.issueStartsAt,
    issueEndsAt: body.issueEndsAt,
    visibleFrom: body.visibleFrom,
    endsAt: endsAt,
  )) {
    ctx.addIssue(found.message, path: [for (final p in found.path) p!]);
  }
}
