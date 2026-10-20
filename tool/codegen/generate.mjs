// Node SDK(npm 패키지)에서 Dart SDK 코드를 생성한다.
//
//   cd tool/codegen && npm install && node generate.mjs
//
// 원천: 패키지의 TS 원본(src, export·JSDoc·인터페이스·클라이언트 정의)과 런타임 zod 스키마(검증 규칙·기본값·describe).
// 생성할 수 없는 코드(함수·클로저 구현)는 같은 라이브러리의 `{파일}.manual.dart` part에 손으로 쓴다.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as esbuild from "esbuild";
import * as z from "zod";
import { generateClient } from "./client.mjs";
import { DartEmitter, doc, formal, ident, interfaceMembers, lit, optional, read, regex, str, ts, tsToDart } from "./emit.mjs";
import { IrBuilder, pascal } from "./ir.mjs";
import { generateParity } from "./parity.mjs";
import { packageSrc, scanEntry } from "./scan.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));

/** 생성 대상 — Node 패키지 하나가 Dart 패키지 하나다 */
const TARGETS = {
  storefront: {
    PKG: "@sayren/storefront-sdk",
    OUT: path.join(here, "../../packages/storefront-sdk"),
    LIBRARY: "sayren_storefront_sdk",
    TEST_IMPORT: "package:flutter_test/flutter_test.dart",
    PARITY: path.join(here, "../parity/generated"),
    /** 손으로 쓴 파일이 맡는 export — 생성하지 않는다 */
    HAND_WRITTEN: {
      "http.ts": ["ApiError", "buildQuery", "Query", "TokenSource"],
      "client.ts": ["StorefrontClient", "StorefrontClientOptions", "createStorefrontClient"],
      "analytics-ids.ts": ["analyticsIdsFromCookie"],
      "session.ts": ["createStorefrontSession", "SessionStorage", "StorefrontSessionOptions", "StorefrontSession", "STOREFRONT_SESSION_KEYS"],
    },
    /** manual part가 쓰는 추가 import(part는 import를 둘 수 없다) */
    EXTRA_IMPORTS: {
      "schemas/currency.ts": ["import 'dart:math' as math;"],
      "schemas/product-options.ts": ["import 'package:unorm_dart/unorm_dart.dart' as unorm;"],
    },
    /** manual part가 맡는 상수 */
    MANUAL_CONSTS: new Set(["CURRENCIES", "KRW_MONEY_RULES"]),
    CLIENT: {
      fn: "createStorefrontClient",
      cls: "StorefrontClient",
      session: "StorefrontSession",
      sessionFactory: "createStorefrontSession",
      base: "/storefront/v1",
      sessionMembers: ["accessToken", "refreshToken", "userinfo"],
      http: { type: "Http", callees: { http: "_http" } },
      doc: "스토어프론트 API 클라이언트입니다.",
    },
    ENTRY_EXPORTS: [
      "export 'src/analytics-ids.dart';",
      "export 'src/client.dart';",
      "export 'src/http.dart' show ApiError, Fetch, Query, TokenSource, buildQuery;",
      "export 'src/session.dart';",
    ],
    LAUNCH: true,
  },
  store: {
    PKG: "@sayren/store-sdk",
    OUT: path.join(here, "../../packages/store-sdk"),
    LIBRARY: "sayren_store_sdk",
    TEST_IMPORT: "package:test/test.dart",
    PARITY: path.join(here, "../parity/generated/store"),
    HAND_WRITTEN: {
      "http.ts": ["ApiError", "ApprovalPendingError", "APPROVAL_ALREADY_DECIDED_CODE", "APPROVAL_REQUIRED_CODE", "buildQuery", "Query", "TokenSource"],
      "client.ts": ["StoreClient", "StoreClientOptions", "createStoreClient"],
      "oauth.ts": ["buildAuthorizeUrl", "createPkcePair", "exchangeAuthorizationCode", "OAuthTokenResponse", "oauthTokenResponseSchema", "refreshUserToken"],
      "session.ts": ["AuthorizeOptions", "createStoreSession", "SessionStorage", "STORE_SESSION_KEYS", "StoreAuthServer", "StoreSession", "StoreSessionOptions"],
    },
    EXTRA_IMPORTS: {
      "schemas/currency.ts": ["import 'dart:math' as math;"],
      "schemas/product.ts": ["import 'package:unorm_dart/unorm_dart.dart' as unorm;"],
      "schemas/app-manifest.ts": ["import 'dart:convert';", "import '../url.dart';"],
      "schemas/store.ts": ["import '../url.dart';"],
      "schemas/starter.ts": ["import '../url.dart';"],
      "schemas/storefront-hosting.ts": ["import '../url.dart';", "import 'package:unorm_dart/unorm_dart.dart' as unorm;"],
    },
    MANUAL_CONSTS: new Set(["CURRENCIES", "KRW_MONEY_RULES"]),
    /** zod 런타임은 스토어프론트 패키지 것을 그대로 복사한다(Node 두 SDK가 같은 zod를 쓰는 것과 같다) */
    ZOD_FROM: path.join(here, "../../packages/storefront-sdk/lib/src/zod.dart"),
    CLIENT: {
      fn: "createStoreClient",
      cls: "StoreClient",
      session: "StoreSession",
      sessionFactory: "createStoreSession",
      base: "/v1",
      sessionMembers: ["accessToken", "refreshToken", "authorize", "userinfo"],
      http: { type: "_Https", callees: { userHttp: "_http.user", storeHttp: "_http.store" } },
      imports: ["import 'package:cross_file/cross_file.dart';"],
      doc: "관리 API 클라이언트입니다.",
    },
    ENTRY_EXPORTS: [
      "export 'src/client.dart';",
      "export 'src/http.dart' show APPROVAL_ALREADY_DECIDED_CODE, APPROVAL_REQUIRED_CODE, ApiError, ApprovalPendingError, Fetch, Query, TokenSource, buildQuery;",
      "export 'src/oauth.dart';",
      "export 'src/session.dart';",
    ],
  },
};

