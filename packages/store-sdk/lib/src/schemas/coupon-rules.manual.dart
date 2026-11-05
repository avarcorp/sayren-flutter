// 손으로 쓴 부분 — coupon-rules.ts의 사실 값·필드 카탈로그·옛 칸 변환·평가·검증·한국어 문구.
part of 'coupon-rules.dart';

// 시각은 Asia/Seoul(COUPON_TIME_ZONE)이다. 한국은 일광 절약 시간이 없어 UTC+9 고정으로 계산한다(Dart에는 시간대 데이터가 없다)
const _seoulOffset = Duration(hours: 9);

/// BCP 47 정규형을 돌려줍니다(`ko-kr` → `ko-KR`). 사실 값과 규칙 값이 같은 표기여야 목록 비교가 맞습니다. 읽지 못하면 null입니다.
///
/// JS `Intl.getCanonicalLocales`처럼 대소문자를 맞춥니다(언어 소문자, 문자 첫 글자 대문자, 지역 대문자, 확장 소문자).
/// 옛 언어 코드 별칭(`iw` → `he` 등)은 바꾸지 않습니다.
String? canonicalLocale(String? tag) {
  if (tag == null || tag.isEmpty || !jsIsLocaleTag(tag)) return null;
  final parts = tag.toLowerCase().split('-');
  var extension = false;
  for (var i = 1; i < parts.length; i++) {
    final part = parts[i];
    if (part.length == 1) extension = true;
    if (extension) continue;
    if (part.length == 4 && RegExp(r'^[a-z]{4}$').hasMatch(part)) {
      parts[i] = '${part[0].toUpperCase()}${part.substring(1)}';
    } else if (part.length == 2) {
      parts[i] = part.toUpperCase();
    }
  }
  return parts.join('-');
}

/// 클레임 원본으로 사실 값을 만듭니다. [now]는 판정 시각입니다(생일 달·만 나이는 한국 날짜).
CouponClaimFacts couponClaimFactsOf(
  ({
    String? gender,
    String? birthdate,
    bool? email_verified,
    bool? phone_number_verified,
    String? locale,
    String? addressCountry,
  }) claims,
  DateTime now,
) {
  final locale = canonicalLocale(claims.locale);
  return CouponClaimFacts(
    gender: claims.gender == null || claims.gender!.isEmpty ? null : claims.gender,
    birthdate: birthdateFactOf(claims.birthdate, couponTodayAt(now)),
    email_verified: claims.email_verified,
    phone_number_verified: claims.phone_number_verified,
    locale: locale == null ? null : {locale, locale.split('-')[0]}.toList(),
    addressCountry:
        claims.addressCountry == null || claims.addressCountry!.isEmpty ? null : claims.addressCountry!.toUpperCase(),
  );
}

DateTime _seoulAt(DateTime now) => now.toUtc().add(_seoulOffset);

/// 판정 시각의 한국 날짜를 돌려줍니다.
({int year, int month, int day}) couponTodayAt(DateTime now) {
  final at = _seoulAt(now);
  return (year: at.year, month: at.month, day: at.day);
}

/// 판정 시각의 요일·시각(Asia/Seoul)을 돌려줍니다.
CouponTimeFacts couponTimeFactsAt(DateTime now) {
  final at = _seoulAt(now);
  String two(int n) => n.toString().padLeft(2, '0');
  return CouponTimeFacts(weekday: COUPON_WEEKDAYS[at.weekday - 1], timeOfDay: '${two(at.hour)}:${two(at.minute)}');
}

/// JS `Date.parse` — 날짜만 쓴 형식(`YYYY-MM-DD`)은 JS처럼 UTC 자정으로 읽는다
double _parseTime(String value) =>
    jsDateParse(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ? '${value}T00:00:00Z' : value);

/// 두 시각 사이의 지난 날 수(내림)를 돌려줍니다. [from]은 ISO 문자열이나 [DateTime]입니다. 읽지 못하면 null입니다.
int? daysBetween(Object? from, DateTime to) {
  if (from == null || from == '') return null;
  final double start;
  if (from is String) {
    start = _parseTime(from);
  } else if (from is DateTime) {
    start = from.millisecondsSinceEpoch.toDouble();
  } else {
    return null;
  }
  if (start.isNaN) return null;
  final days = ((to.millisecondsSinceEpoch - start) / 86400000).floor();
  return days < 0 ? 0 : days;
}

/// 줄 금액에서 줄 컨텍스트를 만듭니다. [categoryPath]는 `/조상/…/자신/`입니다.
CouponLineContext couponLineContextOf({
  required String productId,
  String? categoryPath,
  required int quantity,
  required int baseAmount,
  required int amount,
}) =>
    CouponLineContext(
      productId: productId,
      categoryIds: categoryPath == null || categoryPath.isEmpty
          ? const []
          : categoryPath.split('/').where((s) => s.isNotEmpty).toList(),
      hasInstantDiscount: amount < baseAmount,
      unitPrice: quantity > 0 ? (amount / quantity).floor() : amount,
    );

const _moneyMax = 1000000000000;
const _dayMax = 36500;
const _countMax = 1000000;

