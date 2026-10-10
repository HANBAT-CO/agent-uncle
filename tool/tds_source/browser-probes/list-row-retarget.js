// Run on ?family=list-effects. Compare memoized targets vs repeated requests.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const rows = [];
  let start = performance.now();
  const sample = phase => {
    const row = document.querySelector('.tds-mobile-list-row');
    const effect = [...row.children].find(child => getComputedStyle(child).backgroundImage.startsWith('linear-gradient'));
    rows.push({phase, ms: Math.round(performance.now() - start), width:row.clientWidth, height:row.clientHeight,
      present:!!effect, x:effect ? new DOMMatrixReadOnly(getComputedStyle(effect).transform).m41 : null});
  };
  for (const mode of ['same-count', 'height-only', 'new-target']) {
    window.tdsReference.updateRow({theme:'light',width:320.4,height:40.4});
    await frame();
    start = performance.now();
    window.tdsReference.rowEffect('shine', 1);
    await sleep(550);
    sample(`${mode}-before`);
    window.tdsReference.updateRow({width:mode === 'height-only' ? 320.4 : 200.6,height:70.2});
    await frame();
    sample(`${mode}-resized`);
    window.tdsReference.rowEffect('shine', mode === 'same-count' ? 1 : 2);
    await frame();
    sample(`${mode}-requested`);
    await sleep(400);
    sample(`${mode}-after-400`);
    await sleep(Math.max(0, 2300 - (performance.now() - start)));
    sample(`${mode}-2300`);
    if (mode === 'new-target') {
      await sleep(700);
      sample(`${mode}-second-cycle`);
      await sleep(2300);
      sample(`${mode}-complete`);
    }
  }
  return rows;
})();
