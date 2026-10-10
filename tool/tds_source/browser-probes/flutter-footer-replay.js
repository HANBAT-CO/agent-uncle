// Run on the Flutter gallery ?family=list-footer-colors with semantics enabled.
// No animation frame may run between this first down/up pair.
return (async () => {
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  for (let i=0;i<50 && !document.querySelector('flt-semantics-host')?.textContent.includes('색상 변경');i++) {
    await sleep(100);
  }
  const surface = document.querySelector('flt-glass-pane');
  if (!surface) throw new Error('Flutter event surface is not ready');
  const send = (type, buttons) => surface.dispatchEvent(new PointerEvent(type, {
    bubbles:true,cancelable:true,pointerId:701,pointerType:'mouse',isPrimary:true,
    button:type === 'pointermove' ? -1 : 0,buttons,clientX:180,clientY:54,
  }));
  send('pointermove',0);
  send('pointerdown',1);
  send('pointerup',0);
  await sleep(500);
  const semantics = document.querySelector('flt-semantics-host');
  if (!semantics?.textContent.includes('클릭 1')) throw new Error('Fast raw click was not delivered exactly once');
  const change = [...semantics.querySelectorAll('[role="button"]')].find(node => node.textContent === '색상 변경');
  if (!change) throw new Error('Color control missing');
  change.click();
  await sleep(650);
  return {action:'fresh same-turn press/release then descendant color change',text:semantics.textContent};
})();