final _orderFields = <ConditionFieldDef<CouponOrderContext>>[
  ConditionFieldDef(
    name: 'customer.daysSinceJoined',
    type: 'integer',
    min: 0,
    max: _dayMax,
    resolve: (ctx) => ctx.facts.customer?.daysSinceJoined,
  ),
  ConditionFieldDef(
    name: 'customer.marketingAgreed',
    type: 'boolean',
    resolve: (ctx) => ctx.facts.customer?.marketingAgreed,
  ),
  ConditionFieldDef(
    name: 'customer.paidOrderCount',
    type: 'integer',
    min: 0,
    max: _countMax,
    resolve: (ctx) => ctx.facts.customer?.paidOrderCount,
  ),
  ConditionFieldDef(
    name: 'customer.daysSinceLastOrder',
    type: 'integer',
    min: 0,
    max: _dayMax,
    resolve: (ctx) => ctx.facts.customer?.daysSinceLastOrder,
  ),
  ConditionFieldDef(
    name: 'claims.gender',
    type: 'enumSet',
    options: const ['female', 'male'],
    resolve: (ctx) => ctx.facts.customer?.claims?.gender,
  ),
  ConditionFieldDef(
    name: 'claims.birthdate',
    type: 'birthdate',
    resolve: (ctx) => ctx.facts.customer?.claims?.birthdate,
  ),
  ConditionFieldDef(
    name: 'claims.email_verified',
    type: 'boolean',
    resolve: (ctx) => ctx.facts.customer?.claims?.email_verified,
  ),
  ConditionFieldDef(
    name: 'claims.phone_number_verified',
    type: 'boolean',
    resolve: (ctx) => ctx.facts.customer?.claims?.phone_number_verified,
  ),
  ConditionFieldDef(
    name: 'claims.locale',
    type: 'idSet',
    resolve: (ctx) => ctx.facts.customer?.claims?.locale,
  ),
  ConditionFieldDef(
    name: 'claims.address.country',
    type: 'idSet',
    resolve: (ctx) => ctx.facts.customer?.claims?.addressCountry,
  ),
  ConditionFieldDef(
    name: 'cart.subtotal',
    type: 'integer',
    operators: const ['>=', '<=', 'between'],
    min: 0,
    max: _moneyMax,
    resolve: (ctx) => ctx.cart?.subtotal,
  ),
  ConditionFieldDef(
    name: 'cart.targetSubtotal',
    type: 'integer',
    operators: const ['>=', '<=', 'between'],
    min: 0,
    max: _moneyMax,
    resolve: (ctx) => ctx.cart?.targetSubtotal,
  ),
  ConditionFieldDef(
    name: 'cart.targetQuantity',
    type: 'integer',
    operators: const ['>=', '<=', 'between'],
    min: 0,
    max: _countMax,
    resolve: (ctx) => ctx.cart?.targetQuantity,
  ),
  ConditionFieldDef(
    name: 'time.weekday',
    type: 'enumSet',
    options: COUPON_WEEKDAYS,
    resolve: (ctx) => ctx.facts.time?.weekday,
  ),
  ConditionFieldDef(
    name: 'time.timeOfDay',
    type: 'timeRange',
    resolve: (ctx) => ctx.facts.time?.timeOfDay,
  ),
];

final _lineFields = <ConditionFieldDef<CouponLineContext>>[
  ConditionFieldDef(name: 'line.productId', type: 'idSet', resolve: (ctx) => ctx.productId),
  ConditionFieldDef(name: 'line.categoryId', type: 'idSet', resolve: (ctx) => ctx.categoryIds),
  ConditionFieldDef(name: 'line.hasInstantDiscount', type: 'boolean', resolve: (ctx) => ctx.hasInstantDiscount),
  ConditionFieldDef(
    name: 'line.unitPrice',
    type: 'integer',
    operators: const ['>=', '<=', 'between'],
    min: 0,
    max: _moneyMax,
    resolve: (ctx) => ctx.unitPrice,
  ),
];

/// 사용 조건·발급 대상 트리의 필드 카탈로그(구매자·주문서·시각)입니다.
final ConditionCatalog<CouponOrderContext> COUPON_ORDER_CONDITIONS = conditionCatalog(_orderFields);

/// 할인 대상 트리의 필드 카탈로그(주문서 줄)입니다.
final ConditionCatalog<CouponLineContext> COUPON_LINE_CONDITIONS = conditionCatalog(_lineFields);

/// 필드 이름 → 화면·문서용 필드 정보(자리·단위) — 원천은 COUPON_CONDITION_FIELDS다
final Map<String, Map<String, Object?>> _fieldInfo = {
  for (final field in COUPON_CONDITION_FIELDS) field['name'] as String: field,
};

final _emptyGroup = ConditionGroup(combinator: 'and', rules: const []);

/// 규칙 목록의 정규형을 만듭니다.
CouponTargetRules canonicalizeCouponTargetRules(CouponTargetRules rules) => CouponTargetRules(
      include: rules.include.map(canonicalizeConditionRule).toList(),
      exclude: rules.exclude.map(canonicalizeConditionRule).toList(),
    );

