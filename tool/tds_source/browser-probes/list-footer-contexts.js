// Run on the unchanged 2.5.1 ?family=list-footer-colors fixture. Press depends
// on normal + pressed colors; release depends only on normal colors.
return (async () => {
  await window.tdsReference.ready;
  const theme = new URLSearchParams(location.search).get('theme') ?? 'light';
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [];
  const adaptive = name => `var(--adaptive${name[0].toUpperCase()}${name.slice(1)})`;
  const child = token => [
    {id:'inherit', label:'상속'},
    {id:'custom', label:'명시', color:adaptive(token)},
  ];
  const icons = token => [{id:'inherit-icon'},{id:'custom-icon',color:adaptive(token)}];
  const update = async patch => {
    window.tdsReference.updateFooter(patch);
    await frame();
  };
  const sample = phase => {
    const content = document.querySelector('.tds-mobile-list-footer__content');
    const result = {phase, scale:new DOMMatrixReadOnly(getComputedStyle(content).transform).a,
      shadow:+getComputedStyle(document.querySelector('.tds-mobile-list-footer__shadow')).opacity,
      colors:[...document.querySelectorAll('.tds-mobile-list-footer__text,.tds-mobile-list-footer__icon')].map(node => ({
        id:node.dataset.case ?? node.querySelector('[data-case]')?.dataset.case,
        color:getComputedStyle(node.querySelector('[data-case]') ?? node).color,
        inlineColor:node.style.color,
        iconColor:getComputedStyle(node).getPropertyValue('--icon-color').trim(),
      }))};
    traces.push(result);
    return result;
  };
  const down = () => document.querySelector('[data-case="footer"]').dispatchEvent(
    new MouseEvent('mousedown',{bubbles:true,button:0,buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,button:0}));
  const reset = async (generation, textToken='grey200', iconToken='green500') => {
    up();
    await update({generation,theme,textColor:undefined,iconColor:undefined,
      children:child(textToken),icons:icons(iconToken)});
    await sleep(60);
  };
  for (const target of ['text','icon']) {
    const label = `${target}-completed`;
    await reset(label, target === 'text' ? 'grey200' : 'red500', target === 'icon' ? 'grey200' : 'green500');
    sample(`${label}-initial`);
    down(); await sleep(620); sample(`${label}-pressed`);
    up(); await sleep(620); sample(`${label}-released`);
    await update(target === 'text' ? {children:child('hairlineBorder')} : {icons:icons('hairlineBorder')});
    sample(`${label}-press-only-reset`);
    await update(target === 'text' ? {children:child('blue500')} : {icons:icons('blue500')});
    sample(`${label}-both-reset`);
  }
  await reset('release-running');
  down(); await sleep(620); sample('release-running-pressed');
  up(); await sleep(35); sample('release-running-before-change');
  await update({children:child('hairlineBorder')});
  sample('release-running-after-change');
  await sleep(620); sample('release-running-settled');
  await update({children:child('blue500')}); sample('release-running-both-reset');

  await reset('late-targets','hairlineBorder');
  await update({children:[...child('grey200'),{id:'late',label:'추가',color:adaptive('grey200')}]});
  sample('late-targets-initial');
  down(); await sleep(620); sample('late-targets-pressed');
  up(); await sleep(620); sample('late-targets-released');
  await update({children:[...child('blue500'),{id:'late',label:'추가',color:adaptive('blue500')}]});
  sample('late-targets-both-reset');

  for (const target of ['text','icon']) {
    const label = `${target}-semantic-alias`;
    await reset(label, target === 'text' ? 'greyBackground' : 'red500', target === 'icon' ? 'greyBackground' : 'green500');
    down(); await sleep(620); sample(`${label}-pressed`);
    await update(target === 'text' ? {children:child('backgroundLevelB01')} : {icons:icons('backgroundLevelB01')});
    sample(`${label}-press-only-reset`);
    up(); await sleep(620); sample(`${label}-released`);
  }
  for (const level of [800,900]) {
    const label = `opacity-${level}`;
    await reset(label,`opacity${level}`);
    down(); await sleep(620); sample(`${label}-pressed`);
    if (level === 900) { up(); await sleep(620); sample(`${label}-released`); }
    await update({children:child(`greyOpacity${level}`)});
    sample(`${label}-changed`);
    up(); await sleep(620);
  }

  const at = phase => traces.find(row => row.phase === phase);
  const check = (condition, message) => { if (!condition) throw new Error(message); };
  const textColor = (row,id='inherit') => row.colors.find(color => color.id === id).color;
  for (const target of ['text','icon']) {
    const label = `${target}-completed`;
    const initial = at(`${label}-initial`), pressed = at(`${label}-pressed`);
    const only = at(`${label}-press-only-reset`), both = at(`${label}-both-reset`);
    check(only.scale === 1 && only.shadow === 0, `${label}: release context was also recreated`);
    check(textColor(only) === textColor(initial), `${label}: press-only text cleanup changed`);
    check(only.colors.every(color => !color.inlineColor && !color.iconColor), `${label}: press cleanup left inline styles`);
    check(both.scale === .96 && both.shadow === 1, `${label}: retained release shape snapshot lost`);
    check(textColor(both) === textColor(pressed), `${label}: retained release color snapshot lost`);
    const alias = at(`${target}-semantic-alias-press-only-reset`);
    check(alias.scale === 1 && alias.shadow === 0, `${target}: CSS-variable identity no longer resets only press`);
  }
  const runningBefore = at('release-running-before-change'), runningAfter = at('release-running-after-change');
  check(runningAfter.scale >= runningBefore.scale && runningAfter.scale <= 1, 'Release stopped or restarted after press-only change');
  check(at('release-running-settled').scale === 1, 'Retained release did not finish');
  check(at('release-running-both-reset').scale === .96, 'Running release lost its saved shape');
  const latePress = at('late-targets-pressed'), lateRelease = at('late-targets-released');
  check(textColor(lateRelease,'late') === textColor(latePress,'late'), 'New target unexpectedly joined the old release context');
  check(textColor(lateRelease) !== textColor(lateRelease,'late'), 'Independent target snapshots collapsed');
  check(at('opacity-800-changed').scale === (theme === 'dark' ? 1 : .96), 'Pressed CSS serialization identity changed');
  check(at('opacity-900-changed').scale === (theme === 'dark' ? .96 : 1), 'Normal CSS serialization identity changed');
  return traces;
})();
