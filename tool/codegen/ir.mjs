// 런타임 zod 스키마 → 중간 표현(IR)과 Dart 클래스 목록.
//
// 이름 규칙(ROADMAP 「타입」):
// - export된 객체·union 스키마의 출력은 `z.infer` 타입 이름의 클래스다.
// - 익명 객체·union은 `{소유 클래스}{필드 PascalCase}`, 배열 항목이면 끝에 `Item`, record 값이면 `Value`다.
// - 판별 union의 형태는 `{union}{판별 값 PascalCase}`, 판별 필드가 없는 익명 형태는 `{union}Option{n}`이다.
import { normalize, OVERWRITES, REFINES, SUPER_REFINES, TRANSFORMS } from "./hooks.mjs";

export const pascal = (s) =>
  String(s)
    .replace(/(^|[^A-Za-z0-9]+)([A-Za-z0-9])/g, (_, __, c) => c.toUpperCase())
    .replace(/^[a-z]/, (c) => c.toUpperCase());
export const camel = (s) => pascal(s).replace(/^[A-Z]/, (c) => c.toLowerCase());

export class IrBuilder {
  /**
   * @param exportsByName export 이름 → 스캔 결과
   * @param runtime 패키지 모듈(런타임 값)
   * @param z 패키지와 같은 zod
   */
  constructor(exportsByName, runtime, z) {
    this.exportsByName = exportsByName;
    this.runtime = runtime;
    this.z = z;
    this.schemaName = new Map(); // 런타임 스키마 → export 이름
    // `.describe()`는 def를 공유하는 복제를 만든다 — 런타임 객체 대신 def로 같은 스키마를 알아본다
    for (const [name, e] of exportsByName) if (e.kind === "const" && runtime[name]?._zod) this.schemaName.set(runtime[name]._zod.def, name);
    this.typeOfSchema = new Map(); // 스키마 export 이름 → 출력 타입 이름
    for (const e of exportsByName.values()) {
      if (e.kind === "type" && e.inferOf && !e.inferOf.startsWith("input:")) this.typeOfSchema.set(e.inferOf, e.name);
    }
    // z.input 타입만 있는 요청 스키마는 그 이름을 출력 클래스 이름으로 쓴다
    for (const e of exportsByName.values()) {
      if (e.kind === "type" && e.inferOf?.startsWith("input:") && !this.typeOfSchema.has(e.inferOf.slice(6))) this.typeOfSchema.set(e.inferOf.slice(6), e.name);
    }
    for (const e of exportsByName.values()) {
      const m = e.kind === "const" && /^z\.ZodType<(\w+)/.exec(e.typeText ?? "");
      if (m && !this.typeOfSchema.has(e.name)) this.typeOfSchema.set(e.name, m[1]);
    }
    this.classes = new Map(); // 클래스 이름 → { name, file, kind: 'object'|'union', ... }
    this.anonByObject = new Map(); // 익명 런타임 스키마 → 클래스 이름
    this.irs = new Map(); // export 이름 → IR
    this.missingHooks = [];
  }

  /** export 스키마의 출력 클래스 이름 */
  outputName(exportName) {
    return this.typeOfSchema.get(exportName) ?? pascal(exportName.replace(/Schema$/, ""));
  }

  build(exportName) {
    if (this.irs.has(exportName)) return this.irs.get(exportName);
    const e = this.exportsByName.get(exportName);
    const schema = this.runtime[exportName];
    const ir = this.node(schema, {
      root: exportName,
      file: e.file,
      owner: this.outputName(exportName),
      naming: this.outputName(exportName),
      propPath: [],
      isRoot: true,
    });
    this.irs.set(exportName, ir);
    return ir;
  }

  description(schema) {
    return schema?.description ?? null;
  }

