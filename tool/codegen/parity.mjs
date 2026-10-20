// Node·Dart 동작 대조 자료를 만든다.
// - tool/parity/generated/schema-cases.json: export 스키마마다 유효 예시·null·키 빼기·키 타입 바꾸기
// - tool/parity/generated/scenarios.json: 클라이언트 메서드마다 인자·서버 응답 예시
// - packages/storefront-sdk/tool/parity_generated.dart: Dart 쪽 스키마 표와 메서드 호출 표
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import * as z from "zod";
import { ident, interfaceMembers, optional, str, tsToDart } from "./emit.mjs";

const STRING_CANDIDATES = [
  "sample",
  "KR",
  "US",
  "12345",
  "01012345678",
  "0212345678",
  "+12025550123",
  "2026-01-01",
  "2026-01-01T00:00:00.000Z",
  "2026-01-01T09:00:00+09:00",
  "https://example.test/a.png",
  "buyer@example.test",
  "abc",
  "ABC",
  "a1!",
  "Passw0rd!",
  "1234567890",
  "01012345678",
  "R1",
  "v1",
  "a".repeat(8),
  "sample-id",
  "a".repeat(16), // 방문 분석 ID(16~64자)
  "a".repeat(43), // PKCE code_challenge·code_verifier(43자)
];
const NUMBER_CANDIDATES = [1, 10, 100, 1000, 0, 2, 5];

/** 런타임 zod 스키마로 예시 값을 만든다. 가능한 한 그 스키마를 통과하는 값을 고른다 */
export function sample(schema, depth = 0) {
  const d = schema._zod.def;
  const ok = (v) => schema.safeParse(v).success;
  const first = (cands) => cands.find(ok) ?? cands[0];
  switch (d.type) {
    case "string":
      return first(STRING_CANDIDATES);
    case "number":
      return first(NUMBER_CANDIDATES);
    case "boolean":
      return true;
    case "null":
      return null;
    case "unknown":
      return "x";
    case "enum":
      return Object.values(d.entries)[0];
    case "literal":
      return d.values[0];
    case "optional":
    case "nullable":
    case "default":
    case "catch":
      return sample(d.innerType, depth);
    case "lazy":
      return sample(d.getter(), depth + 1);
    case "pipe":
      return d.in._zod.def.type === "transform" ? sample(d.out, depth) : sample(d.in, depth);
    case "array": {
      if (depth > 2) return [];
      const one = [sample(d.element, depth + 1)];
      return first([one, [], [...one, sample(d.element, depth + 1)]]);
    }
    case "record":
      return { key: sample(d.valueType, depth + 1) };
    case "object": {
      const obj = {};
      for (const [k, v] of Object.entries(d.shape)) {
        const x = sample(v, depth + 1);
        if (x !== undefined) obj[k] = x;
      }
      if (ok(obj)) return obj;
      // 객체 규칙(refine)에 걸리면 선택 필드를 하나씩 빼 보고, 문자열 필드는 다른 후보를 넣어 본다
      for (const k of Object.keys(obj)) {
        if (!d.shape[k].safeParse(undefined).success) continue;
        const { [k]: _, ...rest } = obj;
        if (ok(rest)) return rest;
      }
      for (const k of Object.keys(obj)) {
        if (typeof obj[k] !== "string") continue;
        for (const c of STRING_CANDIDATES) if (d.shape[k].safeParse(c).success && ok({ ...obj, [k]: c })) return { ...obj, [k]: c };
      }
      return obj;
    }
    case "union":
      return first(d.options.map((o) => sample(o, depth)));
    case "intersection":
      return { ...sample(d.left, depth), ...sample(d.right, depth) };
    case "transform":
      return undefined;
    default:
      throw new Error(`sample ${d.type}`);
  }
}

const wrongType = (v) =>
  typeof v === "string" ? 12345 : typeof v === "number" ? "x" : typeof v === "boolean" ? "x" : v === null ? 1 : "x";

function unwrapObject(schema) {
  let s = schema;
  for (;;) {
    const d = s._zod.def;
    if (d.type === "object") return s;
    if (d.type === "lazy") s = d.getter();
    else if (["optional", "nullable", "default", "catch"].includes(d.type)) s = d.innerType;
    else return null;
  }
}

