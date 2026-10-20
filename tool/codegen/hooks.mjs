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

// ── @sayren/store-sdk ──

Object.assign(REFINES, {
  "(body) => body.text.length > 0 || body.attachments.length > 0":
    "(v) { final j = jsonOf(v as ParsedObject); return (j['text'] as String).isNotEmpty || (j['attachments'] as List).isNotEmpty; }",
  '(value) => !APP_RESERVED_HANDLES.has(value) && !value.endsWith("-preview")':
    "(v) => !APP_RESERVED_HANDLES.contains(v) && !(v as String).endsWith('-preview')",
  "function isInstallableScope(scope) { return isStoreScope(scope) && !NON_INSTALLABLE_SCOPES.has(scope); }":
    "(v) => isInstallableScope(v as String)",
  "(params) => Object.keys(params).length <= 20": "(v) => keyCount(v) <= 20",
  "(input) => Object.keys(input).length <= 20": "(v) => keyCount(v) <= 20",
  "(tools) => Object.keys(tools).length <= 20": "(v) => keyCount(v) <= 20",
  "(items) => Object.keys(items).length <= 20": "(v) => keyCount(v) <= 20",
  "(schedules) => Object.keys(schedules).length <= 10": "(v) => keyCount(v) <= 10",
  "(fields) => Object.keys(fields).length <= 30": "(v) => keyCount(v) <= 30",
  "(value) => Object.keys(value).length <= 10": "(v) => keyCount(v) <= 10",
  "(path) => /\\.(png|svg)$/i.test(path)": "(v) => RegExp(r'\\.(png|svg)$', caseSensitive: false).hasMatch(v as String)",
  "(path) => /\\.md$/i.test(path)": "(v) => RegExp(r'\\.md$', caseSensitive: false).hasMatch(v as String)",
  "(value) => value !== void 0": "(v) => v != absent",
  '(value) => value.startsWith("https://")': "(v) => (v as String).startsWith('https://')",
  "(ids) => new Set(ids).size === ids.length": "(v) => (v as List).toSet().length == v.length",
  "(methods) => new Set(methods).size === methods.length": "(v) => (v as List).toSet().length == v.length",
  "(value) => Boolean(value.uid || value.email)":
    "(v) { final j = jsonOf(v as ParsedObject); return truthy(j['uid']) || truthy(j['email']); }",
  "(type) => !KNOWN_FULFILLMENT_TYPES.includes(type)": "(v) => !_knownFulfillmentTypes.contains(v)",
  "(line) => line.delta === void 0 !== (line.counted === void 0)":
    "(v) { final j = jsonOf(v as ParsedObject); return j.containsKey('delta') != j.containsKey('counted'); }",
  "(value) => value !== 0": "(v) => v != 0",
  '(value) => value.deliveryMethod === "DIRECT" || value.deliveryMethod === "NOTHING" ? true : !!value.carrierCode && !!value.trackingNumber':
    "(v) { final j = jsonOf(v as ParsedObject); final m = j['deliveryMethod']; return m == 'DIRECT' || m == 'NOTHING' ? true : truthy(j['carrierCode']) && truthy(j['trackingNumber']); }",
  "(body) => body.enabled !== void 0 || body.sandboxMode !== void 0 || body.easyPayProviders !== void 0":
    "(v) { final j = jsonOf(v as ParsedObject); return j.containsKey('enabled') || j.containsKey('sandboxMode') || j.containsKey('easyPayProviders'); }",
  "(body) => body.priority !== void 0 || body.checkoutOrigins !== void 0":
    "(v) { final j = jsonOf(v as ParsedObject); return j.containsKey('priority') || j.containsKey('checkoutOrigins'); }",
  "(value) => !(value.amount < 0 && value.expiresAt)":
    "(v) { final j = jsonOf(v as ParsedObject); return !((j['amount'] as num) < 0 && truthy(j['expiresAt'])); }",
  "(v) => v.stockQuantity !== void 0 !== (v.adjustment !== void 0)":
    "(v) { final j = jsonOf(v as ParsedObject); return j.containsKey('stockQuantity') != j.containsKey('adjustment'); }",
  '(map) => !("KRW" in map)': "(v) => !jsMap(v).containsKey('KRW')",
  'function isHttpUrl(value) { try { const { protocol } = new URL(value); return protocol === "https:" || protocol === "http:"; } catch { return false; } }':
    "(v) => _isHttpUrl(v as String)",
  "(value) => { const date = /* @__PURE__ */ new Date(`${value}T00:00:00Z`); return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value; }":
    "(v) => _isCalendarDate(v as String)",
  "(value) => value.stock !== void 0 || value.price !== void 0":
    "(v) { final j = jsonOf(v as ParsedObject); return j.containsKey('stock') || j.containsKey('price'); }",
  "(code) => !isReservedStoreCode(code)": "(v) => !isReservedStoreCode(v as String)",
  'function isWebOrigin(value) { try { const url = new URL(value); return (url.protocol === "https:" || url.protocol === "http:") && !url.username && !url.password && url.pathname === "/" && !url.search && !url.hash && !value.includes("*"); } catch { return false; } }':
    "(v) => isWebOrigin(v as String)",
  '(slug) => !slug.includes("--")': "(v) => !(v as String).contains('--')",
  "(slug) => !isReservedStorefrontSlug(slug)": "(v) => !isReservedStorefrontSlug(v as String)",
  'function isEditableStorefrontPath(path) { if (path.length === 0 || path.length > 256) return false; if (INVISIBLE_OR_BIDI.test(path)) return false; if (path !== normalizeStorefrontPath(path)) return false; if (path.startsWith("/")) return false; const segments = path.split("/"); if (segments.length > 16) return false; for (const segment of segments) { if (segment === "" || segment === "." || segment === "..") return false; if (!STOREFRONT_PATH_SEGMENT_PATTERN.test(segment)) return false; if (STOREFRONT_BLOCKED_PATH_SEGMENTS.includes(segment)) return false; if (segment.startsWith(".env")) return false; } return true; }':
    "(v) => isEditableStorefrontPath(v as String)",
  "(files) => new Set(files.map((file) => file.path)).size === files.length":
    "(v) => (v as List).map((f) => jsMap(f)['path']).toSet().length == v.length",
  "(body) => !body.regex || body.query.length <= 100":
    "(v) { final j = jsonOf(v as ParsedObject); return !truthy(j['regex']) || (j['query'] as String).length <= 100; }",
  "(results) => new Set(results.map((result) => result.ruleId)).size === results.length":
    "(v) => (v as List).map((r) => jsMap(r)['ruleId']).toSet().length == v.length",
});

