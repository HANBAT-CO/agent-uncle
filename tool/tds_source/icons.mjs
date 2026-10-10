// Bundle the exact official icons used by native primitives for offline startup.
import { mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const directory = resolve(root, 'packages/tds_mobile_flutter/assets/icons');
await mkdir(directory, { recursive: true });
const names = ['icn-arrow-rightwards', 'icon-arrow-down-mono', 'icon-x-circle-mono',
  'icon-arrow-right-small-mono', 'icon-arrow-up-sidebar-mono',
  'icon-eye-on-mono', 'icon-eye-off-mono', 'icn-searchfield', 'icn-delete',
  'icon-arrow-right-mono', 'icon-arrow-up-mono', 'icon-star-mono',
  'icon-chip-arrow-down-mono', 'icon-chip-x-mono',
  'icon-system-arrow-back-ios-outlined', 'icon-system-arrow-back-android-outlined',
  ...Array.from({length: 9}, (_, i) => ['light', 'dark'].map(theme => `icon-step${i+1}-rounded-${theme}`)).flat()];
const manifest = [];
for (const name of names) {
  const url = `https://static.toss.im/icons/svg/${name}.svg`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (!bytes.toString().includes('<svg')) throw new Error(`Not an SVG: ${url}`);
  await writeFile(resolve(directory, `${name}.svg`), bytes);
  manifest.push({ name, url, sha256: createHash('sha256').update(bytes).digest('hex') });
}
await writeFile(resolve(directory, 'provenance.json'), JSON.stringify(manifest, null, 2)+'\n');
console.log(`Downloaded ${manifest.length} original icons without modification.`);
