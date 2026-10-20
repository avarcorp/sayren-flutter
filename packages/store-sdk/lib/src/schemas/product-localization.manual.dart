// 손으로 쓴 부분 — product-localization.ts의 함수 구현.
part of 'product-localization.dart';

/// 번역할 칸이 비었는지 판정합니다.
///
/// 상품명, 기본 언어에 본문이 있는 상세설명([description]은 기본 언어 상세설명), 옵션명·값·직접 입력 항목명,
/// 셀러가 적은 고시 칸을 봅니다. 이미지·입력 안내는 기본 언어 값을 그대로 써도 되는 칸이라 세지 않습니다.
bool productLocalizationNeedsTranslation(ProductLocalization localization, {String? description}) {
  if (!truthy(localization.name)) return true;
  if ((description ?? '').trim().isNotEmpty && !truthy(localization.description)) return true;
  final groups = [...localization.optionGroups, ...localization.addonGroups];
  if (groups.any((group) => !truthy(group.name) || group.values.any((value) => !truthy(value.name)))) return true;
  if (localization.customInputs.any((item) => !truthy(item.label))) return true;
  return localization.notice.any((entry) => !truthy(entry.value));
}
