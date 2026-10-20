// Node SDK와 Dart SDK를 같은 시나리오로 실행해 요청·결과를 비교한다. 차이가 있으면 종료 코드 1이다.
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { isDeepStrictEqual } from "node:util";

const here = new URL(".", import.meta.url).pathname;
const run = (cmd, args, cwd) => JSON.parse(execFileSync(cmd, args, { cwd, encoding: "utf8", maxBuffer: 64 << 20 }));

const node = run("node", ["node-runner.mjs"], here);
const dart = run("dart", ["run", "tool/parity_runner.dart", `${here}scenarios.json`], `${here}../../packages/storefront-sdk`);
mkdirSync(`${here}out`, { recursive: true });
writeFileSync(`${here}out/node.json`, JSON.stringify(node, null, 2));
writeFileSync(`${here}out/dart.json`, JSON.stringify(dart, null, 2));

function diff(a, b, path = "$", out = []) {
  if (isDeepStrictEqual(a, b)) return out;
  if (a && b && typeof a === "object" && typeof b === "object" && Array.isArray(a) === Array.isArray(b)) {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) diff(a[k], b[k], `${path}.${k}`, out);
  } else {
    out.push(`${path}: node=${JSON.stringify(a)} dart=${JSON.stringify(b)}`);
  }
  return out;
}

let failed = 0;
for (let i = 0; i < node.length; i++) {
  const d = diff(node[i], dart[i]);
  console.log(`${d.length ? "✗" : "✓"} ${node[i].name}`);
  for (const line of d) console.log(`    ${line}`);
  if (d.length) failed++;
}
console.log(`\n${node.length - failed}/${node.length} 일치`);
process.exit(failed ? 1 : 0);
