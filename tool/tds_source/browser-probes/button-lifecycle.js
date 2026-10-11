// Run on ?family=button-lifecycle. Uses the unchanged original TDS package.
// Trusted keyboard behavior must be checked with browser keyboard input:
// Enter down/repeat/up then Space down/up produce click totals 1/2/2/2/3.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const update = async patch => {
    window.tdsReference.updateButton(patch);
    await frame();
  };
  const traces = [];
  const sample = name => {
    const button = document.querySelector('[data-case="button-lifecycle"]');
    const children = [...button.children];
    const gradient = children.find(element => getComputedStyle(element).backgroundImage.includes('radial-gradient'));
    const status = button.querySelector('[role="status"]');
    const result = {name,
      label: +getComputedStyle(button.querySelector('span')).opacity,
      loader: !!status,
      glow: +getComputedStyle(gradient).opacity,
      dimmer: +getComputedStyle(children.at(-1)).opacity,
    };
    traces.push(result);
    return result;
  };
  for (const variant of ['fill', 'weak']) {
    await update({loading:false, disabled:false, variant});
    await sleep(800);
    await update({loading:true, disabled:true});
    await sleep(800);
    if (sample(`${variant}-disabled-loading`).dimmer !== 0) {
      throw new Error('Disabled loading dimmer must be transparent');
    }
  }
  await update({loading:true, disabled:false, variant:'fill'});
  await sleep(270);
  sample('before-exit');
  await update({loading:false});
  const exiting = sample('during-exit');
  if (!exiting.loader || exiting.label !== 0 || exiting.glow <= 0) {
    throw new Error('Expected retained loader/glow and delayed label during exit');
  }
  await sleep(900);
  const finished = sample('after-exit');
  if (finished.loader || finished.label !== 1 || finished.glow !== 0) {
    throw new Error('Expected completed loader/glow exit and restored label');
  }
  return {source:'@toss/tds-mobile@2.5.1', traces};
})();
