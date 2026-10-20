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

// 세션 단계 시나리오
const sessionSpec = read("./session-scenarios.json");
const tick = () => new Promise((r) => setTimeout(r, 0));
const sessionResults = [];
for (const s of sessionSpec.scenarios) {
  const store = new Map(Object.entries(s.storage));
  const storage = { get: (k) => store.get(k) ?? null, set: (k, v) => store.set(k, v), remove: (k) => store.delete(k) };
  const queue = [...s.responses];
  const requests = [];
  const fetch = async (url, init) => {
    requests.push({
      method: init.method ?? "GET",
      url,
      headers: Object.fromEntries(Object.entries(init.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]).sort()),
      body: init.body === undefined ? null : JSON.parse(init.body),
    });
    const r = queue.shift() ?? { status: 500, body: null };
    return new Response(r.status === 204 ? null : JSON.stringify(r.body), { status: r.status, headers: { "content-type": "application/json" } });
  };
  const session = sdk.createStorefrontSession({ ...sessionSpec.defaults, storage, fetch });
  let notified = 0;
  session.subscribe(() => notified++);
  const client = sdk.createStorefrontClient({ ...sessionSpec.defaults, fetch, ...(s.noSession ? {} : { session }) });
  const steps = [];
  for (const step of s.steps) {
    let outcome;
    try {
      let value;
      switch (step.op) {
        case "login": value = await session.login(...step.args); break;
        case "signup": value = await session.signup(...step.args); break;
        case "refresh": value = await session.refresh(); break;
        case "refreshTwice": value = await Promise.all([session.refresh(), session.refresh()]); break;
        case "userinfo": value = await session.userinfo(); break;
        case "clientUserinfo": value = await client.userinfo(); break;
        case "clear": value = session.clear(); break;
        case "tokens": value = { accessToken: session.accessToken, refreshToken: session.refreshToken, clientAccessToken: client.accessToken }; break;
        case "call": {
          const parts = step.call.split(".");
          value = await parts.slice(0, -1).reduce((o, k) => o[k], client)[parts.at(-1)](...step.args);
          break;
        }
      }
      outcome = { ok: true, value: json(value) };
    } catch (error) {
      outcome = { ok: false, error: describeError(error) };
    }
    await tick();
    steps.push({ op: step.op, outcome, notified, storage: Object.fromEntries([...store].sort()) });
  }
  sessionResults.push({ name: s.name, requests, steps });
}

// createStorefrontAuth 시나리오 — 무작위 PKCE 값은 가리고 길이·S256 관계만 남긴다
const { createStorefrontAuth } = await import("@sayren/storefront-sdk/auth");
const { createHash } = await import("node:crypto");
const s256 = (v) => createHash("sha256").update(v).digest("base64url");
const authSpec = read("./auth-scenarios.json");
const authResults = [];
for (const s of authSpec.scenarios) {
  const queue = [...s.responses];
  const requests = [];
  const fetch = async (url, init) => {
    requests.push({
      method: init.method ?? "GET",
      url,
      headers: Object.fromEntries(Object.entries(init.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]).sort()),
      body: init.body === undefined ? null : JSON.parse(init.body),
    });
    const r = queue.shift() ?? { status: 500, body: null };
    return new Response(r.status === 204 ? null : JSON.stringify(r.body), { status: r.status, headers: { "content-type": "application/json" } });
  };
  const auth = createStorefrontAuth({ ...authSpec.defaults, fetch });
  let outcome;
  try {
    outcome = { ok: true, value: json(await auth[s.method](...s.args)) };
  } catch (error) {
    outcome = error?.name === "IdpCallbackError" ? { ok: false, error: { type: "IdpCallbackError", reason: error.reason, message: error.message } } : { ok: false, error: describeError(error) };
  }
  authResults.push({ name: s.name, ...redactPkce(requests, outcome) });
}

function redactPkce(requests, outcome) {
  const v = outcome.ok ? outcome.value : null;
  if (!v || typeof v.codeVerifier !== "string") return { requests, outcome };
  const body = requests[0]?.body ?? {};
  const pkce = {
    stateLength: v.state.length,
    verifierLength: v.codeVerifier.length,
    stateSent: body.state === v.state,
    challengeIsS256: body.codeChallenge === s256(v.codeVerifier),
  };
  const redacted = requests.map((r) => ({ ...r, body: r.body && { ...r.body, state: "<state>", codeChallenge: "<challenge>" } }));
  return { requests: redacted, outcome: { ok: true, value: { url: v.url, pkce } } };
}

process.stdout.write(`${JSON.stringify({ scenarios: scenarioResults, schemaCases: schemaResults, sessions: sessionResults, auth: authResults }, null, 2)}\n`);