  node(schema, ctx) {
    const exported = this.schemaName.get(schema._zod.def);
    if (exported && !(ctx.isRoot && exported === ctx.root)) return { k: "ref", name: exported, schema, desc: this.description(schema) };
    const d = schema._zod.def;
    const desc = this.description(schema);
    const sub = { ...ctx, isRoot: false };
    const checks = this.checks(schema, ctx);
    switch (d.type) {
      case "string":
      case "number":
      case "boolean":
      case "null":
      case "unknown":
        return { k: d.type, schema, desc, checks };
      case "enum":
        return { k: "enum", schema, desc, values: Object.values(d.entries), checks };
      case "literal":
        return { k: "literal", schema, desc, values: d.values, checks };
      case "optional":
      case "nullable":
        return { k: d.type, schema, desc, inner: this.node(d.innerType, ctx), checks };
      case "default":
        return { k: "default", schema, desc, inner: this.node(d.innerType, ctx), value: d.defaultValue, checks };
      case "catch":
        return { k: "catch", schema, desc, inner: this.node(d.innerType, ctx), value: d.catchValue?.({}), checks };
      case "array":
        return { k: "array", schema, desc, el: this.node(d.element, { ...sub, naming: `${ctx.naming}Item` }), checks };
      case "record":
        return { k: "record", schema, desc, value: this.node(d.valueType, { ...sub, naming: `${ctx.naming}Value` }), checks };
      case "lazy":
        return { k: "lazy", schema, desc, inner: this.node(d.getter(), { ...ctx, isRoot: ctx.isRoot }), checks };
      case "pipe": {
        // transform으로 들어가는 객체는 바로 다른 모델로 바뀌므로 클래스를 두지 않는다
        const toTransform = d.out._zod.def.type === "transform";
        return { k: "pipe", schema, desc, in: this.node(d.in, { ...ctx, plain: toTransform }), out: this.node(d.out, ctx), checks };
      }
      case "transform": {
        const t = TRANSFORMS[normalize(d.transform)];
        if (!t) this.missingHooks.push(`transform @ ${ctx.root}: ${normalize(d.transform)}`);
        return { k: "transform", schema, desc, hook: t ?? { dart: "_MISSING" }, checks };
      }
      case "object":
        return this.object(schema, ctx, desc, checks);
      case "union":
        return this.union(schema, ctx, desc, checks);
      case "intersection":
        return this.intersection(schema, ctx, desc, checks);
      default:
        throw new Error(`지원하지 않는 zod 타입 ${d.type} @ ${ctx.root}`);
    }
  }

  checks(schema, ctx) {
    const out = [];
    for (const c of schema._zod.def.checks ?? []) {
      const cd = c._zod.def;
      switch (cd.check) {
        case "min_length":
          out.push({ k: "min", value: cd.minimum });
          break;
        case "max_length":
          out.push({ k: "max", value: cd.maximum });
          break;
        case "number_format":
          if (cd.format !== "safeint") throw new Error(`number format ${cd.format}`);
          out.push({ k: "int" });
          break;
        case "greater_than":
          out.push({ k: "gt", value: cd.value, inclusive: cd.inclusive });
          break;
        case "less_than":
          out.push({ k: "lt", value: cd.value, inclusive: cd.inclusive });
          break;
        case "string_format":
          if (cd.format === "url") out.push({ k: "url" });
          else out.push({ k: "pattern", format: cd.format, regex: cd.pattern });
          break;
        case "overwrite": {
          const m = OVERWRITES[normalize(cd.tx)];
          if (!m) this.missingHooks.push(`overwrite @ ${ctx.root}: ${normalize(cd.tx)}`);
          out.push({ k: "overwrite", method: m ?? "_MISSING" });
          break;
        }
        case "custom": {
          if (cd.fn) {
            const dart = REFINES[normalize(cd.fn)];
            if (!dart) this.missingHooks.push(`refine @ ${ctx.root}: ${normalize(cd.fn)}`);
            let message;
            try {
              message = cd.error?.({});
            } catch {
              message = undefined;
            }
            out.push({ k: "refine", dart: dart ?? "_MISSING", message: message ?? null, path: cd.path ?? [] });
          } else {
            const dart = SUPER_REFINES[ctx.root];
            if (!dart) this.missingHooks.push(`superRefine @ ${ctx.root}`);
            out.push({ k: "superRefine", dart: dart ?? "_MISSING" });
          }
          break;
        }
        default:
          throw new Error(`지원하지 않는 검사 ${cd.check} @ ${ctx.root}`);
      }
    }
    return out;
  }

  /** 클래스 이름을 정한다 — 같은 런타임 객체는 같은 클래스, 이름 충돌은 오류 */
  claim(schema, ctx) {
    if (ctx.isRoot) return { name: this.outputName(ctx.root), schemaRef: ctx.root };
    const existing = this.anonByObject.get(schema._zod.def);
    if (existing) return { name: existing, schemaRef: null, existing: true };
    let name = ctx.naming;
    if (this.classes.has(name) || this.exportsByName.has(name)) {
      throw new Error(`클래스 이름 충돌 ${name} @ ${ctx.root}`);
    }
    this.anonByObject.set(schema._zod.def, name);
    return { name, schemaRef: null };
  }

