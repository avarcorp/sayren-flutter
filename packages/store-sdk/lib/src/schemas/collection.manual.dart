// 손으로 쓴 부분 — collection.ts의 함수·zod 클로저 구현.
part of 'collection.dart';

/// 판매량 상위 조건의 기간(일)입니다. 값은 `7`·`30`·`90`([COLLECTION_BEST_SELLING_DAYS])입니다.
typedef CollectionBestSellingDays = int;

const _dayMs = 86400000;

/// 노출 상태를 판정합니다. 숨김 → 시작 전(예약) → 종료 → 노출 중 순서이고 [now]는 판정 시각입니다.
///
/// ```dart
/// final state = collectionStateOf((visible: c.visible, startsAt: c.startsAt, endsAt: c.endsAt), DateTime.now());
/// ```
CollectionState collectionStateOf(({bool visible, String? startsAt, String? endsAt}) collection, DateTime now) {
  if (!collection.visible) return 'HIDDEN';
  final at = now.millisecondsSinceEpoch;
  final startsAt = collection.startsAt;
  final endsAt = collection.endsAt;
  if (startsAt != null && startsAt.isNotEmpty && jsDateParse(startsAt) > at) return 'SCHEDULED';
  if (endsAt != null && endsAt.isNotEmpty && jsDateParse(endsAt) <= at) return 'ENDED';
  return 'ACTIVE';
}

/// 카테고리 자신과 모든 하위 카테고리 id를 돌려줍니다.
///
/// [categories]는 상점 카테고리의 부모 관계입니다([CollectionRuleContext.categories]).
Set<String> descendantCategoryIdsOf(List<String> roots, List<({String categoryId, String? parentId})> categories) {
  final ids = <String>{...roots};
  final children = <String, List<String>>{};
  for (final category in categories) {
    final parentId = category.parentId;
    if (parentId == null || parentId.isEmpty) continue;
    (children[parentId] ??= []).add(category.categoryId);
  }
  final queue = [...roots];
  while (queue.isNotEmpty) {
    final next = queue.removeAt(0);
    for (final child in children[next] ?? const <String>[]) {
      if (ids.contains(child)) continue;
      ids.add(child);
      queue.add(child);
    }
  }
  return ids;
}

/// 조건 판정 함수를 만듭니다. 모든 조건을 만족해야 true입니다(AND). 카테고리 트리는 여기서 한 번만 풉니다.
///
/// 알 수 없는 조건(`field`)은 만족하지 않는 것으로 봅니다. 판매량 상위(`bestSelling`)는 여기서 모두 통과시키고,
/// 순위 자르기는 판매량을 아는 호출부가 [rankBestSelling]으로 합니다. 판매 상태는 보지 않습니다.
bool Function(CollectionRuleProduct product) collectionRulesPredicate(
  List<CollectionRuleView> rules,
  CollectionRuleContext context,
) {
  final checks = rules.map<bool Function(CollectionRuleProduct)>((rule) {
    final known = collectionRuleSchema.safeParse(rule.toJson());
    if (!known.success) return (_) => false;
    switch (known.data!) {
      case CollectionRuleCreatedwithindays(:final value):
        final since = context.now.millisecondsSinceEpoch - value * _dayMs;
        return (product) => jsDateParse(product.createdAt) >= since;
      case CollectionRuleCategory(:final categoryIds):
        final ids = descendantCategoryIdsOf(categoryIds, context.categories);
        return (product) => product.categoryId != null && ids.contains(product.categoryId);
      case CollectionRulePrice(:final min, :final max):
        return (product) {
          final price = product.discountedPrice ?? product.salePrice;
          return (min == null || price >= min) && (max == null || price <= max);
        };
      case CollectionRuleDiscounted():
        return (product) => product.discountedPrice != null && product.discountedPrice! < product.salePrice;
      case CollectionRuleBestselling():
        return (_) => true;
    }
  }).toList();
  return (product) => checks.isNotEmpty && checks.every((check) => check(product));
}

/// 상품 하나가 조건을 모두 만족하는지 판정합니다. 여러 상품을 판정할 때는 [collectionRulesPredicate]를 한 번 만들어 쓰십시오.
bool matchesCollectionRules(
  CollectionRuleProduct product,
  List<CollectionRuleView> rules,
  CollectionRuleContext context,
) =>
    collectionRulesPredicate(rules, context)(product);