async function generate(T) {
  const { PKG, OUT, HAND_WRITTEN, EXTRA_IMPORTS, MANUAL_CONSTS } = T;
  const LIB = path.join(OUT, "lib/src");
  if (T.ZOD_FROM) {
    const zod = readFileSync(T.ZOD_FROM, "utf8");
    writeFileSync(path.join(LIB, "zod.dart"), `// COPIED by tool/codegen/generate.mjs from packages/storefront-sdk/lib/src/zod.dart — 원본을 고친다.\n${zod}`);
  }
  /** 이번 범위가 아닌 export */
  const EXCLUDED = new Set(T.EXCLUDED ?? []);

  const runtime = await import(PKG);
  const src = packageSrc(PKG);
  const exportsList = scanEntry(src, "index.ts")
    .filter((e) => !EXCLUDED.has(e.name) && !e.deprecated) // Node `@deprecated`는 만들지 않는다
    .filter((e, i, all) => all.findIndex((x) => x.name === e.name) === i);
  const scan = new Map(exportsList.map((e) => [e.name, e]));
  const ir = new IrBuilder(scan, runtime, z);
  const emit = new DartEmitter(ir, scan);

  const isSchema = (e) => e.kind === "const" && runtime[e.name]?._zod;
  // 손으로 쓴 파일(http·client·session 등)이 아닌 export 원본 파일을 모두 생성한다
  const files = [...new Set(exportsList.map((e) => e.file))].filter((f) => !(f in HAND_WRITTEN));

  // 1) 모든 스키마 IR — 파일 순서대로(익명 클래스 이름은 먼저 만난 자리가 정한다)
  for (const e of exportsList) if (isSchema(e)) ir.build(e.name);
  // 모양(shape) 상수 안의 스키마
  const shapeIrs = new Map();
  for (const e of exportsList) {
    const v = runtime[e.name];
    if (e.kind === "const" && v && !v._zod && !(v instanceof RegExp) && !Array.isArray(v) && typeof v === "object" && Object.keys(v).length && Object.values(v).every((x) => x?._zod)) {
      shapeIrs.set(
        e.name,
        Object.entries(v).map(([key, s]) => [key, ir.node(s, { root: e.name, file: e.file, owner: pascal(e.name), naming: `${pascal(e.name)}${pascal(key)}`, propPath: [key], isRoot: false })]),
      );
    }
  }
  if (ir.missingHooks.length && !process.env.ALLOW_MISSING_HOOKS) {
    console.error(`hooks.mjs에 Dart 구현이 없는 클로저:\n  ${[...new Set(ir.missingHooks)].join("\n  ")}`);
    process.exit(1);
  }

  // 2) 인터페이스 — 스키마 출력이 아닌 것만 클래스로 만든다
  const schemaOutputs = new Set([...ir.typeOfSchema.values()]);
  const interfaces = exportsList.filter((e) => e.kind === "interface" && !schemaOutputs.has(e.name) && !Object.values(HAND_WRITTEN).flat().includes(e.name));
  const transformOutputs = new Set([...ir.classes.values()].flatMap(() => []));
  for (const n of collectTransforms()) transformOutputs.add(n);

  // 3) 이름 → Dart 타입(인터페이스·파라미터 변환용)
  const typedefs = new Map(); // 이름 → Dart 타입
  for (const e of exportsList) {
    if (e.kind !== "type") continue;
    if (e.inferOf && !e.inferOf.startsWith("input:")) {
      const node = ir.build(e.inferOf);
      const t = emit.type(node);
      // 출력이 생성 클래스면 그 클래스가 타입이다(typedef를 두지 않는다)
      if (!(ir.classes.has(t) && t === e.name)) typedefs.set(e.name, t);
    } else if (!Object.values(HAND_WRITTEN).flat().includes(e.name)) {
      typedefs.set(e.name, stringLike(e) ? "String" : null);
    }
  }
  const known = (name) => {
    if (name.startsWith("schema:")) return runtime[name.slice(7)]?._zod ? emit.type(ir.build(name.slice(7))) : null;
    if (name.startsWith("partial:")) {
      // Partial<인터페이스> — 모든 필드가 선택인 레코드
      const e = scan.get(name.slice(8));
      if (e?.kind !== "interface") return null;
      const ms = interfaceMembers(e.decl).filter((m) => m.name);
      return `({${ms.map((m) => `${tsToDart(m.type, known).replace(/\?$/, "")}? ${ident(m.name)}`).join(", ")}})`;
    }
    if (name.startsWith("index:")) {
      const v = runtime[name.slice(6)];
      if (Array.isArray(v) && v.every((x) => typeof x === "string")) return "String";
      if (Array.isArray(v) && v.every((x) => Number.isInteger(x))) return "int";
      return null;
    }
    if (typedefs.has(name)) return name;
    if (ir.classes.has(name) || interfaces.some((i) => i.name === name) || schemaOutputs.has(name)) return name;
    return null;
  };

  // 4) union 소속 — 형태 클래스가 구현할 union과 공통 getter
  emit.unionBases = new Map();
  const unionInfo = new Map();
  for (const cls of ir.classes.values()) {
    if (cls.kind !== "union") continue;
    const variants = emit.variantClasses(cls.node);
    if (!variants) continue;
    const fieldsOf = (name) => {
      const c = ir.classes.get(name);
      if (c) return c.fields.map((f) => ({ key: f.key, t: emit.type(f.node), doc: emit.fieldDoc(c.root, f) }));
      const i = scan.get(name);
      return interfaceMembers(i.decl).filter((m) => m.name).map((m) => ({ key: m.name, t: optional(tsToDart(m.type, known), m.optional), doc: formal(m.doc) }));
    };
    const all = variants.map(fieldsOf);
    const common = all[0].filter((f) => all.every((fs) => fs.some((g) => g.key === f.key && g.t === f.t)));
    const sealed = variants.every((v) => fileOfClass(v) === cls.file);
    unionInfo.set(cls.name, { variants, common, sealed });
    for (const v of variants) {
      const b = emit.unionBases.get(v) ?? { implements: [], overrides: new Set() };
      if (!b.implements.includes(cls.name)) b.implements.push(cls.name);
      for (const c of common) b.overrides.add(c.key);
      emit.unionBases.set(v, b);
    }
  }

  function fileOfClass(name) {
    return ir.classes.get(name)?.file ?? scan.get(name)?.file;
  }

  function collectTransforms() {
    const out = new Set();
    for (const c of ir.classes.values()) {
      if (c.kind !== "union") continue;
      for (const o of c.node.options) if (o.k === "pipe" && o.out.k === "transform" && o.out.hook.output) out.add(o.out.hook.output);
    }
    return out;
  }

  function stringLike(e) {
    const checker = e.checker;
    const type = checker.getTypeAtLocation(e.decl.name);
    const parts = type.isUnion() ? type.types : [type];
    return parts.every(
      (t) => t.flags & ts.TypeFlags.StringLike || (t.isIntersection() && t.types.some((x) => x.flags & ts.TypeFlags.String)),
    );
  }

  // 5) 파일별 출력
  const manualNeeded = new Map(); // 파일 → 손으로 쓸 이름
  const out = new Map(); // dart 파일 → 내용
  for (const file of files) {
    const dartFile = file.replace(/\.ts$/, ".dart");
    const base = path.basename(dartFile, ".dart");
    const manualPath = path.join(LIB, path.dirname(dartFile), `${base}.manual.dart`);
    const decls = [];
    const emittedClasses = new Set();
    const emitClassTree = (rootName) => {
      // 이 export가 만든 클래스(자기 출력 + 익명 클래스)를 만든 순서대로 낸다
      for (const cls of ir.classes.values()) {
        if (cls.root !== rootName || emittedClasses.has(cls.name)) continue;
        emittedClasses.add(cls.name);
        const typeExport = cls.schemaRef ? [...ir.typeOfSchema].find(([s]) => s === cls.schemaRef)?.[1] : null;
        const docText = cls.schemaRef ? formal(scan.get(typeExport)?.doc ?? scan.get(cls.schemaRef)?.doc) : formal(cls.doc);
        if (!cls.schemaRef) {
          decls.push(`${doc(`[${cls.name}] 스키마입니다.`)}final ${emit.schemaType(cls.node)} ${cls.privateSchema} = ${emit.expr(cls.node, true)};\n`);
        }
        if (cls.kind === "object") decls.push(emit.objectClass(cls, docText));
        else if (unionInfo.has(cls.name)) {
          const u = unionInfo.get(cls.name);
          decls.push(emit.unionClass(cls, docText, u.sealed, u.common));
        } else if (!typedefs.has(cls.name)) {
          decls.push(`${doc(docText ?? `${cls.name} 값입니다.`)}typedef ${cls.name} = ${emit.type(cls.node)};\n`);
        }
      }
    };
    for (const e of exportsList.filter((x) => x.file === file)) {
      const docText = formal(e.doc);
      if (isSchema(e)) {
        const node = ir.irs.get(e.name);
        const outName = ir.outputName(e.name);
        const values = node.k === "enum" ? ` 값은 ${node.values.map((v) => `\`${v}\``).join("·")}입니다.` : "";
        const head = `[${emit.type(node)}] 스키마입니다.${values}`;
        decls.push(`${doc(docText && docText !== formal(scan.get(outName)?.doc) ? `${head}\n\n${docText}` : head)}final ${emit.schemaType(node)} ${e.name} = ${emit.expr(node, true)};\n`);
        if (!scan.has(outName) || scan.get(outName).kind !== "type") emitClassTree(e.name);
      } else if (e.kind === "type") {
        if (e.inferOf && !e.inferOf.startsWith("input:")) {
          if (typedefs.has(e.name)) {
            const node = ir.irs.get(e.inferOf);
            const values = node.k === "enum" ? `\n\n값은 ${node.values.map((v) => `\`${v}\``).join("·")}입니다.` : "";
            decls.push(`${doc((docText ?? `${e.name} 값입니다.`) + values)}typedef ${e.name} = ${typedefs.get(e.name)};\n`);
          }
          emitClassTree(e.inferOf);
        } else if (e.inferOf?.startsWith("input:")) {
          if (ir.outputName(e.inferOf.slice(6)) !== e.name) decls.push(`${doc(docText ?? `${e.name} 값입니다.`)}typedef ${e.name} = ${ir.outputName(e.inferOf.slice(6))};\n`);
          else emitClassTree(e.inferOf.slice(6));
        } else if (typedefs.get(e.name)) {
          decls.push(`${doc(docText ?? `${e.name} 값입니다.`)}typedef ${e.name} = ${typedefs.get(e.name)};\n`);
        } else if (!ir.classes.has(e.name)) {
          need(file, e.name); // 스키마 출력 클래스로 이미 있는 이름(재귀 타입 등)은 손으로 쓰지 않는다
        }
      } else if (e.kind === "interface") {
        if (schemaOutputs.has(e.name)) continue;
        decls.push(transformOutputs.has(e.name) ? interfaceModel(e, docText) : interfaceClass(e, docText));
      } else if (e.kind === "const") {
        if (MANUAL_CONSTS.has(e.name)) need(file, e.name);
        else {
          const c = constant(e, docText);
          if (c) decls.push(c);
          else need(file, e.name); // 함수가 든 상수 등 — manual part가 맡는다
        }
      } else {
        need(file, e.name);
      }
    }
    // 이 파일에서 만들었지만 아직 내지 않은 클래스(다른 export 안에서 처음 만난 익명 클래스)
    for (const cls of ir.classes.values()) if (cls.file === file && !emittedClasses.has(cls.name)) emitClassTree(cls.root);

    const hasManual = existsSync(manualPath);
    const header = [
      "// GENERATED by tool/codegen/generate.mjs — 직접 고치지 말고 생성기나 manual part를 고친다.",
      `// 원천: ${PKG} src/${file}`,
      "// ignore_for_file: unused_import, unnecessary_cast, unnecessary_non_null_assertion",
      "",
      `/// @docImport '${rel(file, "client.ts")}';`,
      "library;",
      "",
      ...(EXTRA_IMPORTS[file] ?? []),
      `import '${rel(file, "http.ts")}';`,
      `import '${rel(file, "zod.ts")}';`,
      ...files.filter((f) => f !== file).map((f) => `import '${rel(file, f)}';`),
      ...(hasManual ? ["", `part '${base}.manual.dart';`] : []),
      "",
    ].join("\n");
    out.set(dartFile, `${header}\n${decls.join("\n")}`);
    if (manualNeeded.has(file)) {
      const names = manualNeeded.get(file);
      const text = hasManual ? readFileSync(manualPath, "utf8") : "";
      const missing = names.filter((n) => !new RegExp(`(class|typedef)\\s+${n}\\b|\\b${n}\\s*(<[^>]*>)?\\s*\\(|\\b${n}\\s*=`).test(text));
      if (missing.length) console.warn(`${base}.manual.dart에 없는 이름: ${missing.join(", ")}`);
    }
  }

  function need(file, name) {
    if (!manualNeeded.has(file)) manualNeeded.set(file, []);
    manualNeeded.get(file).push(name);
  }

  /** 상수 export */
  function constant(e, docText) {
    const v = runtime[e.name];
    const d = doc(docText ?? `${e.name} 값입니다.`);
    if (shapeIrs.has(e.name)) {
      const entries = shapeIrs.get(e.name).map(([k, n]) => `${str(k)}: ${emit.expr(n)}`);
      return `${d}final Map<String, ZodType<Object?>> ${e.name} = {\n  ${entries.join(",\n  ")},\n};\n`;
    }
    if (v instanceof RegExp) return `${d}final ${e.name} = ${regex(v)};\n`;
    if (typeof v === "string") return `${d}const ${e.name} = ${str(v)};\n`;
    if (typeof v === "number") return `${d}const ${e.name} = ${v};\n`;
    if (Array.isArray(v) && v.every((x) => typeof x === "string")) return `${d}const ${e.name} = <String>[${v.map(str).join(", ")}];\n`;
    const lit = dartLiteral(v);
    if (lit) return `${d}${lit.final ? "final" : "const"} ${e.name} = ${lit.code};\n`;
    return null;
  }

  /** TS 인터페이스 → 파라미터·데이터 클래스 */
  function interfaceClass(e, docText) {
    const members = interfaceMembers(e.decl);
    const parent = members.find((m) => m.extends)?.extends ?? null;
    const parentMembers = parent ? interfaceMembers(scan.get(parent).decl).filter((m) => m.name) : [];
    const own = members.filter((m) => m.name);
    const type = (m) => optional(tsToDart(m.type, known), m.optional);
    const allOptional = [...parentMembers, ...own].every((m) => m.optional);
    let s = doc(docText ?? `${e.name} 값입니다.`);
    s += `class ${e.name}${parent ? ` extends ${parent}` : ""} {\n`;
    const params = [
      ...parentMembers.map((m) => `${m.optional ? "" : "required "}super.${ident(m.name)}`),
      ...own.map((m) => `${m.optional ? "" : "required "}this.${ident(m.name)}`),
    ];
    s += `  /// [${e.name}]을 만듭니다.\n  const ${e.name}({${params.join(", ")}})${parent ? "" : ""};\n`;
    for (const m of own) s += `\n${doc(formal(m.doc) ?? `\`${m.name}\` 값입니다.`, "  ")}  final ${type(m)} ${ident(m.name)};\n`;
    // 선택 필드만 null이면 뺀다 — 필수 nullable 필드(`T | null`)의 null은 Node처럼 싣는다
    const entries = [...parentMembers, ...own]
      .filter((m) => !m.method)
      .map((m) => (m.optional ? `if (${ident(m.name)} != null) ${str(m.name)}: ${ident(m.name)}` : `${str(m.name)}: ${ident(m.name)}`));
    s += `\n  /// ${allOptional ? "쿼리 파라미터로 바꿉니다. null인 값은 뺍니다." : "JSON으로 바꿉니다."}\n`;
    s += `${parent ? "  @override\n" : ""}  Map<String, Object?> toJson() => {${entries.join(", ")}};\n}\n`;
    return s;
  }

  /** transform 출력 인터페이스 → 모델 클래스(union 형태) */
  function interfaceModel(e, docText) {
    const members = interfaceMembers(e.decl).filter((m) => m.name);
    const base = emit.unionBases.get(e.name) ?? { implements: [], overrides: new Set() };
    const type = (m) => optional(tsToDart(m.type, known), m.optional);
    let s = doc(docText ?? `${e.name} 값입니다.`);
    s += `class ${e.name} extends ParsedObject${base.implements.length ? ` implements ${base.implements.join(", ")}` : ""} {\n`;
    s += `  /// [${e.name}]을 만듭니다.\n  ${e.name}({${members.map((m) => `${m.optional ? "" : "required "}${type(m)} ${ident(m.name)}`).join(", ")}})\n`;
    s += `      : super({${members.map((m) => (m.optional ? `if (${ident(m.name)} != null) ${str(m.name)}: ${ident(m.name)}` : `${str(m.name)}: ${ident(m.name)}`)).join(", ")}});\n\n`;
    s += "  Map<String, Object?> get _j => jsonOf(this);\n";
    for (const m of members) {
      s += `\n${doc(formal(m.doc) ?? `\`${m.name}\` 값입니다.`, "  ")}`;
      if (base.overrides.has(m.name)) s += "  @override\n";
      s += `  ${type(m)} get ${ident(m.name)} => ${read(type(m), `_j[${str(m.name)}]`)};\n`;
    }
    return `${s}}\n`;
  }

  // 6) 쓰기
  for (const [file, text] of out) {
    const p = path.join(LIB, file);
    mkdirSync(path.dirname(p), { recursive: true });
    writeFileSync(p, text);
  }
  const schemaFiles = [...out.keys()];
  const methods = process.env.SKIP_CLIENT ? [] : generateClient({ src, scan, ir, emit, known, lib: LIB, schemaFiles, config: T.CLIENT, pkg: PKG });
  generateParity({ runtime, ir, emit, scan, out: OUT, schemaFiles, parityDir: T.PARITY, methods, known, library: T.LIBRARY, clientClass: T.CLIENT.cls, testImport: T.TEST_IMPORT, typedefs });

  // 7) 결제창 실행 스크립트 — Node launch.ts를 그대로 묶는다(WebView용 IIFE, Node 대조용 ESM)
  if (T.LAUNCH) {
    const entry = path.join(src, "payments/launch.ts");
    const iife = esbuild.buildSync({ entryPoints: [entry], bundle: true, write: false, format: "iife", globalName: "sayrenLaunch", target: "es2017", charset: "utf8", absWorkingDir: here });
    const js = iife.outputFiles[0].text;
    if (js.includes("'''")) throw new Error("launch 스크립트에 ''' 가 있어 Dart 원시 문자열로 넣을 수 없습니다");
    mkdirSync(path.join(LIB, "payments"), { recursive: true });
    writeFileSync(
      path.join(LIB, "payments/launch_js.dart"),
      `// GENERATED by tool/codegen/generate.mjs — ${PKG} src/payments/launch.ts를 esbuild로 묶은 결제창 실행 스크립트.\n// ignore_for_file: public_member_api_docs\n\n/// WebView 결제창에서 실행한다. 전역 \`sayrenLaunch.launchPayment(launch, env)\`를 둔다\nconst launchScript = r'''\n${js}''';\n`,
    );
    const esm = esbuild.buildSync({ entryPoints: [entry], bundle: true, write: false, format: "esm", target: "es2022", charset: "utf8", absWorkingDir: here });
    writeFileSync(path.join(here, "../parity/generated/launch.mjs"), esm.outputFiles[0].text);
  }

  // 8) 엔트리포인트
  const entry = path.join(OUT, `lib/${T.LIBRARY}.dart`);
  const entryText = readFileSync(entry, "utf8");
  const exportLines = [
    ...T.ENTRY_EXPORTS,
    ...schemaFiles.map((f) => `export 'src/${f}';`),
    "export 'src/zod.dart' show Nullable, SafeParseResult, ZodArray, ZodEnum, ZodError, ZodIssue, ZodObject, ZodType;",
  ];
  writeFileSync(entry, `${entryText.split("\nlibrary;\n")[0]}\nlibrary;\n\n${exportLines.join("\n")}\n`);
  execFileSync("dart", ["format", "lib", "tool"], { cwd: OUT, stdio: "ignore" });
  console.log(`생성: ${schemaFiles.length}개 파일, 클래스 ${ir.classes.size}개`);
}

