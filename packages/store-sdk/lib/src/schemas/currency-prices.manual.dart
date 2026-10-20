// 손으로 쓴 부분 — currency-prices.ts의 superRefine(판매가 단위, 통화 한 번씩).
part of 'currency-prices.dart';

/// 외화 판매가 superRefine — 판매가가 그 통화의 판매가 단위여야 한다
void _salePriceUnitCheck(ProductCurrencyPrice value, ZodCheckContext ctx) {
  if (!isSaleUnitPrice(value.salePrice, value.currency)) {
    ctx.addIssue('판매가가 이 통화의 판매가 단위가 아닙니다 (INVALID_PRICE_UNIT)', path: ['salePrice']);
  }
}

/// 외화 목록 superRefine — 기본 통화는 넣지 않고, 같은 통화는 한 번만 둔다
void _foreignOnce(List<ParsedObject> items, ZodCheckContext ctx) {
  final seen = <String>{};
  for (var index = 0; index < items.length; index++) {
    final currency = jsonOf(items[index])['currency'] as String;
    if (currency == BASE_CURRENCY) {
      ctx.addIssue('기본 통화는 prices에 넣지 않습니다', path: [index, 'currency']);
    }
    if (seen.contains(currency)) {
      ctx.addIssue('통화가 겹칩니다', path: [index, 'currency']);
    }
    seen.add(currency);
  }
}