const CSV = { dart: "_splitCsv", output: "List<String>" };
Object.assign(TRANSFORMS, {
  '(value) => (Array.isArray(value) ? value : [value]).flatMap((part) => part.split(",")).map((part) => part.trim()).filter((part) => part.length > 0)':
    CSV,
  '(value) => ({ type: "OTHER", rawType: value.type })': { dart: "_unknownFulfillment", output: "UnknownFulfillment" },
  '(value, ctx) => { const normalized = normalizeLocale(value); if (normalized === null) { ctx.addIssue({ code: "custom", message: "언어는 BCP 47 언어 코드입니다(예: ko·en·en-US)" }); return z.NEVER; } return normalized; }':
    { dart: "_localeCode", output: "String", issues: true },
  "(value) => value.toUpperCase()": { dart: "(v) => (v as String).toUpperCase()", output: "String" },
  '(value) => value.toLowerCase().replace(/\\.$/, "")': {
    dart: "(v) => (v as String).toLowerCase().replaceFirst(RegExp(r'\\.$'), '')",
    output: "String",
  },
  'function normalizeStorefrontPath(path) { return path.normalize("NFC"); }': {
    dart: "(v) => normalizeStorefrontPath(v as String)",
    output: "String",
  },
});

Object.assign(SUPER_REFINES, {
  appNetworkHostSchema: "_appNetworkHostCheck",
  collectionRuleSchema: "_collectionRuleCheck",
  collectionRulesSchema: "_collectionRulesCheck",
  collectionCreateRequestSchema: "_periodCheck",
  collectionPatchRequestSchema: "_periodCheck",
  createCouponRequestSchema: "_createCouponCheck",
  productCurrencyPriceSchema: "_salePriceUnitCheck",
  productCurrencyPricesSchema: "_foreignOnce",
  shippingCurrencyPricesSchema: "_foreignOnce",
  additionalCurrencyPricesSchema: "_foreignOnce",
  productFulfillmentCreateSchema: "_shippingConsistency",
  productFulfillmentUpdateSchema: "_shippingConsistency",
  tossPaymentsCredentialsInputSchema: "_tossWidgetKeyCheck",
  couponBenefitSchema: "_couponBenefitCheck",
});