/// 규칙 1개 이하 그룹은 결합어를 `or`로 고정하고, 규칙 없는 하위 그룹은 뺀다(빈 그룹은 참이라 남기면 뜻이 바뀐다)
ConditionGroup _canonicalTargetGroup(ConditionGroup group) {
  final rules = <ConditionNode>[];
  for (final node in group.rules) {
    if (node is! ConditionGroup) {
      rules.add(canonicalizeConditionRule(node as ConditionRule));
      continue;
    }
    final child = _canonicalTargetGroup(node);
    if (child.rules.isNotEmpty) rules.add(child);
  }
  return ConditionGroup(combinator: rules.length <= 1 ? 'or' : group.combinator, rules: rules);
}

/// 할인 대상 트리의 정규형을 만듭니다. 저장·잠금 비교·승인 비교·스냅샷이 같은 함수입니다.
///
/// 규칙 1개 이하 그룹은 결합어를 `or`로 고정하고, 규칙 없는 하위 그룹은 뺍니다.
CouponTargetTree canonicalizeCouponTargetTree(CouponTargetTree tree) =>
    CouponTargetTree(include: _canonicalTargetGroup(tree.include), exclude: _canonicalTargetGroup(tree.exclude));

/// 옛 평평한 목록을 트리로 바꿉니다. 「하나라도」가 그대로 `or` 그룹입니다(같은 줄 판정).
CouponTargetTree couponTargetTreeFromRules(CouponTargetRules rules) => CouponTargetTree(
      include: ConditionGroup(combinator: 'or', rules: rules.include),
      exclude: ConditionGroup(combinator: 'or', rules: rules.exclude),
    );

/// 그룹이 평평한 「하나라도」 목록으로 같은 뜻인가 — 하위 그룹이 없고 `or`이거나 규칙이 1개 이하
List<ConditionRule>? _flatRulesOf(ConditionGroup group) {
  final rules = group.rules;
  if (rules.any(isConditionGroup)) return null;
  if (group.combinator == 'and' && rules.length > 1) return null;
  return rules.cast<ConditionRule>();
}

/// 트리를 옛 평평한 목록으로 바꿉니다.
///
/// 같은 뜻으로 옮길 수 없으면(`모두`에 규칙 2개 이상, 하위 그룹) `rulesOnly`가 true이고 목록은 그룹 최상위 규칙을 평평하게 모은 가장 가까운 값입니다.
({CouponTargetRules targetRules, bool rulesOnly}) couponTargetRulesFromTree(CouponTargetTree tree) {
  final include = _flatRulesOf(tree.include);
  final exclude = _flatRulesOf(tree.exclude);
  List<ConditionRule> top(ConditionGroup group) => group.rules.whereType<ConditionRule>().toList();
  return (
    targetRules: CouponTargetRules(include: include ?? top(tree.include), exclude: exclude ?? top(tree.exclude)),
    rulesOnly: include == null || exclude == null,
  );
}

/// 중복 사용 정책의 정규형을 만듭니다(키 순서 고정, 모르는 키 제거).
CouponStacking canonicalizeCouponStacking(CouponStacking stacking) => CouponStacking(
      combinesWith: CouponStackingCombinesWith(
        order: stacking.combinesWith.order,
        product: stacking.combinesWith.product,
        delivery: stacking.combinesWith.delivery,
      ),
      withPoints: stacking.withPoints,
      perOrderLimit: stacking.perOrderLimit,
    );

/// 묶음의 할인 대상 트리를 돌려줍니다. 트리가 없으면 옛 목록에서 만듭니다(읽기 한 경로).
CouponTargetTree couponTargetTreeOf(CouponRuleTrees trees) =>
    trees.targetTree ?? couponTargetTreeFromRules(trees.targetRules);

List<ConditionRule> _inRule(String field, List<String> ids) {
  if (ids.isEmpty) return const [];
  final sorted = ids.toSet().toList()..sort();
  return [ConditionRule(field: field, operator: 'in', value: sorted)];
}

/// 옛 칸을 트리로 바꿉니다. 계산이 트리 한 경로를 지나게 하는 변환입니다.
///
/// 최소 주문 금액 = 대상 상품 금액 이상, 첫 구매 = 결제 완료 주문 수 0, 즉시할인 중복 불가 = 즉시할인 줄 제외,
/// 포함 목록이 모두 비면 전 상품, 제외가 포함보다 우선입니다. `memberOnly`는 트리 밖입니다.
CouponRuleTrees couponRulesFromLegacy(LegacyCouponConditions conditions, LegacyCouponTarget target) {
  final eligibility = <ConditionNode>[
    if (conditions.firstOrderOnly) ConditionRule(field: 'customer.paidOrderCount', operator: '=', value: 0),
    if (conditions.minOrderAmount > 0)
      ConditionRule(field: 'cart.targetSubtotal', operator: '>=', value: conditions.minOrderAmount),
  ];
  return CouponRuleTrees(
    eligibility: ConditionGroup(combinator: 'and', rules: eligibility),
    targetRules: CouponTargetRules(
      include: [
        ..._inRule('line.productId', target.includeProductIds),
        ..._inRule('line.categoryId', target.includeCategoryIds),
      ],
      exclude: [
        ..._inRule('line.productId', target.excludeProductIds),
        ..._inRule('line.categoryId', target.excludeCategoryIds),
        if (!conditions.stackWithInstantDiscount)
          ConditionRule(field: 'line.hasInstantDiscount', operator: '=', value: true),
      ],
    ),
  );
}