/// 판매량 상위 조건을 돌려줍니다. 없으면 null입니다. 같은 조건은 한 번만 쓰므로 첫 번째입니다.
({CollectionBestSellingDays days, int top})? bestSellingRuleOf(List<CollectionRuleView> rules) {
  for (final rule in rules) {
    final parsed = collectionRuleBestsellingSchema.safeParse(rule.toJson());
    if (parsed.success) return (days: parsed.data!.days, top: parsed.data!.top);
  }
  return null;
}

/// JS `Map.get`처럼 상품 값의 `productId`·`createdAt`을 읽는다 — 모델·맵·레코드 모두 받는다
Object? _salesKeyOf(Object? product, String key) {
  if (product is Map) return product[key];
  if (product is ParsedObject) return jsonOf(product)[key];
  final dynamic p = product;
  return key == 'productId' ? p.productId : p.createdAt;
}

/// 판매량 비교 함수를 만듭니다. 판매 수량이 많은 순, 같으면 최근 등록 순, 그것도 같으면 상품 id 순입니다.
///
/// [T]는 `productId`·`createdAt`(문자열)을 가진 값(모델·맵·레코드)입니다. [sales]에 없는 상품은 0개입니다.
int Function(T a, T b) compareBySales<T>(Map<String, num> sales) => (a, b) {
      final aId = _salesKeyOf(a, 'productId') as String;
      final bId = _salesKeyOf(b, 'productId') as String;
      final bySales = (sales[bId] ?? 0) - (sales[aId] ?? 0);
      if (bySales != 0) return bySales > 0 ? bySales.ceil() : bySales.floor();
      final byDate =
          jsDateParse(_salesKeyOf(b, 'createdAt') as String) - jsDateParse(_salesKeyOf(a, 'createdAt') as String);
      if (!byDate.isNaN && byDate != 0) return byDate > 0 ? byDate.ceil() : byDate.floor();
      return aId.compareTo(bId).sign;
    };

/// 판매량 상위를 자릅니다. 판매 수량이 1개 이상인 상품을 [compareBySales] 순으로 [top]개 남깁니다.
///
/// 판매가 없는 상품은 넣지 않습니다. 정렬은 JS처럼 안정 정렬입니다.
List<T> rankBestSelling<T>(List<T> products, Map<String, num> sales, int top) {
  final compare = compareBySales<T>(sales);
  final indexed = [
    for (var i = 0; i < products.length; i++)
      if ((sales[_salesKeyOf(products[i], 'productId')] ?? 0) > 0) (i, products[i]),
  ]..sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1 - b.$1;
    });
  return [for (final (_, p) in indexed.take(top < 0 ? 0 : top)) p];
}

/// 조건이 참조하는 카테고리 id를 돌려줍니다. 카테고리 삭제의 참조 검사에 씁니다.
List<String> collectionRuleCategoryIds(List<CollectionRuleView> rules) {
  final ids = <String>[];
  for (final rule in rules) {
    final parsed = collectionRuleCategorySchema.safeParse(rule.toJson());
    if (parsed.success) ids.addAll(parsed.data!.categoryIds);
  }
  return ids;
}

/// 가격 조건 superRefine — 최저가·최고가 중 하나는 있고 최저가 ≤ 최고가다
void _collectionRuleCheck(CollectionRule rule, ZodCheckContext ctx) {
  if (rule is! CollectionRulePrice) return;
  final min = rule.min;
  final max = rule.max;
  if (min == null && max == null) {
    ctx.addIssue('최저가나 최고가 중 하나는 있어야 합니다', path: ['min']);
  } else if (min != null && max != null && min > max) {
    ctx.addIssue('최고가는 최저가 이상이어야 합니다', path: ['max']);
  }
}

/// 조건 목록 superRefine — 같은 `field`는 한 번만 쓴다
void _collectionRulesCheck(List<CollectionRule> rules, ZodCheckContext ctx) {
  final seen = <String>{};
  for (var index = 0; index < rules.length; index++) {
    final field = rules[index].field;
    if (seen.contains(field)) ctx.addIssue('같은 조건을 두 번 쓸 수 없습니다', path: [index, 'field']);
    seen.add(field);
  }
}

/// 기간 superRefine — 종료 시각은 시작 시각보다 뒤다
void _periodCheck(ParsedObject body, ZodCheckContext ctx) {
  final j = jsonOf(body);
  final startsAt = j['startsAt'];
  final endsAt = j['endsAt'];
  if (truthy(startsAt) && truthy(endsAt) && jsDateParse(endsAt as String) <= jsDateParse(startsAt as String)) {
    ctx.addIssue('종료 시각은 시작 시각보다 뒤여야 합니다', path: ['endsAt']);
  }
}
