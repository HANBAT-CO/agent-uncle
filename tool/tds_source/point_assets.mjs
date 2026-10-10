import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const directory = resolve(root, 'packages/tds_mobile_flutter/assets/point');
await mkdir(directory, { recursive: true });
const manifest = [];
for (const path of ['3d-common/point-spot.json', 'lotties/point-blue2.png', 'lotties/point-green2.png', 'lotties/point-purple2.png', 'icons/svg/icon-point-circle-mono.svg']) {
  const url = `https://static.toss.im/${path}`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  const name = path.split('/').at(-1);
  await writeFile(resolve(directory, name), bytes);
  manifest.push({name, url, sha256: createHash('sha256').update(bytes).digest('hex')});
}
await writeFile(resolve(directory, 'provenance.json'), JSON.stringify(manifest, null, 2)+'\n');
console.log(`Downloaded ${manifest.length} unmodified point assets.`);
