// Extract original-only measurements from visual-capture.mjs logs. No native
// measurements or hand-adjusted targets enter this regression fixture.
import fs from 'node:fs';
import os from 'node:os';
import {spawnSync} from 'node:child_process';

const phase = process.argv[2] ?? 'after';
if (!['before','after'].includes(phase)) throw new Error('Expected before|after');
const all = process.argv.includes('--all');
const scales = all ? [100,160,200] : [100,160];
const browse = process.env.TDS_BROWSE_BIN ?? `${os.homedir()}/.claude/skills/gstack/browse/dist/browse`;
function samples(name, collect) {
  const filename = `.context/visual-${collect ? 'metrics' : phase}-${name}.log`;
  if (collect) {
    const query = new URLSearchParams({family:'visual-typography',types:'all',theme:'light',...collect});
    const commands = [['viewport','390x844','--scale','1'],
      ['goto',`http://127.0.0.1:5182/?${query}`],
      ['eval','tool/tds_source/browser-probes/visual-geometry.js'],['console','--errors']];
    const result = spawnSync(browse,['chain'],{input:JSON.stringify(commands),encoding:'utf8',timeout:30000});
    fs.writeFileSync(filename,result.stdout+result.stderr);
    if (result.status !== 0 || result.error || /\[(?:eval|goto)\] ERROR/.test(result.stdout)) {
      throw new Error(`Original measurement failed: ${filename}`);
    }
    console.log(`Measured all text types: ${name}`);
  }
  const log = fs.readFileSync(filename,'utf8');
  const end = collect ? '\n\n[console]' : '\n\n[screenshot]';
  const data = JSON.parse(log.slice(log.indexOf('[eval] ')+7,log.indexOf(end)));
  if (data.engine !== 'react') throw new Error('Only original measurements are allowed');
  return data.samples;
}
const typography = [];
for (const weight of ['regular','medium','semibold','bold']) {
  for (const scale of scales) {
    for (const multiline of [false,true]) {
      for (const sample of samples(`type-${weight}${multiline ? '-multiline' : ''}-light-${scale}`,
          all ? {weight,scale,state:multiline ? 'multiline' : 'initial'} : null)) {
        if (sample.css.display !== 'block') throw new Error('Block Text fixture required');
        typography.push({type:sample.id.replace('type-',''),weight,scale,multiline,
          fontSize:parseFloat(sample.css.fontSize),lineHeight:parseFloat(sample.css.lineHeight),
          width:sample.rect.width,height:sample.rect.height,
          baselines:[...new Set(sample.lines.map(line => line.baseline-sample.rect.y))]});
      }
    }
  }
}
const footer = [100,160].map(scale => {
  const text = samples(`footer-default-light-${scale}`).find(sample => sample.id.includes('__text'));
  return {scale,fontSize:parseFloat(text.css.fontSize),lineHeight:text.rect.height,
    baseline:text.lines[0].baseline-text.rect.y};
});
const shadow = ['', '-fractional'].map(suffix => {
  const list = samples(`footer-shadow${suffix}-light-100`);
  const content = list.find(sample => sample.css.display === 'flex' && sample.id === 'visual-footer');
  const shade = list.find(sample => sample.id.includes('__shadow'));
  return {parentWidth:content.rect.width,rect:[shade.rect.x-content.rect.x,
    shade.rect.y-content.rect.y,shade.rect.width,shade.rect.height]};
});
const record = {source:'@toss/tds-mobile@2.5.1',renderer:'Chromium, DPR 1, Android typography',
  generator:`node tool/tds_source/visual-metrics.mjs ${phase}${all ? ' --all' : ''}`,typography,footer,shadow};
// Compact specimen rows keep the generated measurement diff reviewable.
const formatted = JSON.stringify(record,null,2).replace(
  /"typography": \[[\s\S]*?\n  \],\n  "footer"/,
  `"typography": [\n${typography.map(row=>'    '+JSON.stringify(row)).join(',\n')}\n  ],\n  "footer"`);
fs.writeFileSync('packages/tds_mobile_flutter/reference/visual-geometry.json',formatted+'\n');
console.log(`Recorded ${typography.length} text specimens, ${footer.length} Footer baselines, ${shadow.length} shadow bounds`);
