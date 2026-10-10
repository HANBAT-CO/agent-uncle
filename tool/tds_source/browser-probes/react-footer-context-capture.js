// Paired capture of the unchanged 2.5.1 list-footer-colors fixture.
// contextCase selects cleanup, restore, late or alias. No source CSS is edited.
return (async () => {
  await window.tdsReference.ready;
  const phase = new URLSearchParams(location.search).get('contextCase');
  if (!['cleanup', 'restore', 'late', 'alias'].includes(phase)) {
    throw new Error(`Unknown Footer context case: ${phase}`);
  }
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const adaptive = name => `var(--adaptive${name[0].toUpperCase()}${name.slice(1)})`;
  const children = (token, late = false) => [
    {id:'inherit', label:'상속'},
    {id:'custom', label:'명시', color:adaptive(token)},
    ...(late ? [{id:'late', label:'추가', color:adaptive(token)}] : []),
  ];
  const update = async patch => {
    window.tdsReference.updateFooter(patch);
    await sleep(180);
  };
  const snapshot = () => ({
    scale: new DOMMatrixReadOnly(getComputedStyle(
      document.querySelector('.tds-mobile-list-footer__content')).transform).a,
    shadow: +getComputedStyle(document.querySelector('.tds-mobile-list-footer__shadow')).opacity,
    colors: [...document.querySelectorAll('.tds-mobile-list-footer__text')]
      .map(node => getComputedStyle(node).color),
  });
  const check = (value, message) => { if (!value) throw new Error(`${phase}: ${message}`); };
  const down = () => document.querySelector('[data-case="footer"]').dispatchEvent(
    new MouseEvent('mousedown', {bubbles:true, button:0, buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
  const token = phase === 'late' ? 'hairlineBorder' : phase === 'alias' ? 'greyBackground' : 'grey200';
  await update({generation:phase, textColor:undefined, iconColor:undefined,
    children:children(token), icons:[{id:'inherit-icon'}, {id:'custom-icon',color:adaptive('green500')}]});
  const initial = snapshot();
  if (phase === 'late') await update({children:children('grey200', true)});
  down();
  await sleep(450);
  const pressed = snapshot();
  check(pressed.scale === .96 && pressed.shadow === 1, 'press did not finish');
  if (phase === 'alias') {
    await update({children:children('backgroundLevelB01')});
    check(snapshot().scale === 1, 'semantic alias did not recreate press');
  }
  up();
  await sleep(450);
  if (phase === 'cleanup' || phase === 'restore') {
    await update({children:children('hairlineBorder')});
    const cleanup = snapshot();
    check(cleanup.scale === 1 && cleanup.shadow === 0, 'press cleanup lost the unpressed shape');
    check(cleanup.colors.every(color => color === initial.colors[0]), 'press cleanup retained an inline color');
    if (phase === 'restore') await update({children:children('blue500')});
  }
  const result = snapshot();
  if (phase === 'restore') {
    check(result.scale === .96 && result.shadow === 1, 'release save was lost');
    check(result.colors.every(color => color === pressed.colors[0]), 'release saved text was lost');
  }
  if (phase === 'late') {
    check(result.colors[0] === initial.colors[0] && result.colors[1] === initial.colors[1], 'old release targets changed');
    check(result.colors[2] === pressed.colors[2] && result.colors[2] !== result.colors[0], 'late text joined the old release');
  }
  if (phase === 'alias') check(result.scale === 1 && result.shadow === 0, 'alias cleanup did not persist');
  return {phase, ...result};
})();
