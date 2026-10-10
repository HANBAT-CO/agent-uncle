// Run on ?family=list-footer-colors. Original child effects register raw colors.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [];
  const update = async patch => { window.tdsReference.updateFooter(patch); await frame(); await sleep(120); };
  const sample = phase => traces.push({phase,
    scale:getComputedStyle(document.querySelector('.tds-mobile-list-footer__content')).transform,
    shadow:+getComputedStyle(document.querySelector('.tds-mobile-list-footer__shadow')).opacity,
    colors:[...document.querySelectorAll(
    '.tds-mobile-list-footer__text,.tds-mobile-list-footer__icon')].map(node => ({
      id:node.dataset.case ?? node.querySelector('[data-case]')?.dataset.case,
      color:getComputedStyle(node.querySelector('[data-case]') ?? node).color,
      iconColor:getComputedStyle(node).getPropertyValue('--icon-color').trim(),
      inlineColor:node.style.color,
    }))});
  const down = () => document.querySelector('[data-case="footer"]').dispatchEvent(
    new MouseEvent('mousedown', {bubbles:true, button:0, buttons:1}));
  const up = () => window.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
  for (const theme of ['light', 'dark']) {
    for (const order of ['explicit-last', 'explicit-first']) {
      const inherited = {id:'inherit', label:'상속', wrap:true};
      const explicit = {id:'custom', label:'명시', color:'#f04452', wrap:true};
      const children = order === 'explicit-last' ? [inherited, explicit] : [explicit, inherited];
      await update({generation:`${theme}-${order}`, theme, children,
        textColor:undefined, iconColor:undefined, icons:[{id:'inherit-icon'}, {id:'custom-icon', color:'#3182f6'}]});
      sample(`${theme}-${order}-rest`);
      down(); await sleep(650); sample(`${theme}-${order}-pressed`);
      up(); await sleep(650); sample(`${theme}-${order}-released`);
      await update({children:[inherited]}); sample(`${theme}-${order}-removed`);
    }
  }
  await update({generation:'updates', theme:'light', textColor:'#3182f6', children:[{id:'inherit', label:'상속'}], icons:[{id:'inherit-icon'}]});
  await update({textColor:'#f04452', iconColor:'#f04452'}); sample('changed-parent-props');
  await update({children:[{id:'inherit', label:'상속'}, {id:'custom', label:'명시', color:'var(--adaptiveRed500)'}]});
  sample('adaptive-child-light'); down(); await sleep(650); sample('adaptive-child-light-pressed'); up(); await sleep(650); sample('adaptive-child-light-released');
  await update({theme:'dark'}); sample('adaptive-child-dark'); down(); await sleep(650); sample('adaptive-child-dark-pressed'); up(); await sleep(650); sample('adaptive-child-dark-released');
  await update({children:[{id:'inherit', label:'상속'}, {id:'custom', label:'명시', color:'#123456'}]});
  sample('custom-raw-color'); down(); await sleep(650); sample('custom-raw-color-pressed'); up(); await sleep(650); sample('custom-raw-color-released');
  await update({children:[{id:'inherit',label:'상속'}, {id:'custom',label:'명시',color:'var(--adaptiveGreen500)'}]});
  sample('change-after-release');
  down(); await sleep(650);
  await update({children:[{id:'inherit',label:'상속'}, {id:'custom',label:'명시',color:'var(--adaptiveRed500)'}]});
  sample('change-during-press');
  up(); await sleep(650); sample('changed-press-released');
  await update({generation:'late-child',theme:'light',textColor:undefined,iconColor:undefined,children:[{id:'custom',label:'명시',color:'#f04452'}]});
  down(); await sleep(650); up(); await sleep(650);
  await update({children:[{id:'custom',label:'명시',color:'#f04452'},{id:'late',label:'새로',color:'#123456'}]});
  sample('insert-after-release');
  await update({generation:'first-held-update', theme:'light', children:[{id:'inherit',label:'상속'}, {id:'custom',label:'명시',color:'#f04452'}]});
  down(); await sleep(650);
  await update({children:[{id:'inherit',label:'상속'}, {id:'custom',label:'명시',color:'#02c26a'}]});
  sample('first-press-update'); up(); await sleep(650); sample('first-press-update-released');
  await update({generation:'late-unchanged-color',theme:'light',children:[{id:'custom',label:'명시',color:'#f04452'}]});
  down(); await sleep(650); up(); await sleep(650);
  await update({children:[{id:'custom',label:'명시',color:'#f04452'}, {id:'late',label:'추가'}]});
  down(); await sleep(650); sample('late-unchanged-color-pressed'); up(); await sleep(650);
  await update({generation:'icon-revert',theme:'light',children:[{id:'custom',label:'명시',color:'#f04452'}],
    icons:[{id:'inherit-icon'},{id:'custom-icon',color:'#03b26c'}]});
  down(); await sleep(650); sample('icon-revert-pressed'); up(); await sleep(650);
  await update({children:[{id:'custom',label:'명시',color:'#3182f6'}]});
  sample('icon-revert-after-color-change');
  await update({generation:'cancel',theme:'light',children:[{id:'custom',label:'명시',color:'#f04452'}]});
  const target = document.querySelector('[data-case="footer"]');
  const touch = new Touch({identifier:1,target,clientX:100,clientY:40});
  target.dispatchEvent(new TouchEvent('touchstart',{bubbles:true,touches:[touch],changedTouches:[touch]}));
  await sleep(650);
  target.dispatchEvent(new TouchEvent('touchcancel',{bubbles:true,touches:[],changedTouches:[touch]}));
  await sleep(650); sample('touch-cancel-retained');

  const at = phase => traces.find(row => row.phase === phase);
  const ink = (phase,id) => at(phase).colors.find(color => color.id === id)?.color;
  const assertInk = (phase,id,expected) => {
    if (ink(phase,id) !== expected) throw new Error(`${phase}/${id}: ${ink(phase,id)} !== ${expected}`);
  };
  for (const theme of ['light','dark']) {
    const blue = theme === 'light' ? 'rgb(49, 130, 246)' : 'rgb(52, 133, 250)';
    const bluePressed = theme === 'light' ? 'rgb(34, 114, 235)' : 'rgb(68, 155, 255)';
    for (const order of ['explicit-last','explicit-first']) {
      const base = `${theme}-${order}`;
      assertInk(`${base}-rest`,'custom','rgb(240, 68, 82)');
      assertInk(`${base}-rest`,'inherit',order === 'explicit-last' ? 'rgb(240, 68, 82)' : blue);
      for (const id of ['custom','inherit']) {
        assertInk(`${base}-pressed`,id,order === 'explicit-last' ? 'rgb(228, 41, 57)' : bluePressed);
        assertInk(`${base}-released`,id,order === 'explicit-last' ? 'rgb(240, 68, 82)' : blue);
      }
      assertInk(`${base}-pressed`,'inherit-icon','rgb(34, 114, 235)');
    }
  }
  assertInk('changed-parent-props','inherit','rgb(49, 130, 246)');
  assertInk('adaptive-child-dark','inherit','rgb(240, 66, 81)');
  assertInk('adaptive-child-dark-pressed','inherit','rgb(250, 97, 109)');
  assertInk('custom-raw-color','inherit','rgb(250, 97, 109)');
  assertInk('custom-raw-color-pressed','inherit','rgb(18, 52, 86)');
  assertInk('late-unchanged-color-pressed','custom','rgb(228, 41, 57)');
  assertInk('late-unchanged-color-pressed','late','rgb(240, 68, 82)');
  assertInk('icon-revert-pressed','inherit-icon','rgb(2, 162, 98)');
  assertInk('icon-revert-after-color-change','custom','rgb(228, 41, 57)');
  for (const id of ['inherit-icon','custom-icon']) {
    assertInk('icon-revert-after-color-change',id,'rgb(3, 178, 108)');
    if (at('icon-revert-after-color-change').colors.find(color => color.id === id).iconColor !== '') {
      throw new Error('Reverting a source CSS-variable tween retained its inline color');
    }
  }
  if (at('custom-raw-color').shadow !== 1 || at('first-press-update').shadow !== 0 || at('touch-cancel-retained').shadow !== 1) throw new Error('Context cleanup or touch cancellation changed');
  return traces;
})();
