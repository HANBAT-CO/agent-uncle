// Inspect the pinned ESM objects without rendering, mutating or inventing IDs.
// These are React wrapper metadata, not additional visual components.
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const reference = resolve(here, '../../packages/tds_mobile_flutter/reference');
const inventory = JSON.parse(await readFile(resolve(reference, 'api-inventory.json')));
const entry = resolve(here, 'node_modules/@toss/tds-mobile/dist/esm/index.js');
const hash = createHash('sha256').update(await readFile(entry)).digest('hex');
if (hash !== inventory.packages.find(p => p.name === '@toss/tds-mobile').javascriptSha256) {
  throw new Error('Wrapper runtime does not match the pinned inventory.');
}
const original = await import(pathToFileURL(entry).href);

function descendants(nodes, prefix) {
  return nodes.flatMap(node => {
    const source = `${prefix}.${node.name}`;
    return [{ ...node, source }, ...descendants(node.members ?? [], source)];
  });
}
const metadata = inventory.exports
  .filter(api => api.package === 'tds-mobile')
  .flatMap(api => descendants(api.subcomponents, api.name))
  .filter(member =>
    member.name === 'id' && member.signature.trim() === 'id?: string;' ||
    member.name === 'type' && member.signature.trim() === 'readonly type: T;')
  .map(member => {
    const parts = member.source.split('.');
    const property = parts.pop();
    const owner = parts.reduce((object, key) => object[key], original);
    const descriptor = Object.getOwnPropertyDescriptor(owner, property);
    return {
      source: member.source,
      property,
      ownProperty: descriptor != null,
      valueType: typeof owner[property],
      wrapper: Symbol.keyFor(owner.$$typeof),
      ...(property === 'type' ? {
        innerWrapper: Symbol.keyFor(owner.type.$$typeof),
        renderType: typeof owner.type.render,
      } : {}),
    };
  });

const ids = metadata.filter(member => member.property === 'id');
const memos = metadata.filter(member => member.property === 'type');
if (ids.length !== 56 || memos.length !== 7 ||
    ids.some(member => member.ownProperty || member.valueType !== 'undefined' || member.wrapper !== 'react.forward_ref') ||
    memos.some(member => !member.ownProperty || member.wrapper !== 'react.memo' || member.innerWrapper !== 'react.forward_ref' || member.renderType !== 'function')) {
  throw new Error('Original wrapper contract changed; review the native adaptation.');
}

const constructors = {
  'FullSecureKeypad.type': ['TdsFullSecureKeypad.new', 'keypad.dart'],
  'SearchField.type': ['TdsSearchField.new', 'input_controls.dart'],
  'Post.H1.type': ['TdsPostH1.new', 'post.dart'],
  'Post.H2.type': ['TdsPostH2.new', 'post.dart'],
  'Post.H3.type': ['TdsPostH3.new', 'post.dart'],
  'Post.H4.type': ['TdsPostH4.new', 'post.dart'],
  'Post.Paragraph.type': ['TdsPostParagraph.new', 'post.dart'],
};
const mappings = [{
  sources: ids.map(member => member.source),
  dart: ['TdsComponentWithAs.id'],
  files: ['lib/src/foundation/api_adapters.dart'],
  verified: ['test/component_wrappers_test.dart'],
  differences: [
    'All 56 optional static IDs are absent in the original ESM runtime. Nullable immutable metadata on an explicit native builder adapter replaces mutable JavaScript component metadata. It is not a DOM id, Flutter Key or semantics identifier.',
  ],
  remaining: ['Native widget classes do not expose JavaScript reflection or mutable static properties. Parent component rendering/behavior remains partial.'],
}, ...memos.map(member => {
  const [dart, file] = constructors[member.source];
  return {
    sources: [member.source],
    dart: [dart],
    files: [`lib/src/components/${file}`],
    verified: ['test/component_wrappers_test.dart'],
    differences: ['An unwrapped native constructor tear-off replaces React memo.type. Flutter element/key reconciliation replaces React memo/forwardRef objects; it does not promise React render-call counts or JavaScript object identity.'],
    remaining: ['Parent component props, pixels and host behavior remain partial. There is no native React wrapper object.'],
  };
})];

async function output(name, data) {
  const path = resolve(reference, name);
  const text = `${JSON.stringify(data, null, 2)}\n`;
  if (process.argv.includes('--check')) {
    if (await readFile(path, 'utf8') !== text) throw new Error(`Stale ${name}: run node tool/tds_source/wrappers.mjs`);
  } else {
    await writeFile(path, text);
  }
}
await output('component-wrappers.json', {
  sourceVersion: inventory.version,
  javascriptSha256: hash,
  scope: 'Pinned original ESM runtime metadata, not rendered visual/behavioral parity.',
  metadata,
});
await output('native-wrappers.json', mappings);
process.stdout.write(`Audited ${ids.length} absent optional IDs and ${memos.length} memo wrappers. All native mappings remain partial.\n`);
