// Run on ?family=list-effects. Keep the pinned package untouched.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const trace = [];
  const ids = new WeakMap();
  let nextId = 0, start;
  const id = node => {
    if (!node) return null;
    if (!ids.has(node)) ids.set(node, ++nextId);
    return ids.get(node);
  };
  const sample = phase => {
    const row = document.querySelector('.tds-mobile-list-row');
    const children = [...row.children];
    const gradient = children.find(node => getComputedStyle(node).backgroundImage.startsWith('radial-gradient'));
    const dimmer = children.find(node => getComputedStyle(node).backgroundColor === getComputedStyle(row).getPropertyValue('--blue500').trim());
    const solid = dimmer ?? children.find(node => {
      const css = getComputedStyle(node);
      return css.position === 'absolute' && css.backgroundImage === 'none' && css.backgroundColor !== 'rgba(0, 0, 0, 0)';
    });
    const layer = node => {
      if (!node) return null;
      const css = getComputedStyle(node);
      return {id: id(node), width: css.width, height: css.height,
        x: node.getBoundingClientRect().x, y: node.getBoundingClientRect().y,
        opacity: +css.opacity, transform: css.transform,
        background: css.backgroundImage, color: css.backgroundColor};
    };
    trace.push({phase, ms: Math.round(performance.now() - start),
      row: {width: row.clientWidth, height: row.clientHeight},
      gradient: layer(gradient), dimmer: layer(solid)});
  };
  window.tdsReference.updateRow({generation: 'blink-live', theme: 'light', width: 320.4, height: 40.4});
  await frame();
  start = performance.now();
  window.tdsReference.rowEffect('blink', 1.5);
  await sleep(650);
  sample('light-before');
  window.tdsReference.updateRow({theme: 'dark', width: 200.6, height: 70.2});
  await frame();
  sample('dark-resized');
  await sleep(Math.max(0, 1700 - (performance.now() - start)));
  sample('exiting');
  window.tdsReference.updateRow({theme: 'light', width: 300.2, height: 100.4});
  await frame();
  sample('exiting-resized');
  await sleep(1800);
  sample('removed');
  const [before, resized, exiting, exitResized, removed] = trace;
  if (before.gradient.id !== resized.gradient.id || before.gradient.id !== exitResized.gradient.id) {
    throw new Error('Blink remounted on a live layout/theme change');
  }
  if (!before.gradient.background.includes('rgba(49, 130, 246, 0.1)') ||
      resized.gradient.background !== before.gradient.background ||
      resized.dimmer.color !== 'rgb(52, 133, 250)' || exitResized.dimmer.color !== 'rgb(49, 130, 246)') {
    throw new Error('Blink fixed/adaptive color contracts changed');
  }
  if (resized.row.width !== 201 || exitResized.row.width !== 300 ||
      !(exiting.gradient.opacity > 0 && exiting.gradient.opacity < 1) ||
      removed.gradient !== null || removed.dimmer !== null) {
    throw new Error('Blink responsive geometry or retained exit changed');
  }
  return trace;
})();
