// Node SDK(@sayren/store-sdk)로 스키마·함수 대조 자료를 실행하고 결과를 JSON으로 쓴다.
import { readdirSync, readFileSync } from "node:fs";
import * as sdk from "@sayren/store-sdk";

const read = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url), "utf8"));
const json = (v) => (v === undefined ? null : JSON.parse(JSON.stringify(v, (_, x) => (x instanceof Set ? [...x] : x))));

const schemaCases = read("../generated/store/schema-cases.json");
const schemaResults = schemaCases.map((c) => {
  const r = sdk[c.schema].safeParse(c.input);
  return {
    name: `${c.schema} ${c.label}`,
    outcome: r.success ? { ok: true, value: json(r.data) } : { ok: false, issues: r.error.issues.map((i) => ({ code: i.code, path: i.path })) },
  };
});

// JSON으로 나타낼 수 없는 인자 — { "$date": ISO } → Date, { "$map": [[k, v], …] } → Map, { "$set": […] } → Set,
// { "$lookup": { 키: 값 } } → 키로 값을 찾는 함수(없으면 undefined). Dart 어댑터는 같은 표기를 DateTime·Map·Set·함수로 읽는다
const revive = (v) => {
  if (Array.isArray(v)) return v.map(revive);
  if (!v || typeof v !== "object") return v;
  if ("$date" in v) return new Date(v.$date);
  if ("$map" in v) return new Map(v.$map.map(([k, x]) => [k, revive(x)]));
  if ("$set" in v) return new Set(v.$set.map(revive));
  if ("$lookup" in v) {
    const table = revive(v.$lookup);
    return (key) => (Object.hasOwn(table, key) ? table[key] : undefined);
  }
  return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, revive(x)]));
};

// 손으로 쓴 함수 — functions/*.json의 { name, fn, args }를 그대로 부른다
const functionResults = [];
for (const file of readdirSync(new URL("./functions", import.meta.url)).filter((f) => f.endsWith(".json")).sort()) {
  for (const c of read(`./functions/${file}`)) {
    let outcome;
    try {
      outcome = { value: json(sdk[c.fn](...revive(c.args))) };
    } catch {
      outcome = { throws: true };
    }
    functionResults.push({ name: `${file} ${c.name}`, outcome });
  }
}

// 요청 기록 — 폼 본문은 키·값 목록, JSON 본문은 값이다
function recordRequest(requests, url, init, mask) {
  const headers = Object.fromEntries(Object.entries(init.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]).sort());
  let body = null;
  if (typeof init.body === "string") {
    body = headers["content-type"] === "application/x-www-form-urlencoded" ? [...new URLSearchParams(init.body)] : JSON.parse(init.body);
  } else if (init.body instanceof Blob) {
    body = { bytes: [...new Uint8Array(await_(init.body))] };
  }
  requests.push(mask({ method: init.method ?? "GET", url: String(url), headers, body }));
}
// Blob 바이트는 fetch 안에서 미리 읽어 둔다
const blobBytes = new WeakMap();
const await_ = (blob) => blobBytes.get(blob);

function describeError(error) {
  if (error instanceof sdk.ApprovalPendingError) {
    return { type: "ApprovalPendingError", code: error.code, httpStatus: error.httpStatus, approvalId: error.approvalId, status: error.status, message: error.message };
  }
  if (error instanceof sdk.ApiError) {
    return { type: "ApiError", status: error.status, code: error.code, message: error.message, traceId: error.traceId ?? null, details: error.details ?? null, docs: error.docs ?? null, body: error.body ?? null };
  }
  if (error?.name === "ZodError") return { type: "ZodError", issues: error.issues.map((i) => ({ code: i.code, path: i.path })) };
  return { type: "Error", message: error?.message ?? null };
}

const toResponse = (r) =>
  new Response(r.status === 204 ? null : JSON.stringify(r.body), { status: r.status, headers: { "content-type": "application/json" } });

// 클라이언트 시나리오 — 생성 예시 + 손 시나리오(scenarios.json)
const hand = read("./scenarios.json");
const generated = read("../generated/store/scenarios.json");
const scenarioResults = [];
for (const s of [...hand.scenarios, ...generated.scenarios]) {
  const requests = [];
  const queue = s.responses ? [...s.responses] : null;
  const fetch = async (url, init = {}) => {
    if (init.body instanceof Blob) blobBytes.set(init.body, await init.body.arrayBuffer());
    recordRequest(requests, url, init, (x) => x);
    return toResponse(queue ? (queue.shift() ?? { status: 500, body: null }) : s.response);
  };
  const options = { ...hand.defaults.options, ...(s.options ?? {}) };
  const client = sdk.createStoreClient({ baseUrl: options.baseUrl, accessToken: options.accessToken, storeId: options.storeId, fetch });
  const parts = s.call.split(".");
  const target = parts.slice(0, -1).reduce((o, k) => o[k], client);
  const args = s.args.map((a) =>
    a && typeof a === "object" && "$file" in a ? new File([new Uint8Array(a.$file.bytes)], a.$file.name, { type: a.$file.type }) : a,
  );
  let outcome;
  try {
    outcome = { ok: true, value: json(await target[parts.at(-1)](...args)) };
  } catch (error) {
    outcome = { ok: false, error: describeError(error) };
  }
  scenarioResults.push({ name: s.name, requests, outcome });
}

