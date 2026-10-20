// IR → Dart 코드.
import { interfaceMembers, ts } from "./scan.mjs";
import { sentence, toFormal } from "./korean.mjs";

// Dart 예약어와 모델이 이미 가진 멤버 이름 — 필드 이름이 겹치면 끝에 _를 붙인다
const DART_RESERVED = new Set(
  "assert break case catch class const continue default do else enum extends false final finally for if in is new null rethrow return super switch this throw true try var void while with hashCode runtimeType toString toJson noSuchMethod".split(
    " ",
  ),
);

export const ident = (key) => (DART_RESERVED.has(key) ? `${key}_` : key);

/** Dart 문자열 리터럴 */
export function str(s) {
  return `'${String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$").replace(/\n/g, "\\n")}'`;
}

/** JSON 값 → const Dart 리터럴 */
export function lit(v) {
  if (v === undefined) return "absent";
  if (v === null) return "null";
  if (typeof v === "string") return str(v);
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  if (Array.isArray(v)) return `const [${v.map(lit).join(", ")}]`;
  return `const {${Object.entries(v)
    .map(([k, x]) => `${str(k)}: ${lit(x)}`)
    .join(", ")}}`;
}

export function regex(re) {
  const src = re.source;
  const body = !src.includes("'") ? `r'${src}'` : !src.includes('"') ? `r"${src}"` : str(src);
  const flags = [];
  if (re.flags.includes("i")) flags.push("caseSensitive: false");
  if (re.flags.includes("u") || re.flags.includes("v")) flags.push("unicode: true");
  if (re.flags.includes("m")) flags.push("multiLine: true");
  if (re.flags.includes("s")) flags.push("dotAll: true");
  return `RegExp(${[body, ...flags].join(", ")})`;
}

