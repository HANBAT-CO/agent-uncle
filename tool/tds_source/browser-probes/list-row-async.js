// Run on ?family=list-effects&async=true. Promise continuations are intentionally distinct
// from DOM discrete-event commits and from a later rendered frame.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [];
  let generation = 0;
  const mount = async (patch = {}) => {
    window.tdsReference.updateRow({generation:++generation,width:320,height:40,
      childDown:[],rowDown:[],ancestorDown:[],childUp:[],rowUp:[],ancestorUp:[],
      click:[],clickable:true,withTouchEffect:undefined,disabled:false,...patch});
    await frame();
  };
  const effect = (name, value) => window.tdsReference.rowEffect(name, value);
  const send = (kind, phase) => {
    const target = document.querySelector('[data-case="list-effect-content"]');
    if (kind === 'touch') {
      const touch = new Touch({identifier:1,target,clientX:80,clientY:40});
      target.dispatchEvent(new TouchEvent(`touch${phase}`, {bubbles:true,cancelable:true,
        touches:phase === 'start' ? [touch] : [],changedTouches:[touch]}));
    } else {
      target.dispatchEvent(new MouseEvent(`mouse${phase === 'start' ? 'down' : 'up'}`,
        {bubbles:true,cancelable:true,clientX:80,clientY:40,button:0,buttons:phase === 'start' ? 1 : 0}));
    }
  };
  const sample = phase => {
    const row = document.querySelector('.tds-mobile-list-row');
    const children = [...row.children];
    const blink = children.find(node => getComputedStyle(node).backgroundImage.startsWith('radial-gradient'));
    const shine = children.find(node => getComputedStyle(node).backgroundImage.startsWith('linear-gradient'));
    const content = children.find(node => getComputedStyle(node).display === 'flex');
    traces.push({phase,blink:!!blink,shine:!!shine,
      blinkOpacity:blink ? +getComputedStyle(blink).opacity : null,
      touchOpacity:+getComputedStyle(content.firstElementChild).opacity,
      scale:new DOMMatrixReadOnly(getComputedStyle(content).transform).a});
  };
  for (const microtasks of [1, 5]) {
    await mount();
    effect('shine', 1);
    for (let i=0;i<microtasks;i++) await Promise.resolve();
    effect('blink', .3);
    await frame(); sample(`external-shine-${microtasks}-microtasks-blink`);
    await sleep(1050); sample(`external-${microtasks}-deadline`);
  }
  await mount();
  effect('shine', 1);
  await frame();
  effect('blink', .3);
  await frame(); sample('external-shine-frame-blink');
  await mount();
  effect('blink', .3);
  await Promise.resolve();
  effect('shine', 1);
  await frame(); sample('external-blink-microtask-shine');
  await sleep(400); sample('overwritten-blink-deadline');
  for (const kind of ['touch','mouse']) {
    await mount();
    send(kind,'start');
    await Promise.resolve();
    effect('blink', .3);
    await frame(); await sleep(120); sample(`${kind}-down-microtask-blink`);
    send(kind,'end');
    await Promise.resolve();
    effect('blink', .3);
    await frame(); sample(`${kind}-up-microtask-blink`);
    await mount();
    send(kind,'start');
    await Promise.resolve();
    effect('shine', 1);
    await frame(); sample(`${kind}-down-microtask-shine`);
    send(kind,'end'); await frame();
  }
  for (const asyncBlinkFirst of [false,true]) {
    await mount({asyncBlinkFirst});
    document.querySelector('[data-case="async-event-trigger"]').click();
    await frame(); sample(`button-microtask-blink-first-${asyncBlinkFirst}`);
  }
  const at = phase => traces.find(row => row.phase === phase);
  const check = (phase, blink, shine) => {
    const row = at(phase);
    if (row.blink !== blink || row.shine !== shine) throw new Error(`Async batch changed: ${JSON.stringify(row)}`);
  };
  for (const microtasks of [1,5]) check(`external-shine-${microtasks}-microtasks-blink`,true,false);
  check('external-shine-frame-blink',false,true);
  check('external-blink-microtask-shine',false,true);
  check('overwritten-blink-deadline',false,false);
  for (const kind of ['touch','mouse']) {
    check(`${kind}-down-microtask-blink`,false,false);
    if (at(`${kind}-down-microtask-blink`).touchOpacity < .5) throw new Error('Discrete input did not retain touch state');
    check(`${kind}-up-microtask-blink`,true,false);
    check(`${kind}-down-microtask-shine`,false,true);
  }
  for (const blinkFirst of [false,true]) check(`button-microtask-blink-first-${blinkFirst}`,blinkFirst,true);
  return traces;
})();
