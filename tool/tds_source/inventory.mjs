// Index syntax, not regex: aliases and compound component exports are public API.
import ts from 'typescript';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { format } from 'prettier';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
export const sourceRoot = resolve(root, '.context/tds-source');
const out = resolve(root, 'packages/tds_mobile_flutter/reference');
await mkdir(out, { recursive: true });
await mkdir(sourceRoot, { recursive: true });
const manifest = { version: '2.5.1', packages: [], exports: [] };
const printer = ts.createPrinter({ removeComments: true });
for (const name of ['tds-mobile', 'tds-mobile-ait']) {
  const packageRoot = resolve(root, 'tool/tds_source/node_modules/@toss', name);
  const typePath = resolve(packageRoot, 'dist/esm/index.d.ts');
  const program = ts.createProgram([typePath], { skipLibCheck: true, moduleResolution: ts.ModuleResolutionKind.Bundler, module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 });
  const checker = program.getTypeChecker();
  const file = program.getSourceFile(typePath);
  const exports = checker.getExportsOfModule(checker.getSymbolAtLocation(file));
  const reactMetadata = new Set(['$$typeof','displayName','propTypes','defaultProps','contextTypes']);
  function publicMembers(symbol, declaration, ancestors = new Set()) {
    if (!declaration || ancestors.has(symbol)) return [];
    const next = new Set([...ancestors, symbol]);
    const type = checker.getTypeOfSymbolAtLocation(symbol, declaration);
    if(type.flags & (ts.TypeFlags.StringLike | ts.TypeFlags.NumberLike | ts.TypeFlags.BooleanLike | ts.TypeFlags.BigIntLike | ts.TypeFlags.ESSymbolLike | ts.TypeFlags.Any | ts.TypeFlags.Unknown)) return [];
    const members = new Map(checker.getPropertiesOfType(type).filter(p => !reactMetadata.has(p.name)).map(p => [p.name,p]));
    // Namespace type exports (e.g. Asset.FrameShapeType) are not runtime properties.
    if (symbol.exports) for(const member of checker.getExportsOfModule(symbol)) members.set(member.name,member);
    return [...members.values()].map(p => {
      const resolved = p.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(p) : p;
      const d=resolved.declarations?.[0];
      return {name:p.name,kind:resolved.flags & ts.SymbolFlags.Value ? 'runtime' : 'type',
        signature:resolved.declarations?.map(d=>printer.printNode(ts.EmitHint.Unspecified,d,d.getSourceFile())).join('\n'),
        members:next.size < 6 ? publicMembers(resolved,d,next) : [],
      };
    });
  }
  const runtime = await readFile(resolve(packageRoot, 'dist/esm/index.js'), 'utf8');
  const runtimeFile = ts.createSourceFile('index.js', runtime, ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
  const runtimeNames = new Map();
  for (const statement of runtimeFile.statements) {
    if (ts.isExportDeclaration(statement) && statement.exportClause && ts.isNamedExports(statement.exportClause)) {
      for (const element of statement.exportClause.elements) runtimeNames.set(element.name.text, element.propertyName?.text ?? element.name.text);
    }
  }
  const hash = (content) => createHash('sha256').update(content).digest('hex');
  manifest.packages.push({ name: `@toss/${name}`, version: '2.5.1', javascriptSha256: hash(runtime), declarationsSha256: hash(await readFile(typePath)) });
  await writeFile(resolve(sourceRoot, `${name}.js`), await format(runtime, { parser: 'babel' }));
  for (const exported of exports) {
    const symbol = exported.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(exported) : exported;
    const declarations = symbol.declarations ?? [];
    const declaration = declarations[0];
    const subcomponents = runtimeNames.has(exported.name) ? publicMembers(symbol, declaration) : [];
    manifest.exports.push({
      package: name, name: exported.name,
      kind: runtimeNames.has(exported.name) ? (/^use[A-Z]|^useOverlay_/.test(exported.name) ? 'hook' : /^[A-Z]/.test(exported.name) ? 'runtime' : 'utility') : 'type',
      runtimeSymbol: runtimeNames.get(exported.name),
      declaration: declarations.map(d => printer.printNode(ts.EmitHint.Unspecified, d, d.getSourceFile())).join('\n'),
      sourceLine: declaration ? declaration.getSourceFile().getLineAndCharacterOfPosition(declaration.getStart()).line + 1 : null,
      subcomponents,
    });
  }
}
manifest.exports.sort((a, b) => `${a.package}/${a.name}`.localeCompare(`${b.package}/${b.name}`));
await writeFile(resolve(out, 'api-inventory.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify({ packages: manifest.packages, counts: Object.fromEntries(['runtime', 'hook', 'utility', 'type'].map(kind => [kind, manifest.exports.filter(e => e.kind === kind).length])), subcomponents: manifest.exports.reduce((n,e) => n + e.subcomponents.length,0) },null,2));