// 세션·OAuth 시나리오 — 무작위 값(state·verifier·challenge)은 자리표시로 바꾼다
const { createHash } = await import("node:crypto");
const sessionSpec = read("./session-scenarios.json");
const tick = () => new Promise((r) => setTimeout(r, 0));
const sessionResults = [];
for (const s of sessionSpec.scenarios) {
  const store = new Map(Object.entries(s.storage));
  const storage = { get: (k) => store.get(k) ?? null, set: (k, v) => store.set(k, v), remove: (k) => store.delete(k) };
  const secrets = {};
  const mask = (v) => {
    let text = JSON.stringify(v);
    for (const [name, value] of Object.entries(secrets)) if (value) text = text.split(value).join(`<${name}>`);
    return JSON.parse(text);
  };
  const readPkce = () => {
    const raw = store.get("sayren.store.pkce");
    if (!raw) return;
    const blob = JSON.parse(raw);
    secrets.verifier = blob.verifier;
    secrets.state = blob.state;
    secrets.challenge = createHash("sha256").update(blob.verifier).digest("base64url");
  };
  const queue = [...s.responses];
  const requests = [];
  const fetch = async (url, init = {}) => {
    recordRequest(requests, url, init, (x) => x);
    return toResponse(queue.shift() ?? { status: 500, body: null });
  };
  const { baseUrl, authServer, clientId } = sessionSpec.defaults;
  const session = sdk.createStoreSession({ baseUrl, authServer, clientId, storage, fetch });
  let notified = 0;
  session.subscribe(() => notified++);
  const client = sdk.createStoreClient({ baseUrl, fetch, ...(s.noSession ? {} : { session }) });
  const steps = [];
  for (const step of s.steps) {
    let outcome;
    try {
      const args = (step.args ?? []).map((a) => (a === "$state" ? secrets.state : a));
      let value;
      switch (step.op) {
        case "authorize": value = await session.authorize(...args); readPkce(); break;
        case "handleCallback": value = await session.handleCallback(...args); break;
        case "refresh": value = await session.refresh(); break;
        case "refreshTwice": value = await Promise.all([session.refresh(), session.refresh()]); break;
        case "logout": value = await session.logout(); break;
        case "clear": value = session.clear(); break;
        case "setTokens": value = session.setTokens(...args); break;
        case "getToken": value = session.getToken(); break;
        case "userinfo": value = await session.userinfo(); break;
        case "clientUserinfo": value = await client.userinfo(); break;
        case "clientAuthorize": value = await client.authorize(...args); readPkce(); break;
        case "tokens": value = { accessToken: session.accessToken, refreshToken: session.refreshToken, clientAccessToken: client.accessToken, clientRefreshToken: client.refreshToken }; break;
        case "call": {
          const parts = step.call.split(".");
          value = await parts.slice(0, -1).reduce((o, k) => o[k], client)[parts.at(-1)](...args);
          break;
        }
        case "buildAuthorizeUrl": value = sdk.buildAuthorizeUrl(...args); break;
        case "exchangeAuthorizationCode": value = await sdk.exchangeAuthorizationCode({ ...args[0], fetch }); break;
        case "refreshUserToken": value = await sdk.refreshUserToken({ ...args[0], fetch }); break;
        case "createPkcePair": {
          const pair = await sdk.createPkcePair();
          value = { verifierLength: pair.verifier.length, challengeOk: createHash("sha256").update(pair.verifier).digest("base64url") === pair.challenge };
          break;
        }
      }
      outcome = { ok: true, value: json(value) };
    } catch (error) {
      outcome = { ok: false, error: describeError(error) };
    }
    await tick();
    steps.push(mask({ op: step.op, outcome, notified, storage: Object.fromEntries([...store].sort()) }));
  }
  sessionResults.push({ name: s.name, requests: mask(requests), steps });
}

process.stdout.write(
  JSON.stringify({ schemaCases: schemaResults, functions: functionResults, scenarios: scenarioResults, sessions: sessionResults }),
);
