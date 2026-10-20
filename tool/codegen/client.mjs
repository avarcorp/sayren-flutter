// Node `client.ts`의 createStorefrontClient 반환 객체 → Dart StorefrontClient와 네임스페이스 클래스.
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { doc, formal, ident, interfaceMembers, str, ts, tsToDart } from "./emit.mjs";
import { pascal } from "./ir.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const BASE = "/storefront/v1";
/** 세션이 있어야 하는 최상위 멤버 — 세션 범위(이번 배치 밖)라 만들지 않는다 */
const SESSION_MEMBERS = new Set(["accessToken", "refreshToken", "userinfo"]);

function jsdoc(node) {
  const d = ts.getJSDocCommentsAndTags(node).filter(ts.isJSDoc).at(-1);
  if (!d) return null;
  return (typeof d.comment === "string" ? d.comment : ts.getTextOfJSDocComment(d.comment))?.trim() ?? null;
}

/**
 * @returns 메서드 메타데이터 — parity 생성이 쓴다
 */
export function generateClient({ src, scan, ir, emit, known, lib, schemaFiles }) {
  const file = path.join(src, "client.ts");
  const sf = ts.createSourceFile(file, readFileSync(file, "utf8"), ts.ScriptTarget.ES2022, true);
  let returned;
  sf.forEachChild((n) => {
    if (ts.isFunctionDeclaration(n) && n.name?.text === "createStorefrontClient") {
      const visit = (x) => {
        if (ts.isReturnStatement(x) && x.expression && ts.isObjectLiteralExpression(x.expression)) returned = x.expression;
        else ts.forEachChild(x, visit);
      };
      visit(n.body);
    }
  });

  const methods = [];
  const classes = [];

  /** 인터페이스 멤버(파라미터 펼치기용) */
  const membersOf = (name) => {
    const e = scan.get(name);
    if (!e || e.kind !== "interface") throw new Error(`인터페이스가 아닙니다: ${name}`);
    const ms = interfaceMembers(e.decl);
    const parent = ms.find((m) => m.extends)?.extends;
    return [...(parent ? membersOf(parent) : []), ...ms.filter((m) => m.name)];
  };

  /** 파라미터 하나 → { kind: 'positional'|'named', ... } */
  function param(p) {
    const name = p.name.getText();
    const optional = !!p.questionToken;
    const init = p.initializer?.getText() ?? null;
    const tn = p.type;
    const inline = (lit) =>
      lit.members.filter(ts.isPropertySignature).map((m) => ({ name: m.name.getText(), optional: !!m.questionToken, type: m.type.getText() }));
    if (ts.isTypeLiteralNode(tn)) return { kind: "named", name, optional, fields: inline(tn) };
    if (ts.isIntersectionTypeNode(tn)) {
      const fields = tn.types.flatMap((t) =>
        ts.isTypeLiteralNode(t) ? inline(t) : membersOf(t.getText()).map((m) => ({ name: m.name, optional: m.optional, type: m.type })),
      );
      return { kind: "named", name, optional, fields };
    }
    const dart = tsToDart(tn.getText(), known);
    const cls = ir.classes.has(dart) || [...ir.typeOfSchema.values()].includes(dart);
    const iface = scan.get(dart)?.kind === "interface" && !cls;
    return { kind: "positional", name, optional, init, type: dart, model: cls, iface };
  }

  function namedFields(pm) {
    return pm.fields.map((f) => ({ ...f, dart: tsToDart(f.type, known), required: !pm.optional && !f.optional }));
  }

  /** 응답 스키마 TS 식 → { expr, type } */
  function schemaOf(node) {
    if (ts.isIdentifier(node)) {
      const n = ir.build(node.text);
      return { expr: node.text, type: emit.type(n) };
    }
    if (ts.isCallExpression(node)) {
      const callee = node.expression.getText();
      const inner = schemaOf(node.arguments[0]);
      if (callee === "z.array") return { expr: `z.array<${inner.type}>(${inner.expr})`, type: `List<${inner.type}>` };
      if (callee === "pageSchema") return { expr: `pageSchema<${inner.type}>(${inner.expr})`, type: `Page<${inner.type}>` };
    }
    throw new Error(`응답 스키마 식을 옮길 수 없습니다: ${node.getText()}`);
  }

  /** 경로 식 → Dart 문자열 식과 문서용 경로 */
  function pathOf(node) {
    const esc = (s) => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$");
    if (ts.isStringLiteral(node)) return { dart: str(node.text), shown: node.text };
    if (ts.isTaggedTemplateExpression(node) && node.tag.getText() === "path") {
      const t = node.template;
      if (ts.isNoSubstitutionTemplateLiteral(t)) return { dart: str(t.text), shown: t.text };
      let dart = esc(t.head.text);
      let shown = t.head.text;
      for (const span of t.templateSpans) {
        const ex = span.expression.getText();
        const id = ex.replace(/^String\((\w+)\)$/, "$1");
        dart += `\${encodeURIComponent('$${id}')}${esc(span.literal.text)}`;
        shown += `{${id}}${span.literal.text}`;
      }
      return { dart: `'${dart}'`, shown };
    }
    throw new Error(`경로 식을 옮길 수 없습니다: ${node.getText()}`);
  }

  /** 본문·쿼리 값 식 */
  function valueOf(node, params) {
    const byName = new Map(params.map((p) => [p.name, p]));
    const mapOfNamed = (pm) => `compact({${namedFields(pm).map((f) => `${str(f.name)}: ${ident(f.name)}`).join(", ")}})`;
    if (ts.isAsExpression(node)) return valueOf(node.expression, params);
    if (ts.isIdentifier(node)) {
      const p = byName.get(node.text);
      if (!p) throw new Error(`알 수 없는 식별자 ${node.text}`);
      if (p.kind === "named") return mapOfNamed(p);
      if (p.model || p.iface) return p.optional ? `${p.name}?.toJson()` : `${p.name}.toJson()`;
      return p.name;
    }
    if (ts.isObjectLiteralExpression(node)) {
      const entries = node.properties.map((pr) => {
        const key = pr.name.getText();
        const v = ts.isShorthandPropertyAssignment(pr) ? key : pr.initializer.getText();
        return `${str(key)}: ${v}`;
      });
      return `{${entries.join(", ")}}`;
    }
    if (ts.isCallExpression(node) && /\.parse$/.test(node.expression.getText())) {
      const schema = node.expression.getText().replace(/\.parse$/, "");
      const arg = node.arguments[0];
      return `${schema}.parse(${valueOf(arg, params).replace(/\.toJson\(\)$/, "")}).toJson()`;
    }
    throw new Error(`본문 식을 옮길 수 없습니다: ${node.getText()}`);
  }

  function method(prop, nsPath) {
    const name = prop.name.getText();
    const fn = prop.initializer;
    const params = fn.parameters.map(param);
    const call = fn.body;
    if (!ts.isCallExpression(call)) throw new Error(`메서드 본문이 호출식이 아닙니다: ${nsPath.join(".")}.${name}`);
    const callee = call.expression.getText();
    const isVoid = callee === "http.requestVoid";
    const [m, p, ...rest] = call.arguments;
    const verb = m.text;
    const { dart: pathDart, shown } = pathOf(p);
    const schema = isVoid ? null : schemaOf(rest[0]);
    const opts = isVoid ? rest[0] : rest[1];
    const ro = [];
    if (opts) {
      for (const pr of opts.properties) {
        const key = pr.name.getText();
        const valueNode = ts.isShorthandPropertyAssignment(pr) ? pr.name : pr.initializer;
        if (key === "body") ro.push(`body: ${valueOf(valueNode, params)}`);
        else if (key === "query") ro.push(`query: ${valueOf(valueNode, params)}`);
        else throw new Error(`요청 옵션 ${key}`);
      }
    }
    // 시그니처
    const positional = params.filter((x) => x.kind === "positional");
    const named = params.filter((x) => x.kind === "named");
    const req = positional.filter((x) => !x.optional && !x.init);
    const opt = positional.filter((x) => x.optional || x.init);
    if (opt.length && named.length) throw new Error(`선택 위치 인자와 네임드 인자를 함께 쓸 수 없습니다: ${name}`);
    const sig = [
      ...req.map((x) => `${x.type} ${x.name}`),
      ...(opt.length ? [`[${opt.map((x) => (x.init ? `${x.type} ${x.name} = const ${x.init === "{}" ? "{}" : x.init}` : `${x.type}? ${x.name}`)).join(", ")}]`] : []),
      ...(named.length
        ? [`{${named.flatMap(namedFields).map((f) => `${f.required ? "required " : ""}${f.dart}${f.required ? "" : "?"} ${ident(f.name)}`).join(", ")}}`]
        : []),
    ].join(", ");
    const retType = isVoid ? "void" : schema.type;
    const reqOpts = ro.length ? `, RequestOptions(${ro.join(", ")})` : "";
    const body = isVoid
      ? `_http.requestVoid(${str(verb)}, ${pathDart}${reqOpts})`
      : `_http.request(${str(verb)}, ${pathDart}, ${schema.expr}${reqOpts})`;
    const text = formal(jsdoc(prop));
    const endpoint = `\`${verb} ${BASE}${shown}\``;
    const docText = text?.includes(`${BASE}${shown}`) || text?.includes(`\`${verb} ${shown}\``) ? text : [text, endpoint].filter(Boolean).join("\n\n");
    methods.push({ ns: nsPath, name, params, namedFields: named.flatMap(namedFields), verb, shown, schema, isVoid });
    return `${doc(docText, "  ")}  Future<${retType}> ${name}(${sig}) async => ${body};\n`;
  }

  function namespace(obj, nsPath, docText) {
    const cls = `StorefrontClient${nsPath.map(pascal).join("")}`;
    const members = [];
    const children = [];
    for (const prop of obj.properties) {
      if (!ts.isPropertyAssignment(prop)) continue;
      if (ts.isObjectLiteralExpression(prop.initializer)) {
        const child = namespace(prop.initializer, [...nsPath, prop.name.getText()], formal(jsdoc(prop)));
        children.push({ name: prop.name.getText(), cls: child, doc: formal(jsdoc(prop)) });
      } else members.push(method(prop, nsPath));
    }
    let out = doc(docText ?? `\`client.${nsPath.join(".")}\` 네임스페이스입니다.`);
    out += `class ${cls} {\n  ${cls}._(this._http)${children.length ? ` : ${children.map((c) => `${c.name} = ${c.cls}._(_http)`).join(", ")}` : ""};\n\n  final Http _http;\n`;
    for (const c of children) out += `\n${doc(c.doc ?? `\`client.${[...nsPath, c.name].join(".")}\` 네임스페이스입니다.`, "  ")}  final ${c.cls} ${c.name};\n`;
    for (const m of members) out += `\n${m}`;
    out += "}\n";
    classes.push(out);
    return cls;
  }

  const top = [];
  for (const prop of returned.properties) {
    const name = prop.name?.getText();
    if (SESSION_MEMBERS.has(name)) continue;
    if (ts.isPropertyAssignment(prop) && ts.isObjectLiteralExpression(prop.initializer)) {
      const docText = formal(jsdoc(prop));
      top.push({ name, cls: namespace(prop.initializer, [name], docText), doc: docText });
    } else {
      throw new Error(`최상위 멤버를 옮길 수 없습니다: ${name}`);
    }
  }

  const head = readFileSync(path.join(here, "templates/client_head.dart"), "utf8");
  const ctor = readFileSync(path.join(here, "templates/client_ctor.dart"), "utf8").replace(
    "/*INIT*/",
    top.map((t) => `    ${t.name} = ${t.cls}._(http_);`).join("\n"),
  );
  let client = `// GENERATED by tool/codegen/generate.mjs — 직접 고치지 말고 생성기나 templates/를 고친다.
// 원천: @sayren/storefront-sdk src/client.ts
// ignore_for_file: unused_import

import 'package:http/http.dart' as http;

import 'http.dart';
${schemaFiles.map((f) => `import '${f}';`).join("\n")}
import 'zod.dart';

${head.trimEnd()}

/// 스토어프론트 API 클라이언트입니다. [createStorefrontClient]로 만듭니다.
class StorefrontClient {
${ctor}`;
  for (const t of top) client += `\n${doc(t.doc ?? `\`client.${t.name}\` 네임스페이스입니다.`, "  ")}  late final ${t.cls} ${t.name};\n`;
  client += "}\n";
  client += classes.map((c) => `\n${c}`).join("");
  writeFileSync(path.join(lib, "client.dart"), client);
  return methods;
}
