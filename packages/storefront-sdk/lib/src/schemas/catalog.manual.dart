// 손으로 쓴 부분 — catalog.ts의 가격 표시·옵션 선택 함수.
part of 'catalog.dart';

/// 상품 상세의 판매 단위(조합) 하나입니다(Node `ProductDetail["variants"][number]`).
typedef ProductVariant = ProductDetailVariantsItem;

/// 상품 가격 표시를 만듭니다. 카드·상세가 같은 규칙으로 가격을 보이게 합니다.
///
/// [product]는 `salePrice`·`discountedPrice`·`originalPrice`·`currency`를 가진 모델([ProductCard]·[ProductDetail] 등)입니다.
PriceView priceViewOf(ParsedObject product) {
  final j = jsonOf(product);
  final salePrice = j['salePrice'] as int;
  final discountedPrice = j['discountedPrice'] as int?;
  final originalPrice = j['originalPrice'] as int?;
  final price = discountedPrice ?? salePrice;
  final compareAt = originalPrice != null && originalPrice > price
      ? originalPrice
      : discountedPrice != null && salePrice > price
          ? salePrice
          : null;
  return PriceView(
    price: price,
    compareAt: compareAt,
    // JS Math.round — .5는 +∞ 쪽으로 올린다
    discountRate: compareAt == null ? null : ((1 - price / compareAt) * 100 + 0.5).floor(),
    currency: j['currency'] as String,
  );
}

/// 고른 옵션 값으로 판매 단위(조합)를 찾습니다.
///
/// [chosen]은 `optionGroups` 순서의 valueId(고르지 않은 축은 null)입니다. 옵션 없는 상품은 조합 하나(`variants[0]`)입니다.
/// 고르지 않은 축이 있거나 없는 조합이면 null입니다. 찾은 `variantId`가 담기 요청의 `optionId`입니다.
ProductVariant? findVariant(ProductDetail product, List<String?> chosen) {
  if (product.optionGroups.isEmpty) return product.variants.firstOrNull;
  if (chosen.length != product.optionGroups.length || chosen.any((id) => id == null)) return null;
  for (final v in product.variants) {
    if (v.valueIds.length != chosen.length) continue;
    var same = true;
    for (var i = 0; i < chosen.length; i++) {
      if (v.valueIds[i] != chosen[i]) same = false;
    }
    if (same) return v;
  }
  return null;
}

/// 조합 옵션 선택 화면의 값 상태를 만듭니다.
///
/// 각 값을 고를 수 있는지(품절·없는 조합), 고르면 붙는 추가금, 지금 정해진 조합을 한 번에 냅니다. 다른 축의 선택과 이어지는 조합만 봅니다.
/// 모양(드롭다운·버튼)과 문구는 화면이 정합니다.
OptionChoices optionChoicesOf(ProductDetail product, List<String?> chosen) {
  String? at(int i) => i < chosen.length ? chosen[i] : null;
  final groups = [
    for (var g = 0; g < product.optionGroups.length; g++)
      () {
        final group = product.optionGroups[g];
        var othersChosen = true;
        for (var h = 0; h < product.optionGroups.length; h++) {
          if (h != g && at(h) == null) othersChosen = false;
        }
        return (
          groupId: group.groupId,
          name: group.name,
          values: [
            for (final value in group.values)
              () {
                final reachable = product.variants.where((v) {
                  if (g >= v.valueIds.length || v.valueIds[g] != value.valueId) return false;
                  for (var h = 0; h < v.valueIds.length; h++) {
                    if (h != g && at(h) != null && v.valueIds[h] != at(h)) return false;
                  }
                  return true;
                }).toList();
                final OptionValueState state = reachable.isEmpty
                    ? 'UNAVAILABLE'
                    : reachable.every((v) => v.soldOut)
                        ? 'SOLD_OUT'
                        : 'AVAILABLE';
                return (
                  valueId: value.valueId,
                  name: value.name,
                  selected: at(g) == value.valueId,
                  state: state,
                  additionalPrice: othersChosen && reachable.length == 1 ? reachable.first.additionalPrice : null,
                );
              }(),
          ],
        );
      }(),
  ];
  return OptionChoices(groups: groups, variant: findVariant(product, chosen));
}