bool _isMinOrderRule(ConditionNode node) =>
    node is ConditionRule && node.field == 'cart.targetSubtotal' && node.operator == '>=' && node.value is num;

bool _isFirstOrderRule(ConditionNode node) =>
    node is ConditionRule && node.field == 'customer.paidOrderCount' && node.operator == '=' && node.value == 0;

bool _isInstantExcludeRule(ConditionRule rule) =>
    rule.field == 'line.hasInstantDiscount' && rule.operator == '=' && rule.value == true;

bool _instantExcluded(ConditionGroup exclude) =>
    (exclude.combinator == 'or' || exclude.rules.length <= 1) &&
    exclude.rules.any((node) => node is ConditionRule && _isInstantExcludeRule(node));

bool _isIdRule(ConditionRule rule) =>
    (rule.field == 'line.productId' || rule.field == 'line.categoryId') && rule.operator == 'in';

/// 트리를 옛 칸으로 바꿉니다. 옛 응답 필드(`conditions`·`target`)를 채우고 롤링 중 옛 코드가 읽게 합니다.
///
/// 옛 칸으로 표현되지 않는 규칙이 하나라도 있으면 `rulesOnly`가 true입니다(옛 칸은 가장 가까운 값).
({LegacyCouponConditions conditions, LegacyCouponTarget target, bool rulesOnly}) legacyFromCouponRules(
  CouponRuleTrees trees,
  bool memberOnly,
) {
  final top = trees.eligibility.combinator == 'and' || trees.eligibility.rules.length <= 1;
  final nodes = top ? trees.eligibility.rules : const <ConditionNode>[];
  final minRule = nodes.where(_isMinOrderRule).firstOrNull as ConditionRule?;
  final firstRule = nodes.where(_isFirstOrderRule).firstOrNull as ConditionRule?;
  List<String> ids(List<ConditionRule> rules, String field) {
    final out = <String>{
      for (final r in rules)
        if (r.field == field && r.operator == 'in' && r.value is List) ...(r.value as List).map((v) => v as String),
    }.toList()
      ..sort();
    return out;
  }

  final flat = couponTargetRulesFromTree(couponTargetTreeOf(trees));
  final include = flat.targetRules.include;
  final exclude = flat.targetRules.exclude;
  final mappedEligibility = nodes.where((n) => identical(n, minRule) || identical(n, firstRule)).length;
  final rulesOnly = flat.rulesOnly ||
      mappedEligibility != trees.eligibility.rules.length ||
      nodes.where(_isMinOrderRule).length > 1 ||
      include.any((r) => !_isIdRule(r)) ||
      exclude.any((r) => !_isIdRule(r) && !_isInstantExcludeRule(r));
  return (
    conditions: LegacyCouponConditions(
      minOrderAmount: minRule == null ? 0 : (minRule.value as num).toInt(),
      firstOrderOnly: firstRule != null,
      memberOnly: memberOnly,
      // 즉시할인 줄을 모두 빼는 것은 제외가 「하나 이상」(또는 규칙 하나)이고 즉시할인 규칙이 최상위에 있을 때뿐이다
      stackWithInstantDiscount: !_instantExcluded(couponTargetTreeOf(trees).exclude),
    ),
    target: LegacyCouponTarget(
      includeProductIds: ids(include, 'line.productId'),
      includeCategoryIds: ids(include, 'line.categoryId'),
      excludeProductIds: ids(exclude, 'line.productId'),
      excludeCategoryIds: ids(exclude, 'line.categoryId'),
    ),
    rulesOnly: rulesOnly,
  );
}

/// 줄이 대상인지입니다(트리). 제외가 포함보다 우선하고, 포함이 비면 전 상품, 제외가 비면 제외 없음입니다.
///
/// 계산(`quotePricing`·최대 조합·대상 상품 판정)은 모두 이 함수를 지납니다.
bool couponTargetTreeMatches(CouponTargetTree tree, CouponLineContext line) {
  final exclude = tree.exclude;
  if (exclude.rules.isNotEmpty && evaluateConditionNode(exclude, COUPON_LINE_CONDITIONS, line)) return false;
  return evaluateConditionNode(tree.include, COUPON_LINE_CONDITIONS, line);
}

/// 줄이 대상인지입니다(옛 평평한 목록). 트리로 바꿔 같은 판정 함수를 지납니다.
bool couponLineMatches(CouponTargetRules rules, CouponLineContext line) =>
    couponTargetTreeMatches(couponTargetTreeFromRules(rules), line);

bool _usesCart(ConditionNode node) => (node is ConditionGroup ? conditionFields(node) : {(node as ConditionRule).field})
    .any((f) => f.startsWith('cart.'));

