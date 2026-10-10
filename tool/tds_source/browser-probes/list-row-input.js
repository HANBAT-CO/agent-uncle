// Run on ?family=list-effects. Dispatch real DOM event types used by source ht.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [];
  let generation = 0;
  const mount = async patch => {
    window.tdsReference.updateRow({generation:++generation, width:320, height:40,
      childDown:[], rowDown:[], ancestorDown:[], childUp:[], rowUp:[], ancestorUp:[],
      click:[], clickable:true, withTouchEffect:undefined, disabled:false, ...patch});
    await frame();
  };
  const send = (kind, phase, x = 80) => {
    const target = document.querySelector('[data-case="list-effect-content"]');
    if (kind === 'touch') {
      const touch = new Touch({identifier:1, target, clientX:x, clientY:40});
      target.dispatchEvent(new TouchEvent(`touch${phase}`, {bubbles:true, cancelable:true,
        touches:phase === 'start' ? [touch] : [], changedTouches:[touch]}));
    } else {
      target.dispatchEvent(new MouseEvent(`mouse${phase === 'start' ? 'down' : 'up'}`,
        {bubbles:true, cancelable:true, clientX:x, clientY:40, button:0, buttons:phase === 'start' ? 1 : 0}));
    }
  };
  const sample = (name, kind, phase) => {
    const row = document.querySelector('.tds-mobile-list-row');
    const children = [...row.children];
    const gradient = children.find(node => getComputedStyle(node).backgroundImage.startsWith('radial-gradient'));
    const shine = children.find(node => getComputedStyle(node).backgroundImage.startsWith('linear-gradient'));
    const content = children.find(node => getComputedStyle(node).display === 'flex');
    traces.push({name, kind, phase, blink:!!gradient, shine:!!shine,
      opacity:gradient ? +getComputedStyle(gradient).opacity : null,
      touchOpacity:+getComputedStyle(content.firstElementChild).opacity,
      scale:new DOMMatrixReadOnly(getComputedStyle(content).transform).a});
  };
  for (const kind of ['touch', 'mouse']) {
    for (const location of ['child', 'row', 'ancestor']) {
      for (const effect of ['blink', 'shine']) {
        const name = `${location}-down-${effect}`;
        await mount({[`${location}Down`]:[[effect, effect === 'blink' ? .4 : 1]]});
        send(kind, 'start');
        await frame(); await sleep(120); sample(name, kind, 'down');
        if (effect === 'blink') { await sleep(450); sample(name, kind, 'timeout'); }
        send(kind, 'end');
        await frame(); await sleep(600); sample(name, kind, 'released');
      }
    }
    for (const location of ['child', 'row', 'ancestor']) {
      const name = `${location}-up-shine`;
      await mount({[`${location}Up`]:[['shine', 1]]});
      send(kind, 'start'); await frame();
      send(kind, 'end'); await frame(); await sleep(100); sample(name, kind, 'released');
    }
    await mount({withTouchEffect:false});
    window.tdsReference.rowEffect('shine', 1); await frame();
    send(kind, 'start'); await frame(); sample('suppressed-start', kind, 'down');
    send(kind, 'end'); await frame(); sample('suppressed-start', kind, 'released');

    await mount({ancestorUp:[['blink', .4]]});
    send(kind, 'start'); await frame();
    send(kind, 'end'); await frame(); sample('committed-touch-guard', kind, 'released');

    await mount({click:[['blink', .4]]});
    send(kind, 'start'); await frame();
    send(kind, 'end'); await frame();
    document.querySelector('.tds-mobile-list-row').click();
    await frame(); sample('click-after-release', kind, 'clicked');
  }
  await mount({ancestorDown:[['blink', 1]]});
  send('touch', 'start'); await frame();
  send('touch', 'cancel'); await sleep(750); sample('touch-cancel', 'touch', 'cancelled');
  await mount({});
  send('touch','start'); await frame(); send('touch','end'); await frame();
  window.tdsReference.rowEffect('shine', 1); await frame();
  send('mouse','start'); await frame(); sample('compatibility-mouse', 'mouse', 'suppressed');
  send('mouse','end'); await sleep(350);
  send('mouse','start'); await frame(); await sleep(100); sample('compatibility-mouse', 'mouse', 'accepted');
  send('mouse','end'); await frame();
  await mount({});
  send('mouse','start'); await frame();
  window.tdsReference.updateRow({disabled:true}); await frame();
  window.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,button:0}));
  await sleep(600); sample('disabled-while-held','mouse','released');
  await mount({click:[['shine',1]]});
  const eventStart = window.tdsReference.events.length;
  for (const repeat of [false,true]) document.querySelector('.tds-mobile-list-row').dispatchEvent(
    new KeyboardEvent('keydown',{bubbles:true,cancelable:true,key:' ',code:'Space',repeat}));
  await frame(); sample('keyboard-repeat', 'keyboard', 'down');
  if (window.tdsReference.events.length - eventStart !== 2) throw new Error('Space keydown/repeat lost an activation');

  const at = (name,kind,phase) => traces.find(row => row.name === name && row.kind === kind && row.phase === phase);
  for (const kind of ['touch','mouse']) {
    for (const location of ['child','row','ancestor']) {
      for (const effect of ['blink','shine']) {
        const down = at(`${location}-down-${effect}`,kind,'down');
        if (down.blink !== (location !== 'child' && effect === 'blink') ||
            down.shine !== (location !== 'child' && effect === 'shine')) throw new Error(`Down order changed: ${JSON.stringify(down)}`);
        if (location === 'child' && (down.scale >= .99 || down.touchOpacity <= .5)) throw new Error('Child command did not yield to touch');
      }
      const released = at(`${location}-up-shine`,kind,'released');
      if (released.shine !== (kind === 'touch' && location !== 'child')) throw new Error(`End phase changed: ${JSON.stringify(released)}`);
    }
    if (!at('suppressed-start',kind,'down').shine || at('suppressed-start',kind,'released').shine ||
        at('committed-touch-guard',kind,'released').blink || !at('click-after-release',kind,'clicked').blink) throw new Error('Suppression, blink guard or click commit changed');
  }
  if (!at('compatibility-mouse','mouse','suppressed').shine || at('compatibility-mouse','mouse','accepted').shine ||
      Math.abs(at('disabled-while-held','mouse','released').scale - 1) > .01 ||
      at('keyboard-repeat','keyboard','down').scale !== 1) throw new Error('Compatibility, disabled release or keyboard feedback changed');
  return traces;
})();
