// 손으로 쓴 부분 — currency.ts의 통화표와 금액 함수.
part of 'currency.dart';

const _int4Max = 2147483647;
const _pg8DigitMax = 99999999;

/// 1차 판매 통화 16종의 통화표입니다.
///
/// 판매가 단위는 KRW 10원, JPY 1엔, 2자리 통화 1센트, TWD 100입니다. 최소 결제액은 KRW 100원이고 그 밖은 Stripe 최소 청구액을 따릅니다.
const CURRENCIES = <String, CurrencySpec>{
  'KRW': CurrencySpec(code: 'KRW', digits: 0, saleUnit: 10, minPayment: 100, maxOrderAmount: _int4Max),
  'USD': CurrencySpec(code: 'USD', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'EUR': CurrencySpec(code: 'EUR', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'JPY': CurrencySpec(code: 'JPY', digits: 0, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'GBP': CurrencySpec(code: 'GBP', digits: 2, saleUnit: 1, minPayment: 30, maxOrderAmount: _pg8DigitMax),
  'CNY': CurrencySpec(code: 'CNY', digits: 2, saleUnit: 1, minPayment: 400, maxOrderAmount: _pg8DigitMax),
  'HKD': CurrencySpec(code: 'HKD', digits: 2, saleUnit: 1, minPayment: 400, maxOrderAmount: _pg8DigitMax),
  'TWD': CurrencySpec(code: 'TWD', digits: 2, saleUnit: 100, minPayment: 2000, maxOrderAmount: _pg8DigitMax),
  'SGD': CurrencySpec(code: 'SGD', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'AUD': CurrencySpec(code: 'AUD', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'CAD': CurrencySpec(code: 'CAD', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'THB': CurrencySpec(code: 'THB', digits: 2, saleUnit: 1, minPayment: 1000, maxOrderAmount: _pg8DigitMax),
  'MYR': CurrencySpec(code: 'MYR', digits: 2, saleUnit: 1, minPayment: 200, maxOrderAmount: _pg8DigitMax),
  'PHP': CurrencySpec(code: 'PHP', digits: 2, saleUnit: 1, minPayment: 3000, maxOrderAmount: _pg8DigitMax),
  'NZD': CurrencySpec(code: 'NZD', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
  'CHF': CurrencySpec(code: 'CHF', digits: 2, saleUnit: 1, minPayment: 50, maxOrderAmount: _pg8DigitMax),
};

/// [value]가 통화표에 있는 통화인지입니다.
bool isCurrencyCode(String value) => CURRENCIES.containsKey(value);

/// 통화표 항목입니다. 모르는 통화면 [RangeError]를 던집니다.
CurrencySpec currencySpecOf(String code) {
  final spec = CURRENCIES[code];
  if (spec == null) throw RangeError('unsupported currency: $code');
  return spec;
}

int _scaleOf(CurrencySpec spec) => math.pow(10, spec.digits).toInt();

/// JS `Math.round` — .5는 +∞ 쪽으로 올린다
int _jsRound(num value) => (value + 0.5).floor();

/// 주 단위를 최소 단위로 바꿉니다(반올림). 입력·화면 값 변환용입니다.
int toMinor(num major, String currency) => _jsRound(major * _scaleOf(currencySpecOf(currency)));

/// 최소 단위를 주 단위(표시용 숫자)로 바꿉니다.
num minorToMajor(num minor, String currency) => minor / _scaleOf(currencySpecOf(currency));

const _maxSafeInteger = 9007199254740991;

/// 최소 단위를 PG 요청 형식 십진 문자열로 바꿉니다. `1099` USD → `"10.99"`, `1000` KRW → `"1000"`.
String toDecimalString(num minor, String currency) {
  if (minor != minor.truncate() || minor.abs() > _maxSafeInteger) {
    throw RangeError('amount must be an integer: $minor');
  }
  final digits = currencySpecOf(currency).digits;
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs().toInt().toString();
  if (digits == 0) return '$sign$abs';
  final padded = abs.padLeft(digits + 1, '0');
  return '$sign${padded.substring(0, padded.length - digits)}.${padded.substring(padded.length - digits)}';
}

/// PG 응답의 십진 문자열을 최소 단위 정수로 바꿉니다. 형식이 틀리면 [RangeError]를 던집니다.
///
/// 통화 자릿수보다 긴 소수는 끝이 0일 때만 받습니다(`"10.990"` → 1099, `"10.999"`는 [RangeError]).
int fromDecimalString(String value, String currency) {
  final digits = currencySpecOf(currency).digits;
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
  if (match == null) throw RangeError('invalid decimal amount: $value');
  final sign = match[1]!;
  final whole = match[2]!;
  final fraction = match[3] ?? '';
  final extra = fraction.length > digits ? fraction.substring(digits) : '';
  if (RegExp('[^0]').hasMatch(extra)) throw RangeError('too many fraction digits for $currency: $value');
  final kept = fraction.length > digits ? fraction.substring(0, digits) : fraction;
  final minor = num.parse('$whole${kept.padRight(digits, '0')}');
  if (minor > _maxSafeInteger) throw RangeError('amount out of range: $value');
  return sign == '-' && minor != 0 ? -minor.toInt() : minor.toInt();
}

/// 판매가 단위로 내립니다. 할인·정률 쿠폰 계산의 단위 맞춤에 사용합니다.
int floorToSaleUnit(num amount, String currency) {
  final saleUnit = currencySpecOf(currency).saleUnit;
  return (amount / saleUnit).floor() * saleUnit;
}

/// 판매가 규칙(판매가 단위의 배수, 최소 판매가 단위)을 지키는지입니다.
bool isSaleUnitPrice(num amount, String currency) {
  final saleUnit = currencySpecOf(currency).saleUnit;
  return amount == amount.truncate() && amount >= saleUnit && amount % saleUnit == 0;
}

/// 판매가 규칙 위반입니다. 서버는 400 `INVALID_PRICE_UNIT`으로 답합니다.
class InvalidPriceUnitError implements Exception {
  /// 예외를 만듭니다.
  InvalidPriceUnitError(this.amount, this.currency, this.saleUnit);

  /// 오류 코드입니다. 항상 `INVALID_PRICE_UNIT`입니다.
  final String code = 'INVALID_PRICE_UNIT';

  /// 검사한 금액입니다.
  final num amount;

  /// 통화입니다.
  final String currency;

  /// 판매가 단위입니다.
  final int saleUnit;

  /// 예외 이름입니다. 항상 `InvalidPriceUnitError`입니다.
  String get name => 'InvalidPriceUnitError';

  /// 사람이 읽는 설명입니다.
  String get message => 'sale price $amount $currency must be a multiple of $saleUnit and at least $saleUnit';

  @override
  String toString() => '$name: $message';
}

/// 판매가 규칙을 검사합니다. 어기면 [InvalidPriceUnitError]를 던집니다.
void assertSaleUnit(num amount, String currency) {
  if (!isSaleUnitPrice(amount, currency)) {
    throw InvalidPriceUnitError(amount, currency, currencySpecOf(currency).saleUnit);
  }
}

/// 최소 결제액입니다. 통화표 값과 [candidates] 중 큰 값이고, null인 후보는 하한이 없다는 뜻입니다.
int minPaymentOf(String currency, [List<int?> candidates = const []]) {
  var floor = currencySpecOf(currency).minPayment;
  for (final candidate in candidates) {
    if (candidate != null && candidate > floor) floor = candidate;
  }
  return floor;
}

/// 통화의 규칙 값입니다. [minPayment]를 주면 통화표 값 대신 사용합니다.
MoneyRules moneyRulesOf(String currency, {int? minPayment}) {
  final spec = currencySpecOf(currency);
  return MoneyRules(
    currency: spec.code,
    saleUnit: spec.saleUnit,
    minPayment: minPayment ?? spec.minPayment,
    maxOrderAmount: spec.maxOrderAmount,
  );
}

/// 기본 통화(KRW) 규칙입니다.
final KRW_MONEY_RULES = moneyRulesOf(BASE_CURRENCY);