/** 응답 스키마 TS 식(Dart 식과 같은 모양) → 런타임 스키마 */
function runtimeSchema(expr, runtime) {
  const m = /^(z\.array|pageSchema)<.*>\((\w+)\)$/.exec(expr);
  if (m) return m[1] === "z.array" ? z.array(runtime[m[2]]) : runtime.pageSchema(runtime[m[2]]);
  return runtime[expr];
}

export function generateParity({ runtime, ir, emit, scan, out, parityDir, methods, known, library, clientClass, testImport, typedefs }) {
  mkdirSync(parityDir, { recursive: true });

  // 1) 스키마 대조
  const schemaNames = [...scan.values()].filter((e) => e.kind === "const" && runtime[e.name]?._zod).map((e) => e.name);
  const cases = [];
  for (const name of schemaNames) {
    const schema = runtime[name];
    const valid = sample(schema);
    cases.push({ schema: name, label: "sample", input: valid });
    cases.push({ schema: name, label: "null", input: null });
    const obj = unwrapObject(schema);
    if (obj && valid && typeof valid === "object" && !Array.isArray(valid)) {
      for (const key of Object.keys(valid)) {
        const { [key]: _, ...rest } = valid;
        cases.push({ schema: name, label: `-${key}`, input: rest });
        cases.push({ schema: name, label: `${key}:wrong`, input: { ...valid, [key]: wrongType(valid[key]) } });
        // 문자열 형식(이메일·URL·정규식·길이) 검사가 같은지 — 타입은 맞고 형식만 틀린 값
        if (typeof valid[key] === "string") cases.push({ schema: name, label: `${key}:format`, input: { ...valid, [key]: "%" } });
      }
    }
    if (Array.isArray(valid)) cases.push({ schema: name, label: "[wrong]", input: [wrongType(valid[0] ?? "x")] });
  }
  writeFileSync(path.join(parityDir, "schema-cases.json"), `${JSON.stringify(cases, null, 2)}\n`);

  // 2) 메서드 대조
  const schemaOfType = new Map([...ir.typeOfSchema].map(([s, t]) => [t, s]));
  const argSample = (type) => {
    if (type.endsWith("?")) return argSample(type.slice(0, -1));
    if (type === "String") return "id-1";
    if (type === "int" || type === "num") return 1;
    if (type === "bool") return true;
    if (type === "Object") return { note: "x" };
    if (/^List<.+>$/.test(type)) return [argSample(type.slice(5, -1))];
    if (type === "Map<String, Object?>") return { note: "x" };
    const inputOf = scan.get(type)?.inferOf;
    if (inputOf?.startsWith("input:")) return sample(runtime[inputOf.slice(6)]);
    const cls = ir.classes.get(type);
    if (cls?.schemaRef) return sample(runtime[cls.schemaRef]);
    const alias = scan.get(type);
    if (alias?.kind === "type" && !alias.inferOf) {
      // (typeof XS)[number] — 상수 배열의 첫 값, 그 밖의 문자열 별칭은 임의 문자열
      const m = /typeof\s+(\w+)/.exec(alias.typeText ?? "");
      if (m && Array.isArray(runtime[m[1]])) return runtime[m[1]][0];
      if (known(type) === "String" || tsToDart(type, known) === "String") return "id-1";
    }
    const schemaName = schemaOfType.get(type);
    if (schemaName) return sample(runtime[schemaName]);
    const iface = scan.get(type);
    if (iface?.kind === "interface") return ifaceSample(type);
    throw new Error(`인자 예시를 만들 수 없습니다: ${type}`);
  };
  const fieldSample = (f) => {
    const t = tsToDart(f.type, known);
    if (process.env.DEBUG_FIELDS) console.error(f.name, f.type, t);
    if (t === "int") return 1;
    if (t === "bool") return true;
    if (t === "String") {
      const s = schemaOfType.get(f.type);
      return s ? sample(runtime[s]) : `${f.name}-1`;
    }
    return argSample(t);
  };
  const ifaceMembers = (name) => {
    const ms = interfaceMembers(scan.get(name).decl);
    const parent = ms.find((m) => m.extends)?.extends;
    return [...(parent ? ifaceMembers(parent) : []), ...ms.filter((m) => m.name)];
  };
  const ifaceSample = (name) => Object.fromEntries(ifaceMembers(name).map((m) => [m.name, fieldSample(m)]));

  const generatedMethods = methods.filter((m) => !m.override);
  const scenarios = generatedMethods.map((m) => {
    const args = m.params.map((p) =>
      p.kind === "named" ? Object.fromEntries(m.namedFields.map((f) => [f.name, fieldSample(f)])) : p.init === "{}" ? { note: "x" } : argSample(p.type),
    );
    const response = m.isVoid
      ? { status: 204 }
      : {
          status: 200,
          body: { meta: { status: 200, code: "OK", message: "OK", isSuccess: true }, data: sample(runtimeSchema(m.schema.expr, runtime)), error: null },
        };
    return {
      name: `${[...m.ns, m.name].join(".")} 생성 예시`,
      call: [...m.ns, m.name].join("."),
      args,
      options: { accessToken: "member-token", cartToken: "cart-1" },
      response,
    };
  });
  writeFileSync(path.join(parityDir, "scenarios.json"), `${JSON.stringify({ scenarios }, null, 2)}\n`);

  // 3) Dart 표
  /** JSON 값 식 → Dart 타입 값 식 */
  const convValue = (type, src) => {
    if (type.endsWith("?") && type !== "Object?") return `(${src} == null ? null : ${convValue(type.slice(0, -1), src)})`;
    if (type === "Object?" || type === "Object") return src;
    if (type === "Map<String, Object?>") return `(${src} as Map).cast<String, Object?>()`;
    if (["String", "int", "num", "bool"].includes(type)) return `${src} as ${type}`;
    const list = /^List<(.+)>$/.exec(type);
    if (list) return `<${list[1]}>[for (final x in (${src} as List)) ${convValue(list[1], "x")}]`;
    if (ir.classes.has(type)) return `${type}.fromJson((${src} as Map).cast<String, Object?>())`;
    const aliasOf = typedefs.get(type);
    if (aliasOf && aliasOf !== type) return convValue(aliasOf, src);
    const input = scan.get(type)?.inferOf;
    if (input?.startsWith("input:")) return convValue(ir.outputName(input.slice(6)), src);
    if (scan.get(type)?.kind === "interface") {
      const fields = ifaceMembers(type).map((f) => `${ident(f.name)}: ${convValue(optional(tsToDart(f.type, known), f.optional), `(${src} as Map)[${str(f.name)}]`)}`);
      return `${type}(${fields.join(", ")})`;
    }
    if (tsToDart(type, known) === "String") return `${src} as String`;
    throw new Error(`Dart 인자 변환을 만들 수 없습니다: ${type}`);
  };
  const conv = (type, src, isOptional) => {
    if (!isOptional) return convValue(type, src);
    const i = /a\[(\d+)\]/.exec(src)[1];
    return `(a.length > ${i} && ${src} != null ? ${convValue(type.replace(/\?$/, ""), src)} : null)`;
  };
  const callLines = generatedMethods.map((m) => {
    const args = [];
    m.params.forEach((p, i) => {
      if (p.kind === "named") {
        for (const f of m.namedFields) {
          const t = tsToDart(f.type, known);
          args.push(`${ident(f.name)}: ${convValue(f.required ? t : optional(t, true), `(a[${i}] as Map)[${str(f.name)}]`)}`);
        }
      } else args.push(conv(p.type, `a[${i}]`, p.optional));
    });
    return `  ${str([...m.ns, m.name].join("."))}: (c, a) => c.${[...m.ns, m.name].join(".")}(${args.join(", ")}),`;
  });
  const dart = `// GENERATED by tool/codegen/generate.mjs — 대조 하네스(tool/parity)가 쓰는 표.
// ignore_for_file: type_annotate_public_apis, public_member_api_docs

import 'package:${library}/${library}.dart';

/// 대조할 export 스키마
final Map<String, ZodType<Object?>> schemas = {
${schemaNames.map((n) => `  ${str(n)}: ${n},`).join("\n")}
};

/// 시나리오의 \`call\` 이름 → 타입 있는 호출. JSON 인자를 Dart 인자로 바꾼다
final Map<String, Future<Object?> Function(${clientClass} c, List<Object?> a)> calls = {
${callLines.join("\n")}
};
`;
  writeFileSync(path.join(out, "tool/parity_generated.dart"), dart);
  writeFileSync(path.join(out, "test/getters_test.dart"), gettersTest({ ir, emit, scan, schemaNames: schemaNames.filter((n) => runtime[n].safeParse(sample(runtime[n])).success), known, library, testImport, parityDir: path.relative(out, parityDir) }));
}