  object(schema, ctx, desc, checks) {
    const d = schema._zod.def;
    if (ctx.plain) {
      // 클래스를 두지 않는 객체(intersection의 한쪽) — 출력은 JSON 맵이다
      const shape = Object.entries(d.shape).map(([key, value]) => [key, this.node(value, { ...ctx, plain: false, isRoot: false, naming: `${ctx.naming}${pascal(key)}` })]);
      return { k: "plainObject", schema, desc, checks, shape, loose: d.catchall?._zod.def.type === "unknown" };
    }
    const { name, schemaRef, existing } = this.claim(schema, ctx);
    const node = { k: "object", schema, desc, className: name, checks, loose: d.catchall?._zod.def.type === "unknown" };
    if (existing) return node;
    const cls = {
      kind: "object",
      name,
      file: ctx.file,
      root: ctx.root,
      schemaRef, // export 이름(공개 스키마) 또는 null(비공개 스키마를 만든다)
      privateSchema: schemaRef ? null : `${camel(name)}Schema`,
      doc: ctx.isRoot ? null : (desc ?? ctx.fieldDoc ?? null),
      fields: [],
      implements: [],
      node,
    };
    this.classes.set(name, cls);
    for (const [key, value] of Object.entries(d.shape)) {
      const propPath = [...ctx.propPath, key];
      const fieldNode = this.node(value, {
        ...ctx,
        isRoot: false,
        flattenInto: null,
        owner: name,
        naming: `${name}${pascal(key)}`,
        propPath,
        fieldDoc: null,
      });
      cls.fields.push({ key, node: fieldNode, propPath });
    }
    return node;
  }

  union(schema, ctx, desc, checks) {
    const d = schema._zod.def;
    if (ctx.flattenInto) {
      // 익명 union 안의 union — 클래스를 따로 두지 않고 바깥 union의 형태로 펼친다
      const node = { k: "union", schema, desc, className: ctx.flattenInto, flattened: true, discriminator: d.discriminator ?? null, checks, options: [] };
      d.options.forEach((option, i) => node.options.push(this.node(option, { ...ctx, flattenInto: null, naming: this.optionNaming(ctx.flattenInto, d, option, i) })));
      return node;
    }
    const { name, schemaRef, existing } = this.claim(schema, ctx);
    const node = { k: "union", schema, desc, className: name, discriminator: d.discriminator ?? null, checks, options: [] };
    if (existing) return node;
    const cls = {
      kind: "union",
      name,
      file: ctx.file,
      root: ctx.root,
      schemaRef,
      privateSchema: schemaRef ? null : `${camel(name)}Schema`,
      doc: ctx.isRoot ? null : (desc ?? null),
      node,
      variants: [], // 형태 클래스 이름(모델이 아닌 형태가 있으면 null을 넣고 union 타입은 Object?가 된다)
      implements: [],
    };
    this.classes.set(name, cls);
    d.options.forEach((option, i) => {
      const od = option._zod.def;
      const nested = od.type === "union" && !this.schemaName.has(option._zod.def);
      const child = this.node(option, { ...ctx, isRoot: false, naming: this.optionNaming(name, d, option, i), flattenInto: nested ? name : null });
      node.options.push(child);
    });
    return node;
  }

  optionNaming(unionName, d, option, i) {
    const od = option._zod.def;
    if (d.discriminator && od.type === "object") {
      const lit = od.shape[d.discriminator]?._zod.def.values?.[0];
      if (lit !== undefined) return `${unionName}${pascal(String(lit).toLowerCase())}`;
    }
    return `${unionName}Option${i + 1}`;
  }

  /** 판별 union & 객체 — 형태마다 객체를 합친 판별 union으로 펼친다 */
  intersection(schema, ctx, desc, checks) {
    const d = schema._zod.def;
    const left = d.left._zod.def;
    const right = d.right._zod.def;
    if (left.type !== "union" || !left.discriminator || right.type !== "object") {
      throw new Error(`지원하지 않는 intersection @ ${ctx.root}`);
    }
    // 검증은 zod처럼 양쪽을 따로 하고(이슈가 같게 나온다), 출력 모델은 형태마다 객체를 합친 판별 union으로 만든다
    const merged = this.z.discriminatedUnion(
      left.discriminator,
      left.options.map((o) => o.extend(right.shape)),
    );
    const mergedNode = this.union(merged, ctx, desc, []);
    return {
      k: "intersection",
      schema,
      desc,
      checks,
      left: this.node(d.left, { ...ctx, isRoot: false }),
      right: this.node(d.right, { ...ctx, isRoot: false, plain: true }),
      merged: mergedNode,
    };
  }
}
