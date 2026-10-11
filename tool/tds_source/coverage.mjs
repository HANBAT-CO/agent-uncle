// Inventory completeness is not implementation completeness. Every original API
// and recursive member is recorded, including pending and DOM-only APIs.
import { readFile, writeFile, access } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const base = resolve(root, 'packages/tds_mobile_flutter');
const inventory = JSON.parse(await readFile(resolve(base, 'reference/api-inventory.json')));
const map = JSON.parse(await readFile(resolve(base, 'reference/native-mapping.json')));
// Audited families keep related constructor/compound prop adaptations together.
// Each family remains partial until every stated source contract is verified.
const families = (await Promise.all(['native-families.json', 'native-additions.json', 'native-completion.json', 'native-constants.json', 'native-wrappers.json'].map(async file => JSON.parse(await readFile(resolve(base, 'reference', file)))))).flat();
for (const { sources, ...mapping } of families) {
  for (const source of sources) {
    if (source in map) throw new Error(`Duplicate native mapping: ${source}`);
    map[source] = { status: 'partial', ...mapping };
  }
}
const seen = new Set();
function entry(api, name, members) {
  const id = `${api.package}:${name}`;
  const mapping = map[id] ?? map[name];
  if (mapping) seen.add(map[id] ? id : name);
  return { source: id, kind: api.kind, status: mapping?.status ?? 'pending',
    dart: mapping?.dart ?? [], files: mapping?.files ?? [],
    verified: mapping?.verified ?? [], differences: mapping?.differences ?? [],
    remaining: mapping?.remaining ?? ['Native implementation and verification required.'],
    members: members.map(m => entry({...m, package: api.package}, `${name}.${m.name}`, m.members ?? [])) };
}
const exports = inventory.exports.map(e => entry(e, e.name, e.subcomponents));
const flat = exports.flatMap(function flatten(e) { return [e, ...e.members.flatMap(flatten)]; });
for (const key of Object.keys(map)) if (!seen.has(key)) throw new Error(`Mapping not present in source inventory: ${key}`);
for (const e of flat) {
  for (const file of e.files) await access(resolve(base, file));
  const nativeSource = (await Promise.all(e.files.map(f => readFile(resolve(base, f), 'utf8')))).join('\n');
  for (const dart of e.dart) {
    const symbol = dart.split('.')[0];
    if (!new RegExp(`\\b${symbol}\\b`).test(nativeSource)) throw new Error(`Mapped Dart symbol missing: ${e.source} -> ${dart}`);
  }
  for (const evidence of e.verified) {
    if (evidence.startsWith('test/')) await access(resolve(base, evidence.split(':')[0]));
  }
  if (e.status === 'verified' && (!e.verified.length || e.remaining.length)) throw new Error(`Unsubstantiated verified status: ${e.source}`);
}
const counts = items => Object.fromEntries([...new Set(items.map(e => e.status))].sort().map(s => [s, items.filter(e => e.status === s).length]));
const result = { sourceVersion: inventory.version,
  policy: 'partial means a usable subset exists, not whole-export parity. Tests and visual evidence apply only to their stated cases. Native DOM adaptations never count as browser-equivalent.',
  counts: { topLevel: exports.length, topLevelStatus: counts(exports),
    topLevelByKind: Object.fromEntries([...new Set(exports.map(e => e.kind))].map(k => [k, counts(exports.filter(e => e.kind === k))])),
    members: flat.length - exports.length, allStatus: counts(flat) }, exports };
const output = JSON.stringify(result, null, 2)+'\n';
const path = resolve(base, 'reference/native-coverage.json');
if (process.argv.includes('--check')) {
  if (await readFile(path, 'utf8') !== output) throw new Error('Stale native-coverage.json: run node tool/tds_source/coverage.mjs');
} else await writeFile(path, output);
console.log(JSON.stringify(result.counts, null, 2));
