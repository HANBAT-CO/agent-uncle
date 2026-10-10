// Original 2.5.1 behavior when aa(disabledBlue500) has no next color token.
// Run on ?family=list-footer-colors. No original package code is changed.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const adaptive = name => `var(--adaptive${name[0].toUpperCase()}${name.slice(1)})`;
  const traces = [];
  const children = token => [
    {id:'inherit',label:'상속'},
    {id:'different',label:'명시',color:adaptive('red500')},
    {id:'last',label:'마지막',color:adaptive(token)},
  ];
  const icons = token => [
    {id:'inherit-icon'},
    {id:'different-icon',color:adaptive('red500')},
    {id:'last-icon',color:adaptive(token)},
  ];
  const update = async patch => {
    window.tdsReference.updateFooter(patch);
    await sleep(150);
  };
  const sample = phase => {
    const footer = document.querySelector('[data-case="footer"]');
    const content = footer.querySelector('.tds-mobile-list-footer__content');
    const colors = [...footer.querySelectorAll('.tds-mobile-list-footer__text,.tds-mobile-list-footer__icon')]
      .map(node => ({id:node.dataset.case ?? node.querySelector('[data-case]')?.dataset.case,
        color:getComputedStyle(node.querySelector('[data-case]') ?? node).color,
        inline:node.style.color, icon:node.style.getPropertyValue('--icon-color')}));
    const result = {phase,colors,scale:new DOMMatrixReadOnly(getComputedStyle(content).transform).a,
      shadow:+getComputedStyle(footer.querySelector('.tds-mobile-list-footer__shadow')).opacity};
    traces.push(result);
    return result;
  };
  const down = () => document.querySelector('[data-case="footer"]').dispatchEvent(
    new MouseEvent('mousedown',{bubbles:true,button:0,buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,button:0}));
  for (const target of ['text','icon','both']) {
    const textToken = target === 'icon' ? 'green500' : 'disabledBlue500';
    const iconToken = target === 'text' ? 'green500' : 'disabledBlue500';
    await update({generation:target,textColor:undefined,iconColor:undefined,
      children:children(textToken),icons:icons(iconToken)});
    sample(`${target}-initial`);
    down(); await sleep(500); sample(`${target}-pressed`);
    up(); await sleep(500); sample(`${target}-released`);
    down(); await sleep(500); sample(`${target}-repressed`);
    await update({children:children('blue500'),icons:icons('green500')});
    sample(`${target}-changed-held`);
    up(); await sleep(500); sample(`${target}-changed-release`);
    await update({children:children(textToken),icons:icons(iconToken)});
    sample(`${target}-restored`);
    down(); await sleep(500); sample(`${target}-restored-press`);
    up(); await sleep(500); sample(`${target}-restored-release`);
  }
  const at = phase => traces.find(row => row.phase === phase);
  const color = (row,id) => row.colors.find(value => value.id === id).color;
  const check = (value,message) => { if (!value) throw new Error(message); };
  for (const target of ['text','icon','both']) {
    const initial = at(`${target}-initial`), pressed = at(`${target}-pressed`);
    const release = at(`${target}-released`), repressed = at(`${target}-repressed`);
    check(pressed.scale === .96 && pressed.shadow === 1, `${target}: missing color broke shape motion`);
    if (target !== 'icon') {
      check(color(pressed,'different') === color(initial,'different'), 'From-only text did not return to its own CSS');
      check(color(release,'different') === color(initial,'inherit'), 'Release did not use registered normal text');
      check(color(repressed,'different') === color(release,'different'), 'Repeated from-only text used stale CSS');
    }
    if (target !== 'text') {
      check(color(pressed,'different-icon') === 'rgba(0, 0, 0, 0)', 'Unset icon variable is not transparent');
      check(color(release,'different-icon') === color(initial,'inherit-icon'), 'Icon release did not use registered color');
      check(color(repressed,'different-icon') === color(release,'different-icon'), 'Repeated icon destination was not reread');
      check(color(at(`${target}-restored-press`),'different-icon') === 'rgba(0, 0, 0, 0)', 'Icon cleanup retained the custom property');
    }
    check(color(at(`${target}-changed-held`),'different') === color(pressed,'different'), 'Release save did not restore the first pressed text');
    check(at(`${target}-restored-release`).scale === 1, 'Restored from-only release did not finish');
  }
  return traces;
})();
