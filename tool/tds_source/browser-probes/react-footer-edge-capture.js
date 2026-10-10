// Original 2.5.1 endpoint captures, without package/CSS changes.
return (async () => {
  await window.tdsReference.ready;
  const phase = new URLSearchParams(location.search).get('edgeCase');
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const adaptive = name => `var(--adaptive${name[0].toUpperCase()}${name.slice(1)})`;
  const nested = !['from-only','repress'].includes(phase);
  const update = async patch => {
    (nested ? window.tdsReference.updateNestedFooter : window.tdsReference.updateFooter)(patch);
    await sleep(180);
  };
  let where = nested ? 'outer-footer' : 'footer';
  const down = () => document.querySelector(`[data-case="${where}"]`).dispatchEvent(
    new MouseEvent('mousedown',{bubbles:true,button:0,buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,button:0}));
  if (!nested) await update({generation:phase,children:[
    {id:'inherit',label:'상속'}, {id:'different',label:'명시',color:adaptive('red500')},
    {id:'last',label:'마지막',color:adaptive('disabledBlue500')},
  ],icons:[{id:'inherit-icon'}, {id:'different-icon',color:adaptive('red500')},
    {id:'last-icon',color:adaptive('disabledBlue500')}]});
  if (phase === 'late' || phase === 'recaptured') {
    await update({showInner:false}); await update({showInner:true,innerGeneration:1});
    if (phase === 'recaptured') await update({outer:'teal500'});
  }
  if (phase === 'bubbled') where = 'inner-footer';
  down(); await sleep(450);
  if (phase === 'repress') { up(); await sleep(450); down(); await sleep(450); }
  if (phase === 'bubbled') {
    up(); await sleep(450);
    document.querySelector('[data-case="inner-footer"]').click();
    if (window.tdsReference.events.join(',') !== 'inner-click,outer-click') throw new Error('Nested click order changed');
  }
  const result = {phase,colors:[...document.querySelectorAll('.tds-mobile-list-footer__text,.tds-mobile-list-footer__icon')]
    .map(node => ({id:node.dataset.case ?? node.querySelector('[data-case]')?.dataset.case,
      color:getComputedStyle(node.querySelector('[data-case]') ?? node).color})),
    scales:[...document.querySelectorAll('.tds-mobile-list-footer__content')]
      .map(node => new DOMMatrixReadOnly(getComputedStyle(node).transform).a)};
  const color = id => result.colors.find(row => row.id === id).color;
  const check = (value,message) => { if (!value) throw new Error(`${phase}: ${message}`); };
  check(result.scales[0] === (phase === 'bubbled' ? 1 : .96), 'outer shape changed');
  if (phase === 'from-only') {
    check(color('different-icon') === 'rgba(0, 0, 0, 0)', 'unset icon did not disappear');
    check(color('inherit') !== color('different'), 'own CSS destination was lost');
  }
  if (phase === 'repress') check(result.colors.every(row => row.color === color('inherit')), 'current inline destination was not reused');
  if (nested) {
    check(result.scales[1] === (phase === 'bubbled' || phase === 'late' ? 1 : .96), 'inner shape changed');
    check((color('outer-text') === color('inner-text')) === (phase !== 'late'), 'nested selector capture changed');
  }
  return result;
})();
