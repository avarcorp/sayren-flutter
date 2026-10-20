// zod 클로저(refine·superRefine·transform·preprocess·overwrite)의 Dart 구현.
// 키는 Node 함수 원문(공백 정리)이다. 생성기가 원문을 찾지 못하면 멈추고 원문을 보여 준다 — 여기에 Dart 구현을 더한다.
// 모델에 거는 검사는 값이 모델이므로 `jsonOf(v as ParsedObject)`로 JSON을 읽는다.

export const normalize = (fn) => String(fn).replace(/\s+/g, " ").trim();

/** refine 술어 — Dart `(v) => bool` */
export const REFINES = {
  "(value) => Object.values(value).some((v) => v !== void 0)":
    "(v) => jsonOf(v as ParsedObject).isNotEmpty", // undefined가 아닌 값(null 포함)이 하나라도 있다
  '(code) => code !== "KR"': "(v) => v != 'KR'",
  "(type) => !KNOWN_TYPES.includes(type)": "(v) => !_knownTypes.contains(v)",
  "(value) => value.cartItemIds ? !value.directItem : !!value.directItem":
    "(v) { final j = jsonOf(v as ParsedObject); return j['cartItemIds'] != null ? j['directItem'] == null : j['directItem'] != null; }",
  "(value) => (value.issueId ? 1 : 0) + (value.code ? 1 : 0) === 1":
    "(v) { final j = jsonOf(v as ParsedObject); return (truthy(j['issueId']) ? 1 : 0) + (truthy(j['code']) ? 1 : 0) == 1; }",
  "(value) => [ /[a-zA-Z]/, /[0-9]/, /[^a-zA-Z0-9]/ ].filter((pattern) => pattern.test(value)).length >= 2":
    "(v) => [RegExp(r'[a-zA-Z]'), RegExp(r'[0-9]'), RegExp(r'[^a-zA-Z0-9]')].where((p) => p.hasMatch(v as String)).length >= 2",
};

/** overwrite — ZodString 메서드 이름 */
export const OVERWRITES = {
  "(input) => input.trim()": "trim",
};

/** transform·preprocess — Dart 함수와 출력 타입(모델로 바꾸면 그 클래스) */
export const TRANSFORMS = {
  '(value) => ({ type: "OTHER", rawType: value.type, requiresShipping: value.requiresShipping })': {
    dart: "_unknownFulfillmentView",
    output: "UnknownFulfillmentView",
  },
  "(value) => Array.isArray(value) ? value.filter((item) => availablePaymentOptionSchema.safeParse(item).success) : value":
    { dart: "_knownPaymentOptions" },
};

/** superRefine — 원문을 읽을 수 없어 스키마 이름으로 찾는다. Dart `(v, ctx) { … }` 함수 이름 */
export const SUPER_REFINES = {
  cashReceiptRequestSchema: "_cashReceiptCheck",
};
