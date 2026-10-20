// npm 패키지에 실린 Node SDK TS 원본을 읽어 export 목록·종류·원본 파일·JSDoc·z.infer 대응·객체 필드 JSDoc을 뽑는다.
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

/** 패키지 src 디렉터리(`tool/codegen/node_modules/{pkg}/src`) */
export function packageSrc(pkg) {
  return fileURLToPath(new URL(`./node_modules/${pkg}/src`, import.meta.url));
}

function jsdocOf(node) {
  const docs = ts.getJSDocCommentsAndTags(node).filter(ts.isJSDoc);
  const doc = docs.at(-1);
  if (!doc) return null;
  const text = typeof doc.comment === "string" ? doc.comment : ts.getTextOfJSDocComment(doc.comment);
  const deprecated = (doc.tags ?? []).some((t) => t.tagName.text === "deprecated");
  return { text: (text ?? "").trim(), deprecated };
}

/** 스키마 초기화식 안의 객체 리터럴 속성 JSDoc — 키 경로(`a.b`) → 문장 */
function propertyDocs(init) {
  const out = {};
  const visit = (node, trail) => {
    if (ts.isPropertyAssignment(node) || ts.isShorthandPropertyAssignment(node)) {
      const name = node.name.getText().replace(/^["']|["']$/g, "");
      const key = [...trail, name];
      const doc = jsdocOf(node);
      if (doc?.text) out[key.join(".")] = doc.text;
      ts.forEachChild(node, (c) => visit(c, key));
      return;
    }
    ts.forEachChild(node, (c) => visit(c, trail));
  };
  visit(init, []);
  return out;
}

/**
 * 엔트리포인트(`src/index.ts` 등)의 export를 원본 선언까지 따라가 정리한다.
 * 반환: [{ name, kind, file(src 기준 상대), doc, deprecated, inferOf, typeText, decl }]
 */
export function scanEntry(srcDir, entry) {
  const program = ts.createProgram([path.join(srcDir, entry)], {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ESNext,
    moduleResolution: ts.ModuleResolutionKind.Bundler,
    strict: true,
    skipLibCheck: true,
  });
  const checker = program.getTypeChecker();
  const sf = program.getSourceFile(path.join(srcDir, entry));
  const moduleSymbol = checker.getSymbolAtLocation(sf);
  const out = [];
  for (const exp of checker.getExportsOfModule(moduleSymbol)) {
    const sym = exp.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(exp) : exp;
    const decl = sym.declarations?.[0];
    if (!decl) continue;
    const file = path.relative(srcDir, decl.getSourceFile().fileName);
    let kind;
    let inferOf = null;
    let typeText = null;
    let docNode = decl;
    let propDocs = {};
    if (ts.isVariableDeclaration(decl)) {
      kind = "const";
      docNode = decl.parent.parent;
      if (decl.initializer) propDocs = propertyDocs(decl.initializer);
      typeText = checker.typeToString(checker.getTypeAtLocation(decl), decl, ts.TypeFormatFlags.NoTruncation);
    } else if (ts.isTypeAliasDeclaration(decl)) {
      kind = "type";
      typeText = decl.type.getText();
      const m = /^z\.(infer|output)<\s*typeof\s+(\w+)\s*>$/.exec(typeText.replace(/\s+/g, " "));
      if (m) inferOf = m[2];
      const mi = /^z\.input<\s*typeof\s+(\w+)\s*>$/.exec(typeText.replace(/\s+/g, " "));
      if (mi) inferOf = `input:${mi[1]}`;
    } else if (ts.isInterfaceDeclaration(decl)) {
      kind = "interface";
    } else if (ts.isFunctionDeclaration(decl)) {
      kind = "function";
      typeText = decl.getText().split("{")[0];
    } else if (ts.isClassDeclaration(decl)) {
      kind = "class";
    } else {
      kind = ts.SyntaxKind[decl.kind];
    }
    const doc = jsdocOf(docNode);
    out.push({
      name: exp.name,
      kind,
      file,
      pos: decl.getStart(),
      doc: doc?.text ?? null,
      deprecated: doc?.deprecated ?? false,
      inferOf,
      typeText,
      propDocs,
      decl,
      checker,
    });
  }
  out.sort((a, b) => (a.file === b.file ? a.pos - b.pos : a.file < b.file ? -1 : 1));
  return out;
}

/** 인터페이스 멤버 — [{ name, optional, type(TS 텍스트), doc }] */
export function interfaceMembers(decl) {
  const members = [];
  const collect = (d) => {
    for (const h of d.heritageClauses ?? []) {
      for (const t of h.types) members.push({ extends: t.expression.getText() });
    }
    for (const m of d.members) {
      if (ts.isMethodSignature(m)) {
        // 메서드 시그니처는 함수 타입 필드다 — JSON에는 싣지 않는다
        const params = m.parameters.map((p) => `${p.name.getText()}${p.questionToken ? "?" : ""}: ${p.type?.getText() ?? "unknown"}`);
        members.push({
          name: m.name.getText(),
          optional: !!m.questionToken,
          type: `(${params.join(", ")}) => ${m.type?.getText() ?? "void"}`,
          doc: jsdocOf(m)?.text ?? null,
          method: true,
        });
        continue;
      }
      if (!ts.isPropertySignature(m)) continue;
      members.push({
        name: m.name.getText().replace(/^["']|["']$/g, ""),
        optional: !!m.questionToken,
        type: m.type?.getText() ?? "unknown",
        doc: jsdocOf(m)?.text ?? null,
      });
    }
  };
  collect(decl);
  return members;
}

export { ts };
