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

// createAnalyticsWith 시나리오 — 같은 가짜 환경
const { createAnalyticsWith } = await import("@sayren/storefront-sdk/analytics");
const analyticsSpec = read("./analytics-scenarios.json");
const analyticsResults = [];
for (const s of analyticsSpec.scenarios) {
  const c = { ...analyticsSpec.defaults, ...s };
  let now = Date.UTC(2026, 0, 1);
  let href = c.href;
  let visible = c.visible;
  let prerendering = c.prerendering ?? false;
  let ids = 0;
  const cookies = new Map(Object.entries(s.cookies ?? {}).map(([k, v]) => [k, [v, Number.MAX_SAFE_INTEGER]]));
  const sent = [];
  const listeners = { visibilitychange: new Set(), pagehide: new Set(), prerenderingchange: new Set(), navigate: new Set(), interval: new Set() };
  const sub = (set, fn) => (set.add(fn), () => set.delete(fn));
  const emit = (set) => [...set].forEach((fn) => fn());
  const env = {
    now: () => now,
    href: () => href,
    referrer: () => c.referrer,
    hostname: () => c.hostname,
    getCookie: (name) => { const e = cookies.get(name); return e && e[1] > now ? e[0] : null; },
    setCookie: (name, value, maxAgeSec) => cookies.set(name, [value, now + maxAgeSec * 1000]),
    send: (url, body) => sent.push({ url, body: JSON.parse(body) }),
    randomId: () => `rid${String(++ids).padStart(13, "0")}`,
    visible: () => visible,
    prerendering: () => prerendering,
    webdriver: () => c.webdriver ?? false,
    on: (event, fn) => sub(listeners[event], fn),
    onNavigate: (fn) => sub(listeners.navigate, fn),
    setInterval: (fn) => sub(listeners.interval, fn),
  };
  const analytics = createAnalyticsWith({ baseUrl: c.baseUrl, storeCode: c.storeCode, ...s.options }, env);
  const steps = [];
  for (const step of s.steps) {
    let value = null;
    switch (step.op) {
      case "track": analytics.track(step.input); break;
      case "page": analytics.page(); break;
      case "setConsent": analytics.setConsent(step.value); break;
      case "ids": value = analytics.ids(); break;
      case "flush": analytics.flush(); break;
      case "destroy": analytics.destroy(); break;
      case "advance": now += step.ms; break;
      case "navigate": href = step.href; emit(listeners.navigate); break;
      case "visibility": visible = step.visible; emit(listeners.visibilitychange); break;
      case "pagehide": emit(listeners.pagehide); break;
      case "prerenderDone": prerendering = false; emit(listeners.prerenderingchange); break;
      case "interval": emit(listeners.interval); break;
    }
    steps.push({ op: step.op, value, sent: sent.length });
  }
  const listenerCounts = Object.fromEntries(Object.entries(listeners).map(([k, v]) => [k, v.size]));
  const cookieValues = Object.fromEntries([...cookies].sort().map(([k, v]) => [k, v[0]]));
  analyticsResults.push({ name: s.name, steps, sent, cookies: cookieValues, listeners: listenerCounts });
}

// 결제 — 복귀 주소 해석·정리(launch.ts 묶음), paymentResultOf·resolvePaymentMode, result()·start() 흐름
const launch = await import("./generated/launch.mjs");
const { createPayments, paymentResultOf, resolvePaymentMode } = await import("@sayren/storefront-sdk/payments");
const paySpec = read("./payments-scenarios.json");
const paymentResults = [];
for (const url of paySpec.urls) {
  paymentResults.push({ name: `readPaymentReturn ${url.slice(0, 120)}`, value: json(launch.readPaymentReturn(new URL(url).searchParams)) });
  paymentResults.push({ name: `scrubReturnUrl ${url.slice(0, 120)}`, value: launch.scrubReturnUrl(url) });
}
for (const status of paySpec.statuses) {
  paymentResults.push({ name: `paymentResultOf ${status.result}`, value: json(paymentResultOf(status)) });
  paymentResults.push({ name: `paymentResultOf ${status.result} closed`, value: json(paymentResultOf(status, { popupClosed: true })) });
}
for (const [mode, device] of paySpec.modes) paymentResults.push({ name: `resolvePaymentMode ${mode} ${device.userAgent}`, value: resolvePaymentMode(mode ?? undefined, device) });
for (const f of paySpec.flows) {
  const queue = [...f.responses];
  const requests = [];
  const fetch = async (url, init) => {
    requests.push({ method: init.method, url, body: init.body === undefined ? null : JSON.parse(init.body) });
    const r = queue.shift() ?? { status: 500, body: null };
    return new Response(r.status === 204 ? null : JSON.stringify(r.body), { status: r.status, headers: { "content-type": "application/json" } });
  };
  const client = sdk.createStorefrontClient({ baseUrl: "https://api.example.test/storefront/v1", storeCode: "demo", fetch });
  const env = { navigate() {}, currentUrl: () => paySpec.returnUrl, device: () => ({ userAgent: "x", coarsePointer: false, viewportWidth: 1000 }), replaceUrl() {} };
  const payments = createPayments({ client, returnUrl: paySpec.returnUrl, env });
  let outcome;
  try {
    const value = f.op === "result" ? await payments.result(f.url) : await payments.start(...f.args);
    outcome = { ok: true, value: json(value) };
  } catch (error) {
    outcome = { ok: false, error: describeError(error) };
  }
  paymentResults.push({ name: `flow ${f.name}`, requests, outcome });
}

process.stdout.write(`${JSON.stringify({ scenarios: scenarioResults, schemaCases: schemaResults, sessions: sessionResults, auth: authResults, analytics: analyticsResults, payments: paymentResults }, null, 2)}\n`);
