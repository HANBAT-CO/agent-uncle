// Run with `browse eval` on ?family=list-effects. No package internals patched.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const identities = new WeakMap();
  let nextId = 0;
  const rows = [];
  const sample = phase => {
    const row = document.querySelector('.tds-mobile-list-row');
    const effect = [...row.children].find(child => getComputedStyle(child).backgroundImage.startsWith('linear-gradient'));
    if (effect && !identities.has(effect)) identities.set(effect, ++nextId);
    const style = effect ? getComputedStyle(effect) : null;
    const matrix = style ? new DOMMatrixReadOnly(style.transform) : null;
    rows.push({phase, ms: Math.round(performance.now() - start), row: {width:row.clientWidth, height:row.clientHeight},
      identity: effect ? identities.get(effect) : null, x:matrix?.m41, y:matrix?.m42,
      width:style?.width, height:style?.height, opacity:style?.opacity, gradient:style?.backgroundImage});
  };
  const change = async patch => { window.tdsReference.updateRow(patch); await frame(); };
  await change({theme:'light',width:320.4,height:40.4});
  let start = performance.now();
  window.tdsReference.rowEffect('shine', 1);
  await sleep(550);
  sample('light-before-resize');
  await change({width:200.6,height:70.2});
  sample('light-after-resize');
  await sleep(Math.max(0, 2250 - (performance.now() - start)));
  sample('light-completed-original-count');
  start = performance.now();
  window.tdsReference.rowEffect('shine', 1);
  await sleep(300);
  sample('light-fresh-geometry');
  window.tdsReference.rowEffect('shine', 2);
  await frame();
  await change({theme:'dark'});
  sample('dark-remounted');
  await sleep(400);
  sample('dark-before-resize');
  await change({width:300.2,height:90.4});
  sample('dark-after-resize');
  await sleep(2000);
  sample('dark-before-first-cycle-end');
  await sleep(300);
  sample('dark-repeats-latest-count');
  await change({theme:'light',width:240.6,height:50.2});
  sample('light-remounted');
  await sleep(500);
  sample('light-after-remount');
  await sleep(4000);
  sample('light-completed-latest-count');
  return rows;
})();
