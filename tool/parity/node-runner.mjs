// Node SDK(@sayren/storefront-sdk)로 시나리오·스키마 대조 자료를 실행하고 결과를 JSON으로 쓴다.
import { readFileSync } from "node:fs";
import * as sdk from "@sayren/storefront-sdk";

const read = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url), "utf8"));
const hand = read("./scenarios.json");
const generated = read("./generated/scenarios.json");
const schemaCases = read("./generated/schema-cases.json");
const defaults = hand.defaults;
const scenarios = [...hand.scenarios, ...generated.scenarios];

function toOptions(raw) {
  const out = {};
  for (const [k, v] of Object.entries(raw)) out[k] = v && typeof v === "object" && "$fn" in v ? () => v.$fn : v;
  return out;
}

const json = (v) => (v === undefined ? null : JSON.parse(JSON.stringify(v)));

function describeError(error) {
  if (error instanceof sdk.ApiError) {
    return { type: "ApiError", status: error.status, code: error.code, message: error.message, traceId: error.traceId ?? null, details: error.details ?? null, docs: error.docs ?? null, body: error.body ?? null };
  }
  if (error?.name === "ZodError") return { type: "ZodError", issues: error.issues.map((i) => ({ code: i.code, path: i.path })) };
  return { type: "Error" };
}

const scenarioResults = [];
for (const s of scenarios) {
  const requests = [];
  const cartTokens = [];
  const fetch = async (url, init) => {
    requests.push({
      method: init.method,
      url,
      headers: Object.fromEntries(Object.entries(init.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]).sort()),
      body: init.body === undefined ? null : JSON.parse(init.body),
    });
    const r = s.response;
    return new Response(r.status === 204 ? null : JSON.stringify(r.body), { status: r.status, headers: { "content-type": "application/json", ...(r.headers ?? {}) } });
  };
  const client = sdk.createStorefrontClient({ ...toOptions({ ...defaults.options, ...(s.options ?? {}) }), fetch, onCartToken: (t) => cartTokens.push(t) });
  const parts = s.call.split(".");
  const target = parts.slice(0, -1).reduce((o, k) => o[k], client);
  let outcome;
  try {
    outcome = { ok: true, value: json(await target[parts.at(-1)](...s.args)) };
  } catch (error) {
    outcome = { ok: false, error: describeError(error) };
  }
  scenarioResults.push({ name: s.name, requests, cartTokens, outcome });
}

const schemaResults = schemaCases.map((c) => {
  const r = sdk[c.schema].safeParse(c.input);
  return {
    name: `${c.schema} ${c.label}`,
    outcome: r.success ? { ok: true, value: json(r.data) } : { ok: false, issues: r.error.issues.map((i) => ({ code: i.code, path: i.path })) },
  };
});

process.stdout.write(`${JSON.stringify({ scenarios: scenarioResults, schemaCases: schemaResults }, null, 2)}\n`);
