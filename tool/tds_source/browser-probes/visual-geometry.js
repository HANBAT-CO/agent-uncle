// Run against either visual-typography or visual-footer. Measure the original
// without inserting baseline markers or changing its package/CSS/DOM layout.
return (async () => {
  const parameters = new URLSearchParams(location.search);
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  if (window.tdsReference) {
    await window.tdsReference.ready;
    await document.fonts.ready;
    const footer = document.querySelector('[data-case="visual-footer"]');
    if (parameters.get('state') === 'pressed') {
      footer.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, button:0, buttons:1}));
      await sleep(450);
    }
    const properties = ['fontFamily','fontSize','fontWeight','lineHeight',
      'display','verticalAlign','wordBreak','overflowWrap','whiteSpace',
      'width','height','transform','backgroundImage','opacity'];
    const nodes = document.querySelectorAll('[data-case^="type-"] > *, '
      + '.tds-mobile-list-footer__text, .tds-mobile-list-footer__icon, '
      + '.tds-mobile-list-footer__shadow, .tds-mobile-list-footer__content');
    const samples = [...nodes].map(node => {
      const css = getComputedStyle(node);
      const canvas = document.createElement('canvas').getContext('2d');
      canvas.font = `${css.fontWeight} ${css.fontSize} ${css.fontFamily}`;
      const metrics = canvas.measureText(node.textContent);
      const textNode = [...node.childNodes].find(child => child.nodeType === Node.TEXT_NODE);
      const range = document.createRange();
      if (textNode) range.selectNodeContents(textNode);
      return {id:node.parentElement.dataset.case ?? node.className,
        rect:node.getBoundingClientRect().toJSON(),
        css:Object.fromEntries(properties.map(key => [key,css[key]])),
        lines:textNode ? [...range.getClientRects()].map(rect => ({...rect.toJSON(),
          baseline:rect.y + metrics.fontBoundingBoxAscent})) : [],
        metrics:{width:metrics.width,ascent:metrics.fontBoundingBoxAscent,
          descent:metrics.fontBoundingBoxDescent}};
    });
    if (!samples.length) throw new Error('Missing original visual specimens');
    return {engine:'react', samples};
  }
  const host = () => document.querySelector('flt-semantics-host');
  const isFooter = parameters.get('family') === 'visual-footer';
  for (let i = 0; i < 100; i++) {
    document.querySelector('flt-semantics-placeholder')?.click();
    if (isFooter ? host()?.querySelector('[role="button"]') : host()?.textContent.includes('토스')) break;
    await sleep(100);
  }
  if (!(isFooter ? host()?.querySelector('[role="button"]') : host()?.textContent.includes('토스'))) {
    throw new Error('Flutter visual specimens did not settle');
  }
  await sleep(300);
  if (parameters.get('state') === 'pressed') {
    const rect = host().querySelector('[role="button"]').getBoundingClientRect();
    const surface = document.querySelector('flt-glass-pane');
    for (const type of ['pointermove','pointerdown']) {
      surface.dispatchEvent(new PointerEvent(type, {bubbles:true,cancelable:true,
        pointerId:901,pointerType:'mouse',isPrimary:true,button:type === 'pointermove' ? -1 : 0,
        buttons:type === 'pointermove' ? 0 : 1,clientX:rect.x+rect.width/2,clientY:rect.y+rect.height/2}));
    }
    await sleep(450);
  }
  return {engine:'flutter', semantics:host().textContent};
})();