/** src 기준 TS 경로 [from]에서 [to]로 가는 Dart import 경로 */
function rel(from, to) {
  return path.posix.relative(path.posix.dirname(from), to).replace(/\.ts$/, ".dart");
}

/** JSON 같은 값(Set 포함) → 타입 있는 Dart const 리터럴. 옮길 수 없으면 null */
function dartLiteral(v) {
  const join = (types) => {
    const set = new Set(types);
    if (set.size === 1) return [...set][0];
    if ([...set].every((t) => t === "int" || t === "num")) return "num";
    const nn = [...set].filter((t) => t !== "Null");
    if (nn.length === 1) return `${nn[0].replace(/\?$/, "")}?`;
    return "Object?";
  };
  if (v instanceof RegExp) return { code: regex(v), type: "RegExp", final: true };
  if (v === null) return { code: "null", type: "Null" };
  if (typeof v === "string") return { code: str(v), type: "String" };
  if (typeof v === "boolean") return { code: String(v), type: "bool" };
  if (typeof v === "number") return Number.isFinite(v) ? { code: String(v), type: Number.isInteger(v) ? "int" : "num" } : null;
  const list = (items, open, close) => {
    const parts = items.map(dartLiteral);
    if (parts.some((p) => !p)) return null;
    const t = parts.length ? join(parts.map((p) => p.type)) : "Object?";
    return { code: `<${t}>${open}${parts.map((p) => p.code).join(", ")}${close}`, type: `${open === "[" ? "List" : "Set"}<${t}>`, final: parts.some((p) => p.final) };
  };
  if (Array.isArray(v)) return list(v, "[", "]");
  if (v instanceof Set) return list([...v], "{", "}");
  if (typeof v === "object" && Object.getPrototypeOf(v) === Object.prototype) {
    const entries = Object.entries(v).map(([k, x]) => [k, dartLiteral(x)]);
    if (entries.some(([, p]) => !p)) return null;
    const t = entries.length ? join(entries.map(([, p]) => p.type)) : "Object?";
    return { code: `<String, ${t}>{${entries.map(([k, p]) => `${str(k)}: ${p.code}`).join(", ")}}`, type: `Map<String, ${t}>`, final: entries.some(([, p]) => p.final) };
  }
  return null;
}

const only = process.argv[2];
for (const [name, T] of Object.entries(TARGETS)) if (!only || only === name) await generate(T);