/// 사용 조건을 평가합니다. 통과하면 null, 아니면 실패 사유입니다. 두 단계로 부릅니다.
///
/// - `beforeLines`: 대상 줄을 가리기 전 — 최상위 `and`의 주문서 집계를 쓰지 않는 규칙만 봅니다.
/// - `afterLines`: 주문서 집계를 넣어 나머지 — 최상위 `and`면 주문서 집계 규칙만, `or`면 트리 전체를 봅니다.
CouponConditionRejectReason? evaluateCouponEligibility(
  ConditionGroup eligibility,
  CouponOrderContext ctx,
  String phase,
) {
  final topAnd = eligibility.combinator == 'and' || eligibility.rules.length <= 1;
  if (topAnd) {
    final part = ConditionGroup(
      combinator: 'and',
      rules: eligibility.rules.where((node) => phase == 'beforeLines' ? !_usesCart(node) : _usesCart(node)).toList(),
    );
    return _reasonOf(evaluateCondition(part, COUPON_ORDER_CONDITIONS, ctx).failed, true);
  }
  if (phase == 'beforeLines') return null;
  return evaluateCondition(eligibility, COUPON_ORDER_CONDITIONS, ctx).passed ? null : 'CONDITION_NOT_MET';
}

/// 사실 값이 없는 구매자·시각 규칙을 참으로 바꾼 트리를 돌려줍니다. **환불 정산 전용입니다.**
///
/// 결제 시작에서 그 규칙을 통과했으므로 주문서 집계 규칙만 남은 금액으로 다시 판정하게 합니다. 참은 빈 `and` 그룹입니다.
ConditionGroup assumeCouponFactRules(ConditionGroup group, CouponFacts facts) {
  bool known(String field) {
    if (field.startsWith('customer.')) {
      return facts.customer?.toJson()[field.substring('customer.'.length)] != null;
    }
    if (field.startsWith('claims.')) return facts.customer?.claims != null;
    if (field.startsWith('time.')) return facts.time != null;
    return true;
  }

  return ConditionGroup(
    combinator: group.combinator,
    rules: [
      for (final node in group.rules)
        node is ConditionGroup
            ? assumeCouponFactRules(node, facts)
            : known((node as ConditionRule).field)
                ? node
                : _emptyGroup,
    ],
  );
}

CouponConditionRejectReason? _reasonOf(List<ConditionNode> failed, bool topAnd) {
  if (failed.isEmpty) return null;
  final first = failed.first;
  if (!topAnd) return 'CONDITION_NOT_MET';
  if (_isFirstOrderRule(first)) return 'FIRST_ORDER_ONLY';
  if (_isMinOrderRule(first)) return 'MIN_ORDER_AMOUNT';
  return 'CONDITION_NOT_MET';
}

/// 발급 대상을 평가합니다. 구매자 사실 값만 봅니다. 빈 트리는 모두 대상입니다.
bool couponAudienceMatches(ConditionGroup audience, CouponFacts facts) =>
    evaluateCondition(audience, COUPON_ORDER_CONDITIONS, CouponOrderContext(facts: facts)).passed;

/// 트리들에 나온 구매자 사실 값 이름(`daysSinceJoined` 등, 클레임은 `claims` 한 묶음)을 돌려줍니다. 서버가 필요한 값만 읽습니다.
Set<String> couponCustomerFactNames(List<ConditionGroup> groups) {
  final names = <String>{};
  for (final group in groups) {
    for (final field in conditionFields(group)) {
      if (field.startsWith('customer.')) names.add(field.substring('customer.'.length));
      // 클레임은 한 묶음으로 읽는다(회원 행 + 기본 배송지)
      if (field.startsWith('claims.')) names.add('claims');
    }
  }
  return names;
}

/// 사실 값 중 트리가 쓰는 것만 남깁니다. 스냅샷에 굳히는 값입니다(클레임은 굳히지 않습니다).
CouponFacts pickCouponFacts(CouponFacts facts, ConditionGroup eligibility) {
  final fields = conditionFields(eligibility);
  final names = couponCustomerFactNames([eligibility]);
  final source = facts.customer;
  // 클레임은 굳히지 않는다 — 환불 재판정은 없는 사실을 통과로 본다(assumeCouponFactRules)
  final customer = CouponCustomerFacts(
    daysSinceJoined: names.contains('daysSinceJoined') ? source?.daysSinceJoined : null,
    marketingAgreed: names.contains('marketingAgreed') ? source?.marketingAgreed : null,
    paidOrderCount: names.contains('paidOrderCount') ? source?.paidOrderCount : null,
    daysSinceLastOrder: names.contains('daysSinceLastOrder') ? source?.daysSinceLastOrder : null,
  );
  final time = facts.time;
  return CouponFacts(
    customer: customer.toJson().isEmpty ? null : customer,
    time: time != null && fields.any((f) => f.startsWith('time.')) ? time : null,
  );
}

const _issueMessages = <String, String>{
  'DEPTH': '조건 그룹은 3단까지 둘 수 있습니다',
  'TOO_MANY_RULES': '조건은 50개까지 둘 수 있습니다',
  'UNKNOWN_FIELD': '알 수 없는 조건 필드입니다',
  'FIELD_NOT_ALLOWED': '이 자리에 쓸 수 없는 조건 필드입니다',
  'OPERATOR': '이 필드에 쓸 수 없는 연산자입니다',
  'VALUE': '조건 값이 올바르지 않습니다',
};

