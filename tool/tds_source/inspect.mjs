// Print only the selected declarations and their immediate runtime dependencies.
import ts from 'typescript';
import { readFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { format } from 'prettier';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const inventory = JSON.parse(await readFile(resolve(root, 'packages/tds_mobile_flutter/reference/api-inventory.json'), 'utf8'));
const source = await format(await readFile(resolve(root, 'tool/tds_source/node_modules/@toss/tds-mobile/dist/esm/index.js'), 'utf8'), {parser: 'babel'});
const file = ts.createSourceFile('source.js', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
const nodes = new Map();
const typeSource = await readFile(resolve(root, 'tool/tds_source/node_modules/@toss/tds-mobile/dist/esm/index.d.ts'), 'utf8');
const typeFile = ts.createSourceFile('index.d.ts', typeSource, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
const typePrinter = ts.createPrinter({ removeComments: true });
const typeNodes = new Map(typeFile.statements.filter(s => s.name).map(s => [s.name.text, s]));
for (const statement of file.statements) {
  if (ts.isVariableStatement(statement)) for (const d of statement.declarationList.declarations) nodes.set(d.name.getText(file), d);
  else if (statement.name) nodes.set(statement.name.getText(file), statement);
}
const args = process.argv.slice(2);
for (const name of args.filter(a => !a.startsWith('--'))) {
  const api = inventory.exports.find(e => e.name === name && e.package === 'tds-mobile');
  const typeNode=typeNodes.get(name);
  console.log(`\n// ${name}`);
  if (!args.includes('--runtime-only')) console.log(api?.declaration ?? (typeNode ? typePrinter.printNode(ts.EmitHint.Unspecified,typeNode,typeFile) : ''));
  if(args.includes('--types-only')) continue;
  const node = nodes.get(api?.runtimeSymbol ?? name);
  if (!node) continue;
  console.log(node.getText(file));
  if (args.includes('--deps')) {
    const dependencies = new Set();
    function visit(n) { if (ts.isIdentifier(n) && nodes.has(n.text) && n !== node.name) dependencies.add(n.text); ts.forEachChild(n, visit); }
    visit(node);
    for (const dep of dependencies) console.log(`\n// dependency ${dep}\n${nodes.get(dep).getText(file)}`);
  }
}
