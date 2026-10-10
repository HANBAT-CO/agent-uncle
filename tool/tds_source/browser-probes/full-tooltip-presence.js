// Run with `browse eval` on ?family=full-tooltip&side=bottom, with or without
// &floating=true. The top-level return is required by the browser eval wrapper.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const rows = [];
  const identities = new WeakMap();
  let nextId = 0;
  const sample = (phase, start) => {
    const ink = document.querySelector('.tds-mobile-paragraph');
    if (ink && !identities.has(ink)) identities.set(ink, ++nextId);
    rows.push({phase, ms: Math.round(performance.now()-start), present: !!ink,
      identity: ink ? identities.get(ink) : null,
      opacity: ink ? getComputedStyle(ink).opacity : null,
      host: document.querySelector('[data-case="full-tooltip-host"]').getBoundingClientRect().height});
  };
  const change = async (phase, patch, times) => {
    const start = performance.now();
    window.tdsReference.updateFullTooltip(patch);
    for (const time of times) {
      await sleep(Math.max(0, time-(performance.now()-start)));
      sample(phase, start);
    }
  };
  await sleep(1600);
  sample('initial',performance.now());
  await change('close1', {open:false}, [10,80]);
  await change('reopen-interrupted', {open:true}, [10,300,1500]);
  await change('close2', {open:false}, [10,60,200,900]);
  await change('reopen-clean', {open:true}, [10,1500]);
  await change('close3', {open:false}, [10,60,200,900]);
  return rows;
})();