bool Function(String field) _allowedIn(String slot) =>
    (field) => (_fieldInfo[field]?['slots'] as List?)?.contains(slot) ?? false;

/// 쿠폰 규칙을 검증합니다. 관리 API 요청 스키마의 `superRefine`이 부릅니다(검증 원천 하나).
///
/// 트리 형식·필드 자리에 더해 쿠폰 칸과 엮인 규칙을 봅니다.
/// - 비회원에게 여는 쿠폰은 구매자 조건(`customer.*`)을 쓸 수 없습니다(비회원은 사실 값이 없습니다).
/// - 코드형 쿠폰이 결제 완료 주문 수를 쓰면 1인 사용 한도가 필요합니다.
/// - 회원가입 쿠폰의 발급 대상에는 가입 경과 일수를 쓸 수 없습니다(가입 순간 늘 0).
List<CouponRuleIssue> couponRuleIssues({
  required bool memberOnly,
  required String issueMethod,
  int? perMemberUseLimit,
  ConditionGroup? eligibility,
  CouponTargetRules? targetRules,
  CouponTargetTree? targetTree,
  ConditionGroup? audience,
}) {
  final issues = <CouponRuleIssue>[];
  void push(List<Object?> base, List<ConditionIssue> list) {
    for (final issue in list) {
      // 다른 자리의 필드(줄 필드를 사용 조건에)는 「모르는 필드」가 아니라 「이 자리에 못 쓰는 필드」다
      final code = issue.code == 'UNKNOWN_FIELD' && issue.field != null && _fieldInfo.containsKey(issue.field)
          ? 'FIELD_NOT_ALLOWED'
          : issue.code;
      issues.add(CouponRuleIssue(path: [...base, ...issue.path], message: _issueMessages[code]!));
    }
  }

  if (eligibility != null) {
    push(['eligibility'], conditionIssues(eligibility, COUPON_ORDER_CONDITIONS, allowed: _allowedIn('eligibility')));
  }
  if (audience != null) {
    if (issueMethod == 'CODE' && audience.rules.isNotEmpty) {
      issues.add(const CouponRuleIssue(path: ['audience'], message: '코드 입력형 쿠폰에는 발급 대상을 둘 수 없습니다'));
    }
    push(['audience'], conditionIssues(audience, COUPON_ORDER_CONDITIONS, allowed: _allowedIn('audience')));
  }
  if (targetTree != null) {
    push(['targetTree', 'include'],
        conditionIssues(targetTree.include, COUPON_LINE_CONDITIONS, allowed: _allowedIn('target')));
    push(['targetTree', 'exclude'],
        conditionIssues(targetTree.exclude, COUPON_LINE_CONDITIONS, allowed: _allowedIn('target')));
  } else if (targetRules != null) {
    push(
        ['targetRules', 'include'],
        conditionIssues(ConditionGroup(combinator: 'or', rules: targetRules.include), COUPON_LINE_CONDITIONS,
            allowed: _allowedIn('target')));
    push(
        ['targetRules', 'exclude'],
        conditionIssues(ConditionGroup(combinator: 'or', rules: targetRules.exclude), COUPON_LINE_CONDITIONS,
            allowed: _allowedIn('target')));
  }
  final slots = <String, ConditionGroup?>{'eligibility': eligibility, 'audience': audience};
  if (!memberOnly) {
    for (final slot in slots.keys) {
      if (couponCustomerFactNames([slots[slot] ?? _emptyGroup]).isNotEmpty) {
        issues.add(CouponRuleIssue(path: [slot], message: '비회원에게 여는 쿠폰에는 구매자 조건을 둘 수 없습니다'));
      }
    }
  }
  if (issueMethod == 'CODE' &&
      couponCustomerFactNames([eligibility ?? _emptyGroup]).contains('paidOrderCount') &&
      perMemberUseLimit == null) {
    issues.add(const CouponRuleIssue(
      path: ['perMemberUseLimit'],
      message: '결제 완료 주문 수 조건이 있는 코드 입력형 쿠폰은 1인 사용 한도가 필요합니다',
    ));
  }
  // 클레임 목록 값은 사실 값과 같은 표기만 받는다 — 국가는 대문자 두 자, 언어 태그는 BCP 47 정규형(`ko-KR`, 앞부분은 `ko`)
  final country = RegExp(r'^[A-Z]{2}$');
  for (final slot in slots.keys) {
    void walk(ConditionGroup group, List<Object?> path) {
      final rules = group.rules;
      for (var index = 0; index < rules.length; index++) {
        final node = rules[index];
        final at = [...path, 'rules', index];
        if (node is ConditionGroup) {
          walk(node, at);
          continue;
        }
        final rule = node as ConditionRule;
        final values = rule.value;
        if (values is! List) continue;
        if (rule.field == 'claims.address.country' && !values.every((v) => v is String && country.hasMatch(v))) {
          issues.add(CouponRuleIssue(path: [...at, 'value'], message: '국가는 대문자 두 자 코드(예: KR)입니다'));
        }
        if (rule.field == 'claims.locale' && !values.every((v) => v is String && canonicalLocale(v) == v)) {
          issues.add(CouponRuleIssue(path: [...at, 'value'], message: '언어 태그는 정규 표기(예: ko, ko-KR)입니다'));
        }
      }
    }

    final group = slots[slot];
    if (group != null) walk(group, [slot]);
  }
  if (issueMethod == 'SIGNUP' && couponCustomerFactNames([audience ?? _emptyGroup]).contains('daysSinceJoined')) {
    issues.add(const CouponRuleIssue(path: ['audience'], message: '회원가입 쿠폰의 발급 대상에는 가입 경과 일수를 둘 수 없습니다'));
  }
  return issues;
}

