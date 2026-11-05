// Node 모듈 로더 훅 — SDK dist의 `strictRequest`가 만든 복제본과 원본을 잇는다.
//
// `strictRequest(schema)`(관리 API 요청 스키마, 이슈 #193)는 안쪽 객체까지 `catchall: never`로 복제한다. 복제본은 원본과 def가 달라
// 생성기가 공유 스키마(export된 하위 스키마)를 알아보지 못하고 익명 클래스를 새로 만든다. 그래서 dist 원문에 기록 코드를 넣어
// 복제본 def → 원본(`globalThis.__sayrenStrictOrigin`)과 strictRequest 결과 def(`globalThis.__sayrenStrictRoots`)를 남긴다(`.describe()` 복제는 def를 공유한다).
// 생성기는 원본으로 IR을 만들고, 결과 자리에 Dart `strict`(안쪽까지 모르는 키 거부)를 붙인다.

const STRICT_FN = "function strictRequest(schema) {\n\treturn strictOf(schema, /* @__PURE__ */ new Map());\n}";
const SEEN_SET = "\tseen.set(schema, next);";

export async function load(url, context, nextLoad) {
  const result = await nextLoad(url, context);
  if (!url.includes("/@sayren/") || !url.includes("/dist/")) return result;
  const source = String(result.source ?? "");
  if (!source.includes("function strictRequest(schema)")) return result;
  if (!source.includes(STRICT_FN) || !source.includes(SEEN_SET)) {
    throw new Error(`strict-hooks.mjs: ${url}의 strictRequest 원문이 바뀌었습니다. 훅의 원문을 맞추십시오`);
  }
  const patched = source
    .replace(
      STRICT_FN,
      "function strictRequest(schema) {\n\tconst out = strictOf(schema, /* @__PURE__ */ new Map());\n\t(globalThis.__sayrenStrictRoots ??= new WeakSet()).add(out._zod.def);\n\treturn out;\n}",
    )
    .replace(
      SEEN_SET,
      "\tseen.set(schema, next);\n\tif (next !== schema) (globalThis.__sayrenStrictOrigin ??= new WeakMap()).set(next._zod.def, schema);",
    );
  return { ...result, source: patched, shortCircuit: true };
}
