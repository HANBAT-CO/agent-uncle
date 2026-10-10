// Run against the original, unmodified TDS 2.5.1 package.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const traces = [];
  const update = async patch => {
    window.tdsReference.updateNestedFooter(patch);
    await sleep(180);
  };
  const sample = phase => {
    const result = {phase,events:[...window.tdsReference.events],
      footers:[...document.querySelectorAll('[data-case$="-footer"]')].map(footer => ({
        id:footer.dataset.case,
        scale:new DOMMatrixReadOnly(getComputedStyle(footer.querySelector('.tds-mobile-list-footer__content')).transform).a,
        shadow:+getComputedStyle(footer.querySelector(':scope > .tds-mobile-list-footer__content > .tds-mobile-list-footer__shadow')).opacity,
      })),
      colors:[...document.querySelectorAll('.tds-mobile-list-footer__text,.tds-mobile-list-footer__icon')].map(node => ({
        id:node.dataset.case ?? node.querySelector('[data-case]')?.dataset.case,
        color:getComputedStyle(node.querySelector('[data-case]') ?? node).color,
        inline:node.style.color,icon:node.style.getPropertyValue('--icon-color'),
      }))};
    traces.push(result);
    return result;
  };
  const down = (where='outer') => document.querySelector(`[data-case="${where}-footer"]`).dispatchEvent(
    new MouseEvent('mousedown',{bubbles:true,button:0,buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,button:0}));
  const reset = async generation => {
    up(); window.tdsReference.events.length = 0;
    await update({generation,outer:'blue500',inner:'red500',outerIcon:'green500',innerIcon:'orange500',showInner:true});
  };
  await reset('outer-only'); sample('initial');
  down(); await sleep(450); sample('outer-press');
  up(); await sleep(450); sample('outer-release');
  await update({inner:'purple500'}); sample('inner-update-after-outer');
  down(); await sleep(450); sample('outer-press-after-inner-update');
  await update({outer:'teal500'}); sample('outer-update-held');
  up(); await sleep(450); sample('outer-release-new');

  await reset('inner-bubble');
  down('inner'); await sleep(450); sample('inner-bubbled-press');
  up(); await sleep(450); sample('inner-bubbled-release');
  document.querySelector('[data-case="inner-footer"]').click(); sample('inner-click');
  await update({inner:'purple500'}); sample('inner-update-after-bubble');
  await update({outer:'teal500'}); sample('outer-update-after-bubble');
  await sleep(500); sample('outer-update-after-bubble-settled');

  await reset('late-inner');
  await update({showInner:false}); sample('removed');
  await update({showInner:true,innerGeneration:1}); sample('reinserted');
  down(); await sleep(450); sample('outer-press-late-inner');
  up(); await sleep(450); sample('outer-release-late-inner');
  await update({outer:'teal500'});
  down(); await sleep(450); sample('outer-recaptured-press');
  up(); await sleep(450); sample('outer-recaptured-release');
  const at = phase => traces.find(row => row.phase === phase);
  const color = (row,id) => row.colors.find(value => value.id === id).color;
  const shape = (row,id) => row.footers.find(value => value.id === `${id}-footer`);
  const check = (value,message) => { if (!value) throw new Error(message); };
  for (const phase of ['outer-press','outer-press-after-inner-update','inner-bubbled-press','outer-recaptured-press']) {
    const row = at(phase);
    check(row.footers.every(item => item.scale === .96 && item.shadow === 1), `${phase}: descendant shape not targeted`);
    check(color(row,'outer-text') === color(row,'inner-text'), `${phase}: nested provider blocked text selector`);
    check(color(row,'outer-icon') === color(row,'inner-icon'), `${phase}: nested provider blocked icon selector`);
  }
  for (const phase of ['outer-release','inner-bubbled-release','outer-release-new','outer-recaptured-release']) {
    const row = at(phase);
    check(row.footers.every(item => item.scale === 1 && item.shadow === 0), `${phase}: descendant release did not finish`);
    check(color(row,'outer-text') === color(row,'inner-text'), `${phase}: nested text release differs`);
  }
  check(color(at('inner-update-after-outer'),'inner-text') === color(at('outer-release'),'inner-text'), 'Unused child contexts erased ancestor inline text');
  check(color(at('outer-update-held'),'inner-text') === color(at('outer-press'),'inner-text'), 'Parent release lost its nested text save');
  check(color(at('outer-update-held'),'inner-icon') === color(at('initial'),'inner-icon'), 'Nested icon cleanup retained custom property');
  check(at('inner-click').events.join(',') === 'inner-click,outer-click', 'Nested click propagation changed');
  check(shape(at('inner-update-after-bubble'),'outer').scale === 1, 'Inner cleanup changed outer shape');
  check(shape(at('inner-update-after-bubble'),'inner').scale === .96, 'Inner release lost its own save');
  for (const phase of ['outer-press-late-inner','outer-release-late-inner']) {
    const row = at(phase);
    check(shape(row,'inner').scale === 1 && shape(row,'inner').shadow === 0, 'Reinserted shape joined old selectors');
    check(color(row,'inner-text') === color(at('initial'),'inner-text'), 'Reinserted text joined old selectors');
  }
  return traces;
})();