/// 트리 묶음의 정규형을 만듭니다.
CouponRuleTrees canonicalizeCouponTrees(CouponRuleTrees trees) {
  final eligibility = canonicalizeConditionGroup(trees.eligibility);
  final tree = trees.targetTree;
  if (tree == null) {
    return CouponRuleTrees(eligibility: eligibility, targetRules: canonicalizeCouponTargetRules(trees.targetRules));
  }
  final targetTree = canonicalizeCouponTargetTree(tree);
  return CouponRuleTrees(
    eligibility: eligibility,
    targetRules: canonicalizeCouponTargetRules(couponTargetRulesFromTree(targetTree).targetRules),
    targetTree: targetTree,
  );
}

const _weekdayLabels = <String, String>{
  'MON': '월',
  'TUE': '화',
  'WED': '수',
  'THU': '목',
  'FRI': '금',
  'SAT': '토',
  'SUN': '일',
};

const _fieldLabels = <String, String>{
  'customer.daysSinceJoined': '가입',
  'customer.paidOrderCount': '구매',
  'customer.daysSinceLastOrder': '마지막 구매',
  'cart.subtotal': '주문 금액',
  'cart.targetSubtotal': '대상 상품',
  'cart.targetQuantity': '대상 상품',
  'line.unitPrice': '판매가',
};

const _genderLabels = <String, String>{'female': '여성', 'male': '남성'};

/// JS `Number(value)`(문구용) — 숫자·null·참거짓·숫자 문자열만 읽고 나머지는 NaN
num _toNumber(Object? value) {
  if (value is num) return value;
  if (value == null) return 0;
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? 0 : (num.tryParse(t) ?? double.nan);
  }
  return double.nan;
}

/// JS `String(value)` — 정수 값 double은 소수점 없이, 값 없음(`absent`)은 `undefined`
String _text(Object? value) {
  if (identical(value, absent)) return 'undefined';
  if (value is double && value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21) {
    return value.toInt().toString();
  }
  return '$value';
}

/// JS `Array.prototype.join` — null은 빈 문자열
String _join(List<Object?> values, String separator) => values.map((v) => v == null ? '' : _text(v)).join(separator);

Object? _at(Object? list, int index) => list is List && index < list.length ? list[index] : absent;

/// `Intl.NumberFormat("ko-KR").format(n)` — 세 자리 쉼표, 소수는 셋째 자리까지(반올림)
String _formatNumber(num n) {
  if (n.isNaN) return 'NaN';
  if (n.isInfinite) return n > 0 ? '∞' : '-∞';
  final negative = n < 0;
  var text = n.abs().toStringAsFixed(n is int ? 0 : 3);
  if (text.contains('.')) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  final dot = text.indexOf('.');
  final whole = dot < 0 ? text : text.substring(0, dot);
  final fraction = dot < 0 ? '' : text.substring(dot);
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final out = '$grouped$fraction';
  return negative && out != '0' ? '-$out' : out;
}

String _defaultMoney(num minor) => '${_formatNumber(minor)}원';

String _amountText(String field, Object? value, String Function(num minor) formatMoney) {
  final n = _toNumber(identical(value, absent) ? double.nan : value);
  final unit = _fieldInfo[field]?['unit'];
  if (unit == 'money') return formatMoney(n);
  if (unit == 'day') return '${_formatNumber(n)}일';
  if (unit == 'count') return '${_formatNumber(n)}회';
  if (unit == 'quantity') return '${_formatNumber(n)}개';
  return _formatNumber(n);
}

