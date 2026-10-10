// Requires the original/gallery static servers at 5182/5181. No pixel resizing.
// node tool/tds_source/visual-capture.mjs before|after [typography|footer|edges]
import fs from 'node:fs';
import os from 'node:os';
import {spawnSync} from 'node:child_process';

const [phase, group] = process.argv.slice(2);
if (!['before','after'].includes(phase) || (group && !['typography','footer','edges'].includes(group))) {
  throw new Error('Usage: visual-capture.mjs before|after [typography|footer|edges]');
}
const browse = process.env.TDS_BROWSE_BIN ?? `${os.homedir()}/.claude/skills/gstack/browse/dist/browse`;
const cases = [
  ...['regular','medium','semibold','bold'].flatMap(weight => [
    {group:'typography', id:`type-${weight}`, query:{family:'visual-typography',weight}, height:360},
    {group:'typography', id:`type-${weight}-multiline`, query:{family:'visual-typography',weight,state:'multiline'}, height:630},
  ]),
  {group:'footer',id:'footer-default',query:{family:'visual-footer'},height:200},
  {group:'footer',id:'footer-pressed',query:{family:'visual-footer',state:'pressed'},height:200},
  {group:'footer',id:'footer-multiline',query:{family:'visual-footer',variant:'multiline',width:'210'},height:200},
  {group:'footer',id:'footer-shadow',query:{family:'visual-footer',variant:'shadow'},height:200},
  {group:'footer',id:'footer-shadow-fractional',query:{family:'visual-footer',variant:'shadow',width:'333.25'},height:200},
  // The 200px historical crop stays comparable. Also inspect the entire label.
  ...(phase === 'after' ? [{group:'footer',id:'footer-multiline-full',
    query:{family:'visual-footer',variant:'multiline',width:'210'},height:280}] : []),
  ...['from-only','repress','nested','bubbled','late','recaptured'].map(edgeCase => ({
    group:'edges', id:`edge-${edgeCase}`, query:{edgeCase},
    height:['from-only','repress'].includes(edgeCase) ? 100 : 130,
  })),
].filter(specimen => !group || specimen.group === group);
const reports = [];
for (const theme of ['light','dark']) {
  for (const scale of [100,160]) {
    for (const specimen of cases) {
      const name = `${specimen.id}-${theme}-${scale}`;
      const commands = [['viewport','390x844','--scale','1']];
      for (const engine of ['react','flutter']) {
        const family = specimen.group === 'edges'
          ? !['from-only','repress'].includes(specimen.query.edgeCase) ? 'list-footer-nested'
            : engine === 'react' ? 'list-footer-colors' : 'list-footer-undefined'
          : specimen.query.family;
        const query = new URLSearchParams({...specimen.query,family,theme,scale});
        commands.push(['goto',`http://127.0.0.1:${engine === 'react' ? 5182 : 5181}/?${query}`],
          ['eval',`tool/tds_source/browser-probes/${specimen.group === 'edges'
            ? `${engine}-footer-edge-capture.js` : 'visual-geometry.js'}`],
          ['screenshot',`.context/visual-${phase}-${engine}-${name}.png`,'--clip',`0,0,390,${specimen.height}`],
          ['console','--errors']);
      }
      const result = spawnSync(browse,['chain'],{input:JSON.stringify(commands),encoding:'utf8',timeout:45000});
      const log = `.context/visual-${phase}-${name}.log`;
      fs.writeFileSync(log,result.stdout + result.stderr);
      if (result.status !== 0 || result.error || /\[(?:eval|goto|screenshot)\] ERROR/.test(result.stdout)
          || (result.stdout.match(/Screenshot saved/g) ?? []).length !== 2) {
        throw new Error(`Capture failed, inspect ${log}: ${result.error ?? result.status}`);
      }
      const output = `.context/visual-${phase}-paired-${name}.png`;
      const comparison = spawnSync('uv',['run','tool/tds_source/compare_images.py',
        `.context/visual-${phase}-react-${name}.png`,`.context/visual-${phase}-flutter-${name}.png`,
        '--height',`${specimen.height}`,'--output',output],{encoding:'utf8'});
      if (comparison.status !== 0) throw new Error(comparison.stderr);
      const report = {name,...JSON.parse(comparison.stdout)};
      reports.push(report);
      console.log(`${name}: delta>16=${report.pixelsDeltaAbove16}, mean=${report.meanMaxChannelDelta}`);
    }
  }
}
fs.writeFileSync(`.context/visual-${phase}-${group ?? 'all'}-report.json`,JSON.stringify(reports,null,2)+'\n');
