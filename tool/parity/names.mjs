// 공개 이름 목록 대조 — Node SDK 엔트리포인트의 export 이름이 Dart 엔트리포인트에서 모두 보이는지 확인한다.
// Dart에만 있는 이름(익명 객체 클래스와 그 스키마 등)은 허용한다. Node `@deprecated`로 만들지 않기로 한 이름은 뺀다(ROADMAP).
//   node names.mjs
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { scanEntry } from "../codegen/scan.mjs";

const here = path.dirname(new URL(import.meta.url).pathname);
const pkgs = path.join(here, "../../packages");
const src = (pkg) => path.join(here, "../codegen/node_modules", pkg, "src");

const ENTRIES = [
  { pkg: "@sayren/storefront-sdk", entry: "index.ts", dart: "storefront-sdk/lib/sayren_storefront_sdk.dart" },
  { pkg: "@sayren/storefront-sdk", entry: "auth/index.ts", dart: "storefront-sdk/lib/auth.dart" },
  { pkg: "@sayren/storefront-sdk", entry: "payments/index.ts", dart: "storefront-sdk/lib/payments.dart" },
  { pkg: "@sayren/storefront-sdk", entry: "analytics/index.ts", dart: "storefront-sdk/lib/analytics.dart" },
  { pkg: "@sayren/store-sdk", entry: "index.ts", dart: "store-sdk/lib/sayren_store_sdk.dart" },
];
/** 만들지 않는 이름 (ROADMAP 「만들지 않는 이름」) */
const NOT_PORTED = new Set([
  "PaymentMode",
  "PaymentPopup",
  "PaymentPostMessage",
  "PreparedPaymentWindow",
  "PREPARED_WINDOW",
  "changeStorefrontTemplateRequestSchema",
  "ChangeStorefrontTemplateRequest",
]);

/** Dart 파일의 최상위 공개 선언 이름 */
function declarations(file) {
  const text = readFileSync(file, "utf8");
  const names = new Set();
  const patterns = [
    /^(?:abstract |sealed |final |base |interface |mixin )*class\s+([A-Za-z]\w*)/gm,
    /^typedef\s+([A-Za-z]\w*)/gm,
    /^extension\s+([A-Za-z]\w*)/gm,
    /^(?:final|const|var)\s+(?:[\w<>?,\s()]+?\s+)?([A-Za-z]\w*)\s*=/gm,
  ];
  for (const re of patterns) for (const m of text.matchAll(re)) names.add(m[1]);
  // 함수 — 반환 타입이 여러 줄 레코드여도 이름 줄은 0열에서 시작한다(`}) name(`). 함수 타입 `Function(…)`은 지우고 찾는다
  for (const line of text.split("\n")) {
    if (/^[\s/@]/.test(line) || /^(class|typedef|extension|import|export|part|library|final|const|var)\b/.test(line)) continue;
    let t = line;
    for (let i = 0; i < 5 && /Function\(/.test(t); i++) t = t.replace(/Function\([^()]*\)/g, "F");
    const m = /^[^=;]*?\b([A-Za-z]\w*)(?:<[^>]*>)?\s*\(/.exec(t);
    if (m) names.add(m[1]);
  }
  // part 파일의 선언도 같은 라이브러리다
  for (const m of text.matchAll(/^part\s+'([^']+)';/gm)) {
    for (const n of declarations(path.join(path.dirname(file), m[1]))) names.add(n);
  }
  return names;
}

/** Dart 엔트리포인트에서 보이는 이름 — export(show 포함)를 따라간다 */
function visible(file, seen = new Set()) {
  if (seen.has(file)) return new Set();
  seen.add(file);
  const text = readFileSync(file, "utf8");
  const names = declarations(file);
  for (const m of text.matchAll(/^export\s+'([^']+)'(?:\s+show\s+([^;]+))?(?:\s+hide\s+([^;]+))?;/gm)) {
    const target = path.join(path.dirname(file), m[1]);
    if (!existsSync(target)) continue;
    const inner = visible(target, seen);
    const show = m[2]?.split(",").map((s) => s.trim());
    const hide = new Set(m[3]?.split(",").map((s) => s.trim()) ?? []);
    for (const n of show ?? inner) if (inner.has(n) && !hide.has(n)) names.add(n);
  }
  return names;
}

let failed = 0;
for (const e of ENTRIES) {
  const node = scanEntry(src(e.pkg), e.entry)
    .filter((x) => !x.deprecated && !NOT_PORTED.has(x.name))
    .map((x) => x.name);
  const dart = visible(path.join(pkgs, e.dart));
  const missing = [...new Set(node)].filter((n) => !dart.has(n));
  console.log(`${e.pkg}/${e.entry} → ${e.dart}: Node ${new Set(node).size}개 중 ${new Set(node).size - missing.length}개`);
  if (missing.length) {
    failed++;
    console.log(`  Dart에 없는 이름: ${missing.join(", ")}`);
  }
}
process.exit(failed ? 1 : 0);