/// 규칙 한 개의 문구를 돌려줍니다(「가입 30일 이상」 「대상 상품 50,000원 이상」 「첫 구매」).
///
/// [formatMoney]는 금액(쿠폰 통화 최소 단위)을 글자로 바꿉니다. 생략하면 「50,000원」 형식입니다.
String describeCouponRule(ConditionRule rule, [String Function(num minor)? formatMoney]) {
  final money = formatMoney ?? _defaultMoney;
  if (_isFirstOrderRule(rule)) return '첫 구매';
  final label = _fieldLabels[rule.field] ?? rule.field;
  final value = rule.value;
  switch (rule.field) {
    case 'customer.marketingAgreed':
      return truthy(value) ? '마케팅 수신 동의' : '마케팅 수신 미동의';
    case 'line.productId':
      return '상품 ${_formatNumber((value as List).length)}개';
    case 'line.categoryId':
      return '카테고리 ${_formatNumber((value as List).length)}개';
    case 'line.hasInstantDiscount':
      return truthy(value) ? '즉시할인 상품' : '즉시할인 없는 상품';
    case 'time.weekday':
      return '${_join([for (final d in value as List) _weekdayLabels[d] ?? d], '·')}요일';
    case 'time.timeOfDay':
      return '${_text(_at(value, 0))}~${_text(_at(value, 1))}';
    case 'claims.gender':
      return _join([for (final g in value as List) _genderLabels[g] ?? g], '·');
    case 'claims.email_verified':
      return truthy(value) ? '이메일 확인 회원' : '이메일 미확인 회원';
    case 'claims.phone_number_verified':
      return truthy(value) ? '휴대폰 확인 회원' : '휴대폰 미확인 회원';
    case 'claims.locale':
      return '언어 ${_join(value as List, '·')}';
    case 'claims.address.country':
      return '국가 ${_join(value as List, '·')}';
    case 'claims.birthdate':
      return _describeBirthdateRule(rule);
  }
  String text(Object? v) => _amountText(rule.field, v, money);
  if (rule.operator == 'between') return '$label ${text(_at(value, 0))}~${text(_at(value, 1))}';
  final suffix = rule.operator == '>='
      ? ' 이상'
      : rule.operator == '<='
          ? ' 이하'
          : '';
  if (rule.field == 'customer.paidOrderCount' && rule.operator == '=') return '$label ${text(value)}';
  return '$label ${text(value)}$suffix';
}

String _describeBirthdateRule(ConditionRule rule) {
  final value = rule.value;
  switch (rule.operator) {
    case 'ageBetween':
      return '만 ${_text(_at(value, 0))}~${_text(_at(value, 1))}세';
    case 'age>=':
      return '만 ${_text(value)}세 이상';
    case 'age<=':
      return '만 ${_text(value)}세 이하';
    case 'birthMonthIn':
      return '생일 ${_join(value as List, '·')}월';
    case 'birthMonthIsCurrent':
      return '생일 달';
    default:
      return '생일';
  }
}

/// 그룹의 문구를 돌려줍니다. 규칙을 「그리고」·「또는」으로 잇고 하위 그룹은 괄호로 묶습니다.
String describeCouponGroup(ConditionGroup group, [String Function(num minor)? formatMoney]) {
  final joint = group.combinator == 'and' ? ' 그리고 ' : ' 또는 ';
  return group.rules
      .map((node) => node is ConditionGroup
          ? '(${describeCouponGroup(node, formatMoney)})'
          : describeCouponRule(node as ConditionRule, formatMoney))
      .join(joint);
}

/// 할인 대상 문구를 돌려줍니다(「아우터 카테고리 1개 · 상품 1개, 즉시할인 상품 제외」). 포함이 비면 「전 상품」입니다.
String describeCouponTargetRules(CouponTargetRules rules, [String Function(num minor)? formatMoney]) {
  final include =
      rules.include.isNotEmpty ? rules.include.map((r) => describeCouponRule(r, formatMoney)).join(' 또는 ') : '전 상품';
  if (rules.exclude.isEmpty) return include;
  final exclude = rules.exclude.map((r) => describeCouponRule(r, formatMoney)).join(', ');
  return '$include ($exclude 제외)';
}

/// 할인 대상 문구(트리)를 돌려줍니다(「상품 1개 그리고 판매가 30,000원 이상 (즉시할인 상품 제외)」). 포함이 비면 「전 상품」입니다.
///
/// 「하나라도」만 쓴 옛 쿠폰은 [describeCouponTargetRules]와 같은 문구입니다.
String describeCouponTargetTree(CouponTargetTree tree, [String Function(num minor)? formatMoney]) {
  final flat = couponTargetRulesFromTree(tree);
  if (!flat.rulesOnly) return describeCouponTargetRules(flat.targetRules, formatMoney);
  final include = tree.include.rules.isNotEmpty ? describeCouponGroup(tree.include, formatMoney) : '전 상품';
  if (tree.exclude.rules.isEmpty) return include;
  return '$include (${describeCouponGroup(tree.exclude, formatMoney)} 제외)';
}

/// 스토어프론트 `requirements`를 만듭니다. 최상위 `and`면 노드마다 한 줄(그룹은 문구 한 줄), 최상위 `or`면 트리 전체를 한 줄로 둡니다.
///
/// `minOrderAmount`(옛 필드)와 같은 원천에서 나옵니다.
List<CouponRequirement> couponRequirementsOf(ConditionGroup eligibility, [String Function(num minor)? formatMoney]) {
  final canonical = canonicalizeConditionGroup(eligibility);
  if (canonical.rules.isEmpty) return [];
  final topAnd = canonical.combinator == 'and' || canonical.rules.length <= 1;
  if (!topAnd) return [CouponRequirement(field: 'group', label: describeCouponGroup(canonical, formatMoney))];
  return [
    for (final node in canonical.rules)
      node is ConditionGroup
          ? CouponRequirement(field: 'group', label: describeCouponGroup(node, formatMoney))
          : CouponRequirement(
              field: (node as ConditionRule).field,
              operator: node.operator,
              value: node.value,
              label: describeCouponRule(node, formatMoney),
            ),
  ];
}
