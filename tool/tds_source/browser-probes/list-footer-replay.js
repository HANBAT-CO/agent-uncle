// Run on ?family=list-footer-colors using the unmodified TDS Mobile 2.5.1.
// Exercise retained press/release contexts, not only one completed tap.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [];
  const theme = new URLSearchParams(location.search).get('theme') ?? 'light';
  const update = async patch => {
    window.tdsReference.updateFooter(patch);
    await frame();
    await sleep(100);
  };
  const sample = phase => {
    const content = document.querySelector('.tds-mobile-list-footer__content');
    const matrix = new DOMMatrixReadOnly(getComputedStyle(content).transform);
    const result = {
      phase,
      scale: matrix.a,
      shadow: +getComputedStyle(document.querySelector('.tds-mobile-list-footer__shadow')).opacity,
      colors: [...document.querySelectorAll('.tds-mobile-list-footer__text,.tds-mobile-list-footer__icon')].map(node => ({
        id: node.dataset.case ?? node.querySelector('[data-case]')?.dataset.case,
        color: getComputedStyle(node.querySelector('[data-case]') ?? node).color,
        inlineColor: node.style.color,
        iconColor: getComputedStyle(node).getPropertyValue('--icon-color').trim(),
      })),
    };
    traces.push(result);
    return result;
  };
  const down = () => document.querySelector('[data-case="footer"]').dispatchEvent(
    new MouseEvent('mousedown', {bubbles:true, button:0, buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
  const changeColor = () => update({children:[
    {id:'inherit',label:'상속'},
    {id:'custom',label:'명시',color:'#3182f6'},
  ]});
  const reset = async (generation, theme) => {
    up();
    await update({generation,theme,textColor:undefined,iconColor:undefined,
      children:[{id:'inherit',label:'상속'},{id:'custom',label:'명시',color:'#f04452'}],
      icons:[{id:'inherit-icon'},{id:'custom-icon',color:'#03b26c'}],
    });
  };
  {
    for (const scenario of ['repeated-down','cycle-repress','partial-release','repeated-partial','same-turn']) {
      const id = `${theme}-${scenario}`;
      await reset(id, theme);
      sample(`${id}-initial`);
      down();
      await sleep(scenario === 'partial-release' || scenario === 'repeated-partial' ? 60 : 620);
      sample(`${id}-first-press`);
      if (scenario !== 'repeated-down') {
        up();
        await sleep(scenario === 'same-turn' || scenario === 'cycle-repress' ? 620 : 45);
        sample(`${id}-first-release`);
      }
      if (scenario !== 'partial-release') {
        down();
        sample(`${id}-second-down-immediate`);
        if (scenario === 'same-turn') {
          up();
        } else {
          await sleep(scenario === 'repeated-partial' ? 80 : 620);
          sample(`${id}-second-press`);
          if (scenario === 'repeated-partial') up();
        }
      }
      await sleep(620);
      sample(`${id}-before-change`);
      await changeColor();
      sample(`${id}-after-change`);
      up();
      await sleep(620);
      sample(`${id}-final-release`);
    }
  }
  for (const scenario of ['fresh-same-turn', 'equivalent-raw-color', 'unrendered-repress']) {
    const id = `${theme}-${scenario}`;
    await reset(id, theme);
    if (scenario === 'equivalent-raw-color') {
      await update({children:[
        {id:'inherit',label:'상속'},
        {id:'custom',label:'명시',color:'var(--adaptiveRed500)'},
      ]});
    }
    sample(`${id}-initial`);
    down();
    sample(`${id}-immediate-down`);
    if (scenario === 'equivalent-raw-color') await sleep(620);
    sample(`${id}-before-up`);
    up();
    sample(`${id}-immediate-up`);
    if (scenario === 'unrendered-repress') down();
    await sleep(620);
    sample(`${id}-before-change`);
    await update({children:[
      {id:'inherit',label:'상속'},
      {id:'custom',label:'명시',color:scenario === 'equivalent-raw-color' ? (theme === 'dark' ? '#f04251' : '#f04452') : '#3182f6'},
    ]});
    sample(`${id}-after-change`);
    down(); await sleep(620); up(); await sleep(620);
    sample(`${id}-next-cycle`);
    await changeColor();
    sample(`${id}-base-change`);
  }
  await update({generation:'fresh-distinct-descendants',theme,textColor:undefined,iconColor:undefined,
    children:[{id:'custom',label:'명시',color:'#f04452'},{id:'inherit',label:'상속'}]});
  sample(`${theme}-distinct-initial`);
  down(); up(); await sleep(60);
  sample(`${theme}-distinct-release`);
  await sleep(620);
  sample(`${theme}-distinct-settled`);
  const at = phase => traces.find(row => row.phase === `${theme}-${phase}`);
  const assertInk = (row, expected) => {
    for (const id of ['inherit','custom']) {
      if (row.colors.find(color => color.id === id).color !== expected) throw new Error(`Color changed: ${JSON.stringify(row)}`);
    }
  };
  for (const [scenario,saved] of [
    ['repeated-down','first-press'],['cycle-repress','first-press'],
    ['partial-release','first-press'],['repeated-partial','second-press'],
    ['same-turn','first-release'],
  ]) {
    const before = at(`${scenario}-${saved}`), after = at(`${scenario}-after-change`);
    if (after.scale !== before.scale || after.shadow !== before.shadow) throw new Error(`Context shape changed: ${JSON.stringify(after)}`);
    assertInk(after,before.colors.find(color => color.id === 'inherit').color);
    for (const color of after.colors.filter(color => color.id.includes('icon'))) {
      if (color.color !== 'rgb(3, 178, 108)' || color.iconColor !== '') throw new Error('CSS-variable cleanup changed');
    }
  }
  for (const scenario of ['fresh-same-turn','unrendered-repress']) {
    const down = at(`${scenario}-immediate-down`), after = at(`${scenario}-after-change`);
    if (down.colors.some(color => color.inlineColor || color.iconColor)) throw new Error('Untouched zero-playhead motion stopped being lazy');
    assertInk(after,'rgb(49, 130, 246)');
    if (after.scale !== 1 || after.shadow !== 0) throw new Error('Unrendered context left a shape snapshot');
  }
  const equivalent = at('equivalent-raw-color-after-change');
  assertInk(equivalent,theme === 'dark' ? 'rgb(240, 66, 81)' : 'rgb(240, 68, 82)');
  if (equivalent.scale !== 1 || equivalent.shadow !== 0) throw new Error('Equivalent resolved dependencies recreated a context');
  const distinctInitial = at('distinct-initial'), distinct = at('distinct-release');
  const custom = row => row.colors.find(color => color.id === 'custom').color;
  const inherited = row => row.colors.find(color => color.id === 'inherit').color;
  if (custom(distinct) === custom(distinctInitial) || custom(distinct) === inherited(distinct)) throw new Error('Fresh release lost the individual CSS start color');
  for (const icon of distinct.colors.filter(color => color.id.includes('icon'))) {
    const channels = icon.iconColor.match(/^rgba\(([^)]+)\)$/)?.[1].split(',').map(Number);
    if (!channels || !(channels[3] > 0 && channels[3] < 1)) throw new Error('Unset icon variable stopped initializing from transparent black');
    if (Math.abs(channels[1] - Math.round(178 * channels[3])) > 1) throw new Error('Icon RGB did not interpolate with the missing variable');
  }
  assertInk(at('distinct-settled'),inherited(distinctInitial));
  return traces;
})();
