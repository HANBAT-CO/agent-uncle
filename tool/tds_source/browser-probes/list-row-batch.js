// Run on ?family=list-effects. One synchronous callback is one React batch.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [];
  let start;
  const sample = phase => {
    const row = document.querySelector('.tds-mobile-list-row');
    const children = [...row.children];
    const gradient = children.find(node => getComputedStyle(node).backgroundImage.startsWith('radial-gradient'));
    const shine = children.find(node => getComputedStyle(node).backgroundImage.startsWith('linear-gradient'));
    const content = children.find(node => getComputedStyle(node).display === 'flex');
    traces.push({phase, ms: Math.round(performance.now() - start), blink: !!gradient,
      blinkOpacity: gradient ? +getComputedStyle(gradient).opacity : null,
      shine: !!shine, contentTransform: content ? getComputedStyle(content).transform : null});
  };
  for (const [name, commands] of [
    ['shine-blink', [['shine', 1], ['blink', .5]]],
    ['blink-shine', [['blink', .5], ['shine', 1]]],
    ['long-short-blink', [['blink', .5], ['blink', .1]]],
    ['short-long-blink', [['blink', .1], ['blink', .5]]],
    ['shine-count', [['shine', 1], ['shine', 3]]],
  ]) {
    window.tdsReference.updateRow({generation: name, theme: 'light', width: 320.4, height: 40.4});
    await frame();
    start = performance.now();
    commands.forEach(([effect, value]) => window.tdsReference.rowEffect(effect, value));
    await frame();
    sample(`${name}-committed`);
    await sleep(Math.max(0, 200 - (performance.now() - start)));
    sample(`${name}-200`);
    if (name === 'short-long-blink') {
      window.tdsReference.rowEffect('shine', 1);
      await frame();
      sample(`${name}-new-shine`);
    }
    await sleep(Math.max(0, 650 - (performance.now() - start)));
    sample(`${name}-650`);
    if (name === 'shine-count') {
      await sleep(1900);
      sample(`${name}-after-one-cycle`);
      await sleep(4450);
      sample(`${name}-complete`);
    }
  }
  const at = phase => traces.find(row => row.phase === phase);
  if (!at('shine-blink-committed').blink || at('shine-blink-committed').shine ||
      at('blink-shine-committed').blink || !at('blink-shine-committed').shine ||
      at('blink-shine-650').shine || at('short-long-blink-650').shine) {
    throw new Error('The last accepted effect or a retained blink deadline changed');
  }
  if (!(at('long-short-blink-200').blinkOpacity < 1) ||
      !(at('short-long-blink-200').blinkOpacity < 1) ||
      !at('shine-count-after-one-cycle').shine || at('shine-count-complete').shine) {
    throw new Error('A synchronous batch lost a deadline or its final repeat count');
  }
  return traces;
})();
