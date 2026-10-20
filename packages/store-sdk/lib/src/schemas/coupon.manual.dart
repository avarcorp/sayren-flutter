// 손으로 쓴 부분 — coupon.ts의 함수·zod 클로저 구현.
part of 'coupon.dart';

/// 쿠폰 코드를 정규화합니다. 대문자로 바꾸고 앞뒤 공백을 지웁니다. 입력·저장·조회가 같은 함수를 씁니다.
String normalizeCouponCode(String code) => code.trim().toUpperCase();

/// 쿠폰 등록 superRefine — 발급 방식과 코드·한도·기간의 조합을 검사한다
void _createCouponCheck(CreateCouponRequest body, ZodCheckContext ctx) {
  final j = jsonOf(body);
  void issue(String path, String message) => ctx.addIssue(message, path: [path]);
  final issueMethod = j['issueMethod'];
  final hasCode = truthy(j['code']);
  if (issueMethod == 'CODE' && !hasCode) issue('code', '코드 입력형 쿠폰은 코드가 필요합니다');
  if (issueMethod != 'CODE' && hasCode) issue('code', '코드는 코드 입력형 쿠폰에만 둡니다');
  if (issueMethod == 'CODE' && j['validDaysAfterIssue'] != null) {
    issue('validDaysAfterIssue', '발급 후 유효 일수는 셀러 지급 쿠폰에만 둡니다');
  }
  if (issueMethod == 'CODE' && j['perMemberIssueLimit'] != null) {
    issue('perMemberIssueLimit', '1인 발급 수 한도는 발급형 쿠폰에만 둡니다');
  }
  if (issueMethod == 'SIGNUP' && j['perMemberIssueLimit'] != null && j['perMemberIssueLimit'] != 1) {
    issue('perMemberIssueLimit', '회원가입 쿠폰은 1인 1장입니다');
  }
  if (issueMethod != 'CODE' && j['perMemberUseLimit'] != null) {
    issue('perMemberUseLimit', '발급형 쿠폰은 발급 한 장이 한 번 쓰입니다. 1인 발급 수 한도를 사용하십시오');
  }
  final conditions = j['conditions'];
  final memberOnly =
      (conditions == null ? null : jsMap(conditions)['memberOnly']) ?? COUPON_CONDITIONS_DEFAULTS['memberOnly'];
  if (!truthy(memberOnly) && (issueMethod != 'CODE' || j['perMemberUseLimit'] != null)) {
    issue('conditions', '비회원에게 여는 쿠폰은 코드 입력형이면서 1인 사용 한도가 없어야 합니다');
  }
  final startsAt = j['startsAt'];
  final endsAt = j['endsAt'];
  if (truthy(startsAt) && truthy(endsAt) && jsDateParse(endsAt as String) <= jsDateParse(startsAt as String)) {
    issue('endsAt', '종료 시각은 시작 시각보다 뒤여야 합니다');
  }
}