/** 여러 줄 dartdoc */
export function doc(text, indent = "") {
  if (!text) return "";
  return `${text
    .trim()
    .split("\n")
    .map((l) => `${indent}///${l.trim() ? ` ${l.trimEnd()}` : ""}`)
    .join("\n")}\n`;
}

/** Node 설명 → pub 문서 문장 */
export const formal = (text) => (text ? sentence(toFormal(text)) : null);

const nullable = (t) => (t.endsWith("?") || t === "Null" || t === "dynamic" ? t : `${t}?`);

export class DartEmitter {
  constructor(ir, scan) {
    this.ir = ir;
    this.scan = scan; // export 이름 → 스캔 결과
    this.definedIn = new Map(); // Dart 이름 → 파일
  }

  /** IR 노드의 Dart 출력 타입 */
  type(n) {
    switch (n.k) {
      case "ref":
        return this.type(this.ir.build(n.name));
      case "string":
      case "enum":
        return "String";
      case "number":
        return n.checks.some((c) => c.k === "int") ? "int" : "num";
      case "boolean":
        return "bool";
      case "null":
        return "Null";
      case "unknown":
        return "Object?";
      case "literal": {
        const v = n.values[0];
        return typeof v === "string" ? "String" : typeof v === "boolean" ? "bool" : Number.isInteger(v) ? "int" : "num";
      }
      case "optional":
      case "nullable":
      case "catch":
        return nullable(this.type(n.inner));
      case "default": {
        // zod 출력에서 기본값은 「키 없음」을 채우므로 안쪽 optional은 null을 만들지 않는다
        const t = this.type(n.inner.k === "optional" ? n.inner.inner : n.inner);
        return n.value === null ? nullable(t) : t;
      }
      case "array":
        return `List<${this.type(n.el)}>`;
      case "record":
        return `Map<String, ${this.type(n.value)}>`;
      case "lazy":
        return this.type(n.inner);
      case "pipe":
        return this.type(n.out);
      case "transform":
        return n.hook.output ?? "Object?";
      case "object":
        return n.className;
      case "plainObject":
        return "Map<String, Object?>";
      case "union":
        return this.unionType(n);
      case "intersection":
        return this.type(n.merged);
      default:
        throw new Error(`type ${n.k}`);
    }
  }

  /** union 형태들의 클래스 이름 — 모델이 아닌 형태가 있으면 null */
  variantClasses(n, seen = new Set()) {
    const out = [];
    for (const o of n.options) {
      let x = o;
      while (x.k === "ref") x = this.ir.build(x.name);
      while (x.k === "lazy") x = x.inner;
      if (x.k === "object") out.push(x.className);
      else if (x.k === "union") {
        const inner = this.variantClasses(x, seen);
        if (!inner) return null;
        out.push(...inner);
      } else if (x.k === "pipe" && x.out.k === "transform" && x.out.hook.output) out.push(x.out.hook.output);
      else return null;
    }
    return out;
  }

  unionType(n) {
    if (this.variantClasses(n)) return n.className;
    const types = new Set(n.options.map((o) => this.type(o)));
    if (types.size === 1) return [...types][0];
    if ([...types].every((t) => t === "String")) return "String";
    return "Object?";
  }

  /** 스키마 식. [define]이면 객체·union을 참조하지 않고 그 자리에서 정의한다 */
  expr(n, define = false) {
    let e;
    switch (n.k) {
      case "ref":
        e = n.name;
        break;
      case "string":
        e = "z.string()";
        break;
      case "number":
        e = "z.number()";
        break;
      case "boolean":
        e = "z.boolean()";
        break;
      case "null":
        e = "z.null_()";
        break;
      case "unknown":
        e = "z.unknown()";
        break;
      case "enum":
        e = `z.enum_([${n.values.map(str).join(", ")}])`;
        break;
      case "literal": {
        const t = this.type(n);
        e = n.values.length === 1 ? `z.literal<${t}>(${lit(n.values[0])})` : `z.literals<${t}>([${n.values.map(lit).join(", ")}])`;
        break;
      }
      case "optional":
        e = `${this.expr(n.inner)}.optional()`;
        break;
      case "nullable":
        e = `${this.expr(n.inner)}.nullable()`;
        break;
      case "default":
        e = `${this.expr(n.inner)}.withDefault(${lit(n.value)})`;
        break;
      case "catch":
        e = `${this.expr(n.inner)}.catchValue(${lit(n.value)})`;
        break;
      case "array":
        e = `z.array<${this.type(n.el)}>(${this.expr(n.el)})`;
        break;
      case "record":
        e = `z.record<${this.type(n.value)}>(${this.expr(n.value)})`;
        break;
      case "lazy":
        e = `z.lazy<${this.type(n)}>(() => ${this.expr(n.inner, define)})`;
        break;
      case "pipe":
        e = `z.pipe<${this.type(n)}>(${this.expr(n.in)}, ${this.expr(n.out)})`;
        break;
      case "transform":
        e = `z.transform<${this.type(n)}>(${n.hook.dart})`;
        break;
      case "object": {
        const cls = this.ir.classes.get(n.className);
        if (!define) return this.withChecks(cls.schemaRef ?? cls.privateSchema, []);
        const fields = cls.fields.map((f) => `${str(f.key)}: ${this.expr(f.node)}`).join(",\n    ");
        e = `z.object<${n.className}>({\n    ${fields},\n  }, ${n.className}._${n.loose ? ", loose: true" : ""})`;
        break;
      }
      case "plainObject": {
        const fields = n.shape.map(([k, f]) => `${str(k)}: ${this.expr(f)}`).join(", ");
        e = `z.plainObject({${fields}}${n.loose ? ", loose: true" : ""})`;
        break;
      }
      case "intersection":
        e = `z.intersection<${this.type(n)}>(${this.expr(n.left)}, ${this.expr(n.right)}, ${this.expr(n.merged, true)})`;
        break;
      case "union": {
        const cls = this.ir.classes.get(n.className);
        if (!define && !n.flattened) return this.withChecks(cls.schemaRef ?? cls.privateSchema, []);
        const t = this.type(n);
        const opts = n.options.map((o) => this.expr(o)).join(",\n    ");
        e = n.discriminator
          ? `z.discriminatedUnion<${t}>(${str(n.discriminator)}, [\n    ${opts},\n  ])`
          : `z.union<${t}>([\n    ${opts},\n  ])`;
        break;
      }
      default:
        throw new Error(`expr ${n.k}`);
    }
    return this.withChecks(e, n.checks ?? []);
  }

  withChecks(e, checks) {
    for (const c of checks) {
      switch (c.k) {
        case "min":
          e += `.min(${c.value})`;
          break;
        case "max":
          e += `.max(${c.value})`;
          break;
        case "int":
          e += ".int_()";
          break;
        case "gt":
          e += `.greaterThan(${c.value}, inclusive: ${c.inclusive})`;
          break;
        case "lt":
          e += `.lessThan(${c.value}, inclusive: ${c.inclusive})`;
          break;
        case "url":
          e += ".url()";
          break;
        case "pattern":
          e += `.pattern(${regex(c.regex)}${c.format === "regex" ? "" : `, format: ${str(c.format)}`})`;
          break;
        case "overwrite":
          e += `.${c.method}()`;
          break;
        case "refine": {
          const args = [c.dart];
          if (c.message) args.push(`message: ${str(c.message)}`);
          if (c.path?.length) args.push(`path: [${c.path.map(lit).join(", ")}]`);
          e += `.refine(${args.join(", ")})`;
          break;
        }
        case "superRefine":
          e += `.check(${c.dart})`;
          break;
        default:
          throw new Error(`check ${c.k}`);
      }
    }
    return e;
  }

  /** 필드 설명 — 스키마 describe, 없으면 TS JSDoc */
  fieldDoc(root, field) {
    let n = field.node;
    let desc = n.desc;
    while (!desc && n.inner) {
      n = n.inner;
      desc = n.desc;
    }
    if (!desc) desc = this.scan.get(root)?.propDocs?.[field.propPath.join(".")] ?? null;
    return formal(desc);
  }

  /** 스키마 상수 타입 */
  schemaType(n) {
    const t = this.type(n);
    if (n.k === "object" && !n.checks?.some((c) => c.k === "superRefine")) return `ZodObject<${t}>`;
    if (n.k === "enum" && !n.checks?.length) return "ZodEnum";
    if (n.k === "array" && !n.checks?.some((c) => c.k === "refine" || c.k === "superRefine")) return `ZodArray<${this.type(n.el)}>`;
    return `ZodType<${t}>`;
  }

  /** 객체 클래스 */
  objectClass(cls, docText) {
    const fields = cls.fields.map((f) => {
      const name = ident(f.key);
      const t = this.type(f.node);
      let n = f.node;
      const flags = { optional: false, nullable: false, def: undefined };
      for (;;) {
        if (n.k === "optional") flags.optional = true;
        else if (n.k === "nullable") flags.nullable = true;
        else if (n.k === "default") flags.def = n.value;
        else if (n.k === "catch") flags.optional = true;
        else break;
        n = n.inner;
      }
      return { ...f, name, t, flags };
    });
    const base = this.unionBases.get(cls.name) ?? { implements: [], overrides: new Set() };
    const params = fields.map((f) => {
      const { optional, nullable: nul, def } = f.flags;
      if (def !== undefined) return def === null ? `${nullable(f.t)} ${f.name}` : `${f.t} ${f.name} = ${lit(def)}`;
      if (optional && nul) return `Nullable<${f.t.replace(/\?$/, "")}>? ${f.name}`;
      if (optional) return `${nullable(f.t)} ${f.name}`;
      return `required ${f.t} ${f.name}`;
    });
    const entries = fields.map((f) => {
      const { optional, nullable: nul, def } = f.flags;
      if (def === undefined && optional && nul) return `if (${f.name} != null) ${str(f.key)}: ${f.name}.value`;
      if (def === undefined && optional) return `if (${f.name} != null) ${str(f.key)}: ${f.name}`;
      return `${str(f.key)}: ${f.name}`;
    });
    const schemaName = cls.schemaRef ?? cls.privateSchema;
    const impl = base.implements.length ? ` implements ${base.implements.join(", ")}` : "";
    let out = doc(docText ?? `${cls.name} 값입니다.`);
    out += `class ${cls.name} extends ParsedObject${impl} {\n`;
    out += `  /// [${cls.name}]을 만듭니다. 검증하지 않으므로 테스트·미리보기 데이터에 사용하십시오.\n`;
    out += params.length
      ? `  ${cls.name}({${params.join(", ")}}) : super({${entries.join(", ")}});\n\n`
      : `  ${cls.name}() : super(const {});\n\n`;
    out += `  ${cls.name}._(super.json);\n\n`;
    out += `  /// JSON을 [${schemaName}]로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.\n`;
    out += `  factory ${cls.name}.fromJson(Map<String, Object?> json) => ${schemaName}.parse(json);\n\n`;
    out += `  Map<String, Object?> get _j => jsonOf(this);\n`;
    for (const f of fields) {
      out += `\n${doc(this.fieldDoc(cls.root, f) ?? `\`${f.key}\` 값입니다.`, "  ")}`;
      if (base.overrides.has(f.key)) out += "  @override\n";
      out += `  ${f.t} get ${f.name} => ${read(f.t, `_j[${str(f.key)}]`)};\n`;
    }
    return `${out}}\n`;
  }

  /** union 클래스 */
  unionClass(cls, docText, sealed, common) {
    const schemaName = cls.schemaRef ?? cls.privateSchema;
    let out = doc(docText ?? `${cls.name} 값입니다.`);
    out += `${sealed ? "sealed class" : "abstract interface class"} ${cls.name} {\n`;
    out += `  /// JSON을 [${schemaName}]로 검증해 맞는 형태로 만듭니다. 맞지 않으면 [ZodError]를 던집니다.\n`;
    out += `  factory ${cls.name}.fromJson(Map<String, Object?> json) => ${schemaName}.parse(json);\n`;
    for (const c of common) {
      out += `\n${doc(c.doc ?? `\`${c.key}\` 값입니다.`, "  ")}  ${c.t} get ${ident(c.key)};\n`;
    }
    out += "\n  /// JSON으로 바꿉니다.\n  Map<String, Object?> toJson();\n}\n";
    return out;
  }
}

/** JSON 값 읽기 식 */
export function read(t, src) {
  const nn = t.endsWith("?");
  const base = nn ? t.slice(0, -1) : t;
  if (t === "Object?") return src;
  if (t === "Null") return "null";
  if (base.startsWith("List<")) {
    const inner = base.slice(5, -1);
    return nn ? `(${src} as List?)?.cast<${inner}>()` : `(${src} as List).cast<${inner}>()`;
  }
  if (base.startsWith("Map<String, ")) {
    const inner = base.slice(12, -1);
    return nn ? `(${src} as Map?)?.cast<String, ${inner}>()` : `(${src} as Map).cast<String, ${inner}>()`;
  }
  return `${src} as ${t}`;
}

/** TS 타입 텍스트 → Dart 타입(인터페이스·파라미터용) */
export function tsToDart(text, known) {
  const t = text.trim().replace(/^readonly\s+/, "");
  if (t === "string") return "String";
  if (t === "number") return "int";
  if (t === "boolean") return "bool";
  if (t === "unknown" || t === "any") return "Object?";
  if (/^Record<string,\s*unknown>$/.test(t)) return "Map<String, Object?>";
  if (/^(".*?"|'.*?')(\s*\|\s*(".*?"|'.*?'))*$/.test(t)) return "String";
  const arr = /^(.+)\[\]$/.exec(t);
  if (arr) return `List<${tsToDart(arr[1], known)}>`;
  if (/^\w+$/.test(t) && known(t)) return known(t);
  throw new Error(`TS 타입을 Dart로 옮길 수 없습니다: ${t}`);
}

export { interfaceMembers, ts };
