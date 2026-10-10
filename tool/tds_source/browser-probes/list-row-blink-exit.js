// Inspect independent exit channels and a blink that reenters a retained layer.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const traces = [], ids = new WeakMap();
  let nextId = 0, start;
  const sample = phase => {
    const row = document.querySelector('.tds-mobile-list-row');
    const gradient = [...row.children].find(node => getComputedStyle(node).backgroundImage.startsWith('radial-gradient'));
    if (gradient && !ids.has(gradient)) ids.set(gradient, ++nextId);
    const dimmer = gradient?.nextElementSibling;
    const css = gradient && getComputedStyle(gradient);
    traces.push({phase, ms: Math.round(performance.now() - start),
      id: gradient ? ids.get(gradient) : null,
      radius: css ? new DOMMatrixReadOnly(css.transform).m11 : null,
      gradientOpacity: css ? +css.opacity : null,
      dimmerOpacity: dimmer ? +getComputedStyle(dimmer).opacity : null});
  };
  for (const duration of [.1, .6]) {
    window.tdsReference.updateRow({generation: `blink-exit-${duration}`, theme: 'light', width: 320.4, height: 40.4});
    await frame();
    start = performance.now();
    window.tdsReference.rowEffect('blink', duration);
    await sleep(duration * 1000 + 200);
    sample(`${duration}-exiting`);
    await sleep(350);
    sample(`${duration}-late-exit`);
    window.tdsReference.rowEffect('blink', 1.5);
    await frame();
    sample(`${duration}-reentered`);
    await sleep(50);
    sample(`${duration}-reentered-50`);
    await sleep(150);
    sample(`${duration}-reentered-200`);
    await sleep(400);
    sample(`${duration}-reentered-600`);
    await sleep(3000);
    sample(`${duration}-complete`);
  }
  for (const duration of [.1, .6]) {
    const late = traces.find(row => row.phase === `${duration}-late-exit`);
    const resumed = traces.find(row => row.phase === `${duration}-reentered`);
    const complete = traces.find(row => row.phase === `${duration}-complete`);
    if (late.id !== resumed.id || resumed.radius < late.radius || resumed.gradientOpacity >= .75) {
      throw new Error(`Blink reentry did not retain its layer/channels: ${duration}`);
    }
    if (duration === .1 && (late.dimmerOpacity !== 0 || resumed.dimmerOpacity !== 0)) {
      throw new Error('An interrupted delayed dimmer became visible');
    }
    if (complete.id !== null) throw new Error(`Blink did not finish its exit: ${duration}`);
  }
  return traces;
})();
