// Node SDK와 Dart SDK를 같은 자료로 실행해 결과를 비교한다. 차이가 있으면 종료 코드 1이다.
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { isDeepStrictEqual } from "node:util";

const here = new URL(".", import.meta.url).pathname;
const run = (cmd, args, cwd) => JSON.parse(execFileSync(cmd, args, { cwd, encoding: "utf8", maxBuffer: 256 << 20 }));

const node = run("node", ["node-runner.mjs"], here);
const dart = run("dart", ["run", "tool/parity_runner.dart", here], `${here}../../packages/storefront-sdk`);
mkdirSync(`${here}out`, { recursive: true });
writeFileSync(`${here}out/node.json`, JSON.stringify(node, null, 2));
writeFileSync(`${here}out/dart.json`, JSON.stringify(dart, null, 2));

function diff(a, b, path = "$", out = []) {
  if (isDeepStrictEqual(a, b)) return out;
  if (a && b && typeof a === "object" && typeof b === "object" && Array.isArray(a) === Array.isArray(b)) {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) diff(a[k], b[k], `${path}.${k}`, out);
  } else {
    out.push(`${path}: node=${JSON.stringify(a)?.slice(0, 200)} dart=${JSON.stringify(b)?.slice(0, 200)}`);
  }
  return out;
}

const verbose = process.argv.includes("--verbose");
let failed = 0;
let total = 0;
for (const key of ["scenarios", "schemaCases"]) {
  let bad = 0;
  for (let i = 0; i < node[key].length; i++) {
    total++;
    const d = diff(node[key][i], dart[key][i]);
    if (d.length) {
      bad++;
      failed++;
      console.log(`✗ ${node[key][i].name}`);
      for (const line of d.slice(0, verbose ? 50 : 3)) console.log(`    ${line}`);
    } else if (verbose) console.log(`✓ ${node[key][i].name}`);
  }
  console.log(`${key}: ${node[key].length - bad}/${node[key].length} 일치`);
}
process.exit(failed ? 1 : 0);