/**
 * 모든 클래스의 모든 getter를 읽어 보는 테스트 — 대조 하네스는 toJson만 비교하므로 getter 캐스트(`as int` 등)는 여기서 확인한다.
 * 스키마 예시(schema-cases.json의 sample)를 파싱한 결과에서 시작해 중첩 모델까지 따라간다.
 */
function gettersTest({ ir, emit, scan, schemaNames, known, library, testImport, parityDir }) {
  const isClass = (t) => ir.classes.has(t) || scan.get(t)?.kind === "interface";
  const fn = (t) => `_touch${t}`;
  const touch = (t, e) => {
    const nn = t.endsWith("?");
    const base = nn ? t.slice(0, -1) : t;
    let body;
    if (base.startsWith("List<")) {
      const inner = base.slice(5, -1);
      body = isClass(inner.replace(/\?$/, "")) ? `for (final x in ${nn ? `${e}!` : e}) ${touch(inner, "x")}` : `${nn ? `${e}!` : e}.length;`;
    } else if (base.startsWith("Map<")) body = `${nn ? `${e}!` : e}.length;`;
    else if (isClass(base)) body = `${fn(base)}(${nn ? `${e}!` : e});`;
    else body = `${e};`;
    return nn ? `if (${e} != null) { ${body} }` : body;
  };
  const funcs = [];
  for (const cls of ir.classes.values()) {
    if (cls.kind === "object") {
      const shown = cls.fields.filter((f) => !(["optional", "catch"].includes(f.node.k) && emit.deprecatedField(cls.root, f)));
      const lines = shown.map((f) => `  ${touch(emit.type(f.node), `v.${ident(f.key)}`)}`);
      funcs.push(`void ${fn(cls.name)}(${cls.name} v) {\n  v.toJson();\n${lines.join("\n")}\n}`);
    } else {
      const variants = emit.variantClasses(cls.node);
      if (!variants) continue;
      funcs.push(`void ${fn(cls.name)}(${cls.name} v) {\n${variants.map((x) => `  if (v is ${x}) ${fn(x)}(v);`).join("\n")}\n}`);
    }
  }
  for (const e of scan.values()) {
    if (e.kind !== "interface" || !emit.unionBases?.has(e.name)) continue;
    const ms = interfaceMembers(e.decl).filter((m) => m.name);
    funcs.push(`void ${fn(e.name)}(${e.name} v) {\n${ms.map((m) => `  v.${ident(m.name)};`).join("\n")}\n}`);
  }
  const roots = schemaNames
    .map((n) => [n, emit.type(ir.build(n))])
    .filter(([, t]) => isClass(t.replace(/\?$/, "")) || /^List<(\w+)>$/.test(t));
  return `// GENERATED by tool/codegen/generate.mjs — 모든 모델 getter를 스키마 예시로 읽어 본다.
// ignore_for_file: unnecessary_statements, unnecessary_null_comparison, unnecessary_non_null_assertion, unused_element

import 'dart:convert';
import 'dart:io';

import 'package:${library}/${library}.dart';
import '${testImport}';

void main() {
  final samples = <String, Object?>{
    for (final c in (jsonDecode(File('${parityDir}/schema-cases.json').readAsStringSync()) as List)
        .cast<Map<String, Object?>>())
      if (c['label'] == 'sample') c['schema'] as String: c['input'],
  };
${roots.map(([n, t]) => `  test(${str(n)}, () {\n    final v = ${n}.parse(samples[${str(n)}]);\n    ${touch(t, "v")}\n  });`).join("\n")}
}

${funcs.join("\n\n")}
`;
}
