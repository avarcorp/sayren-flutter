// Node SDK(@sayren/storefront-sdk)로 시나리오를 실행하고 요청·결과를 JSON으로 쓴다.
import { readFileSync } from "node:fs";
import { createStorefrontClient, ApiError } from "@sayren/storefront-sdk";

const { defaults, scenarios } = JSON.parse(readFileSync(new URL("./scenarios.json", import.meta.url), "utf8"));

function toOptions(raw) {
  const out = {};
  for (const [k, v] of Object.entries(raw)) out[k] = v && typeof v === "object" && "$fn" in v ? () => v.$fn : v;
  return out;
}

function describeError(error) {
  if (error instanceof ApiError) {
    return { type: "ApiError", status: error.status, code: error.code, message: error.message, traceId: error.traceId ?? null, details: error.details ?? null, docs: error.docs ?? null, body: error.body ?? null };
  }
  if (error?.name === "ZodError") {
    return { type: "ZodError", issues: error.issues.map((i) => ({ code: i.code, path: i.path })) };
  }
  return { type: "Error", message: String(error) };
}

const results = [];
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
  const client = createStorefrontClient({ ...toOptions({ ...defaults.options, ...(s.options ?? {}) }), fetch, onCartToken: (t) => cartTokens.push(t) });
  const [ns, method] = s.call.split(".");
  let outcome;
  try {
    const value = await client[ns][method](...s.args);
    outcome = { ok: true, value: value === undefined ? null : JSON.parse(JSON.stringify(value)) };
  } catch (error) {
    outcome = { ok: false, error: describeError(error) };
  }
  results.push({ name: s.name, requests, cartTokens, outcome });
}
process.stdout.write(`${JSON.stringify(results, null, 2)}\n`);
